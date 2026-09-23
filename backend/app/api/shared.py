# app/api/shared.py
from datetime import date

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.redis import check_redis_connectivity
from app.db.session import check_database_connectivity, get_db
from app.models.user import User
from app.schemas.shared import LivenessResponse, ReadinessResponse, SearchResponse, TimelineResponse
from app.services import shared as shared_service

router = APIRouter(tags=["shared"])


@router.get("/health", response_model=LivenessResponse, status_code=status.HTTP_200_OK)
async def liveness() -> LivenessResponse:
    return LivenessResponse(status="ok")


@router.get("/health/ready", response_model=ReadinessResponse, status_code=status.HTTP_200_OK)
async def readiness() -> ReadinessResponse:
    try:
        database_ok = await check_database_connectivity()
    except Exception:
        database_ok = False
    try:
        redis_ok = await check_redis_connectivity()
    except Exception:
        redis_ok = False
    overall_status = "ok" if database_ok and redis_ok else "degraded"
    return ReadinessResponse(status=overall_status, database=database_ok, redis=redis_ok)


@router.get("/timeline", response_model=TimelineResponse, status_code=status.HTTP_200_OK)
async def get_timeline(
    timeline_date: date = Query(..., alias="date"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> TimelineResponse:
    return await shared_service.get_timeline(session, current_user, timeline_date)


@router.get("/search", response_model=SearchResponse, status_code=status.HTTP_200_OK)
async def search(
    q: str = Query(..., min_length=1),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SearchResponse:
    return await shared_service.search_all(session, current_user.id, q, limit, offset)