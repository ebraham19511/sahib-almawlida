import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/state.dart';

const _panel = Color(0xE6121826);
const _accent = Color(0xFFE8892B);

class GameHud extends StatelessWidget {
  final GameState state;
  const GameHud({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => Stack(
        children: [
          Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: _TopBar(state: state))),
          Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(child: _BottomBar(state: state))),
          if (state.selected != null && !state.collecting && state.alarm <= 0)
            Positioned(left: 12, right: 12, bottom: 200, child: _InfoCard(state: state)),
          if (state.collecting) Positioned(left: 16, right: 16, bottom: 200, child: _CollectBanner(state: state)),
          if (state.toast != null && !state.tutorialActive)
            Positioned(
              top: 215,
              left: 24,
              right: 24,
              child: SafeArea(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24)),
                    child: Text(state.toast!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            ),
          if (state.alarm > 0 && !state.overlayOpen)
            Positioned(left: 16, right: 16, bottom: 200, child: _AlarmBanner(state: state)),
          if (state.currentEvent != null && !state.tutorialActive) _EventOverlay(state: state),
          if (state.fixing && !state.tutorialActive) _FixGame(key: const ValueKey('fix'), state: state),
          if (state.report != null && !state.tutorialActive) _ReportOverlay(state: state),
          if (state.tutorialActive) _Tutorial(state: state),
        ],
      ),
    );
  }
}

// ---------------- الشريط العلوي ----------------
class _TopBar extends StatelessWidget {
  final GameState state;
  const _TopBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final m = state.mission;
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.payments, color: Color(0xFF66BB6A), size: 20),
              const SizedBox(width: 6),
              Text('${fmt(state.money)} د.ع',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('ش${state.month} · يوم ${state.day}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 6),
              _SmallButton(label: '×${state.speed}', onTap: state.toggleSpeed),
              const SizedBox(width: 4),
              _SmallButton(label: '؟', onTap: state.showHelp),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Meter(
                  icon: Icons.local_gas_station,
                  label: 'الكاز ${state.fuel.round()}/${state.fuelCapacity.round()}',
                  value: state.fuel / state.fuelCapacity,
                  color: const Color(0xFFFFB300),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Meter(
                  icon: Icons.build,
                  label: 'الحالة ${state.health.round()}%',
                  value: state.health / 100,
                  color: const Color(0xFF42A5F5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Meter(
                  icon: Icons.sentiment_satisfied_alt,
                  label: 'الرضا ${state.satisfaction.round()}%',
                  value: state.satisfaction / 100,
                  color: state.satisfaction < 30 ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Chip(
                text: state.nationalOn ? 'الوطنية: جاية' : 'الوطنية: طافية',
                color: state.nationalOn ? const Color(0xFF2E7D32) : const Color(0xFF6D4C41),
              ),
              const SizedBox(width: 6),
              _Chip(
                text: 'الحمل ${state.load}/${state.capacityAmps} أمبير',
                color: state.overloaded ? const Color(0xFFE65100) : const Color(0xFF37474F),
              ),
              const SizedBox(width: 6),
              _Chip(text: 'المشتركين ${state.subscribers}/10', color: const Color(0xFF37474F)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x33FFC107),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFC107)),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag, size: 16, color: Color(0xFFFFC107)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    m == null ? 'خلصت كل المهام! صرت أكبر صاحب مولدة بالزگاق 🏆' : 'المهمة: ${m.title}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (m != null)
                  Text('🎁 ${fmt(m.reward)}', style: const TextStyle(fontSize: 11, color: Color(0xFFFFE082))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF263042),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      );
}

class _Meter extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final Color color;
  const _Meter({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            minHeight: 6,
            color: color,
            backgroundColor: Colors.white12,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Text(text, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
        ),
      );
}

// ---------------- الأزرار السفلية ----------------
class _BottomBar extends StatelessWidget {
  final GameState state;
  const _BottomBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final expensive = s.ampPrice > GameState.fairPrice + 3000;
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('سعر الأمبير:'),
              IconButton(onPressed: () => s.changePrice(-1000), icon: const Icon(Icons.remove_circle_outline)),
              Text(fmt(s.ampPrice),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: expensive ? const Color(0xFFEF5350) : Colors.white,
                  )),
              IconButton(onPressed: () => s.changePrice(1000), icon: const Icon(Icons.add_circle_outline)),
              const Spacer(),
              Text(expensive ? 'غالي! الناس تترك' : 'المعقول ${fmt(GameState.fairPrice)}',
                  style: TextStyle(fontSize: 11, color: expensive ? const Color(0xFFEF5350) : Colors.white60)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: s.running ? Icons.power_settings_new : Icons.play_arrow,
                  label: s.running ? 'طفّي' : 'شغّل',
                  onTap: s.toggleRunning,
                  highlight: !s.running,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionButton(
                  icon: Icons.local_gas_station,
                  label: 'كاز 100 لتر\n${fmt(s.fuelPrice * 100)}',
                  onTap: s.buyFuel,
                  highlight: s.fuel < 60,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionButton(
                  icon: Icons.build,
                  label: 'صيانة\n${fmt(GameState.maintenanceCost)}',
                  onTap: s.maintain,
                  highlight: s.health < 40 && !s.broken,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionButton(
                  icon: Icons.upgrade,
                  label: s.upgradeCost == 0 ? 'أكبر مولدة' : 'طوّر\n${fmt(s.upgradeCost)}',
                  onTap: s.upgrade,
                  highlight: s.upgradeCost > 0 && s.money >= s.upgradeCost,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? _accent : const Color(0xFF263042),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- إنذار انقطاع الوطنية ----------------
class _AlarmBanner extends StatelessWidget {
  final GameState state;
  const _AlarmBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEEB71C1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        children: [
          Text('${state.alarm.ceil()}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('طفت الوطنية! شغّل المولدة قبل ما الناس تزعل',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFB71C1C)),
            onPressed: state.toggleRunning,
            child: const Text('شغّل ⚡'),
          ),
        ],
      ),
    );
  }
}

// ---------------- لعبة التصليح ----------------
class _FixGame extends StatefulWidget {
  final GameState state;
  const _FixGame({super.key, required this.state});

  @override
  State<_FixGame> createState() => _FixGameState();
}

class _FixGameState extends State<_FixGame> {
  static const _parts = [
    (Icons.settings, 'الدينمو'),
    (Icons.bolt, 'الفيوز'),
    (Icons.oil_barrel, 'الزيت'),
    (Icons.cable, 'الواير'),
    (Icons.air, 'الفلتر'),
    (Icons.filter_alt, 'البلف'),
  ];
  static const _need = 6;
  static const _seconds = 9.0;

  final _rnd = Random();
  Timer? _timer;
  double _left = _seconds;
  double _sinceSwitch = 0;
  int _target = 0;
  int _hits = 0;
  int? _wrong;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _target = _rnd.nextInt(_parts.length);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _done) return;
      setState(() {
        _left -= 0.1;
        _sinceSwitch += 0.1;
        if (_sinceSwitch > 0.9) _next();
        if (_left <= 0) _finish(false);
      });
    });
  }

  void _next() {
    var t = _rnd.nextInt(_parts.length);
    if (t == _target) t = (t + 1) % _parts.length;
    _target = t;
    _sinceSwitch = 0;
    _wrong = null;
  }

  void _tap(int i) {
    if (_done) return;
    setState(() {
      if (i == _target) {
        _hits++;
        if (_hits >= _need) {
          _finish(true);
        } else {
          _next();
        }
      } else {
        _wrong = i;
        _left -= 0.5;
      }
    });
  }

  void _finish(bool ok) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    Future.delayed(const Duration(milliseconds: 600), () => widget.state.fixResult(ok));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Dim(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2333),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('صلّح المولدة! 🔧',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _accent)),
            const SizedBox(height: 6),
            Text(
              _done ? (_hits >= _need ? 'اشتغلت! 🎉' : 'خلص الوكت 😓') : 'اضغط على القطعة الحمرة بسرعة ($_hits/$_need)',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_left / _seconds).clamp(0.0, 1.0),
                minHeight: 8,
                color: _left < 3 ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < _parts.length; i++)
                  Material(
                    color: i == _target && !_done
                        ? const Color(0xFFD32F2F)
                        : (i == _wrong ? const Color(0xFF5D4037) : const Color(0xFF263042)),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _tap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_parts[i].$1, size: 30),
                          const SizedBox(height: 4),
                          Text(_parts[i].$2, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- جمع آخر الشهر ----------------
class _CollectBanner extends StatelessWidget {
  final GameState state;
  const _CollectBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107), width: 2),
      ),
      child: Row(
        children: [
          const Text('🪙', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'آخر الشهر! اضغط العملات بسرعة قبل ما يهربون\nباقي ${fmt(state.pendingTotal)} د.ع',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          FilledButton(onPressed: state.collectAll, child: const Text('اجمع الكل')),
        ],
      ),
    );
  }
}

// ---------------- بطاقة البيت أو المولدة ----------------
class _InfoCard extends StatelessWidget {
  final GameState state;
  const _InfoCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final sel = state.selected!;
    final List<Widget> lines;
    Widget? action;
    String title;

    if (sel == -1) {
      title = 'المولدة · ${state.capacityAmps} أمبير';
      final status = state.broken
          ? (state.repairDays > 0 ? 'عاطلة · تتصلّح بعد ${state.repairDays} يوم' : 'عاطلة')
          : !state.running
              ? 'مطفية'
              : state.fuel <= 0
                  ? 'خلص الكاز'
                  : state.overloaded
                      ? 'شغالة · ضغط زايد! طوّرها أو قلّل المشتركين'
                      : 'شغالة';
      lines = [
        Text('الوضع: $status'),
        Text('المستوى ${state.genLevel} · الحمل الحالي ${state.effectiveLoad.round()} أمبير'),
      ];
    } else {
      final h = state.houses[sel];
      title = h.name;
      final tooHigh = state.priceTooHigh(h);
      lines = [
        Text(h.subscribed ? 'مشترك بـ ${h.amps} أمبير' : 'مو مشترك (يحتاج ${h.amps} أمبير)'),
        if (h.rate < 1) Text('عنده خصم ${(100 - h.rate * 100).round()}%'),
        Text(
          tooHigh ? 'رأيه بسعرك: غالي عليه 😠' : 'رأيه بسعرك: مناسب 🙂',
          style: TextStyle(color: tooHigh ? const Color(0xFFEF5350) : const Color(0xFF81C784)),
        ),
        Text(h.debt > 0 ? 'عليه دين ${fmt(h.debt)} د.ع' : 'ما عليه دين'),
        if (!h.subscribed && !tooHigh)
          const Text('إذا الرضا فوك 60% ممكن يشترك', style: TextStyle(fontSize: 11, color: Colors.white60)),
      ];
      if (h.debt > 0) {
        action = FilledButton(onPressed: () => state.collectDebt(sel), child: const Text('طالبه بالدين'));
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            IconButton(onPressed: () => state.select(null), icon: const Icon(Icons.close)),
          ]),
          ...lines,
          if (action != null) Padding(padding: const EdgeInsets.only(top: 8), child: action),
        ],
      ),
    );
  }
}

// ---------------- خلفية معتمة ----------------
class _Dim extends StatelessWidget {
  final Widget child;
  final Alignment align;
  const _Dim({required this.child, this.align = Alignment.center});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: ColoredBox(
            color: const Color(0x99000000),
            child: Align(
              alignment: align,
              child: Padding(padding: const EdgeInsets.all(20), child: child),
            ),
          ),
        ),
      );
}

// ---------------- الشرح ----------------
class _Tutorial extends StatelessWidget {
  final GameState state;
  const _Tutorial({required this.state});

  static const _steps = [
    ('هلا بيك يا صاحب المولدة! 👋', 'هذا زگاقك، والمولدة الخضرة بالنص هي رزقك. الأسلاك توصل للبيوت المشتركة، والشبابيك تضوي إذا وصلتهم الكهرباء.', Alignment.center),
    ('الأرقام فوك ⬆️', 'فلوسك، والكاز، وحالة المولدة، ورضا الناس.\nإذا خلص الكاز تطفي المولدة والناس تزعل. وإذا الحالة نزلت، المولدة تعطل.', Alignment(0, 0.45)),
    ('أزرارك تحت ⬇️', 'تشتري كاز، تسوي صيانة، تطوّر المولدة، وتحدد سعر الأمبير.\nانتبه: السعر الغالي يطلّع الناس، والرخيص ما يربّحك.', Alignment(0, -0.2)),
    ('خليك منتبه! ⚡', 'لما تنقطع الوطنية عندك 5 ثواني تشغّل المولدة.\nإذا شفت حرامي 🦹 على عمود اضغط عليه بسرعة.\nوإذا طلع ⚡ أخضر فوك بيت، اضغطه حتى تبيعه أمبيرات زيادة.', Alignment.center),
    ('آخر كل شهر 🪙', 'تطلع عملات فوك البيوت، اضغطها بسرعة قبل ما يخلص عدادها ويهرب صاحبها!\nوإذا عطلت المولدة تگدر تصلّحها بإيدك ببلاش.', Alignment.center),
    ('يلا نبدي! 🎯', 'تابع المهمة بالشريط الأصفر فوك، وكل مهمة إلها جائزة.\nاضغط على أي بيت حتى تشوف تفاصيله، وزر ؟ يرجّعلك هذا الشرح.', Alignment.center),
  ];

  @override
  Widget build(BuildContext context) {
    final i = state.tutorialStep.clamp(0, _steps.length - 1);
    final step = _steps[i];
    final last = i == _steps.length - 1;
    return _Dim(
      align: step.$3,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2333),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFC107), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(step.$1,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFFFFC107))),
            const SizedBox(height: 10),
            Text(step.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.6)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var k = 0; k < _steps.length; k++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: k == i ? const Color(0xFFFFC107) : Colors.white24,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: state.nextTutorial, child: Text(last ? 'يلا نبدي' : 'التالي')),
          ],
        ),
      ),
    );
  }
}

// ---------------- بطاقة الحدث ----------------
class _EventOverlay extends StatelessWidget {
  final GameState state;
  const _EventOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    final e = state.currentEvent!;
    return _Dim(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2333),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(e.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _accent)),
            const SizedBox(height: 10),
            Text(e.body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 16),
            for (final c in e.choices)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton(onPressed: () => state.choose(c), child: Text(c.label)),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------- تقرير آخر الشهر ----------------
class _ReportOverlay extends StatelessWidget {
  final GameState state;
  const _ReportOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    final r = state.report!;
    final net = r.income - r.spend;
    Widget row(String a, String b, [Color? color]) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Text(a),
            const Spacer(),
            Text(b, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ]),
        );
    return _Dim(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFF1B2333), borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('خلص الشهر ${r.month}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _accent)),
            const SizedBox(height: 12),
            row('الجباية والدخل', '${fmt(r.income)} د.ع', const Color(0xFF66BB6A)),
            row('المصاريف', '${fmt(r.spend)} د.ع', const Color(0xFFEF5350)),
            const Divider(),
            row('الصافي', '${fmt(net)} د.ع', net >= 0 ? const Color(0xFF66BB6A) : const Color(0xFFEF5350)),
            if (r.late.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('گالوا "باچر": ${r.late.join('، ')}', style: const TextStyle(color: Colors.white70)),
            ],
            if (r.left.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('تركوا الاشتراك: ${r.left.toSet().join('، ')}', style: const TextStyle(color: Color(0xFFEF9A9A))),
              const Text('السبب غالباً السعر الغالي أو الانقطاع', style: TextStyle(fontSize: 11, color: Colors.white54)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: state.closeReport, child: const Text('يلا الشهر الجاي')),
          ],
        ),
      ),
    );
  }
}
