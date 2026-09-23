# app/integrations/health.py
from datetime import date, datetime
from typing import Any


def _coerce_datetime(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    return datetime.fromisoformat(str(value))


def _coerce_date(value: Any) -> date:
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value))


def normalize_daily_metric_payload(raw_payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "metric_date": _coerce_date(raw_payload["metric_date"]),
        "steps": max(int(raw_payload.get("steps", 0)), 0),
        "distance_meters": max(float(raw_payload.get("distance_meters", 0.0)), 0.0),
        "active_calories": max(float(raw_payload.get("active_calories", 0.0)), 0.0),
    }


def normalize_sleep_payload(raw_payload: dict[str, Any]) -> dict[str, Any]:
    start_at = _coerce_datetime(raw_payload["start_at"])
    end_at = _coerce_datetime(raw_payload["end_at"])
    default_duration_minutes = max(int((end_at - start_at).total_seconds() // 60), 0)
    return {
        "sleep_date": _coerce_date(raw_payload["sleep_date"]),
        "start_at": start_at,
        "end_at": end_at,
        "duration_minutes": int(raw_payload.get("duration_minutes") or default_duration_minutes),
        "quality": raw_payload.get("quality"),
    }


def normalize_workout_payload(raw_payload: dict[str, Any]) -> dict[str, Any]:
    end_at_raw = raw_payload.get("end_at")
    return {
        "workout_type": str(raw_payload["workout_type"]),
        "start_at": _coerce_datetime(raw_payload["start_at"]),
        "end_at": _coerce_datetime(end_at_raw) if end_at_raw else None,
        "duration_minutes": raw_payload.get("duration_minutes"),
        "calories": raw_payload.get("calories"),
        "distance_meters": raw_payload.get("distance_meters"),
    }