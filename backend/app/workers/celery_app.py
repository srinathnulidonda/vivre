# app/workers/celery_app.py
from celery import Celery
from celery.schedules import crontab

from app.core.config import get_settings

_settings = get_settings()

celery_app = Celery("vivre", broker=_settings.REDIS_URL, backend=_settings.REDIS_URL)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_default_queue="vivre",
    worker_prefetch_multiplier=1,
    task_acks_late=True,
    broker_connection_retry_on_startup=True,
    broker_pool_limit=10,
    task_time_limit=300,
    task_soft_time_limit=270,
    worker_max_tasks_per_child=200,
    result_expires=3600,
)

celery_app.conf.beat_schedule = {
    "deliver-pending-notifications": {
        "task": "app.workers.tasks.deliver_pending_notifications_task",
        "schedule": 60.0,
    },
    "dispatch-daily-review-prompts": {
        "task": "app.workers.tasks.dispatch_daily_review_prompts_task",
        "schedule": crontab(minute=0),
    },
    "dispatch-weekly-digest-emails": {
        "task": "app.workers.tasks.dispatch_weekly_digest_emails_task",
        "schedule": crontab(minute=0),
    },
}

celery_app.autodiscover_tasks(["app.workers"])