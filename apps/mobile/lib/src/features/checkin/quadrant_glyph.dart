import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';

/// Quadrant icons — lighthouse, raindrop, moon, sun — so quadrants are never
/// encoded by colour alone (REQ-A11Y-10). Painted, so all four share one
/// line weight and none looks heavier than another.
class QuadrantGlyph extends StatelessWidget {
  const QuadrantGlyph(this.quadrant, {super.key, this.size = 20, this.color});

  final Quadrant quadrant;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _GlyphPainter(quadrant, color ?? AuraColors.quadrant(quadrant)),
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.q, this.color);

  final Quadrant q;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, w * 0.08)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    switch (q) {
      case Quadrant.storm: // lighthouse
        final tower = Path()
          ..moveTo(w * 0.38, w * 0.92)
          ..lineTo(w * 0.44, w * 0.38)
          ..lineTo(w * 0.56, w * 0.38)
          ..lineTo(w * 0.62, w * 0.92)
          ..close();
        canvas.drawPath(tower, stroke);
        canvas.drawRect(Rect.fromLTRB(w * 0.42, w * 0.24, w * 0.58, w * 0.38), stroke);
        canvas.drawCircle(Offset(w * 0.5, w * 0.31), w * 0.04, fill);
        canvas.drawLine(Offset(w * 0.62, w * 0.28), Offset(w * 0.92, w * 0.18), stroke);
        canvas.drawLine(Offset(w * 0.38, w * 0.28), Offset(w * 0.08, w * 0.18), stroke);
        canvas.drawLine(Offset(w * 0.25, w * 0.92), Offset(w * 0.75, w * 0.92), stroke);
      case Quadrant.rain: // raindrop
        final drop = Path()
          ..moveTo(w * 0.5, w * 0.1)
          ..quadraticBezierTo(w * 0.86, w * 0.52, w * 0.78, w * 0.68)
          ..arcToPoint(Offset(w * 0.22, w * 0.68), radius: Radius.circular(w * 0.29))
          ..quadraticBezierTo(w * 0.14, w * 0.52, w * 0.5, w * 0.1)
          ..close();
        canvas.drawPath(drop, stroke);
      case Quadrant.moonlight: // crescent moon
        final moon = Path()
          ..addOval(Rect.fromCircle(center: Offset(w * 0.5, w * 0.5), radius: w * 0.38));
        final bite = Path()
          ..addOval(Rect.fromCircle(center: Offset(w * 0.68, w * 0.36), radius: w * 0.32));
        canvas.drawPath(Path.combine(PathOperation.difference, moon, bite), stroke);
      case Quadrant.sunrise: // sun
        canvas.drawCircle(Offset(w * 0.5, w * 0.5), w * 0.2, stroke);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(
            Offset(w * 0.5, w * 0.5) + d * (w * 0.32),
            Offset(w * 0.5, w * 0.5) + d * (w * 0.44),
            stroke,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.q != q || old.color != color;
}

String quadrantName(AppLocalizations l, Quadrant q) => switch (q) {
  Quadrant.storm => l.quadrant_storm,
  Quadrant.rain => l.quadrant_rain,
  Quadrant.moonlight => l.quadrant_moonlight,
  Quadrant.sunrise => l.quadrant_sunrise,
};

String tagLabel(AppLocalizations l, String key) => switch (key) {
  'study' => l.tag_study,
  'work' => l.tag_work,
  'family' => l.tag_family,
  'friends' => l.tag_friends,
  'sleep' => l.tag_sleep,
  'health' => l.tag_health,
  'money' => l.tag_money,
  'love' => l.tag_love,
  'alone' => l.tag_alone,
  'commute' => l.tag_commute,
  _ => key,
};

String habitLabel(AppLocalizations l, String key) => switch (key) {
  'hydrate' => l.habit_hydrate,
  'sleep_on_time' => l.habit_sleep_on_time,
  'move' => l.habit_move,
  'breathe' => l.habit_breathe,
  'journal' => l.habit_journal,
  'go_outside' => l.habit_go_outside,
  _ => key,
};
