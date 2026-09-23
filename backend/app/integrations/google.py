# app/integrations/google.py
from typing import Any

from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import id_token as google_id_token
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow

from app.core.config import get_settings

_settings = get_settings()
_SCOPES: list[str] = [
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/drive.readonly",
    "openid",
    "email",
]


def _build_flow(state: str | None = None) -> Flow:
    client_config = {
        "web": {
            "client_id": _settings.GOOGLE_CLIENT_ID,
            "client_secret": _settings.GOOGLE_CLIENT_SECRET,
            "redirect_uris": [_settings.GOOGLE_REDIRECT_URI],
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
        }
    }
    return Flow.from_client_config(
        client_config, scopes=_SCOPES, state=state, redirect_uri=_settings.GOOGLE_REDIRECT_URI
    )


def build_authorization_url(state: str) -> str:
    flow = _build_flow(state=state)
    authorization_url, _ = flow.authorization_url(
        access_type="offline", include_granted_scopes="true", prompt="consent"
    )
    return str(authorization_url)


def exchange_code_for_tokens(code: str) -> dict[str, Any]:
    flow = _build_flow()
    flow.fetch_token(code=code)
    credentials_obj: Credentials = flow.credentials
    verified_email: str | None = None
    if credentials_obj.id_token:
        try:
            id_info = google_id_token.verify_oauth2_token(
                credentials_obj.id_token, GoogleAuthRequest(), _settings.GOOGLE_CLIENT_ID
            )
            verified_email = id_info.get("email")
        except ValueError:
            verified_email = None
    return {
        "access_token": credentials_obj.token,
        "refresh_token": credentials_obj.refresh_token,
        "scope": " ".join(credentials_obj.scopes or []),
        "expires_at": credentials_obj.expiry,
        "google_account_email": verified_email,
    }


def refresh_access_token(refresh_token: str) -> dict[str, Any]:
    credentials_obj = Credentials(
        token=None,
        refresh_token=refresh_token,
        token_uri="https://oauth2.googleapis.com/token",
        client_id=_settings.GOOGLE_CLIENT_ID,
        client_secret=_settings.GOOGLE_CLIENT_SECRET,
    )
    credentials_obj.refresh(GoogleAuthRequest())
    return {
        "access_token": credentials_obj.token,
        "expires_at": credentials_obj.expiry,
    }