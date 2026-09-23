# app/api/notifications.py
import uuid

from fastapi import APIRouter, Depends, Query, Request, status
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.redis import redis_client
from app.db.session import get_db
from app.models.user import User
from app.schemas.notifications import (
    DeviceTokenRequest,
    MarkAllReadResponse,
    NotificationPreferenceRead,
    NotificationPreferenceUpdateRequest,
    NotificationRead,
)
from app.schemas.shared import PaginatedResponse, PaginationParams, pagination_params
from app.services import notifications as notifications_service

router = APIRouter(prefix="/notifications", tags=["notifications"])

_SSE_HEARTBEAT_SECONDS = 15
_SSE_HEADERS = {
    "Cache-Control": "no-cache, no-transform",
    "Connection": "keep-alive",
    "X-Accel-Buffering": "no",
}


@router.get("", response_model=PaginatedResponse[NotificationRead], status_code=status.HTTP_200_OK)
async def list_notifications(
    unread_only: bool = Query(default=False),
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[NotificationRead]:
    notifications, total = await notifications_service.list_notifications(
        session, current_user.id, pagination, unread_only=unread_only
    )
    return PaginatedResponse(items=notifications, total=total, limit=pagination.limit, offset=pagination.offset)


@router.get("/stream")
async def stream_notifications(
    request: Request, current_user: User = Depends(get_current_user)
) -> StreamingResponse:
    channel = notifications_service.notification_stream_channel(current_user.id)

    async def event_generator():
        pubsub = redis_client.pubsub()
        await pubsub.subscribe(channel)
        try:
            yield "retry: 5000\n\n"
            while True:
                if await request.is_disconnected():
                    break
                message = await pubsub.get_message(
                    ignore_subscribe_messages=True, timeout=_SSE_HEARTBEAT_SECONDS
                )
                if message is None:
                    yield ": heartbeat\n\n"
                    continue
                yield f"data: {message['data']}\n\n"
        finally:
            await pubsub.unsubscribe(channel)
            await pubsub.close()

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers=_SSE_HEADERS,
    )


@router.patch("/{notification_id}/read", response_model=NotificationRead, status_code=status.HTTP_200_OK)
async def mark_notification_read(
    notification_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> NotificationRead:
    notification = await notifications_service.mark_notification_read(session, current_user.id, notification_id)
    return NotificationRead.model_validate(notification)


@router.post("/read-all", response_model=MarkAllReadResponse, status_code=status.HTTP_200_OK)
async def mark_all_notifications_read(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> MarkAllReadResponse:
    marked_count = await notifications_service.mark_all_notifications_read(session, current_user.id)
    return MarkAllReadResponse(marked_count=marked_count)


@router.get("/preferences", response_model=NotificationPreferenceRead, status_code=status.HTTP_200_OK)
async def get_notification_preferences(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> NotificationPreferenceRead:
    preference = await notifications_service.get_notification_preference(session, current_user.id)
    return NotificationPreferenceRead.model_validate(preference)


@router.patch("/preferences", response_model=NotificationPreferenceRead, status_code=status.HTTP_200_OK)
async def update_notification_preferences(
    payload: NotificationPreferenceUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> NotificationPreferenceRead:
    preference = await notifications_service.update_notification_preference(session, current_user.id, payload)
    return NotificationPreferenceRead.model_validate(preference)


@router.post("/device-tokens", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def register_device_token(
    payload: DeviceTokenRequest, current_user: User = Depends(get_current_user)
) -> None:
    await notifications_service.register_device_token(current_user.id, payload.device_token)


@router.delete("/device-tokens", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def unregister_device_token(
    payload: DeviceTokenRequest, current_user: User = Depends(get_current_user)
) -> None:
    await notifications_service.unregister_device_token(current_user.id, payload.device_token)