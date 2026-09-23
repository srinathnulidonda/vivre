# app/services/ai.py
import asyncio
import json
from datetime import datetime
from typing import Any
from zoneinfo import ZoneInfo

from sqlalchemy.ext.asyncio import AsyncSession

from app.integrations.ai import generate_chat_completion
from app.models.user import User
from app.schemas.ai import (
    AICaptureResponse,
    AICaptureResultType,
    AIChatMessage,
    AIChatResponse,
    AIPlanResponse,
    AIPlanStep,
)
from app.schemas.health import HealthContextSummary
from app.schemas.notes import NoteCreateRequest
from app.schemas.personal import HabitLogCreateRequest, JournalEntryCreateRequest
from app.schemas.work import TaskCreateRequest
from app.services.health import get_health_context_summary
from app.services.notes import create_note
from app.services.personal import create_journal_entry, find_habit_by_name, log_habit_checkin
from app.services.work import create_task

_CAPTURE_CLASSIFICATION_PROMPT = (
    "Classify the following captured text into exactly one of: note, task, journal_entry, habit_log. "
    "Respond with strict JSON only, no prose, matching this shape: "
    '{"result_type": "note|task|journal_entry|habit_log", "title": "short title", '
    '"habit_name": "name of habit if result_type is habit_log else null"}'
)

_PLAN_PROMPT = (
    "Break the following objective into three to seven concrete, ordered steps. "
    "Respond with strict JSON only, no prose, matching this shape: "
    '{"steps": [{"title": "short title", "description": "one sentence detail"}]}'
)


def _build_context_suffix(health_summary: HealthContextSummary) -> str:
    return (
        "Contextual signals for this user (informational only, never diagnostic): "
        f"steps_today={health_summary.steps_count}, sleep_hours_last_night={health_summary.sleep_hours}, "
        f"recent_workouts_7d={health_summary.recent_workouts_count}."
    )


async def chat_with_ai(
    session: AsyncSession, user: User, messages: list[AIChatMessage]
) -> AIChatResponse:
    today = datetime.now(ZoneInfo(user.timezone)).date()
    health_summary = await get_health_context_summary(session, user, today)
    context_suffix = _build_context_suffix(health_summary)
    provider_messages = [{"role": message.role, "content": message.content} for message in messages]
    reply = await asyncio.to_thread(generate_chat_completion, provider_messages, context_suffix)
    return AIChatResponse(reply=reply)


async def capture_from_text(session: AsyncSession, user: User, raw_text: str) -> AICaptureResponse:
    completion = await asyncio.to_thread(
        generate_chat_completion,
        [{"role": "user", "content": f"{_CAPTURE_CLASSIFICATION_PROMPT}\n\nText: {raw_text}"}],
    )
    classification: dict[str, Any] = {}
    try:
        parsed = json.loads(completion)
        if isinstance(parsed, dict):
            classification = parsed
    except json.JSONDecodeError:
        classification = {}

    try:
        result_type = AICaptureResultType(classification.get("result_type", "note"))
    except ValueError:
        result_type = AICaptureResultType.NOTE
    title = str(classification.get("title") or raw_text[:80])

    today = datetime.now(ZoneInfo(user.timezone)).date()

    if result_type == AICaptureResultType.TASK:
        task = await create_task(session, user.id, TaskCreateRequest(title=title))
        return AICaptureResponse(result_type=AICaptureResultType.TASK, result_id=task.id, summary=task.title)

    if result_type == AICaptureResultType.JOURNAL_ENTRY:
        journal_entry = await create_journal_entry(
            session, user.id, JournalEntryCreateRequest(title=title, content=raw_text, entry_date=today)
        )
        return AICaptureResponse(
            result_type=AICaptureResultType.JOURNAL_ENTRY, result_id=journal_entry.id, summary=title
        )

    if result_type == AICaptureResultType.HABIT_LOG:
        habit_name = str(classification.get("habit_name") or "")
        habit = await find_habit_by_name(session, user.id, habit_name) if habit_name else None
        if habit is not None:
            habit_log = await log_habit_checkin(
                session, user.id, habit.id, HabitLogCreateRequest(log_date=today)
            )
            return AICaptureResponse(
                result_type=AICaptureResultType.HABIT_LOG, result_id=habit_log.id, summary=habit.name
            )
        note = await create_note(session, user.id, NoteCreateRequest(title=title, content=raw_text))
        return AICaptureResponse(result_type=AICaptureResultType.NOTE, result_id=note.id, summary=note.title)

    note = await create_note(session, user.id, NoteCreateRequest(title=title, content=raw_text))
    return AICaptureResponse(result_type=AICaptureResultType.NOTE, result_id=note.id, summary=note.title)


async def plan_from_objective(
    session: AsyncSession, user: User, objective: str, context: str | None
) -> AIPlanResponse:
    prompt_body = f"{_PLAN_PROMPT}\n\nObjective: {objective}"
    if context:
        prompt_body += f"\n\nAdditional context: {context}"
    completion = await asyncio.to_thread(
        generate_chat_completion, [{"role": "user", "content": prompt_body}]
    )
    try:
        parsed = json.loads(completion)
        raw_steps = parsed.get("steps", [])
        steps = [
            AIPlanStep(title=str(step["title"]), description=step.get("description"))
            for step in raw_steps
        ]
        if not steps:
            raise ValueError("empty steps")
    except (json.JSONDecodeError, ValueError, KeyError):
        steps = [AIPlanStep(title=objective[:255], description=None)]
    return AIPlanResponse(steps=steps)