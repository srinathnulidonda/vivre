// lib/app/profile/widgets/profile_sheets.dart
import 'package:flutter/material.dart';

import '../../../themes/color-palette.dart';

Future<String?> showNameSheet(
  BuildContext context, {
  required String initial,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NameSheet(initial: initial),
    );

Future<String?> showTimezoneSheet(
  BuildContext context, {
  required String initial,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimezoneSheet(initial: initial),
    );

class _NameSheet extends StatefulWidget {
  final String initial;

  const _NameSheet({required this.initial});

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _controller.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final double inset = MediaQuery.viewInsetsOf(context).bottom;
    final String value = _controller.text.trim();
    final bool canSave = value.length >= 1 && value != widget.initial;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
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
                  'Your name',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'How should we greet you?',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    fontSize: 16,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    hintStyle: TextStyle(
                      color: colors.textMuted,
                      fontSize: 16,
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
                  onSubmitted: (String raw) {
                    final String trimmed = raw.trim();
                    if (trimmed.isEmpty) return;
                    Navigator.of(context).pop(trimmed);
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canSave
                        ? () => Navigator.of(context).pop(value)
                        : null,
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
                    child: const Text(
                      'Save',
                      style: TextStyle(
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

class _TimezoneSheet extends StatefulWidget {
  final String initial;

  const _TimezoneSheet({required this.initial});

  @override
  State<_TimezoneSheet> createState() => _TimezoneSheetState();
}

class _TimezoneSheetState extends State<_TimezoneSheet> {
  late String _selected;

  static const List<({String id, String label})> _zones = [
    (id: 'UTC', label: 'UTC (Coordinated Universal Time)'),
    (id: 'America/Los_Angeles', label: 'Pacific — Los Angeles'),
    (id: 'America/Denver', label: 'Mountain — Denver'),
    (id: 'America/Chicago', label: 'Central — Chicago'),
    (id: 'America/New_York', label: 'Eastern — New York'),
    (id: 'America/Sao_Paulo', label: 'São Paulo'),
    (id: 'Europe/London', label: 'London'),
    (id: 'Europe/Paris', label: 'Paris · Berlin · Madrid'),
    (id: 'Europe/Istanbul', label: 'Istanbul · Moscow'),
    (id: 'Africa/Cairo', label: 'Cairo · Johannesburg'),
    (id: 'Asia/Dubai', label: 'Dubai'),
    (id: 'Asia/Karachi', label: 'Karachi · Islamabad'),
    (id: 'Asia/Kolkata', label: 'India — Mumbai · Delhi'),
    (id: 'Asia/Bangkok', label: 'Bangkok · Jakarta'),
    (id: 'Asia/Singapore', label: 'Singapore · Kuala Lumpur'),
    (id: 'Asia/Shanghai', label: 'Shanghai · Beijing'),
    (id: 'Asia/Tokyo', label: 'Tokyo · Seoul'),
    (id: 'Australia/Sydney', label: 'Sydney · Melbourne'),
    (id: 'Pacific/Auckland', label: 'Auckland'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    final bool known =
        _zones.any((({String id, String label}) z) => z.id == _selected);
    if (!known) _selected = 'UTC';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Timezone',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used for daily reviews, digests, and reminders.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _zones.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (BuildContext context, int index) {
                  final ({String id, String label}) zone = _zones[index];
                  final bool selected = zone.id == _selected;
                  return Material(
                    color: selected ? colors.primarySoft : colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _selected = zone.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? colors.primary
                                : colors.border,
                            width: selected ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                zone.label,
                                style: TextStyle(
                                  color: selected
                                      ? colors.primary
                                      : colors.textPrimary,
                                  fontSize: 14.5,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: colors.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected == widget.initial
                      ? null
                      : () => Navigator.of(context).pop(_selected),
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
                  child: const Text(
                    'Save timezone',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}