# app/schemas/notes.py
import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class FolderCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    parent_folder_id: uuid.UUID | None = None


class FolderUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    parent_folder_id: uuid.UUID | None = None


class FolderRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    name: str
    parent_folder_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime


class NoteCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    content: str = Field(default="")
    folder_id: uuid.UUID | None = None


class NoteUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=500)
    content: str | None = None
    folder_id: uuid.UUID | None = None
    is_pinned: bool | None = None


class NoteRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    title: str
    content: str
    folder_id: uuid.UUID | None
    is_pinned: bool
    last_accessed_at: datetime | None
    created_at: datetime
    updated_at: datetime


class NoteVersionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    content: str
    created_at: datetime


class NoteDetailRead(NoteRead):
    versions: list[NoteVersionRead] = Field(default_factory=list)


class NoteLinkCreateRequest(BaseModel):
    to_note_id: uuid.UUID


class NoteLinkRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    from_note_id: uuid.UUID
    to_note_id: uuid.UUID
    created_at: datetime


class QuickCaptureCreateRequest(BaseModel):
    raw_text: str = Field(min_length=1)


class QuickCaptureRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    raw_text: str
    is_processed: bool
    created_at: datetime