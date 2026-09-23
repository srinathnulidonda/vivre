# app/events.py
import uuid
from collections.abc import Awaitable, Callable
from datetime import date, datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict

from app.core.logging import get_logger

logger = get_logger(__name__)


class EventType(str, Enum):
    TASK_COMPLETED = "task.completed"
    HABIT_CHECKED_IN = "habit.checked_in"
    GOAL_ACHIEVED = "goal.achieved"
    MILESTONE_COMPLETED = "milestone.completed"


class EventPayload(BaseModel):
    model_config = ConfigDict(frozen=True)
    user_id: uuid.UUID


class TaskCompletedPayload(EventPayload):
    task_id: uuid.UUID
    task_title: str
    completed_at: datetime


class HabitCheckedInPayload(EventPayload):
    habit_id: uuid.UUID
    habit_name: str
    log_date: date


class GoalAchievedPayload(EventPayload):
    goal_id: uuid.UUID
    goal_title: str
    achieved_at: datetime


class MilestoneCompletedPayload(EventPayload):
    milestone_id: uuid.UUID
    project_id: uuid.UUID
    milestone_title: str
    completed_at: datetime


EventHandler = Callable[[EventPayload], Awaitable[None]]


class EventBus:
    def __init__(self) -> None:
        self._subscribers: dict[EventType, list[EventHandler]] = {}

    def subscribe(self, event_type: EventType, handler: EventHandler) -> None:
        self._subscribers.setdefault(event_type, []).append(handler)

    async def publish(self, event_type: EventType, payload: EventPayload) -> None:
        handlers = self._subscribers.get(event_type, [])
        for handler in handlers:
            try:
                await handler(payload)
            except Exception as exc:
                logger.error("event_handler_failed", event_type=event_type.value, error=str(exc))


event_bus = EventBus()