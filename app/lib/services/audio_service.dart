import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';
import 'web_audio_stub.dart' if (dart.library.html) 'web_audio_impl.dart' as web_audio;

/// Service for playing game sounds
class AudioService {
  // Use WAV for web (best compatibility), MP3 for mobile
  static String get _audioExt => kIsWeb ? 'wav' : 'mp3';
  static AudioService? _instance;
  static AudioService get instance {
    _instance ??= AudioService._();
    return _instance!;
  }

  AudioService._();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();

  bool _sfxEnabled = true;
  bool _bgmEnabled = true;
  double _sfxVolume = 1.0;
  double _bgmVolume = 0.5;

  // Getters
  bool get sfxEnabled => _sfxEnabled;
  bool get bgmEnabled => _bgmEnabled;
  double get sfxVolume => _sfxVolume;
  double get bgmVolume => _bgmVolume;

  /// Initialize audio service
  Future<void> init() async {
    if (!kIsWeb) {
      await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    }
  }

  /// Play drop sound effect (fire and forget for instant playback)
  void playDrop() {
    if (!_sfxEnabled) return;
    _playSound('drop.$_audioExt');
  }

  /// Play merge sound effect
  void playMerge() {
    if (!_sfxEnabled) return;
    _playSound('merge.$_audioExt');
  }

  /// Play combo sound effect with increasing pitch
  void playCombo(int comboCount) {
    if (!_sfxEnabled) return;
    // Higher combo = higher pitch (1.0 base, +0.15 per combo, max 2.0)
    final pitch = (1.0 + (comboCount - 1) * 0.15).clamp(1.0, 2.0);
    _playSoundWithPitch('combo.$_audioExt', pitch);
  }

  /// Play high value block created sound
  void playHighValue() {
    if (!_sfxEnabled) return;
    _playSound('high_value.$_audioExt');
  }

  /// Play game over sound
  void playGameOver() {
    if (!_sfxEnabled) return;
    _playSound('game_over.$_audioExt');
  }

  /// Play button click sound
  void playClick() {
    if (!_sfxEnabled) return;
    _playSound('click.$_audioExt');
  }

  /// Play coin sound
  void playCoin() {
    if (!_sfxEnabled) return;
    _playSound('coin.$_audioExt');
  }

  /// Play background music
  Future<void> playBGM() async {
    if (!_bgmEnabled) return;
    if (kIsWeb) {
      web_audio.playWebBGM('assets/audio/bgm.$_audioExt', _bgmVolume);
    } else {
      try {
        await _bgmPlayer.setVolume(_bgmVolume);
        await _bgmPlayer.play(_getAudioSource('bgm.$_audioExt'));
      } catch (e) {
        // Audio file might not exist yet
      }
    }
  }

  /// Stop background music
  Future<void> stopBGM() async {
    if (kIsWeb) {
      web_audio.stopWebBGM();
    } else {
      await _bgmPlayer.stop();
    }
  }

  /// Pause background music
  Future<void> pauseBGM() async {
    if (kIsWeb) {
      web_audio.pauseWebBGM();
    } else {
      await _bgmPlayer.pause();
    }
  }

  /// Resume background music
  Future<void> resumeBGM() async {
    if (_bgmEnabled) {
      if (kIsWeb) {
        web_audio.resumeWebBGM();
      } else {
        await _bgmPlayer.resume();
      }
    }
  }

  /// Toggle sound effects
  void toggleSFX() {
    _sfxEnabled = !_sfxEnabled;
  }

  /// Toggle background music
  void toggleBGM() {
    _bgmEnabled = !_bgmEnabled;
    if (!_bgmEnabled) {
      stopBGM();
    } else {
      playBGM();
    }
  }

  /// Set SFX enabled state
  void setSFXEnabled(bool enabled) {
    _sfxEnabled = enabled;
  }

  /// Set BGM enabled state
  void setBGMEnabled(bool enabled) {
    _bgmEnabled = enabled;
    if (!_bgmEnabled) {
      stopBGM();
    } else {
      // Auto-play BGM when enabled
      playBGM();
    }
  }

  /// Set SFX volume
  void setSFXVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
  }

  /// Set BGM volume
  void setBGMVolume(double volume) {
    _bgmVolume = volume.clamp(0.0, 1.0);
    if (kIsWeb) {
      web_audio.setWebBGMVolume(_bgmVolume);
    } else {
      _bgmPlayer.setVolume(_bgmVolume);
    }
  }

  Source _getAudioSource(String filename) {
    if (kIsWeb) {
      // Web: use UrlSource with relative path to web/assets/audio/
      return UrlSource('assets/audio/$filename');
    } else {
      // Mobile: use AssetSource from Flutter assets
      return AssetSource('audio/$filename');
    }
  }

  Future<void> _playSound(String filename) async {
    if (kIsWeb) {
      web_audio.playWebAudio('assets/audio/$filename', _sfxVolume, 1.0);
    } else {
      try {
        await _sfxPlayer.setVolume(_sfxVolume);
        await _sfxPlayer.setPlaybackRate(1.0);
        await _sfxPlayer.play(_getAudioSource(filename));
      } catch (e) {
        // Audio file might not exist yet
      }
    }
  }

  Future<void> _playSoundWithPitch(String filename, double pitch) async {
    if (kIsWeb) {
      web_audio.playWebAudio('assets/audio/$filename', _sfxVolume, pitch);
    } else {
      try {
        await _sfxPlayer.setVolume(_sfxVolume);
        await _sfxPlayer.setPlaybackRate(pitch);
        await _sfxPlayer.play(_getAudioSource(filename));
      } catch (e) {
        // Audio file might not exist yet
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _sfxPlayer.dispose();
    _bgmPlayer.dispose();
  }
}
