import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'base_effect.dart';

/// Metal spark effect - collision sparks
class MetalSparkEffect extends MergeEffect {
  @override
  String get id => 'metalSpark';

  @override
  String get name => '금속충돌불꽃';

  @override
  Widget build(Widget child, Animation<double> animation, Color color) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;

        // Quick flash on impact
        final flash = value < 0.2 ? (0.2 - value) / 0.2 : 0.0;

        return Container(
          decoration: BoxDecoration(
            boxShadow: flash > 0
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(flash * 0.8),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.orange.withOpacity(flash * 0.5),
                      blurRadius: 25,
                      spreadRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: child,
    );
  }

  @override
  Widget? buildOverlay(Animation<double> animation, Color color, Size size) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final value = animation.value;
        if (value > 0.6) return const SizedBox.shrink();

        return CustomPaint(
          size: size,
          painter: SparkPainter(
            progress: value,
            sparkColor: Colors.orange,
            sparkCount: 12,
          ),
        );
      },
    );
  }
}

/// Electric spark effect - lightning
class ElectricSparkEffect extends MergeEffect {
  @override
  String get id => 'electricSpark';

  @override
  String get name => '전기스파크';

  @override
  Widget build(Widget child, Animation<double> animation, Color color) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;

        // Electric glow effect
        final glowIntensity = math.sin(value * 4 * math.pi).abs() * (1 - value);

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(glowIntensity * 0.7),
                blurRadius: 15,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(glowIntensity * 0.5),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: child,
    );
  }

  @override
  Widget? buildOverlay(Animation<double> animation, Color color, Size size) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final value = animation.value;
        if (value > 0.7) return const SizedBox.shrink();

        return CustomPaint(
          size: size,
          painter: LightningPainter(
            progress: value,
            color: Colors.cyan,
          ),
        );
      },
    );
  }
}

/// Spark particle painter
class SparkPainter extends CustomPainter {
  final double progress;
  final Color sparkColor;
  final int sparkCount;
  final math.Random _random = math.Random(42);

  SparkPainter({
    required this.progress,
    required this.sparkColor,
    this.sparkCount = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < sparkCount; i++) {
      final angle = (i / sparkCount) * 2 * math.pi + _random.nextDouble() * 0.3;
      final speed = 0.8 + _random.nextDouble() * 0.4;
      final distance = size.width * progress * speed;

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      final opacity = (1 - progress) * 0.9;
      final sparkSize = 3.0 * (1 - progress * 0.7);

      // Draw spark line
      final paint = Paint()
        ..color = sparkColor.withOpacity(opacity)
        ..strokeWidth = sparkSize
        ..strokeCap = StrokeCap.round;

      final startX = center.dx + math.cos(angle) * distance * 0.8;
      final startY = center.dy + math.sin(angle) * distance * 0.8;

      canvas.drawLine(Offset(startX, startY), Offset(x, y), paint);

      // Draw spark head
      final headPaint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), sparkSize * 0.5, headPaint);
    }
  }

  @override
  bool shouldRepaint(SparkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Lightning bolt painter
class LightningPainter extends CustomPainter {
  final double progress;
  final Color color;
  final math.Random _random = math.Random(42);

  LightningPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final boltCount = 4;

    for (int i = 0; i < boltCount; i++) {
      final startAngle = (i / boltCount) * 2 * math.pi;
      _drawLightningBolt(canvas, center, startAngle, size.width * 0.6 * progress);
    }
  }

  void _drawLightningBolt(Canvas canvas, Offset start, double angle, double length) {
    if (length < 5) return;

    final segments = 4;
    final opacity = (1 - progress) * 0.8;

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.5)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    Offset current = start;

    for (int i = 0; i < segments; i++) {
      final segmentLength = length / segments;
      final jitter = (_random.nextDouble() - 0.5) * 0.5;
      final segmentAngle = angle + jitter;

      final next = Offset(
        current.dx + math.cos(segmentAngle) * segmentLength,
        current.dy + math.sin(segmentAngle) * segmentLength,
      );

      canvas.drawLine(current, next, glowPaint);
      canvas.drawLine(current, next, paint);

      current = next;
    }
  }

  @override
  bool shouldRepaint(LightningPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
