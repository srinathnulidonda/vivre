// lib/app/home/widgets/home_cards.dart
import 'package:flutter/material.dart';

import '../../../api/health/health_api.dart';
import '../../../api/notes/notes_api.dart';
import '../../../api/personal/personal_api.dart';
import '../../../api/reviews/reviews_api.dart';
import '../../../api/shared/shared_api.dart';
import '../../../themes/color-palette.dart';
import '../../../widgets/skeleton_loader.dart';

class StatItem {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}

const Color _kAccentEvent = Color(0xFF2C67C5);
const Color _kAccentTask = Color(0xFF2F6B3F);
const Color _kAccentTimeBlock = Color(0xFF4B3F91);
const Color _kAccentFocus = Color(0xFF8A6D1E);
const Color _kAccentHealth = Color(0xFFC23B4A);

Color _timelineAccent(String itemType) {
  switch (itemType) {
    case 'event':
      return _kAccentEvent;
    case 'task':
      return _kAccentTask;
    case 'time_block':
      return _kAccentTimeBlock;
    case 'focus_session':
      return _kAccentFocus;
    default:
      return _kAccentEvent;
  }
}

class GreetingSection extends StatelessWidget {
  final String greeting;
  final String name;
  final DateTime date;

  const GreetingSection({
    super.key,
    required this.greeting,
    required this.name,
    required this.date,
  });

  static const List<String> _weekdays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];

  static const List<String> _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  String get _eyebrow =>
      '${_weekdays[date.weekday - 1]} · ${_months[date.month - 1]} ${date.day}';

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _eyebrow,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$greeting,\n'),
                TextSpan(
                  text: name,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(text: ' 👋'),
              ],
            ),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 29,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class TodayCard extends StatelessWidget {
  final List<TimelineEntry> timeline;
  final bool isLoading;
  final VoidCallback? onViewAll;

  const TodayCard({
    super.key,
    required this.timeline,
    this.isLoading = false,
    this.onViewAll,
  });

  List<TimelineEntry> get _visible {
    final List<TimelineEntry> sorted = List<TimelineEntry>.from(timeline)
      ..sort((TimelineEntry a, TimelineEntry b) {
        final DateTime aStart = a.startAt ?? DateTime(9999);
        final DateTime bStart = b.startAt ?? DateTime(9999);
        return aStart.compareTo(bStart);
      });
    return sorted.take(4).toList();
  }

  String get _summary {
    if (timeline.isEmpty) return 'Nothing scheduled';
    final int events = timeline.where((e) => e.isEvent).length;
    final int tasks = timeline.where((e) => e.isTask).length;
    final List<String> parts = <String>[];
    if (events > 0) parts.add('$events ${events == 1 ? 'event' : 'events'}');
    if (tasks > 0) parts.add('$tasks ${tasks == 1 ? 'task' : 'tasks'}');
    if (parts.isEmpty) return '${timeline.length} scheduled';
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: _SectionCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.wb_sunny_outlined,
              title: 'Today',
              subtitle: isLoading ? 'Loading…' : _summary,
            ),
            const SizedBox(height: 18),
            if (isLoading)
              const _TimelineSkeleton()
            else if (_visible.isEmpty)
              _EmptyRow(
                icon: Icons.event_available_outlined,
                message: 'Your day is clear. Enjoy it.',
              )
            else
              for (int i = 0; i < _visible.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == _visible.length - 1 ? 0 : 14,
                  ),
                  child: _TimelineRow(item: _visible[i]),
                ),
            const SizedBox(height: 8),
            _CardFooter(label: 'View timeline', onTap: onViewAll),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineEntry item;

  const _TimelineRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            item.timeLabel,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _timelineAccent(item.itemType),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      isLoading: true,
      child: Column(
        children: const [
          _SkeletonRow(),
          SizedBox(height: 14),
          _SkeletonRow(),
          SizedBox(height: 14),
          _SkeletonRow(),
        ],
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SkeletonBox(width: 40, height: 12, borderRadius: 4),
        SizedBox(width: 20),
        Expanded(child: SkeletonBox(height: 14, borderRadius: 6)),
      ],
    );
  }
}

class QuickStatsRow extends StatelessWidget {
  final List<StatItem> stats;

  const QuickStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: List.generate(stats.length, (int i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == stats.length - 1 ? 0 : 10),
              child: _StatTile(item: stats[i]),
            ),
          );
        }),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final StatItem item;

  const _StatTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        children: [
          Icon(item.icon, color: item.color, size: 20),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class HabitsCard extends StatelessWidget {
  final List<HabitSummary> habits;
  final Map<String, int> streaks;
  final bool isLoading;
  final VoidCallback? onViewAll;

  const HabitsCard({
    super.key,
    required this.habits,
    required this.streaks,
    this.isLoading = false,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final int totalStreak = streaks.values.fold(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: _SectionCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.eco_outlined,
              iconColor: const Color(0xFF2F6B3F),
              title: 'Habits',
              subtitle: isLoading
                  ? 'Loading…'
                  : '${habits.length} active · $totalStreak day streak',
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const _ListSkeleton(rows: 3)
            else if (habits.isEmpty)
              _EmptyRow(
                icon: Icons.spa_outlined,
                message: 'Start your first habit today.',
              )
            else
              for (int i = 0; i < habits.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == habits.length - 1 ? 0 : 12,
                  ),
                  child: _HabitRow(
                    habit: habits[i],
                    streak: streaks[habits[i].id] ?? 0,
                    accent: colors.primary,
                  ),
                ),
            if (habits.isNotEmpty) ...[
              const SizedBox(height: 6),
              _CardFooter(label: 'All habits', onTap: onViewAll),
            ],
          ],
        ),
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  final HabitSummary habit;
  final int streak;
  final Color accent;

  const _HabitRow({
    required this.habit,
    required this.streak,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.check_rounded,
            color: colors.primary,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            habit.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
        if (streak > 0)
          _StreakPill(streak: streak)
        else
          Text(
            'Start today',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}

class _StreakPill extends StatelessWidget {
  final int streak;

  const _StreakPill({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF0C8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: Color(0xFF8A6D1E),
            size: 13,
          ),
          const SizedBox(width: 3),
          Text(
            '${streak}d',
            style: const TextStyle(
              color: Color(0xFF8A6D1E),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class RecentNotesCard extends StatelessWidget {
  final List<NoteSummary> notes;
  final bool isLoading;
  final VoidCallback? onViewAll;
  final ValueChanged<NoteSummary>? onNoteTap;

  const RecentNotesCard({
    super.key,
    required this.notes,
    this.isLoading = false,
    this.onViewAll,
    this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: _SectionCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.description_outlined,
              iconColor: const Color(0xFF4B3F91),
              title: 'Recent notes',
              subtitle: isLoading
                  ? 'Loading…'
                  : (notes.isEmpty
                      ? 'Capture your first thought'
                      : '${notes.length} recently edited'),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const _ListSkeleton(rows: 3)
            else if (notes.isEmpty)
              _EmptyRow(
                icon: Icons.edit_note_outlined,
                message: 'No notes yet. Start writing.',
              )
            else
              for (int i = 0; i < notes.length; i++)
                _NoteRow(
                  note: notes[i],
                  onTap: onNoteTap == null ? null : () => onNoteTap!(notes[i]),
                  showDivider: i < notes.length - 1,
                ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              _CardFooter(label: 'All notes', onTap: onViewAll),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final NoteSummary note;
  final VoidCallback? onTap;
  final bool showDivider;

  const _NoteRow({
    required this.note,
    this.onTap,
    this.showDivider = true,
  });

  String get _relative {
    final Duration diff = DateTime.now().difference(note.updatedAt.toLocal());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${note.updatedAt.month}/${note.updatedAt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (note.isPinned) ...[
                            Icon(
                              Icons.push_pin_rounded,
                              size: 13,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        note.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _relative,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(color: colors.border, height: 1, thickness: 0.6),
      ],
    );
  }
}

class DailyReviewCard extends StatelessWidget {
  final DailyReviewSummary? review;
  final bool isLoading;
  final VoidCallback? onReflect;

  const DailyReviewCard({
    super.key,
    required this.review,
    this.isLoading = false,
    this.onReflect,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final bool hasReview = review != null && review!.hasContent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: _SectionCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasReview
                        ? Icons.check_circle_rounded
                        : Icons.auto_awesome_outlined,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAILY REVIEW',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasReview
                            ? 'You reflected today'
                            : 'How was your day?',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isLoading)
              const SkeletonLoader(
                isLoading: true,
                child: SkeletonText(lines: 2, widthFactors: [1.0, 0.65]),
              )
            else if (hasReview)
              _ReviewSummary(review: review!)
            else
              Text(
                'Take 30 seconds to note your wins, blockers, and how you feel.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            if (!isLoading && !hasReview) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onReflect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Reflect now',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  final DailyReviewSummary review;

  const _ReviewSummary({required this.review});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final String? wins = review.wins;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (review.mood != null && review.mood!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Text(
              'Mood · ${review.mood}',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          (wins != null && wins.isNotEmpty)
              ? wins
              : 'Logged today — nothing noted yet.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontStyle: FontStyle.italic,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class HealthCard extends StatelessWidget {
  final DailyMetricsSummary? metrics;
  final bool isLoading;
  final VoidCallback? onOpen;

  const HealthCard({
    super.key,
    required this.metrics,
    this.isLoading = false,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: _SectionCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.favorite_border_rounded,
              iconColor: _kAccentHealth,
              iconBg: const Color(0xFFFBDEE1),
              title: 'Health today',
              subtitle: isLoading ? 'Loading…' : _subtitle,
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const SkeletonLoader(
                isLoading: true,
                child: Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 44)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 44)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 44)),
                  ],
                ),
              )
            else if (metrics == null)
              _EmptyRow(
                icon: Icons.watch_outlined,
                message: 'Connect a device to see today\u2019s stats.',
              )
            else
              Row(
                children: [
                  _HealthStat(
                    value: _formatInt(metrics!.steps),
                    label: 'Steps',
                    color: _kAccentHealth,
                  ),
                  _divider(colors),
                  _HealthStat(
                    value: metrics!.distanceKm.toStringAsFixed(1),
                    label: 'km',
                    color: _kAccentHealth,
                  ),
                  _divider(colors),
                  _HealthStat(
                    value: _formatInt(metrics!.activeCalories.round()),
                    label: 'kcal',
                    color: _kAccentHealth,
                  ),
                ],
              ),
            if (!isLoading && metrics != null) ...[
              const SizedBox(height: 10),
              _CardFooter(label: 'Open health', onTap: onOpen),
            ],
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    if (metrics == null) return 'No data yet';
    return 'Steps · distance · calories';
  }

  static String _formatInt(int value) {
    final String s = value.toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  Widget _divider(VivreColors colors) {
    return Container(
      width: 1,
      height: 32,
      color: colors.border,
    );
  }
}

class _HealthStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _HealthStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Color? iconBg;

  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconBg ?? colors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor ?? colors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardFooter extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _CardFooter({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: colors.primary,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.primary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_rounded,
              color: colors.primary,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyRow({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: colors.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  final int rows;

  const _ListSkeleton({this.rows = 3});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      isLoading: true,
      child: Column(
        children: List.generate(rows, (int i) {
          return Padding(
            padding: EdgeInsets.only(bottom: i == rows - 1 ? 0 : 14),
            child: Row(
              children: const [
                SkeletonCircle(size: 32),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 14, borderRadius: 6)),
                SizedBox(width: 12),
                SkeletonBox(width: 42, height: 20, borderRadius: 10),
              ],
            ),
          );
        }),
      ),
    );
  }
}