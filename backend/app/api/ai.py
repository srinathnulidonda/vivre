# app/api/ai.py
from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.core.middleware import limiter
from app.db.session import get_db
from app.models.user import User
from app.schemas.ai import (
    AICaptureRequest,
    AICaptureResponse,
    AIChatRequest,
    AIChatResponse,
    AIPlanRequest,
    AIPlanResponse,
)
from app.services import ai as ai_service

router = APIRouter(prefix="/ai", tags=["ai"])
_settings = get_settings()


@router.post("/chat", response_model=AIChatResponse, status_code=status.HTTP_200_OK)
@limiter.limit(_settings.AI_RATE_LIMIT)
async def chat(
    request: Request,
    payload: AIChatRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> AIChatResponse:
    return await ai_service.chat_with_ai(session, current_user, payload.messages)


@router.post("/capture", response_model=AICaptureResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(_settings.AI_RATE_LIMIT)
async def capture(
    request: Request,
    payload: AICaptureRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> AICaptureResponse:
    return await ai_service.capture_from_text(session, current_user, payload.raw_text)


@router.post("/plan", response_model=AIPlanResponse, status_code=status.HTTP_200_OK)
@limiter.limit(_settings.AI_RATE_LIMIT)
async def plan(
    request: Request,
    payload: AIPlanRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> AIPlanResponse:
    return await ai_service.plan_from_objective(session, current_user, payload.objective, payload.context)