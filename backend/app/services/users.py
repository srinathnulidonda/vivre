# app/services/users.py
import asyncio
import secrets
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.crypto import decrypt_secret, encrypt_secret
from app.core.exceptions import NotFoundError, PermissionDeniedError, ValidationError
from app.core.security import create_oauth_state_token, decode_token
from app.db.redis import redis_client
from app.integrations.cloudinary import delete_image, upload_image
from app.models.user import GoogleConnection, User
from app.schemas.user import UserUpdateRequest

_settings = get_settings()
_GOOGLE_OAUTH_STATE_KEY_PREFIX = "google_oauth_state:"


async def _get_user_or_raise(session: AsyncSession, user_id: uuid.UUID) -> User:
    user = await session.get(User, user_id)
    if user is None:
        raise NotFoundError("User not found")
    return user


async def get_user_profile(session: AsyncSession, user_id: uuid.UUID) -> User:
    return await _get_user_or_raise(session, user_id)


async def update_user_profile(
    session: AsyncSession, user_id: uuid.UUID, request: UserUpdateRequest
) -> User:
    user = await _get_user_or_raise(session, user_id)
    if request.name is not None:
        user.name = request.name
    if request.timezone is not None:
        user.timezone = request.timezone
    await session.commit()
    await session.refresh(user)
    return user


def _validate_upload(content_type: str, file_size_bytes: int) -> None:
    if content_type not in _settings.allowed_image_content_types_list:
        raise ValidationError(f"Unsupported image content type: {content_type}")
    if file_size_bytes > _settings.MAX_UPLOAD_BYTES:
        raise ValidationError("Image exceeds the maximum allowed upload size")


async def upload_avatar(
    session: AsyncSession, user_id: uuid.UUID, file_bytes: bytes, content_type: str
) -> tuple[str, str]:
    _validate_upload(content_type, len(file_bytes))
    user = await _get_user_or_raise(session, user_id)
    previous_public_id = user.avatar_public_id
    avatar_url, avatar_public_id = await asyncio.to_thread(
        upload_image, file_bytes, folder=f"vivre/avatars/{user_id}", public_id="avatar"
    )
    user.avatar_url = avatar_url
    user.avatar_public_id = avatar_public_id
    await session.commit()
    if previous_public_id and previous_public_id != avatar_public_id:
        await asyncio.to_thread(delete_image, previous_public_id)
    return avatar_url, avatar_public_id


async def delete_avatar(session: AsyncSession, user_id: uuid.UUID) -> None:
    user = await _get_user_or_raise(session, user_id)
    if user.avatar_public_id:
        await asyncio.to_thread(delete_image, user.avatar_public_id)
    user.avatar_url = None
    user.avatar_public_id = None
    await session.commit()


async def create_google_oauth_state(user_id: uuid.UUID) -> str:
    nonce = secrets.token_urlsafe(16)
    token = create_oauth_state_token(user_id, nonce)
    await redis_client.set(
        f"{_GOOGLE_OAUTH_STATE_KEY_PREFIX}{nonce}",
        str(user_id),
        ex=_settings.GOOGLE_OAUTH_STATE_TTL_SECONDS,
    )
    return token


async def consume_google_oauth_state(state: str) -> uuid.UUID:
    try:
        payload = decode_token(state)
    except Exception as exc:
        raise PermissionDeniedError("Invalid or expired Google authorization state") from exc
    if payload.get("type") != "google_oauth_state":
        raise PermissionDeniedError("Invalid Google authorization state")
    nonce = payload.get("nonce")
    user_id_raw = payload.get("sub")
    if not nonce or not user_id_raw:
        raise PermissionDeniedError("Malformed Google authorization state")
    stored_user_id = await redis_client.getdel(f"{_GOOGLE_OAUTH_STATE_KEY_PREFIX}{nonce}")
    if stored_user_id is None or stored_user_id != user_id_raw:
        raise PermissionDeniedError("Google authorization state has already been used or expired")
    return uuid.UUID(user_id_raw)


async def upsert_google_connection(
    session: AsyncSession,
    user_id: uuid.UUID,
    google_account_email: str,
    access_token: str,
    refresh_token: str | None,
    scope: str,
    token_expires_at: object,
) -> GoogleConnection:
    result = await session.execute(select(GoogleConnection).where(GoogleConnection.user_id == user_id))
    connection = result.scalar_one_or_none()
    if connection is None:
        if not refresh_token:
            raise ValidationError(
                "Google did not return a refresh token; please reconnect and grant offline access"
            )
        connection = GoogleConnection(
            user_id=user_id,
            google_account_email=google_account_email,
            refresh_token=encrypt_secret(refresh_token),
        )
        session.add(connection)
    else:
        if refresh_token:
            connection.refresh_token = encrypt_secret(refresh_token)
        connection.google_account_email = google_account_email
    connection.access_token = encrypt_secret(access_token)
    connection.scope = scope
    connection.token_expires_at = token_expires_at
    await session.commit()
    await session.refresh(connection)
    return connection


async def get_google_connection(session: AsyncSession, user_id: uuid.UUID) -> GoogleConnection | None:
    result = await session.execute(select(GoogleConnection).where(GoogleConnection.user_id == user_id))
    return result.scalar_one_or_none()


async def get_decrypted_google_tokens(connection: GoogleConnection) -> tuple[str, str]:
    return decrypt_secret(connection.access_token), decrypt_secret(connection.refresh_token)


async def disconnect_google(session: AsyncSession, user_id: uuid.UUID) -> None:
    result = await session.execute(select(GoogleConnection).where(GoogleConnection.user_id == user_id))
    connection = result.scalar_one_or_none()
    if connection is None:
        raise NotFoundError("No Google connection found")
    await session.delete(connection)
    await session.commit()