# app/core/middleware.py
import re
import time
import uuid

import structlog
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address
from starlette.middleware.cors import CORSMiddleware
from starlette.types import ASGIApp, Receive, Scope, Send

from app.core.config import get_settings
from app.core.constants import REQUEST_ID_HEADER_NAME
from app.core.exceptions import PayloadTooLargeError
from app.core.logging import get_worker_id
from app.core.security import decode_token

_settings = get_settings()

_REQUEST_ID_PATTERN = re.compile(r"^[A-Za-z0-9._-]{1,128}$")
_REQUEST_ID_HEADER_BYTES = REQUEST_ID_HEADER_NAME.lower().encode("latin-1")
_PAYLOAD_TOO_LARGE_MESSAGE = "request body exceeds the maximum allowed size"
_DOCS_PATHS = {"/docs", "/redoc", "/openapi.json"}
_DOCS_CSP = b"default-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; img-src 'self' data: https://fastapi.tiangolo.com"
_DEFAULT_CSP = b"default-src 'none'; frame-ancestors 'none'"


def rate_limit_key(request: Request) -> str:
    auth_header = request.headers.get("authorization")
    if auth_header and auth_header.lower().startswith("bearer "):
        token = auth_header[7:]
        try:
            payload = decode_token(token)
        except Exception:
            payload = None
        if payload and payload.get("type") == "access" and payload.get("sub"):
            return f"user:{payload['sub']}"
    return f"ip:{get_remote_address(request)}"


limiter = Limiter(key_func=rate_limit_key, storage_uri=_settings.REDIS_URL)


class ProxyAwareClientMiddleware:
    def __init__(self, app: ASGIApp, trust_proxy_headers: bool) -> None:
        self.app = app
        self.trust_proxy_headers = trust_proxy_headers

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] == "http" and self.trust_proxy_headers:
            raw_headers = dict(scope.get("headers") or [])
            forwarded_for = raw_headers.get(b"x-forwarded-for")
            if forwarded_for:
                client_ip = forwarded_for.decode("latin-1").split(",")[0].strip()
                if client_ip:
                    original_client = scope.get("client") or ("", 0)
                    original_port = original_client[1] if len(original_client) > 1 else 0
                    scope["client"] = (client_ip, original_port)
        await self.app(scope, receive, send)


class RequestCorrelationMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        raw_headers = dict(scope.get("headers") or [])
        incoming_request_id = raw_headers.get(_REQUEST_ID_HEADER_BYTES)
        request_id = str(uuid.uuid4())
        if incoming_request_id is not None:
            decoded = incoming_request_id.decode("latin-1")
            if _REQUEST_ID_PATTERN.match(decoded):
                request_id = decoded

        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=request_id, worker=get_worker_id())

        async def send_wrapper(message: dict) -> None:
            if message["type"] == "http.response.start":
                response_headers = list(message.get("headers", []))
                response_headers.append((_REQUEST_ID_HEADER_BYTES, request_id.encode("latin-1")))
                message["headers"] = response_headers
            await send(message)

        await self.app(scope, receive, send_wrapper)


class RequestGuardMiddleware:
    def __init__(self, app: ASGIApp, max_body_bytes: int) -> None:
        self.app = app
        self.max_body_bytes = max_body_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        raw_headers = dict(scope.get("headers") or [])
        content_length_header = raw_headers.get(b"content-length")
        if content_length_header is not None:
            try:
                declared_length = int(content_length_header)
            except ValueError:
                declared_length = 0
            if declared_length > self.max_body_bytes:
                response = JSONResponse(
                    status_code=PayloadTooLargeError.status_code,
                    content={
                        "error": {
                            "code": PayloadTooLargeError.code,
                            "message": _PAYLOAD_TOO_LARGE_MESSAGE,
                        }
                    },
                )
                await response(scope, receive, send)
                return

        bytes_received = 0

        async def receive_wrapper() -> dict:
            nonlocal bytes_received
            message = await receive()
            if message["type"] == "http.request":
                bytes_received += len(message.get("body", b""))
                if bytes_received > self.max_body_bytes:
                    raise PayloadTooLargeError(_PAYLOAD_TOO_LARGE_MESSAGE)
            return message

        started_at = time.perf_counter()
        request_path = scope.get("path", "")

        async def send_wrapper(message: dict) -> None:
            if message["type"] == "http.response.start":
                headers = list(message.get("headers", []))
                existing_header_names = {name.lower() for name, _ in headers}
                elapsed_ms = f"{(time.perf_counter() - started_at) * 1000:.2f}".encode("latin-1")
                csp_value = _DOCS_CSP if request_path in _DOCS_PATHS else _DEFAULT_CSP
                headers.extend(
                    [
                        (b"x-process-time-ms", elapsed_ms),
                        (b"x-content-type-options", b"nosniff"),
                        (b"x-frame-options", b"DENY"),
                        (b"strict-transport-security", b"max-age=63072000; includeSubDomains; preload"),
                        (b"referrer-policy", b"no-referrer"),
                        (b"permissions-policy", b"geolocation=(), camera=(), microphone=(), payment=()"),
                        (b"cross-origin-opener-policy", b"same-origin"),
                        (b"x-permitted-cross-domain-policies", b"none"),
                        (b"content-security-policy", csp_value),
                    ]
                )
                if b"cache-control" not in existing_header_names:
                    headers.append((b"cache-control", b"no-store"))
                message["headers"] = headers
            await send(message)

        await self.app(scope, receive_wrapper, send_wrapper)


def setup_middleware(app: FastAPI) -> None:
    settings = get_settings()
    app.state.limiter = limiter
    app.add_middleware(SlowAPIMiddleware)
    app.add_middleware(RequestGuardMiddleware, max_body_bytes=settings.MAX_REQUEST_BODY_BYTES)
    app.add_middleware(RequestCorrelationMiddleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(ProxyAwareClientMiddleware, trust_proxy_headers=settings.TRUST_PROXY_HEADERS)