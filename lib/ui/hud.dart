import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/people.dart';
import '../game/state.dart';

const _panel = Color(0xE6121826);
const _accent = Color(0xFFE8892B);

class GameHud extends StatelessWidget {
  final GameState state;
  const GameHud({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final playing = !state.overlayOpen;
        return Stack(
          children: [
            Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: _TopBar(state: state))),
            Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(child: _BottomBar(state: state))),
            if (playing) Positioned(left: 10, bottom: 205, child: _Joystick(key: const ValueKey('joy'), state: state)),
            if (playing) Positioned(right: 10, bottom: 225, child: _ContextButton(state: state)),
            if (state.selected != null && !state.collecting && state.alarm <= 0)
              Positioned(left: 12, right: 12, top: topInset + 262, child: _InfoCard(state: state)),
            if (state.collecting && playing)
              Positioned(left: 16, right: 16, top: topInset + 262, child: _CollectBanner(state: state)),
            if (state.alarm > 0 && playing)
              Positioned(left: 16, right: 16, top: topInset + 262, child: _AlarmBanner(state: state)),
            if (state.toast != null && !state.tutorialActive)
              Positioned(
                top: topInset + 212,
                left: 24,
                right: 24,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24)),
                    child: Text(state.toast!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            if (state.visiting != null && !state.tutorialActive)
              _Interior(key: ValueKey('visit${state.visiting}'), state: state, index: state.visiting!),
            if (state.currentEvent != null && !state.tutorialActive) _EventOverlay(state: state),
            if (state.fixing && !state.tutorialActive) _FixGame(key: const ValueKey('fix'), state: state),
            if (state.report != null && !state.tutorialActive) _ReportOverlay(state: state),
            if (state.tutorialActive) _Tutorial(state: state),
          ],
        );
      },
    );
  }
}

// ---------------- عصا التحكم ----------------
class _Joystick extends StatefulWidget {
  final GameState state;
  const _Joystick({super.key, required this.state});

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  static const double _r = 55;
  Offset _knob = Offset.zero;

  void _update(Offset local) {
    var v = local - const Offset(_r, _r);
    if (v.distance > _r) v = v / v.distance * _r;
    setState(() => _knob = v);
    final x = v.dx / _r, y = v.dy / _r;
    if (v.distance < 8) {
      widget.state.setMove(0, 0);
    } else {
      widget.state.setMove(x, y);
    }
  }

  void _end() {
    setState(() => _knob = Offset.zero);
    widget.state.setMove(0, 0);
  }

  @override
  void dispose() {
    widget.state.setMove(0, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _end(),
      onPanCancel: _end,
      child: Container(
        width: _r * 2,
        height: _r * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x55000000),
          border: Border.all(color: Colors.white38, width: 2),
        ),
        child: Center(
          child: Transform.translate(
            offset: _knob,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xCCFFC107)),
              child: const Icon(Icons.directions_walk, color: Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- زر "ادخل" حسب مكانك ----------------
class _ContextButton extends StatelessWidget {
  final GameState state;
  const _ContextButton({required this.state});

  @override
  Widget build(BuildContext context) {
    String? label;
    VoidCallback? onTap;
    final near = state.nearHouse;
    if (near != null) {
      final h = state.houses[near];
      label = '🚪 ادخل\n${h.owner}';
      onTap = () => state.enterHouse(near);
    } else if (state.nearTea) {
      label = '☕ ادخل\nالجايخانة';
      onTap = state.enterTea;
    } else if (state.nearGenerator) {
      label = '⚙️ شوف\nالمولدة';
      onTap = () => state.select(-1);
    }
    if (label == null) return const SizedBox.shrink();
    return Material(
      color: _accent,
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ---------------- داخل البيت أو الجايخانة ----------------
class _Interior extends StatefulWidget {
  final GameState state;
  final int index; // -1 = الجايخانة
  const _Interior({super.key, required this.state, required this.index});

  @override
  State<_Interior> createState() => _InteriorState();
}

class _InteriorState extends State<_Interior> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late String _line;

  GameState get s => widget.state;
  bool get _tea => widget.index < 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _line = _tea ? 'هلا بيك يا أبو المولدة! تفضل اگعد، جاي لو حامض؟ ☕' : s.greet(widget.index);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _say(String Function() f) => setState(() => _line = f());

  PersonLook _ownerLook() {
    if (_tea) return PersonLook.oldMan;
    final o = s.houses[widget.index].owner;
    if (o.contains('أم') || o.contains('الحجية')) return PersonLook.abaya;
    if (o.contains('الدكتور')) return PersonLook.doctor;
    if (o.contains('الحاج') || o.contains('الشيخ')) return PersonLook.shemagh;
    if (o.contains('ستار') || o.contains('حيدر') || o.contains('جاسم')) return PersonLook.dishdasha;
    return widget.index.isEven ? PersonLook.shemagh : PersonLook.dishdasha;
  }

  @override
  Widget build(BuildContext context) {
    final house = _tea ? null : s.houses[widget.index];
    final name = _tea ? 'أبو علي (صاحب الجايخانة)' : house!.owner;
    final lit = _tea ? true : s.houseLit(house!);
    final options = <(String, VoidCallback)>[
      if (_tea) ('اشرب جاي (1,000) ☕', () => _say(s.drinkTea)),
      if (!_tea) ('سولف وياه 💬', () => _say(() => s.chat(widget.index))),
      if (!_tea && house!.debt > 0) ('طالبه بالدين 💵', () => _say(() => s.askDebt(widget.index))),
      if (!_tea && !house!.subscribed) ('اقنعه يشترك 🤝', () => _say(() => s.offerSub(widget.index))),
      if (!_tea && house!.subscribed) ('تبيعه أمبيرات ⚡', () => _say(() => s.offerAmps(widget.index))),
      ('مع السلامة 👋', s.leave),
    ];
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xFF0E1320),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_tea ? 'جايخانة أبو علي' : house!.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _accent)),
                    ),
                    if (!_tea)
                      Text(house!.subscribed ? 'مشترك ${house!.amps} أمبير' : 'مو مشترك',
                          style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _RoomPainter(
                      tea: _tea,
                      lit: lit,
                      t: _anim.value,
                      owner: _ownerLook(),
                      seed: widget.index + 3,
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(name, style: const TextStyle(color: Color(0xFFBF360C), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_line, style: const TextStyle(color: Colors.black87, fontSize: 16, height: 1.5)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final o in options) FilledButton(onPressed: o.$2, child: Text(o.$1)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomPainter extends CustomPainter {
  final bool tea;
  final bool lit;
  final double t;
  final PersonLook owner;
  final int seed;
  _RoomPainter({required this.tea, required this.lit, required this.t, required this.owner, required this.seed});

  static const _walls = [0xFFE8D9C0, 0xFFD6E4E5, 0xFFF1E0D6, 0xFFE3E8D2, 0xFFE9DCEB];

  @override
  void paint(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final floorY = h * 0.72;
    final wall = tea ? 0xFFD7C4A3 : _walls[seed % _walls.length];
    c.drawRect(Rect.fromLTWH(0, 0, w, floorY), Paint()..color = Color(wall));
    c.drawRect(Rect.fromLTWH(0, floorY, w, h - floorY), Paint()..color = const Color(0xFF8D6E63));
    // سجادة
    final rug = Rect.fromLTWH(w * 0.12, floorY + 8, w * 0.76, (h - floorY) * 0.75);
    c.drawRect(rug, Paint()..color = const Color(0xFFB71C1C));
    c.drawRect(rug.deflate(6), Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    for (var k = 0; k < 5; k++) {
      final cx = rug.left + rug.width * (k + 0.5) / 5;
      c.drawPath(
        Path()
          ..moveTo(cx, rug.top + 12)
          ..lineTo(cx + 8, rug.center.dy)
          ..lineTo(cx, rug.bottom - 12)
          ..lineTo(cx - 8, rug.center.dy)
          ..close(),
        Paint()..color = const Color(0xFF1A237E),
      );
    }

    if (tea) {
      // سماور وطاولي وصور
      final sam = Offset(w * 0.78, floorY - 10);
      c.drawRect(Rect.fromLTWH(w * 0.68, floorY - 60, w * 0.25, 60), Paint()..color = const Color(0xFF6D4C41));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: sam.translate(0, -85), width: 50, height: 60), const Radius.circular(14)),
          Paint()..color = const Color(0xFFB0BEC5));
      for (var k = 0; k < 4; k++) {
        c.drawRect(Rect.fromLTWH(w * 0.7 + k * 16, floorY - 72, 9, 12), Paint()..color = const Color(0xFFBF360C));
      }
      for (var k = 0; k < 3; k++) {
        final steam = sin(t * 2 * pi + k) * 4;
        c.drawCircle(sam.translate(steam, -125 - k * 12.0), 6 - k.toDouble(), Paint()..color = const Color(0x66FFFFFF));
      }
      c.drawRect(Rect.fromLTWH(w * 0.1, h * 0.12, w * 0.18, h * 0.2), Paint()..color = const Color(0xFF5D4037));
      c.drawRect(Rect.fromLTWH(w * 0.12, h * 0.14, w * 0.14, h * 0.16), Paint()..color = const Color(0xFF90A4AE));
      final board = Rect.fromCenter(center: Offset(w * 0.3, floorY + 2), width: w * 0.22, height: 20);
      c.drawRect(board, Paint()..color = const Color(0xFF795548));
      drawPerson(c, Offset(w * 0.18, floorY + 30), w * 0.9, PersonLook.shemagh, sitting: true, face: 1);
    } else {
      // شباك وستارة
      final win = Rect.fromLTWH(w * 0.08, h * 0.1, w * 0.26, h * 0.3);
      c.drawRect(win, Paint()..color = lit ? const Color(0xFF90CAF9) : const Color(0xFF263238));
      c.drawRect(Rect.fromLTWH(win.left - 6, win.top - 6, win.width * 0.35, win.height + 12), Paint()..color = const Color(0xFF7B1FA2));
      c.drawRect(Rect.fromLTWH(win.right - win.width * 0.3, win.top - 6, win.width * 0.35, win.height + 12),
          Paint()..color = const Color(0xFF7B1FA2));
      // سبلت وهواه
      final ac = Rect.fromLTWH(w * 0.55, h * 0.08, w * 0.32, h * 0.09);
      c.drawRRect(RRect.fromRectAndRadius(ac, const Radius.circular(8)), Paint()..color = Colors.white);
      c.drawLine(Offset(ac.left + 8, ac.bottom - 6), Offset(ac.right - 8, ac.bottom - 6), Paint()
        ..color = const Color(0xFF90A4AE)
        ..strokeWidth = 2);
      if (lit) {
        for (var k = 0; k < 3; k++) {
          final y = ac.bottom + 10 + ((t * 30 + k * 10) % 30);
          c.drawLine(Offset(ac.left + 20 + k * 30, y), Offset(ac.left + 30 + k * 30, y + 6), Paint()
            ..color = const Color(0x8890CAF9)
            ..strokeWidth = 2);
        }
      }
      // تلفزيون وقنفة
      final tv = Rect.fromLTWH(w * 0.62, floorY - 95, w * 0.28, 60);
      c.drawRect(Rect.fromLTWH(w * 0.6, floorY - 35, w * 0.32, 35), Paint()..color = const Color(0xFF5D4037));
      c.drawRect(tv, Paint()..color = const Color(0xFF111111));
      c.drawRect(tv.deflate(4), Paint()..color = lit ? Color.lerp(const Color(0xFF42A5F5), const Color(0xFF66BB6A), (sin(t * 2 * pi) + 1) / 2)! : const Color(0xFF212121));
      final sofa = Rect.fromLTWH(w * 0.05, floorY - 45, w * 0.36, 45);
      c.drawRRect(RRect.fromRectAndRadius(sofa, const Radius.circular(10)), Paint()..color = const Color(0xFF6A1B9A));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(sofa.left, sofa.top - 25, sofa.width, 30), const Radius.circular(10)),
          Paint()..color = const Color(0xFF4A148C));
      // ساعة حايط
      c.drawCircle(Offset(w * 0.46, h * 0.15), 16, Paint()..color = Colors.white);
      final ang = t * 2 * pi;
      c.drawLine(Offset(w * 0.46, h * 0.15), Offset(w * 0.46 + cos(ang) * 11, h * 0.15 + sin(ang) * 11), Paint()
        ..color = Colors.black
        ..strokeWidth = 1.5);
    }

    // پنكة السقف
    final fan = Offset(w * 0.5, 18);
    c.drawLine(Offset(w * 0.5, 0), fan, Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 3);
    final spin = lit ? t * 2 * pi * 3 : 0.3;
    for (var k = 0; k < 3; k++) {
      final a = spin + k * 2 * pi / 3;
      final end = fan + Offset(cos(a) * 60, sin(a) * 8);
      c.drawLine(fan, end, Paint()
        ..color = const Color(0xFF795548)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round);
    }
    // ضوية
    if (lit) {
      c.drawCircle(Offset(w * 0.5, 40), 40, Paint()..color = const Color(0x33FFF59D));
    }

    // صاحب البيت
    drawPerson(c, Offset(w * 0.5, floorY + 40), w * 1.5, owner, face: -1, walkPhase: null);

    // إذا الكهرباء طافية: ظلمة وفانوس
    if (!lit) {
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0x99000000));
      final lamp = Offset(w * 0.75, floorY - 20);
      c.drawCircle(lamp, 70, Paint()..color = const Color(0x33FFB74D));
      c.drawRect(Rect.fromCenter(center: lamp, width: 16, height: 24), Paint()..color = const Color(0xFFFFB74D));
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) => true;
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
              _Chip(text: 'المشتركين ${state.subscribers}/${GameState.houseCount}', color: const Color(0xFF37474F)),
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
              'آخر الشهر! امشِ لعند العملات 🪙 قبل ما يهربون\nباقي ${fmt(state.pendingTotal)} د.ع',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          FilledButton(onPressed: state.collectAll, child: const Text('العامل يجمع\n(ياخذ 10%)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
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
    ('هلا بيك يا صاحب المولدة! 👋', 'هذي محلتك: زگاقين وشارع عام، والمولدة الخضرة بالزگاق هي رزقك. الشبابيك تضوي إذا وصلتهم كهرباءك.', Alignment.center),
    ('امشِ بالمحلة 🚶', 'استعمل عصا التحكم الصفرة يسار الشاشة حتى تمشي. الكاميرا تلحگك، ودير بالك من السيارات بالشارع!', Alignment(0, -0.3)),
    ('ادخل البيوت 🚪', 'لما تقرب من بيت يطلع زر "ادخل" يمين. تدخل وتسولف ويه صاحب البيت، تطالبه بالدين، تقنعه يشترك، أو تبيعه أمبيرات.\nوبالجايخانة تشرب جاي وتسمع أخبار المحلة ☕', Alignment.center),
    ('الأرقام والأزرار', 'فوك: فلوسك، الكاز، حالة المولدة، رضا الناس، والمهمة.\nتحت: سعر الأمبير، كاز، صيانة، تطوير.', Alignment.center),
    ('خليك منتبه! ⚡', 'لما تنقطع الوطنية عندك 5 ثواني تشغّل المولدة.\nإذا طلع حرامي 🦹 على عمود، اركض لعنده تمسكه.\nوالأسهم على حافة الشاشة تدلك وين الشغلة.', Alignment.center),
    ('آخر كل شهر 🪙', 'تطلع عملات فوك البيوت. امشِ لعند كل بيت حتى تاخذ فلوسه قبل ما يخلص العداد ويهرب!\nيلا، الله وياك 🎯', Alignment.center),
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
