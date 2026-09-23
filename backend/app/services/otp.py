# app/services/otp.py
import hashlib
import secrets
from enum import Enum

from app.core.config import get_settings
from app.core.exceptions import ConflictError, ValidationError
from app.db.redis import redis_client

_settings = get_settings()
_OTP_KEY_PREFIX = "otp:"
_OTP_ATTEMPTS_KEY_PREFIX = "otp_attempts:"
_OTP_COOLDOWN_KEY_PREFIX = "otp_cooldown:"


class OTPPurpose(str, Enum):
    EMAIL_VERIFICATION = "email_verification"
    PASSWORD_RESET = "password_reset"


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _otp_key(purpose: OTPPurpose, email: str) -> str:
    return f"{_OTP_KEY_PREFIX}{purpose.value}:{_normalize_email(email)}"


def _attempts_key(purpose: OTPPurpose, email: str) -> str:
    return f"{_OTP_ATTEMPTS_KEY_PREFIX}{purpose.value}:{_normalize_email(email)}"


def _cooldown_key(purpose: OTPPurpose, email: str) -> str:
    return f"{_OTP_COOLDOWN_KEY_PREFIX}{purpose.value}:{_normalize_email(email)}"


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


def _generate_code() -> str:
    return "".join(secrets.choice("0123456789") for _ in range(_settings.OTP_LENGTH))


async def issue_otp(purpose: OTPPurpose, email: str) -> str:
    if await redis_client.exists(_cooldown_key(purpose, email)):
        raise ConflictError("A code was already sent recently. Please wait before requesting another")
    code = _generate_code()
    await redis_client.set(_otp_key(purpose, email), _hash_code(code), ex=_settings.OTP_TTL_SECONDS)
    await redis_client.delete(_attempts_key(purpose, email))
    await redis_client.set(_cooldown_key(purpose, email), "1", ex=_settings.OTP_RESEND_COOLDOWN_SECONDS)
    return code


async def verify_otp(purpose: OTPPurpose, email: str, code: str) -> None:
    key = _otp_key(purpose, email)
    stored_hash = await redis_client.get(key)
    if stored_hash is None:
        raise ValidationError("This code is invalid or has expired")
    attempts_key = _attempts_key(purpose, email)
    attempts = await redis_client.incr(attempts_key)
    if attempts == 1:
        remaining_ttl = await redis_client.ttl(key)
        await redis_client.expire(
            attempts_key, remaining_ttl if remaining_ttl and remaining_ttl > 0 else _settings.OTP_TTL_SECONDS
        )
    if attempts > _settings.OTP_MAX_ATTEMPTS:
        await redis_client.delete(key)
        await redis_client.delete(attempts_key)
        raise ValidationError("Too many incorrect attempts. Please request a new code")
    if stored_hash != _hash_code(code):
        raise ValidationError("Incorrect code")
    await redis_client.delete(key)
    await redis_client.delete(attempts_key)