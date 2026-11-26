import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress.dart';

/// إعدادات كل مرحلة. 40 مرحلة، كل وحدة أصعب من اللي قبلها
class LevelCfg {
  final String title;
  final String tip;
  final double duration; // ثواني
  final double spawn; // كل كم ثانية ينطفي بيت
  final double darkTimeout; // وكت قبل ما يزعل صاحب البيت
  final double fuelDrain; // كم ينقص الكاز بالثانية (0 = ماكو)
  final double thiefEvery; // كل كم ثانية يجي حرامي (0 = ماكو)
  final int cars; // عدد السيارات بالشوارع
  final int theme; // 0 نهار، 1 غروب، 2 ليل، 3 مطر، 4 مطر بالليل
  final List<double> storms; // بأي ثانية تجي عاصفة
  final List<double> overloads; // بأي ثانية المولدة تسخن
  final double gangEvery; // كل كم ثانية تجي العصابة (0 = ماكو)
  final int gangSize;
  final int boss; // 0 ماكو زعيم، 1..4 قوة الزعيم
  final bool vehicle; // اكو سيارة شغل تگدر تسوگها
  final bool heli; // اكو هليكوبتر
  final int nx, ny; // حجم المدينة بالبلوكات
  final int seed; // شكل المدينة (وين الحدايق)
  final List<int> stars;
  const LevelCfg({
    required this.title,
    required this.tip,
    required this.duration,
    required this.spawn,
    required this.darkTimeout,
    this.fuelDrain = 0,
    this.thiefEvery = 0,
    this.cars = 0,
    this.theme = 0,
    this.storms = const [],
    this.overloads = const [],
    this.gangEvery = 0,
    this.gangSize = 0,
    this.boss = 0,
    this.vehicle = false,
    this.heli = false,
    this.nx = 4,
    this.ny = 6,
    this.seed = 1,
    required this.stars,
  });
  bool get night => theme == 2 || theme == 4;
  bool get rain => theme == 3 || theme == 4;
}

const _titles = [
  'أول يوم شغل', 'شارع الزحمة', 'الكاز خلصان', 'الحرامي!', 'الليل', 'المطر المكهرب', 'حمل زائد', 'العاصفة', 'العصابة', 'الزعيم الأول',
  'الحي الجديد', 'غروب بغداد', 'ليلة طويلة', 'شوارع مبلولة', 'الزحمة الكبيرة', 'عيد الحي', 'حرامية الواير', 'ليل ومطر', 'صيف حار', 'زعيم السوگ',
  'المدينة الكبيرة', 'الكهرباء الوطنية طافية', 'ليلة الحراميه', 'السيل', 'سوگ الجمعة', 'العرس', 'المولدة التعبانة', 'برد وظلمة', 'عصابة الليل', 'الزعيم الأحمر',
  'المدينة كلها', 'الامتحان', 'ما ننام', 'العاصفة الكبرى', 'ساعة الذروة', 'الحرّ', 'الحرب على الحرامية', 'آخر ليلة', 'ضد الجميع', 'ملك المولدات',
];

const _intro = {
  0: '⚡ اركض للبيت الطافي.. و🚙 اركب سيارة الشغل حتى توصل أسرع',
  1: '🚁 الهليكوبتر تصلّح البيوت من الجو! حوم فوگ البيت الطافي.. بس انتبه لوقودها',
  2: '⛽ الكاز يخلص! 🚚 اركب السيارة، املي التانكر من المحطة، وودّيه للمولدة',
  3: '🦹 الحرامي يگص الواير ويهرب.. الحگه أو اضربه 👊',
  4: '🌙 الدنيا ظلمة.. اتبع الأسهم',
  5: '⚡💧 المطر كهرب المي! لا تدوس على المي وهي تشرّر',
  6: '🔥 إذا المولدة سخنت اركضلها واضغط بسرعة',
  7: '⛈️ عاصفة راح تطفي نص الحي مرة وحدة!',
  8: '👊 عصابة دخلت الحي! اضربهم بزر القبضة',
  9: '👹 الزعيم! لازم تغلبه قبل ما يخلص الوكت',
};

const _themeTips = [
  '☀️ نهار، والمدينة أكبر.. استعمل السيارة',
  '🌇 غروب، والبيوت تطفي أسرع',
  '🌙 ليل.. البيت الطافي ما يبين إلا بالسهم',
  '🌧️ مطر.. انتبه للمي المكهربة',
  '🌧️🌙 ليل ومطر.. أصعب شي',
];

List<LevelCfg> buildLevels() {
  final out = <LevelCfg>[];
  const cycle = [0, 1, 2, 0, 3, 1, 2, 3, 0, 4];
  const firstTen = [0, 0, 0, 1, 2, 3, 1, 0, 0, 4];
  for (var i = 0; i < 40; i++) {
    final tier = i ~/ 10, k = i % 10;
    final nx = const [5, 6, 7, 8][tier];
    final ny = const [7, 9, 10, 12][tier];
    final area = sqrt(nx * ny / 24.0);
    final dur = (50 + tier * 10 + k * 1.5).roundToDouble();
    final theme = tier == 0 ? firstTen[k] : cycle[k];
    final storms = <double>[];
    if (i >= 7 && k % 2 == 1) storms.add((dur * 0.3).roundToDouble());
    if (tier >= 2 && k % 3 == 0) storms.add((dur * 0.65).roundToDouble());
    if (i == 7) storms.add(18);
    final overloads = <double>[];
    if (i >= 6 && k % 3 == 0) overloads.add((dur * 0.4).roundToDouble());
    if (i == 6) overloads.add(15);
    if (tier >= 2 && k % 2 == 0) overloads.add((dur * 0.75).roundToDouble());
    final boss = k == 9 ? tier + 1 : 0;
    final mult = 1 + tier * 0.3 + (boss > 0 ? 0.3 : 0);
    out.add(LevelCfg(
      title: _titles[i],
      tip: _intro[i] ?? _themeTips[theme],
      duration: dur,
      spawn: max(1.5, 3.0 - tier * 0.3 - k * 0.05),
      darkTimeout: max(7.5, 11 + (area - 1) * 5 - tier * 1.0 - k * 0.12),
      fuelDrain: i >= 2 ? 0.025 + i * 0.0004 : 0,
      thiefEvery: i >= 3 ? max(6.0, 13 - i * 0.18) : 0,
      cars: i == 0 ? 0 : ((4 + i ~/ 3) * area).round(),
      theme: theme,
      storms: storms,
      overloads: overloads,
      gangEvery: i >= 8 ? max(11.0, 24 - tier * 3 - k * 0.4) : 0,
      gangSize: i >= 8 ? 2 + tier : 0,
      boss: boss,
      vehicle: true,
      heli: i >= 1,
      nx: nx,
      ny: ny,
      seed: i * 7919 + 13,
      stars: [
        ((dur * 11 * mult) / 50).round() * 50,
        ((dur * 19 * mult) / 50).round() * 50,
        ((dur * 27 * mult) / 50).round() * 50,
      ],
    ));
  }
  return out;
}

final List<LevelCfg> levels = buildLevels();

/// ماشي على الرصيف حوالين بلوك
class Walker {
  final Rect ring;
  double t;
  final double speed;
  final int sprite;
  Offset pos = Offset.zero;
  Offset dir = const Offset(1, 0);
  Walker(this.ring, this.t, this.speed, this.sprite);
}

/// صاحب البيت يطلع يشكرك
class Greeter {
  final Offset pos;
  final int sprite;
  double t;
  final String text;
  Greeter(this.pos, this.sprite, this.t, this.text);
}

class House {
  final Rect rect;
  final int style;
  int get floors => style % 3 == 0 ? 2 : 1;
  bool lit = true;
  double dark = 0;
  double flash = 0;
  double angry = 0;
  House(this.rect, this.style);
  Offset get center => rect.center;
}

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

/// واحد من العصابة، أو الزعيم
class Thug {
  Offset pos;
  final bool boss;
  final int maxHp;
  int hp;
  Offset dir = const Offset(0, 1);
  double windup = 0; // يتهيأ يضرب
  double cd = 0; // بين ضربة وضربة
  double hurt = 0; // يرمش بعد ما ينضرب
  Offset knock = Offset.zero;
  double stuck = 0;
  Offset? detour;
  double detourT = 0;
  double slamT = 0, summonT = 0; // للزعيم
  Offset? slamAt;
  double slamWarn = 0;
  Thug(this.pos, this.maxHp, {this.boss = false}) : hp = maxHp;
}

class Puddle {
  final Offset pos;
  final double r;
  int state = 0; // 0 عادي، 1 ينذر، 2 مكهرب
  double t;
  Puddle(this.pos, this.r, this.t);
}

class Car {
  Offset pos;
  final Offset dir;
  final double speed;
  final int kind;
  double honk = 0;
  Car(this.pos, this.dir, this.speed, this.kind);
  bool get vertical => dir.dx == 0;
  Rect get rect => vertical ? Rect.fromCenter(center: pos, width: 0.7, height: 0.95) : Rect.fromCenter(center: pos, width: 0.95, height: 0.7);
}

class Pickup {
  Offset pos;
  final int kind; // 0 كاز، 1 سرعة، 2 صحة
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

/// كل منطق اللعبة. الإحداثيات بالمربعات، وكل بلوك 4 × 4
class ArcadeWorld extends ChangeNotifier {
  static const double speed = 5.0;
  static const double carSpeed = 8.5;
  static const double radius = 0.3;

  // شكل المدينة (يتغير حسب المرحلة)
  double w = 16, h = 24;
  List<double> roadXs = [], roadYs = [];
  Rect plaza = Rect.zero, generator = Rect.zero;
  Offset startPos = Offset.zero;
  List<Rect> parks = [];

  final _rnd = Random();
  void Function(String)? onSfx;
  void Function(String)? onMusic;
  void sfx(String n) => onSfx?.call(n);

  List<int> stars = List.filled(levels.length, 0);
  List<int> best = List.filled(levels.length, 0);

  // ---------- المتجر (فلوس اللعبة، تنجمع باللعب) ----------
  static const shopIcons = ['👟', '💪', '👊', '⛽'];
  static const shopNames = ['حذاء سريع', 'صحة أقوى', 'قبضة حديد', 'خزان كاز أكبر'];
  static const shopDesc = ['تمشي وتسوگ أسرع 8% لكل مستوى', '+25 صحة لكل مستوى', 'ضربتك أسرع، وبالمستوى 2 أقوى', 'الكاز يخلص أبطأ 15% لكل مستوى'];
  static const upgCosts = [200, 450, 900];
  static const heartCost = 150;
  int coins = 0;
  List<int> upg = [0, 0, 0, 0];
  int extraHearts = 0;
  int lastCoins = 0;
  bool doubled = false; // ضاعف فلوسه بإعلان
  bool revived = false; // كمّل بإعلان (مرة وحدة بالمرحلة)

  /// مكافأة الإعلان: ضعف الفلوس
  void doubleCoins() {
    if (doubled || lastCoins <= 0) return;
    doubled = true;
    coins += lastCoins;
    lastCoins *= 2;
    sfx('coin');
    _saveProgress();
    notifyListeners();
  }

  bool get canRevive => phase == Phase.lost && !revived && (hearts <= 0 || (cfg.boss > 0 && boss != null));

  /// مكافأة الإعلان: كمّل نفس المرحلة
  void revive() {
    if (!canRevive) return;
    revived = true;
    coins -= lastCoins;
    lastCoins = 0;
    if (hearts <= 0) hearts = 1;
    hp = maxHp;
    if (timeLeft < 20) timeLeft = 20;
    invuln = 3;
    lostReason = '';
    phase = Phase.playing;
    onMusic?.call(cfg.boss > 0 && boss != null ? 'music_boss' : 'music_main');
    _saveProgress();
    _say('❤️ رجعت! كمّل');
  }

  int? upgCost(int i) => upg[i] < upgCosts.length ? upgCosts[upg[i]] : null;

  bool buyUpg(int i) {
    final c = upgCost(i);
    if (c == null || coins < c) return false;
    coins -= c;
    upg[i]++;
    sfx('coin');
    _saveProgress();
    notifyListeners();
    return true;
  }

  bool buyHeart() {
    if (coins < heartCost || extraHearts >= 5) return false;
    coins -= heartCost;
    extraHearts++;
    sfx('coin');
    _saveProgress();
    notifyListeners();
    return true;
  }

  double get maxHp => 100 + 25.0 * upg[1];

  Phase phase = Phase.menu;
  int level = 0;
  LevelCfg get cfg => levels[level];
  double timeLeft = 0, countdown = 0, clock = 0;
  int score = 0, hearts = 3, combo = 1, fixes = 0, caught = 0, beaten = 0;
  double comboTimer = 0, spawnTimer = 0, thiefTimer = 0, canTimer = 0, boostTimer = 0, boostSpawn = 0, gangTimer = 0;
  double fuel = 1, shake = 0, hintTime = 0;
  double stun = 0, invuln = 0;
  double hp = 100;
  double runT = 0; // كل ما تمشي أكثر بدون توقف تبدي تركض
  double attackCd = 0, attackT = 0;
  Offset player = Offset.zero;
  Offset move = Offset.zero;
  double face = pi / 2;
  // سيارة الشغل
  bool riding = false;
  Offset truck = Offset.zero;
  double truckFace = 0;
  bool nearTruck = false;
  // الهليكوبتر
  bool flying = false;
  Offset heli = Offset.zero;
  double heliFace = 0;
  bool nearHeli = false;
  // فايدة الهليكوبتر: تصلّح من الجو بس وقودها محدود
  double heliFuel = 1;
  int _hoverHouse = -1;
  double hoverT = 0;
  bool _heliTip = false, _truckTip = false;
  // فايدة السيارة: تانكر كاز من المحطة للمولدة
  Rect station = Rect.zero;
  bool tanker = false;
  int get hoverHouse => _hoverHouse;
  double _rideNag = 0;

  List<House> houses = [];
  final List<Walker> walkers = [];
  final List<Greeter> greeters = [];
  final DailyMissions missions = DailyMissions();
  final Cosmetics looks = Cosmetics(); // الأشكال (مو cos حتى ما يتعارض ويا دالة cos)
  final List<Thief> thieves = [];
  final List<Thug> thugs = [];
  final List<Puddle> puddles = [];
  final List<Car> cars = [];
  final List<Pickup> pickups = [];
  final List<Particle> particles = [];
  final List<FloatText> floats = [];
  int lastStars = 0;
  bool newBest = false;
  String lostReason = '';

  int _nextStorm = 0, _nextOverload = 0;
  double stormT = 0, lightning = 0;
  bool overloadOn = false;
  double heat = 0;
  bool nearGenerator = false;
  String banner = '';
  double bannerT = 0;
  bool bossSpawned = false;

  ArcadeWorld() {
    _buildCity(levels[0]);
    _spawnCars(8);
  }

  Thug? get boss {
    for (final t in thugs) {
      if (t.boss) return t;
    }
    return null;
  }

  bool get canFight => cfg.thiefEvery > 0 || cfg.gangEvery > 0 || cfg.boss > 0;
  double get elapsed => cfg.duration - timeLeft;

  // ---------- بناء المدينة ----------
  void _buildCity(LevelCfg c) {
    w = c.nx * 4.0;
    h = c.ny * 4.0;
    roadXs = [0.4, for (var i = 0; i < c.nx - 1; i++) 4.0 + i * 4.0, w - 0.4];
    roadYs = [0.4, for (var j = 0; j < c.ny - 1; j++) 3.9 + j * 4.0, h - 0.5];
    final pj = c.ny ~/ 2 - 1;
    plaza = Rect.fromLTWH(4.8, 0.8 + pj * 4.0, 2.4, 2.2);
    generator = Rect.fromLTWH(plaza.left + 0.5, plaza.top + 0.4, 1.4, 1.2);
    startPos = Offset(plaza.center.dx, plaza.bottom + 0.9);
    truck = Offset(plaza.center.dx + 1.6, plaza.bottom + 0.9);
    truckFace = 0;
    heli = Offset(plaza.left - 0.8, plaza.top - 0.9);
    heliFace = 0;
    // محطة الوقود بآخر المدينة (بعيدة عن المولدة)
    station = Rect.fromLTWH(w - 3.2, h - 3.2, 2.4, 2.2);
    final r = Random(c.seed);
    houses = [];
    parks = [];
    var k = c.seed % 7;
    for (var j = 0; j < c.ny; j++) {
      for (var i = 0; i < c.nx; i++) {
        final rect = Rect.fromLTWH(0.8 + i * 4.0, 0.8 + j * 4.0, 2.4, 2.2);
        k++;
        if (rect.overlaps(plaza)) continue;
        if (rect.overlaps(station)) continue; // محطة الوقود
        // بعض البلوكات حدايق (تگدر تعبر منها)
        if (c.seed > 30 && r.nextDouble() < 0.14) {
          parks.add(rect);
          continue;
        }
        houses.add(House(rect, k));
      }
    }
    // ناس تمشي على الأرصفة
    walkers.clear();
    final wr = Random(c.seed + 1);
    final n = min(16, houses.length ~/ 2);
    for (var k = 0; k < n; k++) {
      final hs = houses[wr.nextInt(houses.length)];
      walkers.add(Walker(hs.rect.inflate(0.16), wr.nextDouble() * 9, (0.7 + wr.nextDouble() * 0.6) * (wr.nextBool() ? 1 : -1), const [23, 104, 185][wr.nextInt(3)]));
    }
    greeters.clear();
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
      coins = p.getInt('coins') ?? 0;
      await missions.load(p);
      await looks.load(p);
      extraHearts = p.getInt('xhearts') ?? 0;
      final u = p.getStringList('upg');
      if (u != null) {
        for (var i = 0; i < min(u.length, upg.length); i++) {
          upg[i] = (int.tryParse(u[i]) ?? 0).clamp(0, upgCosts.length).toInt();
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
      await p.setInt('coins', coins);
      await p.setInt('xhearts', extraHearts);
      await p.setStringList('upg', upg.map((e) => '$e').toList());
      await missions.save(p);
      await looks.save(p);
    } catch (_) {}
  }

  bool unlocked(int i) => i == 0 || stars[i - 1] > 0;
  int get totalStars => stars.fold(0, (a, b) => a + b);

  // ---------- بداية ونهاية ----------
  void start(int lv) {
    level = lv;
    _buildCity(cfg);
    thieves.clear();
    thugs.clear();
    puddles.clear();
    pickups.clear();
    particles.clear();
    floats.clear();
    cars.clear();
    player = startPos;
    move = Offset.zero;
    face = pi / 2;
    riding = false;
    flying = false;
    nearTruck = false;
    nearHeli = false;
    heliFuel = 1;
    _hoverHouse = -1;
    hoverT = 0;
    tanker = false;
    timeLeft = cfg.duration;
    score = 0;
    hearts = 3;
    hp = maxHp;
    lastCoins = 0;
    doubled = false;
    revived = false;
    combo = 1;
    fixes = 0;
    caught = 0;
    beaten = 0;
    comboTimer = 0;
    spawnTimer = 1.0;
    thiefTimer = cfg.thiefEvery > 0 ? cfg.thiefEvery * 0.5 : 0;
    gangTimer = cfg.gangEvery > 0 ? cfg.gangEvery * 0.6 : 0;
    canTimer = 4;
    boostTimer = 0;
    boostSpawn = 12;
    fuel = 1;
    shake = 0;
    stun = 0;
    invuln = 0;
    attackCd = 0;
    attackT = 0;
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
    bossSpawned = false;
    lostReason = '';
    _spawnCars(cfg.cars);
    if (cfg.rain) _spawnPuddles(6 + cfg.nx * cfg.ny ~/ 4);
    countdown = 3;
    phase = Phase.countdown;
    if (extraHearts > 0) {
      extraHearts--;
      hearts = 4;
      _saveProgress();
      banner = '❤️ استعملت قلب إضافي';
      bannerT = 3;
    }
    onMusic?.call('music_main');
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
    onMusic?.call('music_main');
    notifyListeners();
  }

  void _end(bool won) {
    move = Offset.zero;
    overloadOn = false;
    nearGenerator = false;
    nearTruck = false;
    nearHeli = false;
    if (won && cfg.boss > 0 && boss != null) {
      won = false;
      lostReason = '👹 الزعيم بعده عايش!';
    }
    if (won) {
      final s = cfg.stars;
      lastStars = score >= s[2] ? 3 : (score >= s[1] ? 2 : (score >= s[0] ? 1 : 0));
      newBest = score > best[level];
      if (newBest) best[level] = score;
      if (lastStars > stars[level]) stars[level] = lastStars;
      phase = lastStars > 0 ? Phase.won : Phase.lost;
      if (lastStars == 0) lostReason = '⭐ تحتاج ${s[0]} نقطة للنجمة الأولى';
      lastCoins = score ~/ 10 + lastStars * 20;
      coins += lastCoins;
      _mission('stars', lastStars);
      _mission('play', 1);
      sfx(lastStars > 0 ? 'win' : 'miss');
      _saveProgress();
    } else {
      lastStars = 0;
      newBest = false;
      phase = Phase.lost;
      if (lostReason.isEmpty) lostReason = '😡 الناس زعلت';
      lastCoins = score ~/ 20;
      coins += lastCoins;
      _mission('play', 1);
      _saveProgress();
      sfx('miss');
    }
    onMusic?.call('music_main');
    notifyListeners();
  }

  void _say(String text) {
    banner = text;
    bannerT = 2.5;
    notifyListeners();
  }

  void _burst(Offset at, int color, int n, double sp, [double size = 0.06]) {
    for (var k = 0; k < n; k++) {
      final a = _rnd.nextDouble() * 2 * pi;
      particles.add(Particle(at, Offset(cos(a), sin(a)) * sp * (0.5 + _rnd.nextDouble()), color, 0.5, size));
    }
  }

  // ---------- الإدخال ----------
  void setMove(Offset v) => move = v;

  void tapCool() {
    if (!overloadOn || !nearGenerator || phase != Phase.playing) return;
    heat -= 0.075;
    sfx('pump');
    _burst(generator.center, 0xFF80D8FF, 4, 2.5, 0.07);
    if (heat <= 0) {
      overloadOn = false;
      heat = 0;
      score += 250;
      floats.add(FloatText(generator.center, '❄️ +250', 0xFF80D8FF));
      sfx('win');
      _say('✅ بردت المولدة!');
    }
  }

  /// اركب أو انزل من سيارة الشغل
  void toggleRide() {
    if (phase != Phase.playing || !cfg.vehicle) return;
    if (flying) {
      // ننزل بأقرب مكان فاضي
      Offset? spot;
      for (var r = 0.0; r < 4 && spot == null; r += 0.4) {
        for (var a = 0.0; a < 2 * pi; a += pi / 6) {
          final q = player + Offset(cos(a), sin(a)) * r;
          if (!_hitsSolid(q, 0.5)) {
            spot = q;
            break;
          }
        }
      }
      if (spot == null) {
        floats.add(FloatText(player, '🚁 ماكو مكان تنزل', 0xFFFFFFFF));
        return;
      }
      flying = false;
      riding = false;
      heli = spot;
      heliFace = face;
      player = spot + const Offset(0, 0.9);
      if (_hitsSolid(player, radius)) player = spot;
      sfx('kick');
      notifyListeners();
      return;
    }
    if (!riding && nearHeli && cfg.heli) {
      if (heliFuel < 0.15) {
        floats.add(FloatText(heli, '⛽ الهليكوبتر تتعبى..', 0xFFFFFFFF));
        return;
      }
      riding = true;
      flying = true;
      player = heli;
      face = heliFace;
      sfx('engine');
      if (!_heliTip) {
        _heliTip = true;
        _say('🚁 طير فوگ البيت الطافي وصلّحه من الجو!');
      }
      nearHeli = false;
      nearTruck = false;
      notifyListeners();
      return;
    }
    if (riding) {
      // ننزل جنب السيارة بمكان فاضي
      riding = false;
      truck = player;
      truckFace = face;
      for (final d in const [Offset(0, 0.8), Offset(0, -0.8), Offset(0.8, 0), Offset(-0.8, 0)]) {
        if (!_hitsSolid(truck + d, radius)) {
          player = truck + d;
          break;
        }
      }
      sfx('kick');
    } else if (nearTruck) {
      riding = true;
      player = truck;
      face = truckFace;
      sfx('engine');
      if (!_truckTip && cfg.fuelDrain > 0) {
        _truckTip = true;
        _say(tanker ? '🚚 ودّي الكاز للمولدة!' : '🚚 روح لمحطة الوقود ⛽ واملي التانكر');
      }
    }
    nearTruck = false;
    notifyListeners();
  }

  /// ضربة (قبضة)
  void attack() {
    if (phase != Phase.playing || attackCd > 0 || stun > 0 || riding) return;
    attackCd = 0.3 - 0.04 * upg[2];
    attackT = 0.18;
    final f = Offset(cos(face), sin(face));
    var hit = false;
    for (final t in List.of(thugs)) {
      final d = t.pos - player;
      final dist = d.distance;
      final reach = t.boss ? 1.6 : 1.15;
      if (dist > reach) continue;
      if (dist > 0.6 && (d.dx * f.dx + d.dy * f.dy) / dist < 0.1) continue;
      _damageThug(t, upg[2] >= 2 ? 2 : 1, dist > 0.01 ? d / dist : f);
      hit = true;
    }
    for (final t in List.of(thieves)) {
      if ((t.pos - player).distance < 1.2) {
        _catchThief(t);
        hit = true;
      }
    }
    sfx(hit ? 'punch' : 'kick');
    if (hit) shake = max(shake, 0.4);
  }

  // ---------- التحديث ----------
  void update(double dt) {
    clock += dt;
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
    if (phase == Phase.menu || phase == Phase.countdown || phase == Phase.playing) {
      _updateCars(dt);
      _updateWalkers(dt);
    }

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
    if (attackCd > 0) attackCd -= dt;
    if (attackT > 0) attackT -= dt;
    if (_rideNag > 0) _rideNag -= dt;
    _movePlayer(dt);
    _updateVehicles(dt);
    if (phase != Phase.playing) return;
    _carHits();
    _updateHouses(dt);
    if (phase != Phase.playing) return;
    _updateFuel(dt);
    _updateThieves(dt);
    _updateGang(dt);
    if (phase != Phase.playing) return;
    _updatePuddles(dt);
    if (phase != Phase.playing) return;
    _updatePickups(dt);
    _updateEvents(dt);
    if (phase != Phase.playing) return;

    final near = !riding && _distToRect(player, generator) < 1.3;
    final nt = cfg.vehicle && !riding && (truck - player).distance < 1.3;
    final nh = cfg.heli && !riding && (heli - player).distance < 1.5;
    if (near != nearGenerator || nt != nearTruck || nh != nearHeli) {
      nearGenerator = near;
      nearTruck = nt;
      nearHeli = nh;
      notifyListeners();
    }
    // الصحة ترجع شوية شوية إذا ماكو عركة
    if (hp < maxHp && thugs.every((t) => (t.pos - player).distance > 4)) hp = min(maxHp, hp + dt * 4);

    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) combo = 1;
    }
    if (boostTimer > 0) boostTimer -= dt;
    if (timeLeft.ceil() != sec) notifyListeners();
  }

  bool _hitsSolid(Offset p, double rad) {
    if (p.dx < rad || p.dx > w - rad || p.dy < rad || p.dy > h - rad) return true;
    bool inRect(Rect r) => p.dx > r.left - rad && p.dx < r.right + rad && p.dy > r.top - rad && p.dy < r.bottom + rad;
    for (final hs in houses) {
      if (inRect(hs.rect)) return true;
    }
    return inRect(generator);
  }

  /// حركة مع تزحلق على الحيطان
  bool _slide(Offset from, Offset delta, double rad, void Function(Offset) set) {
    var p = from;
    var moved = false;
    const steps = 3;
    for (var i = 0; i < steps; i++) {
      final dx = Offset(delta.dx / steps, 0), dy = Offset(0, delta.dy / steps);
      if (!_hitsSolid(p + dx, rad)) {
        p += dx;
        moved = true;
      }
      if (!_hitsSolid(p + dy, rad)) {
        p += dy;
        moved = true;
      }
    }
    set(p);
    return moved;
  }

  /// 0 = يمشي، 1 = يركض بكل سرعته
  double get running => riding ? 0 : min(1.0, max(0.0, runT - 0.5) / 0.5);

  void _movePlayer(double dt) {
    if (stun > 0) {
      runT = 0;
      return;
    }
    final len = move.distance;
    if (len < 0.05) {
      runT = 0;
      return;
    }
    runT = len > 0.8 ? runT + dt : 0;
    final dir = move / len;
    face = atan2(dir.dy, dir.dx);
    final base = (flying ? 11.0 : (riding ? carSpeed : speed * (1 + 0.45 * running))) * (1 + 0.08 * upg[0]);
    if (running > 0.9 && _rnd.nextDouble() < 0.4) {
      particles.add(Particle(player + const Offset(0, 0.25), Offset(-dir.dx, -dir.dy) * 1.2 + const Offset(0, -0.4), 0xFFBDBDBD, 0.35, 0.05));
    }
    final sp = base * min(1.0, len) * (boostTimer > 0 ? 1.5 : 1) * dt;
    if (flying) {
      // الهليكوبتر تطير فوگ البيوت
      final n = player + dir * sp;
      player = Offset(n.dx.clamp(0.5, w - 0.5).toDouble(), n.dy.clamp(0.5, h - 0.5).toDouble());
    } else {
      _slide(player, dir * sp, riding ? 0.38 : radius, (p) => player = p);
    }
    final trail = looks.eq('trail');
    if (trail.id != 'trail0' && !flying && _rnd.nextDouble() < 0.55) {
      particles.add(Particle(player + Offset((_rnd.nextDouble() - 0.5) * 0.3, 0.2), Offset(-dir.dx, -dir.dy) * 0.8 + const Offset(0, -0.5), trail.color, 0.5, 0.06));
    }
    if (boostTimer > 0 && _rnd.nextDouble() < 0.5) {
      particles.add(Particle(player, Offset(-dir.dx, -dir.dy) * 1.5, 0xFF80D8FF, 0.35, 0.06));
    }
    if (riding && !flying && _rnd.nextDouble() < 0.3) {
      particles.add(Particle(player - dir * 0.5, Offset(-dir.dx, -dir.dy) * 0.8, 0xFF9E9E9E, 0.4, 0.05));
    }
  }

  double _distToRect(Offset p, Rect r) {
    final dx = max(max(r.left - p.dx, 0.0), p.dx - r.right);
    final dy = max(max(r.top - p.dy, 0.0), p.dy - r.bottom);
    return sqrt(dx * dx + dy * dy);
  }

  bool get generatorOn => cfg.fuelDrain == 0 || fuel > 0;

  void _updateWalkers(double dt) {
    for (final wk in walkers) {
      wk.t += wk.speed * dt;
      final r = wk.ring;
      final per = 2 * (r.width + r.height);
      final s = ((wk.t % per) + per) % per;
      Offset p, d;
      if (s < r.width) {
        p = Offset(r.left + s, r.top);
        d = const Offset(1, 0);
      } else if (s < r.width + r.height) {
        p = Offset(r.right, r.top + s - r.width);
        d = const Offset(0, 1);
      } else if (s < 2 * r.width + r.height) {
        p = Offset(r.right - (s - r.width - r.height), r.bottom);
        d = const Offset(-1, 0);
      } else {
        p = Offset(r.left, r.bottom - (s - 2 * r.width - r.height));
        d = const Offset(0, -1);
      }
      wk.pos = p;
      wk.dir = wk.speed < 0 ? -d : d;
    }
    for (final g in greeters) {
      g.t -= dt;
    }
    greeters.removeWhere((g) => g.t <= 0);
  }

  // ---------- المهام والمتجر ----------
  void _mission(String id, int n) {
    if (n <= 0) return;
    if (missions.add(id, n) && phase == Phase.playing) _say('🎯 خلصت مهمة! استلم جائزتك من المهام');
  }

  bool claimMission(int i) {
    if (i < 0 || i >= missions.list.length) return false;
    final m = missions.list[i];
    if (!m.done || m.claimed) return false;
    m.claimed = true;
    coins += m.reward;
    sfx('win');
    _saveProgress();
    notifyListeners();
    return true;
  }

  int claimLogin() {
    final r = missions.claimLogin();
    if (r > 0) {
      coins += r;
      sfx('win');
      _saveProgress();
      notifyListeners();
    }
    return r;
  }

  bool buyCos(String id) {
    final it = looks.item(id);
    if (looks.owned.contains(id) || coins < it.cost) return false;
    coins -= it.cost;
    looks.owned.add(id);
    looks.equipped[it.kind] = id;
    sfx('coin');
    _saveProgress();
    notifyListeners();
    return true;
  }

  void equipCos(String id) {
    if (!looks.owned.contains(id)) return;
    looks.equipped[looks.item(id).kind] = id;
    sfx('kick');
    _saveProgress();
    notifyListeners();
  }

  /// أول مرحلة مفتوحة وما بيها 3 نجوم (حتى زر "العب" يكمل منها)
  int get nextLevel {
    var last = 0;
    for (var i = 0; i < levels.length; i++) {
      if (!unlocked(i)) break;
      last = i;
      if (stars[i] < 3) return i;
    }
    return last;
  }

  /// الهليكوبتر: وقود + تصليح من الجو. السيارة: تانكر كاز
  void _updateVehicles(double dt) {
    if (flying) {
      heliFuel -= dt / (16 + 4.0 * upg[3]);
      if (heliFuel <= 0) {
        heliFuel = 0;
        _say('🚁 خلص وقود الهليكوبتر! نزلت');
        toggleRide();
        return;
      }
      // نحوم فوگ بيت طافي = نصلّحه
      var over = -1;
      for (var i = 0; i < houses.length; i++) {
        if (!houses[i].lit && houses[i].rect.inflate(0.2).contains(player)) {
          over = i;
          break;
        }
      }
      if (over != _hoverHouse) {
        _hoverHouse = over;
        hoverT = 0;
      }
      if (over >= 0) {
        hoverT += dt;
        if (hoverT >= 0.7) {
          if (generatorOn) {
            _fix(over);
            _mission('heli', 1);
            score += 50;
            floats.add(FloatText(houses[over].center.translate(0, -0.6), '🚁 +50', 0xFF80D8FF));
          } else {
            floats.add(FloatText(houses[over].center, '⛽ الكاز!', 0xFFFF5252));
          }
          _hoverHouse = -1;
          hoverT = 0;
        }
      }
    } else {
      _hoverHouse = -1;
      hoverT = 0;
      if (cfg.heli) heliFuel = min(1.0, heliFuel + dt / 10);
    }
    // التانكر
    if (riding && !flying && cfg.fuelDrain > 0) {
      if (!tanker && _distToRect(player, station) < 1.4) {
        tanker = true;
        sfx('pump');
        floats.add(FloatText(player, '⛽ انملى التانكر!', 0xFFFFB300));
        _say('🚚 هسه ودّيه للمولدة');
      }
      if (tanker && _distToRect(player, generator) < 1.8) {
        tanker = false;
        fuel = 1;
        _mission('tanker', 1);
        score += 150;
        sfx('win');
        floats.add(FloatText(generator.center, '⛽ مولدة مليانة +150', 0xFF69F0AE));
        _burst(generator.center, 0xFFFFB300, 20, 3, 0.08);
        notifyListeners();
      }
    }
  }

  // ---------- الصحة ----------
  void _hurtPlayer(double amount, Offset from, String icon) {
    if (invuln > 0) return;
    hp -= amount;
    invuln = 0.9;
    stun = max(stun, 0.25);
    shake = max(shake, 0.8);
    sfx('hurt');
    floats.add(FloatText(player, '$icon -${amount.round()}', 0xFFFF5252));
    final d = player - from;
    if (d.distance > 0.01) {
      _slide(player, d / d.distance * 0.7, radius, (p) => player = p);
    }
    if (hp <= 0) {
      hp = maxHp;
      if (flying) heli = player;
      riding = false;
      flying = false;
      truck = startPos + const Offset(1.6, 0);
      player = startPos;
      invuln = 2.5;
      _say('😵 ضربوك! رجعت للمولدة');
      _loseHeart(player, '💔');
    }
    notifyListeners();
  }

  // ---------- السيارات ----------
  void _spawnCars(int n) {
    var tries = 0;
    final innerX = roadXs.sublist(1, roadXs.length - 1);
    final innerY = roadYs.sublist(1, roadYs.length - 1);
    while (cars.length < n && tries < 300) {
      tries++;
      final vertical = _rnd.nextBool();
      final forward = _rnd.nextBool();
      final kind = _rnd.nextInt(3);
      final sp = 2.6 + _rnd.nextDouble() * 1.6 + level * 0.02;
      Car c;
      if (vertical) {
        final x = innerX[_rnd.nextInt(innerX.length)] + (forward ? -0.42 : 0.42);
        c = Car(Offset(x, _rnd.nextDouble() * h), Offset(0, forward ? 1 : -1), sp, kind);
      } else {
        final y = innerY[_rnd.nextInt(innerY.length)] + (forward ? 0.42 : -0.42);
        c = Car(Offset(_rnd.nextDouble() * w, y), Offset(forward ? 1 : -1, 0), sp, kind);
      }
      if ((c.pos - startPos).distance < 3) continue;
      if (cars.any((o) => o.rect.inflate(0.4).overlaps(c.rect))) continue;
      cars.add(c);
    }
  }

  void _updateCars(double dt) {
    for (final c in cars) {
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
      // توكف إذا سيارتك گدامها
      if (riding && !flying && ahead.contains(player)) blocked = true;
      if (!blocked) c.pos += c.dir * c.speed * dt;
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
      // العصابة تنضرب بالسيارات هم
      for (final t in List.of(thugs)) {
        if (t.hurt <= 0 && r.contains(t.pos)) _damageThug(t, 2, c.dir);
      }
      if (riding) continue;
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
        hp -= 15;
        sfx('honk');
        floats.add(FloatText(player, '💥 -$lost', 0xFFFF5252));
        _burst(player, 0xFFFFFFFF, 12, 3);
        final side = c.vertical ? Offset(player.dx < c.pos.dx ? -1 : 1, 0) : Offset(0, player.dy < c.pos.dy ? -1 : 1);
        _slide(player, side * 0.9 + c.dir * 0.4, radius, (p) => player = p);
        if (hp <= 0) {
          invuln = 0;
          _hurtPlayer(0.1, c.pos, '🚗');
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
      if (_distToRect(player, hs.rect) < (riding ? 0.45 : radius) + 0.3) {
        if (riding) {
          if (_rideNag <= 0) {
            _rideNag = 2;
            floats.add(FloatText(hs.center, '🚙 انزل حتى تصلّح', 0xFFFFFFFF));
          }
        } else if (generatorOn) {
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
    if (hearts <= 0) {
      lostReason = '😡 الناس زعلت';
      _end(false);
    }
  }

  void _goDark(int i) {
    final hs = houses[i];
    if (!hs.lit) return;
    hs.lit = false;
    hs.dark = cfg.darkTimeout;
    sfx('alarm');
    _burst(hs.center, 0xFFFFEB3B, 8, 2, 0.05);
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
    _burst(hs.center, 0xFFFFD54F, 14, 3, 0.07);
    _mission('fix', 1);
    // صاحب البيت يطلع يشكرك
    const thanks = ['شكراً! 🙏', 'الله يخليك ❤️', 'عاشت إيدك! 👏', 'رجعت الكهرباء! 💡', 'يا بطل! 💪'];
    greeters.add(Greeter(Offset(hs.center.dx, hs.rect.bottom + 0.3), const [23, 104, 185][_rnd.nextInt(3)], 2.2, thanks[_rnd.nextInt(thanks.length)]));
    if (greeters.length > 4) greeters.removeAt(0);
    notifyListeners();
  }

  Offset _randomStreetPoint({double minD = 2, double maxD = 11}) {
    final innerX = roadXs.sublist(1, roadXs.length - 1);
    final innerY = roadYs.sublist(1, roadYs.length - 1);
    for (var tries = 0; tries < 80; tries++) {
      Offset p;
      if (_rnd.nextBool()) {
        p = Offset(1 + _rnd.nextDouble() * (w - 2), innerY[_rnd.nextInt(innerY.length)]);
      } else {
        p = Offset(innerX[_rnd.nextInt(innerX.length)], 1 + _rnd.nextDouble() * (h - 2));
      }
      final d = (p - player).distance;
      if (!_hitsSolid(p, radius) && d > minD && d < maxD) return p;
    }
    return startPos;
  }

  void _updateFuel(double dt) {
    if (cfg.fuelDrain <= 0) return;
    final wasOn = fuel > 0;
    fuel = max(0, fuel - cfg.fuelDrain * (1 - 0.15 * upg[3]) * dt);
    if (wasOn && fuel <= 0) {
      sfx('alarm');
      _say('⛽ خلص الكاز! لمّ جليكان');
    }
    canTimer -= dt * (fuel < 0.35 ? 1.8 : 1);
    if (canTimer <= 0) {
      canTimer = 5 + _rnd.nextDouble() * 3;
      if (pickups.where((p) => p.kind == 0).length < 2) pickups.add(Pickup(_randomStreetPoint(), 0, 14));
    }
  }

  void _updatePickups(double dt) {
    boostSpawn -= dt;
    if (boostSpawn <= 0) {
      boostSpawn = 13 + _rnd.nextDouble() * 8;
      // إذا اكو عركة يطلع صحة أكثر
      final kind = (canFight && hp < maxHp * 0.7 && _rnd.nextBool()) ? 2 : 1;
      pickups.add(Pickup(_randomStreetPoint(), kind, 12));
    }
    for (final p in List.of(pickups)) {
      p.life -= dt;
      if (p.life <= 0) {
        pickups.remove(p);
        continue;
      }
      if ((p.pos - player).distance < (riding ? 0.8 : 0.6)) {
        pickups.remove(p);
        if (p.kind == 0) {
          fuel = min(1, fuel + 0.45);
          score += 30;
          sfx('pump');
          floats.add(FloatText(p.pos, '⛽ +30', 0xFFFFB300));
        } else if (p.kind == 1) {
          boostTimer = 6;
          sfx('goal');
          floats.add(FloatText(p.pos, '⚡ سرعة!', 0xFF80D8FF));
        } else {
          hp = min(maxHp, hp + 40);
          sfx('coin');
          floats.add(FloatText(p.pos, '❤️ +40', 0xFF69F0AE));
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

  void _catchThief(Thief t) {
    if (!thieves.remove(t)) return;
    caught++;
    _mission('thief', 1);
    final pts = t.state == ThiefState.fleeing ? 300 : 150;
    score += pts;
    sfx('goal');
    shake = 0.6;
    floats.add(FloatText(t.pos, '👮 +$pts', 0xFF69F0AE));
    _burst(t.pos, 0xFF69F0AE, 16, 3);
    notifyListeners();
  }

  void _updateThieves(double dt) {
    if (cfg.thiefEvery > 0) {
      thiefTimer -= dt;
      if (thiefTimer <= 0 && thieves.length < 2 + level ~/ 15) {
        thiefTimer = cfg.thiefEvery * (0.8 + _rnd.nextDouble() * 0.4);
        final targets = [for (var i = 0; i < houses.length; i++) if (houses[i].lit) i];
        if (targets.isNotEmpty) {
          final ti = targets[_rnd.nextInt(targets.length)];
          final y = roadYs[1 + _rnd.nextInt(roadYs.length - 2)];
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
        final sp = (t.state == ThiefState.fleeing ? 3.7 + level * 0.02 : 2.3) * dt;
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
      if (!flying && (t.pos - player).distance < (riding ? 0.85 : 0.65)) _catchThief(t);
    }
  }

  // ---------- العصابة والزعيم ----------
  Offset _edgeSpawn() {
    final y = roadYs[1 + _rnd.nextInt(roadYs.length - 2)];
    final p = _randomStreetPoint(minD: 7, maxD: 14);
    return p == startPos ? Offset(_rnd.nextBool() ? 0.4 : w - 0.4, y) : p;
  }

  void _updateGang(double dt) {
    if (cfg.gangEvery > 0) {
      gangTimer -= dt;
      if (gangTimer <= 0) {
        gangTimer = cfg.gangEvery * (0.85 + _rnd.nextDouble() * 0.3);
        if (thugs.where((t) => !t.boss).length < 6) {
          final at = _edgeSpawn();
          for (var k = 0; k < cfg.gangSize; k++) {
            thugs.add(Thug(at + Offset((k % 3) * 0.6 - 0.6, (k ~/ 3) * 0.6), 3 + level ~/ 12));
          }
          sfx('whistle');
          _say('👊 العصابة جاية!');
        }
      }
    }
    if (cfg.boss > 0 && !bossSpawned && elapsed > 6) {
      bossSpawned = true;
      thugs.add(Thug(_edgeSpawn(), 22 + cfg.boss * 10, boss: true)
        ..slamT = 4
        ..summonT = 9);
      sfx('boss');
      shake = 1.5;
      onMusic?.call('music_boss');
      _say('👹 الزعيم وصل!');
    }
    for (final t in List.of(thugs)) {
      if (!thugs.contains(t)) continue;
      if (t.hurt > 0) t.hurt -= dt;
      if (t.cd > 0) t.cd -= dt;
      // دفعة الضربة
      if (t.knock.distance > 0.01) {
        _slide(t.pos, t.knock * dt * 8, radius, (p) => t.pos = p);
        t.knock = t.knock * (1 - min(1.0, dt * 8));
      }
      final toP = player - t.pos;
      final dist = toP.distance;
      if (t.boss) _bossAi(t, dt, dist);
      if (t.windup > 0) {
        t.windup -= dt;
        if (t.windup <= 0) {
          t.cd = t.boss ? 1.2 : 1.0;
          if (!flying && dist < (t.boss ? 1.5 : 1.05)) {
            _hurtPlayer(t.boss ? 22.0 + cfg.boss * 3 : 9.0 + level * 0.15, t.pos, t.boss ? '👹' : '👊');
            sfx('punch');
          }
        }
        continue;
      }
      if (!flying && dist < (t.boss ? 1.3 : 0.9) && t.cd <= 0 && stun <= 0) {
        t.windup = t.boss ? 0.55 : 0.4;
        t.dir = dist > 0.01 ? toP / dist : t.dir;
        continue;
      }
      if (dist < 0.7) continue;
      // يمشي صوبك، وإذا انحصر يدور طريق من التقاطعات
      var goal = player;
      if (t.detour != null) {
        t.detourT -= dt;
        goal = t.detour!;
        if (t.detourT <= 0 || (goal - t.pos).distance < 0.3) t.detour = null;
      }
      final d = goal - t.pos;
      final len = d.distance;
      if (len < 0.01) continue;
      t.dir = d / len;
      final sp = (t.boss ? 2.4 : 3.0 + level * 0.025) * dt;
      final before = t.pos;
      _slide(t.pos, t.dir * sp, t.boss ? 0.45 : radius, (p) => t.pos = p);
      if ((t.pos - before).distance < sp * 0.3) {
        t.stuck += dt;
        if (t.stuck > 0.4) {
          t.stuck = 0;
          t.detour = _bestCorner(t.pos, player);
          t.detourT = 2.0;
        }
      } else {
        t.stuck = 0;
      }
      // سيارتك تدعمهم
      if (riding && !flying && t.hurt <= 0 && dist < 0.9 && move.distance > 0.3) _damageThug(t, 2, dist > 0.01 ? -toP / dist : t.dir);
    }
  }

  Offset _bestCorner(Offset from, Offset to) {
    var best = from;
    var bd = 1e9;
    for (final x in roadXs) {
      for (final y in roadYs) {
        final p = Offset(x, y);
        final a = (p - from).distance;
        if (a > 6) continue;
        final s = a + (to - p).distance * 1.2;
        if (s < bd) {
          bd = s;
          best = p;
        }
      }
    }
    return best;
  }

  void _bossAi(Thug b, double dt, double dist) {
    // ضربة أرض: دائرة حمرة تنذرك، اطلع منها
    if (b.slamAt != null) {
      b.slamWarn -= dt;
      if (b.slamWarn <= 0) {
        final at = b.slamAt!;
        if (!flying && (player - at).distance < 1.7) _hurtPlayer(28.0 + cfg.boss * 4, at, '💥');
        for (final t in thugs) {
          if (!t.boss && (t.pos - at).distance < 1.7) t.knock = (t.pos - at) * 1.2;
        }
        _burst(at, 0xFFFF6D00, 26, 5, 0.09);
        shake = 1.6;
        sfx('boss');
        b.slamAt = null;
      }
    } else {
      b.slamT -= dt;
      if (b.slamT <= 0 && dist < 7) {
        b.slamT = max(2.6, 5.0 - cfg.boss * 0.5);
        b.slamAt = player;
        b.slamWarn = 1.1;
      }
    }
    b.summonT -= dt;
    if (b.summonT <= 0) {
      b.summonT = max(8.0, 14.0 - cfg.boss * 1.5);
      if (thugs.length < 7) {
        for (var k = 0; k < 2; k++) {
          thugs.add(Thug(b.pos + Offset(k == 0 ? -0.8 : 0.8, 0.3), 2 + cfg.boss));
        }
        _say('👹 الزعيم صاح على جماعته!');
      }
    }
  }

  void _damageThug(Thug t, int dmg, Offset dir) {
    if (t.hurt > 0) return;
    t.hp -= dmg;
    t.hurt = 0.25;
    t.windup = 0;
    t.knock = dir * (t.boss ? 0.6 : 1.6);
    _burst(t.pos, 0xFFFFFFFF, 6, 2.5, 0.05);
    floats.add(FloatText(t.pos, '💢', 0xFFFFFFFF));
    if (t.boss) notifyListeners();
    if (t.hp <= 0) {
      thugs.remove(t);
      beaten++;
      _mission('gang', 1);
      final pts = t.boss ? 1500 : 120;
      score += pts;
      floats.add(FloatText(t.pos, t.boss ? '🏆 +$pts' : '👊 +$pts', 0xFF69F0AE));
      _burst(t.pos, t.boss ? 0xFFFFD54F : 0xFF69F0AE, t.boss ? 40 : 14, t.boss ? 6 : 3, 0.08);
      sfx(t.boss ? 'win' : 'goal');
      if (t.boss) {
        shake = 2;
        onMusic?.call('music_main');
        _say('🏆 غلبت الزعيم!');
        // جماعته يهربون
        for (final o in List.of(thugs)) {
          thugs.remove(o);
          _burst(o.pos, 0xFF9E9E9E, 8, 2);
        }
      }
      notifyListeners();
    }
  }

  // ---------- المي المكهربة ----------
  void _spawnPuddles(int n) {
    for (var k = 0; k < n; k++) {
      final p = _randomStreetPoint(minD: 2.5, maxD: 40);
      if (p == startPos) continue;
      if (puddles.any((o) => (o.pos - p).distance < 2)) continue;
      puddles.add(Puddle(p, 0.55 + _rnd.nextDouble() * 0.35, 2 + _rnd.nextDouble() * 6));
    }
  }

  void _updatePuddles(double dt) {
    for (final p in puddles) {
      p.t -= dt;
      if (p.t <= 0) {
        if (p.state == 0) {
          p.state = 1;
          p.t = 1.0;
        } else if (p.state == 1) {
          p.state = 2;
          p.t = 2.2 + level * 0.02;
        } else {
          p.state = 0;
          p.t = max(2.5, 7 - level * 0.08) + _rnd.nextDouble() * 3;
        }
      }
      if (p.state != 2) continue;
      if (_rnd.nextDouble() < dt * 8) {
        final a = _rnd.nextDouble() * 2 * pi;
        particles.add(Particle(p.pos + Offset(cos(a), sin(a)) * p.r * 0.6, Offset(0, -1.5), 0xFF80D8FF, 0.25, 0.04));
      }
      // داخل المي (السيارة تحميك)
      if (!riding && (player - p.pos).distance < p.r + 0.1 && invuln <= 0) {
        stun = 0.9;
        sfx('zap');
        _burst(player, 0xFF80D8FF, 14, 3);
        _hurtPlayer(14.0 + level * 0.2, p.pos, '⚡');
        if (phase != Phase.playing) return;
      }
      for (final t in List.of(thugs)) {
        if (!t.boss && (t.pos - p.pos).distance < p.r) _damageThug(t, 1, const Offset(0, -1));
      }
    }
  }

  // ---------- العاصفة والحمل الزائد ----------
  void _updateEvents(double dt) {
    if (stormT > 0) stormT -= dt;
    if (_nextStorm < cfg.storms.length && elapsed >= cfg.storms[_nextStorm]) {
      _nextStorm++;
      stormT = 7;
      lightning = 1;
      shake = 1.5;
      sfx('alarm');
      _say('⛈️ عاصفة! انطفى نص الحي');
      final litOnes = [for (var i = 0; i < houses.length; i++) if (houses[i].lit) i]..shuffle(_rnd);
      for (final i in litOnes.take(4 + level ~/ 10)) {
        _goDark(i);
        houses[i].dark = cfg.darkTimeout + 3;
      }
      _spawnPuddles(3);
    }
    if ((stormT > 0 || cfg.rain) && _rnd.nextDouble() < dt * (stormT > 0 ? 0.6 : 0.08)) {
      lightning = 1;
      if (_rnd.nextDouble() < 0.5) sfx('zap');
    }

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
      heat += dt * (0.07 + level * 0.0008);
      if (_rnd.nextDouble() < dt * 6) {
        particles.add(Particle(Offset(generator.center.dx, generator.top), Offset(_rnd.nextDouble() - 0.5, -2), 0xFFFF6D00, 0.6, 0.08));
      }
      if (heat >= 1) {
        overloadOn = false;
        heat = 0;
        shake = 2;
        lightning = 0.8;
        _say('💥 المولدة انفجرت!');
        _burst(generator.center, 0xFFFF6D00, 30, 4, 0.1);
        for (var i = 0; i < houses.length; i++) {
          if (houses[i].lit && _rnd.nextDouble() < 0.4) _goDark(i);
        }
        _loseHeart(generator.center, '💥');
      }
    }
  }

  int get darkCount => houses.where((x) => !x.lit).length;
}
