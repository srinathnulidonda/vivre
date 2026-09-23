# app/api/notes.py
import uuid

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.notes import (
    FolderCreateRequest,
    FolderRead,
    FolderUpdateRequest,
    NoteCreateRequest,
    NoteDetailRead,
    NoteLinkCreateRequest,
    NoteLinkRead,
    NoteRead,
    NoteUpdateRequest,
    NoteVersionRead,
    QuickCaptureCreateRequest,
    QuickCaptureRead,
)
from app.schemas.shared import PaginatedResponse, PaginationParams, pagination_params
from app.services import notes as notes_service

router = APIRouter(prefix="/notes", tags=["notes"])


@router.post("/folders", response_model=FolderRead, status_code=status.HTTP_201_CREATED)
async def create_folder(
    payload: FolderCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> FolderRead:
    folder = await notes_service.create_folder(session, current_user.id, payload)
    return FolderRead.model_validate(folder)


@router.get("/folders", response_model=PaginatedResponse[FolderRead], status_code=status.HTTP_200_OK)
async def list_folders(
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[FolderRead]:
    folders, total = await notes_service.list_folders(session, current_user.id, pagination)
    return PaginatedResponse(items=folders, total=total, limit=pagination.limit, offset=pagination.offset)


@router.patch("/folders/{folder_id}", response_model=FolderRead, status_code=status.HTTP_200_OK)
async def update_folder(
    folder_id: uuid.UUID,
    payload: FolderUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> FolderRead:
    folder = await notes_service.update_folder(session, current_user.id, folder_id, payload)
    return FolderRead.model_validate(folder)


@router.delete("/folders/{folder_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_folder(
    folder_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await notes_service.delete_folder(session, current_user.id, folder_id)


@router.post("", response_model=NoteRead, status_code=status.HTTP_201_CREATED)
async def create_note(
    payload: NoteCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> NoteRead:
    note = await notes_service.create_note(session, current_user.id, payload)
    return NoteRead.model_validate(note)


@router.get("", response_model=PaginatedResponse[NoteRead], status_code=status.HTTP_200_OK)
async def list_notes(
    folder_id: uuid.UUID | None = Query(default=None),
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[NoteRead]:
    notes, total = await notes_service.list_notes(session, current_user.id, pagination, folder_id=folder_id)
    return PaginatedResponse(items=notes, total=total, limit=pagination.limit, offset=pagination.offset)


@router.get("/recent", response_model=list[NoteRead], status_code=status.HTTP_200_OK)
async def list_recent_notes(
    limit: int = Query(default=10, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[NoteRead]:
    notes = await notes_service.list_recent_notes(session, current_user.id, limit)
    return [NoteRead.model_validate(note) for note in notes]


@router.post("/quick-captures", response_model=QuickCaptureRead, status_code=status.HTTP_201_CREATED)
async def create_quick_capture(
    payload: QuickCaptureCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> QuickCaptureRead:
    capture = await notes_service.create_quick_capture(session, current_user.id, payload)
    return QuickCaptureRead.model_validate(capture)


@router.get("/quick-captures", response_model=PaginatedResponse[QuickCaptureRead], status_code=status.HTTP_200_OK)
async def list_quick_captures(
    unprocessed_only: bool = Query(default=False),
    pagination: PaginationParams = Depends(pagination_params),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedResponse[QuickCaptureRead]:
    captures, total = await notes_service.list_quick_captures(
        session, current_user.id, pagination, unprocessed_only=unprocessed_only
    )
    return PaginatedResponse(items=captures, total=total, limit=pagination.limit, offset=pagination.offset)


@router.post("/quick-captures/{capture_id}/process", response_model=QuickCaptureRead, status_code=status.HTTP_200_OK)
async def mark_quick_capture_processed(
    capture_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> QuickCaptureRead:
    capture = await notes_service.mark_quick_capture_processed(session, current_user.id, capture_id)
    return QuickCaptureRead.model_validate(capture)


@router.post("/{note_id}/links", response_model=NoteLinkRead, status_code=status.HTTP_201_CREATED)
async def create_note_link(
    note_id: uuid.UUID,
    payload: NoteLinkCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> NoteLinkRead:
    link = await notes_service.create_note_link(session, current_user.id, note_id, payload.to_note_id)
    return NoteLinkRead.model_validate(link)


@router.delete("/links/{link_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_note_link(
    link_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await notes_service.delete_note_link(session, current_user.id, link_id)


@router.get("/{note_id}", response_model=NoteDetailRead, status_code=status.HTTP_200_OK)
async def get_note_detail(
    note_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> NoteDetailRead:
    note = await notes_service.get_note_detail(session, current_user.id, note_id)
    return NoteDetailRead(
        id=note.id,
        title=note.title,
        content=note.content,
        folder_id=note.folder_id,
        is_pinned=note.is_pinned,
        last_accessed_at=note.last_accessed_at,
        created_at=note.created_at,
        updated_at=note.updated_at,
        versions=[NoteVersionRead.model_validate(version) for version in note.versions],
    )


@router.patch("/{note_id}", response_model=NoteRead, status_code=status.HTTP_200_OK)
async def update_note(
    note_id: uuid.UUID,
    payload: NoteUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> NoteRead:
    note = await notes_service.update_note(session, current_user.id, note_id, payload)
    return NoteRead.model_validate(note)


@router.delete("/{note_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def delete_note(
    note_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await notes_service.delete_note(session, current_user.id, note_id)