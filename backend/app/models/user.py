# app/models/user.py
import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class AuthProvider(str, enum.Enum):
    PASSWORD = "password"
    GOOGLE = "google"


class User(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    hashed_password: Mapped[str | None] = mapped_column(String(255), nullable=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    avatar_public_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    timezone: Mapped[str] = mapped_column(String(64), nullable=False, default="UTC", server_default="UTC")
    auth_provider: Mapped[AuthProvider] = mapped_column(
        SqlEnum(
            AuthProvider,
            name="auth_provider",
            native_enum=False,
            validate_strings=True,
            create_constraint=True,
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
        ),
        nullable=False,
        default=AuthProvider.PASSWORD,
        server_default=AuthProvider.PASSWORD.value,
    )
    google_user_id: Mapped[str | None] = mapped_column(String(255), unique=True, index=True, nullable=True)
    is_email_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")

    google_connection: Mapped["GoogleConnection | None"] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    notification_preference: Mapped["NotificationPreference | None"] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )


class GoogleConnection(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "google_connections"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True, nullable=False
    )
    google_account_email: Mapped[str] = mapped_column(String(255), nullable=False)
    access_token: Mapped[str] = mapped_column(String(2048), nullable=False)
    refresh_token: Mapped[str] = mapped_column(String(2048), nullable=False)
    scope: Mapped[str] = mapped_column(String(512), nullable=False)
    token_expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    user: Mapped["User"] = relationship(back_populates="google_connection")