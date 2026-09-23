# app/services/auth.py
import asyncio
import json
import uuid
from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.email import (
    build_email_verification_email,
    build_password_changed_alert_email,
    build_password_reset_email,
)
from app.core.exceptions import ConflictError, PermissionDeniedError, ValidationError
from app.core.logging import get_logger
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.db.redis import redis_client
from app.integrations.brevo import send_transactional_email
from app.integrations.google_identity import verify_google_id_token
from app.models.user import AuthProvider, User
from app.schemas.user import TokenResponse, UserLoginRequest, UserSignupRequest
from app.services.otp import OTPPurpose, issue_otp, verify_otp

logger = get_logger(__name__)
_settings = get_settings()

_REFRESH_SESSION_KEY_PREFIX = "auth:session:"
_USER_SESSIONS_KEY_PREFIX = "auth:user_sessions:"
_USER_CACHE_KEY_PREFIX = "user_cache:"
_LOGIN_FAILURE_KEY_PREFIX = "auth:login_failures:"
_LOGIN_FAILURE_WINDOW_SECONDS = 300
_LOGIN_FAILURE_MAX_ATTEMPTS = 10
_DUMMY_HASH = hash_password("vivre-timing-defense-placeholder-value")


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _refresh_session_key(session_id: str) -> str:
    return f"{_REFRESH_SESSION_KEY_PREFIX}{session_id}"


def _user_sessions_key(user_id: uuid.UUID) -> str:
    return f"{_USER_SESSIONS_KEY_PREFIX}{user_id}"


def _user_cache_key(user_id: uuid.UUID) -> str:
    return f"{_USER_CACHE_KEY_PREFIX}{user_id}"


def _login_failure_key(email: str) -> str:
    return f"{_LOGIN_FAILURE_KEY_PREFIX}{email}"


async def cache_user_profile(user: User) -> None:
    payload = {
        "id": str(user.id),
        "email": user.email,
        "name": user.name,
        "avatar_url": user.avatar_url,
        "avatar_public_id": user.avatar_public_id,
        "timezone": user.timezone,
        "is_email_verified": user.is_email_verified,
        "created_at": user.created_at.isoformat(),
        "updated_at": user.updated_at.isoformat(),
    }
    await redis_client.set(
        _user_cache_key(user.id),
        json.dumps(payload),
        ex=_settings.USER_CACHE_TTL_SECONDS,
    )


async def invalidate_user_cache(user_id: uuid.UUID) -> None:
    await redis_client.delete(_user_cache_key(user_id))


async def _issue_token_pair(user_id: uuid.UUID, session_id: str | None = None) -> TokenResponse:
    access_token = create_access_token(user_id)
    refresh_token, jti, resolved_session_id = create_refresh_token(user_id, session_id=session_id)
    ttl_seconds = int(timedelta(days=_settings.REFRESH_TOKEN_EXPIRE_DAYS).total_seconds())
    await redis_client.set(_refresh_session_key(resolved_session_id), jti, ex=ttl_seconds)
    await redis_client.sadd(_user_sessions_key(user_id), resolved_session_id)
    await redis_client.expire(_user_sessions_key(user_id), ttl_seconds)
    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


async def revoke_all_sessions(user_id: uuid.UUID) -> None:
    sessions_key = _user_sessions_key(user_id)
    session_ids = await redis_client.smembers(sessions_key)
    for session_id in session_ids:
        await redis_client.delete(_refresh_session_key(session_id))
    await redis_client.delete(sessions_key)


async def send_email_verification_otp(user: User) -> None:
    if user.is_email_verified:
        return
    code = await issue_otp(OTPPurpose.EMAIL_VERIFICATION, user.email)
    subject, html_content = build_email_verification_email(code)
    await asyncio.to_thread(
        send_transactional_email,
        to_email=user.email,
        to_name=user.name,
        subject=subject,
        html_content=html_content,
    )


async def _send_password_reset_otp_email(user: User, code: str) -> None:
    subject, html_content = build_password_reset_email(code)
    await asyncio.to_thread(
        send_transactional_email,
        to_email=user.email,
        to_name=user.name,
        subject=subject,
        html_content=html_content,
    )


async def _send_password_changed_alert(user: User) -> None:
    subject, html_content = build_password_changed_alert_email()
    await asyncio.to_thread(
        send_transactional_email,
        to_email=user.email,
        to_name=user.name,
        subject=subject,
        html_content=html_content,
    )


async def signup_user(
    session: AsyncSession, request: UserSignupRequest
) -> tuple[User, TokenResponse]:
    email = _normalize_email(request.email)
    existing_result = await session.execute(select(User).where(User.email == email))
    if existing_result.scalar_one_or_none() is not None:
        raise ConflictError("An account with this email already exists")
    hashed_password = await asyncio.to_thread(hash_password, request.password)
    user = User(
        email=email,
        hashed_password=hashed_password,
        name=request.name,
        timezone=request.timezone,
        auth_provider=AuthProvider.PASSWORD,
    )
    session.add(user)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise ConflictError("An account with this email already exists")
    await session.refresh(user)
    tokens = await _issue_token_pair(user.id)
    try:
        await send_email_verification_otp(user)
    except Exception as exc:
        logger.error(
            "signup_verification_email_failed",
            user_id=str(user.id),
            error=str(exc),
        )
    return user, tokens


async def authenticate_user(
    session: AsyncSession, request: UserLoginRequest
) -> tuple[User, TokenResponse]:
    email = _normalize_email(request.email)
    failure_key = _login_failure_key(email)
    failure_count_raw = await redis_client.get(failure_key)
    if failure_count_raw is not None and int(failure_count_raw) >= _LOGIN_FAILURE_MAX_ATTEMPTS:
        raise PermissionDeniedError("Invalid email or password")
    result = await session.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    hash_to_check = user.hashed_password if (user is not None and user.hashed_password) else _DUMMY_HASH
    password_valid = await asyncio.to_thread(verify_password, request.password, hash_to_check)
    if user is None or user.hashed_password is None or not password_valid:
        pipeline = redis_client.pipeline()
        pipeline.incr(failure_key)
        pipeline.expire(failure_key, _LOGIN_FAILURE_WINDOW_SECONDS)
        await pipeline.execute()
        raise PermissionDeniedError("Invalid email or password")
    await redis_client.delete(failure_key)
    tokens = await _issue_token_pair(user.id)
    return user, tokens


async def login_with_google(session: AsyncSession, id_token: str) -> tuple[User, TokenResponse]:
    claims = verify_google_id_token(id_token)
    google_user_id = claims["sub"]
    email = _normalize_email(claims["email"])
    email_verified = bool(claims.get("email_verified", False))
    name = claims.get("name") or email.split("@")[0]
    avatar_url: str | None = claims.get("picture")

    result = await session.execute(select(User).where(User.google_user_id == google_user_id))
    user = result.scalar_one_or_none()

    if user is None:
        existing_result = await session.execute(select(User).where(User.email == email))
        user = existing_result.scalar_one_or_none()

        if user is None:
            user = User(
                email=email,
                hashed_password=None,
                name=name,
                avatar_url=avatar_url,
                auth_provider=AuthProvider.GOOGLE,
                google_user_id=google_user_id,
                is_email_verified=True,
            )
            session.add(user)
            try:
                await session.commit()
            except IntegrityError:
                await session.rollback()
                result = await session.execute(select(User).where(User.google_user_id == google_user_id))
                user = result.scalar_one_or_none()
                if user is None:
                    result = await session.execute(select(User).where(User.email == email))
                    user = result.scalar_one_or_none()
                if user is None:
                    raise
        else:
            if not email_verified:
                raise PermissionDeniedError("Unable to verify ownership of this email address")
            user.google_user_id = google_user_id
            user.is_email_verified = True
            await session.commit()

    await session.refresh(user)
    tokens = await _issue_token_pair(user.id)
    return user, tokens


async def request_email_verification(session: AsyncSession, email: str) -> None:
    normalized_email = _normalize_email(email)
    result = await session.execute(select(User).where(User.email == normalized_email))
    user = result.scalar_one_or_none()
    if user is None or user.is_email_verified:
        return
    try:
        await send_email_verification_otp(user)
    except ConflictError:
        pass
    except Exception as exc:
        logger.error(
            "email_verification_request_failed",
            user_id=str(user.id),
            error=str(exc),
        )


async def confirm_email_verification(session: AsyncSession, email: str, code: str) -> User:
    normalized_email = _normalize_email(email)
    result = await session.execute(select(User).where(User.email == normalized_email))
    user = result.scalar_one_or_none()
    if user is None:
        raise ValidationError("This code is invalid or has expired")
    await verify_otp(OTPPurpose.EMAIL_VERIFICATION, normalized_email, code)
    user.is_email_verified = True
    await session.commit()
    await session.refresh(user)
    await invalidate_user_cache(user.id)
    return user


async def request_password_reset(session: AsyncSession, email: str) -> None:
    normalized_email = _normalize_email(email)
    result = await session.execute(select(User).where(User.email == normalized_email))
    user = result.scalar_one_or_none()
    if user is None or user.hashed_password is None:
        return
    try:
        code = await issue_otp(OTPPurpose.PASSWORD_RESET, normalized_email)
    except ConflictError:
        return
    try:
        await _send_password_reset_otp_email(user, code)
    except Exception as exc:
        logger.error(
            "password_reset_email_failed",
            user_id=str(user.id),
            error=str(exc),
        )


async def confirm_password_reset(
    session: AsyncSession, email: str, code: str, new_password: str
) -> None:
    normalized_email = _normalize_email(email)
    result = await session.execute(select(User).where(User.email == normalized_email))
    user = result.scalar_one_or_none()
    if user is None:
        raise ValidationError("This code is invalid or has expired")
    await verify_otp(OTPPurpose.PASSWORD_RESET, normalized_email, code)
    user.hashed_password = await asyncio.to_thread(hash_password, new_password)
    if user.auth_provider != AuthProvider.PASSWORD:
        user.auth_provider = AuthProvider.PASSWORD
    await session.commit()
    await invalidate_user_cache(user.id)
    await revoke_all_sessions(user.id)
    try:
        await _send_password_changed_alert(user)
    except Exception as exc:
        logger.error(
            "password_changed_alert_email_failed",
            user_id=str(user.id),
            error=str(exc),
        )


async def refresh_access_token(session: AsyncSession, refresh_token: str) -> TokenResponse:
    try:
        payload = decode_token(refresh_token)
    except Exception as exc:
        raise PermissionDeniedError("Invalid or expired refresh token") from exc
    if payload.get("type") != "refresh":
        raise PermissionDeniedError("Invalid token type")
    session_id = payload.get("sid")
    jti = payload.get("jti")
    user_id_raw = payload.get("sub")
    if not session_id or not jti or not user_id_raw:
        raise PermissionDeniedError("Malformed refresh token")
    stored_jti = await redis_client.get(_refresh_session_key(session_id))
    if stored_jti is None or stored_jti != jti:
        await redis_client.delete(_refresh_session_key(session_id))
        raise PermissionDeniedError("Refresh token has been revoked or reused")
    user_result = await session.execute(select(User).where(User.id == uuid.UUID(user_id_raw)))
    user = user_result.scalar_one_or_none()
    if user is None:
        raise PermissionDeniedError("User no longer exists")
    return await _issue_token_pair(user.id, session_id=session_id)


async def revoke_refresh_session(refresh_token: str) -> None:
    try:
        payload = decode_token(refresh_token)
    except Exception as exc:
        raise PermissionDeniedError("Invalid refresh token") from exc
    session_id = payload.get("sid")
    if not session_id:
        raise PermissionDeniedError("Malformed refresh token")
    await redis_client.delete(_refresh_session_key(session_id))
    user_id_raw = payload.get("sub")
    if user_id_raw:
        await redis_client.srem(_user_sessions_key(uuid.UUID(user_id_raw)), session_id)


async def get_user_from_access_token(session: AsyncSession, access_token: str) -> User:
    try:
        payload = decode_token(access_token)
    except Exception as exc:
        raise PermissionDeniedError("Invalid or expired access token") from exc
    if payload.get("type") != "access":
        raise PermissionDeniedError("Invalid token type")
    user_id_raw = payload.get("sub")
    if not user_id_raw:
        raise PermissionDeniedError("Malformed access token")
    user_id = uuid.UUID(user_id_raw)
    cached_raw = await redis_client.get(_user_cache_key(user_id))
    if cached_raw is not None:
        cached_fields = json.loads(cached_raw)
        return User(
            id=uuid.UUID(cached_fields["id"]),
            email=cached_fields["email"],
            name=cached_fields["name"],
            avatar_url=cached_fields["avatar_url"],
            avatar_public_id=cached_fields.get("avatar_public_id"),
            timezone=cached_fields["timezone"],
            hashed_password=None,
            is_email_verified=cached_fields.get("is_email_verified", False),
            created_at=datetime.fromisoformat(cached_fields["created_at"]),
            updated_at=datetime.fromisoformat(cached_fields["updated_at"]),
        )
    result = await session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise PermissionDeniedError("User no longer exists")
    await cache_user_profile(user)
    return user