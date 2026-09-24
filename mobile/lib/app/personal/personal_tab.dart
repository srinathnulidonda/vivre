// lib/app/personal/personal_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/personal/personal_api.dart';
import '../../themes/color-palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/skeleton_loader.dart';
import 'widgets/personal_sheets.dart';

enum _Section { goals, habits, journal }

class PersonalTab extends StatefulWidget {
  const PersonalTab({super.key});

  @override
  State<PersonalTab> createState() => _PersonalTabState();
}

class _PersonalTabState extends State<PersonalTab> {
  _Section _section = _Section.goals;

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal',
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
                      'Goals, habits, and reflection.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _Segmented(
            selected: _section,
            onSelect: (_Section next) {
              if (next == _section) return;
              HapticFeedback.selectionClick();
              setState(() => _section = next);
            },
          ),
        ),
        Expanded(
          child: switch (_section) {
            _Section.goals => const _GoalsView(),
            _Section.habits => const _HabitsView(),
            _Section.journal => const _JournalView(),
          },
        ),
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  final _Section selected;
  final ValueChanged<_Section> onSelect;

  const _Segmented({required this.selected, required this.onSelect});

  static const List<({_Section section, String label})> _items = [
    (section: _Section.goals, label: 'Goals'),
    (section: _Section.habits, label: 'Habits'),
    (section: _Section.journal, label: 'Journal'),
  ];

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: _items.map((({_Section section, String label}) item) {
          final bool isSelected = item.section == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(item.section),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected
                        ? colors.textPrimary
                        : colors.textSecondary,
                    fontSize: 13.5,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GoalsView extends StatefulWidget {
  const _GoalsView();

  @override
  State<_GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends State<_GoalsView> {
  final PersonalApi _api = PersonalApi();
  List<GoalSummary> _goals = const [];
  bool _isLoading = true;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final List<GoalSummary> goals = await _api.listGoals(
        status: _showCompleted ? null : 'active',
        limit: 60,
      );
      if (!mounted) return;
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _goals = const [];
        _isLoading = false;
      });
    }
  }

  Future<void> _create() async {
    final GoalSummary? created = await showGoalSheet(context);
    if (created == null || !mounted) return;
    await _load();
  }

  Future<void> _edit(GoalSummary goal) async {
    final GoalSummary? updated =
        await showGoalSheet(context, existing: goal);
    if (updated == null || !mounted) return;
    await _load();
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          _isLoading
                              ? 'Loading…'
                              : '${_goals.length} ${_showCompleted ? 'total' : 'active'}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _MiniToggle(
                          label: 'Show completed',
                          value: _showCompleted,
                          onChanged: (bool next) {
                            setState(() => _showCompleted = next);
                            _load();
                          },
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _create,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'New',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primarySoft,
                      foregroundColor: colors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(child: _ListViewSkeleton())
          else if (_goals.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyBlock(
                icon: Icons.flag_outlined,
                title: 'Start your first goal',
                message:
                    'A goal is a future you choose. Write it down and give it a target.',
              ),
            )
          else
            SliverList.separated(
              itemCount: _goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _GoalCard(
                    goal: _goals[index],
                    onTap: () => _edit(_goals[index]),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final GoalSummary goal;
  final VoidCallback onTap;

  const _GoalCard({required this.goal, required this.onTap});

  (String, Color, Color) _status(VivreColors colors) {
    switch (goal.status) {
      case 'completed':
        return ('Completed', const Color(0xFF4F7F5B), const Color(0xFFDFF3E3));
      case 'archived':
        return ('Archived', colors.textMuted, colors.surfaceSoft);
      default:
        return ('Active', colors.primary, colors.primarySoft);
    }
  }

  String? get _targetLabel {
    final DateTime? date = goal.targetDate;
    if (date == null) return null;
    final DateTime local = date.toLocal();
    final int days = local.difference(DateTime.now()).inDays;
    if (days < 0) return 'Past due';
    if (days == 0) return 'Due today';
    if (days < 30) return '${days}d left';
    return '${local.month}/${local.day}';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final (String label, Color fg, Color bg) = _status(colors);
    final String? target = _targetLabel;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (target != null)
                    Text(
                      target,
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
                goal.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  height: 1.3,
                ),
              ),
              if (goal.description != null &&
                  goal.description!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  goal.description!,
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

class _HabitsView extends StatefulWidget {
  const _HabitsView();

  @override
  State<_HabitsView> createState() => _HabitsViewState();
}

class _HabitsViewState extends State<_HabitsView> {
  final PersonalApi _api = PersonalApi();
  List<HabitSummary> _habits = const [];
  Map<String, int> _todayCounts = const {};
  Map<String, int> _streaks = const {};
  bool _isLoading = true;
  final Set<String> _logging = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final List<HabitSummary> habits = await _api.listHabits(limit: 50);
      final Map<String, int> todayCounts = <String, int>{};
      final Map<String, int> streaks = <String, int>{};

      await Future.wait(habits.map((HabitSummary habit) async {
        try {
          final List<HabitLogSummary> logs =
              await _api.listHabitLogs(habit.id, limit: 30);
          todayCounts[habit.id] =
              logs.where((HabitLogSummary l) => l.isToday).fold(
                    0,
                    (int sum, HabitLogSummary l) => sum + l.count,
                  );
        } catch (_) {
          todayCounts[habit.id] = 0;
        }
        try {
          streaks[habit.id] = await _api.habitStreak(habit.id);
        } catch (_) {
          streaks[habit.id] = 0;
        }
      }));

      if (!mounted) return;
      setState(() {
        _habits = habits;
        _todayCounts = todayCounts;
        _streaks = streaks;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _habits = const [];
        _isLoading = false;
      });
    }
  }

  Future<void> _logHabit(HabitSummary habit) async {
    final int current = _todayCounts[habit.id] ?? 0;
    if (current >= habit.targetCount) return;
    if (_logging.contains(habit.id)) return;

    setState(() => _logging.add(habit.id));

    try {
      final HabitLogSummary log = await _api.logHabit(
        habit.id,
        logDate: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _todayCounts = {
          ..._todayCounts,
          habit.id: (_todayCounts[habit.id] ?? 0) + log.count,
        };
        _logging.remove(habit.id);
      });
      HapticFeedback.selectionClick();
      if ((_todayCounts[habit.id] ?? 0) >= habit.targetCount) {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _logging.remove(habit.id));
      showErrorSnackBar(context, 'Could not log this habit.');
    }
  }

  Future<void> _create() async {
    final HabitSummary? created = await showHabitSheet(context);
    if (created == null || !mounted) return;
    await _load();
  }

  Future<void> _edit(HabitSummary habit) async {
    final HabitSummary? updated =
        await showHabitSheet(context, existing: habit);
    if (updated == null || !mounted) return;
    await _load();
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: Row(
                children: [
                  Text(
                    _isLoading
                        ? 'Loading…'
                        : '${_habits.length} active',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _create,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'New',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primarySoft,
                      foregroundColor: colors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(child: _ListViewSkeleton())
          else if (_habits.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyBlock(
                icon: Icons.eco_outlined,
                title: 'Build your first habit',
                message:
                    'Small daily actions compound. Start with one you can keep.',
              ),
            )
          else
            SliverList.separated(
              itemCount: _habits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final HabitSummary habit = _habits[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _HabitRow(
                    habit: habit,
                    todayCount: _todayCounts[habit.id] ?? 0,
                    streak: _streaks[habit.id] ?? 0,
                    isLogging: _logging.contains(habit.id),
                    onLog: () => _logHabit(habit),
                    onEdit: () => _edit(habit),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  final HabitSummary habit;
  final int todayCount;
  final int streak;
  final bool isLogging;
  final VoidCallback onLog;
  final VoidCallback onEdit;

  const _HabitRow({
    required this.habit,
    required this.todayCount,
    required this.streak,
    required this.isLogging,
    required this.onLog,
    required this.onEdit,
  });

  bool get _done => todayCount >= habit.targetCount;

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (streak > 0) ...[
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFF8A6D1E),
                            size: 13,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$streak',
                            style: const TextStyle(
                              color: Color(0xFF8A6D1E),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          habit.frequency == 'weekly' ? 'Weekly' : 'Daily',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$todayCount/${habit.targetCount}',
                          style: TextStyle(
                            color: _done
                                ? const Color(0xFF4F7F5B)
                                : colors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _LogButton(
                done: _done,
                isLogging: isLogging,
                onTap: onLog,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogButton extends StatelessWidget {
  final bool done;
  final bool isLogging;
  final VoidCallback onTap;

  const _LogButton({
    required this.done,
    required this.isLogging,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return GestureDetector(
      onTap: done || isLogging ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done ? colors.success : colors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: isLogging
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                done ? Icons.check_rounded : Icons.add_rounded,
                color: done ? Colors.white : colors.primary,
                size: 22,
              ),
      ),
    );
  }
}

class _JournalView extends StatefulWidget {
  const _JournalView();

  @override
  State<_JournalView> createState() => _JournalViewState();
}

class _JournalViewState extends State<_JournalView> {
  final PersonalApi _api = PersonalApi();
  List<JournalEntrySummary> _entries = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final List<JournalEntrySummary> entries =
          await _api.listJournalEntries(limit: 60);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entries = const [];
        _isLoading = false;
      });
    }
  }

  Future<void> _create() async {
    final JournalEntrySummary? created = await showJournalSheet(context);
    if (created == null || !mounted) return;
    await _load();
  }

  Future<void> _edit(JournalEntrySummary entry) async {
    final JournalEntrySummary? updated =
        await showJournalSheet(context, existing: entry);
    if (updated == null || !mounted) return;
    await _load();
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: Row(
                children: [
                  Text(
                    _isLoading ? 'Loading…' : '${_entries.length} entries',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _create,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'New',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primarySoft,
                      foregroundColor: colors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(child: _ListViewSkeleton())
          else if (_entries.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyBlock(
                icon: Icons.menu_book_outlined,
                title: 'Write your first entry',
                message:
                    'Reflect on your thoughts — even a few lines a day adds up.',
              ),
            )
          else
            SliverList.separated(
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _JournalTile(
                    entry: _entries[index],
                    onTap: () => _edit(_entries[index]),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _JournalTile extends StatelessWidget {
  final JournalEntrySummary entry;
  final VoidCallback onTap;

  const _JournalTile({required this.entry, required this.onTap});

  static const Map<String, String> _moodEmoji = {
    'rough': '😞',
    'low': '😕',
    'okay': '😐',
    'good': '🙂',
    'great': '😄',
  };

  String get _dateLabel {
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
    return '${months[entry.entryDate.month - 1]} ${entry.entryDate.day}';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final String? emoji = _moodEmoji[entry.mood];
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _dateLabel,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  if (emoji != null)
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                ],
              ),
              if (entry.title != null && entry.title!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  entry.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                entry.preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MiniToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value ? colors.primarySoft : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value ? colors.primary : colors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: value ? colors.primary : colors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyBlock({
    required this.icon,
    required this.title,
    required this.message,
  });

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
            child: Icon(icon, color: colors.primary, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
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

class _ListViewSkeleton extends StatelessWidget {
  const _ListViewSkeleton();

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
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 70, height: 16, borderRadius: 8),
                    SizedBox(height: 14),
                    SkeletonBox(height: 15, borderRadius: 6),
                    SizedBox(height: 8),
                    SkeletonBox(width: 220, height: 12, borderRadius: 6),
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