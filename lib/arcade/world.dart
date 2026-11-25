import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات كل مرحلة
class LevelCfg {
  final double duration; // ثواني
  final double spawn; // كل كم ثانية ينطفي بيت
  final double darkTimeout; // وكت قبل ما يزعل صاحب البيت
  final double fuelDrain; // كم ينقص الكاز بالثانية (0 = ماكو)
  final double thiefEvery; // كل كم ثانية يجي حرامي (0 = ماكو)
  final List<int> stars; // نقاط النجمة 1 و2 و3
  const LevelCfg(this.duration, this.spawn, this.darkTimeout, this.fuelDrain, this.thiefEvery, this.stars);
}

const levels = <LevelCfg>[
  LevelCfg(45, 3.2, 9.0, 0.0, 0, [600, 1000, 1500]),
  LevelCfg(50, 3.0, 8.5, 0.025, 0, [800, 1300, 1900]),
  LevelCfg(55, 2.8, 8.0, 0.03, 12, [1000, 1600, 2300]),
  LevelCfg(60, 2.6, 7.5, 0.035, 10, [1200, 1900, 2700]),
  LevelCfg(60, 2.4, 7.0, 0.04, 9, [1400, 2200, 3100]),
  LevelCfg(60, 2.2, 6.5, 0.045, 8, [1600, 2500, 3500]),
  LevelCfg(60, 2.0, 6.2, 0.05, 7, [1800, 2800, 3900]),
  LevelCfg(65, 1.9, 6.0, 0.05, 6, [2000, 3100, 4300]),
  LevelCfg(65, 1.8, 5.6, 0.055, 5.5, [2200, 3400, 4700]),
  LevelCfg(70, 1.6, 5.2, 0.06, 5, [2500, 3800, 5200]),
];

class House {
  final Rect rect;
  final int color;
  final String owner;
  bool lit = true;
  double dark = 0; // العد التنازلي إذا طافي
  double flash = 0; // وميض بعد التصليح
  double angry = 0; // وجه زعلان بعد ما فات الوكت
  House(this.rect, this.color, this.owner);
  Offset get center => rect.center;
}

class Thief {
  Offset pos;
  int target;
  bool leaving = false;
  double life = 14;
  Thief(this.pos, this.target);
}

class Pickup {
  Offset pos;
  final int kind; // 0 كاز، 1 سكوتر سرعة
  double life;
  Pickup(this.pos, this.kind, this.life);
}

class Particle {
  Offset pos, vel;
  final int color;
  double life;
  final double size;
  Particle(this.pos, this.vel, this.color, this.life, this.size);
}

class FloatText {
  final Offset pos;
  final String text;
  final int color;
  double t = 0;
  FloatText(this.pos, this.text, this.color);
}

enum Phase { menu, countdown, playing, paused, won, lost }

/// كل منطق اللعبة. الساحة 8 × 12 مربع، والإحداثيات بالمربعات
class ArcadeWorld extends ChangeNotifier {
  static const double w = 8, h = 12;
  static const double speed = 4.6; // مربع بالثانية
  static const double radius = 0.28;
  static const Rect generator = Rect.fromLTWH(3.4, 5.45, 1.2, 1.0);

  final _rnd = Random();
  void Function(String)? onSfx;
  void sfx(String n) => onSfx?.call(n);

  // التقدم
  List<int> stars = List.filled(levels.length, 0);
  List<int> best = List.filled(levels.length, 0);

  // حالة المرحلة
  Phase phase = Phase.menu;
  int level = 0;
  LevelCfg get cfg => levels[level];
  double timeLeft = 0, countdown = 0, clock = 0;
  int score = 0, hearts = 3, combo = 1, fixes = 0, caught = 0;
  double comboTimer = 0, spawnTimer = 0, thiefTimer = 0, canTimer = 0, boostTimer = 0, boostSpawn = 0;
  double fuel = 1, shake = 0, hintTime = 0;
  Offset player = const Offset(2.6, 6.0);
  Offset move = Offset.zero; // من عصا التحكم (-1..1)
  double face = 0; // زاوية
  late List<House> houses;
  final List<Thief> thieves = [];
  final List<Pickup> pickups = [];
  final List<Particle> particles = [];
  final List<FloatText> floats = [];
  int lastStars = 0;
  bool newBest = false;

  static const _owners = [
    'أبو محمد', 'أم علي', 'أبو حسين', 'جاسم', 'الأستاذ كريم', 'أم زينب',
    'أبو سجاد', 'حيدر', 'أبو مصطفى', 'الحاج عباس', 'الدكتور سعد', 'ستار',
  ];
  static const _colors = [
    0xFFE8C9A0, 0xFFD9A77A, 0xFFEDD9B5, 0xFFC99268, 0xFFE3CFAE, 0xFFD4B08A,
    0xFFF0E2C6, 0xFFB98B6A, 0xFFE0C39C, 0xFFCDA57C, 0xFFE9D6BC, 0xFFC4A07A,
  ];

  ArcadeWorld() {
    houses = _buildHouses();
  }

  List<House> _buildHouses() {
    final out = <House>[];
    const xs = [0.4, 3.2, 6.0];
    const ys = [0.5, 3.3, 7.2, 10.0];
    var k = 0;
    for (final y in ys) {
      for (final x in xs) {
        out.add(House(Rect.fromLTWH(x, y, 1.6, 1.4), _colors[k], _owners[k]));
        k++;
      }
    }
    return out;
  }

  // ---------- التقدم ----------
  Future<void> loadProgress() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getStringList('arcade_stars');
      final b = p.getStringList('arcade_best');
      if (s != null) {
        for (var i = 0; i < min(s.length, levels.length); i++) {
          stars[i] = int.tryParse(s[i]) ?? 0;
        }
      }
      if (b != null) {
        for (var i = 0; i < min(b.length, levels.length); i++) {
          best[i] = int.tryParse(b[i]) ?? 0;
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _saveProgress() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('arcade_stars', stars.map((e) => '$e').toList());
      await p.setStringList('arcade_best', best.map((e) => '$e').toList());
    } catch (_) {}
  }

  bool unlocked(int i) => i == 0 || stars[i - 1] > 0;
  int get totalStars => stars.fold(0, (a, b) => a + b);

  // ---------- بداية ونهاية ----------
  void start(int lv) {
    level = lv;
    houses = _buildHouses();
    thieves.clear();
    pickups.clear();
    particles.clear();
    floats.clear();
    player = const Offset(2.6, 6.0);
    move = Offset.zero;
    timeLeft = cfg.duration;
    score = 0;
    hearts = 3;
    combo = 1;
    fixes = 0;
    caught = 0;
    comboTimer = 0;
    spawnTimer = 1.2;
    thiefTimer = cfg.thiefEvery > 0 ? cfg.thiefEvery * 0.6 : 0;
    canTimer = 4;
    boostTimer = 0;
    boostSpawn = 14;
    fuel = 1;
    shake = 0;
    hintTime = lv == 0 ? 10 : 0;
    countdown = 3;
    phase = Phase.countdown;
    sfx('whistle');
    notifyListeners();
  }

  void pause() {
    if (phase == Phase.playing) {
      phase = Phase.paused;
      move = Offset.zero;
      notifyListeners();
    }
  }

  void resume() {
    if (phase == Phase.paused) {
      phase = Phase.playing;
      notifyListeners();
    }
  }

  void toMenu() {
    phase = Phase.menu;
    notifyListeners();
  }

  void _end(bool won) {
    move = Offset.zero;
    if (won) {
      final s = cfg.stars;
      lastStars = score >= s[2] ? 3 : (score >= s[1] ? 2 : (score >= s[0] ? 1 : 0));
      newBest = score > best[level];
      if (newBest) best[level] = score;
      if (lastStars > stars[level]) stars[level] = lastStars;
      phase = lastStars > 0 ? Phase.won : Phase.lost;
      sfx(lastStars > 0 ? 'win' : 'miss');
      _saveProgress();
    } else {
      lastStars = 0;
      newBest = false;
      phase = Phase.lost;
      sfx('miss');
    }
    notifyListeners();
  }

  // ---------- الإدخال ----------
  void setMove(Offset v) => move = v;

  // ---------- التحديث ----------
  void update(double dt) {
    clock += dt;
    // التأثيرات تمشي دائماً
    for (final p in particles) {
      p.life -= dt;
      p.pos += p.vel * dt;
      p.vel = p.vel * (1 - dt * 2.5);
    }
    particles.removeWhere((p) => p.life <= 0);
    for (final f in floats) {
      f.t += dt;
    }
    floats.removeWhere((f) => f.t > 1.2);
    if (shake > 0) shake = max(0, shake - dt * 3);

    if (phase == Phase.countdown) {
      final before = countdown.ceil();
      countdown -= dt;
      if (countdown.ceil() != before) {
        sfx(countdown <= 0 ? 'goal' : 'pump');
        notifyListeners();
      }
      if (countdown <= 0) {
        phase = Phase.playing;
        notifyListeners();
      }
      return;
    }
    if (phase != Phase.playing) return;

    final sec = timeLeft.ceil();
    timeLeft -= dt;
    if (hintTime > 0) hintTime -= dt;
    if (timeLeft <= 0) {
      timeLeft = 0;
      _end(true);
      return;
    }

    _movePlayer(dt);
    _updateHouses(dt);
    _updateFuel(dt);
    _updateThieves(dt);
    _updatePickups(dt);

    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) combo = 1;
    }
    if (boostTimer > 0) boostTimer -= dt;
    if (timeLeft.ceil() != sec) notifyListeners();
  }

  bool _hitsSolid(Offset p) {
    if (p.dx < radius || p.dx > w - radius || p.dy < radius || p.dy > h - radius) return true;
    bool inRect(Rect r) =>
        p.dx > r.left - radius && p.dx < r.right + radius && p.dy > r.top - radius && p.dy < r.bottom + radius;
    for (final hs in houses) {
      if (inRect(hs.rect)) return true;
    }
    return inRect(generator);
  }

  void _movePlayer(double dt) {
    final len = move.distance;
    if (len < 0.05) return;
    final dir = move / len;
    face = atan2(dir.dy, dir.dx);
    final sp = speed * min(1.0, len) * (boostTimer > 0 ? 1.6 : 1) * dt;
    // نتحرك بخطوات صغيرة ونتزحلق على الحيطان حتى ما ننحصر
    const steps = 3;
    for (var i = 0; i < steps; i++) {
      final dx = Offset(dir.dx * sp / steps, 0), dy = Offset(0, dir.dy * sp / steps);
      if (!_hitsSolid(player + dx)) player += dx;
      if (!_hitsSolid(player + dy)) player += dy;
    }
    if (boostTimer > 0 && _rnd.nextDouble() < 0.5) {
      particles.add(Particle(player, Offset(-dir.dx, -dir.dy) * 1.5, 0xFF80D8FF, 0.35, 0.06));
    }
  }

  double _distToRect(Offset p, Rect r) {
    final dx = max(max(r.left - p.dx, 0.0), p.dx - r.right);
    final dy = max(max(r.top - p.dy, 0.0), p.dy - r.bottom);
    return sqrt(dx * dx + dy * dy);
  }

  bool get generatorOn => cfg.fuelDrain == 0 || fuel > 0;

  void _updateHouses(double dt) {
    // بيت جديد ينطفي
    spawnTimer -= dt * (generatorOn ? 1 : 1.8);
    if (spawnTimer <= 0) {
      spawnTimer = cfg.spawn * (0.75 + _rnd.nextDouble() * 0.5);
      final litOnes = [for (var i = 0; i < houses.length; i++) if (houses[i].lit) i];
      if (litOnes.isNotEmpty) _goDark(litOnes[_rnd.nextInt(litOnes.length)]);
    }
    for (var i = 0; i < houses.length; i++) {
      final hs = houses[i];
      if (hs.flash > 0) hs.flash -= dt;
      if (hs.angry > 0) hs.angry -= dt;
      if (hs.lit) continue;
      hs.dark -= dt;
      // اللاعب وصل للبيت: يرجّع الكهرباء (إذا المولدة شغالة)
      if (_distToRect(player, hs.rect) < radius + 0.25) {
        if (generatorOn) {
          _fix(i);
          continue;
        } else if (_rnd.nextDouble() < dt * 2) {
          floats.add(FloatText(hs.center, '⛽ الكاز!', 0xFFFF5252));
        }
      }
      if (hs.dark <= 0) {
        hs.lit = true;
        hs.angry = 2.5;
        hearts--;
        combo = 1;
        shake = 1;
        sfx('miss');
        floats.add(FloatText(hs.center, '💔', 0xFFFF5252));
        notifyListeners();
        if (hearts <= 0) {
          _end(false);
          return;
        }
      }
    }
  }

  void _goDark(int i) {
    final hs = houses[i];
    if (!hs.lit) return;
    hs.lit = false;
    hs.dark = cfg.darkTimeout;
    sfx('alarm');
    for (var k = 0; k < 8; k++) {
      final a = _rnd.nextDouble() * 2 * pi;
      particles.add(Particle(hs.center, Offset(cos(a), sin(a)) * 2, 0xFFFFEB3B, 0.4, 0.05));
    }
  }

  void _fix(int i) {
    final hs = houses[i];
    hs.lit = true;
    hs.flash = 0.6;
    fixes++;
    final quick = hs.dark > cfg.darkTimeout * 0.5;
    final pts = 100 * combo + (quick ? 50 : 0);
    score += pts;
    floats.add(FloatText(hs.center, combo > 1 ? '+$pts ×$combo' : '+$pts', quick ? 0xFF69F0AE : 0xFFFFD54F));
    combo = min(5, combo + 1);
    comboTimer = 3.5;
    sfx('coin');
    for (var k = 0; k < 14; k++) {
      final a = _rnd.nextDouble() * 2 * pi;
      final s = 1.5 + _rnd.nextDouble() * 3;
      particles.add(Particle(hs.center, Offset(cos(a), sin(a)) * s, k.isEven ? 0xFFFFD54F : 0xFFFFF59D, 0.6, 0.07));
    }
    notifyListeners();
  }

  Offset _randomStreetPoint() {
    for (var tries = 0; tries < 40; tries++) {
      final p = Offset(0.5 + _rnd.nextDouble() * (w - 1), 0.5 + _rnd.nextDouble() * (h - 1));
      if (!_hitsSolid(p) && (p - player).distance > 1.5) return p;
    }
    return const Offset(1.0, 6.0);
  }

  void _updateFuel(double dt) {
    if (cfg.fuelDrain <= 0) return;
    final wasOn = fuel > 0;
    fuel = max(0, fuel - cfg.fuelDrain * dt);
    if (wasOn && fuel <= 0) {
      sfx('alarm');
      floats.add(FloatText(generator.center, '⛽ خلص الكاز!', 0xFFFF5252));
      notifyListeners();
    }
    canTimer -= dt * (fuel < 0.35 ? 1.8 : 1);
    if (canTimer <= 0) {
      canTimer = 5 + _rnd.nextDouble() * 3;
      if (pickups.where((p) => p.kind == 0).length < 2) pickups.add(Pickup(_randomStreetPoint(), 0, 10));
    }
  }

  void _updatePickups(double dt) {
    boostSpawn -= dt;
    if (boostSpawn <= 0) {
      boostSpawn = 16 + _rnd.nextDouble() * 8;
      pickups.add(Pickup(_randomStreetPoint(), 1, 8));
    }
    for (final p in List.of(pickups)) {
      p.life -= dt;
      if (p.life <= 0) {
        pickups.remove(p);
        continue;
      }
      if ((p.pos - player).distance < 0.55) {
        pickups.remove(p);
        if (p.kind == 0) {
          fuel = min(1, fuel + 0.4);
          score += 30;
          sfx('pump');
          floats.add(FloatText(p.pos, '⛽ +30', 0xFFFFB300));
        } else {
          boostTimer = 5;
          sfx('goal');
          floats.add(FloatText(p.pos, '🛵 سرعة!', 0xFF80D8FF));
        }
        notifyListeners();
      }
    }
  }

  void _updateThieves(double dt) {
    if (cfg.thiefEvery > 0) {
      thiefTimer -= dt;
      if (thiefTimer <= 0) {
        thiefTimer = cfg.thiefEvery * (0.8 + _rnd.nextDouble() * 0.4);
        final targets = [for (var i = 0; i < houses.length; i++) if (houses[i].lit) i];
        if (targets.isNotEmpty) {
          const edges = [Offset(0.3, 2.6), Offset(7.7, 2.6), Offset(0.3, 6.0), Offset(7.7, 6.0), Offset(0.3, 9.3), Offset(7.7, 9.3)];
          thieves.add(Thief(edges[_rnd.nextInt(edges.length)], targets[_rnd.nextInt(targets.length)]));
          sfx('whistle');
        }
      }
    }
    for (final t in List.of(thieves)) {
      t.life -= dt;
      if (t.life <= 0) t.leaving = true;
      final goal = t.leaving ? const Offset(-1, 6) : _doorOf(houses[t.target].rect);
      final d = goal - t.pos;
      final len = d.distance;
      if (len > 0.05) {
        final step = d / len * (t.leaving ? 3.0 : 1.7) * dt;
        final nx = t.pos + Offset(step.dx, 0), ny = t.pos + Offset(0, step.dy);
        if (t.leaving || !_hitsSolidLoose(nx)) t.pos = nx;
        if (t.leaving || !_hitsSolidLoose(ny)) t.pos = ny;
      }
      if (!t.leaving && len < 0.3) {
        _goDark(t.target);
        houses[t.target].dark = cfg.darkTimeout;
        floats.add(FloatText(houses[t.target].center, '✂️', 0xFFFF5252));
        t.leaving = true;
      }
      if (t.leaving && t.pos.dx < -0.5) {
        thieves.remove(t);
        continue;
      }
      // اللاعب لزمه
      if ((t.pos - player).distance < 0.5) {
        thieves.remove(t);
        caught++;
        score += 150;
        sfx('goal');
        shake = 0.5;
        floats.add(FloatText(t.pos, '👮 +150', 0xFF69F0AE));
        for (var k = 0; k < 16; k++) {
          final a = _rnd.nextDouble() * 2 * pi;
          particles.add(Particle(t.pos, Offset(cos(a), sin(a)) * 3, 0xFF69F0AE, 0.5, 0.06));
        }
        notifyListeners();
      }
    }
  }

  bool _hitsSolidLoose(Offset p) {
    for (final hs in houses) {
      if (hs.rect.deflate(0.05).contains(p)) return true;
    }
    return generator.contains(p);
  }

  /// نقطة الباب: نص الحافة اللي تطل على أقرب شارع
  Offset _doorOf(Rect r) => Offset(r.center.dx, r.bottom + 0.2);

  int get darkCount => houses.where((x) => !x.lit).length;
}
