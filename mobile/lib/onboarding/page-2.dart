// lib/onboarding/page-2.dart
import 'package:flutter/material.dart';

import 'shared.dart';

class OnboardingPage2 extends StatelessWidget {
  final double scale;
  final PageController controller;
  final int index;

  const OnboardingPage2({
    super.key,
    required this.scale,
    required this.controller,
    required this.index,
  });

  static const double _textImageLeftFactor = 0.58;
  static const double _textImageTopFactor = 0.12;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double orbitWidth = (size.width - 100).clamp(190.0, 240.0);
    final double orbitHeight = orbitWidth * 1.0;

    return Column(
      children: [
        SizedBox(height: 4 * scale),
        Semantics(
          header: true,
          child: Text(
            'Bring everything together',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22 * scale,
              fontWeight: FontWeight.w700,
              color: kDarkNavy,
              letterSpacing: -0.2,
            ),
          ),
        ),
        SizedBox(height: 8 * scale),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Text(
            'Your notes, tasks, goals, habits, health,\n'
            'calendar and more — all in one place.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14 * scale, color: kBodyGray, height: 1.35),
          ),
        ),
        SizedBox(height: 6 * scale),
        OnboardingParallax(
          controller: controller,
          index: index,
          child: _OrbitDiagram(width: orbitWidth, height: orbitHeight),
        ),
        SizedBox(height: 2 * scale),
        Expanded(
          child: OnboardingParallax(
            controller: controller,
            index: index,
            child: Stack(
              fit: StackFit.expand,
              children: [
                OnboardingBackground(
                  assetName: 'bg-screen-2.webp',
                  topFadeHeight: 88 * scale,
                ),
                Positioned(
                  left: size.width * _textImageLeftFactor,
                  top: size.height * _textImageTopFactor,
                  child: Image.asset(
                    '$kAssetPath/text-screen-2.webp',
                    height: 72 * scale,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrbitNode {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final double dx;
  final double dy;
  const _OrbitNode(this.icon, this.label, this.bg, this.fg, this.dx, this.dy);
}

const List<_OrbitNode> _orbitNodes = [
  _OrbitNode(Icons.work_outline, 'Tasks', Color(0xFFFBE7D2), Color(0xFF8A5A24), 0.5, 0.06),
  _OrbitNode(Icons.menu_book_outlined, 'Notes', Color(0xFFDCEAFB), Color(0xFF1B3A6B), 0.22, 0.28),
  _OrbitNode(Icons.eco_outlined, 'Goals', Color(0xFFDFF3E3), Color(0xFF2F6B3F), 0.78, 0.28),
  _OrbitNode(Icons.calendar_today_outlined, 'Calendar', Color(0xFFE6E1F9), Color(0xFF4B3F91), 0.16, 0.62),
  _OrbitNode(Icons.favorite_border, 'Health', Color(0xFFFBDEE1), Color(0xFFC23B4A), 0.84, 0.62),
  _OrbitNode(Icons.bar_chart_rounded, 'Habits', Color(0xFFFBF0C8), Color(0xFF8A6D1E), 0.34, 0.90),
  _OrbitNode(Icons.auto_awesome_outlined, 'AI', Color(0xFFDCEAFB), Color(0xFF1B3A6B), 0.66, 0.90),
];

class _OrbitDiagram extends StatelessWidget {
  final double width;
  final double height;
  const _OrbitDiagram({required this.width, required this.height});

  static const double _vMargin = 24;

  @override
  Widget build(BuildContext context) {
    final double innerHeight = height - (_vMargin * 2);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    kAccentBlue.withValues(alpha: 0.14),
                    kAccentBlue.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: kAccentBlue.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                '$kAssetPath/icon-1.webp',
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.auto_awesome_outlined,
                  color: kAccentBlue,
                  size: 20,
                ),
              ),
            ),
          ),
          ..._orbitNodes.map((node) {
            return Positioned(
              left: node.dx * width - 20,
              top: _vMargin + node.dy * innerHeight - 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: node.bg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(node.icon, color: node.fg, size: 18),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    node.label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: kDarkNavy,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}