// lib/app/personal/widgets/personal_sheets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api/api_exception.dart';
import '../../../api/personal/personal_api.dart';
import '../../../themes/color-palette.dart';
import '../../../widgets/feedback.dart';

Future<GoalSummary?> showGoalSheet(
  BuildContext context, {
  GoalSummary? existing,
}) =>
    showModalBottomSheet<GoalSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalSheet(existing: existing),
    );

Future<HabitSummary?> showHabitSheet(
  BuildContext context, {
  HabitSummary? existing,
}) =>
    showModalBottomSheet<HabitSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HabitSheet(existing: existing),
    );

Future<JournalEntrySummary?> showJournalSheet(
  BuildContext context, {
  JournalEntrySummary? existing,
}) =>
    showModalBottomSheet<JournalEntrySummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JournalSheet(existing: existing),
    );

class _GoalSheet extends StatefulWidget {
  final GoalSummary? existing;

  const _GoalSheet({this.existing});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  final PersonalApi _api = PersonalApi();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  DateTime? _targetDate;
  String _status = 'active';
  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get _isNew => widget.existing == null;

  static const List<({String id, String label, Color color})> _statuses = [
    (id: 'active', label: 'Active', color: Color(0xFF2C67C5)),
    (id: 'completed', label: 'Completed', color: Color(0xFF4F7F5B)),
    (id: 'archived', label: 'Archived', color: Color(0xFF6B7280)),
  ];

  @override
  void initState() {
    super.initState();
    final GoalSummary? existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _description.text = existing.description ?? '';
      _targetDate = existing.targetDate;
      _status = existing.status;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _submit() async {
    final String title = _title.text.trim();
    if (title.isEmpty || _isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final GoalSummary goal;
      if (_isNew) {
        goal = await _api.createGoal(
          title: title,
          description: _description.text.trim(),
          targetDate: _targetDate,
        );
      } else {
        goal = await _api.updateGoal(
          widget.existing!.id,
          title: title,
          description: _description.text.trim(),
          targetDate: _targetDate,
          status: _status,
        );
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(goal);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Could not save this goal.');
    }
  }

  Future<void> _delete() async {
    if (_isNew || _isDeleting) return;
    final bool? confirmed = await _confirm(
      context,
      title: 'Delete goal?',
      body: 'This goal and its key results will be removed.',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _api.deleteGoal(widget.existing!.id);
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
      showErrorSnackBar(context, 'Could not delete this goal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final double inset = MediaQuery.viewInsetsOf(context).bottom;
    final bool canSubmit = _title.text.trim().isNotEmpty && !_isSubmitting;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: _SheetShell(
        title: _isNew ? 'New goal' : 'Edit goal',
        onDelete: _isNew ? null : _delete,
        isDeleting: _isDeleting,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetField(
              controller: _title,
              hint: 'Goal title',
              autofocus: _isNew,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _SheetField(
              controller: _description,
              hint: 'Why does this matter? (optional)',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 18),
            _SheetDateRow(
              date: _targetDate,
              onTap: _pickDate,
              onClear: _targetDate == null
                  ? null
                  : () => setState(() => _targetDate = null),
            ),
            if (!_isNew) ...[
              const SizedBox(height: 18),
              _SheetLabel(text: 'Status'),
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
            const SizedBox(height: 24),
            _PrimaryButton(
              label: _isNew ? 'Create goal' : 'Save changes',
              isLoading: _isSubmitting,
              onPressed: canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitSheet extends StatefulWidget {
  final HabitSummary? existing;

  const _HabitSheet({this.existing});

  @override
  State<_HabitSheet> createState() => _HabitSheetState();
}

class _HabitSheetState extends State<_HabitSheet> {
  final PersonalApi _api = PersonalApi();
  final TextEditingController _name = TextEditingController();
  String _frequency = 'daily';
  int _targetCount = 1;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get _isNew => widget.existing == null;

  static const List<({String id, String label, Color color})> _frequencies = [
    (id: 'daily', label: 'Daily', color: Color(0xFF2C67C5)),
    (id: 'weekly', label: 'Weekly', color: Color(0xFF4B3F91)),
  ];

  @override
  void initState() {
    super.initState();
    final HabitSummary? existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _frequency = existing.frequency;
      _targetCount = existing.targetCount;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _name.text.trim();
    if (name.isEmpty || _isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final HabitSummary habit;
      if (_isNew) {
        habit = await _api.createHabit(
          name: name,
          frequency: _frequency,
          targetCount: _targetCount,
        );
      } else {
        habit = await _api.updateHabit(
          widget.existing!.id,
          name: name,
          frequency: _frequency,
          targetCount: _targetCount,
        );
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(habit);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Could not save this habit.');
    }
  }

  Future<void> _delete() async {
    if (_isNew || _isDeleting) return;
    final bool? confirmed = await _confirm(
      context,
      title: 'Delete habit?',
      body: 'Your logs will be permanently removed.',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _api.deleteHabit(widget.existing!.id);
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
      showErrorSnackBar(context, 'Could not delete this habit.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double inset = MediaQuery.viewInsetsOf(context).bottom;
    final bool canSubmit = _name.text.trim().isNotEmpty && !_isSubmitting;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: _SheetShell(
        title: _isNew ? 'New habit' : 'Edit habit',
        onDelete: _isNew ? null : _delete,
        isDeleting: _isDeleting,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetField(
              controller: _name,
              hint: 'e.g. Drink water, Read, Meditate',
              autofocus: _isNew,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _SheetLabel(text: 'Frequency'),
            const SizedBox(height: 10),
            _PillRow(
              options: _frequencies,
              selected: _frequency,
              onSelect: (String id) {
                setState(() => _frequency = id);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(height: 20),
            _SheetLabel(text: 'Target per day'),
            const SizedBox(height: 10),
            _CounterRow(
              value: _targetCount,
              onChanged: (int next) {
                setState(() => _targetCount = next);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(height: 24),
            _PrimaryButton(
              label: _isNew ? 'Create habit' : 'Save changes',
              isLoading: _isSubmitting,
              onPressed: canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalSheet extends StatefulWidget {
  final JournalEntrySummary? existing;

  const _JournalSheet({this.existing});

  @override
  State<_JournalSheet> createState() => _JournalSheetState();
}

class _JournalSheetState extends State<_JournalSheet> {
  final PersonalApi _api = PersonalApi();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();

  String? _mood;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get _isNew => widget.existing == null;

  static const List<({String id, String emoji})> _moods = [
    (id: 'rough', emoji: '😞'),
    (id: 'low', emoji: '😕'),
    (id: 'okay', emoji: '😐'),
    (id: 'good', emoji: '🙂'),
    (id: 'great', emoji: '😄'),
  ];

  @override
  void initState() {
    super.initState();
    final JournalEntrySummary? existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title ?? '';
      _content.text = existing.content;
      _mood = existing.mood;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String content = _content.text.trim();
    if (content.isEmpty || _isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final JournalEntrySummary entry;
      if (_isNew) {
        entry = await _api.createJournalEntry(
          title: _title.text.trim(),
          content: content,
          mood: _mood,
          entryDate: DateTime.now(),
        );
      } else {
        entry = await _api.updateJournalEntry(
          widget.existing!.id,
          title: _title.text.trim(),
          content: content,
          mood: _mood,
        );
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(entry);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Could not save this entry.');
    }
  }

  Future<void> _delete() async {
    if (_isNew || _isDeleting) return;
    final bool? confirmed = await _confirm(
      context,
      title: 'Delete entry?',
      body: 'This journal entry will be permanently removed.',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _api.deleteJournalEntry(widget.existing!.id);
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
      showErrorSnackBar(context, 'Could not delete this entry.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double inset = MediaQuery.viewInsetsOf(context).bottom;
    final bool canSubmit = _content.text.trim().isNotEmpty && !_isSubmitting;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: _SheetShell(
        title: _isNew ? 'New entry' : 'Edit entry',
        onDelete: _isNew ? null : _delete,
        isDeleting: _isDeleting,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetField(
              controller: _title,
              hint: 'Title (optional)',
              autofocus: _isNew,
            ),
            const SizedBox(height: 12),
            _SheetField(
              controller: _content,
              hint: 'What\u2019s on your mind?',
              minLines: 5,
              maxLines: 10,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _SheetLabel(text: 'Mood'),
            const SizedBox(height: 10),
            Row(
              children: _moods.map((({String id, String emoji}) mood) {
                final bool selected = _mood == mood.id;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: mood == _moods.last ? 0 : 6,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _mood = selected ? null : mood.id);
                        HapticFeedback.selectionClick();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? context.colors.primarySoft
                              : context.colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? context.colors.primary
                                : context.colors.border,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          mood.emoji,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _PrimaryButton(
              label: _isNew ? 'Save entry' : 'Update entry',
              isLoading: _isSubmitting,
              onPressed: canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirm(
  BuildContext context, {
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

class _SheetShell extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onDelete;
  final bool isDeleting;

  const _SheetShell({
    required this.title,
    required this.child,
    this.onDelete,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Container(
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
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
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
                            title,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (onDelete != null)
                          IconButton(
                            onPressed: isDeleting ? null : onDelete,
                            icon: isDeleting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(
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
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _SheetField({
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
      style: TextStyle(fontSize: 15, color: colors.textPrimary, height: 1.4),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 15),
        filled: true,
        fillColor: colors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: context.colors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        height: 1.2,
      ),
    );
  }
}

class _SheetDateRow extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _SheetDateRow({
    required this.date,
    required this.onTap,
    this.onClear,
  });

  static const List<String> _months = [
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

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return GestureDetector(
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
              Icons.flag_outlined,
              size: 16,
              color: date == null ? colors.textMuted : colors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                date == null
                    ? 'Target date (optional)'
                    : '${_months[date!.month - 1]} ${date!.day}, ${date!.year}',
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

class _CounterRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _CounterRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_rounded, size: 20),
            color: colors.textPrimary,
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: value >= 20 ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded, size: 20),
            color: colors.textPrimary,
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.primary.withValues(alpha: 0.5),
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}