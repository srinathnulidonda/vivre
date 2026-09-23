# app/services/reviews.py
import uuid
from datetime import date
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.models.reviews import DailyReview, Reflection, WeeklyReview
from app.models.user import User
from app.models.work import Task, TaskStatus
from app.schemas.reviews import DailyReviewUpsertRequest, ReflectionCreateRequest, WeeklyReviewUpsertRequest
from app.schemas.shared import PaginationParams
from app.services.health import get_health_context_summary
from app.services.personal import compute_habit_streak, list_habits
from app.services.shared import resolve_local_day_bounds

_REVIEW_CONTEXT_HABIT_LIMIT = 100


async def upsert_daily_review(
    session: AsyncSession, user_id: uuid.UUID, request: DailyReviewUpsertRequest
) -> DailyReview:
    stmt = (
        pg_insert(DailyReview)
        .values(
            id=uuid.uuid4(),
            user_id=user_id,
            review_date=request.review_date,
            wins=request.wins,
            blockers=request.blockers,
            mood=request.mood,
            notes=request.notes,
        )
        .on_conflict_do_update(
            index_elements=[DailyReview.user_id, DailyReview.review_date],
            set_={
                "wins": request.wins,
                "blockers": request.blockers,
                "mood": request.mood,
                "notes": request.notes,
                "updated_at": func.now(),
            },
        )
        .returning(DailyReview)
    )
    result = await session.execute(stmt)
    review = result.scalar_one()
    await session.commit()
    return review


async def get_daily_review(
    session: AsyncSession, user_id: uuid.UUID, review_date: date
) -> DailyReview:
    result = await session.execute(
        select(DailyReview).where(
            DailyReview.user_id == user_id, DailyReview.review_date == review_date
        )
    )
    review = result.scalar_one_or_none()
    if review is None:
        raise NotFoundError("Daily review not found")
    return review


async def list_daily_reviews(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[DailyReview], int]:
    count_result = await session.execute(
        select(func.count()).select_from(DailyReview).where(DailyReview.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(DailyReview)
        .where(DailyReview.user_id == user_id)
        .order_by(DailyReview.review_date.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def upsert_weekly_review(
    session: AsyncSession, user_id: uuid.UUID, request: WeeklyReviewUpsertRequest
) -> WeeklyReview:
    stmt = (
        pg_insert(WeeklyReview)
        .values(
            id=uuid.uuid4(),
            user_id=user_id,
            week_start_date=request.week_start_date,
            wins=request.wins,
            blockers=request.blockers,
            mood=request.mood,
            notes=request.notes,
        )
        .on_conflict_do_update(
            index_elements=[WeeklyReview.user_id, WeeklyReview.week_start_date],
            set_={
                "wins": request.wins,
                "blockers": request.blockers,
                "mood": request.mood,
                "notes": request.notes,
                "updated_at": func.now(),
            },
        )
        .returning(WeeklyReview)
    )
    result = await session.execute(stmt)
    review = result.scalar_one()
    await session.commit()
    return review


async def list_weekly_reviews(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[WeeklyReview], int]:
    count_result = await session.execute(
        select(func.count()).select_from(WeeklyReview).where(WeeklyReview.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(WeeklyReview)
        .where(WeeklyReview.user_id == user_id)
        .order_by(WeeklyReview.week_start_date.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def create_reflection(
    session: AsyncSession, user_id: uuid.UUID, request: ReflectionCreateRequest
) -> Reflection:
    reflection = Reflection(
        user_id=user_id,
        reflection_date=request.reflection_date,
        prompt=request.prompt,
        content=request.content,
    )
    session.add(reflection)
    await session.commit()
    await session.refresh(reflection)
    return reflection


async def list_reflections(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[Reflection], int]:
    count_result = await session.execute(
        select(func.count()).select_from(Reflection).where(Reflection.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(Reflection)
        .where(Reflection.user_id == user_id)
        .order_by(Reflection.reflection_date.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def generate_daily_review_context(
    session: AsyncSession, user: User, review_date: date
) -> dict[str, Any]:
    day_start, day_end = resolve_local_day_bounds(user.timezone, review_date)
    completed_tasks_result = await session.execute(
        select(func.count())
        .select_from(Task)
        .where(
            Task.user_id == user.id,
            Task.status == TaskStatus.DONE,
            Task.completed_at >= day_start,
            Task.completed_at < day_end,
        )
    )
    completed_task_count = completed_tasks_result.scalar_one()
    habits, _ = await list_habits(
        session, user.id, PaginationParams(limit=_REVIEW_CONTEXT_HABIT_LIMIT, offset=0)
    )
    habit_streaks = {habit.name: await compute_habit_streak(session, user.id, habit.id) for habit in habits}
    health_summary = await get_health_context_summary(session, user, review_date)
    return {
        "review_date": review_date.isoformat(),
        "completed_task_count": completed_task_count,
        "habit_streaks": habit_streaks,
        "health_summary": health_summary.model_dump(),
    }