# app/schemas/ai.py
import uuid
from enum import Enum
from typing import Literal

from pydantic import BaseModel, Field


class AIChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=8000)


class AIChatRequest(BaseModel):
    messages: list[AIChatMessage] = Field(min_length=1, max_length=50)


class AIChatResponse(BaseModel):
    reply: str


class AICaptureRequest(BaseModel):
    raw_text: str = Field(min_length=1, max_length=4000)


class AICaptureResultType(str, Enum):
    NOTE = "note"
    TASK = "task"
    HABIT_LOG = "habit_log"
    JOURNAL_ENTRY = "journal_entry"

class AICaptureResponse(BaseModel):
    result_type: AICaptureResultType
    result_id: uuid.UUID
    summary: str


class AIPlanRequest(BaseModel):
    objective: str = Field(min_length=1, max_length=2000)
    context: str | None = Field(default=None, max_length=4000)


class AIPlanStep(BaseModel):
    title: str
    description: str | None = None


class AIPlanResponse(BaseModel):
    steps: list[AIPlanStep]