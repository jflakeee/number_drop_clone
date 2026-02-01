import 'dart:math' as math;
import 'package:flutter/animation.dart';
import '../config/game_settings.dart';

/// Custom easing curves for game animations
class GameEasings {
  GameEasings._();

  /// Get Flutter Curve for the given EasingType
  static Curve getCurve(EasingType type) {
    switch (type) {
      case EasingType.gravity:
        return Curves.easeIn; // Accelerating fall
      case EasingType.magnet:
        return const MagnetCurve(); // Pull with overshoot
      case EasingType.cotton:
        return Curves.easeOutSine; // Soft deceleration
      case EasingType.metal:
        return Curves.linear; // Constant speed
      case EasingType.jelly:
        return Curves.bounceOut; // Bouncy landing
    }
  }

  /// Get drop curve (for falling blocks)
  static Curve getDropCurve(EasingType type) {
    return getCurve(type);
  }

  /// Get merge curve (for blocks moving to merge target)
  static Curve getMergeCurve(EasingType type) {
    // Merge uses different curves for smoother appearance
    switch (type) {
      case EasingType.gravity:
        return Curves.easeOutCubic;
      case EasingType.magnet:
        return const MagnetCurve(overshoot: 0.3);
      case EasingType.cotton:
        return Curves.easeOutQuad;
      case EasingType.metal:
        return Curves.linear;
      case EasingType.jelly:
        return Curves.elasticOut;
    }
  }

  /// Get gravity curve (for blocks falling after merge)
  static Curve getGravityCurve(EasingType type) {
    switch (type) {
      case EasingType.gravity:
        return Curves.easeIn;
      case EasingType.magnet:
        return Curves.easeInQuad;
      case EasingType.cotton:
        return Curves.easeInSine;
      case EasingType.metal:
        return Curves.linear;
      case EasingType.jelly:
        return Curves.easeIn;
    }
  }
}

/// Custom magnet-like curve with overshoot effect
/// Simulates being pulled by a magnet - accelerates then overshoots slightly
class MagnetCurve extends Curve {
  final double overshoot;

  const MagnetCurve({this.overshoot = 0.5});

  @override
  double transformInternal(double t) {
    // Modified back-out easing with configurable overshoot
    // Formula: 1 + (s+1) * (t-1)^3 + s * (t-1)^2
    final s = overshoot * 1.70158; // Magic number from standard back easing
    final t1 = t - 1;
    return 1 + (s + 1) * t1 * t1 * t1 + s * t1 * t1;
  }
}

/// Elastic curve for jelly-like effects
class JellyStretchCurve extends Curve {
  final double amplitude;
  final double period;

  const JellyStretchCurve({
    this.amplitude = 1.0,
    this.period = 0.4,
  });

  @override
  double transformInternal(double t) {
    if (t == 0 || t == 1) return t;

    final s = period / 4;
    return amplitude *
            math.pow(2, -10 * t) *
            math.sin((t - s) * (2 * math.pi) / period) +
        1;
  }
}

/// Quick pulse curve for scale effects
class PulseCurve extends Curve {
  final double scale;

  const PulseCurve({this.scale = 0.2});

  @override
  double transformInternal(double t) {
    // Grows then shrinks: starts at 1, peaks at 1+scale at t=0.5, returns to 1
    if (t < 0.5) {
      return 1.0 + scale * (t * 2);
    } else {
      return 1.0 + scale * (2 - t * 2);
    }
  }
}

/// Shake curve for screen shake effect
class ShakeCurve extends Curve {
  final int shakes;
  final double decay;

  const ShakeCurve({
    this.shakes = 3,
    this.decay = 0.5,
  });

  @override
  double transformInternal(double t) {
    // Decaying sine wave
    final decayFactor = math.pow(1 - t, decay);
    return math.sin(t * shakes * 2 * math.pi) * decayFactor;
  }
}
