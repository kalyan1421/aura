import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'avatar_assets.dart';
import 'avatar_manifest.dart';

/// Render quality (PRD F2). Still = one painted frame (Reduce Motion, share
/// cards, widget snapshots); a slow glow only under Reduce Motion.
enum AvatarTier { high, low, still }

/// Per-stage "presence": stages change how the same character carries light,
/// never who the character is.
@immutable
class _StageLook {
  const _StageLook({
    required this.scale,
    required this.brightness,
    required this.glow,
    required this.halo,
    required this.particles,
    required this.warmth,
  });

  final double scale;
  final double brightness;
  final double glow;
  final double halo;
  final int particles;

  /// 0..1 shift of the glow towards ember amber.
  final double warmth;

  static const Map<AuraStage, _StageLook> all = {
    AuraStage.spark: _StageLook(
      scale: 0.70,
      brightness: 0.80,
      glow: 0.40,
      halo: 0,
      particles: 6,
      warmth: 0,
    ),
    AuraStage.ember: _StageLook(
      scale: 0.84,
      brightness: 0.90,
      glow: 0.58,
      halo: 0,
      particles: 10,
      warmth: 0.45,
    ),
    AuraStage.glow: _StageLook(
      scale: 1.0,
      brightness: 1.0,
      glow: 0.72,
      halo: 0.22,
      particles: 16,
      warmth: 0.1,
    ),
    AuraStage.radiance: _StageLook(
      scale: 1.0,
      brightness: 1.04,
      glow: 0.92,
      halo: 0.9,
      particles: 28,
      warmth: 0.1,
    ),
    AuraStage.constellation: _StageLook(
      scale: 1.0,
      brightness: 1.06,
      glow: 0.96,
      halo: 1.0,
      particles: 32,
      warmth: 0.1,
    ),
  };
}

/// Maps normalized image coordinates to canvas coordinates, including the
/// stage scale and the breathing float, so every layer stays locked to the
/// art's anchors.
@immutable
class _Geo {
  const _Geo({
    required this.anchor,
    required this.centerN,
    required this.baseW,
    required this.baseH,
    required this.scale,
    required this.dy,
  });

  final Offset anchor;
  final Offset centerN;
  final double baseW;
  final double baseH;
  final double scale;
  final double dy;

  Offset map(Offset n) =>
      anchor +
      Offset(
        (n.dx - centerN.dx) * baseW * scale,
        (n.dy - centerN.dy) * baseH * scale + dy,
      );

  Offset mapXY(double x, double y) => map(Offset(x, y));

  /// A size unit that scales with the character.
  double get unit => baseW * scale;

  Rect get imageRect => Rect.fromPoints(map(Offset.zero), map(const Offset(1, 1)));
}

/// Draws the hybrid avatar: character art as the base + procedural light.
///
/// Pure function of ([state], [time]) and the loaded [assets]. Layers, back
/// to front: (a) shader aura glow, (b) Resting Nebula, orbs/ring arcs behind
/// the body, (c) the breathing base character with a subtle hue tint,
/// (d) brow/heart glints, (e) orbs/ring arcs in front, (f) sparkles and
/// particles, (g) the constellation arc.
class AuraAvatarPainter extends CustomPainter {
  AuraAvatarPainter({
    required this.state,
    required this.time,
    required this.assets,
    this.tier = AvatarTier.high,
    this.useShaders = true,
    this.evolve = 1,
    this.wake = 1,
    this.seed = 0.37,
  }) : super(repaint: time);

  final AuraAvatarState state;

  /// Elapsed seconds.
  final ValueListenable<double> time;
  final AvatarAssets? assets;
  final AvatarTier tier;
  final bool useShaders;

  /// Evolve moment progress (1 = none/finished).
  final double evolve;

  /// Wake-up moment progress (1 = none/finished).
  final double wake;
  final double seed;

  static const double breathPeriod = 6;
  static const double restingBreathPeriod = 9;

  /// Hue tint strength on the character (≤ 25% so it stays recognisable).
  static const double tintStrength = 0.18;

  /// Set when the last paint fell back (for tests/diagnostics).
  static String? lastFallback;

  @override
  void paint(Canvas canvas, Size size) {
    final save = canvas.getSaveCount();
    try {
      _paintAll(canvas, size, time.value);
      lastFallback = null;
    } catch (e) {
      // Painter threw → plain base image; never blank (REQ-AVA-07).
      canvas.restoreToCount(save);
      lastFallback = 'painter:${e.runtimeType}';
      _paintPlain(canvas, size);
    }
  }

  // ---- composition ---------------------------------------------------------

  void _paintAll(Canvas canvas, Size size, double t) {
    final m = assets?.manifest;
    final look = _StageLook.all[state.stage]!;
    final hueColor = _hueColor(state.hue);
    final warm = Color.lerp(hueColor, const Color(0xFFFFB25E), look.warmth)!;
    final core = Color.lerp(warm, Colors.white, 0.55)!;

    final restingMix = state.isResting ? 1.0 : (1 - wake).clamp(0.0, 1.0);
    final period = restingMix > 0.5 ? restingBreathPeriod : breathPeriod;
    final breath = tier == AvatarTier.still
        ? 0.0
        : math.sin(2 * math.pi * t / period);

    final geo = _layout(size, m, look.scale, breath);
    final glowBoost = 0.12 * state.glowLevel;
    final evolveFlash = evolve < 1 ? (1 - evolve) : 0.0;

    // (a) Aura glow.
    final glowCenter = geo.mapXY(0.5, 0.56);
    // The glow always fades out inside the canvas (the shader squashes y by
    // 0.82, so vertical room is scaled accordingly).
    final roomX = math.min(glowCenter.dx, size.width - glowCenter.dx);
    final roomY = math.min(glowCenter.dy, size.height - glowCenter.dy) * 0.82;
    final glowRadius = math.min(
      geo.baseH * geo.scale * (0.66 + 0.05 * state.glowLevel),
      math.min(roomX, roomY) * 1.02,
    );
    final intensity =
        (look.glow + glowBoost) * (1 - 0.3 * restingMix) + 0.35 * evolveFlash;
    _glow(
      canvas,
      size,
      glowCenter,
      glowRadius,
      t,
      warm,
      core,
      intensity,
      look.halo,
    );

    // (b) Resting Nebula (behind).
    if (restingMix > 0.001) {
      _nebula(canvas, size, geo, t, hueColor, restingMix, front: false);
    }

    if (m != null) {
      // Orbs and ring arcs behind the body.
      _rings(canvas, geo, m, t, front: false);
    }

    // (c) The character.
    final brightness =
        look.brightness * (1 - 0.25 * restingMix) * (1 + 0.3 * evolveFlash);
    _base(canvas, size, geo, brightness);

    if (restingMix > 0.001) {
      _nebula(canvas, size, geo, t, hueColor, restingMix, front: true);
    }

    if (m != null) {
      // (d) Glints on the brow and heart stars.
      _glint(canvas, geo.map(m.brow), geo.unit * 0.05, t, 0, hueColor);
      _glint(
        canvas,
        geo.map(m.heart),
        geo.unit * (0.055 + 0.008 * state.glowLevel),
        t,
        1.7,
        hueColor,
      );
      // (e) Orbs and ring arcs in front.
      _rings(canvas, geo, m, t, front: true);
    }

    // (f) Sparkles and particles.
    _particles(canvas, geo, t, look, hueColor, restingMix);

    // (g) Constellation arc.
    if (m != null &&
        (state.stage == AuraStage.constellation ||
            state.constellationStars > 0)) {
      _constellation(canvas, geo, m, t);
    }

    if (evolve < 1) _evolveRing(canvas, glowCenter, geo, evolve, hueColor);
  }

  _Geo _layout(Size size, AvatarManifest? m, double stageScale, double breath) {
    final aspect = m?.aspect ?? (1145 / 1374);
    final baseH = math.min(size.height * 0.80, size.width * 0.9 / aspect);
    final baseW = baseH * aspect;
    return _Geo(
      anchor: Offset(size.width / 2, size.height * 0.56),
      centerN: m?.center ?? const Offset(0.508, 0.53),
      baseW: baseW,
      baseH: baseH,
      scale: stageScale * (1 + 0.02 * breath),
      dy: -0.012 * size.height * breath,
    );
  }

  // ---- (a) glow ------------------------------------------------------------

  void _glow(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    double t,
    Color color,
    Color core,
    double intensity,
    double halo,
  ) {
    final program = useShaders ? assets?.glowProgram : null;
    if (program != null) {
      try {
        final s = program.fragmentShader()
          ..setFloat(0, size.width)
          ..setFloat(1, size.height)
          ..setFloat(2, center.dx)
          ..setFloat(3, center.dy)
          ..setFloat(4, radius)
          ..setFloat(5, t)
          ..setFloat(6, color.r)
          ..setFloat(7, color.g)
          ..setFloat(8, color.b)
          ..setFloat(9, core.r)
          ..setFloat(10, core.g)
          ..setFloat(11, core.b)
          ..setFloat(12, intensity.clamp(0.0, 1.4))
          ..setFloat(13, halo)
          ..setFloat(14, seed * 10);
        canvas.drawRect(Offset.zero & size, Paint()..shader = s);
        s.dispose();
        return;
      } catch (e) {
        lastFallback = 'glowShader:${e.runtimeType}';
      }
    }
    // Painter-only glow: layered radial gradients + a soft halo.
    final pulse = tier == AvatarTier.still
        ? 1.0
        : 0.92 + 0.08 * math.sin(t * 1.0472);
    final a = (intensity * pulse).clamp(0.0, 1.0);
    canvas.drawCircle(
      center,
      radius * 1.25,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius * 1.25,
          [
            core.withValues(alpha: 0.85 * a),
            color.withValues(alpha: 0.45 * a),
            color.withValues(alpha: 0),
          ],
          const [0, 0.38, 1],
        ),
    );
    if (halo > 0) {
      canvas.drawCircle(
        center,
        radius * 0.86,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.1
          ..color = Color.lerp(color, Colors.white, 0.35)!
              .withValues(alpha: 0.35 * halo * a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.06),
      );
    }
  }

  // ---- (b) nebula ----------------------------------------------------------

  void _nebula(
    Canvas canvas,
    Size size,
    _Geo geo,
    double t,
    Color hue,
    double mix, {
    required bool front,
  }) {
    final center = geo.mapXY(0.5, 0.80);
    final radii = Offset(geo.baseW * geo.scale * 0.66, geo.baseH * geo.scale * 0.27);
    // Soft, luminous clouds in the avatar's own hue — never grey or dim.
    final deep = Color.lerp(hue, const Color(0xFF8C82E6), 0.5)!;
    final lit = Color.lerp(hue, const Color(0xFFF8EDFF), 0.68)!;
    final alpha = (front ? 0.62 : 0.9) * mix;

    final program = useShaders && tier == AvatarTier.high
        ? assets?.nebulaProgram
        : null;
    if (program != null) {
      try {
        final s = program.fragmentShader()
          ..setFloat(0, size.width)
          ..setFloat(1, size.height)
          ..setFloat(2, center.dx)
          ..setFloat(3, center.dy)
          ..setFloat(4, radii.dx)
          ..setFloat(5, radii.dy)
          ..setFloat(6, t + (front ? 17 : 0))
          ..setFloat(7, deep.r)
          ..setFloat(8, deep.g)
          ..setFloat(9, deep.b)
          ..setFloat(10, lit.r)
          ..setFloat(11, lit.g)
          ..setFloat(12, lit.b)
          ..setFloat(13, alpha)
          ..setFloat(14, front ? 1 : 0);
        final rect = Rect.fromCenter(
          center: center,
          width: radii.dx * 2.2,
          height: radii.dy * 2.4,
        ).intersect(Offset.zero & size);
        canvas.drawRect(rect, Paint()..shader = s);
        s.dispose();
        return;
      } catch (e) {
        lastFallback = 'nebulaShader:${e.runtimeType}';
      }
    }
    // Painter-only nebula: soft drifting cloud puffs.
    final puffs = front ? 5 : 8;
    for (var i = 0; i < puffs; i++) {
      final r1 = _rand(i, front ? 71 : 31);
      final r2 = _rand(i, front ? 73 : 37);
      final drift = tier == AvatarTier.still ? 0.0 : math.sin(t * 0.12 + i) * 0.06;
      final x = center.dx + (r1 - 0.5 + drift) * radii.dx * 1.6;
      final y = center.dy +
          (front ? 0.25 + r2 * 0.45 : r2 - 0.5) * radii.dy * (front ? 1.2 : 1.4);
      final w = radii.dx * (0.55 + 0.4 * r2);
      final h = radii.dy * (0.45 + 0.35 * r1);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: w, height: h),
        Paint()
          ..color = Color.lerp(deep, lit, r1)!.withValues(alpha: alpha * 0.32)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.35),
      );
    }
  }

  // ---- (c) base --------------------------------------------------------------

  void _base(Canvas canvas, Size size, _Geo geo, double brightness) {
    final image = assets?.base;
    if (image == null) {
      _paintOrb(canvas, size, geo, brightness);
      return;
    }
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(
      image,
      src,
      geo.imageRect,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.matrix(
          tintMatrix(_hueColor(state.hue), tintStrength, brightness),
        ),
    );
  }

  /// Luminance-preserving hue tint of [strength] (≤ 0.25) times [brightness].
  @visibleForTesting
  static List<double> tintMatrix(Color tint, double strength, double brightness) {
    final k = strength.clamp(0.0, 0.25);
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final tl = lr * tint.r + lg * tint.g + lb * tint.b;
    final gain = tl <= 0.001 ? 1.0 : 1 / tl;
    final tr = tint.r * gain, tg = tint.g * gain, tb = tint.b * gain;
    final b = brightness;
    return [
      b * ((1 - k) + k * tr * lr), b * (k * tr * lg), b * (k * tr * lb), 0, 0,
      b * (k * tg * lr), b * ((1 - k) + k * tg * lg), b * (k * tg * lb), 0, 0,
      b * (k * tb * lr), b * (k * tb * lg), b * ((1 - k) + k * tb * lb), 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  // ---- (d) glints ------------------------------------------------------------

  void _glint(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    double phase,
    Color hue,
  ) {
    final p = tier == AvatarTier.still
        ? 0.6
        : 0.5 + 0.5 * math.sin(2 * math.pi * t / 3.4 + phase);
    final radius = r * (0.8 + 0.35 * p);
    final tint = Color.lerp(Colors.white, hue, 0.18)!;
    canvas.drawCircle(
      c,
      radius * 1.6,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(c, radius * 1.6, [
          tint.withValues(alpha: 0.55 * p + 0.15),
          tint.withValues(alpha: 0),
        ]),
    );
    canvas.drawPath(
      star4(c, radius),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = Colors.white.withValues(alpha: 0.45 + 0.45 * p),
    );
  }

  // ---- (e) rings & orbs --------------------------------------------------

  void _rings(
    Canvas canvas,
    _Geo geo,
    AvatarManifest m,
    double t, {
    required bool front,
  }) {
    final count = math.min(state.ringCount, m.rings.length);
    for (var i = 0; i < count; i++) {
      final ring = m.rings[i];
      if (!ring.baked) _ringLine(canvas, geo, ring, front: front);
      final phase = _rand(i, 5);
      final u = tier == AvatarTier.still ? phase : t / ring.period + phase;
      final p = ring.at(u);
      if ((p.z >= 0) != front) continue;
      // A short comet trail behind the orb.
      if (tier != AvatarTier.still) {
        for (var k = 6; k >= 1; k--) {
          final q = ring.at(u - k * 0.0045);
          if ((q.z >= 0) != front) continue;
          canvas.drawCircle(
            geo.mapXY(q.x, q.y),
            geo.unit * 0.006 * (1 - k / 8),
            Paint()
              ..blendMode = BlendMode.plus
              ..color = ring.glow.withValues(alpha: 0.28 * (1 - k / 7)),
          );
        }
      }
      _orb(
        canvas,
        geo.mapXY(p.x, p.y),
        geo.unit * 0.021 * (1 + 0.22 * p.z),
        ring.color,
        ring.glow,
        front ? 1.0 : 0.7,
      );
    }
  }

  void _ringLine(Canvas canvas, _Geo geo, RingSpec ring, {required bool front}) {
    final n = ring.samples.length;
    final w = geo.unit * 0.0042;
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 4
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 2.2);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w;
    for (var i = 0; i < n; i++) {
      final a = ring.samples[i];
      final b = ring.samples[(i + 1) % n];
      if ((a.z >= 0) != front) continue;
      final pa = geo.mapXY(a.x, a.y);
      final pb = geo.mapXY(b.x, b.y);
      // Gold ↔ blue along the loop, dimmer where it passes behind.
      final c = Color.lerp(
        ring.color,
        ring.glow,
        0.5 + 0.5 * math.sin(2 * math.pi * i / n),
      )!;
      final depth = front ? 1.0 : 0.55;
      glowPaint.color = c.withValues(alpha: 0.28 * depth);
      line.color = Color.lerp(c, Colors.white, 0.3)!.withValues(alpha: 0.9 * depth);
      canvas
        ..drawLine(pa, pb, glowPaint)
        ..drawLine(pa, pb, line);
    }
  }

  void _orb(
    Canvas canvas,
    Offset p,
    double r,
    Color color,
    Color glow,
    double alpha,
  ) {
    canvas.drawCircle(
      p,
      r * 3.4,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(p, r * 3.4, [
          glow.withValues(alpha: 0.5 * alpha),
          glow.withValues(alpha: 0),
        ]),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          p.translate(-r * 0.25, -r * 0.3),
          r * 1.2,
          [
            Colors.white.withValues(alpha: alpha),
            color.withValues(alpha: 0.95 * alpha),
            glow.withValues(alpha: 0.6 * alpha),
          ],
          const [0, 0.5, 1],
        ),
    );
  }

  // ---- (f) particles -------------------------------------------------------

  void _particles(
    Canvas canvas,
    _Geo geo,
    double t,
    _StageLook look,
    Color hue,
    double restingMix,
  ) {
    var count = look.particles;
    if (tier != AvatarTier.high) count = (count / 3).ceil();
    final center = geo.mapXY(0.5, 0.52);
    final rx = geo.baseW * geo.scale * 0.62;
    final ry = geo.baseH * geo.scale * 0.55;
    final speedScale = restingMix > 0.5 ? 0.5 : 1.0;
    for (var i = 0; i < count; i++) {
      final a = 2 * math.pi * _rand(i, 1);
      final rr = 0.45 + 0.55 * _rand(i, 2);
      final range = ry * 0.5;
      final rise = tier == AvatarTier.still
          ? range * _rand(i, 3)
          : (t * ry * 0.02 * (0.6 + _rand(i, 4)) * speedScale +
                    range * _rand(i, 3)) %
                range;
      final life = math.sin(math.pi * rise / range); // fade in/out
      final pos = center +
          Offset(math.cos(a) * rx * rr, math.sin(a) * ry * rr - rise + range / 2);
      // Twinkle ≤ 0.4 Hz: never flashes (REQ-A11Y-09).
      final tw = tier == AvatarTier.still
          ? 0.7
          : 0.35 + 0.65 * math.pow(
              0.5 + 0.5 * math.sin(t * (0.5 + 2.0 * _rand(i, 6)) + 6.28 * _rand(i, 7)),
              2,
            );
      final alpha = (life * tw).clamp(0.0, 1.0) * 0.9;
      final pick = _rand(i, 8);
      final color = pick < 0.4
          ? Colors.white
          : pick < 0.7
          ? const Color(0xFFF7E6B5)
          : Color.lerp(hue, Colors.white, 0.35)!;
      final size = geo.unit * (0.004 + 0.007 * _rand(i, 9));
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..color = color.withValues(alpha: alpha);
      if (i % 4 == 0) {
        canvas.drawPath(star4(pos, size * 2.6), paint);
      } else {
        canvas.drawCircle(pos, size, paint);
      }
    }
  }

  // ---- (g) constellation -------------------------------------------------

  void _constellation(Canvas canvas, _Geo geo, AvatarManifest m, double t) {
    const slots = 12;
    final lit = state.constellationStars;
    final pts = [
      for (var i = 0; i < slots; i++) geo.map(m.constellationArc.slot(i, slots)),
    ];
    final showSlots = state.stage == AuraStage.constellation;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, geo.unit * 0.0025)
      ..color = const Color(0xFFE9E4FF).withValues(alpha: 0.35);
    for (var i = 0; i + 1 < lit; i++) {
      canvas.drawLine(pts[i], pts[i + 1], line);
    }
    for (var i = 0; i < slots; i++) {
      final on = i < lit;
      if (!on && !showSlots) continue;
      final p = pts[i];
      if (!on) {
        canvas.drawCircle(
          p,
          geo.unit * 0.004,
          Paint()..color = Colors.white.withValues(alpha: 0.18),
        );
        continue;
      }
      final tw = tier == AvatarTier.still
          ? 0.8
          : 0.7 + 0.3 * math.sin(t * 0.8 + i * 1.3);
      final r = geo.unit * (0.018 + 0.004 * _rand(i, 11));
      canvas.drawCircle(
        p,
        r * 2.4,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(p, r * 2.4, [
            const Color(0xFFF7E6B5).withValues(alpha: 0.5 * tw),
            const Color(0x00F7E6B5),
          ]),
      );
      canvas.drawPath(
        star4(p, r),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Colors.white.withValues(alpha: 0.9 * tw),
      );
    }
  }

  // ---- moments -------------------------------------------------------------

  void _evolveRing(Canvas canvas, Offset c, _Geo geo, double p, Color hue) {
    final e = Curves.easeOutCubic.transform(p);
    final r = geo.unit * (0.15 + 0.85 * e);
    final fade = math.pow(1 - p, 1.4).toDouble();
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geo.unit * 0.03 * fade + 1
        ..color = Color.lerp(Colors.white, hue, e)!.withValues(alpha: 0.7 * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, geo.unit * 0.02),
    );
  }

  // ---- fallbacks -----------------------------------------------------------

  void _paintPlain(Canvas canvas, Size size) {
    try {
      final geo = _layout(size, assets?.manifest, 1, 0);
      _base(canvas, size, geo, 1);
    } catch (_) {
      _paintOrb(canvas, size, _layout(size, null, 1, 0), 1);
    }
  }

  /// Last resort when the base art is unavailable: a painted orb, so the
  /// avatar slot is never empty.
  void _paintOrb(Canvas canvas, Size size, _Geo geo, double brightness) {
    final c = geo.mapXY(0.5, 0.52);
    final r = geo.baseH * geo.scale * 0.2;
    final hue = _hueColor(state.hue);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(c, r, [
          Colors.white.withValues(alpha: 0.95 * brightness.clamp(0, 1)),
          Color.lerp(hue, Colors.white, 0.3)!.withValues(alpha: 0.8),
          hue.withValues(alpha: 0),
        ], const [0, 0.35, 1]),
    );
  }

  // ---- helpers ---------------------------------------------------------------

  static Color _hueColor(double hue) =>
      HSVColor.fromAHSV(1, hue % 360, 0.55, 1).toColor();

  /// Deterministic pseudo-random in [0, 1).
  static double _rand(int i, int salt) {
    final v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// A 4-point star (the art's sparkle motif).
  static Path star4(Offset c, double r, {double thin = 0.16}) => Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx + r * thin, c.dy - r * thin, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + r * thin, c.dy + r * thin, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - r * thin, c.dy + r * thin, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - r * thin, c.dy - r * thin, c.dx, c.dy - r)
    ..close();

  @override
  bool shouldRepaint(AuraAvatarPainter old) =>
      old.state != state ||
      old.assets != assets ||
      old.tier != tier ||
      old.useShaders != useShaders ||
      old.evolve != evolve ||
      old.wake != wake ||
      old.time != time;
}
