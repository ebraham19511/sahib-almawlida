import 'dart:convert';
import 'dart:math';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'events.dart';

/// بيت أو محل بالمحلة
class House {
  final String name;
  final String owner;
  int amps;
  bool subscribed;
  int debt; // دين بالدينار
  double lazy; // احتمال يگول "باچر" آخر الشهر
  double rate; // نسبة من السعر (1 = سعر كامل)
  int maxPrice; // أعلى سعر أمبير يتحمله
  int pending = 0; // فلوس تنتظر الجمع (العملة فوك البيت)
  String? bubble; // كلام فوك البيت
  double bubbleTime = 0;
  double coinTime = 0; // وكت العملة قبل ما "يهرب" صاحبها
  double requestTime = 0; // طلب أمبير زيادة ينتظر موافقتك
  int lastChat = -1;
  int lastOffer = -1;
  int lastDebtAsk = -1;
  bool wireCut = false; // الحرامي گص الواير
  final List<(bool, String)> chatLog = []; // (آني؟، الكلام)

  House({
    required this.name,
    required this.owner,
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
        'owner': owner,
        'amps': amps,
        'sub': subscribed,
        'debt': debt,
        'lazy': lazy,
        'rate': rate,
        'max': maxPrice,
        'pending': pending,
        'cut': wireCut,
      };

  factory House.fromJson(Map<String, dynamic> j) => House(
        name: j['name'] as String,
        owner: j['owner'] as String? ?? 'صاحب البيت',
        amps: (j['amps'] as num).toInt(),
        maxPrice: (j['max'] as num?)?.toInt() ?? 18000,
        subscribed: j['sub'] as bool,
        debt: (j['debt'] as num).toInt(),
        lazy: (j['lazy'] as num).toDouble(),
        rate: (j['rate'] as num).toDouble(),
      )
        ..pending = (j['pending'] as num?)?.toInt() ?? 0
        ..wireCut = j['cut'] as bool? ?? false;
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

enum QuestType { delivery, fixWire, visit }

/// واجب صغير بالمحلة
class Quest {
  final QuestType type;
  final int house;
  final String item; // للتوصيل: صمون، جاي...
  final int from; // للتوصيل: 0 فرن، 1 جايخانة
  final int reward;
  int daysLeft;
  bool picked = false;
  Quest(this.type, this.house, this.reward, {this.item = '', this.from = 0, this.daysLeft = 3});

  String title(List<House> hs) {
    final o = hs[house].owner;
    switch (type) {
      case QuestType.delivery:
        return picked ? 'وصّل $item لـ $o' : 'جيب $item من ${from == 0 ? 'الفرن' : 'الجايخانة'} لـ $o';
      case QuestType.fixWire:
        return 'صلّح واير $o (گصّه الحرامي)';
      case QuestType.visit:
        return '$o يريد يشوفك، ادخل بيته';
    }
  }
}

/// كل منطق اللعبة هنا، والرسم والواجهة يقرون منه
class GameState extends ChangeNotifier {
  static const double secondsPerDay = 15; // يوم كامل بليله ونهاره = 15 ثانية
  static const int daysPerMonth = 10; // الشهر = دقيقتين ونص
  static const double k = 3; // كل يوم هسه يعادل 3 أيام من النسخة القديمة
  static const int fairPrice = 15000; // سعر الأمبير "المعقول" بالحي
  static const int maintenanceCost = 50000;
  static const int tutorialCount = 6;
  static const String _key = 'save_v4';
  static const double coinSeconds = 25;
  static const double alarmSeconds = 5;
  static const double thiefSeconds = 10;
  static const double walkSpeed = 2.4; // مربع بالثانية

  // ---------- خريطة المحلة (إحداثيات الشبكة) ----------
  static const int houseCount = 16;
  static Offset housePos(int i) => i < 8 ? Offset(i.toDouble(), 0) : Offset((i - 8).toDouble(), 3);
  static const Offset genPos = Offset(3.5, 1.5);
  static const List<Offset> poles = [Offset(1, 0.72), Offset(6, 0.72), Offset(1, 2.28), Offset(6, 2.28)];
  // صف المحلات على الشارع العام
  static const Offset teaPos = Offset(1, 8);
  static const Offset mosquePos = Offset(3.5, 8);
  static const Offset bakeryPos = Offset(6, 8);
  // محلات زيادة بالشارع (للزينة)
  static const List<Offset> shops = [Offset(-0.2, 8), Offset(2.2, 8), Offset(4.9, 8), Offset(7.2, 8), Offset(8.4, 8)];
  static const List<String> shopNames = ['قصاب الخير', 'أسواق المحلة', 'صيدلية الشفاء', 'حلاق الشباب', 'كهربائي سلام'];
  static const int aiDailyLimit = 60;
  static const double minX = -1.6, maxX = 8.6, minY = -0.9, maxY = 7.45;

  static final List<Mission> missions = [
    Mission('امشِ لبيت أبو محمد وادخل سولف وياه', 50000, (s) => s.chats > 0),
    Mission('اشترِ كاز للمولدة', 50000, (s) => s.fuelBought > 0),
    Mission('اجمع فلوس أول شهر (امشِ لعند العملات)', 50000, (s) => s.totalCollected > 0),
    Mission('اشرب جاي بالجايخانة واسمع الأخبار', 30000, (s) => s.teas > 0),
    Mission('اقنع واحد يشترك وياك (ادخل بيته)', 100000, (s) => s.convinced > 0),
    Mission('امسك حرامي واير', 75000, (s) => s.thievesCaught > 0),
    Mission('خلّص 3 واجبات 📋', 100000, (s) => s.questsDone >= 3),
    Mission('شغّل المولدة بسرعة لما تنقطع الوطنية', 75000, (s) => s.alarmsSaved > 0),
    Mission('وصّل 10 مشتركين', 200000, (s) => s.subscribers >= 10),
    Mission('طوّر المولدة لـ 100 أمبير', 300000, (s) => s.genLevel >= 2),
    Mission('اجمع 3,000,000 دينار', 300000, (s) => s.money >= 3000000),
    Mission('وصّل كل المحلة (16 مشترك)', 1000000, (s) => s.subscribers >= 16),
  ];

  final Random _rnd = Random();
  Random get rnd => _rnd;

  int money = 500000;
  double fuel = 200;
  double fuelCapacity = 400;
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

  // اللاعب
  double px = 3.5, py = 2.3;
  double moveX = 0, moveY = 0; // اتجاه عصا التحكم على الشاشة (-1..1)
  bool get walking => moveX != 0 || moveY != 0;
  double faceX = 1;

  // التقدم والمهام والشرح
  int missionIndex = 0;
  int tutorialStep = 0;
  int fuelBought = 0;
  int maintCount = 0;
  int totalCollected = 0;
  int chats = 0;
  int teas = 0;
  int convinced = 0;
  int questsDone = 0;
  final List<Quest> quests = [];
  int aiCount = 0;
  int aiStamp = -1;
  bool collecting = false; // آخر الشهر: ننتظر اللاعب يجمع العملات
  bool fixing = false; // لعبة تصليح المولدة مفتوحة
  int? visiting; // رقم البيت اللي داخله، أو -1 للجايخانة
  int speed = 1;

  // لحظات الحركة
  double alarm = 0;
  double thiefTime = 0;
  int thiefPole = 0;
  int thievesCaught = 0;
  int alarmsSaved = 0;

  final List<String> _late = [];
  final List<String> _left = [];

  double clock = 0; // للحركة
  double _dayTimer = secondsPerDay * 0.3; // نبدي الصبح
  double _saveTimer = 0;
  double _toastTimer = 0;

  GameEvent? currentEvent;
  MonthReport? report;
  String? toast;
  int? selected; // رقم البيت، أو -1 للمولدة

  static List<House> _defaultHouses() => [
        House(name: 'بيت أبو محمد', owner: 'أبو محمد', amps: 5, maxPrice: 16000, subscribed: true, lazy: 0.15),
        House(name: 'بيت الحجية أم علي', owner: 'الحجية أم علي', amps: 3, maxPrice: 14000, subscribed: true, lazy: 0.02),
        House(name: 'بيت أبو حسين', owner: 'أبو حسين', amps: 6, maxPrice: 18000, subscribed: true, lazy: 0.1),
        House(name: 'دكان جاسم', owner: 'جاسم', amps: 8, maxPrice: 22000, subscribed: true, lazy: 0.05),
        House(name: 'بيت الأستاذ كريم', owner: 'الأستاذ كريم', amps: 4, maxPrice: 17000, subscribed: true, lazy: 0.05),
        House(name: 'بيت أم زينب', owner: 'أم زينب', amps: 5, maxPrice: 15000, subscribed: true, lazy: 0.1),
        House(name: 'بيت أبو سجاد', owner: 'أبو سجاد', amps: 6, maxPrice: 16000, lazy: 0.3),
        House(name: 'صالون حيدر', owner: 'حيدر الحلاق', amps: 7, maxPrice: 20000, lazy: 0.1),
        House(name: 'بيت أبو مصطفى', owner: 'أبو مصطفى', amps: 5, maxPrice: 15000, lazy: 0.2),
        House(name: 'بيت الحاج عباس', owner: 'الحاج عباس', amps: 10, maxPrice: 21000, lazy: 0.05),
        House(name: 'بيت أبو علاوي', owner: 'أبو علاوي', amps: 6, maxPrice: 17000, lazy: 0.15),
        House(name: 'عيادة الدكتور سعد', owner: 'الدكتور سعد', amps: 9, maxPrice: 23000, lazy: 0.02),
        House(name: 'بيت أم حسين', owner: 'أم حسين', amps: 4, maxPrice: 14500, lazy: 0.1),
        House(name: 'بيت أبو كرار', owner: 'أبو كرار', amps: 7, maxPrice: 18000, lazy: 0.25),
        House(name: 'محل موبايلات ستار', owner: 'ستار', amps: 6, maxPrice: 21000, lazy: 0.1),
        House(name: 'بيت الشيخ عبد الله', owner: 'الشيخ عبد الله', amps: 8, maxPrice: 19000, lazy: 0.05),
      ];

  // ---------- قراءات ----------
  bool get tutorialActive => tutorialStep < tutorialCount;
  bool get overlayOpen => currentEvent != null || report != null || fixing || visiting != null || tutorialActive;
  bool get paused => overlayOpen || collecting;
  bool get generating => running && !broken && fuel > 0;
  bool houseLit(House h) => nationalOn || (h.subscribed && generating && !h.wireCut);
  bool priceTooHigh(House h) => ampPrice * h.rate > h.maxPrice;
  int get load => houses.where((h) => h.subscribed).fold(0, (a, h) => a + h.amps);
  double get effectiveLoad => nationalOn ? load * 0.3 : load.toDouble();
  bool get overloaded => generating && effectiveLoad > capacityAmps;
  double get dayProgress => _dayTimer / secondsPerDay;
  double get light => 0.5 + 0.5 * sin(2 * pi * (dayProgress - 0.25));
  bool get isNight => light < 0.3;
  int get subscribers => houses.where((h) => h.subscribed).length;
  int get upgradeCost => genLevel == 1 ? 1500000 : (genLevel == 2 ? 4000000 : 0);
  Mission? get mission => missionIndex < missions.length ? missions[missionIndex] : null;
  int get pendingTotal => houses.fold(0, (a, h) => a + h.pending);
  int get _stamp => month * 100 + day;

  double _dist(Offset a) => sqrt((px - a.dx) * (px - a.dx) + (py - a.dy) * (py - a.dy));

  /// أقرب بيت للاعب (إذا قريب كفاية يدخله)
  int? get nearHouse {
    int? best;
    var bd = 1.05;
    for (var i = 0; i < houseCount; i++) {
      final d = _dist(housePos(i));
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  bool get nearTea => _dist(teaPos) < 1.2;
  bool get nearBakery => _dist(bakeryPos) < 1.2;
  /// واجب تصليح واير لبيت قريب
  Quest? get nearFix {
    final n = nearHouse;
    if (n == null) return null;
    for (final q in quests) {
      if (q.type == QuestType.fixWire && q.house == n) return q;
    }
    return null;
  }
  bool get nearGenerator => _dist(genPos) < 1.2;

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

  // ---------- الحركة ----------
  bool _blocked(double x, double y) {
    if (x < minX || x > maxX || y < minY || y > maxY) return true;
    bool inBox(Offset c, double half) => (x - c.dx).abs() < half && (y - c.dy).abs() < half;
    for (var i = 0; i < houseCount; i++) {
      if (inBox(housePos(i), 0.56)) return true;
    }
    if (inBox(genPos, 0.6)) return true;
    for (final b in [teaPos, mosquePos, bakeryPos, ...shops]) {
      if (inBox(b, 0.6)) return true;
    }
    return false;
  }

  void setMove(double x, double y) {
    moveX = x;
    moveY = y;
  }

  void _movePlayer(double dt) {
    if (!walking) return;
    // من اتجاه الشاشة لاتجاه الشبكة المائلة
    var gx = moveX + 2 * moveY;
    var gy = 2 * moveY - moveX;
    final len = sqrt(gx * gx + gy * gy);
    if (len < 0.01) return;
    final mag = min(1.0, sqrt(moveX * moveX + moveY * moveY));
    gx = gx / len * walkSpeed * mag * dt;
    gy = gy / len * walkSpeed * mag * dt;
    if (moveX.abs() > 0.1) faceX = moveX.sign;
    if (!_blocked(px + gx, py + gy)) {
      px += gx;
      py += gy;
    } else if (!_blocked(px + gx, py)) {
      px += gx;
    } else if (!_blocked(px, py + gy)) {
      py += gy;
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
    if (!overlayOpen) {
      final wasNear = '${nearHouse}_${nearTea}_$nearGenerator';
      _movePlayer(dt);
      _tickAction(dt);
      if ('${nearHouse}_${nearTea}_$nearGenerator' != wasNear) notifyListeners();
    }
    if (paused) return;
    _dayTimer += dt * speed;
    if (_dayTimer >= secondsPerDay) {
      _dayTimer -= secondsPerDay;
      _advanceDay(events: true);
      notifyListeners();
    }
  }

  /// العدادات اللي تحتاج سرعة من اللاعب (تمشي بالوكت الحقيقي)
  void _tickAction(double dt) {
    if (collecting) {
      for (var i = 0; i < houseCount; i++) {
        final h = houses[i];
        if (h.pending <= 0) continue;
        if (_dist(housePos(i)) < 1.3) {
          collect(i);
          continue;
        }
        h.coinTime -= dt;
        if (h.coinTime <= 0) {
          h.debt += h.pending;
          h.pending = 0;
          _late.add(h.name);
          h.say('هرب! 🏃');
          if (pendingTotal == 0) _finishMonth();
          notifyListeners();
        }
      }
      return;
    }
    for (final h in houses) {
      if (h.requestTime > 0) h.requestTime -= dt;
    }
    _tickQuests();
    if (alarm > 0) {
      if (generating || nationalOn) {
        alarm = 0;
        notifyListeners();
      } else {
        final before = alarm.ceil();
        alarm -= dt;
        if (alarm.ceil() != before && alarm > 0) notifyListeners();
        if (alarm <= 0) {
          alarm = 0;
          satisfaction = max(0.0, satisfaction - 12);
          for (final h in houses.where((h) => h.subscribed).take(4)) {
            h.say('طفت!! 😡');
          }
          showToast('تأخرت! الناس زعلت');
          notifyListeners();
        }
      }
    }
    if (thiefTime > 0) {
      if (_dist(poles[thiefPole]) < 1.0) {
        catchThief();
        return;
      }
      thiefTime -= dt;
      if (thiefTime <= 0) {
        thiefTime = 0;
        penalty(40000);
        final victims = [
          for (var i = 0; i < houseCount; i++)
            if (houses[i].subscribed && !houses[i].wireCut && !quests.any((q) => q.house == i)) i
        ];
        if (victims.isNotEmpty) {
          final v = victims[_rnd.nextInt(victims.length)];
          houses[v].wireCut = true;
          houses[v].say('انگص الواير! 😱');
          quests.add(Quest(QuestType.fixWire, v, 10000, daysLeft: 2));
          showToast('الحرامي گص واير ${houses[v].owner} وهرب! روح صلّحه 🔧');
        } else {
          showToast('الحرامي بالواير وهرب! خسرت 40,000');
        }
        notifyListeners();
      }
    }
  }

  void _tickQuests() {
    for (final q in List.of(quests)) {
      if (q.type != QuestType.delivery) continue;
      if (!q.picked) {
        final src = q.from == 0 ? bakeryPos : teaPos;
        if (_dist(src) < 1.3) {
          q.picked = true;
          showToast('أخذت ${q.item} 🛍️ هسه وصّله لـ ${houses[q.house].owner}');
          notifyListeners();
        }
      } else if (_dist(housePos(q.house)) < 1.2) {
        _completeQuest(q, '${houses[q.house].owner}: تسلم إيدك! 🙏');
      }
    }
  }

  void _completeQuest(Quest q, String msg) {
    quests.remove(q);
    questsDone++;
    earn(q.reward);
    satisfaction = min(100.0, satisfaction + 3);
    houses[q.house].say('تسلم! 🙏');
    showToast('📋 خلص الواجب: $msg\n+${fmt(q.reward)} د.ع');
    notifyListeners();
  }

  void _spawnQuest() {
    if (quests.length >= 3) return;
    final busy = quests.map((q) => q.house).toSet();
    final free = [for (var i = 0; i < houseCount; i++) if (!busy.contains(i)) i];
    if (free.isEmpty) return;
    final h = free[_rnd.nextInt(free.length)];
    if (_rnd.nextBool()) {
      final fromTea = _rnd.nextDouble() < 0.4;
      final item = fromTea ? 'جاي' : _pick(['صمون حار', 'كيس صمون', 'خبز تنور']);
      quests.add(Quest(QuestType.delivery, h, 15000 + _rnd.nextInt(3) * 5000, item: item, from: fromTea ? 1 : 0));
    } else {
      quests.add(Quest(QuestType.visit, h, 20000));
    }
    showToast('📋 واجب جديد: ${quests.last.title(houses)}');
  }

  /// زر "صلّح الواير"
  void fixWire() {
    final q = nearFix;
    if (q == null) return;
    houses[q.house].wireCut = false;
    _completeQuest(q, 'رجعت الكهرباء لبيت ${houses[q.house].owner} 💡');
  }

  House? _randomSub() {
    final subs = houses.where((h) => h.subscribed).toList();
    return subs.isEmpty ? null : subs[_rnd.nextInt(subs.length)];
  }

  void _advanceDay({required bool events}) {
    // الوطنية تجي وتروح
    if (_rnd.nextDouble() < 0.45) {
      nationalOn = !nationalOn;
      if (events) {
        if (!nationalOn && !generating && !broken && fuel > 0) {
          alarm = alarmSeconds;
          showToast('طفت الوطنية! شغّل المولدة بسرعة ⚡');
        } else {
          showToast(nationalOn
              ? (running ? 'جات الوطنية! طفّي المولدة ووفّر الكاز' : 'جات الوطنية!')
              : 'طفت الوطنية! الحي كله على مولدتك');
        }
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
      final use = nationalOn ? 6.0 * k : (3 + effectiveLoad * 0.25) * k;
      fuel = max(0.0, fuel - use);
      health -= (overloaded ? 4 : 0.8) * k;
      if (!nationalOn) satisfaction += (overloaded ? -2 : 1) * k;
      if (overloaded && events) _randomSub()?.say('الضغط واطي!');
      if (fuel == 0 && events) showToast('خلص الكاز! المولدة طفت');
    } else if (!nationalOn) {
      satisfaction -= 4 * k;
      if (events) {
        _randomSub()?.say('طفت!');
        _randomSub()?.say('وين الكهرباء؟!');
      }
    }

    // أثر السعر على رضا الناس
    satisfaction += (fairPrice - ampPrice) / 2500 * k;

    // الأعطال
    if (!broken && (health <= 0 || (health < 30 && _rnd.nextDouble() < 0.25))) {
      _breakdown(events);
    }

    // اللي السعر غالي عليه يترك
    for (final h in houses.where((h) => h.subscribed).toList()) {
      if (priceTooHigh(h) && _rnd.nextDouble() < 0.35) {
        h.subscribed = false;
        _left.add(h.name);
        if (events) h.say('غالي! تركتك');
      }
    }

    // رضا واطي = الناس تترك، رضا عالي = يمكن واحد يشترك
    if (satisfaction < 30 && _rnd.nextDouble() < 0.45) {
      final h = _randomSub();
      if (h != null) {
        h.subscribed = false;
        _left.add(h.name);
        if (events) h.say('تركتك!');
      }
    } else if (satisfaction > 65 && _rnd.nextDouble() < 0.25) {
      final non = houses.where((h) => !h.subscribed && !priceTooHigh(h)).toList();
      if (non.isNotEmpty) {
        final h = non[_rnd.nextInt(non.length)];
        h.subscribed = true;
        if (events) {
          h.say('اشتركت!');
          showToast('اشترك ${h.owner} بـ ${h.amps} أمبير');
        }
      }
    }

    // سعر الكاز يتغير كل 3 أيام
    if (day % 3 == 0) {
      final f = 0.85 + _rnd.nextDouble() * 0.3;
      fuelPrice = (fuelPrice * f).round().clamp(700, 1800);
      if (events) showToast('سعر الكاز صار ${fmt(fuelPrice)} للتر');
    }

    // حرامي واير
    if (events && thiefTime <= 0 && _rnd.nextDouble() < 0.3) {
      thiefTime = thiefSeconds;
      thiefPole = _rnd.nextInt(poles.length);
      showToast('🦹 حرامي واير على عمود! اركض لعنده');
    }

    // طلبات أمبير زيادة
    if (events) {
      for (var n = 0; n < 2; n++) {
        if (_rnd.nextDouble() < 0.4) {
          final cand = houses.where((h) => h.subscribed && h.requestTime <= 0 && h.amps < 15).toList();
          if (cand.isNotEmpty) cand[_rnd.nextInt(cand.length)].requestTime = 10;
        }
      }
    }

    // الواجبات: تنتهي إذا تأخرت، وتجي جديدة
    for (final q in List.of(quests)) {
      q.daysLeft--;
      if (q.daysLeft <= 0) {
        quests.remove(q);
        satisfaction -= 4;
        if (q.type == QuestType.fixWire) houses[q.house].wireCut = false;
        if (events) showToast('📋 فات وكت الواجب: ${q.title(houses)} 😞');
      }
    }
    if (events && _rnd.nextDouble() < 0.6) _spawnQuest();

    // حدث عشوائي
    if (events && currentEvent == null && _rnd.nextDouble() < 0.25) {
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
      if (currentEvent!.title != EventLibrary.burnedTitle) repairDays = 2;
    } else {
      repairDays = 2;
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
        h.coinTime = coinSeconds + _rnd.nextDouble() * 5;
      }
    }
    day = 1;
    month++;
    if (pendingTotal > 0) {
      collecting = true;
      showToast('آخر الشهر! امشِ لعند العملات واجمعها قبل ما يهربون 🏃');
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

  /// عامل الجباية يجمع الباقي ويأخذ 10%
  void collectAll() {
    var total = 0;
    for (final h in houses) {
      if (h.pending > 0) {
        total += h.pending;
        h.pending = 0;
      }
    }
    final fee = (total * 0.1).round();
    earn(total - fee);
    totalCollected += total;
    if (total > 0) showToast('العامل جمعهم وأخذ ${fmt(fee)} حقه');
    if (collecting) _finishMonth();
    notifyListeners();
  }

  void toggleRunning() {
    running = !running;
    if (running && alarm > 0 && generating) {
      alarm = 0;
      alarmsSaved++;
      satisfaction = min(100.0, satisfaction + 4);
      showToast('لحگت! الناس ما حست بالانقطاع 👏');
    } else {
      showToast(running ? 'شغّلت المولدة' : 'طفّيت المولدة');
    }
    notifyListeners();
  }

  void toggleSpeed() {
    speed = speed == 1 ? 2 : (speed == 2 ? 3 : 1);
    notifyListeners();
  }

  void catchThief() {
    if (thiefTime <= 0) return;
    thiefTime = 0;
    thievesCaught++;
    earn(30000);
    satisfaction = min(100.0, satisfaction + 3);
    showToast('مسكته! 👮 الجيران كافؤوك 30,000');
    notifyListeners();
  }

  /// الضغط على الحرامي من بعيد ما يكفي
  void tapThief() {
    if (_dist(poles[thiefPole]) < 2.2) {
      catchThief();
    } else {
      showToast('بعيد! اركض لعند العمود 🏃');
      notifyListeners();
    }
  }

  void acceptRequest(int i) {
    final h = houses[i];
    if (h.requestTime <= 0) return;
    h.requestTime = 0;
    final extra = 1 + _rnd.nextInt(2);
    h.amps += extra;
    satisfaction = min(100.0, satisfaction + 1);
    h.say('شكراً! +$extra أمبير');
    notifyListeners();
  }

  void startFix() {
    currentEvent = null;
    fixing = true;
    notifyListeners();
  }

  void fixResult(bool success) {
    fixing = false;
    if (success) {
      broken = false;
      repairDays = 0;
      health = 75;
      showToast('صلّحتها بإيدك! 🔧 ما دفعت ولا فلس');
    } else {
      repairDays = 2;
      spend(60000);
      showToast('ما لحگت... جبت فيتر، يومين وتخلص');
    }
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

  /// من بطاقة البيت: الدين يتطالب وجهاً لوجه
  void collectDebt(int i) {
    if (nearHouse == i) {
      enterHouse(i);
    } else {
      showToast('امشِ لبيت ${houses[i].owner} وادخل طالبه وجهاً لوجه 🚪');
      notifyListeners();
    }
  }

  void tapHouse(int i) {
    if (houses[i].pending > 0) {
      if (_dist(housePos(i)) < 2.2) {
        collect(i);
      } else {
        showToast('امشِ لبيت ${houses[i].owner} حتى تاخذ الفلوس');
        notifyListeners();
      }
    } else if (houses[i].requestTime > 0) {
      acceptRequest(i);
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

  // ---------- الزيارات والسوالف ----------
  void enterHouse(int i) {
    moveX = 0;
    moveY = 0;
    selected = null;
    visiting = i;
    if (i >= 0) {
      for (final q in List.of(quests)) {
        if (q.type == QuestType.visit && q.house == i) _completeQuest(q, '${houses[i].owner} فرح بزيارتك');
      }
    }
    notifyListeners();
  }

  // ---------- المحادثة الحرة ----------
  /// كم رسالة ذكاء اصطناعي باقية اليوم (حد حتى ما يخلص المفتاح المجاني)
  bool useAiQuota() {
    final today = DateTime.now().day + DateTime.now().month * 100;
    if (aiStamp != today) {
      aiStamp = today;
      aiCount = 0;
    }
    if (aiCount >= aiDailyLimit) return false;
    aiCount++;
    return true;
  }

  /// سياق صاحب البيت يروح للذكاء الاصطناعي
  Map<String, dynamic> npcContext(int i) {
    final h = houses[i];
    return {
      'owner': h.owner,
      'place': h.name,
      'subscribed': h.subscribed,
      'amps': h.amps,
      'debt': h.debt,
      'price': ampPrice,
      'maxPrice': h.maxPrice,
      'lit': houseLit(h),
      'satisfaction': satisfaction.round(),
      'national': nationalOn,
      'wireCut': h.wireCut,
    };
  }

  /// نطبّق قرار صاحب البيت بعد المحادثة (مع تحقق حتى ما ينغش)
  String? applyNpcAction(int i, String action) {
    final h = houses[i];
    String? note;
    switch (action) {
      case 'pay_debt':
        if (h.debt > 0) {
          note = '💵 دفع ${fmt(h.debt)} د.ع';
          earn(h.debt);
          h.debt = 0;
        }
      case 'subscribe':
        if (!h.subscribed && !priceTooHigh(h)) {
          h.subscribed = true;
          convinced++;
          note = '🤝 اشترك بـ ${h.amps} أمبير';
        }
      case 'buy_amps':
        if (h.subscribed) {
          final extra = 1 + _rnd.nextInt(2);
          h.amps += extra;
          note = '⚡ زاد $extra أمبير';
        }
      case 'happy':
        satisfaction = min(100.0, satisfaction + 1.5);
      case 'angry':
        satisfaction = max(0.0, satisfaction - 2);
        note = '😠 زعل';
    }
    chats++;
    notifyListeners();
    return note;
  }

  void enterTea() => enterHouse(-1);

  void leave() {
    visiting = null;
    notifyListeners();
  }

  String _pick(List<String> l) => l[_rnd.nextInt(l.length)];

  String greet(int i) {
    final h = houses[i];
    if (!h.subscribed) {
      return priceTooHigh(h) ? 'هلا ابني... سمعنا مولدتك غالية 🤨' : 'هلا بيك! تفضل، والله جنا نحچي عليك';
    }
    if (!houseLit(h)) return 'هلا... بس الكهرباء طافية! شنو القصة؟ 😠';
    if (h.debt > 0) return 'هلا عيني... إي أدري عليّ دين 😅';
    if (satisfaction > 70) return 'هلا بيك! الله يخليك، الكهرباء زينة هالأيام 👍';
    return 'هلا وغلا، تفضل اگعد ☕';
  }

  String chat(int i) {
    final h = houses[i];
    final first = h.lastChat != _stamp;
    h.lastChat = _stamp;
    chats++;
    if (first) satisfaction = min(100.0, satisfaction + 2);
    notifyListeners();
    return _pick([
      'الصيف هالسنة نار، دخيلك لا تطفيها علينا بالظهر!',
      'سمعت أكو واحد يريد يفتح مولدة بالمحلة الثانية...',
      'ابني عنده امتحانات وزارية، دير بالك على الكهرباء بالليل',
      'الوطنية صارت تجي ساعتين وتروح، الله يعينك',
      'أمس الحرامية گصّوا واير بيت جيراننا!',
      'تشرب جاي؟ لا تستحي، البيت بيتك ☕',
      'المبردة ما تبرّد إذا الضغط واطي، انتبه عليها',
      'أبو سجاد يگول للناس ما يدفع إلا تطگ بابه 😂',
    ]);
  }

  String askDebt(int i) {
    final h = houses[i];
    if (h.debt <= 0) return 'ما عليّ شي ابني، دفعت كلشي 🤲';
    if (h.lastDebtAsk == _stamp) return 'هسه طلبتها! اصبر عليّ لباچر';
    h.lastDebtAsk = _stamp;
    if (_rnd.nextDouble() < 0.55) {
      final d = h.debt;
      earn(d);
      h.debt = 0;
      notifyListeners();
      return 'زين ذكرتني، تفضل ${fmt(d)} د.ع 💵';
    }
    satisfaction = max(0.0, satisfaction - 1);
    notifyListeners();
    return _pick([
      'والله الراتب بعده ما نزل، أول ما ينزل أجيبهن',
      'باچر الصبح أدزهن ويه الجاهل',
      'العباس أنطيك، بس هالشهر ضايگة',
      'المولدة طفت علينا يومين وتريد فلوس كاملة؟!',
    ]);
  }

  String offerSub(int i) {
    final h = houses[i];
    if (h.subscribed) return 'آني مشترك وياك أصلاً 😄';
    if (h.lastOffer == _stamp) return 'گلتلك خليني أفكر...';
    h.lastOffer = _stamp;
    if (priceTooHigh(h)) {
      final ok = (h.maxPrice / 1000).floor() * 1000;
      notifyListeners();
      return 'سعرك ${fmt(ampPrice)} غالي علينا. إذا تنزّله لـ ${fmt(ok)} أشترك';
    }
    if (satisfaction < 35) {
      notifyListeners();
      return 'الناس تشتكي من مولدتك... صلّح أمورك وارجعلي';
    }
    h.subscribed = true;
    convinced++;
    notifyListeners();
    return 'اتفقنا! وصّلني ${h.amps} أمبير 🤝';
  }

  String offerAmps(int i) {
    final h = houses[i];
    if (!h.subscribed) return 'بعدني ما مشترك وياك';
    if (h.lastOffer == _stamp) return 'لا عيني، يكفيني اللي عندي';
    h.lastOffer = _stamp;
    if (_rnd.nextDouble() < 0.5) {
      final extra = 1 + _rnd.nextInt(2);
      h.amps += extra;
      notifyListeners();
      return 'زين والله، زيدني $extra أمبير، صار عدنا مبردة ثانية';
    }
    return 'لا، هسه ما أحتاج';
  }

  /// الجايخانة: جاي بـ 1000 وخبر من أخبار المحلة
  String drinkTea() {
    if (!spend(1000)) return 'ما عندك ألف دينار؟! 😅';
    teas++;
    satisfaction = min(100.0, satisfaction + 1);
    final non = houses.where((h) => !h.subscribed).toList();
    final tips = <String>[
      'يگولون الحرامية يطلعون أكثر بالليل، دير بالك على الأعمدة',
      'الشيبان يگولون: المولدة اللي ما تنطفي بالظهر، الناس ما تتركها',
      'سعر الكاز يتغير كل كم يوم، اشتري لما يرخص',
      'إذا تخلي المولدة شغالة والوطنية جاية تحرق كاز على الفاضي',
      if (non.isNotEmpty)
        () {
          final h = non[_rnd.nextInt(non.length)];
          return 'سمعت ${h.owner} يشترك إذا السعر ${fmt((h.maxPrice / 1000).floor() * 1000)} أو أقل';
        }(),
      if (houses.any((h) => h.debt > 0))
        'يگولون ${houses.firstWhere((h) => h.debt > 0).owner} عليه دين وما يدفع إلا تروحله لبيته',
    ];
    notifyListeners();
    return '☕ (تشرب جاي) ${_pick(tips)}';
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
        'thieves': thievesCaught,
        'alarms': alarmsSaved,
        'chats': chats,
        'teas': teas,
        'convinced': convinced,
        'quests': questsDone,
        'px': px,
        'py': py,
        'houses': houses.map((h) => h.toJson()).toList(),
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };

  void _fromJson(Map<String, dynamic> j) {
    int gi(String key, int d) => (j[key] as num?)?.toInt() ?? d;
    double gd(String key, double d) => (j[key] as num?)?.toDouble() ?? d;
    final hs = (j['houses'] as List).map((e) => House.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    if (hs.length == houseCount) houses = hs;
    money = gi('money', 500000);
    fuel = gd('fuel', 200);
    fuelCapacity = gd('fuelCap', 400);
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
    thievesCaught = gi('thieves', 0);
    alarmsSaved = gi('alarms', 0);
    chats = gi('chats', 0);
    teas = gi('teas', 0);
    convinced = gi('convinced', 0);
    questsDone = gi('quests', 0);
    px = gd('px', 3.5);
    py = gd('py', 2.3);
    if (_blocked(px, py)) {
      px = 3.5;
      py = 2.3;
    }
    for (final h in houses) {
      if (h.pending > 0) h.coinTime = coinSeconds;
    }
    if (collecting && pendingTotal == 0) collecting = false;
    if (broken && repairDays == 0) repairDays = 2;
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
    for (var d = 0; d < n; d++) {
      _advanceDay(events: false);
    }
    showToast('وانت غايب مرّت $n يوم على المحلة');
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
