import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Which motif a seal carries (procedural, CustomPainter; no image assets).
enum SealMotif { capsule, glow, ripples, lantern, sanctuary }

/// Presentation of one catalogue keepsake: its motif, fixed colours and line.
/// The line is the seal's words ("Opened a capsule from past me"), the same in
/// the private box and on its share card.
@immutable
class KeepsakeLook {
  const KeepsakeLook(this.motif, this.base, this.glow, this.tier);

  final SealMotif motif;

  /// Fixed per motif, never from the person's mood hue.
  final Color base;
  final Color glow;

  /// 0-3: how many rings / rays the motif draws (bigger milestones, fuller
  /// seals). Never shown as a number or a level.
  final int tier;

  static KeepsakeLook of(String key) => switch (key) {
    'capsule_sealed_first' => const KeepsakeLook(
      SealMotif.capsule,
      Color(0xFF3A2F5C),
      Color(0xFFC9BFFF),
      0,
    ),
    'capsule_opened_first' => const KeepsakeLook(
      SealMotif.capsule,
      Color(0xFF3A2F5C),
      Color(0xFFF7E6B5),
      1,
    ),
    'glow_days_7' => const KeepsakeLook(
      SealMotif.glow,
      Color(0xFF3B2A18),
      Color(0xFFF3BE67),
      0,
    ),
    'glow_days_30' => const KeepsakeLook(
      SealMotif.glow,
      Color(0xFF3B2A18),
      Color(0xFFF3BE67),
      1,
    ),
    'glow_days_100' => const KeepsakeLook(
      SealMotif.glow,
      Color(0xFF3B2A18),
      Color(0xFFF7E6B5),
      2,
    ),
    'glow_days_365' => const KeepsakeLook(
      SealMotif.glow,
      Color(0xFF3B2A18),
      Color(0xFFFFF4D6),
      3,
    ),
    'ripples_first' => const KeepsakeLook(
      SealMotif.ripples,
      Color(0xFF12303A),
      Color(0xFF8FE3D6),
      1,
    ),
    'lantern_hours_1' => const KeepsakeLook(
      SealMotif.lantern,
      Color(0xFF3A2219),
      Color(0xFFF6C1A4),
      0,
    ),
    'lantern_hours_10' => const KeepsakeLook(
      SealMotif.lantern,
      Color(0xFF3A2219),
      Color(0xFFF6C1A4),
      1,
    ),
    'lantern_hours_50' => const KeepsakeLook(
      SealMotif.lantern,
      Color(0xFF3A2219),
      Color(0xFFFFE0C8),
      2,
    ),
    'sanctuary_minutes_60' => const KeepsakeLook(
      SealMotif.sanctuary,
      Color(0xFF16213F),
      Color(0xFFAFC3F0),
      0,
    ),
    'sanctuary_minutes_300' => const KeepsakeLook(
      SealMotif.sanctuary,
      Color(0xFF16213F),
      Color(0xFFAFC3F0),
      1,
    ),
    _ => const KeepsakeLook(
      SealMotif.sanctuary,
      Color(0xFF16213F),
      Color(0xFFDCE6FF),
      2,
    ),
  };
}

/// The seal's line, from the catalogue key and its threshold.
String keepsakeLine(AppLocalizations l, String key) {
  final def = keepsakeCatalogue.firstWhere(
    (d) => d.key == key,
    orElse: () => keepsakeCatalogue.first,
  );
  return switch (def.source) {
    KeepsakeSource.capsuleSeals => l.keepsake_capsuleSealedFirst,
    KeepsakeSource.capsuleOpens => l.keepsake_capsuleOpenedFirst,
    KeepsakeSource.glowDays => l.keepsake_glowDays(def.threshold),
    KeepsakeSource.rippleSessions => l.keepsake_ripplesFirst,
    KeepsakeSource.lanternNights =>
      def.threshold == 1
          ? l.keepsake_lanternFirst
          : l.keepsake_lanternHours(def.threshold),
    KeepsakeSource.sanctuarySeconds => l.keepsake_sanctuaryMinutes(
      def.threshold ~/ 60,
    ),
  };
}

/// Glow seals, hidden from Home while Comfort › hide streak number is on.
bool isGlowKeepsake(String key) => key.startsWith('glow_days_');

/// A round seal, drawn in code: a soft disc, a scalloped rim, the motif.
class KeepsakeSeal extends StatelessWidget {
  const KeepsakeSeal({super.key, required this.keepsakeKey, this.size = 96});

  final String keepsakeKey;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: KeepsakeSealPainter(KeepsakeLook.of(keepsakeKey)),
    ),
  );
}

class KeepsakeSealPainter extends CustomPainter {
  KeepsakeSealPainter(this.look);

  final KeepsakeLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    // Halo.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            look.glow.withValues(alpha: 0.35),
            look.glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Scalloped wax rim.
    final rim = Path();
    const bumps = 18;
    for (var i = 0; i <= bumps * 4; i++) {
      final a = i / (bumps * 4) * 2 * math.pi;
      final rr = r * (0.80 + 0.03 * math.cos(a * bumps));
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? rim.moveTo(p.dx, p.dy) : rim.lineTo(p.dx, p.dy);
    }
    rim.close();
    canvas.drawPath(
      rim,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [Color.lerp(look.base, look.glow, 0.35)!, look.base],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.05
      ..color = look.glow.withValues(alpha: 0.9);
    canvas.drawCircle(c, r * 0.66, line..strokeWidth = r * 0.025);
    line.strokeWidth = r * 0.05;
    switch (look.motif) {
      case SealMotif.capsule:
        _capsule(canvas, c, r, line);
      case SealMotif.glow:
        _glow(canvas, c, r, line);
      case SealMotif.ripples:
        _ripples(canvas, c, r, line);
      case SealMotif.lantern:
        _lantern(canvas, c, r, line);
      case SealMotif.sanctuary:
        _sanctuary(canvas, c, r, line);
    }
  }

  void _capsule(Canvas canvas, Offset c, double r, Paint line) {
    // A folded note with a small star (sealed) or an open flap (opened).
    final w = r * 0.72;
    final h = r * 0.48;
    final rect = Rect.fromCenter(
      center: c + Offset(0, r * 0.06),
      width: w,
      height: h,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r * 0.06)),
      line,
    );
    final flap = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(c.dx, rect.top + (look.tier == 0 ? h * 0.55 : -h * 0.45))
      ..lineTo(rect.right, rect.top);
    canvas.drawPath(flap, line);
    _star(canvas, c + Offset(0, -r * (look.tier == 0 ? 0.02 : 0.42)), r * 0.09);
  }

  void _glow(Canvas canvas, Offset c, double r, Paint line) {
    canvas.drawCircle(
      c,
      r * 0.2,
      Paint()..color = look.glow.withValues(alpha: 0.95),
    );
    final rays = 6 + look.tier * 3;
    for (var i = 0; i < rays; i++) {
      final a = i / rays * 2 * math.pi - math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * r * 0.3, c + d * r * 0.5, line);
    }
  }

  void _ripples(Canvas canvas, Offset c, double r, Paint line) {
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        c,
        r * (0.14 + i * 0.15),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04
          ..color = look.glow.withValues(alpha: 0.95 - i * 0.25),
      );
    }
  }

  void _lantern(Canvas canvas, Offset c, double r, Paint line) {
    final body = Path()
      ..moveTo(c.dx - r * 0.2, c.dy - r * 0.22)
      ..quadraticBezierTo(
        c.dx - r * 0.34,
        c.dy + r * 0.05,
        c.dx - r * 0.16,
        c.dy + r * 0.3,
      )
      ..lineTo(c.dx + r * 0.16, c.dy + r * 0.3)
      ..quadraticBezierTo(
        c.dx + r * 0.34,
        c.dy + r * 0.05,
        c.dx + r * 0.2,
        c.dy - r * 0.22,
      )
      ..close();
    canvas.drawPath(body, Paint()..color = look.glow.withValues(alpha: 0.35));
    canvas.drawPath(body, line);
    canvas.drawLine(c + Offset(0, -r * 0.22), c + Offset(0, -r * 0.36), line);
    canvas.drawCircle(
      c + Offset(0, r * 0.04),
      r * 0.07,
      Paint()..color = look.glow,
    );
    for (var i = 0; i < look.tier; i++) {
      _star(
        canvas,
        c + Offset(r * (0.34 + i * 0.08), -r * (0.3 - i * 0.14)),
        r * 0.05,
      );
    }
  }

  void _sanctuary(Canvas canvas, Offset c, double r, Paint line) {
    // A still orb above calm water lines.
    canvas.drawCircle(
      c + Offset(0, -r * 0.1),
      r * 0.16,
      Paint()..color = look.glow.withValues(alpha: 0.9),
    );
    for (var i = 0; i <= look.tier; i++) {
      final y = c.dy + r * (0.18 + i * 0.1);
      final half = r * (0.34 - i * 0.07);
      canvas.drawLine(Offset(c.dx - half, y), Offset(c.dx + half, y), line);
    }
  }

  void _star(Canvas canvas, Offset p, double s) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * 2 * math.pi - math.pi / 2;
      final rr = i.isEven ? s : s * 0.4;
      final q = p + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = look.glow);
  }

  @override
  bool shouldRepaint(KeepsakeSealPainter old) => old.look != look;
}
