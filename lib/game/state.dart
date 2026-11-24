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

  House({
    required this.name,
    required this.amps,
    this.subscribed = false,
    this.debt = 0,
    this.lazy = 0.1,
    this.rate = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'amps': amps,
        'sub': subscribed,
        'debt': debt,
        'lazy': lazy,
        'rate': rate,
      };

  factory House.fromJson(Map<String, dynamic> j) => House(
        name: j['name'] as String,
        amps: (j['amps'] as num).toInt(),
        subscribed: j['sub'] as bool,
        debt: (j['debt'] as num).toInt(),
        lazy: (j['lazy'] as num).toDouble(),
        rate: (j['rate'] as num).toDouble(),
      );
}

class MonthReport {
  final int month;
  final int income;
  final int spend;
  final List<String> late;
  MonthReport(this.month, this.income, this.spend, this.late);
}

/// كل منطق اللعبة هنا، والرسم والواجهة يقرون منه
class GameState extends ChangeNotifier {
  static const double secondsPerDay = 6; // يوم باللعبة = 6 ثواني (الشهر = 3 دقائق)
  static const int daysPerMonth = 30;
  static const int fairPrice = 15000; // سعر الأمبير "المعقول" بالحي
  static const int maintenanceCost = 50000;
  static const String _key = 'save_v1';

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

  double clock = 0; // للحركة
  double _dayTimer = 0;
  double _saveTimer = 0;
  double _toastTimer = 0;

  GameEvent? currentEvent;
  MonthReport? report;
  String? toast;
  int? selected; // رقم البيت، أو -1 للمولدة

  static List<House> _defaultHouses() => [
        House(name: 'بيت أبو محمد', amps: 5, subscribed: true, lazy: 0.15),
        House(name: 'الحجية أم علي', amps: 3, subscribed: true, lazy: 0.02),
        House(name: 'بيت أبو حسين', amps: 6, subscribed: true, lazy: 0.1),
        House(name: 'دكان جاسم', amps: 8, subscribed: true, lazy: 0.05),
        House(name: 'بيت الأستاذ كريم', amps: 4, subscribed: true, lazy: 0.05),
        House(name: 'بيت أم زينب', amps: 5, subscribed: true, lazy: 0.1),
        House(name: 'بيت أبو سجاد', amps: 6, lazy: 0.3),
        House(name: 'صالون حيدر', amps: 7, lazy: 0.1),
        House(name: 'بيت أبو مصطفى', amps: 5, lazy: 0.2),
        House(name: 'بيت الحاج عباس', amps: 10, lazy: 0.05),
      ];

  // ---------- قراءات ----------
  bool get paused => currentEvent != null || report != null;
  bool get generating => running && !broken && fuel > 0;
  bool houseLit(House h) => nationalOn || (h.subscribed && generating);
  int get load => houses.where((h) => h.subscribed).fold(0, (a, h) => a + h.amps);
  double get effectiveLoad => nationalOn ? load * 0.3 : load.toDouble();
  bool get overloaded => generating && effectiveLoad > capacityAmps;
  double get dayProgress => _dayTimer / secondsPerDay;
  int get subscribers => houses.where((h) => h.subscribed).length;
  int get upgradeCost => genLevel == 1 ? 1500000 : (genLevel == 2 ? 4000000 : 0);

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
    _saveTimer += dt;
    if (_saveTimer > 5) {
      _saveTimer = 0;
      save();
    }
    if (paused) return;
    _dayTimer += dt;
    if (_dayTimer >= secondsPerDay) {
      _dayTimer -= secondsPerDay;
      _advanceDay(events: true);
      notifyListeners();
    }
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
      if (fuel == 0 && events) showToast('خلص الكاز! المولدة طفت');
    } else if (!nationalOn) {
      satisfaction -= 4; // طفت!
    }

    // أثر السعر على رضا الناس
    satisfaction += (fairPrice - ampPrice) / 5000;

    // الأعطال
    if (!broken && (health <= 0 || (health < 30 && _rnd.nextDouble() < 0.1))) {
      _breakdown(events);
    }

    // الناس تترك أو تشترك
    if (satisfaction < 30 && _rnd.nextDouble() < 0.2) {
      final subs = houses.where((h) => h.subscribed).toList();
      if (subs.isNotEmpty) {
        final h = subs[_rnd.nextInt(subs.length)];
        h.subscribed = false;
        if (events) showToast('${h.name} ترك الاشتراك وراح للمولدة الثانية');
      }
    } else if (satisfaction > 65 && _rnd.nextDouble() < 0.15) {
      final non = houses.where((h) => !h.subscribed).toList();
      if (non.isNotEmpty) {
        final h = non[_rnd.nextInt(non.length)];
        h.subscribed = true;
        if (events) showToast('اشترك ${h.name} بـ ${h.amps} أمبير');
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
        repairDays = 4; // في حدث ثاني مفتوح، فيتصلّح على مهل
      }
    } else {
      repairDays = 5;
      if (money >= 60000) {
        money -= 60000;
        monthSpend += 60000;
      }
    }
  }

  void _endMonth() {
    int collected = 0;
    final late = <String>[];
    for (final h in houses.where((h) => h.subscribed)) {
      final bill = (h.amps * ampPrice * h.rate).round();
      if (_rnd.nextDouble() < h.lazy) {
        h.debt += bill;
        late.add(h.name);
      } else {
        collected += bill + h.debt;
        h.debt = 0;
      }
    }
    money += collected;
    monthIncome += collected;
    report = MonthReport(month, monthIncome, monthSpend, late);
    monthIncome = 0;
    monthSpend = 0;
    day = 1;
    month++;
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
    _toastTimer = 3;
  }

  // ---------- أفعال اللاعب ----------
  void toggleRunning() {
    running = !running;
    showToast(running ? 'شغّلت المولدة' : 'طفّيت المولدة');
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
      showToast('${h.name} دفع ${fmt(h.debt)}');
      h.debt = 0;
    } else {
      satisfaction = max(0.0, satisfaction - 2);
      showToast('${h.name}: باچر أنطيك!');
    }
    notifyListeners();
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

  void resetGame() {
    final fresh = GameState();
    _fromJson(fresh.toJson());
    currentEvent = null;
    report = null;
    selected = null;
    save();
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
        'houses': houses.map((h) => h.toJson()).toList(),
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };

  void _fromJson(Map<String, dynamic> j) {
    money = (j['money'] as num).toInt();
    fuel = (j['fuel'] as num).toDouble();
    fuelCapacity = (j['fuelCap'] as num).toDouble();
    fuelPrice = (j['fuelPrice'] as num).toInt();
    ampPrice = (j['ampPrice'] as num).toInt();
    capacityAmps = (j['cap'] as num).toInt();
    genLevel = (j['level'] as num).toInt();
    running = j['running'] as bool;
    health = (j['health'] as num).toDouble();
    broken = j['broken'] as bool;
    repairDays = (j['repairDays'] as num).toInt();
    satisfaction = (j['sat'] as num).toDouble();
    nationalOn = j['national'] as bool;
    day = (j['day'] as num).toInt();
    month = (j['month'] as num).toInt();
    monthIncome = (j['income'] as num).toInt();
    monthSpend = (j['spend'] as num).toInt();
    houses = (j['houses'] as List)
        .map((e) => House.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (broken && repairDays == 0) repairDays = 3; // عطل انترك بدون قرار
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(toJson()));
    } catch (_) {}
  }

  static Future<GameState> load() async {
    final s = GameState();
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        s._fromJson(j);
        s._catchUp((j['savedAt'] as num?)?.toInt());
      }
    } catch (_) {}
    return s;
  }

  /// الأيام اللي مرت واللاعب غايب (بدون أحداث، ولحد آخر الشهر فقط)
  void _catchUp(int? savedAt) {
    if (savedAt == null) return;
    final secs = (DateTime.now().millisecondsSinceEpoch - savedAt) / 1000;
    final days = (secs / secondsPerDay).floor();
    final n = min(days, daysPerMonth - day);
    if (n <= 0) return;
    for (var i = 0; i < n; i++) {
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
