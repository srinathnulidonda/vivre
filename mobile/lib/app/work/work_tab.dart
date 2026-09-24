// lib/app/work/work_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/work/work_api.dart';
import '../../themes/color-palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/skeleton_loader.dart';
import 'project_detail_page.dart';
import 'widgets/work_sheets.dart';

class WorkTab extends StatefulWidget {
  const WorkTab({super.key});

  @override
  State<WorkTab> createState() => _WorkTabState();
}

class _WorkTabState extends State<WorkTab> {
  final WorkApi _api = WorkApi();

  List<ProjectSummary> _projects = const [];
  bool _isLoading = true;
  String _statusFilter = 'active';

  static const List<({String id, String label})> _filters = [
    (id: 'active', label: 'Active'),
    (id: 'on_hold', label: 'On hold'),
    (id: 'completed', label: 'Completed'),
    (id: '', label: 'All'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final List<ProjectSummary> projects = await _api.listProjects(
        status: _statusFilter.isEmpty ? null : _statusFilter,
        limit: 60,
      );
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _projects = const [];
        _isLoading = false;
      });
    }
  }

  Future<void> _openProject(String projectId) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProjectDetailPage(projectId: projectId),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _createProject() async {
    final ProjectSummary? created = await showProjectSheet(context);
    if (created == null || !mounted) return;
    await _load();
  }

  void _selectFilter(String id) {
    if (id == _statusFilter) return;
    HapticFeedback.selectionClick();
    setState(() => _statusFilter = id);
    _load();
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
              count: _isLoading ? null : _projects.length,
              onCreate: _createProject,
            ),
          ),
          SliverToBoxAdapter(
            child: _FilterRow(
              filters: _filters,
              selected: _statusFilter,
              onSelect: _selectFilter,
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
      return const [SliverToBoxAdapter(child: _ProjectsSkeleton())];
    }
    if (_projects.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _EmptyState(hasFilter: _statusFilter.isNotEmpty),
        ),
      ];
    }
    return [
      SliverList.separated(
        itemCount: _projects.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ProjectCard(
              project: _projects[index],
              onTap: () => _openProject(_projects[index].id),
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
                  'Work',
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
                          ? '1 project'
                          : '$count projects',
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

class _FilterRow extends StatelessWidget {
  final List<({String id, String label})> filters;
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterRow({
    required this.filters,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final ({String id, String label}) filter = filters[index];
          return _Chip(
            label: filter.label,
            selected: filter.id == selected,
            onTap: () => onSelect(filter.id),
          );
        },
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

class _ProjectCard extends StatelessWidget {
  final ProjectSummary project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

  String get _statusLabel {
    switch (project.status) {
      case 'active':
        return 'Active';
      case 'on_hold':
        return 'On hold';
      case 'completed':
        return 'Completed';
      case 'archived':
        return 'Archived';
      default:
        return project.status;
    }
  }

  Color _statusColor(VivreColors colors) {
    switch (project.status) {
      case 'on_hold':
        return const Color(0xFFA8792F);
      case 'completed':
        return const Color(0xFF4F7F5B);
      case 'archived':
        return colors.textMuted;
      default:
        return colors.primary;
    }
  }

  String? get _dueLabel {
    final DateTime? due = project.dueDate;
    if (due == null) return null;
    final DateTime local = due.toLocal();
    final int days = local.difference(DateTime.now()).inDays;
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    if (days < 7) return 'Due in ${days}d';
    return '${local.month}/${local.day}';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final Color statusColor = _statusColor(colors);
    final String? dueLabel = _dueLabel;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (dueLabel != null)
                    Text(
                      dueLabel,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                project.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  height: 1.3,
                ),
              ),
              if (project.description != null &&
                  project.description!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  project.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
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
                  ? Icons.filter_list_off_rounded
                  : Icons.work_outline_rounded,
              color: colors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasFilter ? 'No projects here' : 'Start your first project',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter
                ? 'Try a different filter.'
                : 'Plan it, track it, and move it forward — one task at a time.',
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

class _ProjectsSkeleton extends StatelessWidget {
  const _ProjectsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      isLoading: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: List.generate(4, (int i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 60, height: 16, borderRadius: 8),
                    SizedBox(height: 14),
                    SkeletonBox(height: 16, borderRadius: 6),
                    SizedBox(height: 8),
                    SkeletonBox(width: 200, height: 12, borderRadius: 6),
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