# app/schemas/personal.py
import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.personal import GoalStatus, HabitFrequency


class GoalCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    description: str | None = None
    target_date: date | None = None


class GoalUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    status: GoalStatus | None = None
    target_date: date | None = None


class GoalRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    title: str
    description: str | None
    status: GoalStatus
    target_date: date | None
    created_at: datetime


class KeyResultCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    target_value: float
    current_value: float = 0.0
    unit: str = Field(min_length=1, max_length=64)


class KeyResultUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    target_value: float | None = None
    current_value: float | None = None
    unit: str | None = Field(default=None, min_length=1, max_length=64)


class KeyResultRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    goal_id: uuid.UUID
    title: str
    target_value: float
    current_value: float
    unit: str


class GoalDetailRead(GoalRead):
    key_results: list[KeyResultRead] = Field(default_factory=list)


class HabitCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    frequency: HabitFrequency = HabitFrequency.DAILY
    target_count: int = Field(default=1, ge=1)


class HabitUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    frequency: HabitFrequency | None = None
    target_count: int | None = Field(default=None, ge=1)
    is_archived: bool | None = None


class HabitRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    name: str
    frequency: HabitFrequency
    target_count: int
    is_archived: bool


class HabitLogCreateRequest(BaseModel):
    log_date: date
    count: int = Field(default=1, ge=1)


class HabitLogRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    habit_id: uuid.UUID
    date: date
    count: int


class JournalEntryCreateRequest(BaseModel):
    title: str | None = Field(default=None, max_length=255)
    content: str = Field(min_length=1)
    mood: str | None = Field(default=None, max_length=64)
    entry_date: date


class JournalEntryUpdateRequest(BaseModel):
    title: str | None = Field(default=None, max_length=255)
    content: str | None = None
    mood: str | None = Field(default=None, max_length=64)


class JournalEntryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    title: str | None
    content: str
    mood: str | None
    entry_date: date
    created_at: datetime


class EventCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    description: str | None = None
    start_at: datetime
    end_at: datetime
    location: str | None = Field(default=None, max_length=255)


class EventUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    start_at: datetime | None = None
    end_at: datetime | None = None
    location: str | None = Field(default=None, max_length=255)


class EventRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    title: str
    description: str | None
    start_at: datetime
    end_at: datetime
    location: str | None


class TimeBlockCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    start_at: datetime
    end_at: datetime
    task_id: uuid.UUID | None = None
    event_id: uuid.UUID | None = None


class TimeBlockUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    start_at: datetime | None = None
    end_at: datetime | None = None
    task_id: uuid.UUID | None = None
    event_id: uuid.UUID | None = None


class TimeBlockRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    title: str
    start_at: datetime
    end_at: datetime
    task_id: uuid.UUID | None
    event_id: uuid.UUID | None


class DailyActivityCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    category: str = Field(min_length=1, max_length=128)
    duration_minutes: int | None = Field(default=None, ge=0)
    activity_date: date


class DailyActivityUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    category: str | None = Field(default=None, min_length=1, max_length=128)
    duration_minutes: int | None = Field(default=None, ge=0)


class DailyActivityRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    title: str
    category: str
    duration_minutes: int | None
    activity_date: date

class HabitStreakResponse(BaseModel):
    streak: int