# app/db/session.py

from collections.abc import AsyncGenerator, AsyncIterator
from contextlib import asynccontextmanager

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import Settings, get_settings
from app.db.neon_utils import ensure_direct_neon_endpoint

_POOLER_HOST_MARKER = "-pooler."
_IDLE_IN_TRANSACTION_TIMEOUT_MS = 600_000


def _is_pooler_host(database_url: str) -> bool:
    direct_url = ensure_direct_neon_endpoint(database_url)
    return direct_url != database_url


def create_engine(settings: Settings) -> AsyncEngine:
    statement_timeout_ms = str(int(settings.database_statement_timeout_seconds * 1000))
    connect_args = {
        "timeout": settings.database_connect_timeout_seconds,
        "ssl": settings.database_ssl_mode,
        "server_settings": {
            "statement_timeout": statement_timeout_ms,
            "lock_timeout": statement_timeout_ms,
            "idle_in_transaction_session_timeout": str(_IDLE_IN_TRANSACTION_TIMEOUT_MS),
            "application_name": "vivre-api",
        },
    }
    if settings.database_ssl_mode == "disable":
        connect_args.pop("ssl")
    if _is_pooler_host(settings.DATABASE_URL):
        connect_args["statement_cache_size"] = 0
    return create_async_engine(
        settings.database_url,
        pool_size=settings.database_pool_size,
        max_overflow=settings.database_max_overflow,
        pool_pre_ping=True,
        pool_recycle=settings.database_pool_recycle_seconds,
        pool_use_lifo=True,
        pool_timeout=settings.database_pool_timeout_seconds,
        connect_args=connect_args,
    )


def create_session_factory(engine: AsyncEngine) -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(bind=engine, expire_on_commit=False, class_=AsyncSession)


_settings = get_settings()
engine = create_engine(_settings)
AsyncSessionLocal = create_session_factory(engine)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


@asynccontextmanager
async def get_session_context() -> AsyncIterator[AsyncSession]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def check_database_connectivity() -> bool:
    async with engine.connect() as connection:
        result = await connection.execute(text("SELECT 1"))
        return result.scalar_one() == 1