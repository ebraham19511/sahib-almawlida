import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart' show PositionComponent, HasGameReference, Vector2;
import 'package:flame/events.dart' show TapCallbacks, TapDownEvent;
import 'package:flame/game.dart' show FlameGame;
import 'package:flutter/material.dart';

import 'people.dart';
import 'state.dart';

class _Puff {
  double x, y, age = 0;
  final bool dark;
  _Puff(this.x, this.y, this.dark);
}

class _Car {
  double x;
  final double lane;
  final double dir;
  final double maxSpeed;
  final int color;
  final int kind; // 0 تكسي، 1 كيا، 2 بيكب
  double speed;
  double honk = 0;
  _Car(this.x, this.lane, this.dir, this.maxSpeed, this.color, this.kind) : speed = maxSpeed;
}

class _Walker {
  double x;
  final double lane;
  double dir;
  final double speed;
  final PersonLook look;
  final double minX, maxX;
  String? say;
  double sayTime = 0;
  double greetCool = 0;
  _Walker(this.x, this.lane, this.dir, this.speed, this.look, {this.minX = -1.5, this.maxX = 8.5});
}

class _Filler {
  final double gx, gy;
  final int seed;
  _Filler(this.gx, this.gy, this.seed);
}

class _Cat {
  double x, y, dx, dy, turn = 0;
  final int color;
  _Cat(this.x, this.y, this.color)
      : dx = 0.3,
        dy = 0;
}

/// المحلة كاملة بمنظور مائل، والكاميرا تلحگ اللاعب
class AlleyScene extends PositionComponent with TapCallbacks, HasGameReference<FlameGame> {
  final GameState state;
  AlleyScene(this.state);

  static const List<int> _brick = [
    0xFFC9A27E, 0xFFB98B6A, 0xFFD8B994, 0xFFA97C5A, 0xFFCFAE8A, 0xFFBF9670, 0xFFD2B48C, 0xFFAD8462,
    0xFFC4A07A, 0xFFB58E6B, 0xFFDCC7A1, 0xFFE6E0D4, 0xFFB7957A, 0xFFC9B08E, 0xFF9FB4C7, 0xFFD6C3A5,
  ];
  static const List<double> _heights = [
    0.62, 0.75, 0.58, 0.68, 0.9, 0.66, 0.6, 0.72, 0.64, 0.92, 0.7, 0.8, 0.6, 0.74, 0.68, 0.86,
  ];
  static const List<Offset> _palms = [Offset(-1, 7.1), Offset(2.4, 7.1), Offset(4.9, 7.1), Offset(7.6, 7.1), Offset(8.4, 4.1)];
  static const _greetings = ['هلا أبو المولدة!', 'الله بالخير 👋', 'دير بالك عالكهرباء!', 'مرحبا عمي', 'شلونك؟'];

  final _rnd = Random();
  final List<_Puff> _puffs = [];
  late final List<_Car> _cars;
  late final List<_Walker> _walkers;
  late final List<_Cat> _cats;
  late final List<Offset> _stars;
  final Map<String, TextPainter> _tpCache = {};
  final Map<String, ui.Image> _img = {};
  final List<_Filler> _fillers = [];
  static const _spriteNames = [
    'house_1', 'house_2', 'house_3', 'house_4', 'house_5', 'house_6',
    'generator', 'tea_house', 'mosque', 'bakery', 'shop', 'palm',
  ];
  double _puffTimer = 0;
  double _bakeryTimer = 0;
  double tw = 90, th = 45;
  double camX = 3.5, camY = 2.3;
  Offset origin = Offset.zero;
  Offset _screenCenter = Offset.zero;
  double _top = 205, _bottom = 600;
  double _light = 1;
  Offset _exhaust = Offset.zero;
  Offset _genTop = Offset.zero;

  @override
  Future<void> onLoad() async {
    final r = Random(7);
    _stars = List.generate(60, (_) => Offset(r.nextDouble(), r.nextDouble()));
    _cars = [
      _Car(-2, 5.2, 1, 1.6, 0xFFF5F5F5, 0),
      _Car(4, 5.2, 1, 1.3, 0xFFE0E0E0, 1),
      _Car(9, 5.8, -1, 1.8, 0xFFC62828, 2),
      _Car(3, 5.8, -1, 1.5, 0xFFFFB300, 0),
    ];
    _walkers = [
      _Walker(-1, 1.25, 1, 0.45, PersonLook.dishdasha),
      _Walker(6, 1.75, -1, 0.4, PersonLook.abaya),
      _Walker(2, 4.05, 1, 0.5, PersonLook.shemagh),
      _Walker(7, 3.95, -1, 0.25, PersonLook.oldMan),
      _Walker(0, 6.95, 1, 0.55, PersonLook.dishdasha),
      _Walker(5, 7.05, -1, 0.45, PersonLook.abaya),
      _Walker(3, 6.9, 1, 0.65, PersonLook.kid),
    ];
    _cats = [_Cat(0.5, 3.9, 0xFFFF9800), _Cat(6.5, 7.2, 0xFF424242)];
    // الصور الحقيقية إذا موجودة
    for (final n in _spriteNames) {
      try {
        _img[n] = await game.images.load('$n.png');
      } catch (_) {}
    }
    // بنايات تملي أطراف المدينة حتى ما يبقى فراغ
    var seed = 11;
    void row(double gy, double from, double to) {
      for (var gx = from; gx <= to; gx += 1) {
        _fillers.add(_Filler(gx, gy, seed++));
      }
    }
    row(-1.6, -5, 13);
    row(-2.8, -5, 13);
    row(9.3, -5, 13);
    row(10.5, -5, 13);
    for (final gx in [-2.5, -3.7, 9.6, 10.8]) {
      for (final gy in [0.0, 1.0, 2.0, 3.0, 4.0, 7.0, 8.0]) {
        _fillers.add(_Filler(gx, gy, seed++));
      }
    }
    size = game.size.clone();
    camX = state.px;
    camY = state.py;
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
    _top = topUi;
    _bottom = size.y - bottomUi;
    tw = min(size.x * 0.26, 140.0);
    th = tw / 2;
    _screenCenter = Offset(size.x / 2, topUi + (size.y - topUi - bottomUi) * 0.55);
  }

  Offset iso(double gx, double gy) => Offset(origin.dx + (gx - gy) * tw / 2, origin.dy + (gx + gy) * th / 2);

  Offset _isoRaw(double gx, double gy) => Offset((gx - gy) * tw / 2, (gx + gy) * th / 2);

  // ---------- الحركة ----------
  @override
  void update(double dt) {
    super.update(dt);
    final f = min(1.0, dt * 5);
    camX += (state.px - camX) * f;
    camY += (state.py - camY) * f;

    if (state.generating) {
      _puffTimer += dt;
      final every = state.overloaded ? 0.08 : 0.18;
      while (_puffTimer > every) {
        _puffTimer -= every;
        _puffs.add(_Puff(_exhaust.dx - origin.dx, _exhaust.dy - origin.dy, state.overloaded || state.health < 30));
      }
    }
    _bakeryTimer += dt;
    if (_bakeryTimer > 0.4) {
      _bakeryTimer = 0;
      final b = _isoRaw(GameState.bakeryPos.dx + 0.25, GameState.bakeryPos.dy - 0.25);
      _puffs.add(_Puff(b.dx, b.dy - tw * 0.85, false));
    }
    for (final p in _puffs) {
      p.age += dt;
      p.y -= tw * 0.35 * dt;
      p.x += tw * 0.12 * dt;
    }
    _puffs.removeWhere((p) => p.age > 2.5);

    if (state.overlayOpen) return;

    // السيارات
    for (final c in _cars) {
      var target = c.maxSpeed;
      final ahead = (state.px - c.x) * c.dir;
      if ((state.py - c.lane).abs() < 0.45 && ahead > 0 && ahead < 1.4) {
        target = 0;
        if (c.honk <= 0) c.honk = 1.2;
      }
      for (final o in _cars) {
        if (o == c || o.lane != c.lane) continue;
        final d = (o.x - c.x) * c.dir;
        if (d > 0 && d < 1.5) target = 0;
      }
      c.speed += (target - c.speed) * min(1.0, dt * 4);
      c.x += c.dir * c.speed * dt;
      if (c.honk > 0) c.honk -= dt;
      if (c.dir > 0 && c.x > 12) c.x = -4;
      if (c.dir < 0 && c.x < -4) c.x = 12;
    }

    // الناس
    for (final w in _walkers) {
      if (w.sayTime > 0) w.sayTime -= dt;
      if (w.greetCool > 0) w.greetCool -= dt;
      final near = (state.px - w.x).abs() < 0.4 && (state.py - w.lane).abs() < 0.4;
      if (near) {
        if (w.greetCool <= 0) {
          w.say = _greetings[_rnd.nextInt(_greetings.length)];
          w.sayTime = 2.5;
          w.greetCool = 8;
        }
        continue;
      }
      w.x += w.dir * w.speed * dt;
      if (w.x > w.maxX) w.dir = -1;
      if (w.x < w.minX) w.dir = 1;
    }

    // الگطط
    for (final c in _cats) {
      c.turn -= dt;
      if (c.turn <= 0) {
        c.turn = 1.5 + _rnd.nextDouble() * 2;
        final a = _rnd.nextDouble() * 2 * pi;
        final sp = _rnd.nextDouble() < 0.3 ? 0.0 : 0.35;
        c.dx = cos(a) * sp;
        c.dy = sin(a) * sp * 0.4;
      }
      c.x = (c.x + c.dx * dt).clamp(-1.5, 8.5).toDouble();
      c.y = (c.y + c.dy * dt).clamp(3.7, 7.4).toDouble();
      if (c.y > 4.4 && c.y < 6.6) c.y = c.dy > 0 ? 6.6 : 4.4; // ما تنزل للشارع
    }
  }

  // ---------- الرسم ----------
  @override
  void render(Canvas c) {
    if (size.x != game.size.x || size.y != game.size.y) {
      size = game.size.clone();
      _layout();
    }
    origin = _screenCenter - _isoRaw(camX, camY);
    _light = state.light;

    _sky(c);
    _ground(c);
    _shadows(c);

    final items = <MapEntry<double, void Function()>>[];
    for (var i = 0; i < GameState.houseCount; i++) {
      final g = GameState.housePos(i);
      items.add(MapEntry(g.dx + g.dy, () => _house(c, i)));
    }
    const gp = GameState.genPos;
    items.add(MapEntry(gp.dx + gp.dy, () => _generator(c)));
    for (final p in GameState.poles) {
      items.add(MapEntry(p.dx + p.dy, () => _pole(c, p)));
    }
    items.add(MapEntry(GameState.teaPos.dx + GameState.teaPos.dy, () => _teaHouse(c)));
    items.add(MapEntry(GameState.mosquePos.dx + GameState.mosquePos.dy, () => _mosque(c)));
    items.add(MapEntry(GameState.bakeryPos.dx + GameState.bakeryPos.dy, () => _bakery(c)));
    for (final p in _palms) {
      items.add(MapEntry(p.dx + p.dy, () => _palm(c, p)));
    }
    for (final f in _fillers) {
      items.add(MapEntry(f.gx + f.gy, () => _filler(c, f)));
    }
    for (var k = 0; k < GameState.shops.length; k++) {
      final sp = GameState.shops[k];
      items.add(MapEntry(sp.dx + sp.dy, () => _shop(c, k)));
    }
    for (final car in _cars) {
      items.add(MapEntry(car.x + car.lane, () => _car(c, car)));
    }
    for (final w in _walkers) {
      items.add(MapEntry(w.x + w.lane, () => _walker(c, w)));
    }
    for (final cat in _cats) {
      items.add(MapEntry(cat.x + cat.y, () => _cat(c, cat)));
    }
    // جهال يلعبون طوبة بالزگاق، وشيبان گاعدين گدام الجايخانة
    items.add(MapEntry(5.4 + 1.3, () => _football(c)));
    items.add(MapEntry(1 + 7.35, () => _teaSitters(c)));
    items.add(MapEntry(state.px + state.py, () => _player(c)));
    items.sort((a, b) => a.key.compareTo(b.key));
    for (final it in items) {
      it.value();
    }
    _wires(c);
    _smoke(c);
    _thief(c);
    _bubbles(c);
    _questMarks(c);
    _carHonks(c);
    _sunMoon(c);
    _edgeMarkers(c);
  }

  Color _shade(int argb, [double extra = 1]) {
    final k = (0.32 + 0.68 * _light) * extra;
    int ch(int shift) => (((argb >> shift) & 0xFF) * k).clamp(0, 255).round();
    return Color.fromARGB(255, ch(16), ch(8), ch(0));
  }

  TextPainter _tp(String s, double size, Color color, {bool bold = false}) {
    final key = '$s|${size.toStringAsFixed(1)}|${color.toARGB32()}|$bold';
    final cached = _tpCache[key];
    if (cached != null) return cached;
    if (_tpCache.length > 300) _tpCache.clear();
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    _tpCache[key] = tp;
    return tp;
  }

  void _text(Canvas c, String s, Offset center, double fontSize, Color color, {bool bold = false}) {
    final tp = _tp(s, fontSize, color, bold: bold);
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  Color get _skyColor => Color.lerp(const Color(0xFF0B1630), const Color(0xFF8EC5E8), _light)!;

  void _sky(Canvas c) {
    c.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = _skyColor);
    final starAlpha = ((0.45 - _light) * 2.5).clamp(0.0, 1.0);
    if (starAlpha > 0) {
      final p = Paint()..color = Color.fromARGB((starAlpha * 220).round(), 255, 255, 255);
      for (final s in _stars) {
        c.drawCircle(Offset(s.dx * size.x, s.dy * size.y), 1.2, p);
      }
    }
  }

  // الشمس والگمر بزاوية فوك حتى يبينون
  void _sunMoon(Canvas c) {
    final phase = state.dayProgress;
    final y0 = _top + 30;
    final sunT = (phase - 0.25) * 2;
    if (sunT > 0 && sunT < 1) {
      final pos = Offset(size.x * (0.92 - 0.84 * sunT), y0 + 40 - 40 * sin(pi * sunT));
      c.drawCircle(pos, 22, Paint()..color = const Color(0x44FFE082));
      c.drawCircle(pos, 14, Paint()..color = const Color(0xFFFFD54F));
    }
    final moonT = (((phase + 0.5) % 1) - 0.25) * 2;
    if (moonT > 0 && moonT < 1) {
      final pos = Offset(size.x * (0.92 - 0.84 * moonT), y0 + 40 - 40 * sin(pi * moonT));
      c.drawCircle(pos, 11, Paint()..color = const Color(0xFFF5F3E7));
      c.drawCircle(pos.translate(5, -3), 9, Paint()..color = _skyColor);
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
      ..color = const Color(0x1F000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final cx = camX.round(), cy = camY.round();
    for (var gx = cx - 9; gx <= cx + 9; gx++) {
      for (var gy = cy - 9; gy <= cy + 9; gy++) {
        final p = iso(gx.toDouble(), gy.toDouble());
        if (p.dx < -tw || p.dx > size.x + tw || p.dy < -th || p.dy > size.y + th) continue;
        int col;
        if (gx < -2 || gx > 9 || gy < -1 || gy > 8) {
          col = 0xFFBFAF8A; // برّه المحلة
        } else if (gy == 1 || gy == 2) {
          col = 0xFF5B5E63; // الزگاق
        } else if (gy == 5 || gy == 6) {
          col = 0xFF44474C; // الشارع العام
        } else if (gy == 4 || gy == 7) {
          col = (gx + gy).isEven ? 0xFFB0B4B8 : 0xFFA4A8AD; // رصيف
        } else {
          col = 0xFFD9C9A3;
        }
        final path = _diamond(p, tw, th);
        c.drawPath(path, Paint()..color = _shade(col));
        c.drawPath(path, line);
      }
    }
    final dash = Paint()
      ..color = _shade(0xFFF5F5F5)
      ..strokeWidth = 2.5;
    for (var gx = cx - 9; gx <= cx + 9; gx++) {
      c.drawLine(iso(gx + 0.1, 5.5), iso(gx + 0.55, 5.5), dash);
    }
    final kerb = Paint()
      ..color = _shade(0xFFE0E0E0)
      ..strokeWidth = 2;
    c.drawLine(iso(cx - 9.0, 4.5), iso(cx + 9.0, 4.5), kerb);
    c.drawLine(iso(cx - 9.0, 6.5), iso(cx + 9.0, 6.5), kerb);
  }

  // متوازي مستطيلات على الشبكة: lx على اتجاه gx، ly على اتجاه gy
  void _prism(Canvas c, double gx, double gy, double lx, double ly, double h, Color top, Color left, Color right,
      {double lift = 0}) {
    Offset up(Offset o) => Offset(o.dx, o.dy - lift);
    final a = up(iso(gx - lx / 2, gy - ly / 2));
    final b = up(iso(gx + lx / 2, gy - ly / 2));
    final f = up(iso(gx + lx / 2, gy + ly / 2));
    final d = up(iso(gx - lx / 2, gy + ly / 2));
    final lf = Path()
      ..moveTo(d.dx, d.dy)
      ..lineTo(f.dx, f.dy)
      ..lineTo(f.dx, f.dy - h)
      ..lineTo(d.dx, d.dy - h)
      ..close();
    final rf = Path()
      ..moveTo(f.dx, f.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx, b.dy - h)
      ..lineTo(f.dx, f.dy - h)
      ..close();
    final tp = Path()
      ..moveTo(a.dx, a.dy - h)
      ..lineTo(b.dx, b.dy - h)
      ..lineTo(f.dx, f.dy - h)
      ..lineTo(d.dx, d.dy - h)
      ..close();
    c.drawPath(lf, Paint()..color = left);
    c.drawPath(rf, Paint()..color = right);
    c.drawPath(tp, Paint()..color = top);
    final edge = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    c.drawPath(lf, edge);
    c.drawPath(rf, edge);
  }

  // نقطة على الوجه الأمامي اليسار (يباوع على +gy) أو اليمين (+gx)
  Offset _onLeftFace(double gx, double gy, double lx, double ly, double u, double v) {
    final d = iso(gx - lx / 2, gy + ly / 2), f = iso(gx + lx / 2, gy + ly / 2);
    return Offset(d.dx + (f.dx - d.dx) * u, d.dy + (f.dy - d.dy) * u - v);
  }

  Offset _onRightFace(double gx, double gy, double lx, double ly, double u, double v) {
    final f = iso(gx + lx / 2, gy + ly / 2), b = iso(gx + lx / 2, gy - ly / 2);
    return Offset(f.dx + (b.dx - f.dx) * u, f.dy + (b.dy - f.dy) * u - v);
  }

  Path _quad(Offset Function(double u, double v) f, double u1, double u2, double v1, double v2) => Path()
    ..moveTo(f(u1, v1).dx, f(u1, v1).dy)
    ..lineTo(f(u2, v1).dx, f(u2, v1).dy)
    ..lineTo(f(u2, v2).dx, f(u2, v2).dy)
    ..lineTo(f(u1, v2).dx, f(u1, v2).dy)
    ..close();

  double _hHeight(int i) => tw * _heights[i % _heights.length];

  bool _offscreen(Offset p) => p.dx < -tw * 1.5 || p.dx > size.x + tw * 1.5 || p.dy < -tw * 2 || p.dy > size.y + tw;

  /// يرسم صورة حقيقية رجلها على [base] (الزاوية الگدامية للبناية). يرجع false إذا ماكو صورة
  bool _spr(Canvas c, String key, Offset base, double width) {
    final img = _img[key];
    if (img == null) return false;
    final h = width * img.height / img.width;
    final dst = Rect.fromLTWH(base.dx - width / 2, base.dy - h, width, h);
    final k = (0.4 + 0.6 * _light).clamp(0.0, 1.0);
    final v = (255 * k).round();
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.mode(Color.fromARGB(255, v, v, (v * 1.05).clamp(0, 255).round()), BlendMode.modulate),
    );
    return true;
  }

  void _shadows(Canvas c) {
    if (_light < 0.25) return;
    final p = Paint()..color = Color.fromARGB((40 * _light).round(), 0, 0, 0);
    void sh(double gx, double gy, double size) {
      final o = iso(gx + 0.3, gy - 0.05);
      if (_offscreen(o)) return;
      c.drawPath(_diamond(o, tw * size, th * size), p);
    }

    for (var i = 0; i < GameState.houseCount; i++) {
      final g = GameState.housePos(i);
      sh(g.dx, g.dy, 0.9);
    }
    for (final f in _fillers) {
      sh(f.gx, f.gy, 0.9);
    }
    for (final b in [GameState.teaPos, GameState.mosquePos, GameState.bakeryPos, ...GameState.shops]) {
      sh(b.dx, b.dy, 0.95);
    }
  }

  // خطوط طابوق خفيفة على الجدران
  void _bricks(Canvas c, double gx, double gy, double l, double height) {
    final p = Paint()
      ..color = const Color(0x16000000)
      ..strokeWidth = 1;
    final n = (height / (tw * 0.06)).floor();
    for (var k = 1; k < n; k++) {
      final v = height * k / n;
      c.drawLine(_onLeftFace(gx, gy, l, l, 0, v), _onLeftFace(gx, gy, l, l, 1, v), p);
      c.drawLine(_onRightFace(gx, gy, l, l, 0, v), _onRightFace(gx, gy, l, l, 1, v), p);
    }
  }

  void _filler(Canvas c, _Filler f) {
    final base = iso(f.gx, f.gy);
    if (_offscreen(base)) return;
    const l = 0.84;
    final r = Random(f.seed);
    if (_spr(c, 'house_${f.seed % 6 + 1}', iso(f.gx + l / 2, f.gy + l / 2), tw * 1.12)) return;
    final height = tw * (0.55 + r.nextDouble() * 0.55);
    final col = _brick[f.seed % _brick.length];
    _prism(c, f.gx, f.gy, l, l, height, _shade(col, 1.05), _shade(col, 0.86), _shade(col, 0.68));
    _bricks(c, f.gx, f.gy, l, height);
    Offset onL(double u, double v) => _onLeftFace(f.gx, f.gy, l, l, u, v);
    Offset onR(double u, double v) => _onRightFace(f.gx, f.gy, l, l, u, v);
    final floors = (height / (tw * 0.3)).floor().clamp(1, 3);
    for (var fl = 0; fl < floors; fl++) {
      final v1 = height * (0.2 + fl * 0.75 / floors), v2 = v1 + height * 0.14;
      for (final u in [0.15, 0.6]) {
        final on = _light < 0.5 && r.nextDouble() < (state.nationalOn ? 0.8 : 0.35);
        final col2 = on ? const Color(0xFFFFD25A) : const Color(0xFF2B2B35);
        c.drawPath(_quad(onL, u, u + 0.22, v1, v2), Paint()..color = col2);
        c.drawPath(_quad(onR, u, u + 0.22, v1, v2), Paint()..color = col2);
      }
    }
    _prism(c, f.gx - 0.2, f.gy - 0.15, 0.2, 0.2, tw * 0.09, _shade(0xFFEDEDED), _shade(0xFFCFCFCF), _shade(0xFFB0B0B0),
        lift: height);
  }

  void _shop(Canvas c, int k) {
    final g = GameState.shops[k];
    if (_offscreen(iso(g.dx, g.dy))) return;
    const lx = 0.85, ly = 0.85;
    if (_spr(c, 'shop', iso(g.dx + lx / 2, g.dy + ly / 2), tw * 1.12)) {
      _sign(c, g.dx, g.dy, lx, ly, tw * 0.45, GameState.shopNames[k], 0xFF37474F);
      return;
    }
    const colors = [0xFFE57373, 0xFFFFF176, 0xFF81C784, 0xFF64B5F6, 0xFFFFB74D];
    final h = tw * 0.52;
    final col = [0xFFE0D2B8, 0xFFD9CBB0, 0xFFE6DCC8, 0xFFD2C2A4, 0xFFDDD0B6][k % 5];
    _prism(c, g.dx, g.dy, lx, ly, h, _shade(col, 1.05), _shade(col, 0.9), _shade(col, 0.72));
    Offset onL(double u, double v) => _onLeftFace(g.dx, g.dy, lx, ly, u, v);
    // كبنك (باب محل حديد) مفتوح وبضاعة
    final open = _light > 0.3;
    c.drawPath(_quad(onL, 0.12, 0.88, 0, h * 0.55), Paint()..color = open ? _shade(0xFF3E2723) : _shade(0xFF90A4AE));
    if (open) {
      for (var j = 0; j < 4; j++) {
        final m = onL(0.22 + j * 0.18, h * 0.2);
        c.drawRect(Rect.fromCenter(center: m, width: tw * 0.07, height: tw * 0.07), Paint()..color = _shade(colors[(k + j) % 5]));
      }
    } else {
      for (var j = 1; j < 6; j++) {
        c.drawLine(onL(0.12, h * 0.55 * j / 6), onL(0.88, h * 0.55 * j / 6), Paint()..color = _shade(0xFF607D8B));
      }
    }
    _sign(c, g.dx, g.dy, lx, ly, h * 0.78, GameState.shopNames[k], [0xFFB71C1C, 0xFF1B5E20, 0xFF0D47A1, 0xFF4A148C, 0xFFE65100][k]);
  }

  Offset? _questTarget(Quest q) {
    if (q.type == QuestType.delivery && !q.picked) {
      final src = q.from == 0 ? GameState.bakeryPos : GameState.teaPos;
      return iso(src.dx, src.dy).translate(0, -tw * 0.9);
    }
    return _roofPoint(q.house).translate(0, -tw * 0.6);
  }

  void _questMarks(Canvas c) {
    for (final q in state.quests) {
      final t = _questTarget(q);
      if (t == null) continue;
      final p = t.translate(0, sin(state.clock * 4) * 4);
      c.drawCircle(p, 14, Paint()..color = const Color(0xEE1E88E5));
      _text(c, q.type == QuestType.fixWire ? '🔧' : (q.type == QuestType.visit ? '🚪' : '📦'), p, 13, Colors.white);
    }
  }

  void _house(Canvas c, int i) {
    final h = state.houses[i];
    final g = GameState.housePos(i);
    if (_offscreen(iso(g.dx, g.dy))) return;
    const s = 0.82;
    final height = _hHeight(i);
    final col = _brick[i % _brick.length];
    if (_spr(c, 'house_${i % 6 + 1}', iso(g.dx + s / 2, g.dy + s / 2), tw * 1.12)) {
      final rd = iso(g.dx, g.dy);
      if (state.houseLit(h) && _light < 0.5) {
        c.drawCircle(rd.translate(0, -height * 0.4), tw * 0.35, Paint()..color = const Color(0x33FFD25A));
      }
      if (h.wireCut) _text(c, '✂️', rd.translate(0, -height - tw * 0.1), 14, Colors.white);
      if (state.selected == i) {
        c.drawPath(_diamond(rd, tw * s, th * s),
            Paint()..color = const Color(0xFFFF9800)..style = PaintingStyle.stroke..strokeWidth = 3);
      }
      return;
    }
    _prism(c, g.dx, g.dy, s, s, height, _shade(col, 1.08), _shade(col, 0.88), _shade(col, 0.7));
    _bricks(c, g.dx, g.dy, s, height);
    Offset onL(double u, double v) => _onLeftFace(g.dx, g.dy, s, s, u, v);
    Offset onR(double u, double v) => _onRightFace(g.dx, g.dy, s, s, u, v);

    final lit = state.houseLit(h);
    final winPaint = Paint()..color = lit ? const Color(0xFFFFD25A) : const Color(0xFF2B2B35);
    final glow = Paint()
      ..color = const Color(0x66FFD25A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final twoFloors = height > tw * 0.78;
    final top1 = height * (twoFloors ? 0.58 : 0.75);
    final wins = <Path>[
      _quad(onL, 0.1, 0.3, height * 0.42, top1),
      _quad(onL, 0.72, 0.9, height * 0.42, top1),
      _quad(onR, 0.15, 0.4, height * 0.42, top1),
      _quad(onR, 0.6, 0.85, height * 0.42, top1),
      if (twoFloors) ...[
        _quad(onL, 0.15, 0.4, height * 0.7, height * 0.86),
        _quad(onL, 0.6, 0.85, height * 0.7, height * 0.86),
        _quad(onR, 0.3, 0.7, height * 0.7, height * 0.86),
      ],
    ];
    for (final wp in wins) {
      if (lit && _light < 0.5) c.drawPath(wp, glow);
      c.drawPath(wp, winPaint);
    }
    // الباب على الوجه اللي يباوع على الطريق
    c.drawPath(_quad(onL, 0.4, 0.6, 0, height * (twoFloors ? 0.38 : 0.52)), Paint()..color = _shade(0xFF5D4037));
    c.drawCircle(onL(0.56, height * 0.22), tw * 0.012, Paint()..color = _shade(0xFFFFC107));
    // سبلت
    c.drawPath(_quad(onR, 0.45, 0.62, height * 0.12, height * 0.28), Paint()..color = _shade(0xFFECEFF1));
    // حافة السطح
    final rd = iso(g.dx, g.dy);
    c.drawPath(
      _diamond(rd, tw * s, th * s, height),
      Paint()
        ..color = _shade(col, 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // خزان الماء
    _prism(c, g.dx - 0.18, g.dy - 0.18, 0.2, 0.2, tw * 0.1, _shade(0xFFEDEDED), _shade(0xFFCFCFCF), _shade(0xFFB0B0B0),
        lift: height);
    // حبل غسيل لبعض البيوت
    if (i % 4 == 1) {
      final a = Offset(rd.dx - tw * 0.25, rd.dy - height - tw * 0.08);
      final b = Offset(rd.dx + tw * 0.2, rd.dy - height - tw * 0.02);
      c.drawLine(a, b, Paint()
        ..color = _shade(0xFF555555)
        ..strokeWidth = 1);
      const clothes = [0xFFE53935, 0xFF1E88E5, 0xFFFFFFFF];
      for (var k = 0; k < 3; k++) {
        final m = Offset.lerp(a, b, 0.25 + k * 0.25)!;
        c.drawRect(Rect.fromLTWH(m.dx - 3, m.dy, 6, 8), Paint()..color = _shade(clothes[k]));
      }
    }
    // دش
    if (i % 3 == 0) {
      final d = Offset(rd.dx + tw * 0.12, rd.dy - height - tw * 0.05);
      c.drawOval(Rect.fromCenter(center: d, width: tw * 0.13, height: tw * 0.07), Paint()..color = _shade(0xFFDDDDDD));
    }
    if (state.selected == i) {
      c.drawPath(
        _diamond(rd, tw * s, th * s, height),
        Paint()
          ..color = const Color(0xFFFF9800)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  Offset _roofPoint(int i) {
    final g = GameState.housePos(i);
    final p = iso(g.dx, g.dy);
    return Offset(p.dx, p.dy - _hHeight(i));
  }

  Offset _poleTop(Offset g) => iso(g.dx, g.dy).translate(0, -tw * 0.95);

  void _pole(Canvas c, Offset g) {
    final base = iso(g.dx, g.dy);
    final top = _poleTop(g);
    final paint = Paint()
      ..color = _shade(0xFF6D6D6D)
      ..strokeWidth = tw * 0.035;
    c.drawLine(base, top, paint);
    c.drawLine(top.translate(-tw * 0.1, tw * 0.05), top.translate(tw * 0.1, tw * 0.05), paint..strokeWidth = tw * 0.025);
    // ضوية شارع بالليل
    final lamp = top.translate(tw * 0.1, tw * 0.1);
    final on = _light < 0.45 && (state.generating || state.nationalOn);
    if (on) {
      c.drawCircle(lamp, tw * 0.35, Paint()..color = const Color(0x22FFE082));
      c.drawOval(Rect.fromCenter(center: iso(g.dx + 0.3, g.dy + 0.3), width: tw * 0.9, height: th * 0.9),
          Paint()..color = const Color(0x18FFE082));
    }
    c.drawCircle(lamp, tw * 0.03, Paint()..color = on ? const Color(0xFFFFF59D) : _shade(0xFF9E9E9E));
  }

  void _generator(Canvas c) {
    const gp = GameState.genPos;
    final scale = 1 + 0.18 * (state.genLevel - 1);
    final base = iso(gp.dx, gp.dy);
    final fence = Paint()
      ..color = _shade(0xFF9E9E9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fw = tw * 1.05 * scale, fh = th * 1.05 * scale;
    c.drawPath(_diamond(base, fw, fh), fence);
    c.drawPath(_diamond(base, fw, fh, tw * 0.18), fence);
    for (final corner in [Offset(base.dx - fw / 2, base.dy), Offset(base.dx + fw / 2, base.dy), Offset(base.dx, base.dy - fh / 2)]) {
      c.drawLine(corner, corner.translate(0, -tw * 0.18), fence);
    }
    final shake = state.generating ? sin(state.clock * 70) * 0.008 : 0.0;
    final l = 0.62 * scale, height = tw * 0.32 * scale;
    if (_img.containsKey('generator')) {
      final gpos = iso(gp.dx + l / 2 + shake, gp.dy + l / 2);
      _spr(c, 'generator', gpos, tw * 0.95 * scale);
      final p = iso(gp.dx + shake, gp.dy);
      _exhaust = p.translate(tw * 0.12, -height - tw * 0.2);
      _genTop = p.translate(-tw * 0.1, -height);
      c.drawCircle(p.translate(tw * 0.2, -height * 0.3), tw * 0.035,
          Paint()..color = state.broken ? const Color(0xFFE53935) : (!state.generating ? const Color(0xFF9E9E9E) : (state.overloaded ? const Color(0xFFFF9800) : const Color(0xFF43A047))));
      _text(c, 'مولدة المحلة', p.translate(0, th * 0.75), max(9.0, tw * 0.11), _shade(0xFFFFFFFF), bold: true);
      if (state.alarm > 0 && (state.clock * 5).floor().isEven) {
        c.drawPath(_diamond(p, tw * l * 1.4, th * l * 1.4),
            Paint()..color = const Color(0xFFFF1744)..style = PaintingStyle.stroke..strokeWidth = 4);
      }
      return;
    }
    final body = state.broken ? 0xFF6A3A3A : 0xFF3E6B48;
    final gx = gp.dx + shake;
    _prism(c, gx, gp.dy, l, l, height, _shade(body, 1.15), _shade(body, 0.9), _shade(body, 0.7));
    Offset onL(double u, double v) => _onLeftFace(gx, gp.dy, l, l, u, v);
    Offset onR(double u, double v) => _onRightFace(gx, gp.dy, l, l, u, v);
    final grill = Paint()
      ..color = _shade(0xFF1B2E20)
      ..strokeWidth = 1.2;
    for (var k = 0; k < 4; k++) {
      final u = 0.2 + k * 0.15;
      c.drawLine(onL(u, height * 0.2), onL(u, height * 0.8), grill);
    }
    c.drawPath(_quad(onR, 0.25, 0.7, height * 0.35, height * 0.8), Paint()..color = _shade(0xFF263238));
    final status = state.broken
        ? const Color(0xFFE53935)
        : !state.generating
            ? const Color(0xFF9E9E9E)
            : state.overloaded
                ? const Color(0xFFFF9800)
                : const Color(0xFF43A047);
    c.drawCircle(onR(0.47, height * 0.58), tw * 0.035, Paint()..color = status);
    final p = iso(gx, gp.dy);
    final pipeBase = Offset(p.dx + tw * 0.12, p.dy - height);
    final pipeTop = Offset(pipeBase.dx, pipeBase.dy - tw * 0.22);
    c.drawLine(pipeBase, pipeTop, Paint()
      ..color = _shade(0xFF444444)
      ..strokeWidth = tw * 0.05);
    _exhaust = pipeTop;
    _genTop = Offset(p.dx - tw * 0.1, p.dy - height);
    _text(c, 'مولدة المحلة', p.translate(0, th * 0.75), max(9.0, tw * 0.11), _shade(0xFFFFFFFF), bold: true);
    if (state.alarm > 0 && (state.clock * 5).floor().isEven) {
      c.drawPath(
        _diamond(p, tw * l * 1.4, th * l * 1.4, height),
        Paint()
          ..color = const Color(0xFFFF1744)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
    if (state.selected == -1) {
      c.drawPath(
        _diamond(p, tw * l, th * l, height),
        Paint()
          ..color = const Color(0xFFFF9800)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _sign(Canvas c, double gx, double gy, double lx, double ly, double v, String txt, int bg) {
    final m = _onLeftFace(gx, gy, lx, ly, 0.5, v);
    final fs = max(9.0, tw * 0.1);
    final tp = _tp(txt, fs, Colors.white, bold: true);
    final r = Rect.fromCenter(center: m, width: tp.width + 10, height: tp.height + 4);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), Paint()..color = _shade(bg));
    tp.paint(c, Offset(r.left + 5, r.top + 2));
  }

  void _teaHouse(Canvas c) {
    const g = GameState.teaPos;
    if (_offscreen(iso(g.dx, g.dy))) return;
    const lx = 0.95, ly = 0.85;
    final h = tw * 0.55;
    if (_spr(c, 'tea_house', iso(g.dx + lx / 2, g.dy + ly / 2), tw * 1.2)) return;
    _prism(c, g.dx, g.dy, lx, ly, h, _shade(0xFFEFE3C8), _shade(0xFFE0CFA8), _shade(0xFFC9B58C));
    Offset onL(double u, double v) => _onLeftFace(g.dx, g.dy, lx, ly, u, v);
    c.drawPath(_quad(onL, 0.35, 0.65, 0, h * 0.55), Paint()..color = _light < 0.5 ? const Color(0xFFFFB74D) : _shade(0xFF6D4C41));
    // مظلة مخططة
    for (var k = 0; k < 6; k++) {
      final u1 = k / 6, u2 = (k + 1) / 6;
      final p = Path()
        ..moveTo(onL(u1, h * 0.72).dx, onL(u1, h * 0.72).dy)
        ..lineTo(onL(u2, h * 0.72).dx, onL(u2, h * 0.72).dy)
        ..lineTo(onL(u2, h * 0.6).dx, onL(u2, h * 0.6).dy + th * 0.15)
        ..lineTo(onL(u1, h * 0.6).dx, onL(u1, h * 0.6).dy + th * 0.15)
        ..close();
      c.drawPath(p, Paint()..color = _shade(k.isEven ? 0xFFC62828 : 0xFFFFFFFF));
    }
    _sign(c, g.dx, g.dy, lx, ly, h * 0.88, 'جايخانة أبو علي ☕', 0xFF4E342E);
  }

  void _teaSitters(Canvas c) {
    for (final x in [0.65, 1.35]) {
      final p = iso(x, 7.35);
      if (_offscreen(p)) return;
      c.drawRect(Rect.fromCenter(center: p.translate(0, -tw * 0.06), width: tw * 0.22, height: tw * 0.06),
          Paint()..color = _shade(0xFF8D6E63));
      drawPerson(c, p.translate(0, -tw * 0.03), tw, x < 1 ? PersonLook.oldMan : PersonLook.shemagh,
          light: _light, sitting: true, face: x < 1 ? 1 : -1);
      final glass = p.translate(x < 1 ? tw * 0.08 : -tw * 0.08, -tw * 0.12);
      c.drawRect(Rect.fromCenter(center: glass, width: 4, height: 6), Paint()..color = const Color(0xFFBF360C));
      final steam = sin(state.clock * 3 + x) * 2;
      c.drawCircle(glass.translate(steam, -8), 2.5, Paint()..color = const Color(0x55FFFFFF));
    }
  }

  void _mosque(Canvas c) {
    const g = GameState.mosquePos;
    if (_offscreen(iso(g.dx, g.dy))) return;
    const lx = 1.1, ly = 0.95;
    final h = tw * 0.5;
    if (_spr(c, 'mosque', iso(g.dx + lx / 2, g.dy + ly / 2), tw * 1.4)) return;
    _prism(c, g.dx, g.dy, lx, ly, h, _shade(0xFFF3EFE6), _shade(0xFFE8E1D2), _shade(0xFFCFC6B3));
    Offset onL(double u, double v) => _onLeftFace(g.dx, g.dy, lx, ly, u, v);
    for (final u in [0.2, 0.5, 0.8]) {
      final m = onL(u, h * 0.3);
      c.drawRRect(
        RRect.fromRectAndCorners(Rect.fromCenter(center: m, width: tw * 0.13, height: h * 0.45),
            topLeft: Radius.circular(tw * 0.07), topRight: Radius.circular(tw * 0.07)),
        Paint()..color = _shade(0xFF00695C),
      );
    }
    final top = iso(g.dx, g.dy).translate(0, -h);
    c.drawArc(Rect.fromCenter(center: top, width: tw * 0.55, height: tw * 0.55), pi, pi, true, Paint()..color = _shade(0xFF26A69A));
    c.drawLine(top.translate(0, -tw * 0.27), top.translate(0, -tw * 0.38), Paint()
      ..color = _shade(0xFFFFD54F)
      ..strokeWidth = 2);
    _prism(c, g.dx + 0.45, g.dy - 0.4, 0.16, 0.16, tw * 1.25, _shade(0xFFF3EFE6), _shade(0xFFE8E1D2), _shade(0xFFCFC6B3));
    final mt = iso(g.dx + 0.45, g.dy - 0.4).translate(0, -tw * 1.25);
    c.drawArc(Rect.fromCenter(center: mt, width: tw * 0.16, height: tw * 0.2), pi, pi, true, Paint()..color = _shade(0xFF26A69A));
    _sign(c, g.dx, g.dy, lx, ly, h * 0.82, 'جامع المحلة', 0xFF00695C);
  }

  void _bakery(Canvas c) {
    const g = GameState.bakeryPos;
    if (_offscreen(iso(g.dx, g.dy))) return;
    const lx = 0.95, ly = 0.85;
    final h = tw * 0.5;
    if (_spr(c, 'bakery', iso(g.dx + lx / 2, g.dy + ly / 2), tw * 1.2)) return;
    _prism(c, g.dx, g.dy, lx, ly, h, _shade(0xFFD7B899), _shade(0xFFC9A882), _shade(0xFFAE8E6A));
    Offset onL(double u, double v) => _onLeftFace(g.dx, g.dy, lx, ly, u, v);
    c.drawPath(_quad(onL, 0.15, 0.55, h * 0.15, h * 0.6), Paint()..color = const Color(0xFFFF7043));
    c.drawPath(_quad(onL, 0.65, 0.85, 0, h * 0.55), Paint()..color = _shade(0xFF5D4037));
    _prism(c, g.dx + 0.25, g.dy - 0.25, 0.14, 0.14, tw * 0.3, _shade(0xFF8D6E63), _shade(0xFF795548), _shade(0xFF5D4037), lift: h);
    _sign(c, g.dx, g.dy, lx, ly, h * 0.85, 'فرن صمون حجري', 0xFFBF360C);
  }

  void _palm(Canvas c, Offset g) {
    final base = iso(g.dx, g.dy);
    if (_offscreen(base)) return;
    if (_spr(c, 'palm', base, tw * 0.9)) return;
    final top = base.translate(tw * 0.05, -tw * 1.1);
    final trunk = Paint()
      ..color = _shade(0xFF8D6E63)
      ..strokeWidth = tw * 0.06
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    c.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(base.dx - tw * 0.05, base.dy - tw * 0.6, top.dx, top.dy),
      trunk,
    );
    final leaf = Paint()
      ..color = _shade(0xFF388E3C)
      ..strokeWidth = tw * 0.04
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sway = sin(state.clock * 1.5 + g.dx) * tw * 0.02;
    for (var k = 0; k < 7; k++) {
      final a = -pi + k * pi / 6;
      final end = top.translate(cos(a) * tw * 0.35 + sway, sin(a) * tw * 0.12 + tw * 0.12);
      final mid = top.translate(cos(a) * tw * 0.2, -tw * 0.06);
      c.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy),
        leaf,
      );
    }
  }

  void _car(Canvas c, _Car car) {
    final p = iso(car.x, car.lane);
    if (_offscreen(p)) return;
    final lx = car.kind == 1 ? 1.05 : 0.85;
    const ly = 0.42;
    final wheelH = tw * 0.045;
    c.drawOval(Rect.fromCenter(center: p.translate(0, th * 0.05), width: tw * lx * 0.9, height: th * 0.55),
        Paint()..color = const Color(0x33000000));
    final wheel = Paint()..color = const Color(0xFF1A1A1A);
    for (final dx in [-lx * 0.32, lx * 0.32]) {
      c.drawOval(Rect.fromCenter(center: iso(car.x + dx, car.lane + ly / 2), width: tw * 0.13, height: tw * 0.09), wheel);
      c.drawOval(Rect.fromCenter(center: iso(car.x + dx, car.lane - ly / 2), width: tw * 0.13, height: tw * 0.09), wheel);
    }
    final bodyH = tw * (car.kind == 1 ? 0.26 : 0.13);
    final col = car.color;
    _prism(c, car.x, car.lane, lx, ly, bodyH, _shade(col, 1.1), _shade(col, 0.9), _shade(col, 0.75), lift: wheelH);
    if (car.kind == 0) {
      _prism(c, car.x - car.dir * 0.05, car.lane, lx * 0.5, ly * 0.85, tw * 0.1, _shade(col, 1.1), _shade(0xFF263238),
          _shade(0xFF37474F),
          lift: wheelH + bodyH);
      final roof = iso(car.x - car.dir * 0.05, car.lane).translate(0, -(wheelH + bodyH + tw * 0.1));
      c.drawRect(Rect.fromCenter(center: roof.translate(0, -3), width: 12, height: 5), Paint()..color = _shade(0xFFFFB300));
    } else if (car.kind == 1) {
      Offset face(double u, double v) => _onLeftFace(car.x, car.lane, lx, ly, u, v + wheelH);
      for (var k = 0; k < 4; k++) {
        final u1 = 0.08 + k * 0.22;
        c.drawPath(_quad(face, u1, u1 + 0.17, bodyH * 0.55, bodyH * 0.9), Paint()..color = _shade(0xFF37474F));
      }
      c.drawPath(_quad(face, 0, 1, bodyH * 0.3, bodyH * 0.4), Paint()..color = _shade(0xFF1565C0));
    } else {
      _prism(c, car.x + car.dir * 0.2, car.lane, lx * 0.4, ly * 0.9, tw * 0.12, _shade(col, 1.1), _shade(0xFF263238),
          _shade(0xFF37474F),
          lift: wheelH + bodyH);
    }
    if (_light < 0.5) {
      final front = iso(car.x + car.dir * (lx / 2 + 0.5), car.lane);
      c.drawOval(Rect.fromCenter(center: front, width: tw * 0.8, height: th * 0.6), Paint()..color = const Color(0x33FFF59D));
    }
  }

  void _carHonks(Canvas c) {
    for (final car in _cars) {
      if (car.honk > 0) {
        final p = iso(car.x, car.lane).translate(0, -tw * 0.5);
        _bubble(c, p, 'بيب بيب! 📯', const Color(0xFFFFF59D));
      }
    }
  }

  void _walker(Canvas c, _Walker w) {
    final p = iso(w.x, w.lane);
    if (_offscreen(p)) return;
    final moving = !state.overlayOpen && w.sayTime <= 0;
    drawPerson(c, p, tw, w.look, light: _light, walkPhase: moving ? state.clock * 8 + w.x : null, face: w.dir);
    if (w.look == PersonLook.kid) {
      final b = p.translate(w.dir * tw * 0.08, -(sin(state.clock * 8).abs()) * tw * 0.08);
      c.drawCircle(b, tw * 0.03, Paint()..color = Colors.white);
    }
    if (w.sayTime > 0 && w.say != null) _bubble(c, p.translate(0, -tw * 0.45), w.say!, Colors.white);
  }

  void _football(Canvas c) {
    final a = iso(5.0, 1.3), b = iso(6.2, 1.7);
    if (_offscreen(a)) return;
    final t = (sin(state.clock * 1.6) + 1) / 2;
    drawPerson(c, a, tw, PersonLook.kid, light: _light, walkPhase: state.clock * 6, face: 1, shirt: 0xFFE53935);
    drawPerson(c, b, tw, PersonLook.kid, light: _light, walkPhase: state.clock * 6 + 1, face: -1, shirt: 0xFF1E88E5);
    final ball = Offset.lerp(a, b, t)!.translate(0, -sin(t * pi) * tw * 0.25);
    c.drawCircle(ball, tw * 0.035, Paint()..color = Colors.white);
    c.drawCircle(ball, tw * 0.035, Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
  }

  void _cat(Canvas c, _Cat cat) {
    final p = iso(cat.x, cat.y);
    if (_offscreen(p)) return;
    final s = tw * 0.05;
    final dir = cat.dx >= 0 ? 1.0 : -1.0;
    final col = Paint()
      ..color = _shade(cat.color)
      ..strokeWidth = 2;
    c.drawOval(Rect.fromCenter(center: p.translate(0, -s * 0.6), width: s * 2, height: s), col);
    c.drawCircle(p.translate(dir * s, -s * 1.1), s * 0.5, col);
    c.drawPath(
      Path()
        ..moveTo(p.dx + dir * s * 0.8, p.dy - s * 1.5)
        ..lineTo(p.dx + dir * s * 0.95, p.dy - s * 1.9)
        ..lineTo(p.dx + dir * s * 1.15, p.dy - s * 1.5)
        ..close(),
      col,
    );
    final tail = sin(state.clock * 4 + cat.x) * s * 0.4;
    c.drawLine(p.translate(-dir * s, -s * 0.6), p.translate(-dir * s * 1.6, -s * 1.4 + tail), col);
  }

  void _player(Canvas c) {
    final p = iso(state.px, state.py);
    c.drawOval(
      Rect.fromCenter(center: p, width: tw * 0.35, height: th * 0.35),
      Paint()
        ..color = const Color(0x66FFC107)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    drawPerson(c, p, tw, PersonLook.player,
        light: max(_light, 0.6), walkPhase: state.walking ? state.clock * 10 : null, face: state.faceX);
    final bob = sin(state.clock * 4) * 3;
    final a = p.translate(0, -tw * 0.42 + bob);
    c.drawPath(
      Path()
        ..moveTo(a.dx - 7, a.dy - 10)
        ..lineTo(a.dx + 7, a.dy - 10)
        ..lineTo(a.dx, a.dy)
        ..close(),
      Paint()..color = const Color(0xFFFFC107),
    );
  }

  void _sag(Canvas c, Offset a, Offset b, Paint paint, [double amount = 0.15]) {
    final mid = Offset((a.dx + b.dx) / 2, max(a.dy, b.dy) + tw * amount);
    c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy),
      paint,
    );
  }

  void _wires(Canvas c) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    const ps = GameState.poles;
    for (final pl in ps) {
      _sag(c, _genTop, _poleTop(pl), paint, 0.1);
    }
    _sag(c, _poleTop(ps[0]), _poleTop(ps[1]), paint);
    _sag(c, _poleTop(ps[2]), _poleTop(ps[3]), paint);
    for (var i = 0; i < GameState.houseCount; i++) {
      if (!state.houses[i].subscribed) continue;
      final g = GameState.housePos(i);
      final near = g.dy < 1.5 ? (g.dx < 3.5 ? ps[0] : ps[1]) : (g.dx < 3.5 ? ps[2] : ps[3]);
      _sag(c, _poleTop(near), _roofPoint(i), paint, 0.1);
    }
  }

  void _smoke(Canvas c) {
    for (final p in _puffs) {
      final t = p.age / 2.5;
      final alpha = ((1 - t) * (p.dark ? 150 : 90)).round().clamp(0, 255);
      final g = p.dark ? 60 : 190;
      c.drawCircle(Offset(p.x + origin.dx, p.y + origin.dy), tw * (0.03 + t * 0.12), Paint()..color = Color.fromARGB(alpha, g, g, g));
    }
  }

  Offset _thiefPos() {
    final pl = GameState.poles[state.thiefPole % GameState.poles.length];
    return iso(pl.dx, pl.dy).translate(tw * 0.06, -tw * 0.6);
  }

  void _thief(Canvas c) {
    if (state.thiefTime <= 0) return;
    final p = _thiefPos();
    final s = tw * 0.07;
    final wiggle = sin(state.clock * 12) * s * 0.3;
    final flash = (state.clock * 4).floor().isEven;
    c.drawCircle(p, tw * 0.32, Paint()..color = flash ? const Color(0x66FF1744) : const Color(0x33FF1744));
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
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.dx - s * 0.5 + wiggle, p.dy - s, s, s * 2), Radius.circular(s * 0.3)),
        Paint()..color = const Color(0xFF111111));
    c.drawCircle(p.translate(wiggle, -s * 1.4), s * 0.5, Paint()..color = const Color(0xFF111111));
    _text(c, '🦹', p.translate(0, -tw * 0.45), 16, Colors.white);
  }

  void _bubble(Canvas c, Offset anchor, String text, Color fill) {
    final fs = max(10.0, tw * 0.12);
    final tp = _tp(text, fs, const Color(0xFF212121), bold: true);
    final rect = Rect.fromCenter(center: anchor, width: tp.width + 14, height: tp.height + 8);
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
  }

  Offset _coinPos(int i) => _roofPoint(i).translate(0, -tw * 0.32);

  void _bubbles(Canvas c) {
    final fs = max(10.0, tw * 0.12);
    for (var i = 0; i < GameState.houseCount; i++) {
      final h = state.houses[i];
      final anchor = _coinPos(i);
      if (_offscreen(anchor)) continue;
      if (h.pending > 0) {
        final cpos = anchor.translate(0, sin(state.clock * 5 + i) * 4);
        final rr = tw * 0.15;
        c.drawCircle(cpos, rr * 1.35, Paint()..color = const Color(0x55FFD54F));
        c.drawCircle(cpos, rr, Paint()..color = const Color(0xFFFFC107));
        final ring = Paint()
          ..color = (h.coinTime < 6 ? const Color(0xFFFF1744) : Colors.white)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        c.drawArc(Rect.fromCircle(center: cpos, radius: rr * 1.35), -pi / 2,
            2 * pi * (h.coinTime / GameState.coinSeconds).clamp(0.0, 1.0), false, ring);
        _text(c, 'د.ع', cpos, fs * 0.8, const Color(0xFF5D4037), bold: true);
        _text(c, fmt(h.pending), cpos.translate(0, rr + fs * 0.8), fs * 0.85, Colors.white, bold: true);
      } else if (h.requestTime > 0) {
        final pulse = 1 + 0.08 * sin(state.clock * 8);
        final rect = Rect.fromCenter(center: anchor, width: tw * 0.75 * pulse, height: fs * 1.9 * pulse);
        c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), Paint()..color = const Color(0xFF43A047));
        _text(c, '⚡ +أمبير؟', anchor, fs * 0.9, Colors.white, bold: true);
      } else if (h.bubble != null) {
        final b = h.bubble!;
        final bad = b.contains('!') && !b.startsWith('+') && !b.contains('اشترك') && !b.contains('شكر');
        _bubble(c, anchor, b, b.startsWith('+') ? const Color(0xFFC8E6C9) : (bad ? const Color(0xFFFFCDD2) : Colors.white));
      } else if (h.debt > 0) {
        c.drawCircle(anchor, tw * 0.07, Paint()..color = const Color(0xFFE53935));
        _text(c, '!', anchor, fs, Colors.white, bold: true);
      }
    }
  }

  // أسهم على حافة الشاشة للحرامي والعملات والمولدة
  void _edgeMarkers(Canvas c) {
    final area = Rect.fromLTRB(24, _top + 24, size.x - 24, _bottom - 24);
    void marker(Offset target, String emoji, Color color) {
      if (area.contains(target)) return;
      final center = area.center;
      final v = target - center;
      final sx = v.dx == 0 ? double.infinity : (area.width / 2) / v.dx.abs();
      final sy = v.dy == 0 ? double.infinity : (area.height / 2) / v.dy.abs();
      final pos = center + v * min(sx, sy);
      c.drawCircle(pos, 16, Paint()..color = color);
      _text(c, emoji, pos, 14, Colors.white);
    }

    if (state.thiefTime > 0) marker(_thiefPos(), '🦹', const Color(0xDDFF1744));
    for (var i = 0; i < GameState.houseCount; i++) {
      if (state.houses[i].pending > 0) marker(_coinPos(i), '🪙', const Color(0xDDFFA000));
    }
    if (state.alarm > 0) marker(iso(GameState.genPos.dx, GameState.genPos.dy), '⚡', const Color(0xDDFF1744));
    for (final q in state.quests) {
      final t = _questTarget(q);
      if (t != null) marker(t, '📋', const Color(0xDD1E88E5));
    }
  }

  // ---------- اللمس ----------
  @override
  void onTapDown(TapDownEvent event) {
    final pt = Offset(event.localPosition.x, event.localPosition.y);
    if (state.thiefTime > 0 && (pt - _thiefPos()).distance < tw * 0.5) {
      state.tapThief();
      return;
    }
    for (var i = 0; i < GameState.houseCount; i++) {
      final h = state.houses[i];
      if (h.pending <= 0 && h.requestTime <= 0) continue;
      if ((pt - _coinPos(i)).distance < tw * 0.35) {
        state.tapHouse(i);
        return;
      }
    }
    final order = List<int>.generate(GameState.houseCount, (i) => i)
      ..sort((a, b) {
        final ga = GameState.housePos(a), gb = GameState.housePos(b);
        return (gb.dx + gb.dy).compareTo(ga.dx + ga.dy);
      });
    for (final i in order) {
      final g = GameState.housePos(i);
      final p = iso(g.dx, g.dy);
      final rect = Rect.fromLTRB(p.dx - tw * 0.41, p.dy - _hHeight(i) - th * 0.41, p.dx + tw * 0.41, p.dy + th * 0.41);
      if (rect.contains(pt)) {
        state.tapHouse(i);
        return;
      }
    }
    final gp = iso(GameState.genPos.dx, GameState.genPos.dy);
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
