# app/services/notifications.py
import asyncio
import json
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import NotFoundError, PermissionDeniedError
from app.core.logging import get_logger
from app.db.redis import redis_client
from app.db.session import get_session_context
from app.events import (
    EventPayload,
    EventType,
    GoalAchievedPayload,
    HabitCheckedInPayload,
    MilestoneCompletedPayload,
    TaskCompletedPayload,
    event_bus,
)
from app.integrations.brevo import send_transactional_email
from app.integrations.fcm import UnregisteredPushTokenError, send_push_notification
from app.models.notifications import Notification, NotificationChannel, NotificationPreference
from app.models.user import User
from app.schemas.notifications import NotificationPreferenceUpdateRequest
from app.schemas.shared import PaginationParams

logger = get_logger(__name__)
_settings = get_settings()
_PUSH_TOKEN_KEY_PREFIX = "push_tokens:"
_NOTIFICATION_STREAM_CHANNEL_PREFIX = "notifications:stream:"
_DELIVERY_BATCH_LIMIT = 100
_CELERY_TASK_BY_EVENT: dict[EventType, str] = {
    EventType.TASK_COMPLETED: "app.workers.tasks.process_task_completed_event_task",
    EventType.HABIT_CHECKED_IN: "app.workers.tasks.process_habit_checked_in_event_task",
    EventType.GOAL_ACHIEVED: "app.workers.tasks.process_goal_achieved_event_task",
    EventType.MILESTONE_COMPLETED: "app.workers.tasks.process_milestone_completed_event_task",
}


def _push_token_key(user_id: uuid.UUID) -> str:
    return f"{_PUSH_TOKEN_KEY_PREFIX}{user_id}"


def notification_stream_channel(user_id: uuid.UUID) -> str:
    return f"{_NOTIFICATION_STREAM_CHANNEL_PREFIX}{user_id}"


async def register_device_token(user_id: uuid.UUID, device_token: str) -> None:
    await redis_client.sadd(_push_token_key(user_id), device_token)


async def unregister_device_token(user_id: uuid.UUID, device_token: str) -> None:
    await redis_client.srem(_push_token_key(user_id), device_token)


async def get_notification_preference(
    session: AsyncSession, user_id: uuid.UUID
) -> NotificationPreference:
    result = await session.execute(
        select(NotificationPreference).where(NotificationPreference.user_id == user_id)
    )
    preference = result.scalar_one_or_none()
    if preference is not None:
        return preference
    preference = NotificationPreference(user_id=user_id)
    session.add(preference)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        result = await session.execute(
            select(NotificationPreference).where(NotificationPreference.user_id == user_id)
        )
        return result.scalar_one()
    await session.refresh(preference)
    return preference


async def update_notification_preference(
    session: AsyncSession, user_id: uuid.UUID, request: NotificationPreferenceUpdateRequest
) -> NotificationPreference:
    preference = await get_notification_preference(session, user_id)
    update_fields = request.model_dump(exclude_unset=True)
    for field_name, field_value in update_fields.items():
        setattr(preference, field_name, field_value)
    await session.commit()
    await session.refresh(preference)
    return preference


async def _publish_stream_event(notification: Notification) -> None:
    event = {
        "id": str(notification.id),
        "notification_type": notification.notification_type,
        "payload": notification.payload,
        "created_at": notification.created_at.isoformat(),
    }
    await redis_client.publish(notification_stream_channel(notification.user_id), json.dumps(event))


async def create_notification(
    session: AsyncSession,
    user_id: uuid.UUID,
    notification_type: str,
    channel: NotificationChannel,
    payload: dict[str, Any],
) -> Notification:
    notification = Notification(
        user_id=user_id, notification_type=notification_type, channel=channel, payload=payload
    )
    if channel == NotificationChannel.IN_APP:
        notification.sent_at = datetime.now(timezone.utc)
    session.add(notification)
    await session.commit()
    await session.refresh(notification)
    if channel == NotificationChannel.IN_APP:
        await _publish_stream_event(notification)
    return notification


async def create_notifications_batch(
    session: AsyncSession, entries: list[dict[str, Any]]
) -> list[Notification]:
    now = datetime.now(timezone.utc)
    notifications = [
        Notification(
            user_id=entry["user_id"],
            notification_type=entry["notification_type"],
            channel=entry["channel"],
            payload=entry["payload"],
        )
        for entry in entries
    ]
    for notification in notifications:
        if notification.channel == NotificationChannel.IN_APP:
            notification.sent_at = now
    session.add_all(notifications)
    await session.commit()
    notification_ids = [notification.id for notification in notifications]
    refreshed_result = await session.execute(
        select(Notification).where(Notification.id.in_(notification_ids))
    )
    refreshed_by_id = {notification.id: notification for notification in refreshed_result.scalars().all()}
    stream_notifications = [
        refreshed_by_id[notification.id]
        for notification in notifications
        if notification.channel == NotificationChannel.IN_APP and notification.id in refreshed_by_id
    ]
    for notification in stream_notifications:
        await _publish_stream_event(notification)
    return list(refreshed_by_id.values())


async def mark_notification_read(
    session: AsyncSession, user_id: uuid.UUID, notification_id: uuid.UUID
) -> Notification:
    notification = await session.get(Notification, notification_id)
    if notification is None:
        raise NotFoundError("Notification not found")
    if notification.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this notification")
    notification.read_at = datetime.now(timezone.utc)
    await session.commit()
    await session.refresh(notification)
    return notification


async def mark_all_notifications_read(session: AsyncSession, user_id: uuid.UUID) -> int:
    result = await session.execute(
        update(Notification)
        .where(Notification.user_id == user_id, Notification.read_at.is_(None))
        .values(read_at=datetime.now(timezone.utc))
    )
    await session.commit()
    return result.rowcount or 0


async def list_notifications(
    session: AsyncSession,
    user_id: uuid.UUID,
    pagination: PaginationParams,
    unread_only: bool = False,
) -> tuple[list[Notification], int]:
    filters = [Notification.user_id == user_id]
    if unread_only:
        filters.append(Notification.read_at.is_(None))
    count_result = await session.execute(select(func.count()).select_from(Notification).where(*filters))
    total = count_result.scalar_one()
    result = await session.execute(
        select(Notification)
        .where(*filters)
        .order_by(Notification.created_at.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def _deliver_push(notification: Notification) -> None:
    device_tokens = await redis_client.smembers(_push_token_key(notification.user_id))
    if not device_tokens:
        return
    tokens = list(device_tokens)
    title = str(notification.payload.get("title", "VIVRE"))
    body = str(notification.payload.get("body", ""))
    data = {key: str(value) for key, value in notification.payload.items()}
    results = await asyncio.gather(
        *(
            asyncio.to_thread(send_push_notification, token, title, body, data)
            for token in tokens
        ),
        return_exceptions=True,
    )
    unregistered_tokens = [
        token
        for token, result in zip(tokens, results)
        if isinstance(result, UnregisteredPushTokenError)
    ]
    if unregistered_tokens:
        await redis_client.srem(_push_token_key(notification.user_id), *unregistered_tokens)
    transient_failure_count = sum(
        1
        for result in results
        if isinstance(result, BaseException) and not isinstance(result, UnregisteredPushTokenError)
    )
    if transient_failure_count:
        raise RuntimeError(f"push_delivery_failed device_count={transient_failure_count}")


async def _deliver_email(notification: Notification, user: User) -> None:
    await asyncio.to_thread(
        send_transactional_email,
        to_email=user.email,
        to_name=user.name,
        subject=str(notification.payload.get("subject", "VIVRE update")),
        html_content=str(notification.payload.get("html_content", "")),
    )


async def _deliver_notification(notification: Notification, user: User | None) -> None:
    if notification.channel == NotificationChannel.PUSH:
        await _deliver_push(notification)
        return
    if notification.channel == NotificationChannel.EMAIL:
        if user is None:
            raise RuntimeError(f"notification_user_missing notification_id={notification.id}")
        await _deliver_email(notification, user)


async def deliver_pending_notifications(batch_limit: int = _DELIVERY_BATCH_LIMIT) -> int:
    async with get_session_context() as session:
        result = await session.execute(
            select(Notification)
            .where(Notification.sent_at.is_(None), Notification.failed_at.is_(None))
            .order_by(Notification.created_at.asc())
            .limit(batch_limit)
            .with_for_update(skip_locked=True)
        )
        pending = list(result.scalars().all())
        if not pending:
            return 0
        user_ids = {notification.user_id for notification in pending}
        users_result = await session.execute(select(User).where(User.id.in_(user_ids)))
        users_by_id = {user.id: user for user in users_result.scalars().all()}
        delivery_results = await asyncio.gather(
            *(
                _deliver_notification(notification, users_by_id.get(notification.user_id))
                for notification in pending
            ),
            return_exceptions=True,
        )
        now = datetime.now(timezone.utc)
        delivered_count = 0
        for notification, outcome in zip(pending, delivery_results):
            notification.delivery_attempts += 1
            notification.last_attempted_at = now
            if isinstance(outcome, BaseException):
                logger.error(
                    "notification_delivery_failed",
                    notification_id=str(notification.id),
                    error=str(outcome),
                )
                if notification.delivery_attempts >= _settings.MAX_NOTIFICATION_DELIVERY_ATTEMPTS:
                    notification.failed_at = now
                    logger.error(
                        "notification_delivery_abandoned",
                        notification_id=str(notification.id),
                        attempts=notification.delivery_attempts,
                    )
            else:
                notification.sent_at = now
                delivered_count += 1
        return delivered_count


async def _dispatch_event_to_celery(event_type: EventType, payload: EventPayload) -> None:
    from app.workers.celery_app import celery_app

    await asyncio.to_thread(
        celery_app.send_task,
        _CELERY_TASK_BY_EVENT[event_type],
        args=[payload.model_dump(mode="json")],
    )


async def _handle_task_completed(payload: EventPayload) -> None:
    if isinstance(payload, TaskCompletedPayload):
        await _dispatch_event_to_celery(EventType.TASK_COMPLETED, payload)


async def _handle_habit_checked_in(payload: EventPayload) -> None:
    if isinstance(payload, HabitCheckedInPayload):
        await _dispatch_event_to_celery(EventType.HABIT_CHECKED_IN, payload)


async def _handle_goal_achieved(payload: EventPayload) -> None:
    if isinstance(payload, GoalAchievedPayload):
        await _dispatch_event_to_celery(EventType.GOAL_ACHIEVED, payload)


async def _handle_milestone_completed(payload: EventPayload) -> None:
    if isinstance(payload, MilestoneCompletedPayload):
        await _dispatch_event_to_celery(EventType.MILESTONE_COMPLETED, payload)


def register_notification_event_handlers() -> None:
    event_bus.subscribe(EventType.TASK_COMPLETED, _handle_task_completed)
    event_bus.subscribe(EventType.HABIT_CHECKED_IN, _handle_habit_checked_in)
    event_bus.subscribe(EventType.GOAL_ACHIEVED, _handle_goal_achieved)
    event_bus.subscribe(EventType.MILESTONE_COMPLETED, _handle_milestone_completed)