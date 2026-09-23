# app/api/health.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.health import (
    DailyMetricRead,
    DailyMetricUpsertRequest,
    DeviceConnectionCreateRequest,
    DeviceConnectionRead,
    SleepRecordRead,
    SleepRecordUpsertRequest,
    WorkoutCreateRequest,
    WorkoutRead,
)
from app.schemas.shared import PaginatedResponse, PaginationParams, pagination_params
from app.services import health as health_service

router = APIRouter(prefix="/health-metrics", tags=["health"])


@router.post("/daily-metrics", response_model=DailyMetricRead, status_code=status.HTTP_200_OK)
async def upsert_daily_metric(
    payload: DailyMetricUpsertRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> DailyMetricRead:
    metric = await health_service.upsert_daily_metric(session, current_user.id, payload.model_dump())
    return DailyMetricRead.model_validate(metric)


@router.get("/daily-metrics", response_model=PaginatedResponse[DailyMetricRead], status_code=status.HTTP_200_OK)
async def list_daily_metrics(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[DailyMetricRead]:
    metrics, total = await health_service.list_daily_metrics(session, current_user.id, pagination)
    return PaginatedResponse(items=metrics, total=total, limit=pagination.limit, offset=pagination.offset)


@router.post("/sleep", response_model=SleepRecordRead, status_code=status.HTTP_200_OK)
async def upsert_sleep_record(
    payload: SleepRecordUpsertRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SleepRecordRead:
    sleep_record = await health_service.upsert_sleep_record(session, current_user.id, payload.model_dump())
    return SleepRecordRead.model_validate(sleep_record)


@router.get("/sleep", response_model=PaginatedResponse[SleepRecordRead], status_code=status.HTTP_200_OK)
async def list_sleep_records(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[SleepRecordRead]:
    sleep_records, total = await health_service.list_sleep_records(session, current_user.id, pagination)
    return PaginatedResponse(items=sleep_records, total=total, limit=pagination.limit, offset=pagination.offset)


@router.post("/workouts", response_model=WorkoutRead, status_code=status.HTTP_201_CREATED)
async def create_workout(
    payload: WorkoutCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> WorkoutRead:
    workout = await health_service.create_workout(session, current_user.id, payload.model_dump())
    return WorkoutRead.model_validate(workout)


@router.get("/workouts", response_model=PaginatedResponse[WorkoutRead], status_code=status.HTTP_200_OK)
async def list_workouts(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[WorkoutRead]:
    workouts, total = await health_service.list_workouts(session, current_user.id, pagination)
    return PaginatedResponse(items=workouts, total=total, limit=pagination.limit, offset=pagination.offset)


@router.delete("/workouts/{workout_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_workout(
    workout_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await health_service.delete_workout(session, current_user.id, workout_id)


@router.post("/device-connections", response_model=DeviceConnectionRead, status_code=status.HTTP_201_CREATED)
async def connect_device(
    payload: DeviceConnectionCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> DeviceConnectionRead:
    connection = await health_service.connect_device(session, current_user.id, payload.platform)
    return DeviceConnectionRead.model_validate(connection)


@router.post("/device-connections/{connection_id}/disconnect", response_model=DeviceConnectionRead, status_code=status.HTTP_200_OK)
async def disconnect_device(
    connection_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> DeviceConnectionRead:
    connection = await health_service.disconnect_device(session, current_user.id, connection_id)
    return DeviceConnectionRead.model_validate(connection)


@router.get("/device-connections", response_model=list[DeviceConnectionRead], status_code=status.HTTP_200_OK)
async def list_device_connections(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[DeviceConnectionRead]:
    connections = await health_service.list_device_connections(session, current_user.id)
    return [DeviceConnectionRead.model_validate(connection) for connection in connections]