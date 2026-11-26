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
  Color backgroundColor() => const Color(0xFF16222A);
}

/// يرسم المدينة بكاميرا تلحگ اللاعب، ويستلم السحب (عصا تحكم بأي مكان)
class Arena extends PositionComponent with DragCallbacks, HasGameReference<FlameGame> {
  final ArcadeWorld wd;
  Arena(this.wd);

  static double topSpace = 120; // تحت الشريط الفوگاني (يتحدد من الواجهة)
  static const double viewWidth = 8.2; // كم مربع يبين بعرض الشاشة

  double tile = 60;
  Offset cam = const Offset(8, 12);
  Offset _sc = Offset.zero; // مركز الشاشة
  Rect view = Rect.zero; // اللي يبين من المدينة
  Offset? _joyStart;
  Offset _joyNow = Offset.zero;
  final Map<String, TextPainter> _tp = {};
  final _rnd = Random();

  // صور المدينة (Kenney RPG Urban Pack - CC0)
  ui.Image? _sheet;
  ui.Image? _face; // صورة وجه اللاعب (قديمة)
  ui.Image? _hero; // صورة الشخصية الكاملة
  bool _heroTried = false;
  bool _heroFlip = false;
  final Paint _heroPaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;
  final Paint _heroHurt = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = const ColorFilter.mode(Color(0xFFFF8A80), BlendMode.modulate);
  final Paint _smooth = Paint()
    ..filterQuality = FilterQuality.high
    ..isAntiAlias = true;
  final Paint _px = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  final Paint _thiefPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0xFF7A7A99), BlendMode.modulate);
  final Paint _hurtPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0xFFFF8A80), BlendMode.modulate);

  final Paint _outline = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0xFF0B0F14), BlendMode.srcIn);
  final Paint _thugPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0xFFFFE6DC), BlendMode.modulate);
  final Paint _bossPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0xFFFFC4C4), BlendMode.modulate);
  final Paint _flashPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn);

  // ألوان السطوح تتغير من مرحلة لمرحلة حتى كل مرحلة شكلها غير
  static const _roofTints = [
    Color(0xFFFFFFFF), Color(0xFFFFC9B0), Color(0xFFC8E6C9), Color(0xFFBBDEFB), Color(0xFFFFF59D), Color(0xFFE1BEE7), Color(0xFFFFCCBC), Color(0xFFB2DFDB),
  ];
  int _tintLevel = -1;
  final List<Paint> _roofPaints = [];

  Paint _roofPaint(int style) {
    if (_tintLevel != wd.level) {
      _tintLevel = wd.level;
      _roofPaints.clear();
      for (var k = 0; k < 3; k++) {
        final c = _roofTints[(wd.level * 3 + k * 5) % _roofTints.length];
        _roofPaints.add(Paint()
          ..filterQuality = FilterQuality.none
          ..colorFilter = ColorFilter.mode(c, BlendMode.modulate));
      }
    }
    return _roofPaints[style % _roofPaints.length];
  }

  // مكان السيارات بالصورة (بكسل)
  static const _carFront = [Rect.fromLTWH(244, 234, 24, 22), Rect.fromLTWH(245, 266, 22, 22), Rect.fromLTWH(336, 236, 16, 21)];
  static const _carBack = [Rect.fromLTWH(272, 235, 16, 21), Rect.fromLTWH(272, 267, 16, 21), Rect.fromLTWH(352, 236, 16, 21)];

  @override
  Future<void> onLoad() async {
    size = game.size.clone();
    try {
      _sheet = await game.images.load('city.png');
    } catch (_) {
      _sheet = null;
    }
    try {
      _hero = await game.images.load('player.png');
    } catch (_) {
      _hero = null;
    }
    _heroTried = true;
    if (_hero == null) {
      try {
        _face = await game.images.load('player_face.png');
      } catch (_) {
        _face = null;
      }
    }
  }

  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);
    size = s.clone();
  }

  // ---------- الكاميرا ----------
  @override
  void update(double dt) {
    super.update(dt);
    Offset target;
    if (wd.phase == Phase.menu) {
      // جولة بطيئة بالمدينة ورا القائمة
      target = Offset(8 + sin(wd.clock * 0.12) * 4.5, 12 + cos(wd.clock * 0.08) * 8);
    } else {
      // الكاميرا تسبق اللاعب شوية باتجاه حركته
      target = wd.player + wd.move * 1.2;
    }
    if ((cam - target).distance > 6) {
      cam = target;
    } else {
      final k = 1 - exp(-dt * 5);
      cam = Offset.lerp(cam, target, k)!;
    }
  }

  void _layout() {
    tile = size.x / viewWidth;
    _sc = Offset(size.x / 2, topSpace * 0.5 + size.y * 0.5);
    final halfW = _sc.dx / tile;
    final up = _sc.dy / tile, down = (size.y - _sc.dy) / tile;
    const m = 1.0; // نخلي شوية برّا المدينة يبين
    final cx = cam.dx.clamp(halfW - m, wd.w - halfW + m).toDouble();
    final cy = cam.dy.clamp(up - m, wd.h - down + m).toDouble();
    cam = Offset(cx, cy);
    view = Rect.fromLTRB(cx - halfW, cy - up, cx + halfW, cy + down);
  }

  Offset P(Offset w) => _sc + (w - cam) * tile;
  Rect R(Rect r) => Rect.fromPoints(P(r.topLeft), P(r.bottomRight));
  bool _visible(Rect worldRect) => worldRect.overlaps(view.inflate(0.5));

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
    final mag = min(1.0, 0.55 + 0.45 * len);
    if (len > 1) _joyStart = _joyNow - (v / len) * 40; // العصا تلحگ إصبعك
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

  Rect _src(int i) => Rect.fromLTWH((i % 27) * 16.0, (i ~/ 27) * 16.0, 16, 16);

  void _spr(Canvas c, int i, Rect dst, [Paint? p]) => c.drawImageRect(_sheet!, _src(i), dst, p ?? _px);

  /// مربع بتسع قطع (زوايا + حواف + وسط)
  void _nine(Canvas c, int tl, Rect r, double s, [Paint? paint]) {
    final cols = max(2, (r.width / s).round());
    final rows = max(2, (r.height / s).round());
    final cw = r.width / cols, rh = r.height / rows;
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        final idx = tl + (j == 0 ? 0 : (j == rows - 1 ? 54 : 27)) + (i == 0 ? 0 : (i == cols - 1 ? 2 : 1));
        _spr(c, idx, Rect.fromLTWH(r.left + i * cw, r.top + j * rh, cw + 0.7, rh + 0.7), paint);
      }
    }
  }

  // ---------- الرسم ----------
  @override
  void render(Canvas c) {
    if (size.x != game.size.x || size.y != game.size.y) size = game.size.clone();
    _layout();
    if (_sheet == null) {
      // الصورة ناقصة: نكتب تنبيه بدل ما تطلع شاشة فارغة
      _say(c, '⚠️ ملف assets/images/city.png ناقص', Offset(size.x / 2, size.y * 0.7), 16, Colors.white);
      return;
    }
    c.save();
    if (wd.shake > 0) {
      c.translate((_rnd.nextDouble() - 0.5) * 12 * wd.shake, (_rnd.nextDouble() - 0.5) * 12 * wd.shake);
    }
    _ground(c);
    for (final pd in wd.puddles) {
      _puddle(c, pd);
    }
    _generatorDraw(c);
    _station(c);
    if (wd.phase != Phase.menu) {
      for (final t in wd.thugs) {
        if (t.slamAt != null) _slamWarn(c, t);
      }
    }
    // كلشي واگف على الگاع ينرسم حسب بعده (اللي جوه يطلع گدام) حتى البنايات تغطي اللي وراها
    final items = <MapEntry<double, VoidCallback>>[];
    var hn = 0;
    for (final hs in wd.houses) {
      hn++;
      if (!_visible(hs.rect.inflate(1.5))) continue;
      items.add(MapEntry(hs.rect.bottom, () => _house(c, hs)));
      final n = hn;
      items.add(MapEntry(hs.rect.bottom + 0.3, () => _decor(c, hs, n)));
    }
    for (final p in wd.pickups) {
      items.add(MapEntry(p.pos.dy, () => _pickup(c, p)));
    }
    for (final car in wd.cars) {
      if (_visible(car.rect)) items.add(MapEntry(car.pos.dy + 0.3, () => _car(c, car)));
    }
    for (final wk in wd.walkers) {
      items.add(MapEntry(wk.pos.dy, () => _walker(c, wk)));
    }
    for (final g in wd.greeters) {
      items.add(MapEntry(g.pos.dy, () => _greeter(c, g)));
    }
    var pk = 0;
    for (final park in wd.parks) {
      final k = pk++;
      if (k < 4) items.add(MapEntry(park.center.dy + 0.4, () => _kids(c, park, k)));
    }
    if (wd.phase != Phase.menu) {
      if (wd.cfg.vehicle && !(wd.riding && !wd.flying)) items.add(MapEntry(wd.truck.dy, () => _truck(c, wd.truck, wd.truckFace, false)));
      if (wd.cfg.heli && !wd.flying) items.add(MapEntry(wd.heli.dy, () => _heli(c, wd.heli, wd.heliFace, false)));
      items.add(MapEntry(wd.player.dy, () => _player(c)));
      for (final t in wd.thieves) {
        items.add(MapEntry(t.pos.dy, () => _thief(c, t)));
      }
      for (final t in wd.thugs) {
        items.add(MapEntry(t.pos.dy, () => _thug(c, t)));
      }
    }
    items.sort((a, b) => a.key.compareTo(b.key));
    for (final e in items) {
      e.value();
    }
    if (wd.phase != Phase.menu) _hint(c);
    for (final p in wd.particles) {
      c.drawCircle(P(p.pos), p.size * tile * (0.4 + p.life), Paint()..color = Color(p.color));
    }
    if (wd.flying && wd.phase != Phase.menu) {
      final hi = wd.hoverHouse;
      if (hi >= 0 && hi < wd.houses.length) {
        final ctr = _roofCenter(wd.houses[hi]);
        c.drawArc(Rect.fromCircle(center: ctr, radius: tile * 0.8), -pi / 2, 2 * pi * (wd.hoverT / 0.7).clamp(0.0, 1.0), false, Paint()
          ..color = const Color(0xFF80D8FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = tile * 0.14
          ..strokeCap = StrokeCap.round);
      }
      _heli(c, wd.player, wd.face, true);
    }
    final menu = wd.phase == Phase.menu;
    if (!menu && wd.cfg.theme == 1) {
      c.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = const Color(0x40FF6E40));
    }
    if (menu || wd.cfg.night) _night(c, menu ? 0.55 : 0.84);
    if (wd.stormT > 0 || (!menu && wd.cfg.rain)) _rain(c);
    for (final hs in wd.houses) {
      if (!hs.lit && _visible(hs.rect.inflate(1.5))) _houseAlarm(c, hs);
    }
    for (final f in wd.floats) {
      final pos = P(f.pos).translate(0, -tile * 0.6 - f.t * 45);
      final a = (255 * (1 - f.t / 1.2)).clamp(0, 255).round();
      final tp = _text(f.text, 20, Color(f.color));
      final r = Rect.fromCenter(center: pos, width: tp.width + 16, height: tp.height + 8);
      c.saveLayer(r.inflate(4), Paint()..color = Color.fromARGB(a, 0, 0, 0));
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)), Paint()..color = const Color(0xCC000000));
      tp.paint(c, Offset(r.left + 8, r.top + 4));
      c.restore();
    }
    c.restore();
    if (wd.lightning > 0) {
      c.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = Color.fromARGB((wd.lightning * 150).round(), 230, 240, 255));
    }
    if (wd.phase == Phase.playing || wd.phase == Phase.countdown) {
      _arrows(c);
      if (wd.overloadOn) _heatBar(c);
      if (wd.cfg.heli && (wd.flying || wd.heliFuel < 1)) _heliFuelBar(c);
      final b = wd.boss;
      if (b != null) _bossBar(c, b);
      if (wd.cfg.fuelDrain > 0) _fuelBar(c);
      _minimap(c);
    }
    _joystick(c);
    if (_heroTried && _hero == null && wd.phase != Phase.menu) {
      _say(c, '⚠️ assets/images/player.png ناقص', Offset(size.x / 2, size.y - 60), 13, Colors.white);
    }
  }

  void _ground(Canvas c) {
    const s = 0.5;
    final x0 = (view.left / s).floor() - 1, x1 = (view.right / s).ceil() + 1;
    final y0 = (view.top / s).floor() - 1, y1 = (view.bottom / s).ceil() + 1;
    final ts = tile * s;
    for (var gy = y0; gy <= y1; gy++) {
      for (var gx = x0; gx <= x1; gx++) {
        final wx = gx * s, wy = gy * s;
        final inside = wx >= 0 && wy >= 0 && wx < wd.w && wy < wd.h;
        final o = P(Offset(wx, wy));
        _spr(c, inside ? 441 : 28, Rect.fromLTWH(o.dx, o.dy, ts + 0.7, ts + 0.7));
      }
    }
    // حافة المدينة
    c.drawRect(
      R(Rect.fromLTWH(0, 0, wd.w, wd.h)),
      Paint()
        ..color = const Color(0xFFB0B4C8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = tile * 0.12,
    );
    // خطوط الشوارع
    final dash = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = tile * 0.06;
    for (var i = 1; i < wd.roadYs.length - 1; i++) {
      final y = wd.roadYs[i];
      if (y < view.top - 1 || y > view.bottom + 1) continue;
      for (var x = max(0.0, (view.left / 0.8).floor() * 0.8); x < min(wd.w, view.right + 1); x += 0.8) {
        if (wd.roadXs.any((rx) => (x + 0.2 - rx).abs() < 1.0)) continue;
        c.drawLine(P(Offset(x, y)), P(Offset(x + 0.4, y)), dash);
      }
    }
    for (var i = 1; i < wd.roadXs.length - 1; i++) {
      final x = wd.roadXs[i];
      if (x < view.left - 1 || x > view.right + 1) continue;
      for (var y = max(0.0, (view.top / 0.8).floor() * 0.8); y < min(wd.h, view.bottom + 1); y += 0.8) {
        if (wd.roadYs.any((ry) => (y + 0.2 - ry).abs() < 1.0)) continue;
        c.drawLine(P(Offset(x, y)), P(Offset(x, y + 0.4)), dash);
      }
      // عبّارات مشاة قبل كل تقاطع
      for (var j = 1; j < wd.roadYs.length - 1; j++) {
        final y = wd.roadYs[j] - 1.45;
        if (y < view.top - 1 || y > view.bottom + 1) continue;
        for (var k = 0; k < 3; k++) {
          _spr(c, 434, R(Rect.fromLTWH(x - 0.8 + k * 0.533, y, 0.54, 0.5)));
        }
      }
    }
    // أرصفة
    for (final hs in wd.houses) {
      if (_visible(hs.rect)) _nine(c, 8, R(hs.rect.inflate(0.25)), tile * 0.4);
    }
    if (_visible(wd.plaza)) _nine(c, 8, R(wd.plaza.inflate(0.25)), tile * 0.4);
    // حدايق
    var pi2 = 0;
    for (final pk in wd.parks) {
      pi2++;
      if (!_visible(pk)) continue;
      final r = R(pk.inflate(0.25));
      _nine(c, 0, r, tile * 0.4);
      if (pi2 % 2 == 0) _nine(c, 170, R(Rect.fromCenter(center: pk.center, width: 1.2, height: 0.9)), tile * 0.3);
      final ts = tile * 0.55;
      for (final o in [Offset(r.left + ts * 0.3, r.top + ts * 0.2), Offset(r.right - ts * 1.3, r.top + ts * 0.3), Offset(r.left + ts * 0.5, r.bottom - ts * 2.0)]) {
        _spr(c, 260, Rect.fromLTWH(o.dx, o.dy, ts, ts));
        _spr(c, 287, Rect.fromLTWH(o.dx, o.dy + ts, ts, ts));
      }
    }
    // أعمدة كهرباء جنب المولدة
    if (_visible(wd.plaza)) {
      final r = R(wd.plaza);
      final ts = tile * 0.6;
      _spr(c, 162, Rect.fromLTWH(r.left - ts * 0.2, r.bottom - ts * 1.9, ts, ts));
      _spr(c, 189, Rect.fromLTWH(r.left - ts * 0.2, r.bottom - ts * 0.9, ts, ts));
      _spr(c, 162, Rect.fromLTWH(r.right - ts * 0.8, r.bottom - ts * 1.9, ts, ts));
      _spr(c, 189, Rect.fromLTWH(r.right - ts * 0.8, r.bottom - ts * 0.9, ts, ts));
    }
    // ظلال البنايات على الگاع
    final shadow = Paint()..color = const Color(0x40000000);
    for (final hs in wd.houses) {
      if (!_visible(hs.rect.inflate(1.5))) continue;
      final g = R(hs.rect);
      final hh = _hH(hs) * tile;
      c.drawRect(Rect.fromLTRB(g.left + hh * 0.3, g.top - hh * 0.25, g.right + hh * 0.55, g.bottom + tile * 0.14), shadow);
    }
  }

  /// ارتفاع البناية (بالمربعات): طابق أو طابقين
  double _hH(House hs) => hs.floors == 2 ? 1.3 : 0.85;

  /// مركز السطح على الشاشة (للعلامات)
  Offset _roofCenter(House hs) {
    final hh = _hH(hs) * tile;
    return R(hs.rect).translate(hh * 0.28, -hh).center;
  }

  /// بناية 2.5D: واجهة أمامية + جانب + سطح مرفوع
  void _house(Canvas c, House hs) {
    final hh = _hH(hs) * tile;
    final sk = hh * 0.28;
    final g = R(hs.rect);
    final roof = g.translate(sk, -hh);
    // إذا اللاعب ورا البناية نخليها شفافة شوية حتى يبين
    final pr = wd.player;
    final behind = wd.phase != Phase.menu &&
        !wd.flying &&
        pr.dx > hs.rect.left - 0.3 &&
        pr.dx < hs.rect.right + 0.7 &&
        pr.dy < hs.rect.top + 0.3 &&
        pr.dy > hs.rect.top - _hH(hs) - 0.7;
    if (behind) c.saveLayer(roof.expandToInclude(g).inflate(sk + 4), Paint()..color = const Color(0x73000000));
    if (hs.lit) {
      c.drawRRect(RRect.fromRectAndRadius(g.inflate(tile * 0.2), Radius.circular(tile * 0.3)), Paint()..color = const Color(0x22FFE082));
    }
    final brick = hs.style % 3 == 0 ? 72 : (hs.style % 3 == 1 ? 180 : 99);
    // الجانب الشرقي (أغمق)
    final east = Path()
      ..moveTo(g.right, g.bottom)
      ..lineTo(g.right + sk, g.bottom - hh)
      ..lineTo(g.right + sk, g.top - hh)
      ..lineTo(g.right, g.top)
      ..close();
    c.drawPath(east, Paint()..color = hs.style % 3 == 1 ? const Color(0xFF8D4A1F) : const Color(0xFF7A2E26));
    c.drawPath(east, Paint()..color = const Color(0x33000000));
    // الواجهة الأمامية (مايلة مثل الجانب)
    c.save();
    c.translate(g.left, g.bottom);
    c.skew(-sk / hh, 0);
    final fw = g.width;
    const cols = 5;
    final cw = fw / cols;
    final rows = hs.floors;
    final rh = hh / rows;
    for (var row = 0; row < rows; row++) {
      for (var i = 0; i < cols; i++) {
        final cell = Rect.fromLTWH(i * cw, -hh + row * rh, cw + 0.7, rh + 0.7);
        _spr(c, brick, cell);
        final sq = min(cw, rh) * 0.86;
        final win = Rect.fromCenter(center: cell.center, width: sq, height: sq);
        if (row == rows - 1 && i == 2) {
          _spr(c, 285, win);
        } else {
          _spr(c, 336, win);
          final glass = win.deflate(sq * 0.32);
          c.drawRect(glass, Paint()..color = hs.lit ? const Color(0xDDFFD54F) : const Color(0xCC10141C));
        }
      }
    }
    // خط بين الطوابق
    if (rows > 1) c.drawRect(Rect.fromLTWH(0, -hh + rh - 2, fw, 4), Paint()..color = const Color(0x66000000));
    if (!hs.lit) c.drawRect(Rect.fromLTWH(0, -hh, fw, hh), Paint()..color = const Color(0x88000018));
    if (hs.flash > 0) {
      c.drawRect(Rect.fromLTWH(0, -hh, fw, hh), Paint()..color = Color.fromARGB((hs.flash / 0.6 * 200).round().clamp(0, 255), 255, 255, 255));
    }
    c.restore();
    // السطح
    _nine(c, hs.style % 2 == 0 ? 81 : 89, roof, tile * 0.4, _roofPaint(hs.style));
    _spr(c, 280, Rect.fromLTWH(roof.left + tile * 0.15, roof.top + tile * 0.12, tile * 0.42, tile * 0.42));
    if (hs.floors == 2) _spr(c, 254, Rect.fromLTWH(roof.right - tile * 0.6, roof.top + tile * 0.15, tile * 0.42, tile * 0.42));
    if (!hs.lit) c.drawRect(roof, Paint()..color = const Color(0x88000018));
    if (hs.flash > 0) {
      c.drawRect(roof, Paint()..color = Color.fromARGB((hs.flash / 0.6 * 200).round().clamp(0, 255), 255, 255, 255));
    }
    if (behind) c.restore();
    if (hs.angry > 0) _say(c, '😡', roof.topCenter.translate(0, -tile * 0.2 - (2.5 - hs.angry) * 10), tile * 0.6, Colors.white);
  }

  /// زينة: شجرة أو عمود إنارة بزاوية الرصيف الجنوبية
  void _decor(Canvas c, House hs, int n) {
    final r = R(hs.rect.inflate(0.25));
    final ts = tile * 0.55;
    if (n % 2 == 0) {
      _spr(c, 260, Rect.fromLTWH(r.left - ts * 0.1, r.bottom - ts * 1.8, ts, ts));
      _spr(c, 287, Rect.fromLTWH(r.left - ts * 0.1, r.bottom - ts * 0.8, ts, ts));
    } else if (n % 3 == 0) {
      _spr(c, 165, Rect.fromLTWH(r.right - ts * 0.9, r.bottom - ts * 1.8, ts, ts));
      _spr(c, 192, Rect.fromLTWH(r.right - ts * 0.9, r.bottom - ts * 0.8, ts, ts));
    }
  }

  void _walker(Canvas c, Walker wk) {
    if (!_visible(Rect.fromCircle(center: wk.pos, radius: 1))) return;
    final h = tile * 0.85;
    _drawChar(c, _charFrame(wk.sprite, wk.dir, true, wd.clock * 0.6 + wk.ring.left), P(wk.pos).translate(0, h * 0.2), h);
  }

  void _greeter(Canvas c, Greeter g) {
    if (!_visible(Rect.fromCircle(center: g.pos, radius: 1))) return;
    final h = tile * 0.9;
    final feet = P(g.pos).translate(0, h * 0.2 - sin(min(1.0, (2.2 - g.t) * 4) * pi) * tile * 0.15);
    _drawChar(c, g.sprite + 1, feet, h);
    // فقاعة كلام
    final tp = _text(g.text, 15, const Color(0xFF1A1A1A));
    final b = Rect.fromCenter(center: feet.translate(0, -h * 1.25), width: tp.width + 16, height: tp.height + 10);
    c.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(12)), Paint()..color = Colors.white);
    c.drawPath(
        Path()
          ..moveTo(b.center.dx - 6, b.bottom)
          ..lineTo(b.center.dx + 6, b.bottom)
          ..lineTo(b.center.dx, b.bottom + 8)
          ..close(),
        Paint()..color = Colors.white);
    tp.paint(c, Offset(b.left + 8, b.top + 5));
  }

  /// أطفال يلعبون طوبة بالحديقة
  void _kids(Canvas c, Rect park, int k) {
    if (!_visible(park)) return;
    final a = park.center + const Offset(-0.6, 0.35), b = park.center + const Offset(0.6, 0.35);
    final h = tile * 0.7;
    final t = (wd.clock * 0.8 + k) % 2;
    final f = t < 1 ? t : 2 - t;
    _drawChar(c, 23 + 3, P(a).translate(0, h * 0.2), h);
    _drawChar(c, 104, P(b).translate(0, h * 0.2), h);
    final ball = P(Offset.lerp(a, b, f)!).translate(0, -sin(f * pi) * tile * 0.5);
    c.drawCircle(P(Offset.lerp(a, b, f)!).translate(0, h * 0.15), tile * 0.08, Paint()..color = const Color(0x55000000));
    c.drawCircle(ball, tile * 0.11, Paint()..color = Colors.white);
    c.drawCircle(ball, tile * 0.11, Paint()
      ..color = const Color(0xFF212121)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }


  void _houseAlarm(Canvas c, House hs) {
    final center = _roofCenter(hs);
    final pulse = (sin(wd.clock * (hs.dark < 3 ? 14 : 7)) + 1) / 2;
    final rad = tile * 0.42;
    c.drawCircle(center, rad + pulse * tile * 0.18, Paint()..color = Color.fromARGB((90 + pulse * 90).round(), 255, 23, 68));
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
    _say(c, '⚡', center, tile * 0.42, Colors.white);
  }

  void _generatorDraw(Canvas c) {
    if (!_visible(wd.plaza)) return;
    final on = wd.generatorOn;
    final hot = wd.overloadOn;
    final shakeX = on ? sin(wd.clock * (hot ? 90 : 60)) * (hot ? 3 : 1.2) : 0.0;
    final r = R(wd.generator).shift(Offset(shakeX, 0));
    if (hot) {
      c.drawRRect(RRect.fromRectAndRadius(r.inflate(tile * (0.25 + wd.heat * 0.3)), Radius.circular(tile * 0.4)),
          Paint()..color = Color.fromARGB((60 + wd.heat * 150).round().clamp(0, 255), 255, 87, 34));
    }
    c.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(5, 6)), Radius.circular(tile * 0.15)), Paint()..color = const Color(0x55000000));
    final body = hot
        ? Color.lerp(const Color(0xFF2E7D32), const Color(0xFFD84315), wd.heat.clamp(0.0, 1.0))!
        : (on ? const Color(0xFF2E7D32) : const Color(0xFF616161));
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(tile * 0.15)), Paint()..color = body);
    c.drawRRect(
      RRect.fromRectAndRadius(r.deflate(tile * 0.06), Radius.circular(tile * 0.12)),
      Paint()
        ..color = const Color(0x55000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = tile * 0.06,
    );
    for (var k = 0; k < 5; k++) {
      final x = r.left + tile * 0.18 + k * tile * 0.14;
      c.drawLine(Offset(x, r.top + tile * 0.25), Offset(x, r.bottom - tile * 0.25), Paint()
        ..color = const Color(0x55000000)
        ..strokeWidth = 3);
    }
    final fan = Offset(r.right - tile * 0.4, r.center.dy);
    c.drawCircle(fan, tile * 0.32, Paint()..color = const Color(0xFF1B5E20));
    final ang = on ? wd.clock * (hot ? 35 : 20) : 0.0;
    for (var k = 0; k < 3; k++) {
      final a = ang + k * 2 * pi / 3;
      c.drawLine(fan, fan + Offset(cos(a), sin(a)) * tile * 0.27, Paint()
        ..color = const Color(0xFFA5D6A7)
        ..strokeWidth = tile * 0.08
        ..strokeCap = StrokeCap.round);
    }
    if (on) {
      for (var k = 0; k < 4; k++) {
        final t = (wd.clock * 0.7 + k / 4) % 1;
        c.drawCircle(
            Offset(r.left + tile * 0.3 + t * tile * 0.4, r.top - t * tile * 1.0),
            tile * (0.08 + t * 0.2),
            Paint()
              ..color = hot ? Color.fromARGB((160 * (1 - t)).round(), 60, 60, 60) : Color.fromARGB((120 * (1 - t)).round(), 200, 200, 200));
      }
    } else if (wd.cfg.fuelDrain > 0) {
      _say(c, '⛽', r.center.translate(0, -tile * 0.9 - sin(wd.clock * 8) * 4), tile * 0.6, Colors.white);
    }
    if (hot) _say(c, wd.nearGenerator ? '👇' : '🔥', r.topCenter.translate(0, -tile * 0.6 - sin(wd.clock * 10) * 5), tile * 0.6, Colors.white);
  }

  void _pickup(Canvas c, Pickup p) {
    if (!_visible(Rect.fromCircle(center: p.pos, radius: 0.5))) return;
    final bob = sin(wd.clock * 5 + p.pos.dx) * 4;
    final pos = P(p.pos).translate(0, bob);
    if (p.life < 2.5 && (wd.clock * 8).floor().isEven) return;
    c.drawOval(Rect.fromCenter(center: P(p.pos).translate(0, tile * 0.28), width: tile * 0.5, height: tile * 0.16),
        Paint()..color = const Color(0x55000000));
    if (p.kind == 0) {
      c.drawCircle(pos, tile * 0.48, Paint()..color = const Color(0x44FFB300));
      final r = Rect.fromCenter(center: pos, width: tile * 0.5, height: tile * 0.62);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(tile * 0.08)), Paint()..color = const Color(0xFFD32F2F));
      c.drawRect(Rect.fromLTWH(r.left, r.center.dy - tile * 0.05, r.width, tile * 0.1), Paint()..color = Colors.white);
      c.drawRect(Rect.fromLTWH(r.right - tile * 0.18, r.top - tile * 0.1, tile * 0.12, tile * 0.12), Paint()..color = const Color(0xFF424242));
    } else {
      c.drawCircle(pos, tile * 0.42, Paint()..color = const Color(0xFF0288D1));
      _say(c, '🛵', pos, tile * 0.45, Colors.white);
    }
  }

  void _car(Canvas c, Car car) {
    final p = P(car.pos);
    c.drawOval(
        Rect.fromCenter(
            center: p.translate(tile * 0.06, tile * 0.1), width: tile * (car.vertical ? 0.75 : 1.05), height: tile * (car.vertical ? 1.05 : 0.75)),
        Paint()..color = const Color(0x55000000));
    if (car.vertical) {
      final src = car.dir.dy > 0 ? _carFront[car.kind] : _carBack[car.kind];
      final scale = 0.72 / src.width; // عرض السيارة ثابت حتى ما تطلع على الرصيف
      final dst = Rect.fromCenter(center: p, width: src.width * scale * tile, height: src.height * scale * tile);
      c.drawImageRect(_sheet!, src, dst, _px);
    } else {
      final src = _carBack[car.kind];
      final scale = 0.72 / src.width;
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(car.dir.dx > 0 ? pi / 2 : -pi / 2);
      c.drawImageRect(_sheet!, src, Rect.fromCenter(center: Offset.zero, width: src.width * scale * tile, height: src.height * scale * tile), _px);
      c.restore();
    }
    if (car.honk > 2.0) _say(c, '📢', p.translate(0, -tile * 0.7), tile * 0.4, Colors.white);
  }

  /// إطار الشخصية: عمود 0 يسار، 1 جوه، 2 فوك، 3 يمين. صف 0 واگف، 1 و2 مشي
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

  /// نرسم الشخصية بحجم مضبوط على البكسل (16 × عدد صحيح) حتى تطلع واضحة مو مغوشة، ونحط حولها خط أسود
  void _drawChar(Canvas c, int frame, Offset feet, double h, [Paint? p]) {
    final px = max(1, (h / 16).round()).toDouble();
    final sz = px * 16;
    final left = (feet.dx - sz / 2).roundToDouble(), top = (feet.dy - sz * 0.95).roundToDouble();
    c.drawOval(Rect.fromCenter(center: feet, width: sz * 0.6, height: sz * 0.22), Paint()..color = const Color(0x66000000));
    final src = _src(frame);
    for (final o in [Offset(-px, 0), Offset(px, 0), Offset(0, -px), Offset(0, px)]) {
      c.drawImageRect(_sheet!, src, Rect.fromLTWH(left + o.dx, top + o.dy, sz, sz), _outline);
    }
    c.drawImageRect(_sheet!, src, Rect.fromLTWH(left, top, sz, sz), p ?? _px);
  }

  void _player(Canvas c) {
    final p = P(wd.player);
    if (wd.flying) return; // تنرسم فوگ كلشي بعدين
    if (wd.riding) {
      if (wd.invuln > 0 && (wd.clock * 12).floor().isEven) return;
      _truck(c, wd.player, wd.face, true);
      return;
    }
    final h = tile * 1.05;
    final moving = wd.move.distance > 0.05 && wd.stun <= 0;
    if (wd.boostTimer > 0) c.drawCircle(p.translate(0, -h * 0.35), h * 0.75, Paint()..color = const Color(0x5580D8FF));
    // إذا انضرب يرمش
    if (wd.invuln > 0 && wd.stun <= 0 && (wd.clock * 12).floor().isEven) return;
    c.drawOval(
      Rect.fromCenter(center: p.translate(0, h * 0.18), width: h * 0.9, height: h * 0.34),
      Paint()
        ..color = const Color(0xFFFFC107)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final dir = Offset(cos(wd.face), sin(wd.face));
    if (_hero != null) {
      _heroChar(c, p.translate(0, h * 0.18), h, moving, dir);
    } else if (_face != null) {
      _photoChar(c, p.translate(0, h * 0.18), h, moving);
    } else {
      final frame = _charFrame(266, dir, moving, wd.clock * (wd.boostTimer > 0 ? 1.6 : 1.0));
      _drawChar(c, frame, p.translate(0, h * 0.18), h, wd.stun > 0 ? _hurtPaint : null);
    }
    if (wd.stun > 0) _say(c, '💫', p.translate(0, -h * 0.95), tile * 0.4, Colors.white);
    // حركة الضربة
    if (wd.attackT > 0) {
      final k = 1 - wd.attackT / 0.18;
      final c0 = p.translate(0, -h * 0.35) + dir * tile * 0.4;
      c.drawArc(Rect.fromCircle(center: c0, radius: tile * (0.45 + k * 0.25)), wd.face - 1.0, 2.0, false, Paint()
        ..color = Color.fromARGB((230 * (1 - k)).round(), 255, 255, 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = tile * 0.12
        ..strokeCap = StrokeCap.round);
      _say(c, '👊', c0 + dir * tile * 0.35 * k, tile * 0.45, Colors.white);
    }
  }

  /// الشخصية الكاملة (صورة اللاعب): تمشي وتهتز وتنقلب حسب الاتجاه
  void _heroChar(Canvas c, Offset feet, double h, bool moving, Offset dir) {
    final img = _hero!;
    if (dir.dx > 0.25) _heroFlip = true;
    if (dir.dx < -0.25) _heroFlip = false;
    final hh = h * 1.05;
    final ww = hh * img.width / img.height;
    final t = wd.clock * (wd.boostTimer > 0 ? 22 : 14 + 8 * wd.running);
    final walk = moving ? sin(t) : 0.0;
    final bob = moving ? walk.abs() * h * 0.06 : sin(wd.clock * 2) * h * 0.012;
    c.drawOval(Rect.fromCenter(center: feet, width: ww * 0.75, height: h * 0.24), Paint()..color = const Color(0x66000000));
    c.save();
    c.translate(feet.dx, feet.dy - bob);
    c.rotate(walk * 0.07 + (_heroFlip ? 1 : -1) * 0.12 * wd.running);
    if (_heroFlip) c.scale(-1, 1);
    // نفس الشخص يمطّ شوية وهو يمشي
    final squash = moving ? 1 + walk.abs() * 0.03 : 1.0;
    c.scale(1 / squash, squash);
    c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromLTWH(-ww / 2, -hh, ww, hh),
        wd.stun > 0 ? _heroHurt : _heroPaint);
    // القبعة من المتجر
    final hat = wd.cos.eq('hat');
    if (hat.id != 'hat0') _say(c, hat.icon, Offset(ww * 0.04, -hh * 0.93), h * 0.5, Colors.white);
    c.restore();
  }

  /// وجه اللاعب بدائرة ذهبية
  void _faceCircle(Canvas c, Offset center, double r) {
    c.drawCircle(center.translate(0, r * 0.12), r * 1.08, Paint()..color = const Color(0x66000000));
    final img = _face!;
    c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCircle(center: center, radius: r), _smooth);
    if (wd.stun > 0) c.drawCircle(center, r, Paint()..color = const Color(0x66FF1744));
    c.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0xFFFFC107)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.5, r * 0.1),
    );
  }

  /// اللاعب بصورته: جسم عامل (صدرية برتقالية) وراسه الصورة
  void _photoChar(Canvas c, Offset feet, double h, bool moving) {
    final walk = moving ? sin(wd.clock * (wd.boostTimer > 0 ? 22 : 15)) : 0.0;
    final bob = moving ? walk.abs() * h * 0.04 : 0.0;
    c.drawOval(Rect.fromCenter(center: feet, width: h * 0.7, height: h * 0.24), Paint()..color = const Color(0x66000000));
    final ink = Paint()
      ..color = const Color(0xFF0B0F14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // رجلين
    for (final side in [-1.0, 1.0]) {
      final leg = RRect.fromRectAndRadius(
        Rect.fromCenter(center: feet.translate(side * h * 0.1, -h * 0.12 + side * walk * h * 0.05), width: h * 0.13, height: h * 0.24),
        Radius.circular(h * 0.05),
      );
      c.drawRRect(leg, Paint()..color = const Color(0xFF283593));
      c.drawRRect(leg, ink);
    }
    // جسم
    final body = Rect.fromCenter(center: feet.translate(0, -h * 0.36 - bob), width: h * 0.5, height: h * 0.34);
    for (final side in [-1.0, 1.0]) {
      final arm = feet.translate(side * h * 0.29, -h * 0.36 - bob - side * walk * h * 0.05);
      c.drawCircle(arm, h * 0.075, Paint()..color = const Color(0xFFD7A27A));
      c.drawCircle(arm, h * 0.075, ink);
    }
    final rb = RRect.fromRectAndRadius(body, Radius.circular(h * 0.1));
    c.drawRRect(rb, Paint()..color = const Color(0xFFFF8F00));
    c.drawRect(Rect.fromLTWH(body.left, body.center.dy - h * 0.02, body.width, h * 0.05), Paint()..color = const Color(0xFFFFF59D));
    c.drawLine(body.topCenter, body.bottomCenter, Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 2);
    c.drawRRect(rb, ink);
    // الراس = الصورة
    _faceCircle(c, feet.translate(0, -h * 0.82 - bob), h * 0.4);
  }

  /// هليكوبتر مرسومة بالكود: جسم وذيل ومروحة تدور، وإذا طايرة ظلها بعيد
  void _heli(Canvas c, Offset world, double angle, bool air) {
    if (!_visible(Rect.fromCircle(center: world, radius: 2))) return;
    final ground = P(world);
    final lift = air ? tile * 0.9 : 0.0;
    final p = ground.translate(0, -lift);
    final s = tile * 1.1;
    // ظل
    c.save();
    c.translate(ground.dx + lift * 0.3, ground.dy + tile * 0.1);
    c.rotate(angle);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 1.1, height: s * 0.5), Paint()..color = Color.fromARGB(air ? 70 : 100, 0, 0, 0));
    c.restore();
    if (!air) {
      // مهبط
      c.drawCircle(ground, s * 0.85, Paint()..color = const Color(0x55FFFFFF));
      _say(c, 'H', ground, tile * 0.9, const Color(0x66FFFFFF));
    }
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(angle);
    final ink = Paint()
      ..color = const Color(0xFF0B0F14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    // ذيل
    final tail = RRect.fromRectAndRadius(Rect.fromLTWH(-s * 1.05, -s * 0.07, s * 0.75, s * 0.14), Radius.circular(s * 0.07));
    final hc = Color(wd.cos.eq('heli').color);
    c.drawRRect(tail, Paint()..color = Color.lerp(hc, Colors.black, 0.15)!);
    c.drawRRect(tail, ink);
    final fin = Rect.fromCenter(center: Offset(-s * 1.0, 0), width: s * 0.12, height: s * 0.45);
    c.drawRect(fin, Paint()..color = Color.lerp(hc, Colors.black, 0.3)!);
    c.drawRect(fin, ink);
    // جسم
    final body = Rect.fromCenter(center: Offset.zero, width: s * 0.9, height: s * 0.55);
    c.drawOval(body, Paint()..color = hc);
    c.drawOval(body, ink);
    c.drawOval(Rect.fromCenter(center: Offset(s * 0.22, 0), width: s * 0.36, height: s * 0.38), Paint()..color = const Color(0xFF81D4FA));
    c.drawOval(Rect.fromCenter(center: Offset(s * 0.22, 0), width: s * 0.36, height: s * 0.38), ink);
    c.drawRect(Rect.fromCenter(center: Offset(-s * 0.15, 0), width: s * 0.12, height: s * 0.55), Paint()..color = const Color(0xFFFFC107));
    // مروحة
    final spin = air ? wd.clock * 30 : wd.clock * 2;
    final blade = Paint()
      ..color = const Color(0xCC263238)
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 4; k++) {
      final a = spin + k * pi / 2;
      c.drawLine(Offset.zero, Offset(cos(a), sin(a)) * s * 0.8, blade);
    }
    if (air) c.drawCircle(Offset.zero, s * 0.8, Paint()..color = const Color(0x22FFFFFF));
    c.drawCircle(Offset.zero, s * 0.08, Paint()..color = const Color(0xFF263238));
    c.restore();
    if (!air && wd.nearHeli) _say(c, '🔑', p.translate(0, -tile * 0.9 - sin(wd.clock * 8) * 4), tile * 0.45, Colors.white);
    if (air && _hero != null) {
      final img = _hero!;
      final src = Rect.fromLTWH(img.width * 0.2, 0, img.width * 0.6, img.height * 0.32);
      final hh = tile * 0.42;
      c.drawImageRect(img, src, Rect.fromCenter(center: p.translate(0, -tile * 0.05), width: hh * src.width / src.height, height: hh), _heroPaint);
    }
  }

  String _truckTintId = '';
  Paint _truckP = Paint();
  Paint _truckPaint() {
    final it = wd.cos.eq('truck');
    if (it.id != _truckTintId) {
      _truckTintId = it.id;
      _truckP = Paint()..filterQuality = FilterQuality.none;
      if (it.id != 'truck0') _truckP.colorFilter = ColorFilter.mode(Color(it.color), BlendMode.modulate);
    }
    return _truckP;
  }

  /// خريطة صغيرة بالزاوية
  void _minimap(Canvas c) {
    const mw = 92.0;
    final mh = mw * wd.h / wd.w;
    final o = Offset(12, size.y - 48 - mh);
    final k = mw / wd.w;
    final box = Rect.fromLTWH(o.dx, o.dy, mw, mh);
    c.drawRRect(RRect.fromRectAndRadius(box.inflate(4), const Radius.circular(10)), Paint()..color = const Color(0xCC0B1020));
    Offset m(Offset w) => o + w * k;
    final blink = (wd.clock * 4).floor().isEven;
    for (final hs in wd.houses) {
      final r = Rect.fromLTWH(o.dx + hs.rect.left * k, o.dy + hs.rect.top * k, hs.rect.width * k, hs.rect.height * k);
      c.drawRect(r, Paint()..color = hs.lit ? const Color(0xFF546E7A) : (blink ? const Color(0xFFFF1744) : const Color(0xFFFFC107)));
    }
    for (final pk in wd.parks) {
      c.drawRect(Rect.fromLTWH(o.dx + pk.left * k, o.dy + pk.top * k, pk.width * k, pk.height * k), Paint()..color = const Color(0xFF2E7D32));
    }
    c.drawRect(Rect.fromLTWH(o.dx + wd.generator.left * k, o.dy + wd.generator.top * k, wd.generator.width * k, wd.generator.height * k),
        Paint()..color = const Color(0xFFFFEB3B));
    if (wd.cfg.fuelDrain > 0) {
      c.drawRect(Rect.fromLTWH(o.dx + wd.station.left * k, o.dy + wd.station.top * k, wd.station.width * k, wd.station.height * k),
          Paint()..color = const Color(0xFFFF9800));
    }
    if (wd.cfg.vehicle && !wd.riding) c.drawCircle(m(wd.truck), 2.5, Paint()..color = const Color(0xFF69F0AE));
    if (wd.cfg.heli && !wd.flying) c.drawCircle(m(wd.heli), 2.5, Paint()..color = const Color(0xFFFF5252));
    for (final t in wd.thieves) {
      c.drawCircle(m(t.pos), 2.5, Paint()..color = const Color(0xFFD500F9));
    }
    for (final t in wd.thugs) {
      c.drawCircle(m(t.pos), t.boss ? 4 : 2, Paint()..color = t.boss ? const Color(0xFFD50000) : const Color(0xFFFF8A80));
    }
    // اللي يبين بالشاشة
    c.drawRect(Rect.fromLTRB(o.dx + view.left * k, o.dy + view.top * k, o.dx + view.right * k, o.dy + view.bottom * k).intersect(box), Paint()
      ..color = const Color(0x88FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    c.drawCircle(m(wd.player), 3.5, Paint()..color = Colors.white);
    c.drawCircle(m(wd.player), 5.5, Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  /// محطة الوقود: تملي التانكر بالسيارة
  void _station(Canvas c) {
    final st = wd.station;
    if (wd.cfg.fuelDrain <= 0 || !_visible(st)) return;
    _nine(c, 8, R(st.inflate(0.25)), tile * 0.4);
    final r = R(st);
    // أرضية + مضخات
    c.drawRect(r.deflate(tile * 0.15), Paint()..color = const Color(0xFF455A64));
    for (var k = 0; k < 2; k++) {
      final pr = Rect.fromCenter(center: Offset(r.left + r.width * (0.33 + k * 0.34), r.center.dy + tile * 0.2), width: tile * 0.35, height: tile * 0.55);
      c.drawRRect(RRect.fromRectAndRadius(pr, Radius.circular(tile * 0.06)), Paint()..color = const Color(0xFFE53935));
      c.drawRect(Rect.fromLTWH(pr.left + pr.width * 0.2, pr.top + pr.height * 0.15, pr.width * 0.6, pr.height * 0.25), Paint()..color = Colors.white);
    }
    // مظلة
    final roof = Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.32);
    c.drawRRect(RRect.fromRectAndRadius(roof, Radius.circular(tile * 0.08)), Paint()..color = const Color(0xFFD32F2F));
    c.drawRect(Rect.fromLTWH(roof.left, roof.bottom - tile * 0.12, roof.width, tile * 0.12), Paint()..color = Colors.white);
    _say(c, '⛽ محطة', roof.center.translate(0, -tile * 0.04), tile * 0.3, Colors.white);
    if (wd.riding && !wd.flying && !wd.tanker) {
      c.drawRect(r.inflate(tile * 0.1), Paint()
        ..color = Color.fromARGB((120 + sin(wd.clock * 8) * 100).round(), 255, 179, 0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4);
    }
  }

  void _heliFuelBar(Canvas c) {
    final r = Rect.fromLTWH(size.x - 132, size.y - 30, 110, 12);
    c.drawRRect(RRect.fromRectAndRadius(r.inflate(3), const Radius.circular(8)), Paint()..color = const Color(0xCC000000));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left, r.top, r.width * wd.heliFuel.clamp(0.0, 1.0), r.height), const Radius.circular(6)),
        Paint()..color = wd.heliFuel < 0.25 ? const Color(0xFFFF1744) : const Color(0xFF80D8FF));
    _say(c, '🚁', Offset(r.left - 16, r.center.dy), 16, Colors.white);
  }

  /// سيارة الشغل (بيك أب) تدور على أي اتجاه
  void _truck(Canvas c, Offset world, double angle, bool driving) {
    if (!_visible(Rect.fromCircle(center: world, radius: 1))) return;
    final p = P(world);
    const src = Rect.fromLTWH(272, 267, 16, 21);
    final sc = 0.82 / 16 * tile;
    c.save();
    c.translate(p.dx, p.dy);
    c.drawOval(Rect.fromCenter(center: Offset(tile * 0.06, tile * 0.1), width: tile * 1.0, height: tile * 1.0), Paint()..color = const Color(0x55000000));
    c.rotate(angle + pi / 2);
    final dst = Rect.fromCenter(center: Offset.zero, width: 16 * sc, height: 21 * sc);
    if (driving) {
      c.drawRRect(RRect.fromRectAndRadius(dst.inflate(tile * 0.08), Radius.circular(tile * 0.2)), Paint()..color = const Color(0x88FFC107));
    }
    c.drawImageRect(_sheet!, src, dst, _truckPaint());
    c.restore();
    if (wd.tanker) _say(c, '⛽', p.translate(tile * 0.35, -tile * 0.75), tile * 0.4, Colors.white);
    if (driving) {
      if (_hero != null) {
        // نص الشخصية الفوگاني طالع من السيارة
        final img = _hero!;
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height * 0.45);
        final hh = tile * 0.75;
        final ww = hh * src.width / src.height;
        c.drawImageRect(img, src, Rect.fromCenter(center: p.translate(0, -tile * 0.45), width: ww, height: hh), _heroPaint);
      } else if (_face != null) {
        _faceCircle(c, p.translate(0, -tile * 0.55), tile * 0.3);
      } else {
        _say(c, '👷', p.translate(0, -tile * 0.15), tile * 0.32, Colors.white);
      }
    } else if (wd.nearTruck) {
      _say(c, '🔑', p.translate(0, -tile * 0.8 - sin(wd.clock * 8) * 4), tile * 0.45, Colors.white);
    }
  }

  void _thug(Canvas c, Thug t) {
    if (!_visible(Rect.fromCircle(center: t.pos, radius: 1.5))) return;
    final p = P(t.pos);
    final h = tile * (t.boss ? 1.7 : 1.05);
    if (t.boss) {
      c.drawCircle(p.translate(0, -h * 0.35), h * 0.65, Paint()..color = Color.fromARGB((60 + sin(wd.clock * 6) * 30).round(), 255, 0, 0));
    }
    if (t.windup > 0) {
      c.drawCircle(p.translate(0, -h * 0.35), h * 0.55, Paint()
        ..color = const Color(0xCCFF1744)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
    }
    final paint = t.hurt > 0 ? _flashPaint : (t.boss ? _bossPaint : _thugPaint);
    _drawChar(c, _charFrame(t.boss ? 185 : 428, t.dir, t.windup <= 0, wd.clock + t.pos.dx), p.translate(0, h * 0.2), h, paint);
    // شريط الصحة
    final bw = h * 0.7;
    final bar = Rect.fromLTWH(p.dx - bw / 2, p.dy - h * 1.0, bw, t.boss ? 8 : 5);
    c.drawRect(bar.inflate(1.5), Paint()..color = const Color(0xDD000000));
    c.drawRect(Rect.fromLTWH(bar.left, bar.top, bw * (t.hp / t.maxHp).clamp(0.0, 1.0), bar.height), Paint()..color = const Color(0xFFFF5252));
    if (t.boss) _say(c, '👑', p.translate(0, -h * 1.15), tile * 0.45, Colors.white);
  }

  void _slamWarn(Canvas c, Thug b) {
    final at = b.slamAt!;
    final k = (1 - b.slamWarn / 1.1).clamp(0.0, 1.0);
    final center = P(at);
    final r = tile * 1.7;
    c.drawCircle(center, r, Paint()..color = Color.fromARGB((40 + k * 80).round(), 255, 23, 68));
    c.drawCircle(center, r * k, Paint()..color = const Color(0x55FF1744));
    c.drawCircle(center, r, Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    _say(c, '⚠️', center, tile * 0.5, Colors.white);
  }

  void _puddle(Canvas c, Puddle pd) {
    if (!_visible(Rect.fromCircle(center: pd.pos, radius: pd.r + 0.3))) return;
    final r = Rect.fromCenter(center: P(pd.pos), width: pd.r * 2.2 * tile, height: pd.r * 1.5 * tile);
    c.drawOval(r, Paint()..color = const Color(0x995C8DB8));
    c.drawOval(r.deflate(tile * 0.08), Paint()..color = const Color(0x6690CAF9));
    if (pd.state == 1 && (wd.clock * 10).floor().isEven) {
      c.drawOval(r, Paint()
        ..color = const Color(0xFFFFEB3B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
    if (pd.state == 2) {
      c.drawOval(r.inflate(tile * 0.1), Paint()..color = Color.fromARGB((90 + sin(wd.clock * 30) * 60).round(), 128, 216, 255));
      final paint = Paint()
        ..color = const Color(0xFFE1F5FE)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (var k = 0; k < 3; k++) {
        final a = wd.clock * 7 + k * 2.1;
        final path = Path()..moveTo(r.center.dx, r.center.dy);
        var q = r.center;
        for (var s = 0; s < 4; s++) {
          q = q + Offset(cos(a + s) * r.width * 0.12, sin(a * 1.3 + s) * r.height * 0.15);
          path.lineTo(q.dx, q.dy);
        }
        c.drawPath(path, paint);
      }
      _say(c, '⚡', r.center.translate(0, -r.height * 0.7), tile * 0.4, const Color(0xFFFFEB3B));
    }
  }

  void _bossBar(Canvas c, Thug b) {
    final w = size.x * 0.7;
    final r = Rect.fromLTWH((size.x - w) / 2, topSpace + (wd.overloadOn ? 34 : 8), w, 14);
    c.drawRRect(RRect.fromRectAndRadius(r.inflate(3), const Radius.circular(10)), Paint()..color = const Color(0xDD000000));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left, r.top, r.width * (b.hp / b.maxHp).clamp(0.0, 1.0), r.height), const Radius.circular(8)),
        Paint()..color = const Color(0xFFD50000));
    _say(c, '👹 الزعيم', r.center, 12, Colors.white);
  }

  void _thief(Canvas c, Thief t) {
    if (!_visible(Rect.fromCircle(center: t.pos, radius: 1))) return;
    final p = P(t.pos);
    final h = tile * 0.95;
    final fleeing = t.state == ThiefState.fleeing;
    c.drawCircle(p.translate(0, -h * 0.3), h * 0.6, Paint()..color = Color.fromARGB(((sin(wd.clock * 10) + 1) * 45).round(), 255, 23, 68));
    final moving = t.state != ThiefState.cutting;
    _drawChar(c, _charFrame(347, t.dir, moving, wd.clock * (fleeing ? 1.5 : 1.0)), p.translate(0, h * 0.2), h, _thiefPaint);
    if (t.state == ThiefState.cutting) {
      _say(c, '✂️', p.translate(0, -h * 1.0 + sin(wd.clock * 20) * 3), tile * 0.45, Colors.white);
    } else {
      _say(c, fleeing ? '💰' : '!', p.translate(0, -h * 1.0), tile * 0.45, const Color(0xFFFF1744));
    }
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
      c.drawCircle(q, 5, Paint()..color = const Color(0xFFFFEB3B));
    }
  }

  /// الليل: نعتّم الشاشة ونفتح ضوء حوالين اللاعب والبيوت المنوّرة والسيارات
  void _night(Canvas c, double darkness) {
    final screen = Offset.zero & Size(size.x, size.y);
    c.saveLayer(screen, Paint());
    c.drawRect(screen, Paint()..color = Color.fromARGB((255 * darkness).round(), 4, 8, 22));
    final hole = Paint()
      ..blendMode = BlendMode.dstOut
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, tile * 0.6);
    if (wd.phase != Phase.menu) c.drawCircle(P(wd.player), tile * 2.4, hole);
    final houseLight = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = const Color(0x99000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, tile * 0.5);
    for (final hs in wd.houses) {
      if (hs.lit && _visible(hs.rect)) c.drawOval(R(hs.rect.inflate(0.3)).translate(0, tile * 0.4), houseLight);
    }
    final carLight = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = const Color(0xCC000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, tile * 0.4);
    for (final car in wd.cars) {
      if (_visible(car.rect)) c.drawCircle(P(car.pos + car.dir * 1.0), tile * 0.8, carLight);
    }
    if (wd.generatorOn) c.drawCircle(P(wd.generator.center), tile * 1.4, hole);
    c.restore();
  }

  void _rain(Canvas c) {
    final paint = Paint()
      ..color = const Color(0x88B3E5FC)
      ..strokeWidth = 2;
    final t = wd.clock;
    for (var i = 0; i < 90; i++) {
      final x = (i * 97.3 + t * 120) % (size.x + 60) - 30;
      final y = (i * 53.7 + t * 900) % (size.y + 60) - 30;
      c.drawLine(Offset(x, y), Offset(x - 8, y + 22), paint);
    }
    c.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = const Color(0x22000033));
  }

  /// أسهم على حافة الشاشة تأشر للبيوت الطافية والحرامية والمولدة إذا برّا الشاشة
  void _arrows(Canvas c) {
    final inner = Rect.fromLTRB(30, topSpace + 30, size.x - 30, size.y - 50);
    void arrow(Offset world, String icon, Color color, {bool pulse = false}) {
      final s = P(world);
      if (inner.inflate(10).contains(s)) return;
      final v = s - inner.center;
      if (v.distance < 1) return;
      final tx = v.dx.abs() < 0.001 ? 1e9 : (inner.width / 2) / v.dx.abs();
      final ty = v.dy.abs() < 0.001 ? 1e9 : (inner.height / 2) / v.dy.abs();
      final pos = inner.center + v * min(tx, ty);
      final dir = v / v.distance;
      final r = 22.0 + (pulse ? sin(wd.clock * 12) * 3 : 0);
      final tip = pos + dir * (r + 12);
      final side = Offset(-dir.dy, dir.dx);
      final b1 = pos + dir * r + side * 9, b2 = pos + dir * r - side * 9;
      final tri = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(b2.dx, b2.dy)
        ..close();
      c.drawPath(tri, Paint()..color = color);
      c.drawCircle(pos, r, Paint()..color = color);
      c.drawCircle(pos, r - 4, Paint()..color = const Color(0xEE111820));
      _say(c, icon, pos, 20, Colors.white);
    }

    for (final hs in wd.houses) {
      if (!hs.lit) arrow(hs.center, '⚡', hs.dark < 3 ? const Color(0xFFFF1744) : const Color(0xFFFFC107), pulse: hs.dark < 3);
    }
    for (final t in wd.thieves) {
      if (t.pos.dx > -0.5 && t.pos.dx < wd.w + 0.5) arrow(t.pos, '🦹', const Color(0xFFD500F9), pulse: true);
    }
    if (wd.overloadOn) arrow(wd.generator.center, '🔥', const Color(0xFFFF6D00), pulse: true);
    for (final t in wd.thugs) {
      if (t.boss) arrow(t.pos, '👹', const Color(0xFFD50000), pulse: true);
    }
    if (wd.cfg.vehicle && !wd.riding) arrow(wd.truck, '🚙', const Color(0xFF43A047));
    if (wd.cfg.heli && !wd.flying) arrow(wd.heli, '🚁', const Color(0xFFE53935));
    if (wd.cfg.fuelDrain > 0 && wd.riding && !wd.flying) {
      if (wd.tanker) {
        arrow(wd.generator.center, '🏭', const Color(0xFF69F0AE), pulse: true);
      } else {
        arrow(wd.station.center, '⛽', const Color(0xFFFFB300), pulse: wd.fuel < 0.4);
      }
    }
    if (wd.cfg.fuelDrain > 0 && wd.fuel < 0.35) {
      for (final p in wd.pickups) {
        if (p.kind == 0) arrow(p.pos, '⛽', const Color(0xFFFFB300));
      }
    }
  }

  void _heatBar(Canvas c) {
    final w = size.x * 0.62;
    final r = Rect.fromLTWH((size.x - w) / 2, topSpace + 8, w, 16);
    c.drawRRect(RRect.fromRectAndRadius(r.inflate(3), const Radius.circular(10)), Paint()..color = const Color(0xDD000000));
    final hh = wd.heat.clamp(0.0, 1.0);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left, r.top, r.width * hh, r.height), const Radius.circular(8)),
        Paint()..color = Color.lerp(const Color(0xFFFFB300), const Color(0xFFFF1744), hh)!);
    _say(c, '🔥 حرارة المولدة', r.center, 12, Colors.white);
  }

  void _fuelBar(Canvas c) {
    final r = Rect.fromLTWH(12, size.y - 30, 110, 12);
    c.drawRRect(RRect.fromRectAndRadius(r.inflate(3), const Radius.circular(8)), Paint()..color = const Color(0xCC000000));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left, r.top, r.width * wd.fuel, r.height), const Radius.circular(6)),
        Paint()..color = Color.lerp(const Color(0xFFFF1744), const Color(0xFF69F0AE), wd.fuel)!);
    _say(c, '⛽', Offset(r.right + 16, r.center.dy), 16, Colors.white);
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
}
