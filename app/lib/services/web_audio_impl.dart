// Web implementation using dart:html
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

html.AudioElement? _bgmElement;

void playWebAudio(String path, double volume, double playbackRate) {
  try {
    // Use absolute path for web
    final absolutePath = path.startsWith('/') ? path : '/$path';
    final audio = html.AudioElement(absolutePath);
    audio.volume = volume;
    audio.playbackRate = playbackRate;
    audio.play();
  } catch (e) {
    // Ignore errors
  }
}

void playWebBGM(String path, double volume) {
  try {
    stopWebBGM();
    final absolutePath = path.startsWith('/') ? path : '/$path';
    _bgmElement = html.AudioElement(absolutePath);
    _bgmElement!.volume = volume;
    _bgmElement!.loop = true;
    _bgmElement!.play();
  } catch (e) {
    // Ignore errors
  }
}

void stopWebBGM() {
  _bgmElement?.pause();
  _bgmElement = null;
}

void pauseWebBGM() {
  _bgmElement?.pause();
}

void resumeWebBGM() {
  _bgmElement?.play();
}

void setWebBGMVolume(double volume) {
  if (_bgmElement != null) {
    _bgmElement!.volume = volume;
  }
}
