// lib/app/health/widgets/health_sheets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api/api_exception.dart';
import '../../../api/health/health_api.dart';
import '../../../themes/color-palette.dart';
import '../../../widgets/feedback.dart';

Future<DailyMetricsSummary?> showDailyMetricsSheet(
  BuildContext context, {
  DailyMetricsSummary? existing,
}) =>
    showModalBottomSheet<DailyMetricsSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DailyMetricsSheet(existing: existing),
    );

Future<SleepSummary?> showSleepSheet(
  BuildContext context, {
  SleepSummary? existing,
}) =>
    showModalBottomSheet<SleepSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SleepSheet(existing: existing),
    );

Future<WorkoutSummary?> showWorkoutSheet(BuildContext context) =>
    showModalBottomSheet<WorkoutSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _WorkoutSheet(),
    );

Future<DevicePlatform?> showDevicePicker(BuildContext context) =>
    showModalBottomSheet<DevicePlatform>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DevicePickerSheet(),
    );

class _DailyMetricsSheet extends StatefulWidget {
  final DailyMetricsSummary? existing;

  const _DailyMetricsSheet({this.existing});

  @override
  State<_DailyMetricsSheet> createState() => _DailyMetricsSheetState();
}

class _DailyMetricsSheetState extends State<_DailyMetricsSheet> {
  final HealthApi _api = HealthApi();
  late final TextEditingController _steps;
  late final TextEditingController _distance;
  late final TextEditingController _calories;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final DailyMetricsSummary? existing = widget.existing;
    _steps = TextEditingController(
      text: existing == null ? '' : existing.steps.toString(),
    );
    _distance = TextEditingController(
      text: existing == null
          ? ''
          : existing.distanceKm.toStringAsFixed(2),
    );
    _calories = TextEditingController(
      text: existing == null
          ? ''
          : existing.activeCalories.round().toString(),
    );
    _steps.addListener(_refresh);
    _distance.addListener(_refresh);
    _calories.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _steps.dispose();
    _distance.dispose();
    _calories.dispose();
    super.dispose();
  }

  bool get _isValid {
    final int? steps = int.tryParse(_steps.text.trim());
    final double? km = double.tryParse(_distance.text.trim());
    final double? kcal = double.tryParse(_calories.text.trim());
    return steps != null && steps >= 0 &&
        km != null && km >= 0 &&
        kcal != null && kcal >= 0;
  }

  Future<void> _submit() async {
    if (!_isValid || _isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final DailyMetricsSummary metric = await _api.upsertDailyMetrics(
        metricDate: DateTime.now(),
        steps: int.parse(_steps.text.trim()),
        distanceMeters: double.parse(_distance.text.trim()) * 1000,
        activeCalories: double.parse(_calories.text.trim()),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(metric);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Could not save today\u2019s metrics.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: _SheetShell(
        title: widget.existing == null
            ? 'Log today\u2019s metrics'
            : 'Update metrics',
        subtitle: 'Steps · distance · active calories',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NumericField(
              controller: _steps,
              label: 'Steps',
              suffix: 'steps',
              icon: Icons.directions_walk_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _NumericField(
              controller: _distance,
              label: 'Distance',
              suffix: 'km',
              icon: Icons.route_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            _NumericField(
              controller: _calories,
              label: 'Active calories',
              suffix: 'kcal',
              icon: Icons.local_fire_department_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            _PrimaryButton(
              label: widget.existing == null ? 'Save metrics' : 'Update',
              isLoading: _isSubmitting,
              onPressed: _isValid ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepSheet extends StatefulWidget {
  final SleepSummary? existing;

  const _SleepSheet({this.existing});

  @override
  State<_SleepSheet> createState() => _SleepSheetState();
}

class _SleepSheetState extends State<_SleepSheet> {
  final HealthApi _api = HealthApi();
  late TimeOfDay _bedtime;
  late TimeOfDay _waketime;
  String? _quality;
  bool _isSubmitting = false;

  static const List<({String id, String label})> _qualities = [
    (id: 'poor', label: 'Poor'),
    (id: 'fair', label: 'Fair'),
    (id: 'good', label: 'Good'),
    (id: 'excellent', label: 'Excellent'),
  ];

  @override
  void initState() {
    super.initState();
    final SleepSummary? existing = widget.existing;
    if (existing != null) {
      final DateTime bedLocal = existing.startAt.toLocal();
      final DateTime wakeLocal = existing.endAt.toLocal();
      _bedtime = TimeOfDay(hour: bedLocal.hour, minute: bedLocal.minute);
      _waketime = TimeOfDay(hour: wakeLocal.hour, minute: wakeLocal.minute);
      _quality = existing.quality;
    } else {
      _bedtime = const TimeOfDay(hour: 23, minute: 0);
      _waketime = const TimeOfDay(hour: 7, minute: 0);
    }
  }

  int _durationMinutes() {
    final int bed = _bedtime.hour * 60 + _bedtime.minute;
    final int wake = _waketime.hour * 60 + _waketime.minute;
    return wake > bed ? wake - bed : (24 * 60 - bed) + wake;
  }

  Future<void> _pick({required bool bedtime}) async {
    final TimeOfDay initial = bedtime ? _bedtime : _waketime;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      if (bedtime) {
        _bedtime = picked;
      } else {
        _waketime = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final DateTime now = DateTime.now();
    final DateTime sleepDate = DateTime(now.year, now.month, now.day);
    final DateTime startAt = DateTime(
      sleepDate.year,
      sleepDate.month,
      sleepDate.day,
      _bedtime.hour,
      _bedtime.minute,
    );
    final int duration = _durationMinutes();
    final DateTime endAt = startAt.add(Duration(minutes: duration));

    try {
      final SleepSummary record = await _api.upsertSleepRecord(
        sleepDate: sleepDate,
        startAt: startAt,
        endAt: endAt,
        durationMinutes: duration,
        quality: _quality,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(record);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Could not save your sleep.');
    }
  }

  String _label(TimeOfDay t) {
    final String hour = t.hour.toString().padLeft(2, '0');
    final String minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get _durationLabel {
    final int minutes = _durationMinutes();
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    if (rest == 0) return '${hours}h';
    return '${hours}h ${rest}m';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final double inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: _SheetShell(
        title: widget.existing == null ? 'Log sleep' : 'Update sleep',
        subtitle: 'Bedtime · wake time · quality',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Bedtime',
                    value: _label(_bedtime),
                    icon: Icons.bedtime_outlined,
                    onTap: () => _pick(bedtime: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimeField(
                    label: 'Wake',
                    value: _label(_waketime),
                    icon: Icons.wb_sunny_outlined,
                    onTap: () => _pick(bedtime: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.nightlight_round,
                    color: colors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _durationLabel,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'total sleep',
                    style: TextStyle(
                      color: colors.primary.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'QUALITY',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(_qualities.length, (int i) {
                final ({String id, String label}) q = _qualities[i];
                final bool available = i == _qualities.length - 1;
                final bool selected = _quality == q.id;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == _qualities.length - 1 ? 0 : 6,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        if (!available) return;
                        setState(() => _quality = selected ? null : q.id);
                        HapticFeedback.selectionClick();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primarySoft
                              : colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? colors.primary
                                : colors.border,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          q.label,
                          style: TextStyle(
                            color: selected
                                ? colors.primary
                                : colors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            _PrimaryButton(
              label: widget.existing == null ? 'Save sleep' : 'Update',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutSheet extends StatefulWidget {
  const _WorkoutSheet();

  @override
  State<_WorkoutSheet> createState() => _WorkoutSheetState();
}

class _WorkoutSheetState extends State<_WorkoutSheet> {
  final HealthApi _api = HealthApi();
  final TextEditingController _type = TextEditingController();
  final TextEditingController _duration = TextEditingController();
  final TextEditingController _calories = TextEditingController();
  final TextEditingController _distance = TextEditingController();

  TimeOfDay _startTime = TimeOfDay.now();
  bool _isSubmitting = false;

  static const List<String> _suggestions = [
    'Run',
    'Walk',
    'Cycle',
    'Swim',
    'Yoga',
    'Strength',
    'HIIT',
    'Pilates',
    'Rowing',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _type.addListener(_refresh);
    _duration.addListener(_refresh);
    _calories.addListener(_refresh);
    _distance.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _type.dispose();
    _duration.dispose();
    _calories.dispose();
    _distance.dispose();
    super.dispose();
  }

  bool get _isValid {
    final int? duration = int.tryParse(_duration.text.trim());
    return _type.text.trim().isNotEmpty &&
        duration != null &&
        duration > 0;
  }

  Future<void> _pickStart() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked == null) return;
    setState(() => _startTime = picked);
  }

  Future<void> _submit() async {
    if (!_isValid || _isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final DateTime now = DateTime.now();
    final DateTime startAt = DateTime(
      now.year,
      now.month,
      now.day,
      _startTime.hour,
      _startTime.minute,
    );
    final int duration = int.parse(_duration.text.trim());
    final double? kcal = double.tryParse(_calories.text.trim());
    final double? km = double.tryParse(_distance.text.trim());

    try {
      final WorkoutSummary workout = await _api.createWorkout(
        workoutType: _type.text.trim(),
        startAt: startAt,
        endAt: startAt.add(Duration(minutes: duration)),
        durationMinutes: duration,
        calories: kcal,
        distanceMeters: km == null ? null : km * 1000,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(workout);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Could not save this workout.');
    }
  }

  String _timeLabel(TimeOfDay t) {
    final String h = t.hour.toString().padLeft(2, '0');
    final String m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final double inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: _SheetShell(
        title: 'Log workout',
        subtitle: 'What did you do today?',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NumericField(
              controller: _type,
              label: 'Workout',
              suffix: '',
              icon: Icons.fitness_center_outlined,
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (BuildContext context, int index) {
                  final String s = _suggestions[index];
                  final bool selected = _type.text.trim() == s;
                  return GestureDetector(
                    onTap: () {
                      _type.text = s;
                      _type.selection = TextSelection.collapsed(
                        offset: s.length,
                      );
                      HapticFeedback.selectionClick();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primary
                            : colors.surface,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: selected ? colors.primary : colors.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : colors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Started at',
                    value: _timeLabel(_startTime),
                    icon: Icons.schedule_rounded,
                    onTap: _pickStart,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumericField(
                    controller: _duration,
                    label: 'Duration',
                    suffix: 'min',
                    icon: Icons.timer_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NumericField(
                    controller: _calories,
                    label: 'Calories',
                    suffix: 'kcal',
                    icon: Icons.local_fire_department_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumericField(
                    controller: _distance,
                    label: 'Distance',
                    suffix: 'km',
                    icon: Icons.route_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _PrimaryButton(
              label: 'Log workout',
              isLoading: _isSubmitting,
              onPressed: _isValid ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicePickerSheet extends StatelessWidget {
  const _DevicePickerSheet();

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
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
                'Connect a device',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a platform to sync your health data.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              for (final DevicePlatform platform in DevicePlatform.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _DeviceOption(
                    platform: platform,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop(platform);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceOption extends StatelessWidget {
  final DevicePlatform platform;
  final VoidCallback onTap;

  const _DeviceOption({required this.platform, required this.onTap});

  IconData _icon() {
    switch (platform) {
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
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon(), color: colors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  platform.label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SheetShell({
    required this.title,
    required this.subtitle,
    required this.child,
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
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
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

class _NumericField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final IconData icon;
  final TextInputType keyboardType;

  const _NumericField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.icon,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 15,
        color: colors.textPrimary,
        height: 1.3,
      ),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 15),
        prefixIcon: Icon(icon, size: 18, color: colors.textMuted),
        suffixText: suffix.isEmpty ? null : suffix,
        suffixStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: colors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _TimeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

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
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: colors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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