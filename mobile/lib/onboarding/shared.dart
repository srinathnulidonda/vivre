// lib/onboarding/shared.dart
import 'package:flutter/material.dart';

import '../splash/vivre_splash.dart' show vivreLogoHeroTag;
import '../themes/app-colors.dart';

export '../themes/app-colors.dart'
    show kAccentBlue, kBodyGray, kDarkNavy, kPageBg;

const String kAssetPath = 'assets/onboarding';

Widget _onboardingImageFallback(BuildContext context, Object error,
    StackTrace? stackTrace) {
  return Container(
    color: kPageBg,
    alignment: Alignment.center,
    child: Icon(
      Icons.image_not_supported_outlined,
      color: kBodyGray.withValues(alpha: 0.5),
      size: 28,
    ),
  );
}

class OnboardingBackground extends StatelessWidget {
  final String assetName;
  final double topFadeHeight;
  final double scrimStart;

  const OnboardingBackground({
    super.key,
    required this.assetName,
    required this.topFadeHeight,
    this.scrimStart = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: kPageBg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            '$kAssetPath/$assetName',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            excludeFromSemantics: true,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: _onboardingImageFallback,
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    kAccentBlue.withValues(alpha: 0.16),
                    kAccentBlue.withValues(alpha: 0.04),
                    Colors.transparent,
                    kDarkNavy.withValues(alpha: 0.10),
                  ],
                  stops: const [0.0, 0.22, 0.42, 0.65, 1.0],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.30),
                  ],
                  stops: [scrimStart, 1.0],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              height: topFadeHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kPageBg,
                    kPageBg.withValues(alpha: 0.7),
                    kPageBg.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingParallax extends StatelessWidget {
  final PageController controller;
  final int index;
  final Widget child;

  const OnboardingParallax({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
  });

  double _currentPage() {
    if (!controller.hasClients) return index.toDouble();
    try {
      return controller.page ?? controller.initialPage.toDouble();
    } catch (_) {
      return controller.initialPage.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, cachedChild) {
            final double absDelta =
                (_currentPage() - index).clamp(-1.0, 1.0).abs();
            final double scaleValue = 1.05 + (absDelta * 0.03);
            return Transform.scale(scale: scaleValue, child: cachedChild);
          },
          child: child,
        ),
      ),
    );
  }
}

class OnboardingSkipButton extends StatelessWidget {
  final VoidCallback onTap;
  const OnboardingSkipButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8, top: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: kBodyGray.withValues(alpha: 0.1),
            highlightColor: kBodyGray.withValues(alpha: 0.05),
            child: Semantics(
              button: true,
              label: 'Skip onboarding',
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 15,
                    color: kBodyGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingLogo extends StatelessWidget {
  final double height;
  const OnboardingLogo({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: vivreLogoHeroTag,
      child: Image.asset(
        '$kAssetPath/logo.webp',
        height: height,
        fit: BoxFit.contain,
        semanticLabel: 'Vivre',
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.eco_rounded,
          size: height * 0.9,
          color: kAccentBlue,
        ),
      ),
    );
  }
}

class OnboardingPageIndicator extends StatelessWidget {
  final PageController controller;
  final int count;
  final ValueChanged<int> onDotTap;

  const OnboardingPageIndicator({
    super.key,
    required this.controller,
    required this.count,
    required this.onDotTap,
  });

  double _currentPage() {
    if (!controller.hasClients) return 0;
    try {
      return controller.page ?? controller.initialPage.toDouble();
    } catch (_) {
      return controller.initialPage.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final double page = _currentPage();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (i) {
            final double distance = (page - i).abs();
            final double t = (1.0 - distance).clamp(0.0, 1.0);
            final double curvedT = Curves.easeInOutCubic.transform(t);

            final double width = 6.0 + (14.0 * curvedT);
            final Color color = Color.lerp(
              Colors.white.withValues(alpha: 0.55),
              kAccentBlue,
              curvedT,
            )!;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onDotTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOutCubic,
                  width: width,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: curvedT > 0.5
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 2,
                            ),
                          ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class OnboardingPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubicEmphasized,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  label,
                  key: ValueKey(label),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingSignInRow extends StatelessWidget {
  final VoidCallback onSignIn;

  const OnboardingSignInRow({super.key, required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?  ',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
        ),
        GestureDetector(
          onTap: onSignIn,
          child: const Text(
            'Sign In',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}