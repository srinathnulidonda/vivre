// lib/motion/springs.dart
import 'package:flutter/animation.dart';

class _SpringCurve extends Curve {
  final List<double> _samples;
  const _SpringCurve(this._samples);

  @override
  double transformInternal(double t) {
    final double pos = t * (_samples.length - 1);
    final int i = pos.floor().clamp(0, _samples.length - 2);
    final double frac = pos - i;
    return _samples[i] + (_samples[i + 1] - _samples[i]) * frac;
  }
}

class AppSprings {
  AppSprings._();

  static const Curve snap = _SpringCurve([
    0, 0.0265, 0.0901, 0.1725, 0.2632, 0.3536, 0.4403, 0.5198, 0.5918,
    0.655, 0.7104, 0.7582, 0.7988, 0.8333, 0.8623, 0.8867, 0.9069,
    0.9238, 0.9377, 0.9492, 0.9587, 0.9664, 0.9728, 0.9779, 0.9822,
    0.9856, 0.9884, 0.9906, 0.9924, 0.9939, 0.9951, 1,
  ]);

  static const Curve settle = _SpringCurve([
    0, 0.0664, 0.1883, 0.3123, 0.424, 0.5193, 0.6, 0.667, 0.7232,
    0.7697, 0.8086, 0.8409, 0.8677, 0.89, 0.9085, 0.924, 0.9367,
    0.9474, 0.9563, 0.9636, 0.9698, 0.9749, 0.9791, 0.9826, 0.9856,
    0.988, 0.99, 0.9917, 0.9931, 0.9943, 0.9952, 1,
  ]);
}