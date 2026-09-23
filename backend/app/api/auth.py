# app/api/auth.py
from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.middleware import limiter
from app.db.session import get_db
from app.schemas.shared import MessageResponse
from app.schemas.user import (
    EmailOTPRequest,
    EmailVerificationConfirmRequest,
    ForgotPasswordRequest,
    GoogleLoginRequest,
    RefreshTokenRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserLoginRequest,
    UserSignupRequest,
)
from app.services import auth as auth_service

router = APIRouter(prefix="/auth", tags=["auth"])
_settings = get_settings()


@router.post("/signup", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(_settings.AUTH_RATE_LIMIT)
async def signup(
    request: Request,
    payload: UserSignupRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    _, tokens = await auth_service.signup_user(session, payload)
    return tokens


@router.post("/login", response_model=TokenResponse, status_code=status.HTTP_200_OK)
@limiter.limit(_settings.AUTH_RATE_LIMIT)
async def login(
    request: Request,
    payload: UserLoginRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    _, tokens = await auth_service.authenticate_user(session, payload)
    return tokens


@router.post("/google", response_model=TokenResponse, status_code=status.HTTP_200_OK)
@limiter.limit(_settings.AUTH_RATE_LIMIT)
async def login_with_google(
    request: Request,
    payload: GoogleLoginRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    _, tokens = await auth_service.login_with_google(session, payload.id_token)
    return tokens


@router.post("/refresh", response_model=TokenResponse, status_code=status.HTTP_200_OK)
@limiter.limit(_settings.AUTH_RATE_LIMIT)
async def refresh(
    request: Request,
    payload: RefreshTokenRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    return await auth_service.refresh_access_token(session, payload.refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
@limiter.limit(_settings.AUTH_RATE_LIMIT)
async def logout(request: Request, payload: RefreshTokenRequest) -> None:
    await auth_service.revoke_refresh_session(payload.refresh_token)


@router.post("/email/verify/request", response_model=MessageResponse, status_code=status.HTTP_200_OK)
@limiter.limit(_settings.AUTH_RATE_LIMIT)
async def request_email_verification(
    request: Request,
    payload: EmailOTPRequest,
    session: AsyncSession = Depends(get_db),
) -> MessageResponse:
    await auth_service.request_email_verification(session, payload.email)
    return MessageResponse(message="If this email is registered and unverified, a verification code has been sent")


@router.post("/email/verify", response_model=MessageResponse, status_code=status.HTTP_200_OK)
@limiter.limit(_settings.AUTH_RATE_LIMIT)
async def confirm_email_verification(
    request: Request,
    payload: EmailVerificationConfirmRequest,
    session: AsyncSession = Depends(get_db),
) -> MessageResponse:
    await auth_service.confirm_email_verification(session, payload.email, payload.otp)
    return MessageResponse(message="Email verified successfully")


@router.post("/password/forgot", response_model=MessageResponse, status_code=status.HTTP_200_OK)
@limiter.limit(_settings.AUTH_RATE_LIMIT)
async def forgot_password(
    request: Request,
    payload: ForgotPasswordRequest,
    session: AsyncSession = Depends(get_db),
) -> MessageResponse:
    await auth_service.request_password_reset(session, payload.email)
    return MessageResponse(message="If this email is registered, a password reset code has been sent")


@router.post("/password/reset", response_model=MessageResponse, status_code=status.HTTP_200_OK)
@limiter.limit(_settings.AUTH_RATE_LIMIT)
async def reset_password(
    request: Request,
    payload: ResetPasswordRequest,
    session: AsyncSession = Depends(get_db),
) -> MessageResponse:
    await auth_service.confirm_password_reset(session, payload.email, payload.otp, payload.new_password)
    return MessageResponse(message="Password reset successfully")