import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/aura_tokens.dart';
import '../avatar/aura_avatar_painter.dart' show AvatarTier;
import 'ripple_controller.dart';
import 'ripple_engine.dart';

/// The night ocean (PRD F7 "Visuals: night ocean, one light per seat; better
/// sync, wider ripples, more fish. Minimum ripple and 3 fish always."). All
/// procedural (CustomPainter): no images, no Rive, no shaders to compile.
///
/// Tiers follow the avatar's render system (PRD F2, US-50): High (every
/// wave layer, drifting fish, three ripple rings), Low (fewer layers and
/// fish, one ring, ~30 fps — chosen when frames run over budget), Still
/// (Reduce Motion: one painted frame; lights keep a fixed size and only
/// their glow steps with the phase — no scaling, drift or particles).
class OceanPainter extends CustomPainter {
  OceanPainter({
    required this.lights,
    required this.sync,
    required this.timeMs,
    required this.tier,
    required Listenable repaint,
  }) : super(repaint: repaint);

  /// Read at paint time (they change every frame).
  final List<LightView> Function() lights;
  final double Function() sync;
  final int Function() timeMs;
  final AvatarTier tier;

  static const Color _sea = Color(0xFF071427);
  static const Color _seaDeep = Color(0xFF030814);
  static const Color _humanLight = AuraColors.starlight;
  static const Color _echoLight = Color(0xFF9FB3D9);
  static const Color _guideLight = AuraColors.lavender;

  /// Where each seat's light sits along the water, 0–1 across.
  static double seatX(int index, int count) =>
      count <= 1 ? 0.5 : 0.18 + 0.64 * index / (count - 1);

  /// The horizon's height, 0–1 down.
  static const double horizon = 0.42;

  @override
  void paint(Canvas canvas, Size size) {
    final still = tier == AvatarTier.still;
    final t = still ? 0.0 : timeMs() / 1000.0;
    final s = sync().clamp(0.0, 1.0);
    final w = size.width;
    final h = size.height;
    final horizonY = h * horizon;

    // Sky and sea.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          [AuraColors.skyDeep, AuraColors.sky, _sea, _seaDeep],
          const [0, 0.4, 0.45, 1],
        ),
    );
    // Moon low over the horizon (clear of the header and the status card),
    // with a soft halo.
    final moonX = w * 0.78;
    final moonR = math.min(w, h) * 0.035;
    final moon = Offset(moonX, horizonY - moonR * 2.6);
    canvas.drawCircle(
      moon,
      moonR * 2.4,
      Paint()
        ..color = AuraColors.moonlight.withValues(alpha: 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, moonR),
    );
    canvas.drawCircle(
      moon,
      moonR,
      Paint()..color = AuraColors.moonlight.withValues(alpha: 0.85),
    );
    // Moon path on the water: soft glints that widen toward the viewer and
    // fade with depth (they shimmer sideways unless Still).
    const glints = 14;
    final glintPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    for (var k = 0; k < glints; k++) {
      final f = (k + 1) / glints;
      final y = horizonY + (h - horizonY) * math.pow(f, 1.4) * 0.9;
      final half = w * (0.012 + 0.05 * f);
      final drift = still ? 0.0 : math.sin(t * 0.8 + k * 1.7) * half * 0.25;
      glintPaint.color = AuraColors.moonlight.withValues(
        alpha: 0.22 * (1 - f * 0.8),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(moonX + drift, y),
            width: half * 2,
            height: 2 + 3 * f,
          ),
          const Radius.circular(3),
        ),
        glintPaint,
      );
    }

    // Swells: layered sines drifting slowly (fewer on Low, frozen on Still).
    final layers = switch (tier) {
      AvatarTier.high => 5,
      AvatarTier.low => 3,
      AvatarTier.still => 3,
    };
    for (var i = 0; i < layers; i++) {
      final y0 = horizonY + (h - horizonY) * (i + 1) / (layers + 1);
      final amp = 3.0 + i * 2.2;
      final path = Path()..moveTo(0, y0);
      for (var x = 0.0; x <= w; x += 12) {
        path.lineTo(
          x,
          y0 + amp * math.sin(x / (60 + i * 25) + t * (0.3 + i * 0.07) + i),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AuraColors.moonlight.withValues(alpha: 0.06 + 0.02 * i),
      );
    }

    final views = lights();
    final lightY = horizonY + (h - horizonY) * 0.42;
    final base = math.min(w, h);

    // Fish: 3 + round(12 × S), bioluminescent dots (no flashing: slow drift).
    final fish = fishCount(s);
    final fishLimit = tier == AvatarTier.high ? fish : math.min(fish, 8);
    for (var i = 0; i < fishLimit; i++) {
      final seed = i * 97.0;
      final fx =
          (w * ((seed % 100) / 100) + t * (8 + i % 5) * (i.isEven ? 1 : -1)) %
          w;
      final fy = horizonY + 24 + ((seed * 3) % (h - horizonY - 48));
      canvas.drawCircle(
        Offset(fx < 0 ? fx + w : fx, fy),
        1.6 + (i % 3) * 0.5,
        Paint()..color = AuraColors.rain.withValues(alpha: 0.55),
      );
    }

    // Ripples around every light: radius from the group's sync, never below
    // the minimum (REQ-GAME-03).
    final ring = rippleRadius(s) * base * 0.16;
    final rings = switch (tier) {
      AvatarTier.high => 3,
      _ => 1,
    };
    for (final (i, v) in views.indexed) {
      final c = Offset(w * seatX(i, views.length), lightY);
      for (var r = 0; r < rings; r++) {
        final phase = still ? 0.0 : ((t * 0.25 + r / rings) % 1.0);
        final radius = ring * (0.55 + 0.45 * (still ? (r + 1) / rings : phase));
        canvas.drawOval(
          Rect.fromCenter(center: c, width: radius * 2, height: radius * 0.7),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = _colorOf(v).withValues(
              alpha:
                  (still ? 0.25 : 0.35 * (1 - phase)) *
                  (v.mode == LightMode.echo ? 0.6 : 1),
            ),
        );
      }
    }

    // The lights themselves: size follows the breath (fixed under Still).
    for (final (i, v) in views.indexed) {
      final c = Offset(w * seatX(i, views.length), lightY);
      final breath = still ? 0.6 : v.fill;
      final core = base * (0.022 + 0.018 * breath);
      final paleness = switch (v.mode) {
        LightMode.live => 1.0,
        LightMode.quiet => 0.8,
        LightMode.guide => 0.7,
        LightMode.echo => 0.5, // "paler labelled light"
      };
      final color = _colorOf(v);
      final glowAlpha = still
          ? (v.fill > 0.5 ? 0.55 : 0.35)
          : 0.25 + 0.4 * breath;
      canvas.drawCircle(
        c,
        core * 3.2,
        Paint()
          ..color = color.withValues(alpha: glowAlpha * paleness)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(
        c,
        core,
        Paint()..color = color.withValues(alpha: paleness),
      );
      if (v.me) {
        canvas.drawCircle(
          c,
          core * 1.8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AuraColors.text.withValues(alpha: 0.7),
        );
      }
      // A received pulse: a ring that opens once (the visual fallback when
      // haptics are off). Under Still it is a steady ring for a moment.
      final age = v.pulseAge;
      if (age != null) {
        final p = still ? 0.5 : age / 1500;
        canvas.drawCircle(
          c,
          core * (2 + 4 * p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: 0.8 * (1 - p)),
        );
      }
    }
  }

  static Color _colorOf(LightView v) => switch (v.mode) {
    LightMode.echo => _echoLight,
    LightMode.guide => _guideLight,
    _ => _humanLight,
  };

  @override
  bool shouldRepaint(OceanPainter old) => old.tier != tier;
}
