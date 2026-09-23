// lib/onboarding/page-1.dart
import 'package:flutter/material.dart';

import 'shared.dart';

class OnboardingPage1 extends StatelessWidget {
  final double scale;
  final PageController controller;
  final int index;

  const OnboardingPage1({
    super.key,
    required this.scale,
    required this.controller,
    required this.index,
  });

  static const double _quoteImageLeftFactor = 0.42;
  static const double _quoteImageTopFactor = 0.07;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Column(
      children: [
        SizedBox(height: 6 * scale),
        Semantics(
          header: true,
          child: Text(
            'A more intentional you',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24 * scale,
              fontWeight: FontWeight.w600,
              color: kDarkNavy,
              letterSpacing: -0.2,
            ),
          ),
        ),
        SizedBox(height: 8 * scale),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            'Organize your knowledge, work, life,\n'
            'health and everything in between.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5 * scale,
              color: kBodyGray,
              height: 1.35,
            ),
          ),
        ),
        SizedBox(height: 14 * scale),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _FeatureBadge(
                    icon: Icons.menu_book_outlined,
                    label: 'Knowledge',
                    bgColor: const Color(0xFFDCEAFB),
                    iconColor: const Color(0xFF1B3A6B),
                    scale: scale,
                  ),
                  _FeatureBadge(
                    icon: Icons.work_outline,
                    label: 'Work',
                    bgColor: const Color(0xFFFBE7D2),
                    iconColor: const Color(0xFF8A5A24),
                    scale: scale,
                  ),
                  _FeatureBadge(
                    icon: Icons.eco_outlined,
                    label: 'Life',
                    bgColor: const Color(0xFFDFF3E3),
                    iconColor: const Color(0xFF2F6B3F),
                    scale: scale,
                  ),
                  _FeatureBadge(
                    icon: Icons.favorite_border,
                    label: 'Health',
                    bgColor: const Color(0xFFFBDEE1),
                    iconColor: const Color(0xFFC23B4A),
                    scale: scale,
                  ),
                ],
              ),
              SizedBox(height: 10 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FeatureBadge(
                    icon: Icons.calendar_today_outlined,
                    label: 'Time',
                    bgColor: const Color(0xFFE6E1F9),
                    iconColor: const Color(0xFF4B3F91),
                    scale: scale,
                  ),
                  SizedBox(width: 26 * scale),
                  _FeatureBadge(
                    icon: Icons.bar_chart_rounded,
                    label: 'Reviews',
                    bgColor: const Color(0xFFFBF0C8),
                    iconColor: const Color(0xFF8A6D1E),
                    scale: scale,
                  ),
                  SizedBox(width: 26 * scale),
                  _FeatureBadge(
                    icon: Icons.auto_awesome_outlined,
                    label: 'AI',
                    bgColor: const Color(0xFFDCEAFB),
                    iconColor: const Color(0xFF1B3A6B),
                    scale: scale,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16 * scale),
        Expanded(
          child: OnboardingParallax(
            controller: controller,
            index: index,
            child: Stack(
              fit: StackFit.expand,
              children: [
                OnboardingBackground(
                  assetName: 'bg-screen-1.webp',
                  topFadeHeight: 88 * scale,
                ),
                Positioned(
                  left: size.width * _quoteImageLeftFactor,
                  top: size.height * _quoteImageTopFactor,
                  child: Image.asset(
                    '$kAssetPath/text-screen-1.webp',
                    height: 76 * scale,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
                Positioned(
                  right: 20 * scale,
                  bottom: 150 * scale,
                  child: SizedBox(
                    width: 150,
                    child: Text(
                      '"A more intentional life\nis a happier life."',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
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

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final double scale;

  const _FeatureBadge({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final double size = 50 * scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16 * scale),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 25 * scale),
        ),
        SizedBox(height: 7 * scale),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5 * scale,
            color: kDarkNavy,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}