// lib/app/notes/note_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_exception.dart';
import '../../api/notes/notes_api.dart';
import '../../themes/color-palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/skeleton_loader.dart';

class NoteDetailPage extends StatefulWidget {
  final String? noteId;
  final String? initialFolderId;

  const NoteDetailPage({super.key, this.noteId, this.initialFolderId});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  final NotesApi _api = NotesApi();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();

  NoteDetail? _note;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isPinned = false;
  String? _folderId;
  String _initialTitle = '';
  String _initialContent = '';
  bool _allowPop = false;

  bool get _isNew => widget.noteId == null;

  bool get _isDirty {
    if (_isNew) {
      return _title.text.trim().isNotEmpty || _content.text.trim().isNotEmpty;
    }
    return _title.text != _initialTitle ||
        _content.text != _initialContent ||
        _isPinned != (_note?.isPinned ?? false);
  }

  bool get _canSave {
    if (_isSaving || _isDeleting) return false;
    if (_title.text.trim().isEmpty) return false;
    return _isDirty;
  }

  @override
  void initState() {
    super.initState();
    _folderId = widget.initialFolderId;
    if (_isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(FocusNode());
      });
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final NoteDetail note = await _api.getDetail(widget.noteId!);
      if (!mounted) return;
      _title.text = note.title;
      _content.text = note.content;
      setState(() {
        _note = note;
        _isPinned = note.isPinned;
        _folderId = note.folderId;
        _initialTitle = note.title;
        _initialContent = note.content;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnackBar(context, e.message);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnackBar(context, 'Could not load this note.');
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      if (_isNew) {
        await _api.create(
          title: _title.text.trim(),
          content: _content.text,
          folderId: _folderId,
        );
      } else {
        await _api.update(
          widget.noteId!,
          title: _title.text.trim(),
          content: _content.text,
          isPinned: _isPinned,
        );
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _allowPop = true;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showErrorSnackBar(context, 'Could not save this note.');
    }
  }

  Future<void> _togglePin() async {
    if (_isNew || _isSaving) return;
    final bool next = !_isPinned;
    setState(() => _isPinned = next);
    HapticFeedback.selectionClick();
    try {
      await _api.update(widget.noteId!, isPinned: next);
      if (!mounted) return;
      _initialTitle = _title.text;
      _initialContent = _content.text;
      setState(() {
        _note = _note == null
            ? null
            : NoteDetail(
                id: _note!.id,
                title: _note!.title,
                content: _note!.content,
                folderId: _note!.folderId,
                isPinned: next,
                lastAccessedAt: _note!.lastAccessedAt,
                createdAt: _note!.createdAt,
                updatedAt: DateTime.now(),
                versions: _note!.versions,
              );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPinned = !next);
      showErrorSnackBar(context, 'Could not update pin.');
    }
  }

  Future<void> _delete() async {
    if (_isNew || _isDeleting) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final VivreColors colors = dialogContext.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete note?',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This note will be permanently removed.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFD64545),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    try {
      await _api.delete(widget.noteId!);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _allowPop = true;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      showErrorSnackBar(context, 'Could not delete this note.');
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final VivreColors colors = dialogContext.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Discard changes?',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'You have unsaved changes. Leave anyway?',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Keep editing',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Discard',
                style: TextStyle(
                  color: Color(0xFFD64545),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;

    return PopScope(
      canPop: _allowPop || !_isDirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool shouldLeave = await _confirmDiscard();
        if (!shouldPopContextValid()) return;
        if (shouldLeave) {
          _allowPop = true;
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: () async {
              if (_isDirty) {
                if (!await _confirmDiscard()) return;
              }
              if (!mounted) return;
              _allowPop = true;
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: colors.textPrimary,
          ),
          titleSpacing: 0,
          title: Text(
            _isNew ? 'New note' : 'Edit note',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          actions: [
            if (!_isNew) ...[
              IconButton(
                onPressed: _isSaving || _isDeleting ? null : _togglePin,
                icon: Icon(
                  _isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  size: 20,
                ),
                color: _isPinned ? colors.primary : colors.textSecondary,
                tooltip: _isPinned ? 'Unpin' : 'Pin',
              ),
              IconButton(
                onPressed: _isSaving || _isDeleting ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: colors.textSecondary,
                tooltip: 'Delete',
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _canSave ? _save : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: colors.primary,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Save',
                        style: TextStyle(
                          color: _canSave
                              ? colors.primary
                              : colors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const _DetailSkeleton()
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _title,
                        onChanged: (_) => setState(() {}),
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          height: 1.25,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Title',
                          hintStyle: TextStyle(
                            color: colors.textMuted,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        color: colors.border,
                        height: 1,
                        thickness: 1,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _content,
                          onChanged: (_) => setState(() {}),
                          maxLines: null,
                          minLines: null,
                          expands: true,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          textAlignVertical: TextAlignVertical.top,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15.5,
                            height: 1.6,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Start writing…',
                            hintStyle: TextStyle(
                              color: colors.textMuted,
                              fontSize: 15.5,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  bool shouldPopContextValid() {
    return mounted;
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      isLoading: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(height: 28, borderRadius: 8),
            SizedBox(height: 22),
            SkeletonText(lines: 8, lineHeight: 14, spacing: 12),
          ],
        ),
      ),
    );
  }
}