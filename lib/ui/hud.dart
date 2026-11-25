import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/npc_chat.dart';
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
        final under = topInset + 128;
        return Stack(
          children: [
            Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: _TopBar(state: state))),
            Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(child: _BottomBar(state: state))),
            if (playing) Positioned(left: 10, bottom: 175, child: _Joystick(key: const ValueKey('joy'), state: state)),
            if (playing) Positioned(right: 14, bottom: 180, child: _SprintButton(state: state)),
            if (playing) Positioned(right: 10, bottom: 275, child: _ContextButton(state: state)),
            if (playing)
              Positioned(left: 10, top: under, child: _QuestButton(state: state)),
            if (playing && state.questsOpen && state.quests.isNotEmpty)
              Positioned(left: 10, top: under + 46, child: _QuestList(state: state)),
            if (state.selected != null && !state.collecting && state.alarm <= 0 && playing)
              Positioned(left: 12, right: 12, top: under + 46, child: _InfoCard(state: state)),
            if (state.collecting && playing)
              Positioned(left: 16, right: 16, top: under + 46, child: _CollectBanner(state: state)),
            if (state.alarm > 0 && playing)
              Positioned(left: 16, right: 16, top: under + 46, child: _AlarmBanner(state: state)),
            if (state.toast != null && !state.tutorialActive)
              Positioned(
                top: under,
                left: 70,
                right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20)),
                    child: Text(state.toast!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            if (state.visiting != null && !state.tutorialActive)
              _Interior(key: ValueKey('visit${state.visiting}'), state: state, index: state.visiting!),
            if (state.currentEvent != null && !state.tutorialActive) _EventOverlay(state: state),
            if (state.fixing && !state.tutorialActive) _FixGame(key: const ValueKey('fix'), state: state),
            if (state.pumping && !state.tutorialActive) _PumpGame(key: const ValueKey('pump'), state: state),
            if (state.football && !state.tutorialActive) _PenaltyGame(key: const ValueKey('ball'), state: state),
            if (state.report != null && !state.tutorialActive) _ReportOverlay(state: state),
            if (state.tutorialActive) _Tutorial(state: state),
          ],
        );
      },
    );
  }
}

// ---------------- زر الركض ----------------
class _SprintButton extends StatelessWidget {
  final GameState state;
  const _SprintButton({required this.state});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => state.setSprint(true),
      onTapUp: (_) => state.setSprint(false),
      onTapCancel: () => state.setSprint(false),
      onLongPressStart: (_) => state.setSprint(true),
      onLongPressEnd: (_) => state.setSprint(false),
      child: SizedBox(
        width: 78,
        height: 78,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 78,
              height: 78,
              child: CircularProgressIndicator(
                value: state.stamina,
                strokeWidth: 6,
                color: const Color(0xFF66BB6A),
                backgroundColor: Colors.white12,
              ),
            ),
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state.sprinting ? const Color(0xFFE8892B) : const Color(0xCC263042),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🏃', style: TextStyle(fontSize: 24)),
                  Text('ركض', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- زر الواجبات ----------------
class _QuestButton extends StatelessWidget {
  final GameState state;
  const _QuestButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final n = state.quests.length;
    return Material(
      color: n > 0 ? const Color(0xFF1E88E5) : const Color(0xCC263042),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: state.toggleQuests,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text('📋 $n', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ---------------- الواجبات ----------------
class _QuestList extends StatelessWidget {
  final GameState state;
  const _QuestList({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xCC0D47A1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📋 الواجبات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          for (final q in state.quests)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• ${q.title(state.houses)} (${q.daysLeft} يوم)', style: const TextStyle(fontSize: 11)),
            ),
        ],
      ),
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
    final fix = state.nearFix;
    if (fix != null) {
      label = '🔧 صلّح\nالواير';
      onTap = state.fixWire;
    } else if (near != null) {
      final h = state.houses[near];
      label = '🚪 ادخل\n${h.owner}';
      onTap = () => state.enterHouse(near);
    } else if (state.nearKids) {
      label = '⚽ العب\nويه الجهال';
      onTap = state.startFootball;
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
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<(int, String)> _teaLog = []; // للجايخانة: 0 آني، 1 هو، 2 ملاحظة
  bool _waiting = false;

  GameState get s => widget.state;
  bool get _tea => widget.index < 0;
  House? get _house => _tea ? null : s.houses[widget.index];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    if (_tea) {
      _teaLog.add((1, 'هلا بيك يا أبو المولدة! تفضل اگعد، جاي لو حامض؟ ☕'));
    } else if (_house!.chatLog.isEmpty) {
      _house!.chatLog.add((false, s.greet(widget.index)));
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _waiting) return;
    _input.clear();
    if (_tea) {
      setState(() {
        _teaLog.add((0, text));
        _teaLog.add((1, text.contains('جاي') || text.contains('چاي') ? s.drinkTea() : 'هلا عيني، اطلب جاي وأحچيلك أخبار المحلة ☕'));
      });
      _toBottom();
      return;
    }
    final h = _house!;
    final history = List.of(h.chatLog);
    setState(() {
      h.chatLog.add((true, text));
      _waiting = true;
    });
    _toBottom();
    final reply = await NpcChat.send(
      context: s.npcContext(widget.index),
      history: history,
      message: text,
      aiAllowed: s.useAiQuota(),
    );
    if (!mounted) return;
    final note = s.applyNpcAction(widget.index, reply.action);
    setState(() {
      h.chatLog.add((false, reply.text));
      if (note != null) h.chatLog.add((false, '— $note —'));
      _waiting = false;
    });
    _toBottom();
  }

  PersonLook _ownerLook() {
    if (_tea) return PersonLook.oldMan;
    final o = _house!.owner;
    if (o.contains('أم') || o.contains('الحجية')) return PersonLook.abaya;
    if (o.contains('الدكتور')) return PersonLook.doctor;
    if (o.contains('الحاج') || o.contains('الشيخ')) return PersonLook.shemagh;
    if (o.contains('ستار') || o.contains('حيدر') || o.contains('جاسم')) return PersonLook.dishdasha;
    return widget.index.isEven ? PersonLook.shemagh : PersonLook.dishdasha;
  }

  Widget _bubble(bool me, String text) {
    final note = text.startsWith('— ');
    if (note) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(text, style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold)),
        ),
      );
    }
    return Align(
      alignment: me ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: me ? const Color(0xFFE8892B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text, style: TextStyle(color: me ? Colors.white : Colors.black87, fontSize: 15, height: 1.4)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = _house;
    final lit = _tea ? true : s.houseLit(h!);
    final List<(bool, String)> log =
        _tea ? [for (final m in _teaLog) (m.$1 == 0, m.$2)] : h!.chatLog;
    final quick = _tea
        ? ['جيبلي جاي ☕', 'شكو ماكو بالمحلة؟']
        : [
            'شلونكم؟ الكهرباء زينة؟',
            if (h!.debt > 0) 'حجي، عليك دين ${fmt(h!.debt)}',
            if (!h!.subscribed) 'تشترك وياي؟ أوصلك ${h!.amps} أمبير',
            if (h!.subscribed) 'تريد أمبيرات زيادة؟',
          ];
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xFF0E1320),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    IconButton(onPressed: s.leave, icon: const Icon(Icons.arrow_forward)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_tea ? 'جايخانة أبو علي' : h!.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _accent)),
                          Text(
                            _tea
                                ? 'جاي بـ 1,000 وأخبار المحلة'
                                : '${h!.subscribed ? 'مشترك ${h!.amps} أمبير' : 'مو مشترك'}${h!.debt > 0 ? ' · عليه ${fmt(h!.debt)}' : ''}',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (!_tea)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF263042), borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          NpcChat.aiLabel,
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 200,
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _RoomPainter(tea: _tea, lit: lit, t: _anim.value, owner: _ownerLook(), seed: widget.index + 3),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    for (final m in log) _bubble(m.$1, m.$2),
                    if (_waiting)
                      const Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('يكتب... ✍️', style: TextStyle(color: Colors.white54)),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final q in quick)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(label: Text(q, style: const TextStyle(fontSize: 12)), onPressed: () => _send(q)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        maxLength: 200,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: _tea ? 'احچي ويه أبو علي...' : 'اكتب لـ ${h!.owner}...',
                          filled: true,
                          fillColor: const Color(0xFF1B2333),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: _waiting ? null : () => _send(_input.text),
                      icon: const Icon(Icons.send),
                    ),
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

  String get _face {
    final s = state.satisfaction;
    if (s >= 75) return '😄';
    if (s >= 50) return '🙂';
    if (s >= 30) return '😐';
    return '😠';
  }

  @override
  Widget build(BuildContext context) {
    final m = state.mission;
    final night = state.isNight;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xEE1B2437), Color(0xEE121826)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // المستوى والنجوم
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      value: state.xp / state.xpNext,
                      strokeWidth: 4,
                      color: const Color(0xFFFFC107),
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  Text('${state.level}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFFFC107))),
                ],
              ),
              const SizedBox(width: 8),
              const Text('💰', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              Text(fmt(state.money), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(night ? '🌙' : '☀️', style: const TextStyle(fontSize: 16)),
              Text(' ${state.day}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 6),
              _SmallButton(label: '×${state.speed}', onTap: state.toggleSpeed),
              const SizedBox(width: 4),
              _SmallButton(label: '؟', onTap: state.showHelp),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _IconMeter(emoji: '⛽', value: state.fuel / state.fuelCapacity, color: const Color(0xFFFFB300)),
              const SizedBox(width: 8),
              _IconMeter(emoji: '🔧', value: state.health / 100, color: const Color(0xFF42A5F5)),
              const SizedBox(width: 8),
              _IconMeter(
                emoji: _face,
                value: state.satisfaction / 100,
                color: state.satisfaction < 30 ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
              ),
              const SizedBox(width: 8),
              _Pill(emoji: '⚡', text: state.nationalOn ? 'وطنية' : 'طافية',
                  color: state.nationalOn ? const Color(0xFF2E7D32) : const Color(0xFF6D4C41)),
              const SizedBox(width: 4),
              _Pill(emoji: '🏠', text: '${state.subscribers}', color: state.overloaded ? const Color(0xFFE65100) : const Color(0xFF37474F)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  m == null ? 'خلصت كل المهام 🏆' : m.title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFFE082)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (m != null) Text('🎁${fmt(m.reward)}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconMeter extends StatelessWidget {
  final String emoji;
  final double value;
  final Color color;
  const _IconMeter({required this.emoji, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 3),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value.clamp(0, 1).toDouble(),
                  minHeight: 9,
                  color: color,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  final String emoji;
  final String text;
  final Color color;
  const _Pill({required this.emoji, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text('$emoji$text', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      );
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
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xEE1B2437), Color(0xEE121826)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // سعر الأمبير
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: expensive ? const Color(0x55E53935) : const Color(0xFF263042),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Round(icon: Icons.remove, onTap: () => s.changePrice(-1000)),
                    Text('${(s.ampPrice / 1000).round()}k',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: expensive ? const Color(0xFFFF8A80) : Colors.white)),
                    _Round(icon: Icons.add, onTap: () => s.changePrice(1000)),
                  ],
                ),
                Text(expensive ? 'غالي 😠' : '⚡ الأمبير', style: const TextStyle(fontSize: 10, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ActionButton(
              icon: s.running ? Icons.power_settings_new : Icons.play_arrow,
              label: s.running ? 'طفّي' : 'شغّل',
              onTap: s.toggleRunning,
              highlight: !s.running,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _ActionButton(
              icon: Icons.local_gas_station,
              label: '⛽ ${(s.fuelPrice * 100 / 1000).round()}k',
              onTap: s.buyFuel,
              highlight: s.fuel < 80,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _ActionButton(
              icon: Icons.build,
              label: '${(GameState.maintenanceCost / 1000).round()}k',
              onTap: s.maintain,
              highlight: s.health < 40 && !s.broken,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _ActionButton(
              icon: Icons.upgrade,
              label: s.upgradeCost == 0 ? 'MAX' : '${(s.upgradeCost / 1000000).toStringAsFixed(1)}M',
              onTap: s.upgrade,
              highlight: s.upgradeCost > 0 && s.money >= s.upgradeCost,
            ),
          ),
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Round({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 18)),
      );
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

// ---------------- لعبة تعبئة الكاز ----------------
class _PumpGame extends StatefulWidget {
  final GameState state;
  const _PumpGame({super.key, required this.state});

  @override
  State<_PumpGame> createState() => _PumpGameState();
}

class _PumpGameState extends State<_PumpGame> {
  static const _seconds = 6.0;
  Timer? _timer;
  double _left = _seconds;
  double _fill = 0;
  bool _done = false;
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _done) return;
      setState(() {
        _left -= 0.1;
        if (_left <= 0) _finish();
      });
    });
  }

  void _tap() {
    if (_done) return;
    widget.state.sfx('pump');
    setState(() {
      _taps++;
      _fill = min(1.0, _fill + 0.055);
      if (_fill >= 1) _finish();
    });
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    final fast = _fill >= 1 && _left > 0;
    Future.delayed(const Duration(milliseconds: 500), () => widget.state.finishPump(_fill, fast));
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
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFFB300), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⛽ عبّي الكاز!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFFB300))),
            const SizedBox(height: 4),
            Text(_done ? (_fill >= 1 ? 'مليان! 🔥 خصم 15%' : '${(_fill * 100).round()} لتر') : 'طگ بسرعة!',
                style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // الخزان
                Container(
                  width: 90,
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFF263238),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white38, width: 3),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      height: 154 * _fill,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  children: [
                    Text('${_left.clamp(0, _seconds).toStringAsFixed(1)}s',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _left < 2 ? const Color(0xFFEF5350) : Colors.white)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTapDown: (_) => _tap(),
                      child: AnimatedScale(
                        scale: _taps.isEven ? 1 : 0.92,
                        duration: const Duration(milliseconds: 80),
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [Color(0xFFFFB74D), Color(0xFFE65100)]),
                          ),
                          child: const Center(child: Text('⛽\nطگ!', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- ضربات جزاء ويه الجهال ----------------
class _PenaltyGame extends StatefulWidget {
  final GameState state;
  const _PenaltyGame({super.key, required this.state});

  @override
  State<_PenaltyGame> createState() => _PenaltyGameState();
}

class _PenaltyGameState extends State<_PenaltyGame> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  final _results = <bool>[];
  double _shotX = 0; // من -1 لـ 1
  double _ballT = 0; // 0 بالأرض، 1 وصلت الهدف
  bool _shooting = false;
  bool _done = false;
  double _keeperX = 0;

  double get _aimX => sin(_anim.value * 2 * pi * 1.0) * 0.95;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _anim.addListener(() {
      if (!mounted) return;
      setState(() {
        if (!_shooting) {
          _keeperX = sin(_anim.value * 2 * pi * 1.6 + 1) * 0.7;
        } else {
          _ballT = min(1.0, _ballT + 0.06);
          if (_ballT >= 1) _resolve();
        }
      });
    });
  }

  void _shoot() {
    if (_shooting || _done) return;
    widget.state.sfx('kick');
    _shooting = true;
    _ballT = 0;
    _shotX = _aimX;
  }

  void _resolve() {
    _shooting = false;
    final goal = (_shotX - _keeperX).abs() > 0.3;
    _results.add(goal);
    widget.state.sfx(goal ? 'goal' : 'miss');
    if (_results.length >= 3) {
      _done = true;
      final goals = _results.where((g) => g).length;
      Future.delayed(const Duration(milliseconds: 900), () => widget.state.finishFootball(goals));
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Dim(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⚽ ', style: TextStyle(fontSize: 20)),
                for (var k = 0; k < 3; k++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(k < _results.length ? (_results[k] ? '✅' : '❌') : '⚪', style: const TextStyle(fontSize: 22)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 1.1,
              child: CustomPaint(
                painter: _PitchPainter(aim: _aimX, keeper: _keeperX, shotX: _shotX, ballT: _ballT, shooting: _shooting),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1B5E20), padding: const EdgeInsets.all(14)),
                onPressed: _done ? null : _shoot,
                child: Text(_done ? '🎉' : 'شوت! ⚽', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  final double aim, keeper, shotX, ballT;
  final bool shooting;
  _PitchPainter({required this.aim, required this.keeper, required this.shotX, required this.ballT, required this.shooting});

  @override
  void paint(Canvas c, Size size) {
    final w = size.width, h = size.height;
    // عشب مخطط
    for (var k = 0; k < 8; k++) {
      c.drawRect(Rect.fromLTWH(0, h * k / 8, w, h / 8), Paint()..color = k.isEven ? const Color(0xFF2E7D32) : const Color(0xFF388E3C));
    }
    // الهدف
    final goal = Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.76, h * 0.32);
    final net = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (var x = goal.left; x <= goal.right; x += 10) {
      c.drawLine(Offset(x, goal.top), Offset(x, goal.bottom), net);
    }
    for (var y = goal.top; y <= goal.bottom; y += 10) {
      c.drawLine(Offset(goal.left, y), Offset(goal.right, y), net);
    }
    final post = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    c.drawPath(
      Path()
        ..moveTo(goal.left, goal.bottom)
        ..lineTo(goal.left, goal.top)
        ..lineTo(goal.right, goal.top)
        ..lineTo(goal.right, goal.bottom),
      post,
    );
    double gx(double v) => goal.center.dx + v * goal.width / 2;
    // الحارس (جاهل)
    final kx = gx(keeper);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(kx, goal.bottom - 30), width: 34, height: 44), const Radius.circular(10)),
        Paint()..color = const Color(0xFFFFC107));
    c.drawCircle(Offset(kx, goal.bottom - 60), 12, Paint()..color = const Color(0xFFE0B48A));
    c.drawLine(Offset(kx - 17, goal.bottom - 40), Offset(kx - 34, goal.bottom - 55), Paint()
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round);
    c.drawLine(Offset(kx + 17, goal.bottom - 40), Offset(kx + 34, goal.bottom - 55), Paint()
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round);
    // سهم التنشين
    if (!shooting) {
      final ax = gx(aim);
      c.drawLine(Offset(w / 2, h * 0.85), Offset(ax, goal.center.dy), Paint()
        ..color = const Color(0xAAFFFFFF)
        ..strokeWidth = 3);
      c.drawCircle(Offset(ax, goal.center.dy), 10, Paint()
        ..color = const Color(0xFFFF5252)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
    }
    // الطوبة
    final start = Offset(w / 2, h * 0.85);
    final end = Offset(gx(shotX), goal.center.dy);
    final b = shooting ? Offset.lerp(start, end, ballT)! : start;
    final r = shooting ? 14 - 6 * ballT : 14.0;
    c.drawCircle(b.translate(0, 6), r * 0.8, Paint()..color = const Color(0x55000000));
    c.drawCircle(b, r, Paint()..color = Colors.white);
    c.drawCircle(b, r * 0.4, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => true;
}

// ---------------- لعبة التصليح ----------------// ---------------- لعبة التصليح ----------------
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
    ('أهلاً يا صاحب المولدة! ⚡', '🏘️ هذي محلتك\n🟩 المولدة رزقك\n💡 الشبابيك تضوي من كهرباءك', Alignment.center),
    ('🕹️ امشِ واركض', 'العصا الصفرة = تمشي\n🏃 زر الركض = أسرع', Alignment(0, -0.3)),
    ('🦹 الحرامي!', 'يطلع على عمود ويهرب\nاركض وراه ولزمه 👮', Alignment.center),
    ('🚪 ادخل البيوت', 'احچي ويه الناس\n💵 دين  🤝 اشتراك  ⚡ أمبيرات', Alignment.center),
    ('⚽ 📋 ⛽', 'العب ويه الجهال\nسوّي الواجبات\nعبّي الكاز بسرعة', Alignment.center),
    ('🪙 آخر الشهر', 'امشِ لعند العملات واجمعها\n⭐ اصعد مستويات!', Alignment.center),
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
