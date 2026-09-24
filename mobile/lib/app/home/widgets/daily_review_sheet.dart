// lib/app/home/widgets/daily_review_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api/api_exception.dart';
import '../../../api/reviews/reviews_api.dart';
import '../../../themes/color-palette.dart';
import '../../../widgets/feedback.dart';

Future<DailyReviewSummary?> showDailyReviewSheet(
  BuildContext context, {
  DailyReviewSummary? existing,
}) {
  return showModalBottomSheet<DailyReviewSummary>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DailyReviewSheet(existing: existing),
  );
}

class _MoodOption {
  final String id;
  final String emoji;
  final String label;

  const _MoodOption({
    required this.id,
    required this.emoji,
    required this.label,
  });
}

const List<_MoodOption> _moodOptions = [
  _MoodOption(id: 'rough', emoji: '😞', label: 'Rough'),
  _MoodOption(id: 'low', emoji: '😕', label: 'Low'),
  _MoodOption(id: 'okay', emoji: '😐', label: 'Okay'),
  _MoodOption(id: 'good', emoji: '🙂', label: 'Good'),
  _MoodOption(id: 'great', emoji: '😄', label: 'Great'),
];

class _DailyReviewSheet extends StatefulWidget {
  final DailyReviewSummary? existing;

  const _DailyReviewSheet({this.existing});

  @override
  State<_DailyReviewSheet> createState() => _DailyReviewSheetState();
}

class _DailyReviewSheetState extends State<_DailyReviewSheet> {
  late final TextEditingController _wins;
  late final TextEditingController _blockers;
  late final TextEditingController _notes;
  final ReviewsApi _api = ReviewsApi();

  String? _mood;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final DailyReviewSummary? existing = widget.existing;
    _wins = TextEditingController(text: existing?.wins ?? '');
    _blockers = TextEditingController(text: existing?.blockers ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _mood = existing?.mood;
  }

  @override
  void dispose() {
    _wins.dispose();
    _blockers.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _hasAnyContent =>
      _wins.text.trim().isNotEmpty ||
      _blockers.text.trim().isNotEmpty ||
      _notes.text.trim().isNotEmpty ||
      _mood != null;

  Future<void> _submit() async {
    if (_isSubmitting || !_hasAnyContent) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final DailyReviewSummary review = await _api.upsertDailyReview(
        reviewDate: DateTime.now(),
        wins: _wins.text.trim().isEmpty ? null : _wins.text.trim(),
        blockers: _blockers.text.trim().isEmpty ? null : _blockers.text.trim(),
        mood: _mood,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(review);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Could not save your review. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.existing != null
                                      ? 'Update your review'
                                      : 'Daily review',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'A moment to reflect on today.',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 13.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel(text: 'How do you feel?'),
                      const SizedBox(height: 12),
                      _MoodPicker(
                        options: _moodOptions,
                        selected: _mood,
                        onChanged: (String id) {
                          setState(() => _mood = _mood == id ? null : id);
                          HapticFeedback.selectionClick();
                        },
                      ),
                      const SizedBox(height: 24),
                      _SectionLabel(text: 'Wins'),
                      const SizedBox(height: 8),
                      _ReviewField(
                        controller: _wins,
                        hint: 'What went well today?',
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel(text: 'Blockers'),
                      const SizedBox(height: 8),
                      _ReviewField(
                        controller: _blockers,
                        hint: 'What got in the way?',
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel(text: 'Anything else'),
                      const SizedBox(height: 8),
                      _ReviewField(
                        controller: _notes,
                        hint: 'Thoughts, ideas, reminders…',
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              (_isSubmitting || !_hasAnyContent) ? null : _submit,
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
                                  widget.existing != null
                                      ? 'Update review'
                                      : 'Save review',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
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

class _MoodPicker extends StatelessWidget {
  final List<_MoodOption> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  const _MoodPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((_MoodOption option) {
        final bool isSelected = option.id == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: option == options.last ? 0 : 8,
            ),
            child: GestureDetector(
              onTap: () => onChanged(option.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.colors.primarySoft
                      : context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      option.emoji,
                      style: const TextStyle(fontSize: 22, height: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.label,
                      style: TextStyle(
                        color: isSelected
                            ? context.colors.primary
                            : context.colors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReviewField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;

  const _ReviewField({
    required this.controller,
    required this.hint,
    this.minLines = 2,
    this.maxLines = 4,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(
        fontSize: 15,
        color: colors.textPrimary,
        height: 1.45,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 14.5,
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