import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/game_settings.dart';

/// Service for managing game settings with persistence
class SettingsService extends ChangeNotifier {
  static const String _settingsKey = 'game_settings';
  static SettingsService? _instance;
  SharedPreferences? _prefs;
  GameSettings _settings = GameSettings.defaults;
  bool _initialized = false;

  SettingsService._();

  /// Singleton instance
  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  /// Current settings
  GameSettings get settings => _settings;

  /// Check if initialized
  bool get isInitialized => _initialized;

  // === Convenience Getters ===
  int get dropDuration => _settings.dropDuration;
  int get mergeDuration => _settings.mergeDuration;
  int get mergeMoveDuration => _settings.mergeMoveDuration;
  int get gravityDuration => _settings.gravityDuration;
  EasingType get easingType => _settings.easingType;
  MergeAnimationType get mergeAnimation => _settings.mergeAnimation;
  BlockTheme get blockTheme => _settings.blockTheme;
  bool get allowDropDuringMerge => _settings.allowDropDuringMerge;
  bool get showGhostBlock => _settings.showGhostBlock;
  bool get screenShakeEnabled => _settings.screenShakeEnabled;

  /// Initialize the service
  Future<void> init() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
    _initialized = true;
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    if (_prefs == null) return;

    final jsonString = _prefs!.getString(_settingsKey);
    if (jsonString == null) {
      _settings = GameSettings.defaults;
      return;
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _settings = GameSettings.fromJson(json);
    } catch (e) {
      // If parsing fails, use defaults
      debugPrint('SettingsService: Failed to parse settings, using defaults: $e');
      _settings = GameSettings.defaults;
    }
  }

  /// Save current settings to storage
  Future<void> _saveSettings() async {
    if (_prefs == null) return;

    try {
      final jsonString = jsonEncode(_settings.toJson());
      await _prefs!.setString(_settingsKey, jsonString);
    } catch (e) {
      debugPrint('SettingsService: Failed to save settings: $e');
    }
  }

  /// Update settings with new values
  Future<void> updateSettings(GameSettings newSettings) async {
    if (_settings == newSettings) return;

    _settings = newSettings;
    notifyListeners();
    await _saveSettings();
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _settings = GameSettings.defaults;
    notifyListeners();
    await _saveSettings();
  }

  // === Individual Setters ===

  Future<void> setDropDuration(int value) async {
    final clamped = value.clamp(GameSettings.minDuration, GameSettings.maxDuration);
    await updateSettings(_settings.copyWith(dropDuration: clamped));
  }

  Future<void> setMergeDuration(int value) async {
    final clamped = value.clamp(GameSettings.minDuration, GameSettings.maxDuration);
    await updateSettings(_settings.copyWith(mergeDuration: clamped));
  }

  Future<void> setMergeMoveDuration(int value) async {
    final clamped = value.clamp(GameSettings.minDuration, GameSettings.maxDuration);
    await updateSettings(_settings.copyWith(mergeMoveDuration: clamped));
  }

  Future<void> setGravityDuration(int value) async {
    final clamped = value.clamp(GameSettings.minDuration, GameSettings.maxDuration);
    await updateSettings(_settings.copyWith(gravityDuration: clamped));
  }

  Future<void> setEasingType(EasingType value) async {
    await updateSettings(_settings.copyWith(easingType: value));
  }

  Future<void> setMergeAnimation(MergeAnimationType value) async {
    await updateSettings(_settings.copyWith(mergeAnimation: value));
  }

  Future<void> setBlockTheme(BlockTheme value) async {
    await updateSettings(_settings.copyWith(blockTheme: value));
  }

  Future<void> setAllowDropDuringMerge(bool value) async {
    await updateSettings(_settings.copyWith(allowDropDuringMerge: value));
  }

  Future<void> setShowGhostBlock(bool value) async {
    await updateSettings(_settings.copyWith(showGhostBlock: value));
  }

  Future<void> setScreenShakeEnabled(bool value) async {
    await updateSettings(_settings.copyWith(screenShakeEnabled: value));
  }
}
