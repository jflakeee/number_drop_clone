import '../../config/game_settings.dart';
import 'base_effect.dart';
import 'jelly_effect.dart';
import 'water_effect.dart';
import 'fire_effect.dart';
import 'spark_effects.dart';
import 'ice_effect.dart';
import 'light_effects.dart';

/// Factory for creating merge effects by type
class MergeEffectFactory {
  MergeEffectFactory._();

  static final Map<MergeAnimationType, MergeEffect> _cache = {};

  /// Get or create a merge effect for the given type
  static MergeEffect create(MergeAnimationType type) {
    return _cache.putIfAbsent(type, () => _createEffect(type));
  }

  static MergeEffect _createEffect(MergeAnimationType type) {
    switch (type) {
      case MergeAnimationType.jelly:
        return JellyEffect();
      case MergeAnimationType.water:
        return WaterEffect();
      case MergeAnimationType.fire:
        return FireEffect();
      case MergeAnimationType.metalSpark:
        return MetalSparkEffect();
      case MergeAnimationType.electricSpark:
        return ElectricSparkEffect();
      case MergeAnimationType.iceShatter:
        return IceShatterEffect();
      case MergeAnimationType.lightScatter:
        return LightScatterEffect();
      case MergeAnimationType.gemSparkle:
        return GemSparkleEffect();
    }
  }

  /// Get all available effects
  static List<MergeEffect> get allEffects {
    return MergeAnimationType.values.map((type) => create(type)).toList();
  }

  /// Clear cache (for testing)
  static void clearCache() {
    _cache.clear();
  }
}
