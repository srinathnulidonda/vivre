# app/workers/tasks.py
import asyncio
import uuid
from datetime import datetime
from zoneinfo import ZoneInfo

from sqlalchemy import select

from app.core.config import get_settings
from app.db.redis import redis_client
from app.db.session import get_session_context
from app.models.notifications import NotificationChannel, NotificationPreference
from app.models.user import User
from app.services.notifications import (
    create_notification,
    create_notifications_batch,
    deliver_pending_notifications,
    get_notification_preference,
)
from app.workers.celery_app import celery_app

_settings = get_settings()

_DAILY_PROMPT_KEY_PREFIX = "review_prompt:daily:"
_WEEKLY_DIGEST_KEY_PREFIX = "review_prompt:weekly:"
_DAILY_PROMPT_TTL_SECONDS = 172800
_WEEKLY_DIGEST_TTL_SECONDS = 1209600


async def _dispatch_daily_review_prompts() -> int:
    dispatched_batches = 0
    last_user_id: uuid.UUID | None = None
    async with get_session_context() as session:
        while True:
            stmt = (
                select(User.id, User.timezone)
                .order_by(User.id)
                .limit(_settings.DIGEST_DISPATCH_BATCH_SIZE)
            )
            if last_user_id is not None:
                stmt = stmt.where(User.id > last_user_id)
            result = await session.execute(stmt)
            rows = result.all()
            if not rows:
                break
            last_user_id = rows[-1][0]
            matching_user_ids = [
                str(user_id)
                for user_id, user_timezone in rows
                if datetime.now(ZoneInfo(user_timezone)).hour
                == _settings.DAILY_REVIEW_PROMPT_LOCAL_HOUR
            ]
            if matching_user_ids:
                send_daily_review_prompt_batch_task.delay(matching_user_ids)
                dispatched_batches += 1
    return dispatched_batches


async def _dispatch_weekly_digest_emails() -> int:
    dispatched_batches = 0
    last_user_id: uuid.UUID | None = None
    async with get_session_context() as session:
        while True:
            stmt = (
                select(User.id, User.timezone)
                .order_by(User.id)
                .limit(_settings.DIGEST_DISPATCH_BATCH_SIZE)
            )
            if last_user_id is not None:
                stmt = stmt.where(User.id > last_user_id)
            result = await session.execute(stmt)
            rows = result.all()
            if not rows:
                break
            last_user_id = rows[-1][0]
            matching_user_ids: list[str] = []
            for user_id, user_timezone in rows:
                local_now = datetime.now(ZoneInfo(user_timezone))
                if (
                    local_now.weekday() == _settings.WEEKLY_DIGEST_LOCAL_WEEKDAY
                    and local_now.hour == _settings.WEEKLY_DIGEST_LOCAL_HOUR
                ):
                    matching_user_ids.append(str(user_id))
            if matching_user_ids:
                send_weekly_digest_batch_task.delay(matching_user_ids)
                dispatched_batches += 1
    return dispatched_batches


async def _send_daily_review_prompt_batch(user_ids: list[str]) -> int:
    parsed_ids = [uuid.UUID(raw_user_id) for raw_user_id in user_ids]
    async with get_session_context() as session:
        users_result = await session.execute(select(User).where(User.id.in_(parsed_ids)))
        users_by_id = {user.id: user for user in users_result.scalars().all()}
        prefs_result = await session.execute(
            select(NotificationPreference).where(NotificationPreference.user_id.in_(parsed_ids))
        )
        prefs_by_id = {pref.user_id: pref for pref in prefs_result.scalars().all()}
        pending_notifications: list[dict] = []
        for user_id in parsed_ids:
            user = users_by_id.get(user_id)
            if user is None:
                continue
            preference = prefs_by_id.get(user_id)
            if preference is not None and not preference.inapp_reviews:
                continue
            local_today = datetime.now(ZoneInfo(user.timezone)).date()
            idempotency_key = f"{_DAILY_PROMPT_KEY_PREFIX}{user.id}:{local_today.isoformat()}"
            was_set = await redis_client.set(
                idempotency_key, "1", nx=True, ex=_DAILY_PROMPT_TTL_SECONDS
            )
            if not was_set:
                continue
            pending_notifications.append(
                {
                    "user_id": user.id,
                    "notification_type": "review.daily_due",
                    "channel": NotificationChannel.IN_APP,
                    "payload": {
                        "title": "Daily review ready",
                        "body": "Take a moment to review your day.",
                        "review_date": local_today.isoformat(),
                    },
                }
            )
        if pending_notifications:
            await create_notifications_batch(session, pending_notifications)
            return len(pending_notifications)
    return 0


async def _send_weekly_digest_batch(user_ids: list[str]) -> int:
    parsed_ids = [uuid.UUID(raw_user_id) for raw_user_id in user_ids]
    async with get_session_context() as session:
        users_result = await session.execute(select(User).where(User.id.in_(parsed_ids)))
        users_by_id = {user.id: user for user in users_result.scalars().all()}
        prefs_result = await session.execute(
            select(NotificationPreference).where(NotificationPreference.user_id.in_(parsed_ids))
        )
        prefs_by_id = {pref.user_id: pref for pref in prefs_result.scalars().all()}
        pending_notifications: list[dict] = []
        for user_id in parsed_ids:
            user = users_by_id.get(user_id)
            if user is None:
                continue
            preference = prefs_by_id.get(user_id)
            if preference is not None and not preference.email_digest:
                continue
            local_today = datetime.now(ZoneInfo(user.timezone)).date()
            idempotency_key = f"{_WEEKLY_DIGEST_KEY_PREFIX}{user.id}:{local_today.isoformat()}"
            was_set = await redis_client.set(
                idempotency_key, "1", nx=True, ex=_WEEKLY_DIGEST_TTL_SECONDS
            )
            if not was_set:
                continue
            pending_notifications.append(
                {
                    "user_id": user.id,
                    "notification_type": "review.weekly_due",
                    "channel": NotificationChannel.EMAIL,
                    "payload": {
                        "subject": "Your VIVRE weekly digest",
                        "html_content": (
                            "<p>Your weekly review is ready. Open VIVRE to reflect on your week.</p>"
                        ),
                    },
                }
            )
        if pending_notifications:
            await create_notifications_batch(session, pending_notifications)
            return len(pending_notifications)
    return 0


async def _process_task_completed_event(payload: dict[str, str]) -> None:
    user_id = uuid.UUID(payload["user_id"])
    async with get_session_context() as session:
        preference = await get_notification_preference(session, user_id)
        if not preference.inapp_tasks:
            return
        await create_notification(
            session,
            user_id,
            notification_type="task.completed",
            channel=NotificationChannel.IN_APP,
            payload={
                "task_id": payload["task_id"],
                "task_title": payload["task_title"],
                "title": "Task completed",
                "body": payload["task_title"],
            },
        )


async def _process_habit_checked_in_event(payload: dict[str, str]) -> None:
    user_id = uuid.UUID(payload["user_id"])
    async with get_session_context() as session:
        preference = await get_notification_preference(session, user_id)
        if not preference.inapp_habits:
            return
        await create_notification(
            session,
            user_id,
            notification_type="habit.checked_in",
            channel=NotificationChannel.IN_APP,
            payload={
                "habit_id": payload["habit_id"],
                "habit_name": payload["habit_name"],
                "title": "Habit logged",
                "body": payload["habit_name"],
            },
        )


async def _process_goal_achieved_event(payload: dict[str, str]) -> None:
    user_id = uuid.UUID(payload["user_id"])
    async with get_session_context() as session:
        preference = await get_notification_preference(session, user_id)
        if preference.inapp_goals:
            await create_notification(
                session,
                user_id,
                notification_type="goal.achieved",
                channel=NotificationChannel.IN_APP,
                payload={
                    "goal_id": payload["goal_id"],
                    "goal_title": payload["goal_title"],
                    "title": "Goal achieved",
                    "body": payload["goal_title"],
                },
            )
        if preference.push_goals:
            await create_notification(
                session,
                user_id,
                notification_type="goal.achieved",
                channel=NotificationChannel.PUSH,
                payload={
                    "goal_id": payload["goal_id"],
                    "title": "Goal achieved",
                    "body": f"You achieved: {payload['goal_title']}",
                },
            )


async def _process_milestone_completed_event(payload: dict[str, str]) -> None:
    user_id = uuid.UUID(payload["user_id"])
    async with get_session_context() as session:
        preference = await get_notification_preference(session, user_id)
        if not preference.inapp_milestones:
            return
        await create_notification(
            session,
            user_id,
            notification_type="milestone.completed",
            channel=NotificationChannel.IN_APP,
            payload={
                "milestone_id": payload["milestone_id"],
                "project_id": payload["project_id"],
                "title": "Milestone completed",
                "body": payload["milestone_title"],
            },
        )


@celery_app.task(name="app.workers.tasks.deliver_pending_notifications_task")
def deliver_pending_notifications_task() -> int:
    return asyncio.run(deliver_pending_notifications())


@celery_app.task(name="app.workers.tasks.dispatch_daily_review_prompts_task")
def dispatch_daily_review_prompts_task() -> int:
    return asyncio.run(_dispatch_daily_review_prompts())


@celery_app.task(name="app.workers.tasks.dispatch_weekly_digest_emails_task")
def dispatch_weekly_digest_emails_task() -> int:
    return asyncio.run(_dispatch_weekly_digest_emails())


@celery_app.task(name="app.workers.tasks.send_daily_review_prompt_batch_task")
def send_daily_review_prompt_batch_task(user_ids: list[str]) -> int:
    return asyncio.run(_send_daily_review_prompt_batch(user_ids))


@celery_app.task(name="app.workers.tasks.send_weekly_digest_batch_task")
def send_weekly_digest_batch_task(user_ids: list[str]) -> int:
    return asyncio.run(_send_weekly_digest_batch(user_ids))


@celery_app.task(name="app.workers.tasks.process_task_completed_event_task")
def process_task_completed_event_task(payload: dict[str, str]) -> None:
    asyncio.run(_process_task_completed_event(payload))


@celery_app.task(name="app.workers.tasks.process_habit_checked_in_event_task")
def process_habit_checked_in_event_task(payload: dict[str, str]) -> None:
    asyncio.run(_process_habit_checked_in_event(payload))


@celery_app.task(name="app.workers.tasks.process_goal_achieved_event_task")
def process_goal_achieved_event_task(payload: dict[str, str]) -> None:
    asyncio.run(_process_goal_achieved_event(payload))


@celery_app.task(name="app.workers.tasks.process_milestone_completed_event_task")
def process_milestone_completed_event_task(payload: dict[str, str]) -> None:
    asyncio.run(_process_milestone_completed_event(payload))