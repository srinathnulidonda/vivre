// lib/onboarding/flow.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';

import '../app/preferences.dart';
import '../auth/login.dart';
import '../auth/register.dart';
import 'page-1.dart';
import 'page-2.dart';
import 'page-3.dart';
import 'shared.dart';

class _SnappyPageScrollPhysics extends PageScrollPhysics {
  const _SnappyPageScrollPhysics({super.parent});

  @override
  _SnappyPageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnappyPageScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 0.5, stiffness: 220, damping: 22);
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const int _pageCount = 3;

  late final PageController _controller;
  int _currentPage = 0;
  int _lastHapticPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _controller.addListener(_handlePageScroll);
    _preloadImages();
  }

  void _preloadImages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(const AssetImage('$kAssetPath/bg-screen-1.webp'), context);
      precacheImage(const AssetImage('$kAssetPath/bg-screen-2.webp'), context);
      precacheImage(const AssetImage('$kAssetPath/bg-screen-3.webp'), context);
      precacheImage(const AssetImage('$kAssetPath/text-screen-1.webp'), context);
      precacheImage(const AssetImage('$kAssetPath/text-screen-2.webp'), context);
      precacheImage(const AssetImage('$kAssetPath/text-screen-3.webp'), context);
      precacheImage(const AssetImage('$kAssetPath/logo.webp'), context);
      precacheImage(const AssetImage('$kAssetPath/icon-1.webp'), context);
    });
  }

  void _handlePageScroll() {
    if (!_controller.hasClients) return;
    final double? page = _controller.page;
    if (page == null) return;
    final int rounded = page.round().clamp(0, _pageCount - 1);
    if (rounded != _currentPage) {
      setState(() => _currentPage = rounded);
    }
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (_currentPage != _lastHapticPage) {
      HapticFeedback.selectionClick();
      _lastHapticPage = _currentPage;
    }
    return false;
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePageScroll);
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _controller.animateToPage(
      index.clamp(0, _pageCount - 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_currentPage >= _pageCount - 1) {
      _finish();
    } else {
      _goTo(_currentPage + 1);
    }
  }

  void _skip() {
    _finish();
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await AppPreferences.markOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  Future<void> _goToSignIn() async {
    HapticFeedback.selectionClick();
    await AppPreferences.markOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  bool get _isLast => _currentPage == _pageCount - 1;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double scale = (size.height / 844).clamp(0.86, 1.08);
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: PopScope(
        canPop: _currentPage == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _currentPage > 0) {
            _goTo(_currentPage - 1);
          }
        },
        child: Scaffold(
          backgroundColor: kPageBg,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    OnboardingSkipButton(onTap: _skip),
                    OnboardingLogo(height: 54 * scale),
                    SizedBox(height: 2 * scale),
                    Expanded(
                      child: NotificationListener<ScrollEndNotification>(
                        onNotification: _handleScrollEnd,
                        child: PageView(
                          controller: _controller,
                          physics: const _SnappyPageScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                          children: [
                            OnboardingPage1(
                              scale: scale,
                              controller: _controller,
                              index: 0,
                            ),
                            OnboardingPage2(
                              scale: scale,
                              controller: _controller,
                              index: 1,
                            ),
                            OnboardingPage3(
                              scale: scale,
                              controller: _controller,
                              index: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset + 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OnboardingPageIndicator(
                          controller: _controller,
                          count: _pageCount,
                          onDotTap: _goTo,
                        ),
                        const SizedBox(height: 18),
                        OnboardingPrimaryButton(
                          label: _isLast ? 'Get Started' : 'Next',
                          onPressed: _next,
                        ),
                        const SizedBox(height: 14),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          opacity: _isLast ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !_isLast,
                            child: OnboardingSignInRow(onSignIn: _goToSignIn),
                          ),
                        ),
                      ],
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