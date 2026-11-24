import 'dart:math';

import 'state.dart';

typedef EventAction = String? Function(GameState s);

class EventChoice {
  final String label;
  final EventAction apply;
  const EventChoice(this.label, this.apply);
}

class GameEvent {
  final String title;
  final String body;
  final List<EventChoice> choices;
  const GameEvent(this.title, this.body, this.choices);
}

/// كل المواقف. لإضافة حدث جديد: اكتب دالة ترجع GameEvent وضيفها بقائمة random
class EventLibrary {
  static const burnedTitle = 'احترگت الدينمو!';

  static GameEvent burnedDynamo() => GameEvent(
        burnedTitle,
        'المولدة وكفت والحي كله يصيح "طفت!". شتسوي؟',
        [
          EventChoice('تصليح سريع (150,000)', (s) {
            if (!s.spend(150000)) {
              s.repairDays = 5;
              return 'ما عندك فلوس، راح تتصلّح على مهل (5 أيام)';
            }
            s.broken = false;
            s.health = 80;
            return 'تصلّحت بنفس اليوم';
          }),
          EventChoice('تصليح رخيص (60,000) - 3 أيام', (s) {
            if (!s.spend(60000)) {
              s.repairDays = 6;
              return 'حتى الرخيص ما يكفي... 6 أيام';
            }
            s.repairDays = 3;
            s.satisfaction -= 3;
            return 'الفيتر گال: 3 أيام وتخلص';
          }),
        ],
      );

  static GameEvent? random(GameState s, Random r) {
    final options = <GameEvent? Function()>[
      () => _hiddenWire(s, r),
      () => _abuMohammed(s),
      () => _inspection(),
      () => _wedding(s, r),
      () => _competitor(),
    ];
    options.shuffle(r);
    for (final o in options) {
      final e = o();
      if (e != null) return e;
    }
    return null;
  }

  static GameEvent? _hiddenWire(GameState s, Random r) {
    final non = s.houses.where((h) => !h.subscribed).toList();
    if (non.isEmpty) return null;
    final h = non[r.nextInt(non.length)];
    return GameEvent(
      'السحب المخفي',
      'لزمت ${h.name} موصلين واير على مولدتك بدون اشتراك!',
      [
        EventChoice('تفضحه گدام الجيران', (s) {
          if (s.rnd.nextBool()) {
            h.subscribed = true;
            s.satisfaction += 3;
            return 'استحى واشترك بـ ${h.amps} أمبير';
          }
          s.satisfaction -= 2;
          return 'زعل وگص الواير';
        }),
        EventChoice('تساومه على 3 أمبير', (s) {
          h.subscribed = true;
          h.amps = 3;
          return '${h.name} صار مشترك بـ 3 أمبير';
        }),
      ],
    );
  }

  static GameEvent? _abuMohammed(GameState s) {
    final h = s.houses[0];
    if (h.rate < 1) return null;
    return GameEvent(
      'أبو محمد والـ 10 أمبير',
      'أبو محمد يريد 10 أمبير بسعر 5، ويگول: "إحنا جيران من زمان".',
      [
        EventChoice('توافق', (s) {
          h.subscribed = true;
          h.amps = 10;
          h.rate = 0.5;
          s.satisfaction += 5;
          return 'أبو محمد يمدحك بالگهوة';
        }),
        EventChoice('خصم 20% بس', (s) {
          h.subscribed = true;
          h.amps = 10;
          h.rate = 0.8;
          s.satisfaction += 2;
          return 'تفاهمتوا على خصم';
        }),
        EventChoice('ترفض', (s) {
          s.satisfaction -= 3;
          return 'أبو محمد زعلان ويحچي عليك';
        }),
      ],
    );
  }

  static GameEvent _inspection() => GameEvent(
        'تفتيش البلدية',
        'المفتش شاف الأسلاك المتشابكة فوك الشارع وسجّل ملاحظة.',
        [
          EventChoice('ترتّبها (100,000)', (s) {
            if (!s.spend(100000)) {
              s.penalty(250000);
              return 'ما گدرت ترتبها، وانطوك غرامة';
            }
            s.satisfaction += 2;
            return 'صار الزگاق أرتب';
          }),
          EventChoice('تأجّل وتجازف', (s) {
            if (s.rnd.nextBool()) {
              s.penalty(250000);
              return 'رجع المفتش: غرامة 250,000';
            }
            return 'المفتش نسى... هالمرة';
          }),
        ],
      );

  static GameEvent _wedding(GameState s, Random r) {
    final h = s.houses[r.nextInt(s.houses.length)];
    return GameEvent(
      'عرس بالحي',
      '${h.name} عندهم عرس ويريدون الكهرباء طول الليل.',
      [
        EventChoice('مجاناً (سمعة)', (s) {
          s.fuel -= 20;
          s.satisfaction += 10;
          return 'الحي كله يدعيلك';
        }),
        EventChoice('بأجر 75,000', (s) {
          s.fuel -= 20;
          s.earn(75000);
          s.satisfaction -= 1;
          return 'ربحت 75,000';
        }),
      ],
    );
  }

  static GameEvent _competitor() => GameEvent(
        'مولدة منافسة',
        'واحد فتح مولدة بالزگاق الثاني بسعر أرخص منك.',
        [
          EventChoice('تنزّل سعرك 2,000', (s) {
            s.ampPrice = (s.ampPrice - 2000).clamp(5000, 40000);
            return 'نزلت السعر، والناس ارتاحت';
          }),
          EventChoice('تحسّن الخدمة (80,000)', (s) {
            if (!s.spend(80000)) return null;
            s.health = 100;
            s.satisfaction += 4;
            return 'المولدة صارت مثل الجديدة';
          }),
          EventChoice('ما تهتم', (s) {
            s.satisfaction -= 6;
            return 'بعض الناس يفكرون يتركونك';
          }),
        ],
      );
}
