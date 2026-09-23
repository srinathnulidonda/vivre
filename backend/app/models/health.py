# app/models/health.py
import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class DeviceConnectionPlatform(str, enum.Enum):
    APPLE_HEALTH = "apple_health"
    GOOGLE_HEALTH_CONNECT = "google_health_connect"
    FITBIT = "fitbit"
    GARMIN = "garmin"
    OTHER = "other"


class DeviceConnectionStatus(str, enum.Enum):
    CONNECTED = "connected"
    DISCONNECTED = "disconnected"
    ERROR = "error"


class DailyMetric(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "daily_metrics"
    __table_args__ = (UniqueConstraint("user_id", "metric_date"),)

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    metric_date: Mapped[date] = mapped_column(Date, index=True, nullable=False)
    steps: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    distance_meters: Mapped[float] = mapped_column(Float, nullable=False, default=0.0, server_default="0")
    active_calories: Mapped[float] = mapped_column(Float, nullable=False, default=0.0, server_default="0")


class SleepRecord(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "sleep_records"
    __table_args__ = (UniqueConstraint("user_id", "sleep_date"),)

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    sleep_date: Mapped[date] = mapped_column(Date, index=True, nullable=False)
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    duration_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    quality: Mapped[str | None] = mapped_column(String(64), nullable=True)


class Workout(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "workouts"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    workout_type: Mapped[str] = mapped_column(String(128), index=True, nullable=False)
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True, nullable=False)
    end_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    calories: Mapped[float | None] = mapped_column(Float, nullable=True)
    distance_meters: Mapped[float | None] = mapped_column(Float, nullable=True)


class DeviceConnection(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "device_connections"
    __table_args__ = (UniqueConstraint("user_id", "platform"),)

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    platform: Mapped[DeviceConnectionPlatform] = mapped_column(
        SqlEnum(
            DeviceConnectionPlatform,
            name="device_connection_platform",
            native_enum=False,
            validate_strings=True,
            create_constraint=True,
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
        ),
        index=True,
        nullable=False,
    )
    status: Mapped[DeviceConnectionStatus] = mapped_column(
        SqlEnum(
            DeviceConnectionStatus,
            name="device_connection_status",
            native_enum=False,
            validate_strings=True,
            create_constraint=True,
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
        ),
        index=True,
        nullable=False,
        default=DeviceConnectionStatus.CONNECTED,
        server_default=DeviceConnectionStatus.CONNECTED.value,
    )
    connected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    disconnected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)