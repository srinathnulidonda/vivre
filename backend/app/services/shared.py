# app/services/shared.py
import uuid
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import func, literal, select, union_all
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.datastructures import UploadFile

from app.core.exceptions import ValidationError
from app.models.notes import Note
from app.models.personal import Event, Goal, Habit, JournalEntry, TimeBlock
from app.models.user import User
from app.models.work import Client, FocusSession, Project, Task
from app.schemas.shared import (
    SearchResponse,
    SearchResultItem,
    SearchResultType,
    TimelineItem,
    TimelineItemType,
    TimelineResponse,
)

_LIKE_ESCAPE_CHARACTER = "\\"


def _escape_like_pattern(value: str) -> str:
    return (
        value.replace(_LIKE_ESCAPE_CHARACTER, _LIKE_ESCAPE_CHARACTER * 2)
        .replace("%", f"{_LIKE_ESCAPE_CHARACTER}%")
        .replace("_", f"{_LIKE_ESCAPE_CHARACTER}_")
    )


def resolve_local_day_bounds(user_timezone: str, reference_date: date) -> tuple[datetime, datetime]:
    zone = ZoneInfo(user_timezone)
    local_start = datetime.combine(reference_date, time.min, tzinfo=zone)
    local_end = local_start + timedelta(days=1)
    return local_start.astimezone(timezone.utc), local_end.astimezone(timezone.utc)


async def read_upload_file_within_limit(file: UploadFile, max_bytes: int, chunk_size: int) -> bytes:
    buffer = bytearray()
    while True:
        chunk = await file.read(chunk_size)
        if not chunk:
            break
        buffer.extend(chunk)
        if len(buffer) > max_bytes:
            await file.close()
            raise ValidationError("Uploaded file exceeds the maximum allowed size")
    return bytes(buffer)


async def get_timeline(session: AsyncSession, user: User, timeline_date: date) -> TimelineResponse:
    day_start, day_end = resolve_local_day_bounds(user.timezone, timeline_date)

    events_result = await session.execute(
        select(Event).where(Event.user_id == user.id, Event.start_at < day_end, Event.end_at >= day_start)
    )
    time_blocks_result = await session.execute(
        select(TimeBlock).where(
            TimeBlock.user_id == user.id, TimeBlock.start_at < day_end, TimeBlock.end_at >= day_start
        )
    )
    tasks_result = await session.execute(
        select(Task).where(Task.user_id == user.id, Task.due_date >= day_start, Task.due_date < day_end)
    )
    focus_sessions_result = await session.execute(
        select(FocusSession).where(
            FocusSession.user_id == user.id,
            FocusSession.start_at >= day_start,
            FocusSession.start_at < day_end,
        )
    )

    items: list[TimelineItem] = []
    for event in events_result.scalars().all():
        items.append(
            TimelineItem(
                item_type=TimelineItemType.EVENT,
                id=event.id,
                title=event.title,
                start_at=event.start_at,
                end_at=event.end_at,
            )
        )
    for time_block in time_blocks_result.scalars().all():
        items.append(
            TimelineItem(
                item_type=TimelineItemType.TIME_BLOCK,
                id=time_block.id,
                title=time_block.title,
                start_at=time_block.start_at,
                end_at=time_block.end_at,
            )
        )
    for task in tasks_result.scalars().all():
        items.append(
            TimelineItem(
                item_type=TimelineItemType.TASK,
                id=task.id,
                title=task.title,
                start_at=task.due_date,
                end_at=task.due_date,
            )
        )
    for focus_session in focus_sessions_result.scalars().all():
        items.append(
            TimelineItem(
                item_type=TimelineItemType.FOCUS_SESSION,
                id=focus_session.id,
                title="Focus session",
                start_at=focus_session.start_at,
                end_at=focus_session.end_at,
            )
        )
    items.sort(key=lambda item: item.start_at or datetime.min.replace(tzinfo=timezone.utc))
    return TimelineResponse(timeline_date=timeline_date, items=items)


async def search_all(
    session: AsyncSession, user_id: uuid.UUID, query: str, limit: int, offset: int
) -> SearchResponse:
    escaped_query = _escape_like_pattern(query)
    pattern = f"%{escaped_query}%"
    like_kwargs = {"escape": _LIKE_ESCAPE_CHARACTER}

    note_select = select(
        literal(SearchResultType.NOTE.value).label("result_type"), Note.id.label("id"), Note.title.label("title")
    ).where(Note.user_id == user_id, Note.title.ilike(pattern, **like_kwargs))

    project_select = select(
        literal(SearchResultType.PROJECT.value).label("result_type"),
        Project.id.label("id"),
        Project.name.label("title"),
    ).where(Project.user_id == user_id, Project.name.ilike(pattern, **like_kwargs))

    task_select = select(
        literal(SearchResultType.TASK.value).label("result_type"), Task.id.label("id"), Task.title.label("title")
    ).where(Task.user_id == user_id, Task.title.ilike(pattern, **like_kwargs))

    goal_select = select(
        literal(SearchResultType.GOAL.value).label("result_type"), Goal.id.label("id"), Goal.title.label("title")
    ).where(Goal.user_id == user_id, Goal.title.ilike(pattern, **like_kwargs))

    habit_select = select(
        literal(SearchResultType.HABIT.value).label("result_type"), Habit.id.label("id"), Habit.name.label("title")
    ).where(Habit.user_id == user_id, Habit.name.ilike(pattern, **like_kwargs))

    journal_select = select(
        literal(SearchResultType.JOURNAL_ENTRY.value).label("result_type"),
        JournalEntry.id.label("id"),
        func.coalesce(JournalEntry.title, func.substr(JournalEntry.content, 1, 80)).label("title"),
    ).where(JournalEntry.user_id == user_id, JournalEntry.content.ilike(pattern, **like_kwargs))

    event_select = select(
        literal(SearchResultType.EVENT.value).label("result_type"), Event.id.label("id"), Event.title.label("title")
    ).where(Event.user_id == user_id, Event.title.ilike(pattern, **like_kwargs))

    client_select = select(
        literal(SearchResultType.CLIENT.value).label("result_type"), Client.id.label("id"), Client.name.label("title")
    ).where(Client.user_id == user_id, Client.name.ilike(pattern, **like_kwargs))

    unioned = union_all(
        note_select,
        project_select,
        task_select,
        goal_select,
        habit_select,
        journal_select,
        event_select,
        client_select,
    ).subquery()

    total_result = await session.execute(select(func.count()).select_from(unioned))
    total = total_result.scalar_one()

    paginated_result = await session.execute(
        select(unioned.c.result_type, unioned.c.id, unioned.c.title)
        .order_by(unioned.c.title.asc())
        .limit(limit)
        .offset(offset)
    )
    results = [
        SearchResultItem(result_type=SearchResultType(row.result_type), id=row.id, title=row.title)
        for row in paginated_result.all()
    ]
    return SearchResponse(query=query, results=results, total=total, limit=limit, offset=offset)