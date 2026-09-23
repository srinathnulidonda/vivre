# app/integrations/firebase.py
import threading

import firebase_admin
from firebase_admin import credentials

from app.core.config import get_settings

_firebase_app: firebase_admin.App | None = None
_firebase_app_lock = threading.Lock()


def get_firebase_app() -> firebase_admin.App:
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app
    with _firebase_app_lock:
        if _firebase_app is None:
            settings = get_settings()
            credential = credentials.Certificate(settings.firebase_credentials_dict)
            _firebase_app = firebase_admin.initialize_app(credential, name="vivre-firebase")
    return _firebase_app