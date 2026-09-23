# app/core/config.py
import json
from functools import lru_cache
from typing import Any

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

from app.db.neon_utils import ensure_asyncpg_driver, parse_ssl_mode


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True, extra="ignore")

    ENVIRONMENT: str = "development"
    LOG_LEVEL: str = "INFO"

    DATABASE_URL: str
    DATABASE_POOL_SIZE: int = 10
    DATABASE_MAX_OVERFLOW: int = 5
    DATABASE_POOL_RECYCLE_SECONDS: int = 1800
    DATABASE_POOL_TIMEOUT_SECONDS: int = 30
    DATABASE_STATEMENT_TIMEOUT_SECONDS: int = 60
    DATABASE_CONNECT_TIMEOUT_SECONDS: int = 10
    MIGRATIONS_CONNECT_TIMEOUT_SECONDS: int = 10

    REDIS_URL: str

    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    CLOUDINARY_CLOUD_NAME: str
    CLOUDINARY_API_KEY: str
    CLOUDINARY_API_SECRET: str

    FIREBASE_SERVICE_ACCOUNT_JSON: str | None = None

    TOKEN_ENCRYPTION_KEY: str | None = None
    GOOGLE_OAUTH_STATE_TTL_SECONDS: int = 600

    TRUST_PROXY_HEADERS: bool = True

    BREVO_API_KEY: str
    BREVO_FROM_EMAIL: str
    BREVO_FROM_NAME: str

    GOOGLE_CLIENT_ID: str | None = None
    GOOGLE_CLIENT_SECRET: str | None = None
    GOOGLE_REDIRECT_URI: str | None = None

    AI_PROVIDER: str = "openai"
    AI_PROVIDER_API_KEY: str | None = None
    AI_MODEL_NAME: str | None = None

    CORS_ORIGINS: str = ""

    DEFAULT_PAGE_SIZE: int = 20
    MAX_PAGE_SIZE: int = 100

    AUTH_RATE_LIMIT: str = "5/minute"
    AI_RATE_LIMIT: str = "20/minute"

    MAX_UPLOAD_BYTES: int = 5242880
    MAX_REQUEST_BODY_BYTES: int = 10485760
    UPLOAD_CHUNK_SIZE_BYTES: int = 65536
    ALLOWED_IMAGE_CONTENT_TYPES: str = "image/jpeg,image/png,image/webp"

    MAX_NOTIFICATION_DELIVERY_ATTEMPTS: int = 5

    DIGEST_DISPATCH_BATCH_SIZE: int = 500
    DAILY_REVIEW_PROMPT_LOCAL_HOUR: int = 20
    WEEKLY_DIGEST_LOCAL_HOUR: int = 18
    WEEKLY_DIGEST_LOCAL_WEEKDAY: int = 6

    USER_CACHE_TTL_SECONDS: int = 60

    OTP_LENGTH: int = 6
    OTP_TTL_SECONDS: int = 600
    OTP_RESEND_COOLDOWN_SECONDS: int = 60
    OTP_MAX_ATTEMPTS: int = 5

    @property
    def direct_database_url(self) -> str:
        return self.DATABASE_URL

    @property
    def database_url(self) -> str:
        return ensure_asyncpg_driver(self.DATABASE_URL)

    @property
    def database_ssl_mode(self) -> str:
        return parse_ssl_mode(self.DATABASE_URL)

    @property
    def database_pool_size(self) -> int:
        return self.DATABASE_POOL_SIZE

    @property
    def database_max_overflow(self) -> int:
        return self.DATABASE_MAX_OVERFLOW

    @property
    def database_pool_recycle_seconds(self) -> int:
        return self.DATABASE_POOL_RECYCLE_SECONDS

    @property
    def database_pool_timeout_seconds(self) -> int:
        return self.DATABASE_POOL_TIMEOUT_SECONDS

    @property
    def database_statement_timeout_seconds(self) -> int:
        return self.DATABASE_STATEMENT_TIMEOUT_SECONDS

    @property
    def database_connect_timeout_seconds(self) -> int:
        return self.DATABASE_CONNECT_TIMEOUT_SECONDS

    @property
    def migrations_connect_timeout_seconds(self) -> int:
        return self.MIGRATIONS_CONNECT_TIMEOUT_SECONDS

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    @property
    def allowed_image_content_types_list(self) -> list[str]:
        return [
            content_type.strip()
            for content_type in self.ALLOWED_IMAGE_CONTENT_TYPES.split(",")
            if content_type.strip()
        ]

    @property
    def firebase_credentials_dict(self) -> dict[str, Any]:
        if not self.FIREBASE_SERVICE_ACCOUNT_JSON:
            raise RuntimeError("FIREBASE_SERVICE_ACCOUNT_JSON is not configured")
        raw_value = self.FIREBASE_SERVICE_ACCOUNT_JSON.strip()
        if raw_value.startswith("{"):
            return json.loads(raw_value)
        with open(raw_value, encoding="utf-8") as credential_file:
            return json.load(credential_file)

    @model_validator(mode="after")
    def validate_production_invariants(self) -> "Settings":
        if self.ENVIRONMENT == "production":
            origins = self.cors_origins_list
            if not origins or "*" in origins:
                raise ValueError("CORS_ORIGINS must be an explicit non-wildcard allow-list in production")
            if len(self.JWT_SECRET_KEY) < 32:
                raise ValueError("JWT_SECRET_KEY must be at least 32 characters in production")
            if not self.GOOGLE_CLIENT_ID:
                raise ValueError("GOOGLE_CLIENT_ID must be set in production")
            if self.GOOGLE_CLIENT_ID and not self.TOKEN_ENCRYPTION_KEY:
                raise ValueError("TOKEN_ENCRYPTION_KEY must be set in production when Google integration is enabled")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()