import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'base_effect.dart';

/// Jelly effect - stretches and squashes like jelly
class JellyEffect extends MergeEffect {
  @override
  String get id => 'jelly';

  @override
  String get name => '젤리';

  @override
  Widget build(Widget child, Animation<double> animation, Color color) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;

        // Scale animation: grow then shrink with overshoot
        double scaleX = 1.0;
        double scaleY = 1.0;

        if (value < 0.3) {
          // Stretch horizontally, squash vertically
          final t = value / 0.3;
          scaleX = 1.0 + 0.2 * math.sin(t * math.pi);
          scaleY = 1.0 - 0.1 * math.sin(t * math.pi);
        } else if (value < 0.6) {
          // Squash horizontally, stretch vertically
          final t = (value - 0.3) / 0.3;
          scaleX = 1.0 - 0.15 * math.sin(t * math.pi);
          scaleY = 1.0 + 0.15 * math.sin(t * math.pi);
        } else {
          // Settle back with wobble
          final t = (value - 0.6) / 0.4;
          final wobble = math.sin(t * 2 * math.pi) * (1 - t) * 0.05;
          scaleX = 1.0 + wobble;
          scaleY = 1.0 - wobble;
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(scaleX, scaleY),
          child: child,
        );
      },
      child: child,
    );
  }
}
