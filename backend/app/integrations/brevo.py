# app/integrations/brevo.py
from functools import lru_cache
from typing import Any

from app.core.config import get_settings


@lru_cache
def _get_transactional_api() -> Any:
    try:
        from brevo_python import ApiClient, Configuration, TransactionalEmailsApi
    except ImportError as exc:
        raise RuntimeError(
            "brevo_python is not installed; email sending is unavailable"
        ) from exc

    settings = get_settings()
    configuration = Configuration()
    configuration.api_key["api-key"] = settings.BREVO_API_KEY
    api_client = ApiClient(configuration)
    return TransactionalEmailsApi(api_client)


def send_transactional_email(to_email: str, to_name: str, subject: str, html_content: str) -> str:
    from brevo_python import SendSmtpEmail, SendSmtpEmailSender, SendSmtpEmailTo

    settings = get_settings()
    transactional_api = _get_transactional_api()

    sender = SendSmtpEmailSender(email=settings.BREVO_FROM_EMAIL, name=settings.BREVO_FROM_NAME)
    recipient = SendSmtpEmailTo(email=to_email, name=to_name)
    email = SendSmtpEmail(sender=sender, to=[recipient], subject=subject, html_content=html_content)
    response: Any = transactional_api.send_transac_email(email)
    return str(response.message_id)