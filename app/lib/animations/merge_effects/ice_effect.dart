import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'base_effect.dart';

/// Ice shatter effect - fragments scatter
class IceShatterEffect extends MergeEffect {
  @override
  String get id => 'iceShatter';

  @override
  String get name => '얼음부서짐';

  @override
  Widget build(Widget child, Animation<double> animation, Color color) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;

        // Crack and shatter effect via scale
        double scale = 1.0;
        if (value < 0.3) {
          // Slight compression before shatter
          scale = 1.0 - 0.05 * (value / 0.3);
        } else if (value < 0.5) {
          // Quick expand
          final t = (value - 0.3) / 0.2;
          scale = 0.95 + 0.2 * t;
        } else {
          // Settle
          final t = (value - 0.5) / 0.5;
          scale = 1.15 - 0.15 * t;
        }

        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: value < 0.6
                  ? [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.3 * (1 - value)),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
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
          painter: IceShardPainter(
            progress: (value - 0.2) / 0.6,
          ),
        );
      },
    );
  }
}

/// Ice shard particle painter
class IceShardPainter extends CustomPainter {
  final double progress;
  final math.Random _random = math.Random(42);

  IceShardPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shardCount = 8;

    for (int i = 0; i < shardCount; i++) {
      final angle = (i / shardCount) * 2 * math.pi + _random.nextDouble() * 0.2;
      final speed = 0.7 + _random.nextDouble() * 0.6;
      final distance = size.width * 0.6 * progress * speed;

      // Gravity effect
      final gravityOffset = progress * progress * size.height * 0.3;

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance + gravityOffset;

      final opacity = (1 - progress) * 0.8;
      final shardSize = 4.0 + _random.nextDouble() * 3;

      // Draw ice shard (triangle-ish)
      _drawShard(canvas, Offset(x, y), shardSize, angle, opacity);
    }
  }

  void _drawShard(Canvas canvas, Offset position, double size, double angle, double opacity) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(opacity * 0.7)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.5)
      ..style = PaintingStyle.fill;

    // Simple diamond shape
    final path = Path();
    path.moveTo(position.dx, position.dy - size);
    path.lineTo(position.dx + size * 0.5, position.dy);
    path.lineTo(position.dx, position.dy + size);
    path.lineTo(position.dx - size * 0.5, position.dy);
    path.close();

    // Rotate shard
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle);
    canvas.translate(-position.dx, -position.dy);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(IceShardPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
