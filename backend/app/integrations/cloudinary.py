# app/integrations/cloudinary.py
from typing import Any

import cloudinary
import cloudinary.uploader

from app.core.config import get_settings

_settings = get_settings()

cloudinary.config(
    cloud_name=_settings.CLOUDINARY_CLOUD_NAME,
    api_key=_settings.CLOUDINARY_API_KEY,
    api_secret=_settings.CLOUDINARY_API_SECRET,
    secure=True,
)


def upload_image(file_bytes: bytes, folder: str, public_id: str) -> tuple[str, str]:
    result: dict[str, Any] = cloudinary.uploader.upload(
        file_bytes,
        folder=folder,
        public_id=public_id,
        overwrite=True,
        resource_type="image",
    )
    return str(result["secure_url"]), str(result["public_id"])


def delete_image(public_id: str) -> None:
    cloudinary.uploader.destroy(public_id, resource_type="image")