// lib/app/layout/bottomnav.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../themes/app-colors.dart';

enum AppTab { home, notes, work, personal }

const double _kBarHeight = 64;
const double _kButtonSize = 56;
const double _kButtonOverhang = 16;
const double _kNotchGap = 6;
const double _kNotchRadius = _kButtonSize / 2 + _kNotchGap;
const double _kNotchCenterY = _kButtonSize / 2 - _kButtonOverhang;
const double _kNotchFillet = 10;
const double _kCenterGap = _kNotchRadius * 2 + 8;
const double _kSideMargin = 16;
const double _kMaxBarWidth = 440;
const double _kShadowBlurSigma = 12;

const Color _kInactiveColor = Color(0xFF5F6368);
const Color _kBarShadowColor = Color(0x1F000000);

class BottomNavBar extends StatelessWidget {
  final AppTab currentTab;
  final ValueChanged<AppTab> onTabSelected;
  final VoidCallback? onAddTap;

  const BottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    this.onAddTap,
  });

  Widget _item({
    required AppTab tab,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    return Expanded(
      child: _NavItem(
        icon: icon,
        selectedIcon: selectedIcon,
        label: label,
        selected: currentTab == tab,
        onTap: () => onTabSelected(tab),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double bottomMargin = math.max(bottomInset + 12, 20);

    return Padding(
      padding: EdgeInsets.fromLTRB(_kSideMargin, 0, _kSideMargin, bottomMargin),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxBarWidth),
          child: SizedBox(
            height: _kBarHeight + _kButtonOverhang,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _kBarHeight,
                  child: CustomPaint(
                    painter: _NotchedBarPainter(
                      color: kNavBarBg,
                      shadowColor: _kBarShadowColor,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _kBarHeight,
                  child: Material(
                    type: MaterialType.transparency,
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _item(
                              tab: AppTab.home,
                              icon: Icons.home_outlined,
                              selectedIcon: Icons.home_rounded,
                              label: 'Home',
                            ),
                            _item(
                              tab: AppTab.notes,
                              icon: Icons.description_outlined,
                              selectedIcon: Icons.description_rounded,
                              label: 'Notes',
                            ),
                            const SizedBox(width: _kCenterGap),
                            _item(
                              tab: AppTab.work,
                              icon: Icons.work_outline_rounded,
                              selectedIcon: Icons.work_rounded,
                              label: 'Work',
                            ),
                            _item(
                              tab: AppTab.personal,
                              icon: Icons.person_outline_rounded,
                              selectedIcon: Icons.person_rounded,
                              label: 'Personal',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    heightFactor: 1,
                    child: _CenterAddButton(onTap: onAddTap),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? kAccentBlue : _kInactiveColor;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 24),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

class _CenterAddButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _CenterAddButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add new',
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kAccentBlue.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: kAccentBlue,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: const SizedBox(
              width: _kButtonSize,
              height: _kButtonSize,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotchedBarPainter extends CustomPainter {
  final Color color;
  final Color shadowColor;

  const _NotchedBarPainter({required this.color, required this.shadowColor});

  Path _buildPath(Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = h / 2;
    final double cx = w / 2;

    const double nr = _kNotchRadius;
    const double cy = _kNotchCenterY;
    const double f = _kNotchFillet;

    const double dy = f - cy;
    final double xf = math.sqrt((nr + f) * (nr + f) - dy * dy);
    final double a = math.atan2(dy, xf);

    return Path()
      ..moveTo(r, 0)
      ..lineTo(cx - xf, 0)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx - xf, f), radius: f),
        -math.pi / 2,
        math.pi / 2 - a,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: nr),
        math.pi - a,
        2 * a - math.pi,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: Offset(cx + xf, f), radius: f),
        math.pi + a,
        math.pi / 2 - a,
        false,
      )
      ..lineTo(w - r, 0)
      ..arcTo(Rect.fromLTWH(w - h, 0, h, h), -math.pi / 2, math.pi, false)
      ..lineTo(r, h)
      ..arcTo(Rect.fromLTWH(0, 0, h, h), math.pi / 2, math.pi, false)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _buildPath(size);

    canvas.drawPath(
      path.shift(const Offset(0, 8)),
      Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _kShadowBlurSigma),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_NotchedBarPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shadowColor != shadowColor;
}