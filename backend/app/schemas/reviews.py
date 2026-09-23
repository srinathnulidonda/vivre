# app/schemas/reviews.py
import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field
from app.schemas.health import HealthContextSummary


class DailyReviewUpsertRequest(BaseModel):
    review_date: date
    wins: str | None = None
    blockers: str | None = None
    mood: str | None = Field(default=None, max_length=64)
    notes: str | None = None


class DailyReviewRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    review_date: date
    wins: str | None
    blockers: str | None
    mood: str | None
    notes: str | None
    created_at: datetime


class WeeklyReviewUpsertRequest(BaseModel):
    week_start_date: date
    wins: str | None = None
    blockers: str | None = None
    mood: str | None = Field(default=None, max_length=64)
    notes: str | None = None


class WeeklyReviewRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    week_start_date: date
    wins: str | None
    blockers: str | None
    mood: str | None
    notes: str | None
    created_at: datetime


class ReflectionCreateRequest(BaseModel):
    reflection_date: date
    prompt: str | None = Field(default=None, max_length=500)
    content: str = Field(min_length=1)


class ReflectionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    reflection_date: date
    prompt: str | None
    content: str
    created_at: datetime

class DailyReviewContext(BaseModel):
    review_date: str
    completed_task_count: int
    habit_streaks: dict[str, int]
    health_summary: HealthContextSummary