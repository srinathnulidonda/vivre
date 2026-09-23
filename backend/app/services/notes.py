# app/services/notes.py
import uuid
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import ConflictError, NotFoundError, PermissionDeniedError, ValidationError
from app.models.notes import Folder, Note, NoteLink, NoteVersion, QuickCapture
from app.schemas.notes import (
    FolderCreateRequest,
    FolderUpdateRequest,
    NoteCreateRequest,
    NoteUpdateRequest,
    QuickCaptureCreateRequest,
)
from app.schemas.shared import PaginationParams

_LAST_ACCESSED_DEBOUNCE_SECONDS = 300
_NULLABLE_FOLDER_FIELDS = frozenset({"parent_folder_id"})
_NULLABLE_NOTE_FIELDS = frozenset({"folder_id"})


def _apply_updates(entity, update_fields: dict, nullable_fields: frozenset[str]) -> None:
    for field_name, field_value in update_fields.items():
        if field_value is None and field_name not in nullable_fields:
            continue
        setattr(entity, field_name, field_value)


async def _get_owned_folder(session: AsyncSession, user_id: uuid.UUID, folder_id: uuid.UUID) -> Folder:
    folder = await session.get(Folder, folder_id)
    if folder is None:
        raise NotFoundError("Folder not found")
    if folder.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this folder")
    return folder


async def _get_owned_note(session: AsyncSession, user_id: uuid.UUID, note_id: uuid.UUID) -> Note:
    note = await session.get(Note, note_id)
    if note is None:
        raise NotFoundError("Note not found")
    if note.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this note")
    return note


async def create_folder(
    session: AsyncSession, user_id: uuid.UUID, request: FolderCreateRequest
) -> Folder:
    if request.parent_folder_id is not None:
        await _get_owned_folder(session, user_id, request.parent_folder_id)
    folder = Folder(user_id=user_id, name=request.name, parent_folder_id=request.parent_folder_id)
    session.add(folder)
    await session.commit()
    await session.refresh(folder)
    return folder


async def update_folder(
    session: AsyncSession, user_id: uuid.UUID, folder_id: uuid.UUID, request: FolderUpdateRequest
) -> Folder:
    folder = await _get_owned_folder(session, user_id, folder_id)
    update_fields = request.model_dump(exclude_unset=True)
    if "parent_folder_id" in update_fields:
        new_parent_id = update_fields["parent_folder_id"]
        if new_parent_id is not None:
            if new_parent_id == folder_id:
                raise ValidationError("A folder cannot be its own parent")
            await _get_owned_folder(session, user_id, new_parent_id)
    _apply_updates(folder, update_fields, _NULLABLE_FOLDER_FIELDS)
    await session.commit()
    await session.refresh(folder)
    return folder


async def delete_folder(session: AsyncSession, user_id: uuid.UUID, folder_id: uuid.UUID) -> None:
    folder = await _get_owned_folder(session, user_id, folder_id)
    await session.delete(folder)
    await session.commit()


async def list_folders(
    session: AsyncSession, user_id: uuid.UUID, pagination: PaginationParams
) -> tuple[list[Folder], int]:
    count_result = await session.execute(
        select(func.count()).select_from(Folder).where(Folder.user_id == user_id)
    )
    total = count_result.scalar_one()
    result = await session.execute(
        select(Folder)
        .where(Folder.user_id == user_id)
        .order_by(Folder.name.asc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def create_note(session: AsyncSession, user_id: uuid.UUID, request: NoteCreateRequest) -> Note:
    if request.folder_id is not None:
        await _get_owned_folder(session, user_id, request.folder_id)
    note = Note(user_id=user_id, title=request.title, content=request.content, folder_id=request.folder_id)
    session.add(note)
    await session.commit()
    await session.refresh(note)
    return note


async def update_note(
    session: AsyncSession, user_id: uuid.UUID, note_id: uuid.UUID, request: NoteUpdateRequest
) -> Note:
    note = await _get_owned_note(session, user_id, note_id)
    update_fields = request.model_dump(exclude_unset=True)
    if "folder_id" in update_fields and update_fields["folder_id"] is not None:
        await _get_owned_folder(session, user_id, update_fields["folder_id"])
    if (
        update_fields.get("content") is not None
        and update_fields["content"] != note.content
    ):
        session.add(NoteVersion(note_id=note.id, content=note.content))
    _apply_updates(note, update_fields, _NULLABLE_NOTE_FIELDS)
    await session.commit()
    await session.refresh(note)
    return note


async def get_note_detail(session: AsyncSession, user_id: uuid.UUID, note_id: uuid.UUID) -> Note:
    result = await session.execute(
        select(Note).options(selectinload(Note.versions)).where(Note.id == note_id)
    )
    note = result.scalar_one_or_none()
    if note is None:
        raise NotFoundError("Note not found")
    if note.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this note")
    now = datetime.now(timezone.utc)
    if note.last_accessed_at is None or (now - note.last_accessed_at).total_seconds() > _LAST_ACCESSED_DEBOUNCE_SECONDS:
        note.last_accessed_at = now
        await session.commit()
        await session.refresh(note)
    return note


async def delete_note(session: AsyncSession, user_id: uuid.UUID, note_id: uuid.UUID) -> None:
    note = await _get_owned_note(session, user_id, note_id)
    await session.delete(note)
    await session.commit()


async def list_notes(
    session: AsyncSession,
    user_id: uuid.UUID,
    pagination: PaginationParams,
    folder_id: uuid.UUID | None = None,
) -> tuple[list[Note], int]:
    filters = [Note.user_id == user_id]
    if folder_id is not None:
        filters.append(Note.folder_id == folder_id)
    count_result = await session.execute(select(func.count()).select_from(Note).where(*filters))
    total = count_result.scalar_one()
    result = await session.execute(
        select(Note)
        .where(*filters)
        .order_by(Note.updated_at.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total


async def list_recent_notes(session: AsyncSession, user_id: uuid.UUID, limit: int) -> list[Note]:
    result = await session.execute(
        select(Note)
        .where(Note.user_id == user_id, Note.last_accessed_at.is_not(None))
        .order_by(Note.last_accessed_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def create_note_link(
    session: AsyncSession, user_id: uuid.UUID, from_note_id: uuid.UUID, to_note_id: uuid.UUID
) -> NoteLink:
    if from_note_id == to_note_id:
        raise ValidationError("A note cannot link to itself")
    await _get_owned_note(session, user_id, from_note_id)
    await _get_owned_note(session, user_id, to_note_id)
    link = NoteLink(from_note_id=from_note_id, to_note_id=to_note_id)
    session.add(link)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise ConflictError("These notes are already linked") from exc
    await session.refresh(link)
    return link


async def delete_note_link(session: AsyncSession, user_id: uuid.UUID, link_id: uuid.UUID) -> None:
    link = await session.get(NoteLink, link_id)
    if link is None:
        raise NotFoundError("Note link not found")
    await _get_owned_note(session, user_id, link.from_note_id)
    await session.delete(link)
    await session.commit()


async def create_quick_capture(
    session: AsyncSession, user_id: uuid.UUID, request: QuickCaptureCreateRequest
) -> QuickCapture:
    capture = QuickCapture(user_id=user_id, raw_text=request.raw_text)
    session.add(capture)
    await session.commit()
    await session.refresh(capture)
    return capture


async def mark_quick_capture_processed(
    session: AsyncSession, user_id: uuid.UUID, capture_id: uuid.UUID
) -> QuickCapture:
    capture = await session.get(QuickCapture, capture_id)
    if capture is None:
        raise NotFoundError("Quick capture not found")
    if capture.user_id != user_id:
        raise PermissionDeniedError("You do not have access to this quick capture")
    capture.is_processed = True
    await session.commit()
    await session.refresh(capture)
    return capture


async def list_quick_captures(
    session: AsyncSession,
    user_id: uuid.UUID,
    pagination: PaginationParams,
    unprocessed_only: bool = False,
) -> tuple[list[QuickCapture], int]:
    filters = [QuickCapture.user_id == user_id]
    if unprocessed_only:
        filters.append(QuickCapture.is_processed.is_(False))
    count_result = await session.execute(select(func.count()).select_from(QuickCapture).where(*filters))
    total = count_result.scalar_one()
    result = await session.execute(
        select(QuickCapture)
        .where(*filters)
        .order_by(QuickCapture.created_at.desc())
        .limit(pagination.limit)
        .offset(pagination.offset)
    )
    return list(result.scalars().all()), total