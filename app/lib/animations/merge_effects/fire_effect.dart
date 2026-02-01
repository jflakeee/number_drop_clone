import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'base_effect.dart';

/// Fire effect - burning flames animation
class FireEffect extends MergeEffect {
  @override
  String get id => 'fire';

  @override
  String get name => '불';

  @override
  Widget build(Widget child, Animation<double> animation, Color color) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;

        // Flickering scale effect
        final flicker = math.sin(value * 8 * math.pi) * 0.03;
        final scale = 1.0 + 0.15 * math.sin(value * math.pi) + flicker;

        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.6 * (1 - value)),
                  blurRadius: 20 * value,
                  spreadRadius: 5 * value,
                ),
                BoxShadow(
                  color: Colors.red.withOpacity(0.4 * (1 - value)),
                  blurRadius: 30 * value,
                  spreadRadius: 10 * value,
                ),
              ],
            ),
            child: child,
          ),
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
        if (value < 0.2 || value > 0.8) return const SizedBox.shrink();

        return CustomPaint(
          size: size,
          painter: FlamePainter(
            progress: value,
            color: color,
          ),
        );
      },
    );
  }
}

/// Custom painter for flame particles
class FlamePainter extends CustomPainter {
  final double progress;
  final Color color;
  final math.Random _random = math.Random(42); // Fixed seed for consistency

  FlamePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final particleCount = 8;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final randomOffset = _random.nextDouble() * 0.3;
      final distance = size.width * 0.5 * progress * (1 + randomOffset);

      // Particles rise up slightly
      final riseOffset = -progress * size.height * 0.3;

      final x = center.dx + math.cos(angle) * distance * 0.5;
      final y = center.dy + math.sin(angle) * distance * 0.3 + riseOffset;

      final opacity = (1 - progress) * 0.8;
      final particleSize = 4.0 * (1 - progress * 0.5);

      // Gradient from yellow to orange to red
      final colorProgress = (i / particleCount + progress) % 1.0;
      final particleColor = Color.lerp(
        Colors.yellow,
        Color.lerp(Colors.orange, Colors.red, colorProgress)!,
        progress,
      )!;

      final paint = Paint()
        ..color = particleColor.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(FlamePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
