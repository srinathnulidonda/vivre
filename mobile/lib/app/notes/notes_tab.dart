// lib/app/notes/notes_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/notes/notes_api.dart';
import '../../themes/color-palette.dart';
import '../../widgets/skeleton_loader.dart';
import 'note_detail_page.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  final NotesApi _api = NotesApi();
  final TextEditingController _searchController = TextEditingController();

  List<NoteSummary> _notes = const [];
  List<FolderSummary> _folders = const [];
  bool _isLoading = true;
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final List<NoteSummary> notes = await _api.list(limit: 60);
      final List<FolderSummary> folders = await _api.listFolders();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _folders = folders;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notes = const [];
        _folders = const [];
        _isLoading = false;
      });
    }
  }

  List<NoteSummary> get _filtered {
    final String query = _searchController.text.trim().toLowerCase();
    Iterable<NoteSummary> working = _notes;

    if (_selectedFolderId != null) {
      working = working.where((NoteSummary n) {
        if (_selectedFolderId == '__unfiled__') return n.folderId == null;
        return n.folderId == _selectedFolderId;
      });
    }

    if (query.isNotEmpty) {
      working = working.where((NoteSummary n) {
        return n.title.toLowerCase().contains(query) ||
            n.content.toLowerCase().contains(query);
      });
    }

    final List<NoteSummary> sorted = working.toList()
      ..sort((NoteSummary a, NoteSummary b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return sorted;
  }

  Future<void> _openNote({String? noteId}) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoteDetailPage(
          noteId: noteId,
          initialFolderId:
              noteId == null ? _resolvedInitialFolder : null,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  String? get _resolvedInitialFolder {
    final String? folderId = _selectedFolderId;
    if (folderId == null || folderId == '__unfiled__') return null;
    return folderId;
  }

  void _selectFolder(String? folderId) {
    setState(() => _selectedFolderId = folderId);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;

    return RefreshIndicator(
      onRefresh: _load,
      color: colors.primary,
      backgroundColor: colors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              count: _isLoading ? null : _notes.length,
              onCreate: () => _openNote(),
            ),
          ),
          SliverToBoxAdapter(
            child: _SearchField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              onClear: () {
                _searchController.clear();
                setState(() {});
              },
            ),
          ),
          SliverToBoxAdapter(
            child: _FolderChips(
              folders: _folders,
              selectedFolderId: _selectedFolderId,
              onSelect: _selectFolder,
            ),
          ),
          ..._buildBody(colors),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  List<Widget> _buildBody(VivreColors colors) {
    if (_isLoading) {
      return const [
        SliverToBoxAdapter(child: _NotesSkeleton()),
      ];
    }

    final List<NoteSummary> notes = _filtered;
    if (notes.isEmpty) {
      final bool hasFilter = _searchController.text.trim().isNotEmpty ||
          _selectedFolderId != null;
      return [
        SliverToBoxAdapter(
          child: _EmptyState(hasFilter: hasFilter),
        ),
      ];
    }

    final List<NoteSummary> pinned =
        notes.where((NoteSummary n) => n.isPinned).toList();
    final List<NoteSummary> rest =
        notes.where((NoteSummary n) => !n.isPinned).toList();

    return [
      if (pinned.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _SectionHeader(label: 'Pinned', count: pinned.length),
        ),
        SliverList.separated(
          itemCount: pinned.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _NoteTile(
                note: pinned[index],
                onTap: () => _openNote(noteId: pinned[index].id),
              ),
            );
          },
        ),
      ],
      SliverToBoxAdapter(
        child: _SectionHeader(
          label: pinned.isEmpty ? 'All notes' : 'Others',
          count: rest.length,
          topPadding: pinned.isEmpty ? 4 : 20,
        ),
      ),
      SliverList.separated(
        itemCount: rest.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _NoteTile(
              note: rest[index],
              onTap: () => _openNote(noteId: rest[index].id),
            ),
          );
        },
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  final int? count;
  final VoidCallback onCreate;

  const _Header({required this.count, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notes',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  count == null
                      ? 'Loading…'
                      : count == 1
                          ? '1 note'
                          : '$count notes',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'New',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primarySoft,
              foregroundColor: colors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: colors.surfaceSoft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(
            fontSize: 14.5,
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Search notes…',
            hintStyle: TextStyle(
              fontSize: 14.5,
              color: colors.textMuted,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 19,
              color: colors.textMuted,
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : GestureDetector(
                    onTap: onClear,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: colors.textMuted,
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}

class _FolderChips extends StatelessWidget {
  final List<FolderSummary> folders;
  final String? selectedFolderId;
  final ValueChanged<String?> onSelect;

  const _FolderChips({
    required this.folders,
    required this.selectedFolderId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) return const SizedBox(height: 4);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: 'All',
            selected: selectedFolderId == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Unfiled',
            selected: selectedFolderId == '__unfiled__',
            onTap: () => onSelect('__unfiled__'),
          ),
          for (final FolderSummary folder in folders) ...[
            const SizedBox(width: 8),
            _Chip(
              label: folder.name,
              selected: selectedFolderId == folder.id,
              onTap: () => onSelect(folder.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final double topPadding;

  const _SectionHeader({
    required this.label,
    required this.count,
    this.topPadding = 12,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final NoteSummary note;
  final VoidCallback onTap;

  const _NoteTile({required this.note, required this.onTap});

  String get _relative {
    final Duration diff = DateTime.now().difference(note.updatedAt.toLocal());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final DateTime d = note.updatedAt.toLocal();
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.isPinned) ...[
                    Icon(
                      Icons.push_pin_rounded,
                      size: 13,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _relative,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                note.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;

  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilter
                  ? Icons.search_off_rounded
                  : Icons.edit_note_outlined,
              color: colors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasFilter ? 'No matching notes' : 'Start your first note',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter
                ? 'Try a different search or folder.'
                : 'Capture a thought, an idea, or a plan — it lives here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesSkeleton extends StatelessWidget {
  const _NotesSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      isLoading: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: List.generate(5, (int i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SkeletonBox(height: 16, borderRadius: 6),
                        ),
                        SizedBox(width: 12),
                        SkeletonBox(width: 30, height: 12, borderRadius: 6),
                      ],
                    ),
                    SizedBox(height: 10),
                    SkeletonBox(height: 12, borderRadius: 6),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}