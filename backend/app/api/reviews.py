# app/api/reviews.py
from datetime import date

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.reviews import (
    DailyReviewContext,
    DailyReviewRead,
    DailyReviewUpsertRequest,
    ReflectionCreateRequest,
    ReflectionRead,
    WeeklyReviewRead,
    WeeklyReviewUpsertRequest,
)
from app.schemas.shared import PaginatedResponse, PaginationParams, pagination_params
from app.services import reviews as reviews_service

router = APIRouter(prefix="/reviews", tags=["reviews"])


@router.post("/daily", response_model=DailyReviewRead, status_code=status.HTTP_200_OK)
async def upsert_daily_review(
    payload: DailyReviewUpsertRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> DailyReviewRead:
    review = await reviews_service.upsert_daily_review(session, current_user.id, payload)
    return DailyReviewRead.model_validate(review)


@router.get("/daily", response_model=PaginatedResponse[DailyReviewRead], status_code=status.HTTP_200_OK)
async def list_daily_reviews(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[DailyReviewRead]:
    reviews, total = await reviews_service.list_daily_reviews(session, current_user.id, pagination)
    return PaginatedResponse(items=reviews, total=total, limit=pagination.limit, offset=pagination.offset)


@router.get("/daily/{review_date}", response_model=DailyReviewRead, status_code=status.HTTP_200_OK)
async def get_daily_review(
    review_date: date,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> DailyReviewRead:
    review = await reviews_service.get_daily_review(session, current_user.id, review_date)
    return DailyReviewRead.model_validate(review)


@router.get("/daily/{review_date}/context", response_model=DailyReviewContext, status_code=status.HTTP_200_OK)
async def get_daily_review_context(
    review_date: date,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> DailyReviewContext:
    context = await reviews_service.generate_daily_review_context(session, current_user, review_date)
    return DailyReviewContext.model_validate(context)


@router.post("/weekly", response_model=WeeklyReviewRead, status_code=status.HTTP_200_OK)
async def upsert_weekly_review(
    payload: WeeklyReviewUpsertRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> WeeklyReviewRead:
    review = await reviews_service.upsert_weekly_review(session, current_user.id, payload)
    return WeeklyReviewRead.model_validate(review)


@router.get("/weekly", response_model=PaginatedResponse[WeeklyReviewRead], status_code=status.HTTP_200_OK)
async def list_weekly_reviews(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[WeeklyReviewRead]:
    reviews, total = await reviews_service.list_weekly_reviews(session, current_user.id, pagination)
    return PaginatedResponse(items=reviews, total=total, limit=pagination.limit, offset=pagination.offset)


@router.post("/reflections", response_model=ReflectionRead, status_code=status.HTTP_201_CREATED)
async def create_reflection(
    payload: ReflectionCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ReflectionRead:
    reflection = await reviews_service.create_reflection(session, current_user.id, payload)
    return ReflectionRead.model_validate(reflection)


@router.get("/reflections", response_model=PaginatedResponse[ReflectionRead], status_code=status.HTTP_200_OK)
async def list_reflections(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[ReflectionRead]:
    reflections, total = await reviews_service.list_reflections(session, current_user.id, pagination)
    return PaginatedResponse(items=reflections, total=total, limit=pagination.limit, offset=pagination.offset)