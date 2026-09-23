# app/core/security.py
import hashlib
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

import bcrypt
import jwt

from app.core.config import get_settings

_BCRYPT_ROUNDS = 12


def _prehash_password(plain_password: str) -> bytes:
    return hashlib.sha256(plain_password.encode("utf-8")).hexdigest().encode("ascii")


def hash_password(plain_password: str) -> str:
    return bcrypt.hashpw(_prehash_password(plain_password), bcrypt.gensalt(rounds=_BCRYPT_ROUNDS)).decode("ascii")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(_prehash_password(plain_password), hashed_password.encode("ascii"))
    except (ValueError, TypeError):
        return False


def create_access_token(user_id: uuid.UUID) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "type": "access",
        "iat": now,
        "exp": expires_at,
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(user_id: uuid.UUID, session_id: str | None = None) -> tuple[str, str, str]:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    resolved_session_id = session_id or str(uuid.uuid4())
    jti = str(uuid.uuid4())
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "type": "refresh",
        "sid": resolved_session_id,
        "iat": now,
        "exp": expires_at,
        "jti": jti,
    }
    token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return token, jti, resolved_session_id


def create_oauth_state_token(user_id: uuid.UUID, nonce: str) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "type": "google_oauth_state",
        "nonce": nonce,
        "iat": now,
        "exp": now + timedelta(seconds=settings.GOOGLE_OAUTH_STATE_TTL_SECONDS),
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    decoded: dict[str, Any] = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
    return decoded