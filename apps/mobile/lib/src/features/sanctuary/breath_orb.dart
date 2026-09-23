import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/aura_tokens.dart';

/// The breathing orb: the person's Aura as a soft ball of light in their own
/// hue (the avatar's glow aesthetic: a halo, a starlit core and the 4-point
/// star the avatar carries on its heart). It grows as [fill] rises (breathing
/// in) and softens as it falls (breathing out).
///
/// Decorative: hidden from screen readers (the phase words carry the
/// rhythm). With [still] it never changes size (Reduce Motion, REQ-SAN-03).
class BreathOrb extends StatelessWidget {
  const BreathOrb({
    super.key,
    required this.hue,
    this.fill,
    this.size = 260,
    this.still = false,
  });

  /// Avatar hue, 0–360°.
  final double hue;

  /// 0–1 breath fill; `null` (or [still]) = a calm resting size.
  final ValueListenable<double>? fill;
  final double size;
  final bool still;

  /// The fill a still orb rests at.
  static const double restingFill = 0.6;

  @override
  Widget build(BuildContext context) {
    final painter = BreathOrbPainter(hue: hue, fill: still ? null : fill);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.square(size), painter: painter),
      ),
    );
  }
}

/// Paints [BreathOrb]. Repaints only when [fill] changes.
class BreathOrbPainter extends CustomPainter {
  BreathOrbPainter({required this.hue, this.fill}) : super(repaint: fill);

  final double hue;
  final ValueListenable<double>? fill;

  /// Smallest and largest radius, as a share of half the box.
  static const double minRadius = 0.5;
  static const double maxRadius = 0.82;

  /// The orb's radius for [fillValue] in a box of [side].
  static double radiusFor(double fillValue, double side) =>
      side /
      2 *
      (minRadius + (maxRadius - minRadius) * fillValue.clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final c = size.center(Offset.zero);
    final f = fill?.value ?? BreathOrb.restingFill;
    final r = radiusFor(f, side);
    final glow = glowColorForHue(hue);
    final light = glowColorForHue(hue, saturation: 0.25);

    // Halo: widest and faintest, a little brighter when full.
    final haloR = math.min(side / 2, r * 1.22);
    canvas.drawCircle(
      c,
      haloR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: 0.30 + 0.12 * f),
            glow.withValues(alpha: 0),
          ],
          stops: const [0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: haloR)),
    );

    // Body: starlit core fading into the hue.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.18, -0.22),
          colors: [
            AuraColors.starlight.withValues(alpha: 0.95),
            light.withValues(alpha: 0.85),
            glow.withValues(alpha: 0.55),
            glow.withValues(alpha: 0.08),
          ],
          stops: const [0, 0.32, 0.72, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // A thin orbit, like the avatar's rings.
    canvas.drawCircle(
      c,
      r * 1.08,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, side * 0.004)
        ..color = light.withValues(alpha: 0.28),
    );

    // The 4-point heart star.
    final s = r * 0.2;
    final star = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s * 0.62, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s * 0.62, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawCircle(
      c,
      s * 1.3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: s * 1.3)),
    );
    canvas.drawPath(star, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(BreathOrbPainter old) =>
      old.hue != hue || old.fill != fill;
}
