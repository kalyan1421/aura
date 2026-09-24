import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';

import '../../core/theme/aura_tokens.dart';

// Procedural art for the Aura Sky (CustomPainter only, no assets). Stars are
// soft and dim so text never sits on a bright field (REQ-A11Y-03); motion is
// a slow shimmer of the halo only (well under 3 changes a second,
// REQ-A11Y-09), and none at all under Reduce Motion.

/// A small quadrant silhouette for places too small for the full glyph (the
/// year view, the month recap's sky): Storm a lighthouse-like triangle, Rain
/// a drop, Moonlight a crescent, Sunrise a round sun. Shapes differ, so a
/// greyscale sky still reads (REQ-A11Y-10).
void paintQuadrantMark(
  Canvas canvas,
  Offset c,
  double r,
  Quadrant q,
  Color color,
) {
  final fill = Paint()
    ..color = color
    ..isAntiAlias = true;
  switch (q) {
    case Quadrant.storm:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * 0.9, c.dy + r * 0.8)
          ..lineTo(c.dx - r * 0.9, c.dy + r * 0.8)
          ..close(),
        fill,
      );
    case Quadrant.rain:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r)
          ..quadraticBezierTo(c.dx + r * 0.95, c.dy + r * 0.1, c.dx, c.dy + r)
          ..quadraticBezierTo(c.dx - r * 0.95, c.dy + r * 0.1, c.dx, c.dy - r)
          ..close(),
        fill,
      );
    case Quadrant.moonlight:
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: c, radius: r)),
          Path()..addOval(
            Rect.fromCircle(
              center: c + Offset(r * 0.5, -r * 0.35),
              radius: r * 0.8,
            ),
          ),
        ),
        fill,
      );
    case Quadrant.sunrise:
      canvas.drawCircle(c, r * 0.75, fill);
  }
}

/// The glow behind one day of the month view: a soft halo in the day's
/// quadrant colour (wedges for a split day), a faint ring for a rest day,
/// nothing for a quiet day. [shimmer] (0–1) gently breathes the halo.
class StarHaloPainter extends CustomPainter {
  StarHaloPainter({
    required this.star,
    this.twinkle,
    this.phase = 0,
    this.today = false,
  }) : super(repaint: twinkle);

  final DayStar star;

  /// A slow repeating 0–1 clock; `null` under Reduce Motion (still).
  final Animation<double>? twinkle;

  /// This star's offset in the shimmer cycle (0–1), so they don't pulse
  /// together.
  final double phase;
  final bool today;

  double get _shimmer {
    final t = twinkle?.value;
    if (t == null) return 0.5;
    return 0.5 + 0.5 * math.sin(2 * math.pi * (t + phase));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shimmer = _shimmer;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (today) {
      canvas.drawCircle(
        c,
        r - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AuraColors.lavender.withValues(alpha: 0.7),
      );
    }
    switch (star.kind) {
      case DayStarKind.empty:
        return;
      case DayStarKind.rest:
        canvas.drawCircle(
          c,
          r * 0.34,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = AuraColors.starlight.withValues(alpha: 0.45),
        );
        return;
      case DayStarKind.single:
      case DayStarKind.split:
        final alpha = 0.30 + 0.12 * shimmer;
        final n = star.quadrants.length;
        final rect = Rect.fromCircle(center: c, radius: r * 0.92);
        for (var i = 0; i < n; i++) {
          final color = AuraColors.quadrant(star.quadrants[i]);
          final paint = Paint()
            ..shader = RadialGradient(
              colors: [
                color.withValues(alpha: alpha),
                color.withValues(alpha: 0),
              ],
            ).createShader(rect);
          if (n == 1) {
            canvas.drawCircle(c, rect.width / 2, paint);
          } else {
            final sweep = 2 * math.pi / n;
            canvas.drawArc(rect, -math.pi / 2 + i * sweep, sweep, true, paint);
          }
        }
    }
  }

  @override
  bool shouldRepaint(StarHaloPainter old) =>
      old.star != star ||
      old.twinkle != twinkle ||
      old.phase != phase ||
      old.today != today;
}

/// One month of the year view: a 7-column grid of small marks (weeks start
/// Monday). Quiet days are plain sky.
class YearMonthPainter extends CustomPainter {
  YearMonthPainter({required this.days, required this.stars});

  /// The month's days, 1st to last.
  final DayRange days;
  final DayStar Function(LocalDay) stars;

  @override
  void paint(Canvas canvas, Size size) {
    final lead = isoWeekday(days.from) - 1;
    final rows = ((lead + days.length) / 7).ceil();
    final cell = math.min(size.width / 7, size.height / math.max(rows, 5));
    final r = cell * 0.36;
    for (var i = 0; i < days.length; i++) {
      final slot = lead + i;
      final c = Offset((slot % 7 + 0.5) * cell, (slot ~/ 7 + 0.5) * cell);
      final star = stars(days.from.addDays(i));
      switch (star.kind) {
        case DayStarKind.empty:
          break;
        case DayStarKind.rest:
          canvas.drawCircle(
            c,
            r * 0.6,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8
              ..color = AuraColors.starlight.withValues(alpha: 0.4),
          );
        case DayStarKind.single:
          final q = star.quadrants.single;
          paintQuadrantMark(canvas, c, r, q, AuraColors.quadrant(q));
        case DayStarKind.split:
          // Two marks side by side (the first two tied quadrants).
          final a = star.quadrants[0];
          final b = star.quadrants[1];
          paintQuadrantMark(
            canvas,
            c - Offset(r * 0.5, 0),
            r * 0.6,
            a,
            AuraColors.quadrant(a),
          );
          paintQuadrantMark(
            canvas,
            c + Offset(r * 0.5, 0),
            r * 0.6,
            b,
            AuraColors.quadrant(b),
          );
      }
    }
  }

  @override
  bool shouldRepaint(YearMonthPainter old) =>
      old.days != days || old.stars != stars;
}

/// "Your month in stars": one star per check-in, scattered over a small
/// night sky by a fixed seed (the same month always draws the same sky).
/// Colour and shape both carry the quadrant.
class MixSkyPainter extends CustomPainter {
  MixSkyPainter({required this.counts, required this.seed});

  final Map<Quadrant, int> counts;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    // A few dim background stars so an almost-empty month still looks like
    // a sky, never a blank box.
    final dim = Paint()..color = AuraColors.text.withValues(alpha: 0.18);
    for (var i = 0; i < 24; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.6 + rnd.nextDouble() * 0.6,
        dim,
      );
    }
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return;
    // Smaller stars when the month is full, so 90 check-ins still fit.
    final r = (size.shortestSide / (5 + math.sqrt(total) * 1.6)).clamp(
      3.0,
      11.0,
    );
    final placed = <Offset>[];
    for (final q in Quadrant.values) {
      final color = AuraColors.quadrant(q);
      for (var i = 0; i < (counts[q] ?? 0); i++) {
        var p = Offset.zero;
        // A few tries to keep stars from sitting on each other.
        for (var t = 0; t < 12; t++) {
          p = Offset(
            r + rnd.nextDouble() * (size.width - 2 * r),
            r + rnd.nextDouble() * (size.height - 2 * r),
          );
          if (placed.every((o) => (o - p).distance > r * 2.2)) break;
        }
        placed.add(p);
        canvas.drawCircle(
          p,
          r * 2.2,
          Paint()
            ..shader = RadialGradient(
              colors: [
                color.withValues(alpha: 0.28),
                color.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: p, radius: r * 2.2)),
        );
        paintQuadrantMark(canvas, p, r, q, color);
      }
    }
  }

  @override
  bool shouldRepaint(MixSkyPainter old) =>
      old.seed != seed || !_sameCounts(old.counts, counts);

  static bool _sameCounts(Map<Quadrant, int> a, Map<Quadrant, int> b) =>
      Quadrant.values.every((q) => a[q] == b[q]);
}
