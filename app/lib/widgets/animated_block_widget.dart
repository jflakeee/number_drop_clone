import 'package:flutter/material.dart';
import '../models/block.dart';
import '../config/block_themes.dart';
import '../services/settings_service.dart';

/// Animated block widget with drop, merge, and glow effects
class AnimatedBlockWidget extends StatefulWidget {
  final Block block;
  final double size;
  final bool showShadow;
  final bool isHammerTarget;
  final bool isNew;
  final bool isMerging;
  final VoidCallback? onMergeComplete;

  const AnimatedBlockWidget({
    super.key,
    required this.block,
    required this.size,
    this.showShadow = false,
    this.isHammerTarget = false,
    this.isNew = false,
    this.isMerging = false,
    this.onMergeComplete,
  });

  @override
  State<AnimatedBlockWidget> createState() => _AnimatedBlockWidgetState();
}

class _AnimatedBlockWidgetState extends State<AnimatedBlockWidget>
    with TickerProviderStateMixin {
  late AnimationController _dropController;
  late AnimationController _mergeController;
  late AnimationController _glowController;
  late AnimationController _sparkleController;

  late Animation<double> _dropAnimation;
  late Animation<double> _mergeScaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();

    // Drop animation controller
    _dropController = AnimationController(
      duration: Duration(milliseconds: SettingsService.instance.dropDuration),
      vsync: this,
    );

    _dropAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dropController, curve: Curves.easeOut),
    );

    // Merge animation controller
    _mergeController = AnimationController(
      duration: Duration(milliseconds: SettingsService.instance.mergeDuration),
      vsync: this,
    );

    _mergeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_mergeController);

    // Glow animation for high-value blocks
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Sparkle animation for 512+ blocks
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );

    // Start animations based on state
    if (widget.isNew) {
      _dropController.forward();
    }

    if (widget.isMerging) {
      _mergeController.forward().then((_) {
        widget.onMergeComplete?.call();
      });
    }

    if (widget.block.hasGlow) {
      _glowController.repeat(reverse: true);
    }

    // Start sparkle animation for 512+ blocks
    if (widget.block.hasCrown) {
      _sparkleController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isMerging && !oldWidget.isMerging) {
      _mergeController.forward(from: 0).then((_) {
        widget.onMergeComplete?.call();
      });
    }

    if (widget.block.hasGlow && !oldWidget.block.hasGlow) {
      _glowController.repeat(reverse: true);
    } else if (!widget.block.hasGlow && oldWidget.block.hasGlow) {
      _glowController.stop();
    }

    if (widget.block.hasCrown && !oldWidget.block.hasCrown) {
      _sparkleController.repeat(reverse: true);
    } else if (!widget.block.hasCrown && oldWidget.block.hasCrown) {
      _sparkleController.stop();
    }
  }

  @override
  void dispose() {
    _dropController.dispose();
    _mergeController.dispose();
    _glowController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showShadow) {
      return _buildShadowBlock();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        _dropController,
        _mergeController,
        _glowController,
        _sparkleController,
      ]),
      builder: (context, child) {
        double scale = 1.0;
        double opacity = 1.0;

        if (widget.isNew && _dropController.isAnimating) {
          opacity = _dropAnimation.value;
        }

        if (widget.isMerging || _mergeController.isAnimating) {
          scale = _mergeScaleAnimation.value;
        }

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: _buildBlock(),
          ),
        );
      },
    );
  }

  Widget _buildShadowBlock() {
    final themeData = BlockThemes.getTheme(SettingsService.instance.blockTheme);
    final color = themeData.getColor(widget.block.value);

    return Container(
      width: widget.size,
      height: widget.size,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3 * themeData.opacity),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildBlock() {
    final hasCrown = widget.block.hasCrown;
    final themeData = BlockThemes.getTheme(SettingsService.instance.blockTheme);
    final themeColor = themeData.getColor(widget.block.value);
    final themeGradient = themeData.getGradient(widget.block.value);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main block
        Container(
          width: widget.size,
          height: widget.size,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: themeGradient == null ? themeColor.withOpacity(themeData.opacity) : null,
            gradient: themeGradient,
            borderRadius: BorderRadius.circular(8),
            border: widget.isHammerTarget
                ? Border.all(color: Colors.red, width: 2)
                : hasCrown
                    ? Border.all(color: const Color(0xFFFFD700), width: 2)
                    : null,
            boxShadow: _buildBoxShadow(themeColor, themeData),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Sparkle effect for 512+ blocks
              if (hasCrown) ...[
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Opacity(
                    opacity: _sparkleAnimation.value,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 4,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 4,
                  child: Opacity(
                    opacity: 1.0 - _sparkleAnimation.value,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.6),
                            blurRadius: 3,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              // Hammer icon overlay when in hammer mode
              if (widget.isHammerTarget)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.close,
                    color: Colors.red.withOpacity(0.8),
                    size: widget.size * 0.2,
                  ),
                ),
              // Block value
              Text(
                _formatValue(widget.block.value),
                style: TextStyle(
                  color: widget.block.textColor,
                  fontSize: _getFontSize(widget.block.value, widget.size),
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Crown on TOP of block (outside)
        if (hasCrown)
          Positioned(
            top: -8,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '👑',
                style: TextStyle(
                  fontSize: widget.size * 0.28,
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<BoxShadow>? _buildBoxShadow(Color themeColor, BlockThemeData themeData) {
    if (widget.isHammerTarget) {
      return [
        BoxShadow(
          color: Colors.red.withOpacity(0.4),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
    }

    // Theme-specific glow
    if (themeData.hasGlow || widget.block.hasGlow) {
      return [
        BoxShadow(
          color: themeColor.withOpacity(_glowAnimation.value * 0.8),
          blurRadius: 12 + (_glowAnimation.value * 8),
          spreadRadius: 2 + (_glowAnimation.value * 2),
        ),
      ];
    }

    // Reflection effect for themes that support it
    if (themeData.hasReflection) {
      return [
        BoxShadow(
          color: Colors.white.withOpacity(0.1),
          blurRadius: 4,
          spreadRadius: 0,
          offset: const Offset(-2, -2),
        ),
      ];
    }

    return null;
  }

  String _formatValue(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return value.toString();
  }

  double _getFontSize(int value, double size) {
    final digits = value.toString().length;
    if (digits <= 2) return size * 0.4;
    if (digits <= 3) return size * 0.35;
    if (digits <= 4) return size * 0.28;
    return size * 0.22;
  }
}
