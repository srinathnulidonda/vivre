# app/integrations/google_identity.py
from typing import Any

from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import id_token as google_id_token

from app.core.config import get_settings
from app.core.exceptions import PermissionDeniedError

_VALID_ISSUERS = ("accounts.google.com", "https://accounts.google.com")


def verify_google_id_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    try:
        claims = google_id_token.verify_oauth2_token(token, GoogleAuthRequest(), settings.GOOGLE_CLIENT_ID)
    except ValueError as exc:
        raise PermissionDeniedError("Invalid Google identity token") from exc
    if claims.get("iss") not in _VALID_ISSUERS:
        raise PermissionDeniedError("Invalid Google token issuer")
    if not claims.get("email"):
        raise PermissionDeniedError("Google token did not include an email address")
    return claims