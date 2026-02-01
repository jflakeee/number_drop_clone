/// Game settings model for customizable gameplay options
library;

/// Easing type for drop/gravity animations
enum EasingType {
  gravity('중력', 'Accelerating fall'),
  magnet('자석', 'Pull with bounce'),
  cotton('솜', 'Soft deceleration'),
  metal('금속', 'Constant speed'),
  jelly('젤리', 'Bouncy landing');

  final String koreanName;
  final String description;

  const EasingType(this.koreanName, this.description);
}

/// Merge animation effect type
enum MergeAnimationType {
  jelly('젤리', 'Stretch and squash'),
  water('물', 'Ripple wave effect'),
  fire('불', 'Burning flames'),
  metalSpark('금속충돌불꽃', 'Metal collision sparks'),
  electricSpark('전기스파크', 'Electric lightning'),
  iceShatter('얼음부서짐', 'Ice shattering'),
  lightScatter('빛산란', 'Radial light rays'),
  gemSparkle('보석반짝임', 'Gem sparkles');

  final String koreanName;
  final String description;

  const MergeAnimationType(this.koreanName, this.description);
}

/// Block visual theme
enum BlockTheme {
  classic('클래식', 'Default colorful blocks'),
  metal('금속', 'Metallic shiny blocks'),
  gem('보석', 'Sparkling gemstones'),
  glass('유리', 'Transparent glass'),
  gravel('자갈', 'Rough stone texture'),
  wood('나무', 'Warm wooden blocks'),
  soil('흙', 'Earthy tones'),
  water('물', 'Fluid water blocks'),
  fire('불', 'Flaming blocks');

  final String koreanName;
  final String description;

  const BlockTheme(this.koreanName, this.description);
}

/// Game settings configuration
class GameSettings {
  // === Animation Durations (milliseconds) ===
  final int dropDuration;
  final int mergeDuration;
  final int mergeMoveDuration;
  final int gravityDuration;

  // === Animation Types ===
  final EasingType easingType;
  final MergeAnimationType mergeAnimation;

  // === Block Theme ===
  final BlockTheme blockTheme;

  // === Gameplay Options ===
  final bool allowDropDuringMerge;
  final bool showGhostBlock;
  final bool screenShakeEnabled;

  // === Default Values ===
  static const int defaultDropDuration = 120;
  static const int defaultMergeDuration = 250;
  static const int defaultMergeMoveDuration = 180;
  static const int defaultGravityDuration = 80;
  static const EasingType defaultEasingType = EasingType.gravity;
  static const MergeAnimationType defaultMergeAnimation = MergeAnimationType.jelly;
  static const BlockTheme defaultBlockTheme = BlockTheme.classic;
  static const bool defaultAllowDropDuringMerge = false;
  static const bool defaultShowGhostBlock = true;
  static const bool defaultScreenShakeEnabled = true;

  // === Duration Limits ===
  static const int minDuration = 0;
  static const int maxDuration = 1000;
  static const int durationStep = 20;

  const GameSettings({
    this.dropDuration = defaultDropDuration,
    this.mergeDuration = defaultMergeDuration,
    this.mergeMoveDuration = defaultMergeMoveDuration,
    this.gravityDuration = defaultGravityDuration,
    this.easingType = defaultEasingType,
    this.mergeAnimation = defaultMergeAnimation,
    this.blockTheme = defaultBlockTheme,
    this.allowDropDuringMerge = defaultAllowDropDuringMerge,
    this.showGhostBlock = defaultShowGhostBlock,
    this.screenShakeEnabled = defaultScreenShakeEnabled,
  });

  /// Create a copy with updated values
  GameSettings copyWith({
    int? dropDuration,
    int? mergeDuration,
    int? mergeMoveDuration,
    int? gravityDuration,
    EasingType? easingType,
    MergeAnimationType? mergeAnimation,
    BlockTheme? blockTheme,
    bool? allowDropDuringMerge,
    bool? showGhostBlock,
    bool? screenShakeEnabled,
  }) {
    return GameSettings(
      dropDuration: dropDuration ?? this.dropDuration,
      mergeDuration: mergeDuration ?? this.mergeDuration,
      mergeMoveDuration: mergeMoveDuration ?? this.mergeMoveDuration,
      gravityDuration: gravityDuration ?? this.gravityDuration,
      easingType: easingType ?? this.easingType,
      mergeAnimation: mergeAnimation ?? this.mergeAnimation,
      blockTheme: blockTheme ?? this.blockTheme,
      allowDropDuringMerge: allowDropDuringMerge ?? this.allowDropDuringMerge,
      showGhostBlock: showGhostBlock ?? this.showGhostBlock,
      screenShakeEnabled: screenShakeEnabled ?? this.screenShakeEnabled,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'dropDuration': dropDuration,
      'mergeDuration': mergeDuration,
      'mergeMoveDuration': mergeMoveDuration,
      'gravityDuration': gravityDuration,
      'easingType': easingType.name,
      'mergeAnimation': mergeAnimation.name,
      'blockTheme': blockTheme.name,
      'allowDropDuringMerge': allowDropDuringMerge,
      'showGhostBlock': showGhostBlock,
      'screenShakeEnabled': screenShakeEnabled,
    };
  }

  /// Create from JSON
  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      dropDuration: _parseIntWithDefault(
        json['dropDuration'],
        defaultDropDuration,
        minDuration,
        maxDuration,
      ),
      mergeDuration: _parseIntWithDefault(
        json['mergeDuration'],
        defaultMergeDuration,
        minDuration,
        maxDuration,
      ),
      mergeMoveDuration: _parseIntWithDefault(
        json['mergeMoveDuration'],
        defaultMergeMoveDuration,
        minDuration,
        maxDuration,
      ),
      gravityDuration: _parseIntWithDefault(
        json['gravityDuration'],
        defaultGravityDuration,
        minDuration,
        maxDuration,
      ),
      easingType: _parseEnum(
        json['easingType'],
        EasingType.values,
        defaultEasingType,
      ),
      mergeAnimation: _parseEnum(
        json['mergeAnimation'],
        MergeAnimationType.values,
        defaultMergeAnimation,
      ),
      blockTheme: _parseEnum(
        json['blockTheme'],
        BlockTheme.values,
        defaultBlockTheme,
      ),
      allowDropDuringMerge: json['allowDropDuringMerge'] as bool? ?? defaultAllowDropDuringMerge,
      showGhostBlock: json['showGhostBlock'] as bool? ?? defaultShowGhostBlock,
      screenShakeEnabled: json['screenShakeEnabled'] as bool? ?? defaultScreenShakeEnabled,
    );
  }

  /// Parse int with bounds checking
  static int _parseIntWithDefault(dynamic value, int defaultValue, int min, int max) {
    if (value == null) return defaultValue;
    if (value is int) {
      return value.clamp(min, max);
    }
    if (value is num) {
      return value.toInt().clamp(min, max);
    }
    return defaultValue;
  }

  /// Parse enum from string name
  static T _parseEnum<T extends Enum>(dynamic value, List<T> values, T defaultValue) {
    if (value == null) return defaultValue;
    if (value is String) {
      try {
        return values.firstWhere((e) => e.name == value);
      } catch (_) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  /// Default settings instance
  static const GameSettings defaults = GameSettings();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameSettings &&
        other.dropDuration == dropDuration &&
        other.mergeDuration == mergeDuration &&
        other.mergeMoveDuration == mergeMoveDuration &&
        other.gravityDuration == gravityDuration &&
        other.easingType == easingType &&
        other.mergeAnimation == mergeAnimation &&
        other.blockTheme == blockTheme &&
        other.allowDropDuringMerge == allowDropDuringMerge &&
        other.showGhostBlock == showGhostBlock &&
        other.screenShakeEnabled == screenShakeEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      dropDuration,
      mergeDuration,
      mergeMoveDuration,
      gravityDuration,
      easingType,
      mergeAnimation,
      blockTheme,
      allowDropDuringMerge,
      showGhostBlock,
      screenShakeEnabled,
    );
  }

  @override
  String toString() {
    return 'GameSettings('
        'drop: ${dropDuration}ms, '
        'merge: ${mergeDuration}ms, '
        'easing: ${easingType.name}, '
        'effect: ${mergeAnimation.name}, '
        'theme: ${blockTheme.name})';
  }
}
