# app/api/users.py
import asyncio

from fastapi import APIRouter, Depends, File, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.core.exceptions import NotFoundError
from app.db.session import get_db
from app.integrations.google import build_authorization_url, exchange_code_for_tokens
from app.models.user import User
from app.schemas.user import (
    AvatarUploadResponse,
    GoogleAuthorizationURLResponse,
    GoogleConnectionRead,
    UserRead,
    UserUpdateRequest,
)
from app.services import users as users_service
from app.services.auth import invalidate_user_cache
from app.services.shared import read_upload_file_within_limit

router = APIRouter(prefix="/users", tags=["users"])
_settings = get_settings()


@router.get("/me", response_model=UserRead, status_code=status.HTTP_200_OK)
async def get_my_profile(current_user: User = Depends(get_current_user)) -> User:
    return current_user


@router.patch("/me", response_model=UserRead, status_code=status.HTTP_200_OK)
async def update_my_profile(
    payload: UserUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> User:
    user = await users_service.update_user_profile(session, current_user.id, payload)
    await invalidate_user_cache(current_user.id)
    return user


@router.post("/me/avatar", response_model=AvatarUploadResponse, status_code=status.HTTP_200_OK)
async def upload_my_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> AvatarUploadResponse:
    file_bytes = await read_upload_file_within_limit(
        file, _settings.MAX_UPLOAD_BYTES, _settings.UPLOAD_CHUNK_SIZE_BYTES
    )
    avatar_url, avatar_public_id = await users_service.upload_avatar(
        session, current_user.id, file_bytes, file.content_type or ""
    )
    await invalidate_user_cache(current_user.id)
    return AvatarUploadResponse(avatar_url=avatar_url, avatar_public_id=avatar_public_id)


@router.delete("/me/avatar", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_my_avatar(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await users_service.delete_avatar(session, current_user.id)
    await invalidate_user_cache(current_user.id)


@router.get("/me/google/authorize-url", response_model=GoogleAuthorizationURLResponse, status_code=status.HTTP_200_OK)
async def get_google_authorize_url(current_user: User = Depends(get_current_user)) -> GoogleAuthorizationURLResponse:
    state = await users_service.create_google_oauth_state(current_user.id)
    authorization_url = await asyncio.to_thread(build_authorization_url, state)
    return GoogleAuthorizationURLResponse(authorization_url=authorization_url)


@router.get("/me/google", response_model=GoogleConnectionRead, status_code=status.HTTP_200_OK)
async def get_google_connection_status(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> GoogleConnectionRead:
    connection = await users_service.get_google_connection(session, current_user.id)
    if connection is None:
        raise NotFoundError("No Google connection found")
    return GoogleConnectionRead.model_validate(connection)


@router.get("/me/google/callback", response_model=GoogleConnectionRead, status_code=status.HTTP_200_OK)
async def google_oauth_callback(
    code: str,
    state: str,
    session: AsyncSession = Depends(get_db),
) -> GoogleConnectionRead:
    user_id = await users_service.consume_google_oauth_state(state)
    user = await session.get(User, user_id)
    if user is None:
        raise NotFoundError("User not found")
    tokens = await asyncio.to_thread(exchange_code_for_tokens, code)
    connection = await users_service.upsert_google_connection(
        session,
        user.id,
        google_account_email=tokens["google_account_email"] or user.email,
        access_token=str(tokens["access_token"]),
        refresh_token=tokens["refresh_token"],
        scope=str(tokens["scope"]),
        token_expires_at=tokens["expires_at"],
    )
    return GoogleConnectionRead.model_validate(connection)


@router.delete("/me/google", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def disconnect_google_account(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await users_service.disconnect_google(session, current_user.id)