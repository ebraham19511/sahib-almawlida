import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'events.dart';

/// بيت أو محل بالزگاق
class House {
  final String name;
  int amps;
  bool subscribed;
  int debt; // دين بالدينار
  double lazy; // احتمال يگول "باچر" آخر الشهر
  double rate; // نسبة من السعر (1 = سعر كامل)
  int maxPrice; // أعلى سعر أمبير يتحمله
  int pending = 0; // فلوس تنتظر الجمع (العملة فوك البيت)
  String? bubble; // كلام فوك البيت
  double bubbleTime = 0;

  House({
    required this.name,
    required this.amps,
    required this.maxPrice,
    this.subscribed = false,
    this.debt = 0,
    this.lazy = 0.1,
    this.rate = 1.0,
  });

  void say(String s) {
    bubble = s;
    bubbleTime = 3.5;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'amps': amps,
        'sub': subscribed,
        'debt': debt,
        'lazy': lazy,
        'rate': rate,
        'max': maxPrice,
        'pending': pending,
      };

  factory House.fromJson(Map<String, dynamic> j) => House(
        name: j['name'] as String,
        amps: (j['amps'] as num).toInt(),
        maxPrice: (j['max'] as num?)?.toInt() ?? 18000,
        subscribed: j['sub'] as bool,
        debt: (j['debt'] as num).toInt(),
        lazy: (j['lazy'] as num).toDouble(),
        rate: (j['rate'] as num).toDouble(),
      )..pending = (j['pending'] as num?)?.toInt() ?? 0;
}

class MonthReport {
  final int month;
  final int income;
  final int spend;
  final List<String> late;
  final List<String> left;
  MonthReport(this.month, this.income, this.spend, this.late, this.left);
}

class Mission {
  final String title;
  final int reward;
  final bool Function(GameState s) done;
  const Mission(this.title, this.reward, this.done);
}

/// كل منطق اللعبة هنا، والرسم والواجهة يقرون منه
class GameState extends ChangeNotifier {
  static const double secondsPerDay = 6; // يوم باللعبة = 6 ثواني (الشهر = 3 دقائق)
  static const int daysPerMonth = 30;
  static const int fairPrice = 15000; // سعر الأمبير "المعقول" بالحي
  static const int maintenanceCost = 50000;
  static const int tutorialCount = 5;
  static const String _key = 'save_v2';

  static final List<Mission> missions = [
    Mission('اشترِ كاز للمولدة', 50000, (s) => s.fuelBought > 0),
    Mission('اجمع فلوس أول شهر من العملات', 50000, (s) => s.totalCollected > 0),
    Mission('سوّي صيانة للمولدة', 50000, (s) => s.maintCount > 0),
    Mission('وصّل 8 مشتركين', 150000, (s) => s.subscribers >= 8),
    Mission('خلّي رضا الناس 70% أو أكثر', 100000, (s) => s.satisfaction >= 70),
    Mission('اجمع 2,000,000 دينار', 200000, (s) => s.money >= 2000000),
    Mission('طوّر المولدة لـ 100 أمبير', 300000, (s) => s.genLevel >= 2),
    Mission('وصّل كل الزگاق (10 مشتركين)', 500000, (s) => s.subscribers >= 10),
    Mission('اجمع 10,000,000 دينار', 1000000, (s) => s.money >= 10000000),
  ];

  final Random _rnd = Random();
  Random get rnd => _rnd;

  int money = 500000;
  double fuel = 150;
  double fuelCapacity = 300;
  int fuelPrice = 1000; // دينار للتر
  int ampPrice = fairPrice;
  int capacityAmps = 50;
  int genLevel = 1;
  bool running = true;
  double health = 100;
  bool broken = false;
  int repairDays = 0;
  double satisfaction = 60;
  bool nationalOn = false;
  int day = 1;
  int month = 1;
  int monthIncome = 0;
  int monthSpend = 0;
  List<House> houses = _defaultHouses();

  // التقدم والمهام والشرح
  int missionIndex = 0;
  int tutorialStep = 0;
  int fuelBought = 0;
  int maintCount = 0;
  int totalCollected = 0;
  bool collecting = false; // آخر الشهر: ننتظر اللاعب يجمع العملات
  int speed = 1;

  final List<String> _late = [];
  final List<String> _left = [];

  double clock = 0; // للحركة
  double _dayTimer = 0;
  double _saveTimer = 0;
  double _toastTimer = 0;

  GameEvent? currentEvent;
  MonthReport? report;
  String? toast;
  int? selected; // رقم البيت، أو -1 للمولدة

  static List<House> _defaultHouses() => [
        House(name: 'بيت أبو محمد', amps: 5, maxPrice: 16000, subscribed: true, lazy: 0.15),
        House(name: 'الحجية أم علي', amps: 3, maxPrice: 14000, subscribed: true, lazy: 0.02),
        House(name: 'بيت أبو حسين', amps: 6, maxPrice: 18000, subscribed: true, lazy: 0.1),
        House(name: 'دكان جاسم', amps: 8, maxPrice: 22000, subscribed: true, lazy: 0.05),
        House(name: 'بيت الأستاذ كريم', amps: 4, maxPrice: 17000, subscribed: true, lazy: 0.05),
        House(name: 'بيت أم زينب', amps: 5, maxPrice: 15000, subscribed: true, lazy: 0.1),
        House(name: 'بيت أبو سجاد', amps: 6, maxPrice: 16000, lazy: 0.3),
        House(name: 'صالون حيدر', amps: 7, maxPrice: 20000, lazy: 0.1),
        House(name: 'بيت أبو مصطفى', amps: 5, maxPrice: 15000, lazy: 0.2),
        House(name: 'بيت الحاج عباس', amps: 10, maxPrice: 21000, lazy: 0.05),
      ];

  // ---------- قراءات ----------
  bool get tutorialActive => tutorialStep < tutorialCount;
  bool get paused => currentEvent != null || report != null || collecting || tutorialActive;
  bool get generating => running && !broken && fuel > 0;
  bool houseLit(House h) => nationalOn || (h.subscribed && generating);
  bool priceTooHigh(House h) => ampPrice * h.rate > h.maxPrice;
  int get load => houses.where((h) => h.subscribed).fold(0, (a, h) => a + h.amps);
  double get effectiveLoad => nationalOn ? load * 0.3 : load.toDouble();
  bool get overloaded => generating && effectiveLoad > capacityAmps;
  double get dayProgress => _dayTimer / secondsPerDay;
  int get subscribers => houses.where((h) => h.subscribed).length;
  int get upgradeCost => genLevel == 1 ? 1500000 : (genLevel == 2 ? 4000000 : 0);
  Mission? get mission => missionIndex < missions.length ? missions[missionIndex] : null;
  int get pendingTotal => houses.fold(0, (a, h) => a + h.pending);

  @override
  void notifyListeners() {
    _checkMission();
    super.notifyListeners();
  }

  void _checkMission() {
    final m = mission;
    if (m == null || tutorialActive) return;
    if (m.done(this)) {
      money += m.reward;
      missionIndex++;
      showToast('✅ خلصت المهمة: ${m.title}\nالجائزة ${fmt(m.reward)} د.ع');
    }
  }

  // ---------- الوقت ----------
  void tick(double dt) {
    clock += dt;
    if (toast != null) {
      _toastTimer -= dt;
      if (_toastTimer <= 0) {
        toast = null;
        notifyListeners();
      }
    }
    for (final h in houses) {
      if (h.bubble != null) {
        h.bubbleTime -= dt;
        if (h.bubbleTime <= 0) h.bubble = null;
      }
    }
    _saveTimer += dt;
    if (_saveTimer > 5) {
      _saveTimer = 0;
      save();
    }
    if (paused) return;
    _dayTimer += dt * speed;
    if (_dayTimer >= secondsPerDay) {
      _dayTimer -= secondsPerDay;
      _advanceDay(events: true);
      notifyListeners();
    }
  }

  House? _randomSub() {
    final subs = houses.where((h) => h.subscribed).toList();
    return subs.isEmpty ? null : subs[_rnd.nextInt(subs.length)];
  }

  void _advanceDay({required bool events}) {
    // الوطنية تجي وتروح
    if (_rnd.nextDouble() < 0.25) {
      nationalOn = !nationalOn;
      if (events) {
        showToast(nationalOn ? 'جات الوطنية! الطلب نزل' : 'طفت الوطنية! الحي كله على مولدتك');
      }
    }

    // التصليح البطيء
    if (broken && repairDays > 0) {
      repairDays--;
      if (repairDays == 0) {
        broken = false;
        health = max(health, 60.0);
        if (events) showToast('خلص تصليح المولدة');
      }
    }

    // التشغيل والكاز
    if (generating) {
      final use = 3 + effectiveLoad * 0.25;
      fuel = max(0.0, fuel - use);
      health -= overloaded ? 4 : 0.8;
      if (!nationalOn) satisfaction += overloaded ? -2 : 1;
      if (overloaded && events) _randomSub()?.say('الضغط واطي!');
      if (fuel == 0 && events) showToast('خلص الكاز! المولدة طفت');
    } else if (!nationalOn) {
      satisfaction -= 4;
      if (events) {
        _randomSub()?.say('طفت!');
        if (_rnd.nextBool()) _randomSub()?.say('وين الكهرباء؟!');
      }
    }

    // أثر السعر على رضا الناس
    satisfaction += (fairPrice - ampPrice) / 2500;

    // الأعطال
    if (!broken && (health <= 0 || (health < 30 && _rnd.nextDouble() < 0.1))) {
      _breakdown(events);
    }

    // اللي السعر غالي عليه يترك
    for (final h in houses.where((h) => h.subscribed).toList()) {
      if (priceTooHigh(h) && _rnd.nextDouble() < 0.15) {
        h.subscribed = false;
        _left.add(h.name);
        if (events) h.say('غالي! تركتك');
      }
    }

    // رضا واطي = الناس تترك، رضا عالي = الناس تشترك
    if (satisfaction < 30 && _rnd.nextDouble() < 0.2) {
      final h = _randomSub();
      if (h != null) {
        h.subscribed = false;
        _left.add(h.name);
        if (events) h.say('تركتك!');
      }
    } else if (satisfaction > 60 && _rnd.nextDouble() < 0.2) {
      final non = houses.where((h) => !h.subscribed && !priceTooHigh(h)).toList();
      if (non.isNotEmpty) {
        final h = non[_rnd.nextInt(non.length)];
        h.subscribed = true;
        if (events) {
          h.say('اشتركت!');
          showToast('اشترك ${h.name} بـ ${h.amps} أمبير');
        }
      }
    }

    // سعر الكاز يتغير كل أسبوع
    if (day % 7 == 0) {
      final f = 0.85 + _rnd.nextDouble() * 0.3;
      fuelPrice = (fuelPrice * f).round().clamp(700, 1800);
      if (events) showToast('سعر الكاز صار ${fmt(fuelPrice)} للتر');
    }

    // حدث عشوائي
    if (events && currentEvent == null && _rnd.nextDouble() < 0.12) {
      currentEvent = EventLibrary.random(this, _rnd);
    }

    _clamp();
    day++;
    if (day > daysPerMonth) _endMonth();
  }

  void _breakdown(bool events) {
    broken = true;
    health = max(health, 0.0);
    if (events) {
      currentEvent ??= EventLibrary.burnedDynamo();
      if (currentEvent!.title != EventLibrary.burnedTitle) {
        repairDays = 4;
      }
    } else {
      repairDays = 5;
      if (money >= 60000) {
        money -= 60000;
        monthSpend += 60000;
      }
    }
  }

  /// آخر الشهر: كل مشترك يقرر يدفع، يأجّل، أو يترك إذا السعر غالي عليه
  void _endMonth() {
    for (final h in houses.where((h) => h.subscribed).toList()) {
      final bill = (h.amps * ampPrice * h.rate).round();
      if (priceTooHigh(h)) {
        h.subscribed = false;
        _left.add(h.name);
        h.say('غالي! ما أدفع');
      } else if (_rnd.nextDouble() < h.lazy) {
        h.debt += bill;
        _late.add(h.name);
        h.say('باچر أنطيك');
      } else {
        h.pending = bill + h.debt;
        h.debt = 0;
      }
    }
    day = 1;
    month++;
    if (pendingTotal > 0) {
      collecting = true;
      showToast('آخر الشهر! اضغط على العملات حتى تجمع فلوسك');
    } else {
      _finishMonth();
    }
  }

  void _finishMonth() {
    collecting = false;
    report = MonthReport(month - 1, monthIncome, monthSpend, List.of(_late), List.of(_left));
    _late.clear();
    _left.clear();
    monthIncome = 0;
    monthSpend = 0;
    save();
  }

  void _clamp() {
    satisfaction = satisfaction.clamp(0, 100).toDouble();
    health = health.clamp(0, 100).toDouble();
    fuel = fuel.clamp(0, fuelCapacity).toDouble();
  }

  // ---------- أدوات للأحداث ----------
  bool spend(int cost) {
    if (money < cost) {
      showToast('ما عندك فلوس كافية');
      return false;
    }
    money -= cost;
    monthSpend += cost;
    return true;
  }

  void earn(int amount) {
    money += amount;
    monthIncome += amount;
  }

  void penalty(int amount) {
    final paid = min(money, amount);
    money -= paid;
    monthSpend += paid;
  }

  void showToast(String m) {
    toast = m;
    _toastTimer = 3.5;
  }

  // ---------- أفعال اللاعب ----------
  void collect(int i) {
    final h = houses[i];
    if (h.pending <= 0) return;
    earn(h.pending);
    totalCollected += h.pending;
    h.say('+${fmt(h.pending)}');
    h.pending = 0;
    if (collecting && pendingTotal == 0) _finishMonth();
    notifyListeners();
  }

  void collectAll() {
    for (final h in houses) {
      if (h.pending > 0) {
        earn(h.pending);
        totalCollected += h.pending;
        h.pending = 0;
      }
    }
    if (collecting) _finishMonth();
    notifyListeners();
  }

  void toggleRunning() {
    running = !running;
    showToast(running ? 'شغّلت المولدة' : 'طفّيت المولدة');
    notifyListeners();
  }

  void toggleSpeed() {
    speed = speed == 1 ? 2 : (speed == 2 ? 3 : 1);
    notifyListeners();
  }

  void buyFuel() {
    final space = fuelCapacity - fuel;
    if (space < 1) {
      showToast('الخزان مليان');
    } else {
      final liters = min(100.0, space);
      final cost = (liters * fuelPrice).round();
      if (spend(cost)) {
        fuel += liters;
        fuelBought++;
        showToast('اشتريت ${liters.round()} لتر كاز');
      }
    }
    notifyListeners();
  }

  void maintain() {
    if (broken) {
      showToast('المولدة عاطلة، تحتاج تصليح مو صيانة');
    } else if (spend(maintenanceCost)) {
      health = min(100.0, health + 40);
      maintCount++;
      showToast('غيّرت الزيت والفلاتر');
    }
    notifyListeners();
  }

  void changePrice(int delta) {
    ampPrice = (ampPrice + delta).clamp(5000, 40000);
    notifyListeners();
  }

  void upgrade() {
    final cost = upgradeCost;
    if (cost == 0) {
      showToast('عندك أكبر مولدة');
    } else if (spend(cost)) {
      genLevel++;
      capacityAmps = genLevel == 2 ? 100 : 250;
      fuelCapacity += 200;
      health = 100;
      broken = false;
      repairDays = 0;
      showToast('مبروك! مولدة $capacityAmps أمبير');
    }
    notifyListeners();
  }

  void collectDebt(int i) {
    final h = houses[i];
    if (h.debt == 0) return;
    if (_rnd.nextBool()) {
      earn(h.debt);
      h.say('تفضل ${fmt(h.debt)}');
      h.debt = 0;
    } else {
      satisfaction = max(0.0, satisfaction - 2);
      h.say('باچر أنطيك!');
    }
    notifyListeners();
  }

  void tapHouse(int i) {
    if (houses[i].pending > 0) {
      collect(i);
    } else {
      select(selected == i ? null : i);
    }
  }

  void select(int? i) {
    selected = i;
    notifyListeners();
  }

  void choose(EventChoice c) {
    currentEvent = null;
    final msg = c.apply(this);
    _clamp();
    if (msg != null) showToast(msg);
    notifyListeners();
  }

  void closeReport() {
    report = null;
    notifyListeners();
  }

  void nextTutorial() {
    tutorialStep++;
    if (!tutorialActive) save();
    notifyListeners();
  }

  void showHelp() {
    tutorialStep = 0;
    notifyListeners();
  }

  // ---------- الحفظ ----------
  Map<String, dynamic> toJson() => {
        'money': money,
        'fuel': fuel,
        'fuelCap': fuelCapacity,
        'fuelPrice': fuelPrice,
        'ampPrice': ampPrice,
        'cap': capacityAmps,
        'level': genLevel,
        'running': running,
        'health': health,
        'broken': broken,
        'repairDays': repairDays,
        'sat': satisfaction,
        'national': nationalOn,
        'day': day,
        'month': month,
        'income': monthIncome,
        'spend': monthSpend,
        'mission': missionIndex,
        'tutorial': tutorialStep,
        'fuelBought': fuelBought,
        'maint': maintCount,
        'collected': totalCollected,
        'collecting': collecting,
        'houses': houses.map((h) => h.toJson()).toList(),
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };

  void _fromJson(Map<String, dynamic> j) {
    int gi(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    double gd(String k, double d) => (j[k] as num?)?.toDouble() ?? d;
    houses = (j['houses'] as List)
        .map((e) => House.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    money = gi('money', 500000);
    fuel = gd('fuel', 150);
    fuelCapacity = gd('fuelCap', 300);
    fuelPrice = gi('fuelPrice', 1000);
    ampPrice = gi('ampPrice', fairPrice);
    capacityAmps = gi('cap', 50);
    genLevel = gi('level', 1);
    running = j['running'] as bool? ?? true;
    health = gd('health', 100);
    broken = j['broken'] as bool? ?? false;
    repairDays = gi('repairDays', 0);
    satisfaction = gd('sat', 60);
    nationalOn = j['national'] as bool? ?? false;
    day = gi('day', 1);
    month = gi('month', 1);
    monthIncome = gi('income', 0);
    monthSpend = gi('spend', 0);
    missionIndex = gi('mission', 0);
    tutorialStep = gi('tutorial', 0);
    fuelBought = gi('fuelBought', 0);
    maintCount = gi('maint', 0);
    totalCollected = gi('collected', 0);
    collecting = j['collecting'] as bool? ?? false;
    if (collecting && pendingTotal == 0) collecting = false;
    if (broken && repairDays == 0) repairDays = 3;
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(toJson()));
    } catch (_) {}
  }

  static Future<GameState> loadSaved() async {
    var s = GameState();
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        s._fromJson(j);
        s._catchUp((j['savedAt'] as num?)?.toInt());
      }
    } catch (_) {
      s = GameState();
    }
    return s;
  }

  /// الأيام اللي مرت واللاعب غايب (بدون أحداث، ولحد آخر الشهر فقط)
  void _catchUp(int? savedAt) {
    if (savedAt == null || paused) return;
    final secs = (DateTime.now().millisecondsSinceEpoch - savedAt) / 1000;
    final days = (secs / secondsPerDay).floor();
    final n = min(days, daysPerMonth - day);
    if (n <= 0) return;
    for (var k = 0; k < n; k++) {
      _advanceDay(events: false);
    }
    showToast('وانت غايب مرّت $n يوم على الزگاق');
  }
}

/// 1500000 -> 1,500,000
String fmt(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
} 
