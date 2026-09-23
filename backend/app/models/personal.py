# app/models/personal.py
import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class GoalStatus(str, enum.Enum):
    ACTIVE = "active"
    ACHIEVED = "achieved"
    ABANDONED = "abandoned"


class HabitFrequency(str, enum.Enum):
    DAILY = "daily"
    WEEKLY = "weekly"
    CUSTOM = "custom"


class Goal(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "goals"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[GoalStatus] = mapped_column(
        SqlEnum(
            GoalStatus,
            name="goal_status",
            native_enum=False,
            validate_strings=True,
            create_constraint=True,
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
        ),
        nullable=False,
        default=GoalStatus.ACTIVE,
        server_default=GoalStatus.ACTIVE.value,
        index=True,
    )
    target_date: Mapped[date | None] = mapped_column(Date, index=True, nullable=True)

    key_results: Mapped[list["KeyResult"]] = relationship(back_populates="goal", cascade="all, delete-orphan")


class KeyResult(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "key_results"

    goal_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("goals.id", ondelete="CASCADE"), index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    target_value: Mapped[float] = mapped_column(Float, nullable=False)
    current_value: Mapped[float] = mapped_column(Float, nullable=False, default=0.0, server_default="0")
    unit: Mapped[str] = mapped_column(String(64), nullable=False)

    goal: Mapped["Goal"] = relationship(back_populates="key_results")


class Habit(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "habits"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    frequency: Mapped[HabitFrequency] = mapped_column(
        SqlEnum(
            HabitFrequency,
            name="habit_frequency",
            native_enum=False,
            validate_strings=True,
            create_constraint=True,
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
        ),
        nullable=False,
        default=HabitFrequency.DAILY,
        server_default=HabitFrequency.DAILY.value,
    )
    target_count: Mapped[int] = mapped_column(Integer, nullable=False, default=1, server_default="1")
    is_archived: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, index=True, server_default="false"
    )

    logs: Mapped[list["HabitLog"]] = relationship(back_populates="habit", cascade="all, delete-orphan")


class HabitLog(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "habit_logs"
    __table_args__ = (UniqueConstraint("habit_id", "date"),)

    habit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("habits.id", ondelete="CASCADE"), index=True, nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    date: Mapped[date] = mapped_column(Date, index=True, nullable=False)
    count: Mapped[int] = mapped_column(Integer, nullable=False, default=1, server_default="1")

    habit: Mapped["Habit"] = relationship(back_populates="logs")


class JournalEntry(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "journal_entries"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    title: Mapped[str | None] = mapped_column(String(255), nullable=True)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    mood: Mapped[str | None] = mapped_column(String(64), nullable=True)
    entry_date: Mapped[date] = mapped_column(Date, index=True, nullable=False)


class Event(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "events"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True, nullable=False)
    end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True, nullable=False)
    location: Mapped[str | None] = mapped_column(String(255), nullable=True)

    time_blocks: Mapped[list["TimeBlock"]] = relationship(back_populates="event")


class TimeBlock(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "time_blocks"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True, nullable=False)
    end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True, nullable=False)
    task_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tasks.id", ondelete="SET NULL"), index=True, nullable=True
    )
    event_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("events.id", ondelete="SET NULL"), index=True, nullable=True
    )

    event: Mapped["Event | None"] = relationship(back_populates="time_blocks")


class DailyActivity(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "daily_activities"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    category: Mapped[str] = mapped_column(String(128), index=True, nullable=False)
    duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    activity_date: Mapped[date] = mapped_column(Date, index=True, nullable=False)