// lib/app/health/health_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_exception.dart';
import '../../api/health/health_api.dart';
import '../../themes/color-palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/skeleton_loader.dart';
import 'widgets/health_sheets.dart';

enum _HealthSection { today, workouts, devices }

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final HealthApi _api = HealthApi();

  _HealthSection _section = _HealthSection.today;
  DailyMetricsSummary? _todayMetrics;
  SleepSummary? _todaySleep;
  List<WorkoutSummary> _workouts = const [];
  List<DeviceConnectionSummary> _devices = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final List<DailyMetricsSummary> metrics =
          await _api.listDailyMetrics(limit: 7);
      final List<SleepSummary> sleep = await _api.listSleepRecords(limit: 7);
      final List<WorkoutSummary> workouts =
          await _api.listWorkouts(limit: 30);
      final List<DeviceConnectionSummary> devices =
          await _api.listDeviceConnections();

      DailyMetricsSummary? todayMetrics;
      for (final DailyMetricsSummary m in metrics) {
        if (m.isToday) {
          todayMetrics = m;
          break;
        }
      }
      SleepSummary? todaySleep;
      for (final SleepSummary s in sleep) {
        if (s.isToday) {
          todaySleep = s;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _todayMetrics = todayMetrics;
        _todaySleep = todaySleep;
        _workouts = workouts;
        _devices = devices;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editMetrics() async {
    final DailyMetricsSummary? updated = await showDailyMetricsSheet(
      context,
      existing: _todayMetrics,
    );
    if (updated == null || !mounted) return;
    await _load();
  }

  Future<void> _editSleep() async {
    final SleepSummary? updated = await showSleepSheet(
      context,
      existing: _todaySleep,
    );
    if (updated == null || !mounted) return;
    await _load();
  }

  Future<void> _addWorkout() async {
    final WorkoutSummary? created = await showWorkoutSheet(context);
    if (created == null || !mounted) return;
    await _load();
  }

  Future<void> _deleteWorkout(WorkoutSummary workout) async {
    final bool? confirmed = await _confirm(
      context,
      title: 'Delete workout?',
      body: 'This workout will be permanently removed.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteWorkout(workout.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not delete this workout.');
    }
  }

  Future<void> _connectDevice() async {
    final DevicePlatform? platform = await showDevicePicker(context);
    if (platform == null || !mounted) return;
    try {
      await _api.connectDevice(platform);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not connect this device.');
    }
  }

  Future<void> _disconnectDevice(DeviceConnectionSummary device) async {
    final bool? confirmed = await _confirm(
      context,
      title: 'Disconnect ${device.platform.label}?',
      body: 'You can reconnect anytime.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.disconnectDevice(device.id);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not disconnect this device.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: colors.textPrimary,
        ),
        titleSpacing: 0,
        title: Text(
          'Health',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _Segmented(
              selected: _section,
              onSelect: (_HealthSection next) {
                if (next == _section) return;
                HapticFeedback.selectionClick();
                setState(() => _section = next);
              },
            ),
          ),
          Expanded(
            child: switch (_section) {
              _HealthSection.today => _TodayView(
                  metrics: _todayMetrics,
                  sleep: _todaySleep,
                  isLoading: _isLoading,
                  onRefresh: _load,
                  onEditMetrics: _editMetrics,
                  onEditSleep: _editSleep,
                ),
              _HealthSection.workouts => _WorkoutsView(
                  workouts: _workouts,
                  isLoading: _isLoading,
                  onRefresh: _load,
                  onCreate: _addWorkout,
                  onDelete: _deleteWorkout,
                ),
              _HealthSection.devices => _DevicesView(
                  devices: _devices,
                  isLoading: _isLoading,
                  onRefresh: _load,
                  onConnect: _connectDevice,
                  onDisconnect: _disconnectDevice,
                ),
            },
          ),
        ],
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
              'Confirm',
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

class _Segmented extends StatelessWidget {
  final _HealthSection selected;
  final ValueChanged<_HealthSection> onSelect;

  const _Segmented({required this.selected, required this.onSelect});

  static const List<({_HealthSection section, String label})> _items = [
    (section: _HealthSection.today, label: 'Today'),
    (section: _HealthSection.workouts, label: 'Workouts'),
    (section: _HealthSection.devices, label: 'Devices'),
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
        children: _items.map((({_HealthSection section, String label}) item) {
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

class _TodayView extends StatelessWidget {
  final DailyMetricsSummary? metrics;
  final SleepSummary? sleep;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditMetrics;
  final VoidCallback onEditSleep;

  const _TodayView({
    required this.metrics,
    required this.sleep,
    required this.isLoading,
    required this.onRefresh,
    required this.onEditMetrics,
    required this.onEditSleep,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: context.colors.primary,
      backgroundColor: context.colors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          if (isLoading)
            const SliverToBoxAdapter(child: _TodaySkeleton())
          else ...[
            SliverToBoxAdapter(
              child: _MetricsCard(
                metrics: metrics,
                onEdit: onEditMetrics,
              ),
            ),
            SliverToBoxAdapter(
              child: _SleepCard(sleep: sleep, onEdit: onEditSleep),
            ),
            if (metrics == null && sleep == null)
              const SliverToBoxAdapter(child: _EmptyHint()),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final DailyMetricsSummary? metrics;
  final VoidCallback onEdit;

  const _MetricsCard({required this.metrics, required this.onEdit});

  static String _formatInt(int value) {
    final String s = value.toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final DailyMetricsSummary? m = metrics;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                    color: const Color(0xFFFBDEE1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    color: Color(0xFFC23B4A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today',
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
                        m == null ? 'Nothing logged yet' : 'Steps · distance · calories',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      m == null ? 'Log' : 'Edit',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _Stat(
                  value: m == null ? '—' : _formatInt(m.steps),
                  label: 'Steps',
                  color: const Color(0xFFC23B4A),
                ),
                _divider(colors),
                _Stat(
                  value: m == null ? '—' : m.distanceKm.toStringAsFixed(1),
                  label: 'km',
                  color: const Color(0xFFC23B4A),
                ),
                _divider(colors),
                _Stat(
                  value: m == null
                      ? '—'
                      : _formatInt(m.activeCalories.round()),
                  label: 'kcal',
                  color: const Color(0xFFC23B4A),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(VivreColors colors) {
    return Container(
      width: 1,
      height: 32,
      color: colors.border,
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Stat({
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
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
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

class _SleepCard extends StatelessWidget {
  final SleepSummary? sleep;
  final VoidCallback onEdit;

  const _SleepCard({required this.sleep, required this.onEdit});

  String? get _timeRange {
    final SleepSummary? s = sleep;
    if (s == null) return null;
    final DateTime bed = s.startAt.toLocal();
    final DateTime wake = s.endAt.toLocal();
    final String bedH = bed.hour.toString().padLeft(2, '0');
    final String bedM = bed.minute.toString().padLeft(2, '0');
    final String wakeH = wake.hour.toString().padLeft(2, '0');
    final String wakeM = wake.minute.toString().padLeft(2, '0');
    return '$bedH:$bedM → $wakeH:$wakeM';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final SleepSummary? s = sleep;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border, width: 1),
        ),
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
                    color: const Color(0xFFE6E1F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.nightlight_round,
                    color: Color(0xFF4B3F91),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sleep',
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
                        s == null
                            ? 'Not logged'
                            : '${
                                _timeRange!
                              }${s.quality == null ? '' : ' · ${s.quality}'}',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      s == null ? 'Log' : 'Edit',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  s == null ? '—' : s.durationLabel,
                  style: TextStyle(
                    color: const Color(0xFF4B3F91),
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.05,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'of rest',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: Column(
        children: [
          Icon(
            Icons.monitor_heart_outlined,
            size: 40,
            color: colors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Tap Log to record your day.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutsView extends StatelessWidget {
  final List<WorkoutSummary> workouts;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreate;
  final ValueChanged<WorkoutSummary> onDelete;

  const _WorkoutsView({
    required this.workouts,
    required this.isLoading,
    required this.onRefresh,
    required this.onCreate,
    required this.onDelete,
  });

  String _dateLabel(DateTime start) {
    final DateTime local = start.toLocal();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(local.year, local.month, local.day);
    final int days = today.difference(target).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '${days} days ago';
    return '${local.month}/${local.day}';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return RefreshIndicator(
      onRefresh: onRefresh,
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
                    isLoading
                        ? 'Loading…'
                        : '${workouts.length} logged',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: onCreate,
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
          if (isLoading)
            const SliverToBoxAdapter(child: _ListViewSkeleton())
          else if (workouts.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyBlock(
                icon: Icons.fitness_center_outlined,
                title: 'No workouts yet',
                message:
                    'Log a walk, run, or anything you did today — it adds up.',
              ),
            )
          else
            SliverList.separated(
              itemCount: workouts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final WorkoutSummary w = workouts[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _WorkoutRow(
                    workout: w,
                    dateLabel: _dateLabel(w.startAt),
                    onDelete: () => onDelete(w),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  final WorkoutSummary workout;
  final String dateLabel;
  final VoidCallback onDelete;

  const _WorkoutRow({
    required this.workout,
    required this.dateLabel,
    required this.onDelete,
  });

  IconData _icon() {
    final String type = workout.workoutType.toLowerCase();
    if (type.contains('run')) return Icons.directions_run_rounded;
    if (type.contains('walk')) return Icons.directions_walk_rounded;
    if (type.contains('cycl') || type.contains('bike')) {
      return Icons.directions_bike_rounded;
    }
    if (type.contains('swim')) return Icons.pool_rounded;
    if (type.contains('yoga')) return Icons.self_improvement_rounded;
    if (type.contains('strength') || type.contains('hiit')) {
      return Icons.fitness_center_rounded;
    }
    return Icons.sports_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon(), color: colors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.workoutType,
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
                        Text(
                          '$dateLabel · ${workout.timeLabel}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (workout.distanceKm != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '· ${workout.distanceKm!.toStringAsFixed(2)} km',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    workout.durationLabel,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      height: 1.2,
                    ),
                  ),
                  if (workout.calories != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${workout.calories!.round()} kcal',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevicesView extends StatelessWidget {
  final List<DeviceConnectionSummary> devices;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final VoidCallback onConnect;
  final ValueChanged<DeviceConnectionSummary> onDisconnect;

  const _DevicesView({
    required this.devices,
    required this.isLoading,
    required this.onRefresh,
    required this.onConnect,
    required this.onDisconnect,
  });

  IconData _icon(DevicePlatform p) {
    switch (p) {
      case DevicePlatform.appleHealth:
        return Icons.favorite_border_rounded;
      case DevicePlatform.googleHealthConnect:
        return Icons.favorite_rounded;
      case DevicePlatform.fitbit:
        return Icons.directions_walk_rounded;
      case DevicePlatform.garmin:
        return Icons.watch_outlined;
      case DevicePlatform.other:
        return Icons.devices_other_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return RefreshIndicator(
      onRefresh: onRefresh,
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
                    isLoading
                        ? 'Loading…'
                        : '${devices.where((DeviceConnectionSummary d) => d.isConnected).length} connected',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: onConnect,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'Connect',
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
          if (isLoading)
            const SliverToBoxAdapter(child: _ListViewSkeleton())
          else if (devices.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyBlock(
                icon: Icons.watch_outlined,
                title: 'No devices connected',
                message:
                    'Connect Apple Health, Google Health Connect, Fitbit, or Garmin to import your data.',
              ),
            )
          else
            SliverList.separated(
              itemCount: devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final DeviceConnectionSummary device = devices[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _DeviceTile(
                    device: device,
                    icon: _icon(device.platform),
                    onDisconnect: device.isConnected
                        ? () => onDisconnect(device)
                        : null,
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final DeviceConnectionSummary device;
  final IconData icon;
  final VoidCallback? onDisconnect;

  const _DeviceTile({
    required this.device,
    required this.icon,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final bool connected = device.isConnected;
    final Color statusColor = connected
        ? const Color(0xFF4F7F5B)
        : colors.textMuted;
    final Color statusBg = connected
        ? const Color(0xFFDFF3E3)
        : colors.surfaceSoft;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.platform.label,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          connected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onDisconnect != null)
              TextButton(
                onPressed: onDisconnect,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: colors.textMuted,
                ),
                child: Text(
                  'Disconnect',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
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

class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      isLoading: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonBox(width: 40, height: 40, borderRadius: 12),
                      SizedBox(width: 12),
                      Expanded(
                        child: SkeletonBox(height: 14, borderRadius: 6),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  SkeletonBox(height: 24, borderRadius: 8),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonBox(width: 40, height: 40, borderRadius: 12),
                      SizedBox(width: 12),
                      Expanded(
                        child: SkeletonBox(height: 14, borderRadius: 6),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  SkeletonBox(height: 32, borderRadius: 8),
                ],
              ),
            ),
          ],
        ),
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
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: const [
                    SkeletonBox(width: 40, height: 40, borderRadius: 12),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(height: 14, borderRadius: 6),
                          SizedBox(height: 6),
                          SkeletonBox(width: 120, height: 11, borderRadius: 6),
                        ],
                      ),
                    ),
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