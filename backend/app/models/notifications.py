# app/models/notifications.py
import enum
import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class NotificationChannel(str, enum.Enum):
    IN_APP = "in_app"
    PUSH = "push"
    EMAIL = "email"


class Notification(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "notifications"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    notification_type: Mapped[str] = mapped_column(String(128), index=True, nullable=False)
    channel: Mapped[NotificationChannel] = mapped_column(
        SqlEnum(
            NotificationChannel,
            name="notification_channel",
            native_enum=False,
            validate_strings=True,
            create_constraint=True,
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
        ),
        index=True,
        nullable=False,
    )
    payload: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True, nullable=True)
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True, nullable=True)
    delivery_attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    last_attempted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    failed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True, nullable=True)


class NotificationPreference(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "notification_preferences"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True, nullable=False
    )
    push_tasks: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    push_habits: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    push_reviews: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    push_goals: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    push_milestones: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    email_digest: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    email_reviews: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    inapp_tasks: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    inapp_habits: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    inapp_reviews: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    inapp_goals: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    inapp_milestones: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")

    user: Mapped["User"] = relationship(back_populates="notification_preference")