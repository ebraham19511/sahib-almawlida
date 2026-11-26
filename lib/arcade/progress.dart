import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

// ======================= المهام اليومية =======================

class MissionType {
  final String id;
  final String icon;
  final String text; // {n} يتبدل بالعدد
  final List<int> goals;
  final int rewardPer; // فلوس لكل وحدة
  const MissionType(this.id, this.icon, this.text, this.goals, this.rewardPer);
}

const missionTypes = [
  MissionType('fix', '⚡', 'صلّح {n} بيت', [15, 25, 40], 6),
  MissionType('thief', '🦹', 'الزم {n} حرامية', [2, 4, 6], 60),
  MissionType('gang', '👊', 'اغلب {n} من العصابة', [3, 6, 10], 35),
  MissionType('stars', '⭐', 'اجمع {n} نجوم', [3, 6, 9], 40),
  MissionType('heli', '🚁', 'صلّح {n} بيوت من الهليكوبتر', [3, 6, 10], 30),
  MissionType('tanker', '🚚', 'وصّل التانكر للمولدة {n} مرات', [1, 2, 3], 120),
  MissionType('play', '🎮', 'العب {n} مراحل', [3, 5, 8], 40),
];

class Mission {
  final MissionType type;
  final int goal;
  int prog = 0;
  bool claimed = false;
  Mission(this.type, this.goal);
  int get reward => goal * type.rewardPer;
  bool get done => prog >= goal;
  String get text => type.text.replaceAll('{n}', '$goal');
}

class DailyMissions {
  String date = '';
  List<Mission> list = [];
  // مكافأة الدخول اليومي
  String loginDate = '';
  int streak = 0;
  bool loginClaimedToday = false;

  static String today() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  int get loginReward => 50 * min(max(streak, 1), 7);
  int get readyCount => list.where((m) => m.done && !m.claimed).length + (loginClaimedToday ? 0 : 1);

  void _newDay(String t) {
    date = t;
    final seed = t.codeUnits.fold<int>(7, (a, b) => a * 31 + b) & 0x7fffffff;
    final r = Random(seed);
    final types = [...missionTypes]..shuffle(r);
    list = [for (final ty in types.take(3)) Mission(ty, ty.goals[r.nextInt(ty.goals.length)])];
  }

  Future<void> load(SharedPreferences p) async {
    final t = today();
    date = p.getString('m_date') ?? '';
    if (date != t) {
      _newDay(t);
    } else {
      _newDay(t); // نفس المهام (نفس البذرة) ونرجّع التقدم
      final prog = p.getStringList('m_prog') ?? [];
      final cl = p.getStringList('m_claim') ?? [];
      for (var i = 0; i < list.length; i++) {
        if (i < prog.length) list[i].prog = int.tryParse(prog[i]) ?? 0;
        if (i < cl.length) list[i].claimed = cl[i] == '1';
      }
    }
    loginDate = p.getString('login_date') ?? '';
    streak = p.getInt('streak') ?? 0;
    loginClaimedToday = loginDate == t;
  }

  Future<void> save(SharedPreferences p) async {
    await p.setString('m_date', date);
    await p.setStringList('m_prog', list.map((m) => '${m.prog}').toList());
    await p.setStringList('m_claim', list.map((m) => m.claimed ? '1' : '0').toList());
    await p.setString('login_date', loginDate);
    await p.setInt('streak', streak);
  }

  /// يزيد تقدم المهمة. يرجّع true إذا خلصت هسه
  bool add(String id, int n) {
    if (date != today()) _newDay(today());
    var finished = false;
    for (final m in list) {
      if (m.type.id != id || m.claimed) continue;
      final wasDone = m.done;
      m.prog = min(m.goal, m.prog + n);
      if (!wasDone && m.done) finished = true;
    }
    return finished;
  }

  /// يرجّع مكافأة الدخول اليومي (0 إذا مستلمة)
  int claimLogin() {
    final t = today();
    if (loginDate == t) return 0;
    // إذا دخل البارحة السلسلة تكمل، وإلا ترجع 1
    final y = DateTime.now().subtract(const Duration(days: 1));
    final yesterday = '${y.year}-${y.month}-${y.day}';
    streak = loginDate == yesterday ? streak + 1 : 1;
    loginDate = t;
    loginClaimedToday = true;
    return loginReward;
  }
}

// ======================= الأشكال (المتجر) =======================

class CosItem {
  final String id;
  final String kind; // hat, trail, truck, heli
  final String icon;
  final String name;
  final int cost;
  final int color; // للون الأثر أو المركبة
  const CosItem(this.id, this.kind, this.icon, this.name, this.cost, [this.color = 0xFFFFFFFF]);
}

const cosItems = [
  CosItem('hat0', 'hat', '🚫', 'بدون', 0),
  CosItem('hat1', 'hat', '⛑️', 'خوذة عامل', 150),
  CosItem('hat2', 'hat', '🧢', 'كاب', 200),
  CosItem('hat3', 'hat', '🤠', 'قبعة كاوبوي', 300),
  CosItem('hat4', 'hat', '🎩', 'قبعة رسمية', 400),
  CosItem('hat5', 'hat', '👑', 'تاج الملك', 900),
  CosItem('trail0', 'trail', '🚫', 'بدون', 0),
  CosItem('trail1', 'trail', '✨', 'نجوم', 250, 0xFFFFF59D),
  CosItem('trail2', 'trail', '🔥', 'نار', 350, 0xFFFF6D00),
  CosItem('trail3', 'trail', '💧', 'مي', 350, 0xFF40C4FF),
  CosItem('trail4', 'trail', '⚡', 'كهرباء', 600, 0xFF18FFFF),
  CosItem('truck0', 'truck', '🚙', 'أحمر (الأصلي)', 0, 0xFFFFFFFF),
  CosItem('truck1', 'truck', '🔵', 'أزرق', 250, 0xFF90CAF9),
  CosItem('truck2', 'truck', '🟢', 'أخضر', 250, 0xFFA5D6A7),
  CosItem('truck3', 'truck', '🟡', 'ذهبي', 700, 0xFFFFE082),
  CosItem('heli0', 'heli', '🔴', 'أحمر (الأصلي)', 0, 0xFFE53935),
  CosItem('heli1', 'heli', '🔵', 'أزرق', 300, 0xFF1E88E5),
  CosItem('heli2', 'heli', '⚫', 'أسود', 400, 0xFF37474F),
  CosItem('heli3', 'heli', '🟡', 'ذهبي', 900, 0xFFFFB300),
];

class Cosmetics {
  final Set<String> owned = {'hat0', 'trail0', 'truck0', 'heli0'};
  final Map<String, String> equipped = {'hat': 'hat0', 'trail': 'trail0', 'truck': 'truck0', 'heli': 'heli0'};

  CosItem item(String id) => cosItems.firstWhere((e) => e.id == id, orElse: () => cosItems.first);
  CosItem eq(String kind) => item(equipped[kind] ?? '${kind}0');

  Future<void> load(SharedPreferences p) async {
    owned.addAll(p.getStringList('cos_owned') ?? const []);
    for (final k in equipped.keys.toList()) {
      final v = p.getString('cos_$k');
      if (v != null && owned.contains(v)) equipped[k] = v;
    }
  }

  Future<void> save(SharedPreferences p) async {
    await p.setStringList('cos_owned', owned.toList());
    for (final e in equipped.entries) {
      await p.setString('cos_${e.key}', e.value);
    }
  }
}
