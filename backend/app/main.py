# app/main.py
import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request, Response, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from slowapi.errors import RateLimitExceeded
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api import ai, auth, health, notes, notifications, personal, reviews, shared, users, work
from app.core.config import get_settings
from app.core.exceptions import AppError
from app.core.logging import configure_logging, get_logger
from app.core.middleware import setup_middleware
from app.db.migrations_runner import run_database_migrations
from app.models import health as _health_module
from app.models import notes as _notes_module
from app.models import notifications as _notifications_module
from app.models import personal as _personal_module
from app.models import reviews as _reviews_module
from app.models import user as _user_module
from app.models import work as _work_module
from app.schemas.shared import ErrorDetail, ErrorResponse
from app.services.notifications import register_notification_event_handlers

_registered_models = (
    _health_module,
    _notes_module,
    _notifications_module,
    _personal_module,
    _reviews_module,
    _user_module,
    _work_module,
)

_settings = get_settings()
logger = get_logger(__name__)
_is_production = _settings.ENVIRONMENT == "production"

_FAVICON_PATH = Path(__file__).resolve().parent.parent / "favicon.png"
_FAVICON_FALLBACK_SVG = (
    b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
    b'<path d="M32 4L56 18v28L32 60 8 46V18z" fill="#4F46E5"/>'
    b'<path d="M22 20l10 24 10-24" fill="none" stroke="#FFFFFF" stroke-width="6"'
    b' stroke-linecap="round" stroke-linejoin="round"/></svg>'
)
_FAVICON_CACHE_HEADERS = {"Cache-Control": "public, max-age=604800, immutable"}


def _load_favicon() -> tuple[bytes, str]:
    if _FAVICON_PATH.is_file():
        return _FAVICON_PATH.read_bytes(), "image/png"
    return _FAVICON_FALLBACK_SVG, "image/svg+xml"


_FAVICON_BYTES, _FAVICON_MEDIA_TYPE = _load_favicon()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    configure_logging()
    try:
        await asyncio.to_thread(run_database_migrations)
    except Exception as exc:
        logger.error("startup_migrations_failed", error=str(exc))
        raise
    register_notification_event_handlers()
    yield


app = FastAPI(
    title="VIVRE",
    version="1.0.0",
    lifespan=lifespan,
    docs_url=None if _is_production else "/docs",
    redoc_url=None if _is_production else "/redoc",
    openapi_url=None if _is_production else "/openapi.json",
)
setup_middleware(app)


@app.get("/favicon.png", include_in_schema=False)
@app.get("/favicon.ico", include_in_schema=False)
async def favicon() -> Response:
    return Response(
        content=_FAVICON_BYTES,
        media_type=_FAVICON_MEDIA_TYPE,
        headers=_FAVICON_CACHE_HEADERS,
    )


@app.get("/", include_in_schema=False)
async def root() -> dict:
    return {
        "service": "VIVRE",
        "version": "1.0.0",
        "status": "operational",
        "environment": _settings.ENVIRONMENT,
    }


@app.head("/", include_in_schema=False)
async def root_head() -> Response:
    return Response(status_code=status.HTTP_200_OK)


@app.exception_handler(AppError)
async def handle_app_error(request: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(error=ErrorDetail(code=exc.code, message=exc.message)).model_dump(),
    )


@app.exception_handler(StarletteHTTPException)
async def handle_http_exception(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(error=ErrorDetail(code="http_error", message=str(exc.detail))).model_dump(),
    )


@app.exception_handler(RequestValidationError)
async def handle_request_validation_error(request: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        content=ErrorResponse(
            error=ErrorDetail(code="validation_error", message="Request validation failed")
        ).model_dump(),
    )


@app.exception_handler(RateLimitExceeded)
async def handle_rate_limit_exceeded(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        content=ErrorResponse(
            error=ErrorDetail(code="rate_limit_exceeded", message="Rate limit exceeded")
        ).model_dump(),
    )


@app.exception_handler(Exception)
async def handle_unexpected_error(request: Request, exc: Exception) -> JSONResponse:
    logger.error(
        "unhandled_exception",
        path=request.url.path,
        method=request.method,
        error=str(exc),
        exc_info=exc,
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=ErrorResponse(
            error=ErrorDetail(code="internal_error", message="An unexpected error occurred")
        ).model_dump(),
    )


app.include_router(auth.router)
app.include_router(users.router)
app.include_router(notes.router)
app.include_router(work.router)
app.include_router(personal.router)
app.include_router(health.router)
app.include_router(reviews.router)
app.include_router(ai.router)
app.include_router(notifications.router)
app.include_router(shared.router)