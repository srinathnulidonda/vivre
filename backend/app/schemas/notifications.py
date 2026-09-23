# app/schemas/notifications.py
import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from app.models.notifications import NotificationChannel


class NotificationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    notification_type: str
    channel: NotificationChannel
    payload: dict[str, Any]
    read_at: datetime | None
    sent_at: datetime | None
    failed_at: datetime | None
    created_at: datetime


class NotificationPreferenceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    push_tasks: bool
    push_habits: bool
    push_reviews: bool
    push_goals: bool
    push_milestones: bool
    email_digest: bool
    email_reviews: bool
    inapp_tasks: bool
    inapp_habits: bool
    inapp_reviews: bool
    inapp_goals: bool
    inapp_milestones: bool


class NotificationPreferenceUpdateRequest(BaseModel):
    push_tasks: bool | None = None
    push_habits: bool | None = None
    push_reviews: bool | None = None
    push_goals: bool | None = None
    push_milestones: bool | None = None
    email_digest: bool | None = None
    email_reviews: bool | None = None
    inapp_tasks: bool | None = None
    inapp_habits: bool | None = None
    inapp_reviews: bool | None = None
    inapp_goals: bool | None = None
    inapp_milestones: bool | None = None


class DeviceTokenRequest(BaseModel):
    device_token: str = Field(min_length=1, max_length=512)


class MarkAllReadResponse(BaseModel):
    marked_count: int