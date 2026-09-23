# app/schemas/work.py
import uuid
from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from app.models.work import ProjectStatus, TaskPriority, TaskStatus


class ClientCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    email: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=64)
    notes: str | None = None


class ClientUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    email: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=64)
    notes: str | None = None


class ClientRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    name: str
    email: str | None
    phone: str | None
    notes: str | None
    created_at: datetime


class ProjectTemplateCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    blueprint: dict[str, Any]


class ProjectTemplateRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    name: str
    blueprint: dict[str, Any]
    created_at: datetime


class TemplateInstantiateRequest(BaseModel):
    template_id: uuid.UUID
    project_name: str = Field(min_length=1, max_length=255)


class ProjectCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    client_id: uuid.UUID | None = None
    start_date: date | None = None
    due_date: date | None = None


class ProjectUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    client_id: uuid.UUID | None = None
    status: ProjectStatus | None = None
    start_date: date | None = None
    due_date: date | None = None


class ProjectRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    name: str
    description: str | None
    client_id: uuid.UUID | None
    status: ProjectStatus
    cover_image_url: str | None
    cover_image_public_id: str | None
    start_date: date | None
    due_date: date | None
    created_at: datetime
    updated_at: datetime


class ProjectDetailRead(ProjectRead):
    task_count: int
    completed_task_count: int
    milestone_count: int


class MilestoneCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    due_date: date | None = None


class MilestoneUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    due_date: date | None = None
    is_completed: bool | None = None


class MilestoneRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    project_id: uuid.UUID
    title: str
    due_date: date | None
    is_completed: bool
    completed_at: datetime | None


class TaskCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    description: str | None = None
    project_id: uuid.UUID | None = None
    milestone_id: uuid.UUID | None = None
    parent_task_id: uuid.UUID | None = None
    priority: TaskPriority = TaskPriority.MEDIUM
    due_date: datetime | None = None


class TaskUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=500)
    description: str | None = None
    milestone_id: uuid.UUID | None = None
    status: TaskStatus | None = None
    priority: TaskPriority | None = None
    due_date: datetime | None = None
    position: int | None = None


class TaskRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    project_id: uuid.UUID | None
    milestone_id: uuid.UUID | None
    parent_task_id: uuid.UUID | None
    title: str
    description: str | None
    status: TaskStatus
    priority: TaskPriority
    due_date: datetime | None
    completed_at: datetime | None
    position: int
    created_at: datetime
    updated_at: datetime


class TaskDetailRead(TaskRead):
    subtasks: list[TaskRead] = Field(default_factory=list)
    dependency_ids: list[uuid.UUID] = Field(default_factory=list)


class DependencyCreateRequest(BaseModel):
    depends_on_task_id: uuid.UUID


class DependencyRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    task_id: uuid.UUID
    depends_on_task_id: uuid.UUID


class FocusSessionStartRequest(BaseModel):
    task_id: uuid.UUID | None = None
    project_id: uuid.UUID | None = None


class FocusSessionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    task_id: uuid.UUID | None
    project_id: uuid.UUID | None
    start_at: datetime
    end_at: datetime | None
    duration_seconds: int | None


class CoverImageResponse(BaseModel):
    cover_image_url: str
    cover_image_public_id: str


class ActivityLogEntryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    action: str
    entry_metadata: dict[str, Any] | None
    created_at: datetime

class BlueprintMilestoneSpec(BaseModel):
    title: str = Field(min_length=1, max_length=255)


class BlueprintTaskSpec(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    milestone_index: int | None = None


class ProjectTemplateBlueprint(BaseModel):
    milestones: list[BlueprintMilestoneSpec] = Field(default_factory=list)
    tasks: list[BlueprintTaskSpec] = Field(default_factory=list)