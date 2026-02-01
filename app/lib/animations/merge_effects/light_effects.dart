import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'base_effect.dart';

/// Light scatter effect - radial light rays
class LightScatterEffect extends MergeEffect {
  @override
  String get id => 'lightScatter';

  @override
  String get name => '빛산란';

  @override
  Widget build(Widget child, Animation<double> animation, Color color) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;

        // Pulsing glow
        final glowIntensity = math.sin(value * math.pi);

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(glowIntensity * 0.5),
                blurRadius: 20 * glowIntensity,
                spreadRadius: 5 * glowIntensity,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(glowIntensity * 0.3),
                blurRadius: 10 * glowIntensity,
                spreadRadius: 2 * glowIntensity,
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
        if (value < 0.1 || value > 0.8) return const SizedBox.shrink();

        return CustomPaint(
          size: size,
          painter: LightRayPainter(
            progress: value,
            color: color,
            rayCount: 8,
          ),
        );
      },
    );
  }
}

/// Gem sparkle effect - random sparkles
class GemSparkleEffect extends MergeEffect {
  @override
  String get id => 'gemSparkle';

  @override
  String get name => '보석반짝임';

  @override
  Widget build(Widget child, Animation<double> animation, Color color) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;

        // Twinkling effect
        final twinkle = (math.sin(value * 6 * math.pi) * 0.5 + 0.5) * (1 - value);

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(twinkle * 0.6),
                blurRadius: 15,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(twinkle * 0.4),
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
        if (value > 0.9) return const SizedBox.shrink();

        return CustomPaint(
          size: size,
          painter: SparklePainter(
            progress: value,
            color: color,
          ),
        );
      },
    );
  }
}

/// Light ray painter
class LightRayPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int rayCount;

  LightRayPainter({
    required this.progress,
    required this.color,
    this.rayCount = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxLength = size.width * 0.8;

    for (int i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * 2 * math.pi;
      final rayLength = maxLength * progress;
      final opacity = math.sin(progress * math.pi) * 0.6;

      final endX = center.dx + math.cos(angle) * rayLength;
      final endY = center.dy + math.sin(angle) * rayLength;

      // Gradient ray
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(opacity),
            color.withOpacity(opacity * 0.5),
            color.withOpacity(0),
          ],
        ).createShader(Rect.fromPoints(center, Offset(endX, endY)))
        ..strokeWidth = 3.0 * (1 - progress * 0.5)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(center, Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(LightRayPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Sparkle painter
class SparklePainter extends CustomPainter {
  final double progress;
  final Color color;
  final math.Random _random = math.Random(42);

  SparklePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sparkleCount = 12;
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < sparkleCount; i++) {
      // Staggered appearance
      final delay = (i / sparkleCount) * 0.5;
      final localProgress = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);

      if (localProgress <= 0) continue;

      final angle = _random.nextDouble() * 2 * math.pi;
      final distance = size.width * 0.3 * (0.5 + _random.nextDouble() * 0.5);

      final x = center.dx + math.cos(angle) * distance * localProgress;
      final y = center.dy + math.sin(angle) * distance * localProgress;

      // Twinkling
      final twinkle = math.sin(localProgress * 4 * math.pi);
      final opacity = (1 - localProgress) * (0.5 + twinkle * 0.5).clamp(0.0, 1.0);
      final sparkleSize = 3.0 * (1 - localProgress * 0.5);

      _drawSparkle(canvas, Offset(x, y), sparkleSize, opacity);
    }
  }

  void _drawSparkle(Canvas canvas, Offset position, double size, double opacity) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    // Four-pointed star
    final path = Path();
    path.moveTo(position.dx, position.dy - size);
    path.lineTo(position.dx + size * 0.3, position.dy);
    path.lineTo(position.dx + size, position.dy);
    path.lineTo(position.dx + size * 0.3, position.dy);
    path.lineTo(position.dx, position.dy + size);
    path.lineTo(position.dx - size * 0.3, position.dy);
    path.lineTo(position.dx - size, position.dy);
    path.lineTo(position.dx - size * 0.3, position.dy);
    path.close();

    canvas.drawPath(path, paint);

    // Center glow
    final glowPaint = Paint()
      ..color = color.withOpacity(opacity * 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(position, size * 0.3, glowPaint);
  }

  @override
  bool shouldRepaint(SparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
