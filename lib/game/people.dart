import 'dart:math';

import 'package:flutter/material.dart';

/// أشكال الناس بالمحلة
enum PersonLook { dishdasha, shemagh, abaya, kid, oldMan, player, doctor }

Color _shadeColor(int argb, double light) {
  final k = 0.35 + 0.65 * light;
  int ch(int shift) => (((argb >> shift) & 0xFF) * k).clamp(0, 255).round();
  return Color.fromARGB(255, ch(16), ch(8), ch(0));
}

/// يرسم شخص واقف رجليه على [feet]. [unit] هو عرض المربع (tw) حتى الحجم يتناسب.
/// [walkPhase] إذا موجود يحرك الرجلين والإيدين. [face] = 1 يباوع يمين، -1 يسار.
void drawPerson(
  Canvas c,
  Offset feet,
  double unit,
  PersonLook look, {
  double light = 1,
  double? walkPhase,
  double face = 1,
  bool sitting = false,
  int? shirt,
  double scale = 1,
}) {
  Color sh(int v) => _shadeColor(v, light);
  final kid = look == PersonLook.kid;
  final s = unit * 0.065 * scale * (kid ? 0.72 : 1);
  final swing = walkPhase == null ? 0.0 : sin(walkPhase) * s * 0.45;
  final skin = sh(kid ? 0xFFE0B48A : 0xFFC99A6E);

  // الظل
  c.drawOval(Rect.fromCenter(center: feet, width: s * 1.8, height: s * 0.6), Paint()..color = const Color(0x33000000));

  final bodyTop = sitting ? -s * 2.3 : -s * 3.0;
  final bodyBottom = sitting ? -s * 0.9 : -s * 0.25;

  var robe = 0xFFF2F2F2;
  switch (look) {
    case PersonLook.dishdasha:
      robe = 0xFFF2F2F2;
    case PersonLook.shemagh:
      robe = 0xFF9E9E9E;
    case PersonLook.abaya:
      robe = 0xFF1C1C1C;
    case PersonLook.kid:
      robe = shirt ?? 0xFF43A047;
    case PersonLook.oldMan:
      robe = 0xFF8D6E63;
    case PersonLook.player:
      robe = 0xFF78909C;
    case PersonLook.doctor:
      robe = 0xFFFFFFFF;
  }

  // الرجلين
  final legPaint = Paint()
    ..color = sh(kid ? 0xFF37474F : 0xFF3E2723)
    ..strokeWidth = s * 0.3
    ..strokeCap = StrokeCap.round;
  if (sitting) {
    c.drawLine(feet.translate(-s * 0.2, bodyBottom), feet.translate(-s * 0.2 + face * s * 0.5, -s * 0.3), legPaint);
    c.drawLine(feet.translate(s * 0.2, bodyBottom), feet.translate(s * 0.2 + face * s * 0.5, -s * 0.3), legPaint);
  } else {
    c.drawLine(feet.translate(-s * 0.2, -s * 0.9), feet.translate(-s * 0.2 + swing, 0), legPaint);
    c.drawLine(feet.translate(s * 0.2, -s * 0.9), feet.translate(s * 0.2 - swing, 0), legPaint);
  }

  // الجسم
  if (kid) {
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(feet.dx - s * 0.55, feet.dy + bodyTop, feet.dx + s * 0.55, feet.dy - s * 1.2),
          Radius.circular(s * 0.3)),
      Paint()..color = sh(robe),
    );
    c.drawRect(Rect.fromLTRB(feet.dx - s * 0.5, feet.dy - s * 1.3, feet.dx + s * 0.5, feet.dy - s * 0.8),
        Paint()..color = sh(0xFF1565C0));
  } else {
    final robePath = Path()
      ..moveTo(feet.dx - s * 0.5, feet.dy + bodyTop)
      ..lineTo(feet.dx + s * 0.5, feet.dy + bodyTop)
      ..lineTo(feet.dx + s * 0.7, feet.dy + bodyBottom)
      ..lineTo(feet.dx - s * 0.7, feet.dy + bodyBottom)
      ..close();
    c.drawPath(robePath, Paint()..color = sh(robe));
    if (look == PersonLook.player) {
      // سترة غامقة فوك الدشداشة
      c.drawRect(Rect.fromLTRB(feet.dx - s * 0.55, feet.dy + bodyTop, feet.dx + s * 0.55, feet.dy + bodyTop + s * 1.3),
          Paint()..color = sh(0xFF263238));
    }
    if (look == PersonLook.doctor) {
      c.drawLine(feet.translate(0, bodyTop), feet.translate(0, bodyBottom), Paint()
        ..color = sh(0xFFB0BEC5)
        ..strokeWidth = 1);
    }
  }

  // الإيدين
  final armPaint = Paint()
    ..color = sh(robe)
    ..strokeWidth = s * 0.28
    ..strokeCap = StrokeCap.round;
  final shoulder = feet.dy + bodyTop + s * 0.3;
  c.drawLine(Offset(feet.dx - s * 0.5, shoulder), Offset(feet.dx - s * 0.65 - swing * 0.6, shoulder + s * 1.2), armPaint);
  c.drawLine(Offset(feet.dx + s * 0.5, shoulder), Offset(feet.dx + s * 0.65 + swing * 0.6, shoulder + s * 1.2), armPaint);

  // عكازة الشايب
  if (look == PersonLook.oldMan && !sitting) {
    c.drawLine(Offset(feet.dx + face * s * 0.8, shoulder + s * 1.1), Offset(feet.dx + face * s * 1.0, feet.dy), Paint()
      ..color = sh(0xFF5D4037)
      ..strokeWidth = s * 0.15);
  }

  // الراس
  final head = Offset(feet.dx, feet.dy + bodyTop - s * 0.5);
  final hr = s * 0.45;
  switch (look) {
    case PersonLook.abaya:
      c.drawCircle(head, hr * 1.15, Paint()..color = sh(0xFF1C1C1C));
      c.drawCircle(head.translate(face * hr * 0.25, hr * 0.1), hr * 0.6, Paint()..color = skin);
    case PersonLook.shemagh:
      c.drawCircle(head, hr, Paint()..color = skin);
      // يشماغ أحمر وأبيض وعگال
      final cloth = Path()
        ..moveTo(head.dx - hr * 1.2, head.dy - hr * 0.2)
        ..quadraticBezierTo(head.dx, head.dy - hr * 1.8, head.dx + hr * 1.2, head.dy - hr * 0.2)
        ..lineTo(head.dx - face * hr * 1.3, head.dy + hr * 1.6)
        ..close();
      c.drawPath(cloth, Paint()..color = sh(0xFFE53935));
      c.drawLine(head.translate(-hr * 0.9, -hr * 0.6), head.translate(hr * 0.9, -hr * 0.6), Paint()
        ..color = sh(0xFFFFFFFF)
        ..strokeWidth = 1);
      c.drawLine(head.translate(-hr * 1.0, -hr * 0.85), head.translate(hr * 1.0, -hr * 0.85), Paint()
        ..color = const Color(0xFF111111)
        ..strokeWidth = s * 0.18);
    case PersonLook.oldMan:
      c.drawCircle(head, hr, Paint()..color = skin);
      c.drawArc(Rect.fromCircle(center: head, radius: hr), pi, pi, true, Paint()..color = sh(0xFFE0E0E0));
      c.drawCircle(head.translate(0, -hr * 0.85), hr * 0.55, Paint()..color = sh(0xFFFFFFFF)); // عرقجين
    case PersonLook.player:
      c.drawCircle(head, hr, Paint()..color = skin);
      c.drawArc(Rect.fromCircle(center: head, radius: hr), pi, pi, true, Paint()..color = sh(0xFF212121));
      // كاب
      c.drawRect(Rect.fromLTRB(head.dx - hr, head.dy - hr * 1.05, head.dx + hr, head.dy - hr * 0.45), Paint()..color = sh(0xFFFF8F00));
      c.drawRect(Rect.fromLTRB(head.dx, head.dy - hr * 0.6, head.dx + face * hr * 1.6, head.dy - hr * 0.4),
          Paint()..color = sh(0xFFFF8F00));
    default:
      c.drawCircle(head, hr, Paint()..color = skin);
      c.drawArc(Rect.fromCircle(center: head, radius: hr), pi, pi, true, Paint()..color = sh(0xFF212121));
  }
  // عيون صغيرة
  c.drawCircle(head.translate(face * hr * 0.35, -hr * 0.05), max(0.8, hr * 0.12), Paint()..color = const Color(0xFF111111));
}
