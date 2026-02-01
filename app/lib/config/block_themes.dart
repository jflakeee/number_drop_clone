import 'package:flutter/material.dart';
import 'game_settings.dart';

/// Block theme data with colors and effects
class BlockThemeData {
  final String id;
  final String name;
  final String koreanName;
  final Map<int, Color> colors;
  final Map<int, LinearGradient?> gradients;
  final bool hasGlow;
  final bool hasReflection;
  final double opacity;
  final String? soundPack;

  const BlockThemeData({
    required this.id,
    required this.name,
    required this.koreanName,
    required this.colors,
    this.gradients = const {},
    this.hasGlow = false,
    this.hasReflection = false,
    this.opacity = 1.0,
    this.soundPack,
  });

  /// Get color for a block value
  Color getColor(int value) {
    if (colors.containsKey(value)) {
      return colors[value]!;
    }
    // Fallback for values not in map
    final keys = colors.keys.toList()..sort();
    if (keys.isEmpty) return Colors.grey;
    return colors[keys.last]!;
  }

  /// Get gradient for a block value
  LinearGradient? getGradient(int value) {
    return gradients[value];
  }
}

/// Block themes collection
class BlockThemes {
  BlockThemes._();

  /// Get theme data for a BlockTheme enum value
  static BlockThemeData getTheme(BlockTheme theme) {
    switch (theme) {
      case BlockTheme.classic:
        return classic;
      case BlockTheme.metal:
        return metal;
      case BlockTheme.gem:
        return gem;
      case BlockTheme.glass:
        return glass;
      case BlockTheme.gravel:
        return gravel;
      case BlockTheme.wood:
        return wood;
      case BlockTheme.soil:
        return soil;
      case BlockTheme.water:
        return water;
      case BlockTheme.fire:
        return fire;
    }
  }

  /// Classic theme (original colors)
  static const classic = BlockThemeData(
    id: 'classic',
    name: 'Classic',
    koreanName: '클래식',
    colors: {
      2: Color(0xFFE91E63),    // Pink/Magenta
      4: Color(0xFF4CAF50),    // Green
      8: Color(0xFF26C6DA),    // Cyan/Teal
      16: Color(0xFF2196F3),   // Blue
      32: Color(0xFFFF7043),   // Orange
      64: Color(0xFF9C27B0),   // Purple
      128: Color(0xFF5BA4A4),  // Teal (darker)
      256: Color(0xFFEC407A),  // Bright Pink
      512: Color(0xFF8BC34A),  // Light Green
      1024: Color(0xFFFFEB3B), // Yellow
      2048: Color(0xFFFF9800), // Orange/Gold
      4096: Color(0xFF9C27B0), // Purple
    },
    gradients: {
      4096: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
      ),
      8192: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF5722), Color(0xFFFFEB3B)],
      ),
    },
  );

  /// Metal theme (shiny metallic)
  static const metal = BlockThemeData(
    id: 'metal',
    name: 'Metal',
    koreanName: '금속',
    hasGlow: true,
    hasReflection: true,
    soundPack: 'metal',
    colors: {
      2: Color(0xFF78909C),    // Blue Grey
      4: Color(0xFF90A4AE),    // Light Blue Grey
      8: Color(0xFFB0BEC5),    // Lighter
      16: Color(0xFFCFD8DC),   // Silver
      32: Color(0xFFFFD54F),   // Gold
      64: Color(0xFFFFB300),   // Amber
      128: Color(0xFFFF8F00),  // Dark Amber
      256: Color(0xFFE65100),  // Deep Orange
      512: Color(0xFFBF360C),  // Bronze
      1024: Color(0xFFD4AF37), // Gold
      2048: Color(0xFFC0C0C0), // Silver
      4096: Color(0xFFB87333), // Copper
    },
    gradients: {
      2: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF90A4AE), Color(0xFF607D8B)],
      ),
      4: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB0BEC5), Color(0xFF78909C)],
      ),
      1024: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
      ),
    },
  );

  /// Gem theme (sparkling gemstones)
  static const gem = BlockThemeData(
    id: 'gem',
    name: 'Gem',
    koreanName: '보석',
    hasGlow: true,
    hasReflection: true,
    soundPack: 'gem',
    colors: {
      2: Color(0xFFE91E63),    // Ruby
      4: Color(0xFF4CAF50),    // Emerald
      8: Color(0xFF2196F3),    // Sapphire
      16: Color(0xFFFFEB3B),   // Topaz
      32: Color(0xFF9C27B0),   // Amethyst
      64: Color(0xFF00BCD4),   // Aquamarine
      128: Color(0xFFFF5722),  // Carnelian
      256: Color(0xFF673AB7),  // Deep Amethyst
      512: Color(0xFF8BC34A),  // Peridot
      1024: Color(0xFFE0E0E0), // Diamond
      2048: Color(0xFFFFD700), // Imperial Topaz
      4096: Color(0xFFFF1744), // Red Diamond
    },
    gradients: {
      1024: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFE0E0E0), Color(0xFFB0BEC5)],
      ),
    },
  );

  /// Glass theme (transparent)
  static const glass = BlockThemeData(
    id: 'glass',
    name: 'Glass',
    koreanName: '유리',
    hasReflection: true,
    opacity: 0.85,
    soundPack: 'glass',
    colors: {
      2: Color(0xFFE1BEE7),    // Light Purple
      4: Color(0xFFC8E6C9),    // Light Green
      8: Color(0xFFB3E5FC),    // Light Blue
      16: Color(0xFFFFF9C4),   // Light Yellow
      32: Color(0xFFFFCCBC),   // Light Orange
      64: Color(0xFFD1C4E9),   // Light Deep Purple
      128: Color(0xFFB2EBF2),  // Light Cyan
      256: Color(0xFFF8BBD9),  // Light Pink
      512: Color(0xFFDCEDC8),  // Light Lime
      1024: Color(0xFFFFFFFF), // Clear
      2048: Color(0xFFFFF8E1), // Light Amber
      4096: Color(0xFFE8EAF6), // Light Indigo
    },
  );

  /// Gravel theme (rough stone)
  static const gravel = BlockThemeData(
    id: 'gravel',
    name: 'Gravel',
    koreanName: '자갈',
    soundPack: 'gravel',
    colors: {
      2: Color(0xFF757575),    // Grey
      4: Color(0xFF616161),    // Darker Grey
      8: Color(0xFF9E9E9E),    // Light Grey
      16: Color(0xFF5D4037),   // Brown
      32: Color(0xFF795548),   // Light Brown
      64: Color(0xFF8D6E63),   // Lighter Brown
      128: Color(0xFFA1887F),  // Pale Brown
      256: Color(0xFF4E342E),  // Dark Brown
      512: Color(0xFF3E2723),  // Very Dark Brown
      1024: Color(0xFF424242), // Dark Grey
      2048: Color(0xFF212121), // Almost Black
      4096: Color(0xFF37474F), // Blue Grey Dark
    },
  );

  /// Wood theme (warm wooden)
  static const wood = BlockThemeData(
    id: 'wood',
    name: 'Wood',
    koreanName: '나무',
    soundPack: 'wood',
    colors: {
      2: Color(0xFFDEB887),    // Burlywood
      4: Color(0xFFD2691E),    // Chocolate
      8: Color(0xFFA0522D),    // Sienna
      16: Color(0xFF8B4513),   // Saddle Brown
      32: Color(0xFFCD853F),   // Peru
      64: Color(0xFFBC8F8F),   // Rosy Brown
      128: Color(0xFFF4A460),  // Sandy Brown
      256: Color(0xFF5C4033),  // Dark Wood
      512: Color(0xFF654321),  // Dark Brown
      1024: Color(0xFF8B0000), // Dark Red (Mahogany)
      2048: Color(0xFF2F1810), // Ebony
      4096: Color(0xFF3D1C02), // Very Dark Wood
    },
    gradients: {
      2: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFDEB887), Color(0xFFD2B48C)],
      ),
    },
  );

  /// Soil/Earth theme
  static const soil = BlockThemeData(
    id: 'soil',
    name: 'Soil',
    koreanName: '흙',
    soundPack: 'soil',
    colors: {
      2: Color(0xFF8D6E63),    // Light Brown
      4: Color(0xFF795548),    // Brown
      8: Color(0xFF6D4C41),    // Medium Brown
      16: Color(0xFF5D4037),   // Dark Brown
      32: Color(0xFF4E342E),   // Darker Brown
      64: Color(0xFF3E2723),   // Very Dark Brown
      128: Color(0xFFA1887F),  // Pale Brown
      256: Color(0xFF8B7355),  // Tan
      512: Color(0xFF6B4423),  // Raw Umber
      1024: Color(0xFF8B4513), // Saddle Brown
      2048: Color(0xFF704214), // Sepia
      4096: Color(0xFF3D2314), // Dark Earth
    },
  );

  /// Water theme (fluid)
  static const water = BlockThemeData(
    id: 'water',
    name: 'Water',
    koreanName: '물',
    hasGlow: true,
    opacity: 0.9,
    soundPack: 'water',
    colors: {
      2: Color(0xFF81D4FA),    // Light Blue
      4: Color(0xFF4FC3F7),    // Sky Blue
      8: Color(0xFF29B6F6),    // Blue
      16: Color(0xFF03A9F4),   // Bright Blue
      32: Color(0xFF039BE5),   // Deeper Blue
      64: Color(0xFF0288D1),   // Dark Blue
      128: Color(0xFF0277BD),  // Darker Blue
      256: Color(0xFF01579B),  // Very Dark Blue
      512: Color(0xFF00ACC1),  // Cyan
      1024: Color(0xFF00838F), // Dark Cyan
      2048: Color(0xFF006064), // Very Dark Cyan
      4096: Color(0xFF004D40), // Teal
    },
    gradients: {
      2: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB3E5FC), Color(0xFF81D4FA)],
      ),
    },
  );

  /// Fire theme (flaming)
  static const fire = BlockThemeData(
    id: 'fire',
    name: 'Fire',
    koreanName: '불',
    hasGlow: true,
    soundPack: 'fire',
    colors: {
      2: Color(0xFFFFEB3B),    // Yellow
      4: Color(0xFFFFC107),    // Amber
      8: Color(0xFFFF9800),    // Orange
      16: Color(0xFFFF5722),   // Deep Orange
      32: Color(0xFFF44336),   // Red
      64: Color(0xFFE53935),   // Dark Red
      128: Color(0xFFD32F2F),  // Darker Red
      256: Color(0xFFC62828),  // Very Dark Red
      512: Color(0xFFB71C1C),  // Blood Red
      1024: Color(0xFF880E4F), // Dark Pink
      2048: Color(0xFF4A148C), // Deep Purple (hot core)
      4096: Color(0xFF311B92), // Indigo (plasma)
    },
    gradients: {
      2: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFEB3B), Color(0xFFFF9800)],
      ),
      4: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFC107), Color(0xFFFF5722)],
      ),
    },
  );
}
