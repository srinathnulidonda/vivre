# app/api/work.py
import uuid

from fastapi import APIRouter, Depends, File, Query, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.db.session import get_db
from app.models.user import User
from app.models.work import ProjectStatus, TaskStatus
from app.schemas.shared import PaginatedResponse, PaginationParams, pagination_params
from app.schemas.work import (
    ActivityLogEntryRead,
    ClientCreateRequest,
    ClientRead,
    ClientUpdateRequest,
    CoverImageResponse,
    DependencyCreateRequest,
    DependencyRead,
    FocusSessionRead,
    FocusSessionStartRequest,
    MilestoneCreateRequest,
    MilestoneRead,
    MilestoneUpdateRequest,
    ProjectCreateRequest,
    ProjectDetailRead,
    ProjectRead,
    ProjectTemplateCreateRequest,
    ProjectTemplateRead,
    ProjectUpdateRequest,
    TaskCreateRequest,
    TaskDetailRead,
    TaskRead,
    TaskUpdateRequest,
    TemplateInstantiateRequest,
)
from app.services import work as work_service
from app.services.shared import read_upload_file_within_limit

router = APIRouter(prefix="/work", tags=["work"])
_settings = get_settings()


@router.post("/clients", response_model=ClientRead, status_code=status.HTTP_201_CREATED)
async def create_client(
    payload: ClientCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ClientRead:
    client = await work_service.create_client(session, current_user.id, payload)
    return ClientRead.model_validate(client)


@router.get("/clients", response_model=PaginatedResponse[ClientRead], status_code=status.HTTP_200_OK)
async def list_clients(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[ClientRead]:
    clients, total = await work_service.list_clients(session, current_user.id, pagination)
    return PaginatedResponse(items=clients, total=total, limit=pagination.limit, offset=pagination.offset)


@router.patch("/clients/{client_id}", response_model=ClientRead, status_code=status.HTTP_200_OK)
async def update_client(
    client_id: uuid.UUID,
    payload: ClientUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ClientRead:
    client = await work_service.update_client(session, current_user.id, client_id, payload)
    return ClientRead.model_validate(client)


@router.delete("/clients/{client_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_client(
    client_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await work_service.delete_client(session, current_user.id, client_id)


@router.post("/templates", response_model=ProjectTemplateRead, status_code=status.HTTP_201_CREATED)
async def create_project_template(
    payload: ProjectTemplateCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ProjectTemplateRead:
    template = await work_service.create_project_template(session, current_user.id, payload)
    return ProjectTemplateRead.model_validate(template)


@router.get("/templates", response_model=PaginatedResponse[ProjectTemplateRead], status_code=status.HTTP_200_OK)
async def list_project_templates(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[ProjectTemplateRead]:
    templates, total = await work_service.list_project_templates(session, current_user.id, pagination)
    return PaginatedResponse(items=templates, total=total, limit=pagination.limit, offset=pagination.offset)


@router.post("/templates/instantiate", response_model=ProjectRead, status_code=status.HTTP_201_CREATED)
async def instantiate_template(
    payload: TemplateInstantiateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ProjectRead:
    project = await work_service.instantiate_template(
        session, current_user.id, payload.template_id, payload.project_name
    )
    return ProjectRead.model_validate(project)


@router.post("/projects", response_model=ProjectRead, status_code=status.HTTP_201_CREATED)
async def create_project(
    payload: ProjectCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ProjectRead:
    project = await work_service.create_project(session, current_user.id, payload)
    return ProjectRead.model_validate(project)


@router.get("/projects", response_model=PaginatedResponse[ProjectRead], status_code=status.HTTP_200_OK)
async def list_projects(
    status_filter: ProjectStatus | None = Query(default=None, alias="status"),
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[ProjectRead]:
    projects, total = await work_service.list_projects(session, current_user.id, pagination, status=status_filter)
    return PaginatedResponse(items=projects, total=total, limit=pagination.limit, offset=pagination.offset)


@router.post("/projects/{project_id}/cover", response_model=CoverImageResponse, status_code=status.HTTP_200_OK)
async def upload_project_cover(
    project_id: uuid.UUID,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> CoverImageResponse:
    file_bytes = await read_upload_file_within_limit(
        file, _settings.MAX_UPLOAD_BYTES, _settings.UPLOAD_CHUNK_SIZE_BYTES
    )
    cover_image_url, cover_image_public_id = await work_service.upload_project_cover(
        session, current_user.id, project_id, file_bytes, file.content_type or ""
    )
    return CoverImageResponse(cover_image_url=cover_image_url, cover_image_public_id=cover_image_public_id)


@router.delete("/projects/{project_id}/cover", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_project_cover(
    project_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await work_service.delete_project_cover(session, current_user.id, project_id)


@router.post("/projects/{project_id}/milestones", response_model=MilestoneRead, status_code=status.HTTP_201_CREATED)
async def create_milestone(
    project_id: uuid.UUID,
    payload: MilestoneCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> MilestoneRead:
    milestone = await work_service.create_milestone(session, current_user.id, project_id, payload)
    return MilestoneRead.model_validate(milestone)


@router.get("/projects/{project_id}/activity", response_model=PaginatedResponse[ActivityLogEntryRead], status_code=status.HTTP_200_OK)
async def list_activity_log(
    project_id: uuid.UUID,
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[ActivityLogEntryRead]:
    entries, total = await work_service.list_activity_log(session, current_user.id, project_id, pagination)
    return PaginatedResponse(items=entries, total=total, limit=pagination.limit, offset=pagination.offset)


@router.get("/projects/{project_id}", response_model=ProjectDetailRead, status_code=status.HTTP_200_OK)
async def get_project_detail(
    project_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ProjectDetailRead:
    project, task_count, completed_task_count, milestone_count = await work_service.get_project_detail(
        session, current_user.id, project_id
    )
    return ProjectDetailRead(
        id=project.id,
        name=project.name,
        description=project.description,
        client_id=project.client_id,
        status=project.status,
        cover_image_url=project.cover_image_url,
        cover_image_public_id=project.cover_image_public_id,
        start_date=project.start_date,
        due_date=project.due_date,
        created_at=project.created_at,
        updated_at=project.updated_at,
        task_count=task_count,
        completed_task_count=completed_task_count,
        milestone_count=milestone_count,
    )


@router.patch("/projects/{project_id}", response_model=ProjectRead, status_code=status.HTTP_200_OK)
async def update_project(
    project_id: uuid.UUID,
    payload: ProjectUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ProjectRead:
    project = await work_service.update_project(session, current_user.id, project_id, payload)
    return ProjectRead.model_validate(project)


@router.delete("/projects/{project_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_project(
    project_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await work_service.delete_project(session, current_user.id, project_id)


@router.patch("/milestones/{milestone_id}", response_model=MilestoneRead, status_code=status.HTTP_200_OK)
async def update_milestone(
    milestone_id: uuid.UUID,
    payload: MilestoneUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> MilestoneRead:
    milestone = await work_service.update_milestone(session, current_user.id, milestone_id, payload)
    return MilestoneRead.model_validate(milestone)


@router.delete("/milestones/{milestone_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_milestone(
    milestone_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await work_service.delete_milestone(session, current_user.id, milestone_id)


@router.post("/tasks", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
async def create_task(
    payload: TaskCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> TaskRead:
    task = await work_service.create_task(session, current_user.id, payload)
    return TaskRead.model_validate(task)


@router.get("/tasks", response_model=PaginatedResponse[TaskRead], status_code=status.HTTP_200_OK)
async def list_tasks(
    project_id: uuid.UUID | None = Query(default=None),
    status_filter: TaskStatus | None = Query(default=None, alias="status"),
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[TaskRead]:
    tasks, total = await work_service.list_tasks(
        session, current_user.id, pagination, project_id=project_id, status=status_filter
    )
    return PaginatedResponse(items=tasks, total=total, limit=pagination.limit, offset=pagination.offset)


@router.get("/tasks/{task_id}", response_model=TaskDetailRead, status_code=status.HTTP_200_OK)
async def get_task_detail(
    task_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> TaskDetailRead:
    task = await work_service.get_task_detail(session, current_user.id, task_id)
    return TaskDetailRead(
        id=task.id,
        project_id=task.project_id,
        milestone_id=task.milestone_id,
        parent_task_id=task.parent_task_id,
        title=task.title,
        description=task.description,
        status=task.status,
        priority=task.priority,
        due_date=task.due_date,
        completed_at=task.completed_at,
        position=task.position,
        created_at=task.created_at,
        updated_at=task.updated_at,
        subtasks=[TaskRead.model_validate(subtask) for subtask in task.subtasks],
        dependency_ids=[dependency.depends_on_task_id for dependency in task.dependencies],
    )


@router.patch("/tasks/{task_id}", response_model=TaskRead, status_code=status.HTTP_200_OK)
async def update_task(
    task_id: uuid.UUID,
    payload: TaskUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> TaskRead:
    task = await work_service.update_task(session, current_user.id, task_id, payload)
    return TaskRead.model_validate(task)


@router.patch("/tasks/{task_id}/parent", response_model=TaskRead, status_code=status.HTTP_200_OK)
async def update_task_parent(
    task_id: uuid.UUID,
    new_parent_id: uuid.UUID | None = Query(default=None),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> TaskRead:
    task = await work_service.update_task_parent(session, current_user.id, task_id, new_parent_id)
    return TaskRead.model_validate(task)


@router.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_task(
    task_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await work_service.delete_task(session, current_user.id, task_id)


@router.post("/tasks/{task_id}/dependencies", response_model=DependencyRead, status_code=status.HTTP_201_CREATED)
async def create_dependency(
    task_id: uuid.UUID,
    payload: DependencyCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> DependencyRead:
    dependency = await work_service.create_dependency(session, current_user.id, task_id, payload)
    return DependencyRead.model_validate(dependency)


@router.delete("/dependencies/{dependency_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_dependency(
    dependency_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await work_service.delete_dependency(session, current_user.id, dependency_id)


@router.post("/focus-sessions", response_model=FocusSessionRead, status_code=status.HTTP_201_CREATED)
async def start_focus_session(
    payload: FocusSessionStartRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> FocusSessionRead:
    focus_session = await work_service.start_focus_session(
        session, current_user.id, payload.task_id, payload.project_id
    )
    return FocusSessionRead.model_validate(focus_session)


@router.post("/focus-sessions/{focus_session_id}/stop", response_model=FocusSessionRead, status_code=status.HTTP_200_OK)
async def stop_focus_session(
    focus_session_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> FocusSessionRead:
    focus_session = await work_service.stop_focus_session(session, current_user.id, focus_session_id)
    return FocusSessionRead.model_validate(focus_session)