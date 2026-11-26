import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات كل مرحلة. كل مرحلة تضيف شي جديد حتى ما تتشابه
class LevelCfg {
  final String title;
  final String tip;
  final double duration; // ثواني
  final double spawn; // كل كم ثانية ينطفي بيت
  final double darkTimeout; // وكت قبل ما يزعل صاحب البيت
  final double fuelDrain; // كم ينقص الكاز بالثانية (0 = ماكو)
  final double thiefEvery; // كل كم ثانية يجي حرامي (0 = ماكو)
  final int cars; // عدد السيارات بالشوارع
  final bool night; // ليل: الضوء بس حوالين اللاعب والبيوت
  final List<double> storms; // بأي ثانية من المرحلة تجي عاصفة
  final List<double> overloads; // بأي ثانية المولدة تسخن
  final List<int> stars; // نقاط النجمة 1 و2 و3
  const LevelCfg({
    required this.title,
    required this.tip,
    required this.duration,
    required this.spawn,
    required this.darkTimeout,
    this.fuelDrain = 0,
    this.thiefEvery = 0,
    this.cars = 0,
    this.night = false,
    this.storms = const [],
    this.overloads = const [],
    required this.stars,
  });
}

const levels = <LevelCfg>[
  LevelCfg(
      title: 'أول يوم شغل', tip: '⚡ اركض للبيت الطافي ورجّعله الكهرباء', duration: 45, spawn: 3.0, darkTimeout: 11, stars: [500, 900, 1300]),
  LevelCfg(
      title: 'شارع الزحمة',
      tip: '🚗 دير بالك من السيارات! إذا ضربتك تطيح',
      duration: 50,
      spawn: 2.8,
      darkTimeout: 10,
      cars: 7,
      stars: [700, 1200, 1700]),
  LevelCfg(
      title: 'الكاز خلصان',
      tip: '⛽ لمّ جليكانات الكاز حتى المولدة ما توكف',
      duration: 55,
      spawn: 2.7,
      darkTimeout: 10,
      fuelDrain: 0.03,
      cars: 6,
      stars: [900, 1500, 2100]),
  LevelCfg(
      title: 'الحرامي!',
      tip: '🦹 الحرامي يگص الواير ويهرب.. الحگه قبل ما يطلع',
      duration: 55,
      spawn: 3.0,
      darkTimeout: 10,
      fuelDrain: 0.025,
      thiefEvery: 11,
      cars: 5,
      stars: [1000, 1700, 2400]),
  LevelCfg(
      title: 'الليل',
      tip: '🌙 الدنيا ظلمة.. البيت الطافي ما يبين إلا بالسهم',
      duration: 60,
      spawn: 2.7,
      darkTimeout: 10,
      fuelDrain: 0.03,
      thiefEvery: 13,
      cars: 6,
      night: true,
      stars: [1100, 1800, 2600]),
  LevelCfg(
      title: 'العاصفة',
      tip: '⛈️ عاصفة راح تطفي نص الحي مرة وحدة!',
      duration: 60,
      spawn: 3.0,
      darkTimeout: 11,
      fuelDrain: 0.03,
      cars: 6,
      storms: [18, 40],
      stars: [1300, 2100, 2900]),
  LevelCfg(
      title: 'حمل زائد',
      tip: '🔥 إذا المولدة سخنت اركضلها واضغط بسرعة قبل ما تنفجر',
      duration: 60,
      spawn: 2.8,
      darkTimeout: 10,
      fuelDrain: 0.03,
      thiefEvery: 15,
      cars: 6,
      overloads: [15, 40],
      stars: [1300, 2100, 3000]),
  LevelCfg(
      title: 'ساعة الذروة',
      tip: '🚕 سيارات هوايه وحرامية.. ركّز!',
      duration: 65,
      spawn: 2.4,
      darkTimeout: 9.5,
      fuelDrain: 0.035,
      thiefEvery: 9,
      cars: 13,
      stars: [1500, 2500, 3500]),
  LevelCfg(
      title: 'ليلة العاصفة',
      tip: '🌙⛈️ ليل وعاصفة وحمل زائد',
      duration: 70,
      spawn: 2.5,
      darkTimeout: 10,
      fuelDrain: 0.035,
      thiefEvery: 11,
      cars: 8,
      night: true,
      storms: [22],
      overloads: [45],
      stars: [1700, 2800, 3900]),
  LevelCfg(
      title: 'الامتحان الأخير',
      tip: '👑 كلشي مرة وحدة.. ورّينا شطارتك',
      duration: 75,
      spawn: 2.2,
      darkTimeout: 9.5,
      fuelDrain: 0.04,
      thiefEvery: 8,
      cars: 12,
      night: true,
      storms: [20, 52],
      overloads: [36, 62],
      stars: [2000, 3300, 4600]),
];

class House {
  final Rect rect;
  final int style;
  bool lit = true;
  double dark = 0; // العد التنازلي إذا طافي
  double flash = 0; // وميض بعد التصليح
  double angry = 0; // وجه زعلان بعد ما فات الوكت
  House(this.rect, this.style);
  Offset get center => rect.center;
}

/// حالة الحرامي: رايح للبيت، يگص، هارب
enum ThiefState { going, cutting, fleeing }

class Thief {
  Offset pos;
  final int target;
  ThiefState state = ThiefState.going;
  List<Offset> path = [];
  double cut = 0;
  Offset dir = const Offset(1, 0);
  Thief(this.pos, this.target);
  bool get leaving => state == ThiefState.fleeing;
}

class Car {
  Offset pos;
  final Offset dir; // واحد من الأربع اتجاهات
  final double speed;
  final int kind; // 0 تكسي، 1 حمرة، 2 خضرة
  double honk = 0;
  bool stopped = false;
  Car(this.pos, this.dir, this.speed, this.kind);
  bool get vertical => dir.dx == 0;
  Rect get rect => vertical ? Rect.fromCenter(center: pos, width: 0.7, height: 0.95) : Rect.fromCenter(center: pos, width: 0.95, height: 0.7);
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

/// كل منطق اللعبة. المدينة 16 × 24 مربع، والإحداثيات بالمربعات
class ArcadeWorld extends ChangeNotifier {
  static const double w = 16, h = 24;
  static const double speed = 5.0; // مربع بالثانية
  static const double radius = 0.3;
  static const Rect generator = Rect.fromLTWH(5.3, 9.2, 1.4, 1.2);
  static const Rect plaza = Rect.fromLTWH(4.8, 8.8, 2.4, 2.2);
  static const Offset startPos = Offset(6.0, 11.9);

  /// خطوط نص الشوارع (للسيارات والحرامية)
  static const roadXs = [0.4, 4.0, 8.0, 12.0, 15.6];
  static const roadYs = [0.4, 3.9, 7.9, 11.9, 15.9, 19.9, 23.5];

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
  double stun = 0, invuln = 0; // بعد ما تضربك سيارة
  Offset player = startPos;
  Offset move = Offset.zero; // من عصا التحكم (-1..1)
  double face = pi / 2; // زاوية
  late List<House> houses;
  final List<Thief> thieves = [];
  final List<Car> cars = [];
  final List<Pickup> pickups = [];
  final List<Particle> particles = [];
  final List<FloatText> floats = [];
  int lastStars = 0;
  bool newBest = false;

  // الأحداث المفاجئة
  int _nextStorm = 0, _nextOverload = 0;
  double stormT = 0, lightning = 0;
  bool overloadOn = false;
  double heat = 0;
  bool nearGenerator = false;
  String banner = '';
  double bannerT = 0;

  ArcadeWorld() {
    houses = _buildHouses();
    _spawnCars(8); // سيارات تمشي ورا القائمة
  }

  List<House> _buildHouses() {
    final out = <House>[];
    var k = 0;
    for (var j = 0; j < 6; j++) {
      for (var i = 0; i < 4; i++) {
        final r = Rect.fromLTWH(0.8 + i * 4.0, 0.8 + j * 4.0, 2.4, 2.2);
        k++;
        if (r.overlaps(plaza)) continue; // مكان المولدة
        out.add(House(r, k));
      }
    }
    return out;
  }

  double get elapsed => cfg.duration - timeLeft;

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
    cars.clear();
    player = startPos;
    move = Offset.zero;
    face = pi / 2;
    timeLeft = cfg.duration;
    score = 0;
    hearts = 3;
    combo = 1;
    fixes = 0;
    caught = 0;
    comboTimer = 0;
    spawnTimer = 1.0;
    thiefTimer = cfg.thiefEvery > 0 ? cfg.thiefEvery * 0.5 : 0;
    canTimer = 4;
    boostTimer = 0;
    boostSpawn = 12;
    fuel = 1;
    shake = 0;
    stun = 0;
    invuln = 0;
    hintTime = lv == 0 ? 8 : 0;
    _nextStorm = 0;
    _nextOverload = 0;
    stormT = 0;
    lightning = 0;
    overloadOn = false;
    heat = 0;
    nearGenerator = false;
    banner = '';
    bannerT = 0;
    _spawnCars(cfg.cars);
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
    overloadOn = false;
    nearGenerator = false;
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

  void _say(String text) {
    banner = text;
    bannerT = 2.5;
    notifyListeners();
  }

  // ---------- الإدخال ----------
  void setMove(Offset v) => move = v;

  /// ضغطة على زر التبريد وقت الحمل الزائد
  void tapCool() {
    if (!overloadOn || !nearGenerator || phase != Phase.playing) return;
    heat -= 0.075;
    sfx('pump');
    for (var k = 0; k < 4; k++) {
      final a = _rnd.nextDouble() * 2 * pi;
      particles.add(Particle(generator.center, Offset(cos(a), sin(a)) * 2.5, 0xFF80D8FF, 0.4, 0.07));
    }
    if (heat <= 0) {
      overloadOn = false;
      heat = 0;
      score += 250;
      floats.add(FloatText(generator.center, '❄️ +250', 0xFF80D8FF));
      sfx('win');
      _say('✅ بردت المولدة!');
    }
  }

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
    if (lightning > 0) lightning = max(0, lightning - dt * 3);
    if (bannerT > 0) {
      bannerT -= dt;
      if (bannerT <= 0) notifyListeners();
    }
    // السيارات تمشي حتى بالعد التنازلي
    if (phase == Phase.menu || phase == Phase.countdown || phase == Phase.playing) _updateCars(dt);

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

    if (stun > 0) stun -= dt;
    if (invuln > 0) invuln -= dt;
    _movePlayer(dt);
    _carHits();
    _updateHouses(dt);
    if (phase != Phase.playing) return;
    _updateFuel(dt);
    _updateThieves(dt);
    _updatePickups(dt);
    _updateEvents(dt);
    if (phase != Phase.playing) return;

    final near = _distToRect(player, generator) < 1.3;
    if (near != nearGenerator) {
      nearGenerator = near;
      notifyListeners();
    }

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
    if (stun > 0) return;
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

  // ---------- السيارات ----------
  void _spawnCars(int n) {
    var tries = 0;
    while (cars.length < n && tries < 200) {
      tries++;
      final vertical = _rnd.nextBool();
      final forward = _rnd.nextBool();
      final kind = _rnd.nextInt(3);
      final sp = 2.6 + _rnd.nextDouble() * 1.6;
      Car c;
      if (vertical) {
        final x = roadXs[1 + _rnd.nextInt(3)] + (forward ? -0.42 : 0.42);
        c = Car(Offset(x, _rnd.nextDouble() * h), Offset(0, forward ? 1 : -1), sp, kind);
      } else {
        final y = roadYs[1 + _rnd.nextInt(5)] + (forward ? 0.42 : -0.42);
        c = Car(Offset(_rnd.nextDouble() * w, y), Offset(forward ? 1 : -1, 0), sp, kind);
      }
      if ((c.pos - startPos).distance < 3) continue;
      if (cars.any((o) => o.rect.inflate(0.4).overlaps(c.rect))) continue;
      cars.add(c);
    }
  }

  void _updateCars(double dt) {
    for (final c in cars) {
      // توكف إذا اكو سيارة گدامها. العمودية تنطي مجال للأفقية حتى ما يصير تصادم بالتقاطع
      final ahead = c.rect.shift(c.dir * 0.9);
      var blocked = false;
      for (final o in cars) {
        if (identical(o, c)) continue;
        if (!c.vertical && o.vertical) continue;
        if (o.rect.overlaps(ahead)) {
          blocked = true;
          break;
        }
      }
      c.stopped = blocked;
      if (!blocked) c.pos += c.dir * c.speed * dt;
      // تلف من الجهة الثانية
      if (c.pos.dx < -1.5) c.pos = Offset(w + 1.5, c.pos.dy);
      if (c.pos.dx > w + 1.5) c.pos = Offset(-1.5, c.pos.dy);
      if (c.pos.dy < -1.5) c.pos = Offset(c.pos.dx, h + 1.5);
      if (c.pos.dy > h + 1.5) c.pos = Offset(c.pos.dx, -1.5);
      if (c.honk > 0) c.honk -= dt;
    }
  }

  void _carHits() {
    for (final c in cars) {
      final r = c.rect.inflate(radius * 0.6);
      // تزمّر إذا انت گدامها
      if (c.honk <= 0 && r.shift(c.dir * 1.6).contains(player)) {
        c.honk = 2.5;
        sfx('honk');
      }
      if (invuln > 0) continue;
      if (r.contains(player)) {
        stun = 0.9;
        invuln = 2.2;
        shake = 1.2;
        final lost = min(score, 50);
        score -= lost;
        combo = 1;
        sfx('honk');
        floats.add(FloatText(player, '💥 -$lost', 0xFFFF5252));
        for (var k = 0; k < 12; k++) {
          final a = _rnd.nextDouble() * 2 * pi;
          particles.add(Particle(player, Offset(cos(a), sin(a)) * 3, 0xFFFFFFFF, 0.4, 0.06));
        }
        // تطيرك شوية لجهة السيارة
        final side = c.vertical ? Offset(player.dx < c.pos.dx ? -1 : 1, 0) : Offset(0, player.dy < c.pos.dy ? -1 : 1);
        for (var k = 0; k < 8; k++) {
          final n = player + side * 0.12 + c.dir * 0.06;
          if (!_hitsSolid(n)) player = n;
        }
        notifyListeners();
        return;
      }
    }
  }

  // ---------- البيوت ----------
  void _updateHouses(double dt) {
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
      if (_distToRect(player, hs.rect) < radius + 0.3) {
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
        _loseHeart(hs.center, '💔');
        if (phase != Phase.playing) return;
      }
    }
  }

  void _loseHeart(Offset at, String icon) {
    hearts--;
    combo = 1;
    shake = 1;
    sfx('miss');
    floats.add(FloatText(at, icon, 0xFFFF5252));
    notifyListeners();
    if (hearts <= 0) _end(false);
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
    comboTimer = 4.0;
    sfx('coin');
    for (var k = 0; k < 14; k++) {
      final a = _rnd.nextDouble() * 2 * pi;
      final s = 1.5 + _rnd.nextDouble() * 3;
      particles.add(Particle(hs.center, Offset(cos(a), sin(a)) * s, k.isEven ? 0xFFFFD54F : 0xFFFFF59D, 0.6, 0.07));
    }
    notifyListeners();
  }

  /// نقطة عشوائية على شارع
  Offset _randomStreetPoint() {
    for (var tries = 0; tries < 60; tries++) {
      Offset p;
      if (_rnd.nextBool()) {
        p = Offset(1 + _rnd.nextDouble() * (w - 2), roadYs[1 + _rnd.nextInt(5)]);
      } else {
        p = Offset(roadXs[1 + _rnd.nextInt(3)], 1 + _rnd.nextDouble() * (h - 2));
      }
      final d = (p - player).distance;
      if (!_hitsSolid(p) && d > 2.0 && d < 11) return p;
    }
    return const Offset(8.0, 11.9);
  }

  void _updateFuel(double dt) {
    if (cfg.fuelDrain <= 0) return;
    final wasOn = fuel > 0;
    fuel = max(0, fuel - cfg.fuelDrain * dt);
    if (wasOn && fuel <= 0) {
      sfx('alarm');
      _say('⛽ خلص الكاز! لمّ جليكان');
    }
    canTimer -= dt * (fuel < 0.35 ? 1.8 : 1);
    if (canTimer <= 0) {
      canTimer = 5 + _rnd.nextDouble() * 3;
      if (pickups.where((p) => p.kind == 0).length < 2) pickups.add(Pickup(_randomStreetPoint(), 0, 12));
    }
  }

  void _updatePickups(double dt) {
    boostSpawn -= dt;
    if (boostSpawn <= 0) {
      boostSpawn = 14 + _rnd.nextDouble() * 8;
      pickups.add(Pickup(_randomStreetPoint(), 1, 10));
    }
    for (final p in List.of(pickups)) {
      p.life -= dt;
      if (p.life <= 0) {
        pickups.remove(p);
        continue;
      }
      if ((p.pos - player).distance < 0.6) {
        pickups.remove(p);
        if (p.kind == 0) {
          fuel = min(1, fuel + 0.45);
          score += 30;
          sfx('pump');
          floats.add(FloatText(p.pos, '⛽ +30', 0xFFFFB300));
        } else {
          boostTimer = 6;
          sfx('goal');
          floats.add(FloatText(p.pos, '🛵 سرعة!', 0xFF80D8FF));
        }
        notifyListeners();
      }
    }
  }

  // ---------- الحرامية ----------
  double _nearestRoadY(double y) {
    var best = roadYs[0];
    for (final r in roadYs) {
      if ((r - y).abs() < (best - y).abs()) best = r;
    }
    return best;
  }

  /// طريق على الشوارع: من نقطة على شارع أفقي لنقطة على شارع أفقي ثاني
  List<Offset> _route(Offset from, double y1, double toX, double y2) {
    if ((y1 - y2).abs() < 0.01) return [Offset(toX, y1)];
    var bestX = roadXs[1];
    var bd = 1e9;
    for (final x in roadXs) {
      final d = (from.dx - x).abs() + (toX - x).abs();
      if (d < bd) {
        bd = d;
        bestX = x;
      }
    }
    return [Offset(bestX, y1), Offset(bestX, y2), Offset(toX, y2)];
  }

  Offset _doorOf(Rect r) => Offset(r.center.dx, r.bottom + 0.35);

  void _updateThieves(double dt) {
    if (cfg.thiefEvery > 0) {
      thiefTimer -= dt;
      if (thiefTimer <= 0 && thieves.length < 2) {
        thiefTimer = cfg.thiefEvery * (0.8 + _rnd.nextDouble() * 0.4);
        final targets = [for (var i = 0; i < houses.length; i++) if (houses[i].lit) i];
        if (targets.isNotEmpty) {
          final ti = targets[_rnd.nextInt(targets.length)];
          final y = roadYs[1 + _rnd.nextInt(5)];
          final from = Offset(_rnd.nextBool() ? -0.8 : w + 0.8, y);
          final t = Thief(from, ti);
          final door = _doorOf(houses[ti].rect);
          final dy = _nearestRoadY(door.dy + 0.5);
          t.path = [..._route(from, y, door.dx, dy), door];
          thieves.add(t);
          sfx('whistle');
          _say('🦹 حرامي دخل الحي!');
        }
      }
    }
    for (final t in List.of(thieves)) {
      if (t.state == ThiefState.cutting) {
        t.cut -= dt;
        if (t.cut <= 0) {
          final hs = houses[t.target];
          if (hs.lit) _goDark(t.target);
          hs.dark = cfg.darkTimeout;
          floats.add(FloatText(hs.center, '✂️', 0xFFFF5252));
          // يهرب لأقرب طرف
          final ry = _nearestRoadY(t.pos.dy + 0.5);
          final exitX = t.pos.dx < w / 2 ? -1.2 : w + 1.2;
          t.path = [Offset(t.pos.dx, ry), Offset(exitX, ry)];
          t.state = ThiefState.fleeing;
          _say('🏃 الحرامي هارب! الحگه');
        }
      } else if (t.path.isNotEmpty) {
        final goal = t.path.first;
        final d = goal - t.pos;
        final len = d.distance;
        final sp = (t.state == ThiefState.fleeing ? 3.7 : 2.3) * dt;
        if (len <= sp) {
          t.pos = goal;
          t.path.removeAt(0);
        } else {
          t.dir = d / len;
          t.pos += t.dir * sp;
        }
        if (t.path.isEmpty) {
          if (t.state == ThiefState.going) {
            t.state = ThiefState.cutting;
            t.cut = 1.3;
            t.dir = const Offset(0, -1);
          } else {
            // هرب
            thieves.remove(t);
            final lost = min(score, 100);
            score -= lost;
            sfx('miss');
            floats.add(FloatText(Offset(t.pos.dx.clamp(1.0, w - 1).toDouble(), t.pos.dy), '🦹 هرب! -$lost', 0xFFFF5252));
            notifyListeners();
            continue;
          }
        }
      }
      // اللاعب لزمه
      if ((t.pos - player).distance < 0.65) {
        thieves.remove(t);
        caught++;
        final pts = t.state == ThiefState.fleeing ? 300 : 150;
        score += pts;
        sfx('goal');
        shake = 0.6;
        floats.add(FloatText(t.pos, '👮 +$pts', 0xFF69F0AE));
        for (var k = 0; k < 16; k++) {
          final a = _rnd.nextDouble() * 2 * pi;
          particles.add(Particle(t.pos, Offset(cos(a), sin(a)) * 3, 0xFF69F0AE, 0.5, 0.06));
        }
        notifyListeners();
      }
    }
  }

  // ---------- العاصفة والحمل الزائد ----------
  void _updateEvents(double dt) {
    if (stormT > 0) stormT -= dt;
    if (_nextStorm < cfg.storms.length && elapsed >= cfg.storms[_nextStorm]) {
      _nextStorm++;
      stormT = 6;
      lightning = 1;
      shake = 1.5;
      sfx('alarm');
      _say('⛈️ عاصفة! انطفى نص الحي');
      final litOnes = [for (var i = 0; i < houses.length; i++) if (houses[i].lit) i]..shuffle(_rnd);
      for (final i in litOnes.take(5)) {
        _goDark(i);
        houses[i].dark = cfg.darkTimeout + 3; // وكت إضافي للعاصفة
      }
    }
    if (stormT > 0 && _rnd.nextDouble() < dt * 0.6) lightning = 1;

    if (_nextOverload < cfg.overloads.length && elapsed >= cfg.overloads[_nextOverload]) {
      _nextOverload++;
      if (!overloadOn) {
        overloadOn = true;
        heat = 0.35;
        sfx('alarm');
        _say('🔥 المولدة دتسخن! اركضلها');
      }
    }
    if (overloadOn) {
      heat += dt * 0.075;
      if (_rnd.nextDouble() < dt * 6) {
        particles.add(Particle(Offset(generator.center.dx, generator.top), Offset(_rnd.nextDouble() - 0.5, -2), 0xFFFF6D00, 0.6, 0.08));
      }
      if (heat >= 1) {
        overloadOn = false;
        heat = 0;
        shake = 2;
        lightning = 0.8;
        _say('💥 المولدة انفجرت!');
        for (var k = 0; k < 30; k++) {
          final a = _rnd.nextDouble() * 2 * pi;
          particles.add(Particle(generator.center, Offset(cos(a), sin(a)) * (2 + _rnd.nextDouble() * 4), k.isEven ? 0xFFFF6D00 : 0xFFFFD54F, 0.8, 0.1));
        }
        for (var i = 0; i < houses.length; i++) {
          if (houses[i].lit && _rnd.nextDouble() < 0.5) _goDark(i);
        }
        _loseHeart(generator.center, '💥');
      }
    }
  }

  int get darkCount => houses.where((x) => !x.lit).length;
}
