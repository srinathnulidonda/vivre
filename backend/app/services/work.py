# app/services/work.py
import asyncio
import uuid
from datetime import datetime, timezone
from typing import Any

from pydantic import ValidationError as PydanticValidationError
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased, selectinload

from app.core.config import get_settings
from app.core.exceptions import ConflictError, NotFoundError, PermissionDeniedError, ValidationError
from app.events import EventType, MilestoneCompletedPayload, TaskCompletedPayload, event_bus
from app.integrations.cloudinary import delete_image, upload_image
from app.models.work import (
    ActivityLogEntry,
    Client,
    Dependency,
    FocusSession,
    Milestone,
    Project,
    ProjectStatus,
    ProjectTemplate,
    Task,
    TaskStatus,
)
from app.schemas.shared import PaginationParams
from app.schemas.work import (
    ClientCreateRequest,
    ClientUpdateRequest,
    DependencyCreateRequest,
    MilestoneCreateRequest,
    MilestoneUpdateRequest,
    ProjectCreateRequest,
    ProjectTemplateBlueprint,
    ProjectTemplateCreateRequest,
    ProjectUpdateRequest,
    TaskCreateRequest,
    TaskUpdateRequest,
)

_settings = get_settings()

_NULLABLE_CLIENT_FIELDS = frozenset({"email", "phone", "notes"})
_NULLABLE_PROJECT_FIELDS = frozenset({"client_id", "description", "start_date", "due_date"})
_NULLABLE_MILESTONE_FIELDS = frozenset({"due_date"})
_NULLABLE_TASK_FIELDS = frozenset({"description", "due_date", "milestone_id"})


def _apply_updates(entity, update_fields: dict, nullable_fields: frozenset[str]) -> None:
    for field_name, field_value in update_fields.items():
        if field_value is None and field_name not in nullable_fields:
            continue
        setattr(entity, field_name, field_value)


def _validate_blueprint(blueprint: dict[str, Any]) -> ProjectTemplateBlueprint:
    try:
        return ProjectTemplateBlueprint.model_validate(blueprint)
    except PydanticValidationError as exc:
        raise ValidationError("Invalid project template blueprint structure") from exc


async def _get_owned_client(session: AsyncSession, user_id: uuid.UUID, client_id: uuid.UUID) -> Client:
    client = await session.get(Client, client_id)
    if client is None:
        raise NotFoundError("Client not found")
    if client.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this client")
    return client


async def _get_owned_project(
    session: AsyncSession, user_id: uuid.UUID, project_id: uuid.UUID
) -> Project:
    project = await session.get(Project, project_id)
    if project is None:
        raise NotFoundError("Project not found")
    if project.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this project")
    return project


async def _get_owned_task(session: AsyncSession, user_id: uuid.UUID, task_id: uuid.UUID) -> Task:
    task = await session.get(Task, task_id)
    if task is None:
        raise NotFoundError("Task not found")
    if task.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this task")
    return task


async def _get_owned_milestone(
    session: AsyncSession, user_id: uuid.UUID, milestone_id: uuid.UUID
) -> Milestone:
    milestone = await session.get(Milestone, milestone_id)
    if milestone is None:
        raise NotFoundError("Milestone not found")
    project = await session.get(Project, milestone.project_id)
    if project is None or project.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this milestone")
    return milestone


async def create_client(
    session: AsyncSession, user_id: uuid.UUID, request: ClientCreateRequest
) -> Client:
    client = Client(
        user_id=user_id,
        name=request.name,
        email=request.email,
        phone=request.phone,
        notes=request.notes,
    )
    session.add(client)
    await session.commit()
    await session.refresh(client)
    return client


async def update_client(
    session: AsyncSession, user_id: uuid.UUID, client_id: uuid.UUID, request: ClientUpdateRequest
) -> Client:
    client = await _get_owned_client(session, user_id, client_id)
    _apply_updates(client, request.model_dump(exclude_unset=True), _NULLABLE_CLIENT_FIELDS)
    await session.commit()
    await session.refresh(client)
    return client


async def delete_client(
    session: AsyncSession, user_id: uuid.UUID, client_id: uuid.UUID
) -> None:
    client = await _get_owned_client(session, user_id, client_id)
    await session.delete(client)
    await session.commit()


async def list_clients(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[Client], int]:
    count_result = await session.execute(
        select(func.count()).select_from(Client).where(Client.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(Client)
        .where(Client.user_id == user_id)
        .order_by(Client.name.asc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def create_project_template(
    session: AsyncSession, user_id: uuid.UUID, request: ProjectTemplateCreateRequest
) -> ProjectTemplate:
    _validate_blueprint(request.blueprint)
    template = ProjectTemplate(user_id=user_id, name=request.name, blueprint=request.blueprint)
    session.add(template)
    await session.commit()
    await session.refresh(template)
    return template


async def list_project_templates(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[ProjectTemplate], int]:
    count_result = await session.execute(
        select(func.count()).select_from(ProjectTemplate).where(ProjectTemplate.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(ProjectTemplate)
        .where(ProjectTemplate.user_id == user_id)
        .order_by(ProjectTemplate.name.asc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def instantiate_template(
    session: AsyncSession, user_id: uuid.UUID, template_id: uuid.UUID, project_name: str
) -> Project:
    template = await session.get(ProjectTemplate, template_id)
    if template is None:
        raise NotFoundError("Project template not found")
    if template.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this template")
    blueprint = _validate_blueprint(template.blueprint)
    project = Project(user_id=user_id, name=project_name, status=ProjectStatus.ACTIVE)
    session.add(project)
    await session.flush()

    milestone_instances = [
        Milestone(project_id=project.id, title=milestone_spec.title, due_date=None)
        for milestone_spec in blueprint.milestones
    ]
    if milestone_instances:
        session.add_all(milestone_instances)
        await session.flush()
    milestone_id_by_index = {index: milestone.id for index, milestone in enumerate(milestone_instances)}

    task_instances = [
        Task(
            user_id=user_id,
            project_id=project.id,
            milestone_id=(
                milestone_id_by_index.get(task_spec.milestone_index)
                if task_spec.milestone_index is not None
                else None
            ),
            title=task_spec.title,
        )
        for task_spec in blueprint.tasks
    ]
    if task_instances:
        session.add_all(task_instances)

    await session.commit()
    await session.refresh(project)
    return project


async def create_project(
    session: AsyncSession, user_id: uuid.UUID, request: ProjectCreateRequest
) -> Project:
    if request.client_id is not None:
        await _get_owned_client(session, user_id, request.client_id)
    project = Project(
        user_id=user_id,
        name=request.name,
        description=request.description,
        client_id=request.client_id,
        start_date=request.start_date,
        due_date=request.due_date,
    )
    session.add(project)
    await session.commit()
    await session.refresh(project)
    return project


async def update_project(
    session: AsyncSession, user_id: uuid.UUID, project_id: uuid.UUID, request: ProjectUpdateRequest
) -> Project:
    project = await _get_owned_project(session, user_id, project_id)
    update_fields = request.model_dump(exclude_unset=True)
    if "client_id" in update_fields and update_fields["client_id"] is not None:
        await _get_owned_client(session, user_id, update_fields["client_id"])
    _apply_updates(project, update_fields, _NULLABLE_PROJECT_FIELDS)
    await session.commit()
    await session.refresh(project)
    return project


async def delete_project(session: AsyncSession, user_id: uuid.UUID, project_id: uuid.UUID) -> None:
    project = await _get_owned_project(session, user_id, project_id)
    if project.cover_image_public_id:
        await asyncio.to_thread(delete_image, project.cover_image_public_id)
    await session.delete(project)
    await session.commit()


async def list_projects(
    session: AsyncSession,
    user_id: uuid.UUID,
    pagination: PaginationParams,
    status: ProjectStatus | None = None,
) -> tuple[list[Project], int]:
    filters = [Project.user_id == user_id]
    if status is not None:
        filters.append(Project.status == status)
    count_result = await session.execute(select(func.count()).select_from(Project).where(*filters))
    total = count_result.scalar_one()
    result = await session.execute(
        select(Project)
        .where(*filters)
        .order_by(Project.updated_at.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def get_project_detail(
    session: AsyncSession, user_id: uuid.UUID, project_id: uuid.UUID
) -> tuple[Project, int, int, int]:
    project = await _get_owned_project(session, user_id, project_id)
    task_count_result = await session.execute(
        select(func.count()).select_from(Task).where(Task.project_id == project_id)
    )
    completed_task_count_result = await session.execute(
        select(func.count())
        .select_from(Task)
        .where(Task.project_id == project_id, Task.status == TaskStatus.DONE)
    )
    milestone_count_result = await session.execute(
        select(func.count()).select_from(Milestone).where(Milestone.project_id == project_id)
    )
    return (
        project,
        task_count_result.scalar_one(),
        completed_task_count_result.scalar_one(),
        milestone_count_result.scalar_one(),
    )


async def upload_project_cover(
    session: AsyncSession,
    user_id: uuid.UUID,
    project_id: uuid.UUID,
    file_bytes: bytes,
    content_type: str,
) -> tuple[str, str]:
    if content_type not in _settings.allowed_image_content_types_list:
        raise ValidationError(f"Unsupported image content type: {content_type}")
    project = await _get_owned_project(session, user_id, project_id)
    previous_public_id = project.cover_image_public_id
    cover_image_url, cover_image_public_id = await asyncio.to_thread(
        upload_image, file_bytes, folder=f"vivre/projects/{project_id}", public_id="cover"
    )
    project.cover_image_url = cover_image_url
    project.cover_image_public_id = cover_image_public_id
    await session.commit()
    if previous_public_id and previous_public_id != cover_image_public_id:
        await asyncio.to_thread(delete_image, previous_public_id)
    return cover_image_url, cover_image_public_id


async def delete_project_cover(
    session: AsyncSession, user_id: uuid.UUID, project_id: uuid.UUID
) -> None:
    project = await _get_owned_project(session, user_id, project_id)
    if project.cover_image_public_id:
        await asyncio.to_thread(delete_image, project.cover_image_public_id)
    project.cover_image_url = None
    project.cover_image_public_id = None
    await session.commit()


async def create_milestone(
    session: AsyncSession, user_id: uuid.UUID, project_id: uuid.UUID, request: MilestoneCreateRequest
) -> Milestone:
    await _get_owned_project(session, user_id, project_id)
    milestone = Milestone(project_id=project_id, title=request.title, due_date=request.due_date)
    session.add(milestone)
    await session.commit()
    await session.refresh(milestone)
    return milestone


async def update_milestone(
    session: AsyncSession,
    user_id: uuid.UUID,
    milestone_id: uuid.UUID,
    request: MilestoneUpdateRequest,
) -> Milestone:
    milestone = await _get_owned_milestone(session, user_id, milestone_id)
    update_fields = request.model_dump(exclude_unset=True)
    new_is_completed = update_fields.get("is_completed")
    newly_completed = new_is_completed is True and not milestone.is_completed
    _apply_updates(milestone, update_fields, _NULLABLE_MILESTONE_FIELDS)
    if new_is_completed is not None:
        milestone.completed_at = datetime.now(timezone.utc) if new_is_completed else None
    await session.commit()
    await session.refresh(milestone)
    if newly_completed:
        await event_bus.publish(
            EventType.MILESTONE_COMPLETED,
            MilestoneCompletedPayload(
                user_id=user_id,
                milestone_id=milestone.id,
                project_id=milestone.project_id,
                milestone_title=milestone.title,
                completed_at=milestone.completed_at or datetime.now(timezone.utc),
            ),
        )
    return milestone


async def delete_milestone(
    session: AsyncSession, user_id: uuid.UUID, milestone_id: uuid.UUID
) -> None:
    milestone = await _get_owned_milestone(session, user_id, milestone_id)
    await session.delete(milestone)
    await session.commit()


async def _assert_no_parent_cycle(
    session: AsyncSession, task_id: uuid.UUID, new_parent_id: uuid.UUID
) -> None:
    ancestor_cte = (
        select(Task.id, Task.parent_task_id)
        .where(Task.id == new_parent_id)
        .cte(name="ancestor_chain", recursive=True)
    )
    ancestor_alias = ancestor_cte.alias()
    task_alias = aliased(Task)
    ancestor_cte = ancestor_cte.union(
        select(task_alias.id, task_alias.parent_task_id).join(
            ancestor_alias, task_alias.id == ancestor_alias.c.parent_task_id
        )
    )
    result = await session.execute(select(ancestor_cte.c.id))
    ancestor_ids = {row[0] for row in result.all()}
    if task_id in ancestor_ids:
        raise ConflictError("Assigning this parent would create a cycle in the task hierarchy")


async def _assert_no_dependency_cycle(
    session: AsyncSession, task_id: uuid.UUID, depends_on_task_id: uuid.UUID
) -> None:
    chain_cte = (
        select(Dependency.depends_on_task_id.label("dependency_id"))
        .where(Dependency.task_id == depends_on_task_id)
        .cte(name="dependency_chain", recursive=True)
    )
    chain_alias = chain_cte.alias()
    chain_cte = chain_cte.union(
        select(Dependency.depends_on_task_id.label("dependency_id")).join(
            chain_alias, Dependency.task_id == chain_alias.c.dependency_id
        )
    )
    result = await session.execute(select(chain_cte.c.dependency_id))
    reachable_ids = {row[0] for row in result.all()}
    if task_id in reachable_ids:
        raise ConflictError("Adding this dependency would create a cycle")


async def create_task(
    session: AsyncSession, user_id: uuid.UUID, request: TaskCreateRequest
) -> Task:
    if request.project_id is not None:
        await _get_owned_project(session, user_id, request.project_id)
    if request.milestone_id is not None:
        await _get_owned_milestone(session, user_id, request.milestone_id)
    if request.parent_task_id is not None:
        await _get_owned_task(session, user_id, request.parent_task_id)
    task = Task(
        user_id=user_id,
        project_id=request.project_id,
        milestone_id=request.milestone_id,
        parent_task_id=request.parent_task_id,
        title=request.title,
        description=request.description,
        priority=request.priority,
        due_date=request.due_date,
    )
    session.add(task)
    await session.commit()
    await session.refresh(task)
    return task


async def update_task(
    session: AsyncSession, user_id: uuid.UUID, task_id: uuid.UUID, request: TaskUpdateRequest
) -> Task:
    task = await _get_owned_task(session, user_id, task_id)
    update_fields = request.model_dump(exclude_unset=True)
    if "milestone_id" in update_fields and update_fields["milestone_id"] is not None:
        await _get_owned_milestone(session, user_id, update_fields["milestone_id"])
    new_status = update_fields.get("status")
    just_completed = new_status == TaskStatus.DONE and task.status != TaskStatus.DONE
    _apply_updates(task, update_fields, _NULLABLE_TASK_FIELDS)
    if new_status is not None:
        task.completed_at = datetime.now(timezone.utc) if new_status == TaskStatus.DONE else None
    if just_completed and task.project_id is not None:
        session.add(
            ActivityLogEntry(
                user_id=user_id,
                project_id=task.project_id,
                action="task_completed",
                entry_metadata={"task_id": str(task.id)},
            )
        )
    await session.commit()
    await session.refresh(task)
    if just_completed:
        await event_bus.publish(
            EventType.TASK_COMPLETED,
            TaskCompletedPayload(
                user_id=user_id,
                task_id=task.id,
                task_title=task.title,
                completed_at=task.completed_at or datetime.now(timezone.utc),
            ),
        )
    return task


async def update_task_parent(
    session: AsyncSession,
    user_id: uuid.UUID,
    task_id: uuid.UUID,
    new_parent_id: uuid.UUID | None,
) -> Task:
    task = await _get_owned_task(session, user_id, task_id)
    if new_parent_id is not None:
        await _get_owned_task(session, user_id, new_parent_id)
        await _assert_no_parent_cycle(session, task_id, new_parent_id)
    task.parent_task_id = new_parent_id
    await session.commit()
    await session.refresh(task)
    return task


async def delete_task(session: AsyncSession, user_id: uuid.UUID, task_id: uuid.UUID) -> None:
    task = await _get_owned_task(session, user_id, task_id)
    await session.delete(task)
    await session.commit()


async def list_tasks(
    session: AsyncSession,
    user_id: uuid.UUID,
    pagination: PaginationParams,
    project_id: uuid.UUID | None = None,
    status: TaskStatus | None = None,
) -> tuple[list[Task], int]:
    filters = [Task.user_id == user_id]
    if project_id is not None:
        filters.append(Task.project_id == project_id)
    if status is not None:
        filters.append(Task.status == status)
    count_result = await session.execute(select(func.count()).select_from(Task).where(*filters))
    total = count_result.scalar_one()
    result = await session.execute(
        select(Task)
        .options(selectinload(Task.dependencies))
        .where(*filters)
        .order_by(Task.due_date.asc().nulls_last(), Task.position.asc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def get_task_detail(session: AsyncSession, user_id: uuid.UUID, task_id: uuid.UUID) -> Task:
    result = await session.execute(
        select(Task)
        .options(selectinload(Task.subtasks), selectinload(Task.dependencies))
        .where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()
    if task is None:
        raise NotFoundError("Task not found")
    if task.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this task")
    return task


async def create_dependency(
    session: AsyncSession,
    user_id: uuid.UUID,
    task_id: uuid.UUID,
    request: DependencyCreateRequest,
) -> Dependency:
    if task_id == request.depends_on_task_id:
        raise ValidationError("A task cannot depend on itself")
    await _get_owned_task(session, user_id, task_id)
    await _get_owned_task(session, user_id, request.depends_on_task_id)
    await _assert_no_dependency_cycle(session, task_id, request.depends_on_task_id)
    dependency = Dependency(task_id=task_id, depends_on_task_id=request.depends_on_task_id)
    session.add(dependency)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise ConflictError("This dependency already exists") from exc
    await session.refresh(dependency)
    return dependency


async def delete_dependency(
    session: AsyncSession, user_id: uuid.UUID, dependency_id: uuid.UUID
) -> None:
    dependency = await session.get(Dependency, dependency_id)
    if dependency is None:
        raise NotFoundError("Dependency not found")
    await _get_owned_task(session, user_id, dependency.task_id)
    await session.delete(dependency)
    await session.commit()


async def start_focus_session(
    session: AsyncSession,
    user_id: uuid.UUID,
    task_id: uuid.UUID | None,
    project_id: uuid.UUID | None,
) -> FocusSession:
    if task_id is not None:
        await _get_owned_task(session, user_id, task_id)
    if project_id is not None:
        await _get_owned_project(session, user_id, project_id)
    focus_session = FocusSession(
        user_id=user_id,
        task_id=task_id,
        project_id=project_id,
        start_at=datetime.now(timezone.utc),
    )
    session.add(focus_session)
    await session.commit()
    await session.refresh(focus_session)
    return focus_session


async def stop_focus_session(
    session: AsyncSession, user_id: uuid.UUID, focus_session_id: uuid.UUID
) -> FocusSession:
    focus_session = await session.get(FocusSession, focus_session_id)
    if focus_session is None:
        raise NotFoundError("Focus session not found")
    if focus_session.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this focus session")
    if focus_session.end_at is not None:
        raise ConflictError("This focus session has already been stopped")
    focus_session.end_at = datetime.now(timezone.utc)
    focus_session.duration_seconds = int(
        (focus_session.end_at - focus_session.start_at).total_seconds()
    )
    await session.commit()
    await session.refresh(focus_session)
    return focus_session


async def list_activity_log(
    session: AsyncSession,
    user_id: uuid.UUID,
    project_id: uuid.UUID,
    pagination: PaginationParams,
) -> tuple[list[ActivityLogEntry], int]:
    await _get_owned_project(session, user_id, project_id)
    count_result = await session.execute(
        select(func.count())
        .select_from(ActivityLogEntry)
        .where(ActivityLogEntry.project_id == project_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(ActivityLogEntry)
        .where(ActivityLogEntry.project_id == project_id)
        .order_by(ActivityLogEntry.created_at.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total