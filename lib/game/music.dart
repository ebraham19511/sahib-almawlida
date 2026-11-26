import 'package:audioplayers/audioplayers.dart';

/// موسيقى مستمرة تلف (loop): music_main و music_boss
class Music {
  static bool enabled = true;
  static final AudioPlayer _p = AudioPlayer();
  static String? _current;
  static bool _ready = false;

  static Future<void> play(String name) async {
    if (_current == name) return;
    _current = name;
    if (!enabled) return;
    await _start();
  }

  static Future<void> _start() async {
    final name = _current;
    if (name == null) return;
    try {
      if (!_ready) {
        await _p.setReleaseMode(ReleaseMode.loop);
        _ready = true;
      }
      await _p.stop();
      await _p.play(AssetSource('audio/$name.ogg'), volume: 0.45);
    } catch (_) {}
  }

  static Future<void> setEnabled(bool on) async {
    enabled = on;
    try {
      if (on) {
        await _start();
      } else {
        await _p.stop();
      }
    } catch (_) {}
  }

  static Future<void> pause() async {
    try {
      await _p.pause();
    } catch (_) {}
  }

  static Future<void> resume() async {
    if (!enabled) return;
    try {
      await _p.resume();
    } catch (_) {}
  }
}
