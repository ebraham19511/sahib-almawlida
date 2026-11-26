import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart' show PositionComponent, HasGameReference, Vector2;
import 'package:flame/events.dart' show DragCallbacks, DragStartEvent, DragUpdateEvent, DragEndEvent, DragCancelEvent;
import 'package:flame/game.dart' show FlameGame;
import 'package:flutter/material.dart';

import 'world.dart';

class ArcadeGame extends FlameGame {
  final ArcadeWorld world2;
  ArcadeGame(this.world2);

  @override
  Future<void> onLoad() async {
    add(Arena(world2));
  }

  @override
  void update(double dt) {
    super.update(dt);
    world2.update(min(dt, 0.05));
  }

  @override
  Color backgroundColor() => const Color(0xFF1E2A2F);
}

/// الساحة: ترسم كلشي وتستلم السحب (عصا تحكم بأي مكان)
class Arena extends PositionComponent with DragCallbacks, HasGameReference<FlameGame> {
  final ArcadeWorld wd;
  Arena(this.wd);

  double tile = 40;
  Offset origin = Offset.zero;
  Offset? _joyStart;
  Offset _joyNow = Offset.zero;
  final Map<String, TextPainter> _tp = {};
  final _rnd = Random();

  static double topSpace = 120; // تحت الشريط الفوگاني (يتحدد من الواجهة)

  // صور المدينة (Kenney RPG Urban Pack - CC0)
  ui.Image? _sheet;
  final Paint _px = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  final Paint _thiefPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0xFF6A6A88), BlendMode.modulate);

  @override
  Future<void> onLoad() async {
    size = game.size.clone();
    try {
      _sheet = await game.images.load('city.png');
    } catch (_) {
      _sheet = null; // إذا الصورة ناقصة نرجع للرسم القديم بدل ما توكف اللعبة
    }
  }

  Rect _src(int i) => Rect.fromLTWH((i % 27) * 16.0 + 0.05, (i ~/ 27) * 16.0 + 0.05, 15.9, 15.9);

  void _spr(Canvas c, int i, Rect dst, [Paint? p]) => c.drawImageRect(_sheet!, _src(i), dst, p ?? _px);

  /// يرسم مربع بتسع قطع (زوايا + حواف + وسط) من الصورة
  void _nine(Canvas c, int tl, Rect r, double s) {
    final cols = max(2, (r.width / s).round());
    final rows = max(2, (r.height / s).round());
    final cw = r.width / cols, rh = r.height / rows;
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        final idx = tl + (j == 0 ? 0 : (j == rows - 1 ? 54 : 27)) + (i == 0 ? 0 : (i == cols - 1 ? 2 : 1));
        _spr(c, idx, Rect.fromLTWH(r.left + i * cw, r.top + j * rh, cw + 0.7, rh + 0.7));
      }
    }
  }

  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);
    size = s.clone();
  }

  void _layout() {
    final top = topSpace;
    final avail = size.y - top - 24;
    tile = min(size.x / ArcadeWorld.w, avail / ArcadeWorld.h);
    origin = Offset((size.x - tile * ArcadeWorld.w) / 2, top + (avail - tile * ArcadeWorld.h) / 2);
  }

  Offset P(Offset w) => origin + w * tile;
  Rect R(Rect r) => Rect.fromLTRB(P(r.topLeft).dx, P(r.topLeft).dy, P(r.bottomRight).dx, P(r.bottomRight).dy);

  // ---------- عصا التحكم ----------
  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _joyStart = Offset(event.localPosition.x, event.localPosition.y);
    _joyNow = _joyStart!;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_joyStart == null) return;
    _joyNow += Offset(event.localDelta.x, event.localDelta.y);
    var v = (_joyNow - _joyStart!) / 40;
    final len = v.distance;
    if (len < 0.15) {
      wd.setMove(Offset.zero);
      return;
    }
    // استجابة أسرع: أول ما تسحب شوية يمشي بسرعة زينة
    final mag = min(1.0, 0.55 + 0.45 * len);
    if (len > 1) _joyStart = _joyNow - (v / len) * 40; // العصا تلحك إصبعك
    v = v / len * mag;
    wd.setMove(v);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _joyStart = null;
    wd.setMove(Offset.zero);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _joyStart = null;
    wd.setMove(Offset.zero);
  }

  // ---------- أدوات رسم ----------
  TextPainter _text(String s, double size, Color color) {
    final key = '$s|${size.round()}|${color.toARGB32()}';
    final c = _tp[key];
    if (c != null) return c;
    if (_tp.length > 200) _tp.clear();
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.rtl,
    )..layout();
    _tp[key] = tp;
    return tp;
  }

  void _say(Canvas c, String s, Offset center, double size, Color color) {
    final tp = _text(s, size, color);
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  // ---------- الرسم ----------
  @override
  void render(Canvas c) {
    if (size.x != game.size.x || size.y != game.size.y) size = game.size.clone();
    _layout();
    if (wd.phase == Phase.menu) {
      _menuBackdrop(c);
      return;
    }
    c.save();
    if (wd.shake > 0) {
      c.translate((_rnd.nextDouble() - 0.5) * 10 * wd.shake, (_rnd.nextDouble() - 0.5) * 10 * wd.shake);
    }
    _ground(c);
    for (var i = 0; i < wd.houses.length; i++) {
      _houseShadow(c, wd.houses[i]);
    }
    _generatorDraw(c);
    _wires(c);
    for (var i = 0; i < wd.houses.length; i++) {
      _house(c, wd.houses[i]);
    }
    for (final p in wd.pickups) {
      _pickup(c, p);
    }
    for (final t in wd.thieves) {
      _thief(c, t);
    }
    _player(c);
    _hint(c);
    for (final p in wd.particles) {
      c.drawCircle(P(p.pos), p.size * tile * (0.4 + p.life), Paint()..color = Color(p.color));
    }
    for (final f in wd.floats) {
      final pos = P(f.pos).translate(0, -tile * 0.6 - f.t * 45);
      final a = (255 * (1 - f.t / 1.2)).clamp(0, 255).round();
      final col = Color(f.color);
      final tp = _text(f.text, 20, col);
      c.saveLayer(Rect.fromCenter(center: pos, width: tp.width + 24, height: tp.height + 16), Paint()..color = Color.fromARGB(a, 0, 0, 0));
      final r = Rect.fromCenter(center: pos, width: tp.width + 16, height: tp.height + 8);
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)), Paint()..color = const Color(0xCC000000));
      tp.paint(c, Offset(r.left + 8, r.top + 4));
      c.restore();
    }
    c.restore();
    _joystick(c);
  }

  void _menuBackdrop(Canvas c) {
    // مدينة خفيفة بالخلفية للقائمة
    final t = wd.clock;
    for (var i = 0; i < 18; i++) {
      final x = (i * 73 % 360) / 360 * size.x;
      final hgt = 60 + (i * 37 % 120).toDouble();
      final y = size.y - hgt;
      c.drawRect(Rect.fromLTWH(x - 25, y, 50, hgt), Paint()..color = Color.lerp(const Color(0xFF263238), const Color(0xFF37474F), (i % 3) / 2)!);
      for (var k = 0; k < 3; k++) {
        final on = (sin(t * 1.3 + i * 2 + k) > -0.2);
        c.drawRect(Rect.fromLTWH(x - 15 + k * 11, y + 14, 7, 9), Paint()..color = on ? const Color(0xFFFFD54F) : const Color(0xFF1C262B));
      }
    }
  }

  void _ground(Canvas c) {
    if (_sheet != null) {
      _groundSpr(c);
      return;
    }
    final arena = R(const Rect.fromLTWH(0, 0, ArcadeWorld.w, ArcadeWorld.h));
    c.drawRRect(RRect.fromRectAndRadius(arena.inflate(6), const Radius.circular(18)), Paint()..color = const Color(0xFFBFA77A));
    c.drawRRect(RRect.fromRectAndRadius(arena, const Radius.circular(14)), Paint()..color = const Color(0xFF4A4F57));
    // أرصفة
    for (final hs in wd.houses) {
      c.drawRRect(RRect.fromRectAndRadius(R(hs.rect.inflate(0.18)), Radius.circular(tile * 0.18)), Paint()..color = const Color(0xFFA9ADB2));
    }
    // خطوط الشارع
    final dash = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = tile * 0.06;
    for (var x = 0.3; x < ArcadeWorld.w; x += 0.7) {
      if (x > 3.2 && x < 4.8) continue;
      c.drawLine(P(Offset(x, 5.95)), P(Offset(x + 0.35, 5.95)), dash);
    }
    final dash2 = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = tile * 0.04;
    for (final x in [2.6, 5.4]) {
      for (var y = 0.3; y < ArcadeWorld.h; y += 0.7) {
        if (y > 4.6 && y < 7.3) continue;
        c.drawLine(P(Offset(x, y)), P(Offset(x, y + 0.35)), dash2);
      }
    }
    // عبّارة مشاة
    for (var k = 0; k < 5; k++) {
      final r = Rect.fromLTWH(1.95 + k * 0.25, 4.75, 0.14, 0.45);
      c.drawRect(R(r), Paint()..color = const Color(0x88FFFFFF));
    }
  }

  void _houseShadow(Canvas c, House hs) {
    if (_sheet != null) return;
    c.drawRRect(RRect.fromRectAndRadius(R(hs.rect.shift(const Offset(0.12, 0.14))), Radius.circular(tile * 0.15)),
        Paint()..color = const Color(0x55000000));
  }

  Color _mix(int a, int b, double t) => Color.lerp(Color(a), Color(b), t)!;

  void _house(Canvas c, House hs) {
    if (_sheet != null) {
      _houseSpr(c, hs);
      return;
    }
    final r = R(hs.rect);
    final pulse = (sin(wd.clock * (hs.dark < 3 ? 14 : 7)) + 1) / 2;
    if (hs.lit) {
      c.drawRRect(RRect.fromRectAndRadius(r.inflate(tile * 0.25), Radius.circular(tile * 0.4)), Paint()..color = const Color(0x22FFE082));
    }
    final roof = hs.lit ? Color(hs.color) : _mix(hs.color, 0xFF2B2B33, 0.6);
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(tile * 0.15)), Paint()..color = roof);
    // حافة السطح
    c.drawRRect(
      RRect.fromRectAndRadius(r.deflate(tile * 0.06), Radius.circular(tile * 0.12)),
      Paint()
        ..color = Color.lerp(roof, Colors.black, 0.25)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = tile * 0.08,
    );
    // خزان ماء، سبلت، دش
    final tank = Offset(r.left + tile * 0.4, r.top + tile * 0.4);
    c.drawCircle(tank.translate(2, 3), tile * 0.2, Paint()..color = const Color(0x33000000));
    c.drawCircle(tank, tile * 0.2, Paint()..color = const Color(0xFFF5F5F5));
    c.drawCircle(tank, tile * 0.12, Paint()..color = const Color(0xFFE0E0E0));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.right - tile * 0.62, r.top + tile * 0.22, tile * 0.42, tile * 0.26), Radius.circular(tile * 0.05)),
        Paint()..color = const Color(0xFFECEFF1));
    c.drawOval(Rect.fromCenter(center: Offset(r.right - tile * 0.35, r.bottom - tile * 0.35), width: tile * 0.3, height: tile * 0.2),
        Paint()..color = const Color(0xFFBDBDBD));
    // شبابيك السطح تضوي
    for (var k = 0; k < 3; k++) {
      final wr = Rect.fromLTWH(r.left + tile * (0.3 + k * 0.38), r.bottom - tile * 0.45, tile * 0.22, tile * 0.16);
      c.drawRect(wr, Paint()..color = hs.lit ? const Color(0xFFFFD54F) : const Color(0xFF263238));
    }
    if (hs.flash > 0) {
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(tile * 0.15)),
          Paint()..color = Color.fromARGB((hs.flash / 0.6 * 200).round().clamp(0, 255), 255, 255, 255));
    }
    if (!hs.lit) {
      final center = r.center;
      final rad = tile * 0.55;
      c.drawCircle(center, rad + pulse * tile * 0.15, Paint()..color = Color.fromARGB((80 + pulse * 80).round(), 255, 23, 68));
      c.drawCircle(center, rad, Paint()..color = const Color(0xEE1A1A1A));
      c.drawArc(
        Rect.fromCircle(center: center, radius: rad),
        -pi / 2,
        2 * pi * (hs.dark / wd.cfg.darkTimeout).clamp(0.0, 1.0),
        false,
        Paint()
          ..color = hs.dark < 3 ? const Color(0xFFFF1744) : const Color(0xFFFFC107)
          ..style = PaintingStyle.stroke
          ..strokeWidth = tile * 0.1,
      );
      _say(c, '⚡', center, tile * 0.5, Colors.white);
    }
    if (hs.angry > 0) {
      _say(c, '😡', r.topCenter.translate(0, -tile * 0.2 - (2.5 - hs.angry) * 10), tile * 0.6, Colors.white);
    }
  }

  void _generatorDraw(Canvas c) {
    final g = ArcadeWorld.generator;
    final on = wd.generatorOn;
    final shake = on ? sin(wd.clock * 60) * 1.2 : 0.0;
    final r = R(g).shift(Offset(shake, 0));
    c.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(5, 6)), Radius.circular(tile * 0.15)), Paint()..color = const Color(0x55000000));
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(tile * 0.15)), Paint()..color = on ? const Color(0xFF2E7D32) : const Color(0xFF616161));
    for (var k = 0; k < 5; k++) {
      final x = r.left + tile * 0.15 + k * tile * 0.13;
      c.drawLine(Offset(x, r.top + tile * 0.2), Offset(x, r.bottom - tile * 0.2), Paint()
        ..color = const Color(0x55000000)
        ..strokeWidth = 2);
    }
    // مروحة تدور
    final fan = Offset(r.right - tile * 0.35, r.center.dy);
    c.drawCircle(fan, tile * 0.28, Paint()..color = const Color(0xFF1B5E20));
    final ang = on ? wd.clock * 20 : 0.0;
    for (var k = 0; k < 3; k++) {
      final a = ang + k * 2 * pi / 3;
      c.drawLine(fan, fan + Offset(cos(a), sin(a)) * tile * 0.24, Paint()
        ..color = const Color(0xFFA5D6A7)
        ..strokeWidth = tile * 0.07
        ..strokeCap = StrokeCap.round);
    }
    // عداد الكاز حول المولدة
    if (wd.cfg.fuelDrain > 0) {
      final ring = r.inflate(tile * 0.22);
      final col = Color.lerp(const Color(0xFFFF1744), const Color(0xFF69F0AE), wd.fuel)!;
      c.drawRRect(
        RRect.fromRectAndRadius(ring, Radius.circular(tile * 0.3)),
        Paint()
          ..color = const Color(0x44FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = tile * 0.1,
      );
      final w = ring.width * wd.fuel;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ring.left, ring.bottom - tile * 0.12, w, tile * 0.12), const Radius.circular(4)),
          Paint()..color = col);
      if (!on) _say(c, '⛽', r.center.translate(0, -tile * 0.9 - (sin(wd.clock * 8) * 4)), tile * 0.6, Colors.white);
    }
    // دخان
    if (on) {
      for (var k = 0; k < 4; k++) {
        final t = (wd.clock * 0.7 + k / 4) % 1;
        c.drawCircle(Offset(r.left + tile * 0.3 + t * tile * 0.4, r.top - t * tile * 1.0), tile * (0.08 + t * 0.18),
            Paint()..color = Color.fromARGB((120 * (1 - t)).round(), 200, 200, 200));
      }
    }
  }

  void _wires(Canvas c) {
    final g = P(ArcadeWorld.generator.center);
    for (var i = 0; i < wd.houses.length; i++) {
      final hs = wd.houses[i];
      final end = P(hs.center);
      final mid = Offset((g.dx + end.dx) / 2, (g.dy + end.dy) / 2 + tile * 0.4);
      final path = Path()
        ..moveTo(g.dx, g.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
      final live = hs.lit && wd.generatorOn;
      c.drawPath(
        path,
        Paint()
          ..color = live ? const Color(0x88FFE082) : const Color(0x55000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = live ? 2.5 : 1.5,
      );
      if (live) {
        // كهرباء تجري بالواير
        final t = (wd.clock * 0.9 + i * 0.137) % 1;
        final q = _bezier(g, mid, end, t);
        c.drawCircle(q, 3.2, Paint()..color = const Color(0xFFFFF59D));
      }
    }
  }

  Offset _bezier(Offset a, Offset b, Offset c, double t) {
    final u = 1 - t;
    return a * (u * u) + b * (2 * u * t) + c * (t * t);
  }

  void _pickup(Canvas c, Pickup p) {
    final bob = sin(wd.clock * 5 + p.pos.dx) * 4;
    final pos = P(p.pos).translate(0, bob);
    final blink = p.life < 2.5 && (wd.clock * 8).floor().isEven;
    if (blink) return;
    c.drawCircle(P(p.pos).translate(0, tile * 0.25), tile * 0.22, Paint()..color = const Color(0x44000000));
    if (p.kind == 0) {
      c.drawCircle(pos, tile * 0.45, Paint()..color = const Color(0x33FFB300));
      final r = Rect.fromCenter(center: pos, width: tile * 0.5, height: tile * 0.62);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(tile * 0.08)), Paint()..color = const Color(0xFFD32F2F));
      c.drawRect(Rect.fromLTWH(r.left, r.center.dy - tile * 0.05, r.width, tile * 0.1), Paint()..color = const Color(0xFFFFFFFF));
      c.drawRect(Rect.fromLTWH(r.right - tile * 0.18, r.top - tile * 0.1, tile * 0.12, tile * 0.12), Paint()..color = const Color(0xFF424242));
    } else {
      c.drawCircle(pos, tile * 0.42, Paint()..color = const Color(0xFF0288D1));
      _say(c, '🛵', pos, tile * 0.45, Colors.white);
    }
  }

  void _thief(Canvas c, Thief t) {
    if (_sheet != null) {
      _thiefSpr(c, t);
      return;
    }
    final p = P(t.pos);
    final s = tile * 0.3;
    c.drawCircle(p.translate(3, 4), s, Paint()..color = const Color(0x55000000));
    c.drawCircle(p, s * 1.6, Paint()..color = Color.fromARGB(((sin(wd.clock * 10) + 1) * 40).round(), 255, 23, 68));
    c.drawCircle(p, s, Paint()..color = const Color(0xFF151515));
    c.drawCircle(p.translate(-s * 0.7, s * 0.2), s * 0.5, Paint()..color = const Color(0xFF795548)); // كيس
    c.drawCircle(p.translate(0, -s * 0.1), s * 0.55, Paint()..color = const Color(0xFF151515));
    c.drawRect(Rect.fromCenter(center: p.translate(0, -s * 0.15), width: s * 1.0, height: s * 0.22), Paint()..color = Colors.white);
    if (!t.leaving) _say(c, '!', p.translate(0, -s * 2), tile * 0.45, const Color(0xFFFF1744));
  }

  void _player(Canvas c) {
    if (_sheet != null) {
      _playerSpr(c);
      return;
    }
    final p = P(wd.player);
    final s = tile * 0.32;
    final moving = wd.move.distance > 0.05;
    final bob = moving ? sin(wd.clock * 18) * 2 : 0.0;
    if (wd.boostTimer > 0) {
      c.drawCircle(p, s * 1.8, Paint()..color = const Color(0x5580D8FF));
    }
    c.drawCircle(p.translate(3, 5), s, Paint()..color = const Color(0x55000000));
    // حلقة صفرة تحت اللاعب
    c.drawCircle(
      p,
      s * 1.35,
      Paint()
        ..color = const Color(0xFFFFC107)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // الأكتاف (سترة برتقالية بشريط عاكس)
    c.drawCircle(p.translate(0, bob), s, Paint()..color = const Color(0xFFFF8F00));
    c.drawRect(Rect.fromCenter(center: p.translate(0, bob), width: s * 2, height: s * 0.25), Paint()..color = const Color(0xFFE0F7FA));
    // الراس والكاب باتجاه الحركة
    final dir = Offset(cos(wd.face), sin(wd.face));
    final head = p.translate(dir.dx * s * 0.25, dir.dy * s * 0.25 + bob);
    c.drawCircle(head, s * 0.55, Paint()..color = const Color(0xFFC99A6E));
    c.drawCircle(head.translate(-dir.dx * s * 0.1, -dir.dy * s * 0.1), s * 0.48, Paint()..color = const Color(0xFF212121));
    c.drawCircle(head + dir * s * 0.45, s * 0.22, Paint()..color = const Color(0xFF212121)); // حافة الكاب
  }

  void _hint(Canvas c) {
    if (wd.hintTime <= 0) return;
    House? target;
    var bd = 1e9;
    for (final hs in wd.houses) {
      if (hs.lit) continue;
      final d = (hs.center - wd.player).distance;
      if (d < bd) {
        bd = d;
        target = hs;
      }
    }
    if (target == null) return;
    final a = P(wd.player), b = P(target.center);
    final v = b - a;
    final len = v.distance;
    if (len < tile) return;
    final dir = v / len;
    for (var d = tile * 0.8; d < len - tile * 0.6; d += tile * 0.45) {
      final q = a + dir * (d + (wd.clock * 40) % (tile * 0.45));
      c.drawCircle(q, 4, Paint()..color = const Color(0xFFFFEB3B));
    }
  }

  void _joystick(Canvas c) {
    final s = _joyStart;
    if (s == null) return;
    c.drawCircle(s, 40, Paint()..color = const Color(0x33FFFFFF));
    c.drawCircle(
      s,
      40,
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    var v = _joyNow - s;
    if (v.distance > 40) v = v / v.distance * 40;
    c.drawCircle(s + v, 24, Paint()..color = const Color(0xCCFFC107));
  }

  // ================== رسم بالصور الحقيقية ==================

  void _groundSpr(Canvas c) {
    final arena = R(const Rect.fromLTWH(0, 0, ArcadeWorld.w, ArcadeWorld.h));
    // إطار رصيف حول الساحة
    _nine(c, 8, arena.inflate(tile * 0.35), tile * 0.5);
    c.save();
    c.clipRect(arena);
    final s = tile * 0.5;
    for (var y = arena.top; y < arena.bottom; y += s) {
      for (var x = arena.left; x < arena.right; x += s) {
        _spr(c, 441, Rect.fromLTWH(x, y, s + 0.7, s + 0.7));
      }
    }
    c.restore();
    // أرصفة البيوت
    for (final hs in wd.houses) {
      _nine(c, 8, R(hs.rect.inflate(0.2)), tile * 0.4);
    }
    // خطوط الشارع
    final dash = Paint()
      ..color = const Color(0xDDFFFFFF)
      ..strokeWidth = tile * 0.06;
    for (var x = 0.3; x < ArcadeWorld.w; x += 0.7) {
      if (x > 3.2 && x < 4.8) continue;
      c.drawLine(P(Offset(x, 5.95)), P(Offset(x + 0.35, 5.95)), dash);
    }
    // عبّارة مشاة
    for (var k = 0; k < 2; k++) {
      _spr(c, 434, R(Rect.fromLTWH(2.0 + k * 0.6, 4.75, 0.6, 0.45)));
    }
    for (var k = 0; k < 2; k++) {
      _spr(c, 434, R(Rect.fromLTWH(2.1 + k * 0.5, 7.25, 0.5, 0.45)));
      _spr(c, 434, R(Rect.fromLTWH(4.9 + k * 0.5, 4.2, 0.5, 0.45)));
    }
    // أعمدة إنارة وأشجار صغيرة بزوايا الأرصفة (زينة بس)
    var k = 0;
    for (final hs in wd.houses) {
      final r = R(hs.rect.inflate(0.2));
      final ts = tile * 0.45;
      if (k % 2 == 0) {
        _spr(c, 260, Rect.fromLTWH(r.left - ts * 0.2, r.top - ts * 1.2, ts, ts));
        _spr(c, 287, Rect.fromLTWH(r.left - ts * 0.2, r.top - ts * 0.2, ts, ts));
      } else {
        _spr(c, 165, Rect.fromLTWH(r.right - ts * 0.8, r.top - ts * 1.1, ts, ts));
        _spr(c, 192, Rect.fromLTWH(r.right - ts * 0.8, r.top - ts * 0.1, ts, ts));
      }
      k++;
    }
  }

  void _houseSpr(Canvas c, House hs) {
    final r = R(hs.rect);
    final idx = wd.houses.indexOf(hs);
    final pulse = (sin(wd.clock * (hs.dark < 3 ? 14 : 7)) + 1) / 2;
    // ظل
    c.drawRect(r.shift(Offset(tile * 0.1, tile * 0.12)), Paint()..color = const Color(0x55000000));
    if (hs.lit) {
      c.drawRRect(RRect.fromRectAndRadius(r.inflate(tile * 0.22), Radius.circular(tile * 0.3)), Paint()..color = const Color(0x30FFE082));
    }
    // السطح (فوك) + الواجهة (جوه)
    final wallH = r.height * 0.42;
    final roof = Rect.fromLTRB(r.left, r.top, r.right, r.bottom - wallH);
    final wall = Rect.fromLTRB(r.left, r.bottom - wallH, r.right, r.bottom);
    _nine(c, idx % 2 == 0 ? 81 : 89, roof, tile * 0.4);
    // خزان ماء على السطح
    _spr(c, 280, Rect.fromLTWH(roof.left + tile * 0.12, roof.top + tile * 0.1, tile * 0.38, tile * 0.38));
    // جدار طابوق
    final brick = idx % 3 == 0 ? 72 : (idx % 3 == 1 ? 180 : 99);
    final cols = 4;
    final cw = wall.width / cols;
    for (var i = 0; i < cols; i++) {
      final cell = Rect.fromLTWH(wall.left + i * cw, wall.top, cw + 0.7, wall.height + 0.7);
      _spr(c, brick, cell);
      final sq = min(cw, wall.height) * 0.92;
      final win = Rect.fromCenter(center: cell.center, width: sq, height: sq);
      if (i == 2) {
        _spr(c, 285, win);
      } else {
        _spr(c, 336, win);
        // الشباك يضوي إذا البيت بيه كهرباء
        final glass = win.deflate(sq * 0.32);
        c.drawRect(glass, Paint()..color = hs.lit ? const Color(0xDDFFD54F) : const Color(0xCC10141C));
        if (hs.lit) c.drawRect(glass.inflate(sq * 0.12), Paint()..color = const Color(0x33FFE082));
      }
    }
    // البيت المطفي يصير معتم
    if (!hs.lit) {
      c.drawRect(r, Paint()..color = const Color(0x88000018));
    }
    if (hs.flash > 0) {
      c.drawRect(r, Paint()..color = Color.fromARGB((hs.flash / 0.6 * 200).round().clamp(0, 255), 255, 255, 255));
    }
    if (!hs.lit) {
      final center = roof.center;
      final rad = tile * 0.45;
      c.drawCircle(center, rad + pulse * tile * 0.15, Paint()..color = Color.fromARGB((80 + pulse * 80).round(), 255, 23, 68));
      c.drawCircle(center, rad, Paint()..color = const Color(0xEE1A1A1A));
      c.drawArc(
        Rect.fromCircle(center: center, radius: rad),
        -pi / 2,
        2 * pi * (hs.dark / wd.cfg.darkTimeout).clamp(0.0, 1.0),
        false,
        Paint()
          ..color = hs.dark < 3 ? const Color(0xFFFF1744) : const Color(0xFFFFC107)
          ..style = PaintingStyle.stroke
          ..strokeWidth = tile * 0.1,
      );
      _say(c, '⚡', center, tile * 0.45, Colors.white);
    }
    if (hs.angry > 0) {
      _say(c, '😡', r.topCenter.translate(0, -tile * 0.2 - (2.5 - hs.angry) * 10), tile * 0.6, Colors.white);
    }
  }

  /// يختار إطار الشخصية: col0 يسار، col1 جوه، col2 فوك، col3 يمين. الصف 0 واكف، 1 و2 مشي
  int _charFrame(int base, Offset dir, bool moving, double phase) {
    int col;
    if (dir.dx.abs() > dir.dy.abs()) {
      col = dir.dx < 0 ? 0 : 3;
    } else {
      col = dir.dy > 0 ? 1 : 2;
    }
    var row = 0;
    if (moving) {
      const cyc = [1, 0, 2, 0];
      row = cyc[(phase * 10).floor() % 4];
    }
    return base + row * 27 + col;
  }

  void _drawChar(Canvas c, int frame, Offset feet, double h, [Paint? p]) {
    c.drawOval(Rect.fromCenter(center: feet, width: h * 0.6, height: h * 0.22), Paint()..color = const Color(0x66000000));
    _spr(c, frame, Rect.fromLTWH(feet.dx - h / 2, feet.dy - h * 0.95, h, h), p);
  }

  void _playerSpr(Canvas c) {
    final p = P(wd.player);
    final h = tile * 0.95;
    final moving = wd.move.distance > 0.05;
    if (wd.boostTimer > 0) {
      c.drawCircle(p.translate(0, -h * 0.35), h * 0.75, Paint()..color = const Color(0x5580D8FF));
    }
    c.drawOval(
      Rect.fromCenter(center: p.translate(0, h * 0.18), width: h * 0.9, height: h * 0.34),
      Paint()
        ..color = const Color(0xFFFFC107)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final dir = Offset(cos(wd.face), sin(wd.face));
    _drawChar(c, _charFrame(266, dir, moving, wd.clock * (wd.boostTimer > 0 ? 1.6 : 1.0)), p.translate(0, h * 0.18), h);
  }

  void _thiefSpr(Canvas c, Thief t) {
    final p = P(t.pos);
    final h = tile * 0.9;
    final goal = t.leaving ? const Offset(-1, 6) : wd.houses[t.target].center;
    final d = goal - t.pos;
    c.drawCircle(p.translate(0, -h * 0.3), h * 0.6, Paint()..color = Color.fromARGB(((sin(wd.clock * 10) + 1) * 45).round(), 255, 23, 68));
    _drawChar(c, _charFrame(347, d, true, wd.clock + t.life), p.translate(0, h * 0.2), h, _thiefPaint);
    if (!t.leaving) _say(c, '!', p.translate(0, -h * 1.0), tile * 0.45, const Color(0xFFFF1744));
  }
}
