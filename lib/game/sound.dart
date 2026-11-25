import 'package:audioplayers/audioplayers.dart';

/// أصوات قصيرة: coin, win, whistle, alarm, pump, kick, goal, miss, honk
class Sfx {
  static bool enabled = true;
  static final Map<String, DateTime> _last = {};

  static void play(String name, {double volume = 0.7}) {
    if (!enabled) return;
    final now = DateTime.now();
    final prev = _last[name];
    if (prev != null && now.difference(prev).inMilliseconds < 70) return;
    _last[name] = now;
    try {
      final p = AudioPlayer();
      p.setReleaseMode(ReleaseMode.release);
      p.play(AssetSource('audio/$name.wav'), volume: volume).catchError((_) {});
      p.onPlayerComplete.listen((_) => p.dispose());
    } catch (_) {}
  }
}
