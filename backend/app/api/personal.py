# app/api/personal.py
import uuid

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.personal import GoalStatus
from app.models.user import User
from app.schemas.personal import (
    DailyActivityCreateRequest,
    DailyActivityRead,
    DailyActivityUpdateRequest,
    EventCreateRequest,
    EventRead,
    EventUpdateRequest,
    GoalCreateRequest,
    GoalDetailRead,
    GoalRead,
    GoalUpdateRequest,
    HabitCreateRequest,
    HabitLogCreateRequest,
    HabitLogRead,
    HabitRead,
    HabitStreakResponse,
    HabitUpdateRequest,
    JournalEntryCreateRequest,
    JournalEntryRead,
    JournalEntryUpdateRequest,
    KeyResultCreateRequest,
    KeyResultRead,
    KeyResultUpdateRequest,
    TimeBlockCreateRequest,
    TimeBlockRead,
    TimeBlockUpdateRequest,
)
from app.schemas.shared import PaginatedResponse, PaginationParams, pagination_params
from app.services import personal as personal_service

router = APIRouter(prefix="/personal", tags=["personal"])


@router.post("/goals", response_model=GoalRead, status_code=status.HTTP_201_CREATED)
async def create_goal(
    payload: GoalCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> GoalRead:
    goal = await personal_service.create_goal(session, current_user.id, payload)
    return GoalRead.model_validate(goal)


@router.get("/goals", response_model=PaginatedResponse[GoalRead], status_code=status.HTTP_200_OK)
async def list_goals(
    status_filter: GoalStatus | None = Query(default=None, alias="status"),
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[GoalRead]:
    goals, total = await personal_service.list_goals(session, current_user.id, pagination, status=status_filter)
    return PaginatedResponse(items=goals, total=total, limit=pagination.limit, offset=pagination.offset)


@router.get("/goals/{goal_id}", response_model=GoalDetailRead, status_code=status.HTTP_200_OK)
async def get_goal_detail(
    goal_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> GoalDetailRead:
    goal = await personal_service.get_goal_detail(session, current_user.id, goal_id)
    return GoalDetailRead(
        id=goal.id,
        title=goal.title,
        description=goal.description,
        status=goal.status,
        target_date=goal.target_date,
        created_at=goal.created_at,
        key_results=[KeyResultRead.model_validate(key_result) for key_result in goal.key_results],
    )


@router.patch("/goals/{goal_id}", response_model=GoalRead, status_code=status.HTTP_200_OK)
async def update_goal(
    goal_id: uuid.UUID,
    payload: GoalUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> GoalRead:
    goal = await personal_service.update_goal(session, current_user.id, goal_id, payload)
    return GoalRead.model_validate(goal)


@router.delete("/goals/{goal_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_goal(
    goal_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await personal_service.delete_goal(session, current_user.id, goal_id)


@router.post("/goals/{goal_id}/key-results", response_model=KeyResultRead, status_code=status.HTTP_201_CREATED)
async def create_key_result(
    goal_id: uuid.UUID,
    payload: KeyResultCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> KeyResultRead:
    key_result = await personal_service.create_key_result(session, current_user.id, goal_id, payload)
    return KeyResultRead.model_validate(key_result)


@router.patch("/key-results/{key_result_id}", response_model=KeyResultRead, status_code=status.HTTP_200_OK)
async def update_key_result(
    key_result_id: uuid.UUID,
    payload: KeyResultUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> KeyResultRead:
    key_result = await personal_service.update_key_result(session, current_user.id, key_result_id, payload)
    return KeyResultRead.model_validate(key_result)


@router.delete("/key-results/{key_result_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_key_result(
    key_result_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await personal_service.delete_key_result(session, current_user.id, key_result_id)


@router.post("/habits", response_model=HabitRead, status_code=status.HTTP_201_CREATED)
async def create_habit(
    payload: HabitCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> HabitRead:
    habit = await personal_service.create_habit(session, current_user.id, payload)
    return HabitRead.model_validate(habit)


@router.get("/habits", response_model=PaginatedResponse[HabitRead], status_code=status.HTTP_200_OK)
async def list_habits(
    include_archived: bool = Query(default=False),
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[HabitRead]:
    habits, total = await personal_service.list_habits(session, current_user.id, pagination, include_archived=include_archived)
    return PaginatedResponse(items=habits, total=total, limit=pagination.limit, offset=pagination.offset)


@router.patch("/habits/{habit_id}", response_model=HabitRead, status_code=status.HTTP_200_OK)
async def update_habit(
    habit_id: uuid.UUID,
    payload: HabitUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> HabitRead:
    habit = await personal_service.update_habit(session, current_user.id, habit_id, payload)
    return HabitRead.model_validate(habit)


@router.delete("/habits/{habit_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_habit(
    habit_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await personal_service.delete_habit(session, current_user.id, habit_id)


@router.post("/habits/{habit_id}/logs", response_model=HabitLogRead, status_code=status.HTTP_201_CREATED)
async def log_habit_checkin(
    habit_id: uuid.UUID,
    payload: HabitLogCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> HabitLogRead:
    habit_log = await personal_service.log_habit_checkin(session, current_user.id, habit_id, payload)
    return HabitLogRead.model_validate(habit_log)


@router.get("/habits/{habit_id}/logs", response_model=PaginatedResponse[HabitLogRead], status_code=status.HTTP_200_OK)
async def list_habit_logs(
    habit_id: uuid.UUID,
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[HabitLogRead]:
    logs, total = await personal_service.list_habit_logs(session, current_user.id, habit_id, pagination)
    return PaginatedResponse(items=logs, total=total, limit=pagination.limit, offset=pagination.offset)


@router.get("/habits/{habit_id}/streak", response_model=HabitStreakResponse, status_code=status.HTTP_200_OK)
async def get_habit_streak(
    habit_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> HabitStreakResponse:
    streak = await personal_service.compute_habit_streak(session, current_user.id, habit_id)
    return HabitStreakResponse(streak=streak)


@router.post("/journal", response_model=JournalEntryRead, status_code=status.HTTP_201_CREATED)
async def create_journal_entry(
    payload: JournalEntryCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> JournalEntryRead:
    entry = await personal_service.create_journal_entry(session, current_user.id, payload)
    return JournalEntryRead.model_validate(entry)


@router.get("/journal", response_model=PaginatedResponse[JournalEntryRead], status_code=status.HTTP_200_OK)
async def list_journal_entries(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[JournalEntryRead]:
    entries, total = await personal_service.list_journal_entries(session, current_user.id, pagination)
    return PaginatedResponse(items=entries, total=total, limit=pagination.limit, offset=pagination.offset)


@router.patch("/journal/{entry_id}", response_model=JournalEntryRead, status_code=status.HTTP_200_OK)
async def update_journal_entry(
    entry_id: uuid.UUID,
    payload: JournalEntryUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> JournalEntryRead:
    entry = await personal_service.update_journal_entry(session, current_user.id, entry_id, payload)
    return JournalEntryRead.model_validate(entry)


@router.delete("/journal/{entry_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_journal_entry(
    entry_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await personal_service.delete_journal_entry(session, current_user.id, entry_id)


@router.post("/events", response_model=EventRead, status_code=status.HTTP_201_CREATED)
async def create_event(
    payload: EventCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> EventRead:
    event = await personal_service.create_event(session, current_user.id, payload)
    return EventRead.model_validate(event)


@router.get("/events", response_model=PaginatedResponse[EventRead], status_code=status.HTTP_200_OK)
async def list_events(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[EventRead]:
    events, total = await personal_service.list_events(session, current_user.id, pagination)
    return PaginatedResponse(items=events, total=total, limit=pagination.limit, offset=pagination.offset)


@router.patch("/events/{event_id}", response_model=EventRead, status_code=status.HTTP_200_OK)
async def update_event(
    event_id: uuid.UUID,
    payload: EventUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> EventRead:
    event = await personal_service.update_event(session, current_user.id, event_id, payload)
    return EventRead.model_validate(event)


@router.delete("/events/{event_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_event(
    event_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await personal_service.delete_event(session, current_user.id, event_id)


@router.post("/time-blocks", response_model=TimeBlockRead, status_code=status.HTTP_201_CREATED)
async def create_time_block(
    payload: TimeBlockCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> TimeBlockRead:
    time_block = await personal_service.create_time_block(session, current_user.id, payload)
    return TimeBlockRead.model_validate(time_block)


@router.get("/time-blocks", response_model=PaginatedResponse[TimeBlockRead], status_code=status.HTTP_200_OK)
async def list_time_blocks(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[TimeBlockRead]:
    time_blocks, total = await personal_service.list_time_blocks(session, current_user.id, pagination)
    return PaginatedResponse(items=time_blocks, total=total, limit=pagination.limit, offset=pagination.offset)


@router.patch("/time-blocks/{time_block_id}", response_model=TimeBlockRead, status_code=status.HTTP_200_OK)
async def update_time_block(
    time_block_id: uuid.UUID,
    payload: TimeBlockUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> TimeBlockRead:
    time_block = await personal_service.update_time_block(session, current_user.id, time_block_id, payload)
    return TimeBlockRead.model_validate(time_block)


@router.delete("/time-blocks/{time_block_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_time_block(
    time_block_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await personal_service.delete_time_block(session, current_user.id, time_block_id)


@router.post("/daily-activities", response_model=DailyActivityRead, status_code=status.HTTP_201_CREATED)
async def create_daily_activity(
    payload: DailyActivityCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> DailyActivityRead:
    activity = await personal_service.create_daily_activity(session, current_user.id, payload)
    return DailyActivityRead.model_validate(activity)


@router.get("/daily-activities", response_model=PaginatedResponse[DailyActivityRead], status_code=status.HTTP_200_OK)
async def list_daily_activities(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[DailyActivityRead]:
    activities, total = await personal_service.list_daily_activities(session, current_user.id, pagination)
    return PaginatedResponse(items=activities, total=total, limit=pagination.limit, offset=pagination.offset)


@router.patch("/daily-activities/{activity_id}", response_model=DailyActivityRead, status_code=status.HTTP_200_OK)
async def update_daily_activity(
    activity_id: uuid.UUID,
    payload: DailyActivityUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> DailyActivityRead:
    activity = await personal_service.update_daily_activity(session, current_user.id, activity_id, payload)
    return DailyActivityRead.model_validate(activity)


@router.delete("/daily-activities/{activity_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_daily_activity(
    activity_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await personal_service.delete_daily_activity(session, current_user.id, activity_id)