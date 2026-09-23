# app/core/email.py
from app.core.config import get_settings

_settings = get_settings()

_BRAND_NAME = "VIVRE"
_BRAND_COLOR = "#111827"
_ACCENT_COLOR = "#4F46E5"
_MUTED_COLOR = "#6B7280"
_BORDER_COLOR = "#E5E7EB"


def _base_layout(preheader: str, title: str, body_html: str) -> str:
    """Wraps template-specific body content in a shared, inline-styled shell."""
    return f"""\
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>{title}</title>
  </head>
  <body style="margin:0;padding:0;background-color:#F3F4F6;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
    <span style="display:none;font-size:1px;color:#F3F4F6;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;">
      {preheader}
    </span>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#F3F4F6;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="max-width:480px;width:100%;background-color:#FFFFFF;border-radius:12px;border:1px solid {_BORDER_COLOR};overflow:hidden;">
            <tr>
              <td style="padding:28px 32px 0 32px;">
                <div style="font-size:20px;font-weight:700;color:{_BRAND_COLOR};letter-spacing:-0.02em;">
                  {_BRAND_NAME}
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:24px 32px 32px 32px;color:{_BRAND_COLOR};font-size:15px;line-height:1.6;">
                {body_html}
              </td>
            </tr>
            <tr>
              <td style="padding:20px 32px;border-top:1px solid {_BORDER_COLOR};color:{_MUTED_COLOR};font-size:12px;line-height:1.5;">
                This is an automated message from {_BRAND_NAME}. If you didn't expect this email, you can safely ignore it.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>"""


def _otp_code_block(code: str) -> str:
    spaced_code = " ".join(list(code))
    return f"""\
<div style="margin:24px 0;text-align:center;">
  <span style="display:inline-block;padding:14px 28px;background-color:#F3F4F6;border-radius:8px;
    font-size:28px;font-weight:700;letter-spacing:8px;color:{_ACCENT_COLOR};">
    {spaced_code}
  </span>
</div>"""


def build_email_verification_email(code: str) -> tuple[str, str]:
    subject = f"Verify your {_BRAND_NAME} email address"
    minutes = _settings.OTP_TTL_SECONDS // 60
    body_html = f"""\
<p style="margin:0 0 8px 0;font-size:17px;font-weight:600;">Verify your email</p>
<p style="margin:0 0 4px 0;">Use the code below to verify your email address and finish setting up your account.</p>
{_otp_code_block(code)}
<p style="margin:0;color:{_MUTED_COLOR};font-size:13px;">
  This code expires in {minutes} minutes. Never share this code with anyone — {_BRAND_NAME} staff will never ask for it.
</p>"""
    return subject, _base_layout(
        preheader=f"Your verification code is {code}",
        title=subject,
        body_html=body_html,
    )


def build_password_reset_email(code: str) -> tuple[str, str]:
    subject = f"Reset your {_BRAND_NAME} password"
    minutes = _settings.OTP_TTL_SECONDS // 60
    body_html = f"""\
<p style="margin:0 0 8px 0;font-size:17px;font-weight:600;">Reset your password</p>
<p style="margin:0 0 4px 0;">We received a request to reset your password. Use the code below to continue.</p>
{_otp_code_block(code)}
<p style="margin:0;color:{_MUTED_COLOR};font-size:13px;">
  This code expires in {minutes} minutes. If you didn't request a password reset, you can safely ignore this email —
  your password will not be changed.
</p>"""
    return subject, _base_layout(
        preheader=f"Your password reset code is {code}",
        title=subject,
        body_html=body_html,
    )


def build_password_changed_alert_email() -> tuple[str, str]:
    subject = f"Your {_BRAND_NAME} password was changed"
    body_html = f"""\
<p style="margin:0 0 8px 0;font-size:17px;font-weight:600;">Password changed</p>
<p style="margin:0 0 4px 0;">
  Your {_BRAND_NAME} account password was just changed. All active sessions have been signed out for your security.
</p>
<p style="margin:16px 0 0 0;color:{_MUTED_COLOR};font-size:13px;">
  If you didn't make this change, reset your password immediately and contact support.
</p>"""
    return subject, _base_layout(
        preheader="Your password was just changed",
        title=subject,
        body_html=body_html,
    )


def build_weekly_digest_email() -> tuple[str, str]:
    subject = f"Your {_BRAND_NAME} weekly digest"
    body_html = f"""\
<p style="margin:0 0 8px 0;font-size:17px;font-weight:600;">Your weekly review is ready</p>
<p style="margin:0 0 16px 0;">
  Take a few minutes to reflect on the past week — your wins, blockers, and what's next.
</p>
<div style="text-align:center;margin:24px 0;">
  <span style="display:inline-block;padding:12px 24px;background-color:{_ACCENT_COLOR};border-radius:8px;
    color:#FFFFFF;font-weight:600;font-size:14px;">
    Open {_BRAND_NAME} to reflect on your week
  </span>
</div>"""
    return subject, _base_layout(
        preheader="Your weekly review is ready",
        title=subject,
        body_html=body_html,
    )


def build_daily_review_reminder_email() -> tuple[str, str]:
    subject = f"Your {_BRAND_NAME} daily review is ready"
    body_html = f"""\
<p style="margin:0 0 8px 0;font-size:17px;font-weight:600;">Daily review ready</p>
<p style="margin:0;">Take a moment to review your day — wins, blockers, and mood.</p>"""
    return subject, _base_layout(
        preheader="Take a moment to review your day",
        title=subject,
        body_html=body_html,
    )