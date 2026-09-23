# app/services/personal.py
import uuid
from datetime import date, datetime, timezone

from sqlalchemy import func, literal_column, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import NotFoundError, PermissionDeniedError, ValidationError
from app.events import EventType, GoalAchievedPayload, HabitCheckedInPayload, event_bus
from app.models.personal import (
    DailyActivity,
    Event,
    Goal,
    GoalStatus,
    Habit,
    HabitLog,
    JournalEntry,
    KeyResult,
    TimeBlock,
)
from app.schemas.personal import (
    DailyActivityCreateRequest,
    DailyActivityUpdateRequest,
    EventCreateRequest,
    EventUpdateRequest,
    GoalCreateRequest,
    GoalUpdateRequest,
    HabitCreateRequest,
    HabitLogCreateRequest,
    HabitUpdateRequest,
    JournalEntryCreateRequest,
    JournalEntryUpdateRequest,
    KeyResultCreateRequest,
    KeyResultUpdateRequest,
    TimeBlockCreateRequest,
    TimeBlockUpdateRequest,
)
from app.schemas.shared import PaginationParams

_NULLABLE_GOAL_FIELDS = frozenset({"description", "target_date"})
_NULLABLE_HABIT_FIELDS = frozenset()
_NULLABLE_JOURNAL_FIELDS = frozenset({"title", "mood"})
_NULLABLE_EVENT_FIELDS = frozenset({"description", "location"})
_NULLABLE_TIME_BLOCK_FIELDS = frozenset({"task_id", "event_id"})
_NULLABLE_DAILY_ACTIVITY_FIELDS = frozenset({"duration_minutes"})


def _apply_updates(entity, update_fields: dict, nullable_fields: frozenset[str]) -> None:
    for field_name, field_value in update_fields.items():
        if field_value is None and field_name not in nullable_fields:
            continue
        setattr(entity, field_name, field_value)


async def _get_owned_goal(session: AsyncSession, user_id: uuid.UUID, goal_id: uuid.UUID) -> Goal:
    goal = await session.get(Goal, goal_id)
    if goal is None:
        raise NotFoundError("Goal not found")
    if goal.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this goal")
    return goal


async def _get_owned_key_result(
    session: AsyncSession, user_id: uuid.UUID, key_result_id: uuid.UUID
) -> KeyResult:
    key_result = await session.get(KeyResult, key_result_id)
    if key_result is None:
        raise NotFoundError("Key result not found")
    goal = await session.get(Goal, key_result.goal_id)
    if goal is None or goal.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this key result")
    return key_result


async def _get_owned_habit(
    session: AsyncSession, user_id: uuid.UUID, habit_id: uuid.UUID
) -> Habit:
    habit = await session.get(Habit, habit_id)
    if habit is None:
        raise NotFoundError("Habit not found")
    if habit.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this habit")
    return habit


async def _get_owned_journal_entry(
    session: AsyncSession, user_id: uuid.UUID, entry_id: uuid.UUID
) -> JournalEntry:
    entry = await session.get(JournalEntry, entry_id)
    if entry is None:
        raise NotFoundError("Journal entry not found")
    if entry.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this journal entry")
    return entry


async def _get_owned_event(session: AsyncSession, user_id: uuid.UUID, event_id: uuid.UUID) -> Event:
    event = await session.get(Event, event_id)
    if event is None:
        raise NotFoundError("Event not found")
    if event.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this event")
    return event


async def _get_owned_time_block(
    session: AsyncSession, user_id: uuid.UUID, time_block_id: uuid.UUID
) -> TimeBlock:
    time_block = await session.get(TimeBlock, time_block_id)
    if time_block is None:
        raise NotFoundError("Time block not found")
    if time_block.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this time block")
    return time_block


async def _get_owned_daily_activity(
    session: AsyncSession, user_id: uuid.UUID, activity_id: uuid.UUID
) -> DailyActivity:
    activity = await session.get(DailyActivity, activity_id)
    if activity is None:
        raise NotFoundError("Daily activity not found")
    if activity.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this activity")
    return activity


async def create_goal(session: AsyncSession, user_id: uuid.UUID, request: GoalCreateRequest) -> Goal:
    goal = Goal(
        user_id=user_id,
        title=request.title,
        description=request.description,
        target_date=request.target_date,
    )
    session.add(goal)
    await session.commit()
    await session.refresh(goal)
    return goal


async def update_goal(
    session: AsyncSession, user_id: uuid.UUID, goal_id: uuid.UUID, request: GoalUpdateRequest
) -> Goal:
    goal = await _get_owned_goal(session, user_id, goal_id)
    update_fields = request.model_dump(exclude_unset=True)
    new_status = update_fields.get("status")
    newly_achieved = (
        new_status == GoalStatus.ACHIEVED and goal.status != GoalStatus.ACHIEVED
    )
    _apply_updates(goal, update_fields, _NULLABLE_GOAL_FIELDS)
    await session.commit()
    await session.refresh(goal)
    if newly_achieved:
        await event_bus.publish(
            EventType.GOAL_ACHIEVED,
            GoalAchievedPayload(
                user_id=user_id,
                goal_id=goal.id,
                goal_title=goal.title,
                achieved_at=datetime.now(timezone.utc),
            ),
        )
    return goal


async def delete_goal(session: AsyncSession, user_id: uuid.UUID, goal_id: uuid.UUID) -> None:
    goal = await _get_owned_goal(session, user_id, goal_id)
    await session.delete(goal)
    await session.commit()


async def list_goals(
    session: AsyncSession,
    user_id: uuid.UUID,
    pagination: PaginationParams,
    status: GoalStatus | None = None,
) -> tuple[list[Goal], int]:
    filters = [Goal.user_id == user_id]
    if status is not None:
        filters.append(Goal.status == status)
    count_result = await session.execute(select(func.count()).select_from(Goal).where(*filters))
    total = count_result.scalar_one()
    result = await session.execute(
        select(Goal)
        .where(*filters)
        .order_by(Goal.created_at.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def get_goal_detail(session: AsyncSession, user_id: uuid.UUID, goal_id: uuid.UUID) -> Goal:
    result = await session.execute(
        select(Goal).options(selectinload(Goal.key_results)).where(Goal.id == goal_id)
    )
    goal = result.scalar_one_or_none()
    if goal is None:
        raise NotFoundError("Goal not found")
    if goal.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this goal")
    return goal


async def create_key_result(
    session: AsyncSession, user_id: uuid.UUID, goal_id: uuid.UUID, request: KeyResultCreateRequest
) -> KeyResult:
    await _get_owned_goal(session, user_id, goal_id)
    key_result = KeyResult(
        goal_id=goal_id,
        title=request.title,
        target_value=request.target_value,
        current_value=request.current_value,
        unit=request.unit,
    )
    session.add(key_result)
    await session.commit()
    await session.refresh(key_result)
    return key_result


async def update_key_result(
    session: AsyncSession,
    user_id: uuid.UUID,
    key_result_id: uuid.UUID,
    request: KeyResultUpdateRequest,
) -> KeyResult:
    key_result = await _get_owned_key_result(session, user_id, key_result_id)
    _apply_updates(key_result, request.model_dump(exclude_unset=True), frozenset())
    await session.commit()
    await session.refresh(key_result)
    return key_result


async def delete_key_result(
    session: AsyncSession, user_id: uuid.UUID, key_result_id: uuid.UUID
) -> None:
    key_result = await _get_owned_key_result(session, user_id, key_result_id)
    await session.delete(key_result)
    await session.commit()


async def create_habit(
    session: AsyncSession, user_id: uuid.UUID, request: HabitCreateRequest
) -> Habit:
    habit = Habit(
        user_id=user_id,
        name=request.name,
        frequency=request.frequency,
        target_count=request.target_count,
    )
    session.add(habit)
    await session.commit()
    await session.refresh(habit)
    return habit


async def update_habit(
    session: AsyncSession, user_id: uuid.UUID, habit_id: uuid.UUID, request: HabitUpdateRequest
) -> Habit:
    habit = await _get_owned_habit(session, user_id, habit_id)
    _apply_updates(habit, request.model_dump(exclude_unset=True), _NULLABLE_HABIT_FIELDS)
    await session.commit()
    await session.refresh(habit)
    return habit


async def delete_habit(session: AsyncSession, user_id: uuid.UUID, habit_id: uuid.UUID) -> None:
    habit = await _get_owned_habit(session, user_id, habit_id)
    await session.delete(habit)
    await session.commit()


async def list_habits(
    session: AsyncSession,
    user_id: uuid.UUID,
    pagination: PaginationParams,
    include_archived: bool = False,
) -> tuple[list[Habit], int]:
    filters = [Habit.user_id == user_id]
    if not include_archived:
        filters.append(Habit.is_archived.is_(False))
    count_result = await session.execute(select(func.count()).select_from(Habit).where(*filters))
    total = count_result.scalar_one()
    result = await session.execute(
        select(Habit)
        .where(*filters)
        .order_by(Habit.name.asc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def find_habit_by_name(
    session: AsyncSession, user_id: uuid.UUID, name: str
) -> Habit | None:
    result = await session.execute(
        select(Habit).where(
            Habit.user_id == user_id,
            Habit.is_archived.is_(False),
            func.lower(Habit.name) == name.lower(),
        )
    )
    return result.scalar_one_or_none()


async def log_habit_checkin(
    session: AsyncSession, user_id: uuid.UUID, habit_id: uuid.UUID, request: HabitLogCreateRequest
) -> HabitLog:
    habit = await _get_owned_habit(session, user_id, habit_id)
    insert_stmt = (
        pg_insert(HabitLog)
        .values(
            id=uuid.uuid4(),
            habit_id=habit_id,
            user_id=user_id,
            date=request.log_date,
            count=request.count,
        )
        .on_conflict_do_nothing(index_elements=[HabitLog.habit_id, HabitLog.date])
        .returning(HabitLog)
    )
    result = await session.execute(insert_stmt)
    habit_log = result.scalar_one_or_none()
    if habit_log is not None:
        await session.commit()
        await event_bus.publish(
            EventType.HABIT_CHECKED_IN,
            HabitCheckedInPayload(
                user_id=user_id,
                habit_id=habit.id,
                habit_name=habit.name,
                log_date=request.log_date,
            ),
        )
        return habit_log
    update_stmt = (
        update(HabitLog)
        .where(HabitLog.habit_id == habit_id, HabitLog.date == request.log_date)
        .values(count=request.count, updated_at=func.now())
        .returning(HabitLog)
    )
    update_result = await session.execute(update_stmt)
    existing_log = update_result.scalar_one()
    await session.commit()
    return existing_log


async def list_habit_logs(
    session: AsyncSession,
    user_id: uuid.UUID,
    habit_id: uuid.UUID,
    pagination: PaginationParams,
) -> tuple[list[HabitLog], int]:
    await _get_owned_habit(session, user_id, habit_id)
    count_result = await session.execute(
        select(func.count()).select_from(HabitLog).where(HabitLog.habit_id == habit_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(HabitLog)
        .where(HabitLog.habit_id == habit_id)
        .order_by(HabitLog.date.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def compute_habit_streak(
    session: AsyncSession, user_id: uuid.UUID, habit_id: uuid.UUID
) -> int:
    await _get_owned_habit(session, user_id, habit_id)
    latest_result = await session.execute(
        select(HabitLog.date)
        .where(HabitLog.habit_id == habit_id)
        .order_by(HabitLog.date.desc())
        .limit(1)
    )
    latest_date = latest_result.scalar_one_or_none()
    if latest_date is None:
        return 0
    streak_cte = (
        select(HabitLog.date.label("log_date"))
        .where(HabitLog.habit_id == habit_id, HabitLog.date == latest_date)
        .cte(name="habit_streak", recursive=True)
    )
    streak_alias = streak_cte.alias()
    streak_cte = streak_cte.union(
        select(HabitLog.date.label("log_date"))
        .join(streak_alias, HabitLog.date == streak_alias.c.log_date - literal_column("1"))
        .where(HabitLog.habit_id == habit_id)
    )
    count_result = await session.execute(select(func.count()).select_from(streak_cte))
    return count_result.scalar_one()


async def create_journal_entry(
    session: AsyncSession, user_id: uuid.UUID, request: JournalEntryCreateRequest
) -> JournalEntry:
    entry = JournalEntry(
        user_id=user_id,
        title=request.title,
        content=request.content,
        mood=request.mood,
        entry_date=request.entry_date,
    )
    session.add(entry)
    await session.commit()
    await session.refresh(entry)
    return entry


async def update_journal_entry(
    session: AsyncSession,
    user_id: uuid.UUID,
    entry_id: uuid.UUID,
    request: JournalEntryUpdateRequest,
) -> JournalEntry:
    entry = await _get_owned_journal_entry(session, user_id, entry_id)
    _apply_updates(entry, request.model_dump(exclude_unset=True), _NULLABLE_JOURNAL_FIELDS)
    await session.commit()
    await session.refresh(entry)
    return entry


async def delete_journal_entry(
    session: AsyncSession, user_id: uuid.UUID, entry_id: uuid.UUID
) -> None:
    entry = await _get_owned_journal_entry(session, user_id, entry_id)
    await session.delete(entry)
    await session.commit()


async def list_journal_entries(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[JournalEntry], int]:
    count_result = await session.execute(
        select(func.count()).select_from(JournalEntry).where(JournalEntry.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(JournalEntry)
        .where(JournalEntry.user_id == user_id)
        .order_by(JournalEntry.entry_date.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def create_event(
    session: AsyncSession, user_id: uuid.UUID, request: EventCreateRequest
) -> Event:
    if request.end_at <= request.start_at:
        raise ValidationError("Event end time must be after start time")
    event = Event(
        user_id=user_id,
        title=request.title,
        description=request.description,
        start_at=request.start_at,
        end_at=request.end_at,
        location=request.location,
    )
    session.add(event)
    await session.commit()
    await session.refresh(event)
    return event


async def update_event(
    session: AsyncSession, user_id: uuid.UUID, event_id: uuid.UUID, request: EventUpdateRequest
) -> Event:
    event = await _get_owned_event(session, user_id, event_id)
    _apply_updates(event, request.model_dump(exclude_unset=True), _NULLABLE_EVENT_FIELDS)
    if event.end_at <= event.start_at:
        raise ValidationError("Event end time must be after start time")
    await session.commit()
    await session.refresh(event)
    return event


async def delete_event(session: AsyncSession, user_id: uuid.UUID, event_id: uuid.UUID) -> None:
    event = await _get_owned_event(session, user_id, event_id)
    await session.delete(event)
    await session.commit()


async def list_events(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[Event], int]:
    count_result = await session.execute(
        select(func.count()).select_from(Event).where(Event.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(Event)
        .where(Event.user_id == user_id)
        .order_by(Event.start_at.asc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def create_time_block(
    session: AsyncSession, user_id: uuid.UUID, request: TimeBlockCreateRequest
) -> TimeBlock:
    if request.end_at <= request.start_at:
        raise ValidationError("Time block end must be after start")
    time_block = TimeBlock(
        user_id=user_id,
        title=request.title,
        start_at=request.start_at,
        end_at=request.end_at,
        task_id=request.task_id,
        event_id=request.event_id,
    )
    session.add(time_block)
    await session.commit()
    await session.refresh(time_block)
    return time_block


async def update_time_block(
    session: AsyncSession,
    user_id: uuid.UUID,
    time_block_id: uuid.UUID,
    request: TimeBlockUpdateRequest,
) -> TimeBlock:
    time_block = await _get_owned_time_block(session, user_id, time_block_id)
    _apply_updates(
        time_block, request.model_dump(exclude_unset=True), _NULLABLE_TIME_BLOCK_FIELDS
    )
    if time_block.end_at <= time_block.start_at:
        raise ValidationError("Time block end must be after start")
    await session.commit()
    await session.refresh(time_block)
    return time_block


async def delete_time_block(
    session: AsyncSession, user_id: uuid.UUID, time_block_id: uuid.UUID
) -> None:
    time_block = await _get_owned_time_block(session, user_id, time_block_id)
    await session.delete(time_block)
    await session.commit()


async def list_time_blocks(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[TimeBlock], int]:
    count_result = await session.execute(
        select(func.count()).select_from(TimeBlock).where(TimeBlock.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(TimeBlock)
        .where(TimeBlock.user_id == user_id)
        .order_by(TimeBlock.start_at.asc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def create_daily_activity(
    session: AsyncSession, user_id: uuid.UUID, request: DailyActivityCreateRequest
) -> DailyActivity:
    activity = DailyActivity(
        user_id=user_id,
        title=request.title,
        category=request.category,
        duration_minutes=request.duration_minutes,
        activity_date=request.activity_date,
    )
    session.add(activity)
    await session.commit()
    await session.refresh(activity)
    return activity


async def update_daily_activity(
    session: AsyncSession,
    user_id: uuid.UUID,
    activity_id: uuid.UUID,
    request: DailyActivityUpdateRequest,
) -> DailyActivity:
    activity = await _get_owned_daily_activity(session, user_id, activity_id)
    _apply_updates(
        activity, request.model_dump(exclude_unset=True), _NULLABLE_DAILY_ACTIVITY_FIELDS
    )
    await session.commit()
    await session.refresh(activity)
    return activity


async def delete_daily_activity(
    session: AsyncSession, user_id: uuid.UUID, activity_id: uuid.UUID
) -> None:
    activity = await _get_owned_daily_activity(session, user_id, activity_id)
    await session.delete(activity)
    await session.commit()


async def list_daily_activities(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[DailyActivity], int]:
    count_result = await session.execute(
        select(func.count()).select_from(DailyActivity).where(DailyActivity.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(DailyActivity)
        .where(DailyActivity.user_id == user_id)
        .order_by(DailyActivity.activity_date.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total