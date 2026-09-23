// lib/splash/vivre_splash.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../motion/springs.dart';

const String _kSplashAssetPath = 'assets/splash';
const String vivreLogoHeroTag = 'vivre-logo';

const Color _kSplashBg = Color(0xFFF7FAFD);
const Color _kWordColor = Color(0xFF013074);

class VivreSplash extends StatefulWidget {
  final VoidCallback? onFinished;
  final Duration? holdDuration;

  const VivreSplash({
    super.key,
    this.onFinished,
    this.holdDuration = Duration.zero,
  });

  @override
  State<VivreSplash> createState() => _VivreSplashState();
}

class _VivreSplashState extends State<VivreSplash>
    with SingleTickerProviderStateMixin {
  static const Duration _sequence = Duration(milliseconds: 1400);
  static const String _word = 'VIVRE';

  late final AnimationController _c;

  late final Animation<double> _markOpacity;
  late final Animation<double> _markRise;
  late final Animation<double> _markScale;

  late final Animation<double> _haloOpacity;
  late final Animation<double> _haloScale;

  late final Animation<double> _shadowOpacity;
  late final Animation<double> _contactShadowOpacity;

  late final Animation<double> _darkGrow;
  late final Animation<double> _lightGrow;

  late final List<Animation<double>> _letters;
  late final Animation<double> _lockupScale;

  Timer? _holdTimer;
  Timer? _hapticTimer;
  bool _initialized = false;
  bool _finished = false;
  bool _skipped = false;

  TextStyle? _wordStyle;
  double? _wordStyleFontSize;

  Animation<double> _interval(double startMs, double endMs, Curve curve) {
    return CurvedAnimation(
      parent: _c,
      curve: Interval(
        startMs / _sequence.inMilliseconds,
        endMs / _sequence.inMilliseconds,
        curve: curve,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _sequence);

    _markOpacity = Tween<double>(begin: 0.32, end: 1.0)
        .animate(_interval(0, 230, Curves.easeOutCubic));
    _markRise = _interval(0, 410, AppSprings.snap);
    _markScale = Tween<double>(begin: 0.92, end: 1.0)
        .animate(_interval(50, 765, AppSprings.snap));

    _haloOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.9)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 0.35)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 32,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.35, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 44,
      ),
    ]).animate(_interval(0, 890, Curves.linear));

    _haloScale = Tween<double>(begin: 0.68, end: 1.34)
        .animate(_interval(0, 890, AppSprings.settle));

    _shadowOpacity = _interval(90, 635, Curves.easeOutCubic);
    _contactShadowOpacity = _interval(180, 765, Curves.easeOutCubic);

    _darkGrow = _interval(265, 825, AppSprings.snap);
    _lightGrow = _interval(320, 905, AppSprings.snap);

    const double letterStart = 685;
    const double letterStagger = 40;
    const double letterDur = 330;
    _letters = List.generate(_word.length, (i) {
      final double start = letterStart + i * letterStagger;
      return _interval(start, start + letterDur, AppSprings.snap);
    });

    _lockupScale = Tween<double>(begin: 0.994, end: 1.0)
        .animate(_interval(1045, 1400, AppSprings.settle));

    _c.addStatusListener(_handleStatus);
    _c.forward();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finish();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    _precacheAssets();

    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _c.value = 1.0;
        if (_finished) return;
        _finished = true;
        _holdTimer?.cancel();
        _hapticTimer?.cancel();
        widget.onFinished?.call();
      });
      return;
    }

    _hapticTimer = Timer(
      const Duration(milliseconds: 445),
      () {
        if (!_skipped) HapticFeedback.lightImpact();
      },
    );
  }

  void _precacheAssets() {
    const List<String> assets = [
      '$_kSplashAssetPath/icon-shadow.webp',
      '$_kSplashAssetPath/icon-shadow-contact.webp',
      '$_kSplashAssetPath/leaf-dark.webp',
      '$_kSplashAssetPath/leaf-light.webp',
    ];
    for (final String asset in assets) {
      precacheImage(AssetImage(asset), context);
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    final Duration hold =
        _skipped ? const Duration(milliseconds: 80) : (widget.holdDuration ?? Duration.zero);
    if (hold == Duration.zero) {
      widget.onFinished?.call();
    } else {
      _holdTimer = Timer(hold, () => widget.onFinished?.call());
    }
  }

  void _skip() {
    if (_finished || _skipped) return;
    _skipped = true;
    _holdTimer?.cancel();
    _hapticTimer?.cancel();
    HapticFeedback.selectionClick();
    _c.animateTo(
      1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _c.removeStatusListener(_handleStatus);
    _holdTimer?.cancel();
    _hapticTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  TextStyle _resolveWordStyle(double fontSize) {
    if (_wordStyleFontSize == fontSize && _wordStyle != null) {
      return _wordStyle!;
    }
    _wordStyleFontSize = fontSize;
    _wordStyle = GoogleFonts.nunito(
      fontWeight: FontWeight.w900,
      fontSize: fontSize,
      color: _kWordColor,
      height: 1.0,
    ).copyWith(fontFamilyFallback: const ['Inter']);
    return _wordStyle!;
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double markSize = (size.shortestSide * 0.34).clamp(116.0, 172.0);
    final TextStyle wordStyle = _resolveWordStyle(markSize * 0.225);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: _kSplashBg,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _skip,
          child: Stack(
            children: [
              Center(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final double markOpacity = _markOpacity.value;
                      final double markRise = _markRise.value;
                      final double markScale = _markScale.value;
                      final double lockupScale = _lockupScale.value;

                      return Hero(
                        tag: vivreLogoHeroTag,
                        child: Transform.scale(
                          scale: lockupScale,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Opacity(
                                opacity: markOpacity.clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(0, 22 * (1 - markRise)),
                                  child: Transform.scale(
                                    scale: markScale,
                                    child: SizedBox(
                                      width: markSize,
                                      height: markSize,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          _buildHalo(),
                                          _buildShadow(
                                            asset: 'icon-shadow.webp',
                                            opacity: _shadowOpacity.value,
                                            scale: 1.28,
                                          ),
                                          _buildShadow(
                                            asset:
                                                'icon-shadow-contact.webp',
                                            opacity:
                                                _contactShadowOpacity.value,
                                            scale: 1.10,
                                          ),
                                          _buildLeaf(
                                            markSize: markSize,
                                            left: 0.121212,
                                            top: 0.367624,
                                            width: 0.265550,
                                            height: 0.464912,
                                            t: _darkGrow.value,
                                            asset: 'leaf-dark.webp',
                                          ),
                                          _buildLeaf(
                                            markSize: markSize,
                                            left: 0.388357,
                                            top: 0.192982,
                                            width: 0.490431,
                                            height: 0.634769,
                                            t: _lightGrow.value,
                                            asset: 'leaf-light.webp',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: markSize * 0.15),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(_word.length, (i) {
                                  final bool isLast = i == _word.length - 1;
                                  return _AnimatedLetter(
                                    char: _word[i],
                                    t: _letters[i].value,
                                    trailingSpaceWide: markSize * 0.085,
                                    trailingSpaceFinal:
                                        isLast ? 0.0 : markSize * 0.030,
                                    style: wordStyle,
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHalo() {
    return Positioned.fill(
      child: Opacity(
        opacity: _haloOpacity.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: _haloScale.value,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x382C67C5),
                  Color(0x0F2C67C5),
                  Color(0x002C67C5),
                ],
                stops: [0.30, 0.65, 0.95],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShadow({
    required String asset,
    required double opacity,
    required double scale,
  }) {
    return Positioned.fill(
      child: Opacity(
        opacity: (opacity * 0.9).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: Image.asset(
            '$_kSplashAssetPath/$asset',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaf({
    required double markSize,
    required double left,
    required double top,
    required double width,
    required double height,
    required double t,
    required String asset,
  }) {
    return Positioned(
      left: markSize * left,
      top: markSize * top,
      width: markSize * width,
      height: markSize * height,
      child: _FeatheredReveal(
        t: t,
        child: Image.asset(
          '$_kSplashAssetPath/$asset',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _AnimatedLetter extends StatelessWidget {
  final String char;
  final double t;
  final double trailingSpaceWide;
  final double trailingSpaceFinal;
  final TextStyle style;

  const _AnimatedLetter({
    required this.char,
    required this.t,
    required this.trailingSpaceWide,
    required this.trailingSpaceFinal,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final double tt = t.clamp(0.0, 1.0);
    final double pad = trailingSpaceWide +
        (trailingSpaceFinal - trailingSpaceWide) *
            Curves.easeOutCubic.transform(tt);

    return Opacity(
      opacity: tt,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - tt)),
        child: Transform.scale(
          scale: 0.94 + 0.06 * tt,
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(right: pad.clamp(0.0, double.infinity)),
            child: Text(char, style: style),
          ),
        ),
      ),
    );
  }
}

class _FeatheredReveal extends StatelessWidget {
  final double t;
  final Widget child;

  static const double _feather = 0.08;

  const _FeatheredReveal({required this.t, required this.child});

  @override
  Widget build(BuildContext context) {
    final double tt = t.clamp(0.0, 1.0);
    final double edge = -_feather + tt * (1 + 2 * _feather);
    final double whiteStop = (edge - _feather).clamp(0.0, 1.0);
    final double transparentStop = edge.clamp(0.0, 1.0);

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, whiteStop, transparentStop],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}