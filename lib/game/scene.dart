import 'dart:math';

import 'package:flame/components.dart' show PositionComponent, HasGameReference, Vector2;
import 'package:flame/events.dart' show TapCallbacks, TapDownEvent;
import 'package:flame/game.dart' show FlameGame;
import 'package:flutter/material.dart';

import 'state.dart';

class _Puff {
  double x, y, age = 0;
  _Puff(this.x, this.y);
}

class _Walker {
  double x;
  double lane;
  double dir;
  final double speed;
  final int robe;
  final int head;
  _Walker(this.x, this.lane, this.dir, this.speed, this.robe, this.head);
}

/// الزگاق بمنظور مائل (Isometric) مرسوم بالكود.
class AlleyScene extends PositionComponent with TapCallbacks, HasGameReference<FlameGame> {
  final GameState state;
  AlleyScene(this.state);

  // البيوت: صف (gy=0) وصف (gy=3) والزگاق بينهم
  static const List<Offset> grid = [
    Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(3, 0), Offset(4, 0),
    Offset(0, 3), Offset(1, 3), Offset(2, 3), Offset(3, 3), Offset(4, 3),
  ];
  static const Offset genGrid = Offset(2, 1.5);
  // أعمدة الكهرباء: اثنين بكل جهة من الزگاق
  static const List<Offset> poles = [Offset(0.6, 0.75), Offset(3.4, 0.75), Offset(0.6, 2.25), Offset(3.4, 2.25)];

  static const List<int> _brick = [
    0xFFC9A27E, 0xFFB98B6A, 0xFFD8B994, 0xFFA97C5A, 0xFFCFAE8A,
    0xFFBF9670, 0xFFD2B48C, 0xFFAD8462, 0xFFC4A07A, 0xFFB58E6B,
  ];
  static const List<double> _heights = [0.55, 0.68, 0.5, 0.62, 0.72, 0.6, 0.52, 0.7, 0.58, 0.66];

  final List<_Puff> _puffs = [];
  final List<_Walker> _walkers = [
    _Walker(-1, 1.3, 1, 0.35, 0xFFF2F2F2, 0xFFE0B48A),
    _Walker(4.5, 1.7, -1, 0.28, 0xFF222222, 0xFF222222),
    _Walker(2, 1.45, 1, 0.42, 0xFF3F6FB5, 0xFFC99A6E),
  ];
  late final List<Offset> _stars;
  double _puffTimer = 0;
  double tw = 80, th = 40;
  Offset origin = Offset.zero;
  double _light = 1;
  Offset _exhaust = Offset.zero;
  Offset _genTop = Offset.zero;

  @override
  Future<void> onLoad() async {
    final r = Random(7);
    _stars = List.generate(40, (_) => Offset(r.nextDouble(), r.nextDouble()));
    size = game.size.clone();
    _layout();
  }

  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);
    size = s.clone();
    _layout();
  }

  void _layout() {
    const topUi = 205.0, bottomUi = 200.0;
    final avail = max(220.0, size.y - topUi - bottomUi);
    tw = min(size.x * 0.95 / 4.4, avail / 2.8);
    th = tw / 2;
    origin = Offset(size.x / 2 - tw / 4, topUi + (avail - 2.75 * tw) / 2 + 0.8 * tw);
  }

  Offset iso(double gx, double gy) =>
      Offset(origin.dx + (gx - gy) * tw / 2, origin.dy + (gx + gy) * th / 2);

  // ---------- الحركة ----------
  @override
  void update(double dt) {
    super.update(dt);
    if (state.generating) {
      _puffTimer += dt;
      final every = state.overloaded ? 0.08 : 0.18;
      while (_puffTimer > every) {
        _puffTimer -= every;
        _puffs.add(_Puff(_exhaust.dx, _exhaust.dy));
      }
    }
    for (final p in _puffs) {
      p.age += dt;
      p.y -= tw * 0.35 * dt;
      p.x += tw * 0.12 * dt;
    }
    _puffs.removeWhere((p) => p.age > 2.5);

    if (!state.paused) {
      for (final w in _walkers) {
        w.x += w.dir * w.speed * dt * state.speed;
        if (w.x > 5.5) w.dir = -1;
        if (w.x < -1.5) w.dir = 1;
      }
    }
  }

  // ---------- الرسم ----------
  @override
  void render(Canvas c) {
    if (size.x != game.size.x || size.y != game.size.y) {
      size = game.size.clone();
      _layout();
    }
    final phase = state.dayProgress;
    _light = 0.5 + 0.5 * sin(2 * pi * (phase - 0.25));

    _sky(c, phase);
    _ground(c);

    final items = <MapEntry<double, void Function()>>[];
    for (var i = 0; i < state.houses.length; i++) {
      final g = grid[i];
      items.add(MapEntry(g.dx + g.dy, () => _house(c, i)));
    }
    items.add(MapEntry(genGrid.dx + genGrid.dy, () => _generator(c)));
    for (final w in _walkers) {
      items.add(MapEntry(w.x + w.lane, () => _walker(c, w)));
    }
    for (final p in poles) {
      items.add(MapEntry(p.dx + p.dy, () => _pole(c, p)));
    }
    items.sort((a, b) => a.key.compareTo(b.key));
    for (final it in items) {
      it.value();
    }
    _wires(c);
    _smoke(c);
    _thief(c);
    _bubbles(c);
  }

  Offset _thiefPos() {
    final pl = poles[state.thiefPole % poles.length];
    final base = iso(pl.dx, pl.dy);
    return base.translate(tw * 0.06, -tw * 0.55);
  }

  // حرامي متسلق على العمود
  void _thief(Canvas c) {
    if (state.thiefTime <= 0) return;
    final p = _thiefPos();
    final s = tw * 0.07;
    final wiggle = sin(state.clock * 12) * s * 0.3;
    final flash = (state.clock * 4).floor().isEven;
    c.drawCircle(p, tw * 0.32, Paint()..color = flash ? const Color(0x66FF1744) : const Color(0x33FF1744));
    // عداد
    c.drawArc(
      Rect.fromCircle(center: p, radius: tw * 0.32),
      -pi / 2,
      2 * pi * (state.thiefTime / GameState.thiefSeconds),
      false,
      Paint()
        ..color = const Color(0xFFFF1744)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(p.dx - s * 0.5 + wiggle, p.dy - s, s, s * 2), Radius.circular(s * 0.3)),
      Paint()..color = const Color(0xFF111111),
    );
    c.drawCircle(p.translate(wiggle, -s * 1.4), s * 0.5, Paint()..color = const Color(0xFF111111));
    c.drawLine(p.translate(wiggle - s * 0.4, -s * 1.5), p.translate(wiggle + s * 0.4, -s * 1.5),
        Paint()..color = const Color(0xFFFFFFFF)..strokeWidth = 1.5);
    _text(c, '🦹', p.translate(0, -tw * 0.45), tw * 0.2, Colors.white);
  }

  Color _shade(int argb, [double extra = 1]) {
    final k = (0.35 + 0.65 * _light) * extra;
    int ch(int shift) => (((argb >> shift) & 0xFF) * k).clamp(0, 255).round();
    return Color.fromARGB(255, ch(16), ch(8), ch(0));
  }

  void _text(Canvas c, String s, Offset center, double fontSize, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: fontSize, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _sky(Canvas c, double phase) {
    final col = Color.lerp(const Color(0xFF0E1A33), const Color(0xFF8EC5E8), _light)!;
    c.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = col);

    // نجوم بالليل
    final starAlpha = ((0.45 - _light) * 2.5).clamp(0.0, 1.0);
    if (starAlpha > 0) {
      final p = Paint()..color = Color.fromARGB((starAlpha * 220).round(), 255, 255, 255);
      for (final s in _stars) {
        c.drawCircle(Offset(s.dx * size.x, 190 + s.dy * size.y * 0.25), 1.2, p);
      }
    }

    // الشمس من الشرق للغرب، والگمر بالليل
    final sunT = (phase - 0.25) * 2;
    if (sunT > 0 && sunT < 1) {
      final pos = Offset(size.x * (0.9 - 0.8 * sunT), 270 - 60 * sin(pi * sunT));
      c.drawCircle(pos, tw * 0.3, Paint()..color = const Color(0x55FFE082));
      c.drawCircle(pos, tw * 0.2, Paint()..color = const Color(0xFFFFD54F));
    }
    final moonT = (((phase + 0.5) % 1) - 0.25) * 2;
    if (moonT > 0 && moonT < 1) {
      final pos = Offset(size.x * (0.9 - 0.8 * moonT), 270 - 60 * sin(pi * moonT));
      c.drawCircle(pos, tw * 0.16, Paint()..color = const Color(0xFFF5F3E7));
      c.drawCircle(pos.translate(tw * 0.07, -tw * 0.04), tw * 0.14,
          Paint()..color = Color.lerp(const Color(0xFF0E1A33), const Color(0xFF8EC5E8), _light)!);
    }
  }

  Path _diamond(Offset p, double w, double h, [double lift = 0]) => Path()
    ..moveTo(p.dx, p.dy - h / 2 - lift)
    ..lineTo(p.dx + w / 2, p.dy - lift)
    ..lineTo(p.dx, p.dy + h / 2 - lift)
    ..lineTo(p.dx - w / 2, p.dy - lift)
    ..close();

  void _ground(Canvas c) {
    final line = Paint()
      ..color = const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var gx = -2; gx <= 6; gx++) {
      for (var gy = -2; gy <= 5; gy++) {
        final street = gy == 1 || gy == 2;
        final p = iso(gx.toDouble(), gy.toDouble());
        final path = _diamond(p, tw, th);
        c.drawPath(path, Paint()..color = _shade(street ? 0xFF5B5E63 : 0xFFD9C9A3));
        c.drawPath(path, line);
      }
    }
    // خط الرصيف بالزگاق
    final dash = Paint()
      ..color = _shade(0xFFEDE7D9)
      ..strokeWidth = 2;
    for (var gx = -2; gx <= 6; gx++) {
      final a = iso(gx + 0.15, 1.5), b = iso(gx + 0.55, 1.5);
      c.drawLine(a, b, dash);
    }
  }

  // يرجع نقاط الجدارين
  void _box(Canvas c, Offset p, double w, double h, double height, Color top, Color left, Color right) {
    final l = Offset(p.dx - w / 2, p.dy), b = Offset(p.dx, p.dy + h / 2), r = Offset(p.dx + w / 2, p.dy);
    final lp = Path()
      ..moveTo(l.dx, l.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx, b.dy - height)
      ..lineTo(l.dx, l.dy - height)
      ..close();
    final rp = Path()
      ..moveTo(b.dx, b.dy)
      ..lineTo(r.dx, r.dy)
      ..lineTo(r.dx, r.dy - height)
      ..lineTo(b.dx, b.dy - height)
      ..close();
    c.drawPath(lp, Paint()..color = left);
    c.drawPath(rp, Paint()..color = right);
    c.drawPath(_diamond(p, w, h, height), Paint()..color = top);
    final edge = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    c.drawPath(lp, edge);
    c.drawPath(rp, edge);
  }

  // شكل رباعي على جدار: u على عرض الجدار، v على الارتفاع
  Path _quad(Offset Function(double u, double v) f, double u1, double u2, double v1, double v2) => Path()
    ..moveTo(f(u1, v1).dx, f(u1, v1).dy)
    ..lineTo(f(u2, v1).dx, f(u2, v1).dy)
    ..lineTo(f(u2, v2).dx, f(u2, v2).dy)
    ..lineTo(f(u1, v2).dx, f(u1, v2).dy)
    ..close();

  double get _hw => tw * 0.82;
  double get _hh => th * 0.82;
  double _hHeight(int i) => tw * _heights[i % _heights.length];

  void _house(Canvas c, int i) {
    final h = state.houses[i];
    final g = grid[i];
    final p = iso(g.dx, g.dy);
    final w = _hw, hh = _hh, height = _hHeight(i);
    final col = _brick[i % _brick.length];
    _box(c, p, w, hh, height, _shade(col, 1.08), _shade(col, 0.85), _shade(col, 0.7));

    final l = Offset(p.dx - w / 2, p.dy), b = Offset(p.dx, p.dy + hh / 2), r = Offset(p.dx + w / 2, p.dy);
    Offset onLeft(double u, double v) => Offset(l.dx + (b.dx - l.dx) * u, l.dy + (b.dy - l.dy) * u - v);
    Offset onRight(double u, double v) => Offset(b.dx + (r.dx - b.dx) * u, b.dy + (r.dy - b.dy) * u - v);

    // الشبابيك
    final lit = state.houseLit(h);
    final winPaint = Paint()..color = lit ? const Color(0xFFFFD25A) : const Color(0xFF2B2B35);
    final glow = Paint()
      ..color = const Color(0x66FFD25A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final wins = [
      _quad(onLeft, 0.12, 0.34, height * 0.45, height * 0.78),
      _quad(onLeft, 0.5, 0.72, height * 0.45, height * 0.78),
      _quad(onRight, 0.12, 0.36, height * 0.45, height * 0.78),
    ];
    for (final wp in wins) {
      if (lit && _light < 0.5) c.drawPath(wp, glow);
      c.drawPath(wp, winPaint);
    }

    // الباب
    c.drawPath(_quad(onRight, 0.55, 0.8, 0, height * 0.5), Paint()..color = _shade(0xFF5D4037));
    c.drawCircle(onRight(0.6, height * 0.25), tw * 0.012, Paint()..color = _shade(0xFFFFC107));

    // سبلت (مبردة) على الجدار
    c.drawPath(_quad(onLeft, 0.78, 0.95, height * 0.12, height * 0.3), Paint()..color = _shade(0xFFECEFF1));
    c.drawPath(
      _quad(onLeft, 0.8, 0.93, height * 0.16, height * 0.19),
      Paint()..color = _shade(0xFF90A4AE),
    );

    // حافة السطح
    c.drawPath(
      _diamond(p, w, hh, height),
      Paint()
        ..color = _shade(col, 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // خزان الماء، ودش للبعض
    final roof = Offset(p.dx + tw * 0.08, p.dy - height);
    _box(c, roof, w * 0.22, hh * 0.22, tw * 0.1, _shade(0xFFEDEDED), _shade(0xFFCFCFCF), _shade(0xFFB0B0B0));
    if (i % 3 == 0) {
      final d = Offset(p.dx - tw * 0.15, p.dy - height - tw * 0.04);
      c.drawOval(Rect.fromCenter(center: d, width: tw * 0.14, height: tw * 0.08), Paint()..color = _shade(0xFFDDDDDD));
      c.drawLine(d, d.translate(0, tw * 0.04), Paint()..color = _shade(0xFF777777)..strokeWidth = 1.5);
    }

    // التحديد
    if (state.selected == i) {
      c.drawPath(
        _diamond(p, w, hh, height),
        Paint()
          ..color = const Color(0xFFFF9800)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  Offset _roofPoint(int i) {
    final g = grid[i];
    final p = iso(g.dx, g.dy);
    return Offset(p.dx - tw * 0.1, p.dy - _hHeight(i));
  }

  Offset _poleTop(Offset g) => iso(g.dx, g.dy).translate(0, -tw * 0.85);

  void _pole(Canvas c, Offset g) {
    final base = iso(g.dx, g.dy);
    final top = _poleTop(g);
    final paint = Paint()
      ..color = _shade(0xFF6D6D6D)
      ..strokeWidth = tw * 0.035;
    c.drawLine(base, top, paint);
    c.drawLine(top.translate(-tw * 0.1, tw * 0.05), top.translate(tw * 0.1, tw * 0.05), paint..strokeWidth = tw * 0.025);
  }

  void _walker(Canvas c, _Walker w) {
    final p = iso(w.x, w.lane);
    final s = tw * 0.06;
    final swing = state.paused ? 0.0 : sin(state.clock * 9 + w.x) * s * 0.5;
    final leg = Paint()
      ..color = _shade(0xFF3E2723)
      ..strokeWidth = s * 0.35;
    c.drawLine(p.translate(-s * 0.2, -s * 1.2), p.translate(-s * 0.2 + swing, 0), leg);
    c.drawLine(p.translate(s * 0.2, -s * 1.2), p.translate(s * 0.2 - swing, 0), leg);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(p.dx - s * 0.5, p.dy - s * 3, s, s * 2.1), Radius.circular(s * 0.4)),
      Paint()..color = _shade(w.robe),
    );
    c.drawCircle(p.translate(0, -s * 3.4), s * 0.45, Paint()..color = _shade(w.head));
  }

  void _generator(Canvas c) {
    final scale = 1 + 0.18 * (state.genLevel - 1);
    final base = iso(genGrid.dx, genGrid.dy);

    // السياج
    final fence = Paint()
      ..color = _shade(0xFF9E9E9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fw = tw * 1.05 * scale, fh = th * 1.05 * scale;
    c.drawPath(_diamond(base, fw, fh), fence);
    c.drawPath(_diamond(base, fw, fh, tw * 0.18), fence);
    for (final corner in [
      Offset(base.dx - fw / 2, base.dy),
      Offset(base.dx + fw / 2, base.dy),
      Offset(base.dx, base.dy - fh / 2),
    ]) {
      c.drawLine(corner, corner.translate(0, -tw * 0.18), fence);
    }

    final shake = state.generating ? sin(state.clock * 70) * tw * 0.012 : 0.0;
    final p = Offset(base.dx + shake, base.dy);
    final w = tw * 0.62 * scale, h = th * 0.62 * scale, height = tw * 0.32 * scale;
    final body = state.broken ? 0xFF6A3A3A : 0xFF3E6B48;
    _box(c, p, w, h, height, _shade(body, 1.15), _shade(body, 0.9), _shade(body, 0.7));

    final l = Offset(p.dx - w / 2, p.dy), b = Offset(p.dx, p.dy + h / 2), r = Offset(p.dx + w / 2, p.dy);
    Offset onLeft(double u, double v) => Offset(l.dx + (b.dx - l.dx) * u, l.dy + (b.dy - l.dy) * u - v);
    Offset onRight(double u, double v) => Offset(b.dx + (r.dx - b.dx) * u, b.dy + (r.dy - b.dy) * u - v);

    // الرادييتر (خطوط) ولوحة التحكم
    final grill = Paint()
      ..color = _shade(0xFF1B2E20)
      ..strokeWidth = 1.2;
    for (var k = 0; k < 4; k++) {
      final u = 0.2 + k * 0.15;
      c.drawLine(onLeft(u, height * 0.2), onLeft(u, height * 0.8), grill);
    }
    c.drawPath(_quad(onRight, 0.25, 0.7, height * 0.35, height * 0.8), Paint()..color = _shade(0xFF263238));

    // ضوء الحالة
    final status = state.broken
        ? const Color(0xFFE53935)
        : !state.generating
            ? const Color(0xFF9E9E9E)
            : state.overloaded
                ? const Color(0xFFFF9800)
                : const Color(0xFF43A047);
    c.drawCircle(onRight(0.47, height * 0.58), tw * 0.035, Paint()..color = status);

    // الإكزوز
    final pipeBase = Offset(p.dx + w * 0.18, p.dy - height);
    final pipeTop = Offset(pipeBase.dx, pipeBase.dy - tw * 0.22);
    c.drawLine(
      pipeBase,
      pipeTop,
      Paint()
        ..color = _shade(0xFF444444)
        ..strokeWidth = tw * 0.05,
    );
    _exhaust = pipeTop;
    _genTop = Offset(p.dx - w * 0.15, p.dy - height);

    if (state.alarm > 0 && (state.clock * 5).floor().isEven) {
      c.drawPath(
        _diamond(p, w * 1.3, h * 1.3, height),
        Paint()
          ..color = const Color(0xFFFF1744)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }

    if (state.selected == -1) {
      c.drawPath(
        _diamond(p, w, h, height),
        Paint()
          ..color = const Color(0xFFFF9800)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _sag(Canvas c, Offset a, Offset b, Paint paint, [double amount = 0.15]) {
    final mid = Offset((a.dx + b.dx) / 2, max(a.dy, b.dy) + tw * amount);
    c.drawPath(Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy), paint);
  }

  void _wires(Canvas c) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    // من المولدة للأعمدة، وبين الأعمدة
    for (final pl in poles) {
      _sag(c, _genTop, _poleTop(pl), paint, 0.1);
    }
    _sag(c, _poleTop(poles[0]), _poleTop(poles[1]), paint);
    _sag(c, _poleTop(poles[2]), _poleTop(poles[3]), paint);
    _sag(c, _poleTop(poles[0]), _poleTop(poles[2]), paint, 0.08);
    _sag(c, _poleTop(poles[1]), _poleTop(poles[3]), paint, 0.08);
    // من أقرب عمود لكل بيت مشترك
    for (var i = 0; i < state.houses.length; i++) {
      if (!state.houses[i].subscribed) continue;
      final g = grid[i];
      final near = g.dy < 1.5 ? (g.dx < 2 ? poles[0] : poles[1]) : (g.dx < 2 ? poles[2] : poles[3]);
      _sag(c, _poleTop(near), _roofPoint(i), paint, 0.12);
    }
  }

  void _smoke(Canvas c) {
    final dark = state.overloaded || state.health < 30;
    for (final p in _puffs) {
      final t = p.age / 2.5;
      final alpha = ((1 - t) * (dark ? 150 : 90)).round().clamp(0, 255);
      final g = dark ? 60 : 170;
      c.drawCircle(Offset(p.x, p.y), tw * (0.03 + t * 0.12), Paint()..color = Color.fromARGB(alpha, g, g, g));
    }
  }

  // العملات وكلام الناس فوك البيوت
  void _bubbles(Canvas c) {
    final fs = max(10.0, tw * 0.14);
    for (var i = 0; i < state.houses.length; i++) {
      final h = state.houses[i];
      final anchor = _roofPoint(i).translate(tw * 0.1, -tw * 0.3);
      if (h.pending > 0) {
        final bounce = sin(state.clock * 5 + i) * 4;
        final cpos = anchor.translate(0, bounce);
        final rr = tw * 0.17;
        c.drawCircle(cpos, rr * 1.35, Paint()..color = const Color(0x55FFD54F));
        c.drawCircle(cpos, rr, Paint()..color = const Color(0xFFFFC107));
        c.drawCircle(
          cpos,
          rr * 0.78,
          Paint()
            ..color = const Color(0xFFFFA000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        c.drawArc(
          Rect.fromCircle(center: cpos, radius: rr * 1.35),
          -pi / 2,
          2 * pi * (h.coinTime / GameState.coinSeconds).clamp(0.0, 1.0),
          false,
          Paint()
            ..color = h.coinTime < 2.5 ? const Color(0xFFFF1744) : const Color(0xFFFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        _text(c, 'د.ع', cpos, fs * 0.8, const Color(0xFF5D4037), bold: true);
        _text(c, fmt(h.pending), cpos.translate(0, rr + fs * 0.8), fs * 0.85, Colors.white, bold: true);
      } else if (h.requestTime > 0) {
        final pulse = 1 + 0.08 * sin(state.clock * 8);
        final rect = Rect.fromCenter(center: anchor, width: tw * 0.75 * pulse, height: fs * 1.9 * pulse);
        c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), Paint()..color = const Color(0xFF43A047));
        _text(c, '⚡ +أمبير؟', anchor, fs * 0.9, Colors.white, bold: true);
      } else if (h.bubble != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: h.bubble,
            style: TextStyle(fontSize: fs, color: const Color(0xFF212121), fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        final rect = Rect.fromCenter(center: anchor, width: tp.width + 14, height: tp.height + 8);
        final bad = h.bubble!.contains('!') && !h.bubble!.startsWith('+') && !h.bubble!.contains('اشترك');
        final fill = h.bubble!.startsWith('+') ? const Color(0xFFC8E6C9) : (bad ? const Color(0xFFFFCDD2) : Colors.white);
        c.drawPath(
          Path()
            ..moveTo(anchor.dx - 5, rect.bottom - 1)
            ..lineTo(anchor.dx, rect.bottom + 7)
            ..lineTo(anchor.dx + 5, rect.bottom - 1)
            ..close(),
          Paint()..color = fill,
        );
        c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), Paint()..color = fill);
        tp.paint(c, Offset(rect.left + 7, rect.top + 4));
      } else if (h.debt > 0) {
        c.drawCircle(anchor, tw * 0.07, Paint()..color = const Color(0xFFE53935));
        _text(c, '!', anchor, fs, Colors.white, bold: true);
      }
    }
  }

  // ---------- اللمس ----------
  @override
  void onTapDown(TapDownEvent event) {
    final pt = Offset(event.localPosition.x, event.localPosition.y);
    // الحرامي أولاً
    if (state.thiefTime > 0 && (pt - _thiefPos()).distance < tw * 0.5) {
      state.catchThief();
      return;
    }
    // العملات
    for (var i = 0; i < state.houses.length; i++) {
      if (state.houses[i].pending <= 0) continue;
      final anchor = _roofPoint(i).translate(tw * 0.1, -tw * 0.3);
      if ((pt - anchor).distance < tw * 0.35) {
        state.collect(i);
        return;
      }
    }
    // البيوت، الأقرب للشاشة أولاً
    final order = List<int>.generate(grid.length, (i) => i)
      ..sort((a, b) => (grid[b].dx + grid[b].dy).compareTo(grid[a].dx + grid[a].dy));
    for (final i in order) {
      final p = iso(grid[i].dx, grid[i].dy);
      final rect = Rect.fromLTRB(p.dx - _hw / 2, p.dy - _hHeight(i) - _hh / 2, p.dx + _hw / 2, p.dy + _hh / 2);
      if (rect.contains(pt)) {
        state.tapHouse(i);
        return;
      }
    }
    final gp = iso(genGrid.dx, genGrid.dy);
    final gRect = Rect.fromLTRB(gp.dx - tw * 0.5, gp.dy - tw * 0.6, gp.dx + tw * 0.5, gp.dy + th * 0.5);
    if (gRect.contains(pt)) {
      if (state.alarm > 0 && !state.running) {
        state.toggleRunning();
      } else {
        state.select(state.selected == -1 ? null : -1);
      }
      return;
    }
    state.select(null);
  }
}
