# app/core/logging.py
import logging
import os
import sys
from collections.abc import MutableMapping
from typing import Any

import structlog

from app.core.config import get_settings

_REDACTED_KEYS: set[str] = {
    "password",
    "hashed_password",
    "token",
    "authorization",
    "refresh_token",
    "access_token",
    "secret",
    "jwt_secret_key",
    "api_key",
    "client_secret",
}


def _redact_sensitive_keys(
    logger: Any, method_name: str, event_dict: MutableMapping[str, Any]
) -> MutableMapping[str, Any]:
    for key in list(event_dict.keys()):
        if key.lower() in _REDACTED_KEYS:
            event_dict[key] = "***REDACTED***"
    return event_dict


def get_worker_id() -> str:
    return str(os.getpid())


def _resolve_log_level(raw_level: str) -> int:
    resolved = getattr(logging, raw_level.upper(), None)
    if isinstance(resolved, int):
        return resolved
    try:
        return int(raw_level)
    except (TypeError, ValueError):
        return logging.INFO


def configure_logging() -> None:
    settings = get_settings()
    resolved_level = _resolve_log_level(settings.LOG_LEVEL)
    logging.basicConfig(format="%(message)s", stream=sys.stdout, level=resolved_level)
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            _redact_sensitive_keys,
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(resolved_level),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str) -> structlog.typing.FilteringBoundLogger:
    return structlog.get_logger(name)