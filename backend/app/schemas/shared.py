# app/schemas/shared.py
import uuid
from datetime import date, datetime
from enum import Enum
from typing import Any, Generic, TypeVar

from fastapi import Query
from pydantic import BaseModel, ConfigDict

from app.core.config import get_settings

_settings = get_settings()

T = TypeVar("T")


class ErrorDetail(BaseModel):
    code: str
    message: str


class ErrorResponse(BaseModel):
    error: ErrorDetail


class PaginationParams(BaseModel):
    limit: int
    offset: int


def pagination_params(
    limit: int = Query(default=_settings.DEFAULT_PAGE_SIZE, ge=1, le=_settings.MAX_PAGE_SIZE),
    offset: int = Query(default=0, ge=0),
) -> PaginationParams:
    return PaginationParams(limit=limit, offset=offset)


class PaginatedResponse(BaseModel, Generic[T]):
    items: list[T]
    total: int
    limit: int
    offset: int


class LivenessResponse(BaseModel):
    status: str


class ReadinessResponse(BaseModel):
    status: str
    database: bool
    redis: bool


class TimelineItemType(str, Enum):
    EVENT = "event"
    TIME_BLOCK = "time_block"
    TASK = "task"
    FOCUS_SESSION = "focus_session"


class TimelineItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    item_type: TimelineItemType
    id: uuid.UUID
    title: str
    start_at: datetime | None
    end_at: datetime | None
    item_metadata: dict[str, Any] | None = None


class TimelineResponse(BaseModel):
    timeline_date: date
    items: list[TimelineItem]


class SearchResultType(str, Enum):
    NOTE = "note"
    PROJECT = "project"
    TASK = "task"
    GOAL = "goal"
    HABIT = "habit"
    JOURNAL_ENTRY = "journal_entry"
    EVENT = "event"
    CLIENT = "client"


class SearchResultItem(BaseModel):
    result_type: SearchResultType
    id: uuid.UUID
    title: str
    snippet: str | None = None


class SearchResponse(BaseModel):
    query: str
    results: list[SearchResultItem]
    total: int
    limit: int
    offset: int

class MessageResponse(BaseModel):
    message: str