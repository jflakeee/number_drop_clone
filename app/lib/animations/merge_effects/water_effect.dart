import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'base_effect.dart';

/// Water effect - ripple wave animation
class WaterEffect extends MergeEffect {
  @override
  String get id => 'water';

  @override
  String get name => '물';

  @override
  Widget build(Widget child, Animation<double> animation, Color color) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;

        // Subtle scale pulse
        final scale = 1.0 + 0.1 * math.sin(value * math.pi);

        return Transform.scale(
          scale: scale,
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
        if (value < 0.1 || value > 0.9) return const SizedBox.shrink();

        return CustomPaint(
          size: size,
          painter: RipplePainter(
            progress: value,
            color: color,
            rippleCount: 2,
          ),
        );
      },
    );
  }
}

/// Custom painter for ripple effect
class RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final int rippleCount;

  RipplePainter({
    required this.progress,
    required this.color,
    this.rippleCount = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * 0.8;

    for (int i = 0; i < rippleCount; i++) {
      final delay = i * 0.2;
      final rippleProgress = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);

      if (rippleProgress <= 0) continue;

      final radius = maxRadius * rippleProgress;
      final opacity = (1 - rippleProgress) * 0.5;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1 - rippleProgress);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
