import 'package:flutter/material.dart';

/// Base class for merge animation effects
abstract class MergeEffect {
  /// Unique identifier for this effect type
  String get id;

  /// Display name
  String get name;

  /// Wrap the child widget with the merge effect animation
  /// [child] - The block widget to animate
  /// [animation] - Animation value from 0.0 to 1.0
  /// [color] - The block's primary color for effect theming
  Widget build(Widget child, Animation<double> animation, Color color);

  /// Optional: Build overlay effects (particles, etc.)
  /// These are rendered on top of the main widget
  Widget? buildOverlay(Animation<double> animation, Color color, Size size) {
    return null;
  }
}

/// Animation phase helper
enum MergePhase {
  /// Block is moving toward merge target
  moving,
  /// Blocks are merging (scale/glow effects)
  merging,
  /// Merge complete, showing result
  complete,
}

/// Helper to determine current phase based on animation value
MergePhase getPhase(double value) {
  if (value < 0.4) return MergePhase.moving;
  if (value < 0.7) return MergePhase.merging;
  return MergePhase.complete;
}
