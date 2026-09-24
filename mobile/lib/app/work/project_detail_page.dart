// lib/app/work/project_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_exception.dart';
import '../../api/work/work_api.dart';
import '../../themes/color-palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/skeleton_loader.dart';
import 'widgets/work_sheets.dart';

class ProjectDetailPage extends StatefulWidget {
  final String projectId;

  const ProjectDetailPage({super.key, required this.projectId});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  final WorkApi _api = WorkApi();

  ProjectDetail? _project;
  List<MilestoneSummary> _milestones = const [];
  List<TaskSummary> _tasks = const [];
  bool _isLoading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final ProjectDetail project = await _api.getProject(widget.projectId);
      final List<TaskSummary> tasks =
          await _api.listTasks(projectId: widget.projectId, limit: 100);
      if (!mounted) return;
      setState(() {
        _project = project;
        _tasks = tasks;
        _milestones = const [];
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnackBar(context, e.message);
      Navigator.of(context).pop(_changed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnackBar(context, 'Could not load this project.');
      Navigator.of(context).pop(_changed);
    }
  }

  Future<void> _editProject() async {
    final ProjectDetail? project = _project;
    if (project == null) return;
    final ProjectSummary? updated = await showProjectSheet(
      context,
      existing: ProjectSummary(
        id: project.id,
        name: project.name,
        description: project.description,
        clientId: project.clientId,
        status: project.status,
        coverImageUrl: project.coverImageUrl,
        startDate: project.startDate,
        dueDate: project.dueDate,
        createdAt: project.createdAt,
        updatedAt: project.updatedAt,
      ),
    );
    if (updated == null || !mounted) return;
    _changed = true;
    await _load();
  }

  Future<void> _deleteProject() async {
    final bool? confirmed = await _confirmDelete(
      title: 'Delete project?',
      body: 'All tasks and milestones in this project will be removed.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteProject(widget.projectId);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not delete this project.');
    }
  }

  Future<void> _addTask() async {
    final TaskSummary? created = await showTaskSheet(
      context,
      projectId: widget.projectId,
    );
    if (created == null || !mounted) return;
    _changed = true;
    await _load();
  }

  Future<void> _openTask(TaskSummary task) async {
    final TaskSummary? updated = await showTaskSheet(
      context,
      projectId: widget.projectId,
      existing: task,
    );
    if (updated == null || !mounted) return;
    _changed = true;
    await _load();
  }

  Future<void> _toggleMilestone(MilestoneSummary milestone) async {
    final bool next = !milestone.isCompleted;
    HapticFeedback.selectionClick();
    setState(() {
      _milestones = _milestones
          .map((MilestoneSummary m) => m.id == milestone.id
              ? MilestoneSummary(
                  id: m.id,
                  projectId: m.projectId,
                  title: m.title,
                  dueDate: m.dueDate,
                  isCompleted: next,
                  completedAt: next ? DateTime.now() : null,
                )
              : m)
          .toList();
    });
    try {
      await _api.updateMilestone(milestone.id, isCompleted: next);
      _changed = true;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _milestones = _milestones
            .map((MilestoneSummary m) => m.id == milestone.id
                ? MilestoneSummary(
                    id: m.id,
                    projectId: m.projectId,
                    title: m.title,
                    dueDate: m.dueDate,
                    isCompleted: milestone.isCompleted,
                    completedAt: milestone.completedAt,
                  )
                : m)
            .toList();
      });
      showErrorSnackBar(context, 'Could not update milestone.');
    }
  }

  Future<void> _addMilestone() async {
    final TextEditingController controller = TextEditingController();
    final String? title = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final VivreColors colors = sheetContext.colors;
        final double inset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: Container(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'New milestone',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Design phase complete',
                      hintStyle: TextStyle(
                        color: colors.textMuted,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: colors.border, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: colors.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: colors.primary, width: 1.4),
                      ),
                    ),
                    onSubmitted: (String value) {
                      if (value.trim().isNotEmpty) {
                        Navigator.of(sheetContext).pop(value.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final String value = controller.text.trim();
                        if (value.isEmpty) return;
                        Navigator.of(sheetContext).pop(value);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: const Text(
                        'Add milestone',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (title == null || !mounted) return;

    try {
      final MilestoneSummary created =
          await _api.createMilestone(widget.projectId, title: title);
      if (!mounted) return;
      setState(() => _milestones = [..._milestones, created]);
      _changed = true;
      HapticFeedback.mediumImpact();
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not add milestone.');
    }
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String body,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final VivreColors colors = dialogContext.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            body,
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
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(_changed),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: colors.textPrimary,
          ),
          titleSpacing: 0,
          title: Text(
            'Project',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _editProject,
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: colors.textSecondary,
              tooltip: 'Edit project',
            ),
            IconButton(
              onPressed: _isLoading ? null : _deleteProject,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: colors.textSecondary,
              tooltip: 'Delete project',
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: _isLoading
            ? const _DetailSkeleton()
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _ProjectHeader(project: _project!),
                  ),
                  SliverToBoxAdapter(
                    child: _MilestonesSection(
                      milestones: _milestones,
                      onToggle: _toggleMilestone,
                      onAdd: _addMilestone,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _TasksHeader(
                      count: _tasks.length,
                      onAdd: _addTask,
                    ),
                  ),
                  if (_tasks.isEmpty)
                    const SliverToBoxAdapter(
                      child: _NoTasksCard(),
                    )
                  else
                    SliverList.separated(
                      itemCount: _tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _TaskRow(
                            task: _tasks[index],
                            onTap: () => _openTask(_tasks[index]),
                          ),
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  final ProjectDetail project;

  const _ProjectHeader({required this.project});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final int percent = (project.progress * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.name,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          if (project.description != null &&
              project.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              project.description!,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: project.progress,
                    minHeight: 8,
                    backgroundColor: colors.surfaceSoft,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MetaItem(
                      icon: Icons.check_circle_outline_rounded,
                      label:
                          '${project.completedTaskCount}/${project.taskCount} tasks',
                    ),
                    const SizedBox(width: 18),
                    _MetaItem(
                      icon: Icons.flag_outlined,
                      label: '${project.milestoneCount} milestones',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 14, color: colors.textMuted),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MilestonesSection extends StatelessWidget {
  final List<MilestoneSummary> milestones;
  final ValueChanged<MilestoneSummary> onToggle;
  final VoidCallback onAdd;

  const _MilestonesSection({
    required this.milestones,
    required this.onToggle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'MILESTONES',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAdd,
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 15, color: colors.primary),
                    const SizedBox(width: 3),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (milestones.isEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Center(
                child: Text(
                  'No milestones yet',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < milestones.length; i++)
                    _MilestoneRow(
                      milestone: milestones[i],
                      onToggle: () => onToggle(milestones[i]),
                      showDivider: i < milestones.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final MilestoneSummary milestone;
  final VoidCallback onToggle;
  final bool showDivider;

  const _MilestoneRow({
    required this.milestone,
    required this.onToggle,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final bool done = milestone.isCompleted;
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: done ? colors.success : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done ? colors.success : colors.border,
                      width: 1.6,
                    ),
                  ),
                  child: done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    milestone.title,
                    style: TextStyle(
                      color: done
                          ? colors.textMuted
                          : colors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                      decorationColor: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: colors.border, height: 1, thickness: 0.6),
          ),
      ],
    );
  }
}

class _TasksHeader extends StatelessWidget {
  final int count;
  final VoidCallback onAdd;

  const _TasksHeader({required this.count, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [
          Text(
            'TASKS',
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
          const Spacer(),
          GestureDetector(
            onTap: onAdd,
            child: Row(
              children: [
                Icon(Icons.add_rounded, size: 15, color: colors.primary),
                const SizedBox(width: 3),
                Text(
                  'Add',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final TaskSummary task;
  final VoidCallback onTap;

  const _TaskRow({required this.task, required this.onTap});

  Color _priorityColor(VivreColors colors) {
    switch (task.priority) {
      case 'urgent':
        return const Color(0xFFA94D3D);
      case 'high':
        return const Color(0xFFA8792F);
      default:
        return colors.border;
    }
  }

  String get _dueLabel {
    final DateTime? due = task.dueDate;
    if (due == null) return '';
    final DateTime local = due.toLocal();
    final DateTime now = DateTime.now();
    final int days = local.difference(now).inDays;
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days < 7) return '${days}d';
    return '${local.month}/${local.day}';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final bool done = task.isDone;
    final Color priority = _priorityColor(colors);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 3,
                height: 32,
                decoration: BoxDecoration(
                  color: priority,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: done
                            ? colors.textMuted
                            : colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        decoration:
                            done ? TextDecoration.lineThrough : null,
                        decorationColor: colors.textMuted,
                      ),
                    ),
                    if (task.dueDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _dueLabel,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: task.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final (String label, Color color, Color bg) = switch (status) {
      'done' => (
          'Done',
          const Color(0xFF4F7F5B),
          const Color(0xFFDFF3E3)
        ),
      'in_progress' => (
          'Doing',
          colors.primary,
          colors.primarySoft
        ),
      'archived' => (
          'Archived',
          colors.textMuted,
          colors.surfaceSoft
        ),
      _ => (
          'To do',
          colors.textSecondary,
          colors.surfaceSoft
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          height: 1.1,
        ),
      ),
    );
  }
}

class _NoTasksCard extends StatelessWidget {
  const _NoTasksCard();

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Center(
          child: Text(
            'No tasks yet — add one to get started.',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
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
          children: [
            const SkeletonBox(width: 220, height: 26, borderRadius: 8),
            const SizedBox(height: 10),
            const SkeletonBox(height: 14, borderRadius: 6),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 80, height: 12, borderRadius: 6),
                  SizedBox(height: 12),
                  SkeletonBox(height: 8, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SkeletonText(lines: 4, lineHeight: 14, spacing: 12),
          ],
        ),
      ),
    );
  }
}