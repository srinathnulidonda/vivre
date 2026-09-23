# app/services/health.py
import uuid
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError, PermissionDeniedError
from app.integrations.health import (
    normalize_daily_metric_payload,
    normalize_sleep_payload,
    normalize_workout_payload,
)
from app.models.health import (
    DailyMetric,
    DeviceConnection,
    DeviceConnectionPlatform,
    DeviceConnectionStatus,
    SleepRecord,
    Workout,
)
from app.models.user import User
from app.schemas.health import HealthContextSummary
from app.schemas.shared import PaginationParams
from app.services.shared import resolve_local_day_bounds


async def _get_owned_workout(
    session: AsyncSession, user_id: uuid.UUID, workout_id: uuid.UUID
) -> Workout:
    workout = await session.get(Workout, workout_id)
    if workout is None:
        raise NotFoundError("Workout not found")
    if workout.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this workout")
    return workout


async def upsert_daily_metric(
    session: AsyncSession, user_id: uuid.UUID, raw_payload: dict[str, object]
) -> DailyMetric:
    normalized = normalize_daily_metric_payload(raw_payload)
    stmt = (
        pg_insert(DailyMetric)
        .values(
            id=uuid.uuid4(),
            user_id=user_id,
            metric_date=normalized["metric_date"],
            steps=normalized["steps"],
            distance_meters=normalized["distance_meters"],
            active_calories=normalized["active_calories"],
        )
        .on_conflict_do_update(
            index_elements=[DailyMetric.user_id, DailyMetric.metric_date],
            set_={
                "steps": normalized["steps"],
                "distance_meters": normalized["distance_meters"],
                "active_calories": normalized["active_calories"],
                "updated_at": func.now(),
            },
        )
        .returning(DailyMetric)
    )
    result = await session.execute(stmt)
    metric = result.scalar_one()
    await session.commit()
    return metric


async def list_daily_metrics(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[DailyMetric], int]:
    count_result = await session.execute(
        select(func.count()).select_from(DailyMetric).where(DailyMetric.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(DailyMetric)
        .where(DailyMetric.user_id == user_id)
        .order_by(DailyMetric.metric_date.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def upsert_sleep_record(
    session: AsyncSession, user_id: uuid.UUID, raw_payload: dict[str, object]
) -> SleepRecord:
    normalized = normalize_sleep_payload(raw_payload)
    stmt = (
        pg_insert(SleepRecord)
        .values(
            id=uuid.uuid4(),
            user_id=user_id,
            sleep_date=normalized["sleep_date"],
            start_at=normalized["start_at"],
            end_at=normalized["end_at"],
            duration_minutes=normalized["duration_minutes"],
            quality=normalized["quality"],
        )
        .on_conflict_do_update(
            index_elements=[SleepRecord.user_id, SleepRecord.sleep_date],
            set_={
                "start_at": normalized["start_at"],
                "end_at": normalized["end_at"],
                "duration_minutes": normalized["duration_minutes"],
                "quality": normalized["quality"],
                "updated_at": func.now(),
            },
        )
        .returning(SleepRecord)
    )
    result = await session.execute(stmt)
    sleep_record = result.scalar_one()
    await session.commit()
    return sleep_record


async def list_sleep_records(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[SleepRecord], int]:
    count_result = await session.execute(
        select(func.count()).select_from(SleepRecord).where(SleepRecord.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(SleepRecord)
        .where(SleepRecord.user_id == user_id)
        .order_by(SleepRecord.sleep_date.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def create_workout(
    session: AsyncSession, user_id: uuid.UUID, raw_payload: dict[str, object]
) -> Workout:
    normalized = normalize_workout_payload(raw_payload)
    workout = Workout(user_id=user_id, **normalized)
    session.add(workout)
    await session.commit()
    await session.refresh(workout)
    return workout


async def delete_workout(session: AsyncSession, user_id: uuid.UUID, workout_id: uuid.UUID) -> None:
    workout = await _get_owned_workout(session, user_id, workout_id)
    await session.delete(workout)
    await session.commit()


async def list_workouts(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[Workout], int]:
    count_result = await session.execute(
        select(func.count()).select_from(Workout).where(Workout.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(Workout)
        .where(Workout.user_id == user_id)
        .order_by(Workout.start_at.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def connect_device(
    session: AsyncSession, user_id: uuid.UUID, platform: DeviceConnectionPlatform
) -> DeviceConnection:
    now = datetime.now(timezone.utc)
    stmt = (
        pg_insert(DeviceConnection)
        .values(
            id=uuid.uuid4(),
            user_id=user_id,
            platform=platform,
            status=DeviceConnectionStatus.CONNECTED,
            connected_at=now,
            disconnected_at=None,
        )
        .on_conflict_do_update(
            index_elements=[DeviceConnection.user_id, DeviceConnection.platform],
            set_={
                "status": DeviceConnectionStatus.CONNECTED,
                "connected_at": now,
                "disconnected_at": None,
                "updated_at": func.now(),
            },
            where=DeviceConnection.status != DeviceConnectionStatus.CONNECTED,
        )
        .returning(DeviceConnection)
    )
    result = await session.execute(stmt)
    connection = result.scalar_one_or_none()
    if connection is None:
        raise ConflictError("This device platform is already connected")
    await session.commit()
    return connection


async def disconnect_device(
    session: AsyncSession, user_id: uuid.UUID, connection_id: uuid.UUID
) -> DeviceConnection:
    connection = await session.get(DeviceConnection, connection_id)
    if connection is None:
        raise NotFoundError("Device connection not found")
    if connection.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this device connection")
    connection.status = DeviceConnectionStatus.DISCONNECTED
    connection.disconnected_at = datetime.now(timezone.utc)
    await session.commit()
    await session.refresh(connection)
    return connection


async def list_device_connections(
    session: AsyncSession, user_id: uuid.UUID
) -> list[DeviceConnection]:
    result = await session.execute(
        select(DeviceConnection).where(DeviceConnection.user_id == user_id)
    )
    return list(result.scalars().all())


async def get_health_context_summary(
    session: AsyncSession, user: User, reference_date: date
) -> HealthContextSummary:
    metric_result = await session.execute(
        select(DailyMetric).where(
            DailyMetric.user_id == user.id, DailyMetric.metric_date == reference_date
        )
    )
    metric = metric_result.scalar_one_or_none()

    sleep_result = await session.execute(
        select(SleepRecord).where(
            SleepRecord.user_id == user.id, SleepRecord.sleep_date == reference_date
        )
    )
    sleep_record = sleep_result.scalar_one_or_none()

    window_start, _ = resolve_local_day_bounds(user.timezone, reference_date - timedelta(days=6))
    _, window_end = resolve_local_day_bounds(user.timezone, reference_date)
    workout_count_result = await session.execute(
        select(func.count())
        .select_from(Workout)
        .where(
            Workout.user_id == user.id,
            Workout.start_at >= window_start,
            Workout.start_at < window_end,
        )
    )

    return HealthContextSummary(
        steps_count=metric.steps if metric else None,
        distance_meters=metric.distance_meters if metric else None,
        active_calories=metric.active_calories if metric else None,
        sleep_hours=round(sleep_record.duration_minutes / 60, 2) if sleep_record else None,
        recent_workouts_count=workout_count_result.scalar_one(),
    )