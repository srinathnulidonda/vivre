// lib/app/work/widgets/work_sheets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api/api_exception.dart';
import '../../../api/work/focus_session_service.dart';
import '../../../api/work/work_api.dart';
import '../../../themes/color-palette.dart';
import '../../../widgets/feedback.dart';

Future<ProjectSummary?> showProjectSheet(
  BuildContext context, {
  ProjectSummary? existing,
}) {
  return showModalBottomSheet<ProjectSummary>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProjectSheet(existing: existing),
  );
}

Future<TaskSummary?> showTaskSheet(
  BuildContext context, {
  required String projectId,
  TaskSummary? existing,
  String? initialMilestoneId,
}) {
  return showModalBottomSheet<TaskSummary>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TaskSheet(
      projectId: projectId,
      existing: existing,
      initialMilestoneId: initialMilestoneId,
    ),
  );
}

class _ProjectSheet extends StatefulWidget {
  final ProjectSummary? existing;

  const _ProjectSheet({this.existing});

  @override
  State<_ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends State<_ProjectSheet> {
  final WorkApi _api = WorkApi();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();

  DateTime? _startDate;
  DateTime? _dueDate;
  bool _isSubmitting = false;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final ProjectSummary? existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _description.text = existing.description ?? '';
      _startDate = existing.startDate;
      _dueDate = existing.dueDate;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime? current = isStart ? _startDate : _dueDate;
    final DateTime initial = current ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _dueDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    final String name = _name.text.trim();
    if (name.isEmpty || _isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final ProjectSummary project;
      if (_isNew) {
        project = await _api.createProject(
          name: name,
          description: _description.text.trim(),
          startDate: _startDate,
          dueDate: _dueDate,
        );
      } else {
        project = await _api.updateProject(
          widget.existing!.id,
          name: name,
          description: _description.text.trim(),
          startDate: _startDate,
          dueDate: _dueDate,
        );
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(project);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Could not save this project.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool canSubmit = _name.text.trim().isNotEmpty && !_isSubmitting;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                  _isNew ? 'New project' : 'Edit project',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 20),
                _Field(
                  controller: _name,
                  hint: 'Project name',
                  autofocus: _isNew,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _description,
                  hint: 'Description (optional)',
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Start',
                        date: _startDate,
                        onTap: () => _pickDate(isStart: true),
                        onClear: _startDate == null
                            ? null
                            : () => setState(() => _startDate = null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateField(
                        label: 'Due',
                        date: _dueDate,
                        onTap: () => _pickDate(isStart: false),
                        onClear: _dueDate == null
                            ? null
                            : () => setState(() => _dueDate = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          colors.primary.withValues(alpha: 0.5),
                      elevation: 0,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _isNew ? 'Create project' : 'Save changes',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
}

class _TaskSheet extends StatefulWidget {
  final String projectId;
  final TaskSummary? existing;
  final String? initialMilestoneId;

  const _TaskSheet({
    required this.projectId,
    this.existing,
    this.initialMilestoneId,
  });

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  final WorkApi _api = WorkApi();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();

  String _status = 'todo';
  String _priority = 'medium';
  DateTime? _dueDate;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get _isNew => widget.existing == null;

  static const List<({String id, String label, Color color})> _statuses = [
    (id: 'todo', label: 'To do', color: Color(0xFF6B7280)),
    (id: 'in_progress', label: 'Doing', color: Color(0xFF2C67C5)),
    (id: 'done', label: 'Done', color: Color(0xFF4F7F5B)),
    (id: 'archived', label: 'Archived', color: Color(0xFF8992A0)),
  ];

  static const List<({String id, String label, Color color})> _priorities = [
    (id: 'low', label: 'Low', color: Color(0xFF6B7280)),
    (id: 'medium', label: 'Medium', color: Color(0xFF2C67C5)),
    (id: 'high', label: 'High', color: Color(0xFFA8792F)),
    (id: 'urgent', label: 'Urgent', color: Color(0xFFA94D3D)),
  ];

  @override
  void initState() {
    super.initState();
    final TaskSummary? existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _description.text = existing.description ?? '';
      _status = existing.status;
      _priority = existing.priority;
      _dueDate = existing.dueDate;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _dueDate = DateTime(picked.year, picked.month, picked.day, 12);
    });
  }

  Future<void> _submit() async {
    final String title = _title.text.trim();
    if (title.isEmpty || _isSubmitting || _isDeleting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final TaskSummary task;
      if (_isNew) {
        task = await _api.createTask(
          title: title,
          description: _description.text.trim(),
          projectId: widget.projectId,
          milestoneId: widget.initialMilestoneId,
          priority: _priority,
          dueDate: _dueDate,
        );
      } else {
        task = await _api.updateTask(
          widget.existing!.id,
          title: title,
          description: _description.text.trim(),
          status: _status,
          priority: _priority,
          dueDate: _dueDate,
        );
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(task);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Could not save this task.');
    }
  }

  Future<void> _startFocus() async {
    final TaskSummary? task = widget.existing;
    if (task == null) return;
    if (FocusSessionService.instance.isRunning) return;
    try {
      await FocusSessionService.instance.start(
        taskId: task.id,
        projectId: widget.projectId,
        taskLabel: task.title,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not start a focus session.');
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
            'Delete task?',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This task will be permanently removed.',
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
      await _api.deleteTask(widget.existing!.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      showErrorSnackBar(context, 'Could not delete this task.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool canSubmit = _title.text.trim().isNotEmpty &&
        !_isSubmitting &&
        !_isDeleting;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
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
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _isNew ? 'New task' : 'Edit task',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (!_isNew)
                            IconButton(
                              onPressed: _delete,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                              ),
                              color: colors.textSecondary,
                              tooltip: 'Delete',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _Field(
                        controller: _title,
                        hint: 'Task title',
                        autofocus: _isNew,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _description,
                        hint: 'Description (optional)',
                        minLines: 3,
                        maxLines: 5,
                      ),
                      if (!_isNew) ...[
                        const SizedBox(height: 22),
                        _SectionLabel(text: 'Status'),
                        const SizedBox(height: 10),
                        _PillRow(
                          options: _statuses,
                          selected: _status,
                          onSelect: (String id) {
                            setState(() => _status = id);
                            HapticFeedback.selectionClick();
                          },
                        ),
                      ],
                      const SizedBox(height: 22),
                      _SectionLabel(text: 'Priority'),
                      const SizedBox(height: 10),
                      _PillRow(
                        options: _priorities,
                        selected: _priority,
                        onSelect: (String id) {
                          setState(() => _priority = id);
                          HapticFeedback.selectionClick();
                        },
                      ),
                      const SizedBox(height: 22),
                      _SectionLabel(text: 'Due date'),
                      const SizedBox(height: 10),
                      _DateField(
                        label: _dueDate == null ? 'Set a date' : '',
                        date: _dueDate,
                        onTap: _pickDueDate,
                        onClear: _dueDate == null
                            ? null
                            : () => setState(() => _dueDate = null),
                        fullWidth: true,
                      ),
                      if (!_isNew) ...[
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: FocusSessionService.instance.isRunning
                                ? null
                                : _startFocus,
                            icon: const Icon(Icons.bolt_rounded, size: 18),
                            label: Text(
                              FocusSessionService.instance.isRunning
                                  ? 'Session in progress'
                                  : 'Start focus session',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: colors.surface,
                              foregroundColor: colors.primary,
                              side: BorderSide(color: colors.border),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canSubmit ? _submit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                colors.primary.withValues(alpha: 0.5),
                            elevation: 0,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  _isNew ? 'Create task' : 'Save changes',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(
        fontSize: 15,
        color: colors.textPrimary,
        height: 1.4,
      ),
      decoration: InputDecoration(
        hintText: hint,
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
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: colors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        height: 1.2,
      ),
    );
  }
}

class _PillRow extends StatelessWidget {
  final List<({String id, String label, Color color})> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _PillRow({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(options.length, (int i) {
        final ({String id, String label, Color color}) option = options[i];
        final bool isSelected = option.id == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: i == options.length - 1 ? 0 : 6,
            ),
            child: GestureDetector(
              onTap: () => onSelect(option.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? option.color.withValues(alpha: 0.12)
                      : context.colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? option.color : context.colors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  option.label,
                  style: TextStyle(
                    color: isSelected
                        ? option.color
                        : context.colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool fullWidth;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
    this.fullWidth = false,
  });

  String _format(DateTime d) {
    final List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final String text = date == null ? label : _format(date!);
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: date == null ? colors.border : colors.primary,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: date == null ? colors.textMuted : colors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        date == null ? colors.textMuted : colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: colors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}