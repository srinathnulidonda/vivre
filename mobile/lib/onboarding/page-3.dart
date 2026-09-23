// lib/onboarding/page-3.dart
import 'package:flutter/material.dart';

import 'shared.dart';

class OnboardingPage3 extends StatelessWidget {
  final double scale;
  final PageController controller;
  final int index;

  const OnboardingPage3({
    super.key,
    required this.scale,
    required this.controller,
    required this.index,
  });

  static const double _textImageLeftFactor = 0.66;
  static const double _textImageTopFactor = 0.17;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Column(
      children: [
        SizedBox(height: 6 * scale),
        Semantics(
          header: true,
          child: Text(
            'A more intentional life',
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Stay focused, build better habits,\n'
            'track your progress and create a\n'
            'healthier, happier you.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14 * scale, color: kBodyGray, height: 1.35),
          ),
        ),
        SizedBox(height: 14 * scale),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              _FeatureListRow(
                icon: Icons.bolt_rounded,
                title: 'Focus',
                subtitle: 'Do what matters',
                bg: const Color(0xFFDCEAFB),
                fg: const Color(0xFF1B3A6B),
                scale: scale,
              ),
              _FeatureListRow(
                icon: Icons.bar_chart_rounded,
                title: 'Grow',
                subtitle: 'Track real progress',
                bg: const Color(0xFFDFF3E3),
                fg: const Color(0xFF2F6B3F),
                scale: scale,
              ),
              _FeatureListRow(
                icon: Icons.favorite_border,
                title: 'Be Healthier',
                subtitle: 'Mind and body, together',
                bg: const Color(0xFFFBDEE1),
                fg: const Color(0xFFC23B4A),
                scale: scale,
              ),
              _FeatureListRow(
                icon: Icons.auto_awesome_outlined,
                title: 'Live Better',
                subtitle: 'A more intentional you',
                bg: const Color(0xFFE6E1F9),
                fg: const Color(0xFF4B3F91),
                scale: scale,
              ),
            ],
          ),
        ),
        SizedBox(height: 12 * scale),
        Expanded(
          child: OnboardingParallax(
            controller: controller,
            index: index,
            child: Stack(
              fit: StackFit.expand,
              children: [
                OnboardingBackground(
                  assetName: 'bg-screen-3.webp',
                  topFadeHeight: 88 * scale,
                  scrimStart: 0.72,
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.10),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: size.width * _textImageLeftFactor,
                  top: size.height * _textImageTopFactor,
                  child: Image.asset(
                    '$kAssetPath/text-screen-3.webp',
                    height: 70 * scale,
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

class _FeatureListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bg;
  final Color fg;
  final double scale;

  const _FeatureListRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.fg,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final double size = 44 * scale;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5 * scale),
      child: Row(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, color: fg, size: 20 * scale),
          ),
          SizedBox(width: 14 * scale),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.5 * scale,
                  fontWeight: FontWeight.w600,
                  color: kDarkNavy,
                ),
              ),
              SizedBox(height: 2 * scale),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12.5 * scale, color: kBodyGray),
              ),
            ],
          ),
        ],
      ),
    );
  }
}