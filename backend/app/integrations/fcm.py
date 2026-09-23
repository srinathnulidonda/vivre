# app/integrations/fcm.py
from firebase_admin import exceptions as firebase_exceptions
from firebase_admin import messaging

from app.integrations.firebase import get_firebase_app

_UNREGISTERED_TOKEN_CODES = frozenset({"NOT_FOUND", "messaging/registration-token-not-registered"})


class UnregisteredPushTokenError(Exception):
    pass


def send_push_notification(device_token: str, title: str, body: str, data: dict[str, str]) -> str:
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data=data,
        token=device_token,
    )
    try:
        message_id: str = messaging.send(message, app=get_firebase_app())
    except firebase_exceptions.FirebaseError as exc:
        if getattr(exc, "code", None) in _UNREGISTERED_TOKEN_CODES:
            raise UnregisteredPushTokenError(str(exc)) from exc
        raise
    return message_id