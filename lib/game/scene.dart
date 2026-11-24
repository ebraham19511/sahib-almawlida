import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'state.dart';

class _Puff {
  double x, y, age = 0;
  _Puff(this.x, this.y);
}

/// الزگاق بمنظور مائل (Isometric) مرسوم بالكود بدون صور،
/// حتى يشتغل النموذج الأولي فوراً. بعدين نبدّل الأشكال برسوم حقيقية.
class AlleyScene extends PositionComponent with TapCallbacks, HasGameReference<FlameGame> {
  final GameState state;
  AlleyScene(this.state);

  // مواقع البيوت على الشبكة: صف يمين وصف يسار والزگاق بالنص
  static const List<Offset> grid = [
    Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(3, 0), Offset(4, 0),
    Offset(0, 3), Offset(1, 3), Offset(2, 3), Offset(3, 3), Offset(4, 3),
  ];
  static const Offset genGrid = Offset(2, 1.5);

  static const List<int> _brick = [
    0xFFC9A27E, 0xFFB98B6A, 0xFFD8B994, 0xFFA97C5A, 0xFFCFAE8A,
    0xFFBF9670, 0xFFD2B48C, 0xFFAD8462, 0xFFC4A07A, 0xFFB58E6B,
  ];

  final List<_Puff> _puffs = [];
  double _puffTimer = 0;
  double tw = 100, th = 50;
  Offset origin = Offset.zero;
  double _light = 1;
  Offset _exhaust = Offset.zero;
  Offset _genTop = Offset.zero;

  @override
  Future<void> onLoad() async {
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
    const topUi = 130.0, bottomUi = 190.0;
    final avail = max(200.0, size.y - topUi - bottomUi);
    tw = min(size.x * 0.25, avail / 2.55);
    th = tw / 2;
    origin = Offset(size.x / 2 - tw / 4, topUi + avail / 2 - 1.75 * th + 0.2 * tw);
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

    _sky(c);
    _ground(c);

    final items = <MapEntry<double, void Function()>>[];
    for (var i = 0; i < state.houses.length; i++) {
      final g = grid[i];
      items.add(MapEntry(g.dx + g.dy, () => _house(c, i)));
    }
    items.add(MapEntry(genGrid.dx + genGrid.dy, () => _generator(c)));
    items.sort((a, b) => a.key.compareTo(b.key));
    for (final it in items) {
      it.value();
    }
    _wires(c);
    _smoke(c);
  }

  Color _shade(int argb, [double extra = 1]) {
    final k = (0.35 + 0.65 * _light) * extra;
    int ch(int shift) => (((argb >> shift) & 0xFF) * k).clamp(0, 255).round();
    return Color.fromARGB(255, ch(16), ch(8), ch(0));
  }

  void _sky(Canvas c) {
    final col = Color.lerp(const Color(0xFF0E1A33), const Color(0xFF8EC5E8), _light)!;
    c.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = col);
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
    for (var gx = -1; gx <= 5; gx++) {
      for (var gy = -1; gy <= 4; gy++) {
        final street = gy == 1 || gy == 2;
        final p = iso(gx.toDouble(), gy.toDouble());
        final path = _diamond(p, tw, th);
        c.drawPath(path, Paint()..color = _shade(street ? 0xFF5B5E63 : 0xFFD9C9A3));
        c.drawPath(path, line);
      }
    }
  }

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

  // أبعاد البيت
  double get _hw => tw * 0.82;
  double get _hh => th * 0.82;
  double get _hHeight => tw * 0.55;

  void _house(Canvas c, int i) {
    final h = state.houses[i];
    final g = grid[i];
    final p = iso(g.dx, g.dy);
    final w = _hw, hh = _hh, height = _hHeight;
    final col = _brick[i % _brick.length];
    _box(c, p, w, hh, height, _shade(col, 1.08), _shade(col, 0.85), _shade(col, 0.7));

    // الشبابيك
    final lit = state.houseLit(h);
    final winPaint = Paint()..color = lit ? const Color(0xFFFFD25A) : const Color(0xFF2B2B35);
    final l = Offset(p.dx - w / 2, p.dy), b = Offset(p.dx, p.dy + hh / 2), r = Offset(p.dx + w / 2, p.dy);
    Offset onLeft(double u, double v) => Offset(l.dx + (b.dx - l.dx) * u, l.dy + (b.dy - l.dy) * u - v);
    Offset onRight(double u, double v) => Offset(b.dx + (r.dx - b.dx) * u, b.dy + (r.dy - b.dy) * u - v);
    for (final face in [onLeft, onRight]) {
      for (final u in [0.2, 0.6]) {
        final v1 = height * 0.35, v2 = height * 0.7;
        final path = Path()
          ..moveTo(face(u, v1).dx, face(u, v1).dy)
          ..lineTo(face(u + 0.22, v1).dx, face(u + 0.22, v1).dy)
          ..lineTo(face(u + 0.22, v2).dx, face(u + 0.22, v2).dy)
          ..lineTo(face(u, v2).dx, face(u, v2).dy)
          ..close();
        if (lit && _light < 0.5) {
          c.drawPath(
            path,
            Paint()
              ..color = const Color(0x66FFD25A)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
        }
        c.drawPath(path, winPaint);
      }
    }

    // خزان الماء على السطح
    final roof = Offset(p.dx + tw * 0.08, p.dy - height);
    _box(c, roof, w * 0.22, hh * 0.22, tw * 0.1, _shade(0xFFEDEDED), _shade(0xFFCFCFCF), _shade(0xFFB0B0B0));

    // علامة الدين
    if (h.debt > 0) {
      c.drawCircle(Offset(p.dx, p.dy - height - hh * 0.9), tw * 0.06, Paint()..color = const Color(0xFFE53935));
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
    return Offset(p.dx, p.dy - _hHeight);
  }

  void _generator(Canvas c) {
    final scale = 1 + 0.18 * (state.genLevel - 1);
    final shake = state.generating ? sin(state.clock * 70) * tw * 0.012 : 0.0;
    final base = iso(genGrid.dx, genGrid.dy);
    final p = Offset(base.dx + shake, base.dy);
    final w = tw * 0.62 * scale, h = th * 0.62 * scale, height = tw * 0.3 * scale;
    final body = state.broken ? 0xFF6A3A3A : 0xFF3E6B48;
    _box(c, p, w, h, height, _shade(body, 1.15), _shade(body, 0.9), _shade(body, 0.7));

    // الصبّة (الإكزوز)
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

    // ضوء الحالة
    final status = state.broken
        ? const Color(0xFFE53935)
        : !state.generating
            ? const Color(0xFF9E9E9E)
            : state.overloaded
                ? const Color(0xFFFF9800)
                : const Color(0xFF43A047);
    c.drawCircle(Offset(p.dx - w * 0.15, p.dy - height * 0.45), tw * 0.04, Paint()..color = status);

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

  void _wires(Canvas c) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < state.houses.length; i++) {
      if (!state.houses[i].subscribed) continue;
      final a = _genTop, b = _roofPoint(i);
      final mid = Offset((a.dx + b.dx) / 2, max(a.dy, b.dy) + tw * 0.2);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
      c.drawPath(path, paint);
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

  // ---------- اللمس ----------
  @override
  void onTapDown(TapDownEvent event) {
    final pt = Offset(event.localPosition.x, event.localPosition.y);
    // الأقرب للشاشة أولاً
    final order = List<int>.generate(grid.length, (i) => i)
      ..sort((a, b) => (grid[b].dx + grid[b].dy).compareTo(grid[a].dx + grid[a].dy));
    for (final i in order) {
      final p = iso(grid[i].dx, grid[i].dy);
      final rect = Rect.fromLTRB(p.dx - _hw / 2, p.dy - _hHeight - _hh / 2, p.dx + _hw / 2, p.dy + _hh / 2);
      if (rect.contains(pt)) {
        state.select(state.selected == i ? null : i);
        return;
      }
    }
    final gp = iso(genGrid.dx, genGrid.dy);
    final gRect = Rect.fromLTRB(gp.dx - tw * 0.4, gp.dy - tw * 0.6, gp.dx + tw * 0.4, gp.dy + th * 0.4);
    if (gRect.contains(pt)) {
      state.select(state.selected == -1 ? null : -1);
      return;
    }
    state.select(null);
  }
}
