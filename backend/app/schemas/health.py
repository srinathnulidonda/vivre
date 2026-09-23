# app/schemas/health.py
import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.health import DeviceConnectionPlatform, DeviceConnectionStatus


class DailyMetricUpsertRequest(BaseModel):
    metric_date: date
    steps: int = Field(ge=0)
    distance_meters: float = Field(ge=0)
    active_calories: float = Field(ge=0)


class DailyMetricRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    metric_date: date
    steps: int
    distance_meters: float
    active_calories: float


class SleepRecordUpsertRequest(BaseModel):
    sleep_date: date
    start_at: datetime
    end_at: datetime
    duration_minutes: int = Field(ge=0)
    quality: str | None = Field(default=None, max_length=64)


class SleepRecordRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    sleep_date: date
    start_at: datetime
    end_at: datetime
    duration_minutes: int
    quality: str | None


class WorkoutCreateRequest(BaseModel):
    workout_type: str = Field(min_length=1, max_length=128)
    start_at: datetime
    end_at: datetime | None = None
    duration_minutes: int | None = Field(default=None, ge=0)
    calories: float | None = Field(default=None, ge=0)
    distance_meters: float | None = Field(default=None, ge=0)


class WorkoutRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    workout_type: str
    start_at: datetime
    end_at: datetime | None
    duration_minutes: int | None
    calories: float | None
    distance_meters: float | None


class DeviceConnectionCreateRequest(BaseModel):
    platform: DeviceConnectionPlatform


class DeviceConnectionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    platform: DeviceConnectionPlatform
    status: DeviceConnectionStatus
    connected_at: datetime | None
    disconnected_at: datetime | None


class HealthContextSummary(BaseModel):
    steps_count: int | None
    distance_meters: float | None
    active_calories: float | None
    sleep_hours: float | None
    recent_workouts_count: int