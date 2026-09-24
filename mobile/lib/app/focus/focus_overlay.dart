// lib/app/focus/focus_overlay.dart
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/work/focus_session_service.dart';
import '../../themes/color-palette.dart';

class ModalDetectorObserver extends NavigatorObserver {
  final ValueNotifier<bool> isModalOpen = ValueNotifier<bool>(false);
  int _depth = 0;

  void _increment() {
    _depth++;
    if (!isModalOpen.value) isModalOpen.value = true;
  }

  void _decrement() {
    if (_depth == 0) return;
    _depth--;
    if (_depth == 0) isModalOpen.value = false;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _increment();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _decrement();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _decrement();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final bool wasModal = oldRoute is PopupRoute;
    final bool isModal = newRoute is PopupRoute;
    if (isModal && !wasModal) {
      _increment();
    } else if (!isModal && wasModal) {
      _decrement();
    }
  }
}

class FocusOverlay extends StatelessWidget {
  final Widget child;
  final ModalDetectorObserver observer;

  const FocusOverlay({
    super.key,
    required this.child,
    required this.observer,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 116,
          child: ValueListenableBuilder<bool>(
            valueListenable: observer.isModalOpen,
            builder: (BuildContext context, bool modalOpen, _) {
              if (modalOpen) return const SizedBox.shrink();
              return const FocusPill();
            },
          ),
        ),
      ],
    );
  }
}

class FocusPill extends StatelessWidget {
  const FocusPill({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActiveFocusSession?>(
      valueListenable: FocusSessionService.instance.active,
      builder: (BuildContext context, ActiveFocusSession? session, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> anim) {
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            );
          },
          child: session == null
              ? const SizedBox.shrink(key: ValueKey<String>('focus-empty'))
              : _FocusPillBody(
                  key: ValueKey<String>(session.id),
                  session: session,
                ),
        );
      },
    );
  }
}

class _FocusPillBody extends StatelessWidget {
  final ActiveFocusSession session;

  const _FocusPillBody({super.key, required this.session});

  static String _format(Duration d) {
    final int hours = d.inHours;
    final String minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  static String _human(Duration d) {
    if (d.inHours >= 1) {
      final int hours = d.inHours;
      final int minutes = d.inMinutes % 60;
      return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
    }
    if (d.inMinutes >= 1) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) =>
          Opacity(opacity: t, child: child),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openDetails(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF16233D),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const _PulsingDot(),
                const SizedBox(width: 12),
                ValueListenableBuilder<Duration>(
                  valueListenable: FocusSessionService.instance.elapsed,
                  builder: (BuildContext context, Duration elapsed, _) {
                    return Text(
                      _format(elapsed),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    session.primaryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
                Material(
                  color: Colors.white.withValues(alpha: 0.10),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => _stopAndNotify(context),
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.stop_rounded,
                        color: Colors.white,
                        size: 18,
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

  void _openDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FocusDetailsSheet(session: session),
    );
  }

  Future<void> _stopAndNotify(BuildContext context) async {
    HapticFeedback.selectionClick();
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    final Duration? duration = await FocusSessionService.instance.stop();
    if (duration == null) return;
    HapticFeedback.mediumImpact();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Focus session ended · ${_human(duration)}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E)
                    .withValues(alpha: 0.35 + 0.35 * _c.value),
                blurRadius: 6 + 4 * _c.value,
                spreadRadius: 1 + _c.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FocusDetailsSheet extends StatelessWidget {
  final ActiveFocusSession session;

  const _FocusDetailsSheet({required this.session});

  static String _formatLong(Duration d) {
    final int hours = d.inHours;
    final String minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }

  static String _human(Duration d) {
    if (d.inHours >= 1) {
      final int hours = d.inHours;
      final int minutes = d.inMinutes % 60;
      return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
    }
    if (d.inMinutes >= 1) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final String subtitle = session.subtitle;

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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6E1F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFF4B3F91),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Focus session',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Center(
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: FocusSessionService.instance.elapsed,
                    builder: (BuildContext context, Duration elapsed, _) {
                      return Text(
                        _formatLong(elapsed),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.2,
                          height: 1.05,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ScaffoldMessengerState? messenger =
                        ScaffoldMessenger.maybeOf(context);
                    final NavigatorState navigator = Navigator.of(context);
                    HapticFeedback.selectionClick();
                    final Duration? duration =
                        await FocusSessionService.instance.stop();
                    if (!context.mounted) return;
                    HapticFeedback.mediumImpact();
                    navigator.pop();
                    if (duration == null) return;
                    messenger
                      ?..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            'Focus session ended · ${_human(duration)}',
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                  },
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  label: const Text(
                    'End session',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD64545),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
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