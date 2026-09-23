# app/db/redis.py
from collections.abc import AsyncGenerator

from redis.asyncio import Redis, from_url

from app.core.config import get_settings

_settings = get_settings()
_REDIS_MAX_CONNECTIONS = 200
_REDIS_SOCKET_CONNECT_TIMEOUT_SECONDS = 5
_REDIS_HEALTH_CHECK_INTERVAL_SECONDS = 30

redis_client: Redis = from_url(
    _settings.REDIS_URL,
    decode_responses=True,
    max_connections=_REDIS_MAX_CONNECTIONS,
    socket_connect_timeout=_REDIS_SOCKET_CONNECT_TIMEOUT_SECONDS,
    socket_keepalive=True,
    health_check_interval=_REDIS_HEALTH_CHECK_INTERVAL_SECONDS,
)


async def get_redis() -> AsyncGenerator[Redis, None]:
    yield redis_client


async def check_redis_connectivity() -> bool:
    pong = await redis_client.ping()
    return bool(pong)