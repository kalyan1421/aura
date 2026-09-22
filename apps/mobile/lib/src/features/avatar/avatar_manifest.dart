import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A point on a ring path in normalized image space (0–1) with depth:
/// `z > 0` passes in front of the body, `z < 0` behind it.
@immutable
class RingPoint {
  const RingPoint(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

/// One orbit ring. Baked rings are painted into the base art (only the orbs
/// are procedural); non-baked rings are drawn in code as well.
@immutable
class RingSpec {
  RingSpec({
    required this.id,
    required this.baked,
    required this.color,
    required this.glow,
    required this.period,
    required List<RingPoint> samples,
  }) : samples = List.unmodifiable(samples);

  final String id;
  final bool baked;
  final Color color;
  final Color glow;

  /// Seconds per orbit.
  final double period;

  /// Evenly spaced (by arc length) closed-loop samples.
  final List<RingPoint> samples;

  /// Position at loop fraction [u] (0–1), linearly interpolated.
  RingPoint at(double u) {
    final n = samples.length;
    final f = (u % 1.0) * n;
    final i = f.floor() % n;
    final j = (i + 1) % n;
    final k = f - f.floorToDouble();
    final a = samples[i];
    final b = samples[j];
    return RingPoint(
      a.x + (b.x - a.x) * k,
      a.y + (b.y - a.y) * k,
      a.z + (b.z - a.z) * k,
    );
  }
}

@immutable
class ArcSpec {
  const ArcSpec({
    required this.center,
    required this.radii,
    required this.fromDeg,
    required this.toDeg,
  });

  final Offset center;
  final Offset radii;
  final double fromDeg;
  final double toDeg;

  /// Normalized position of slot [i] of [count] along the arc.
  Offset slot(int i, int count) {
    final t = count <= 1 ? 0.5 : i / (count - 1);
    final a = (fromDeg + (toDeg - fromDeg) * t) * math.pi / 180;
    return Offset(
      center.dx + radii.dx * math.cos(a),
      center.dy + radii.dy * math.sin(a),
    );
  }
}

/// `assets/avatar/manifest.json`: where the procedural layers attach to the
/// base art. A new base (clean, ring-less, other body forms) only needs a new
/// manifest.
@immutable
class AvatarManifest {
  const AvatarManifest({
    required this.base,
    required this.fallbackBase,
    required this.imageSize,
    required this.bakedRings,
    required this.brow,
    required this.heart,
    required this.center,
    required this.rings,
    required this.constellationArc,
  });

  static const String path = 'assets/avatar/manifest.json';
  static const String assetDir = 'assets/avatar/';

  final String base;
  final String? fallbackBase;
  final Size imageSize;
  final int bakedRings;
  final Offset brow;
  final Offset heart;
  final Offset center;
  final List<RingSpec> rings;
  final ArcSpec constellationArc;

  double get aspect => imageSize.width / imageSize.height;

  static Future<AvatarManifest> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString(path);
    return AvatarManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory AvatarManifest.fromJson(Map<String, dynamic> j) {
    Offset off(Object? v) {
      final l = (v! as List<dynamic>).cast<num>();
      return Offset(l[0].toDouble(), l[1].toDouble());
    }

    final size = off(j['size']);
    final imageSize = Size(size.dx, size.dy);
    final anchors = j['anchors'] as Map<String, dynamic>;
    final arc = j['constellationArc'] as Map<String, dynamic>;
    return AvatarManifest(
      base: j['base'] as String,
      fallbackBase: j['fallbackBase'] as String?,
      imageSize: imageSize,
      bakedRings: (j['bakedRings'] as num?)?.toInt() ?? 0,
      brow: off(anchors['brow']),
      heart: off(anchors['heart']),
      center: off(anchors['center']),
      rings: [
        for (final r in (j['rings'] as List<dynamic>).cast<Map<String, dynamic>>())
          _ring(r, imageSize),
      ],
      constellationArc: ArcSpec(
        center: off(arc['center']),
        radii: off(arc['radii']),
        fromDeg: (arc['fromDeg'] as num).toDouble(),
        toDeg: (arc['toDeg'] as num).toDouble(),
      ),
    );
  }

  static RingSpec _ring(Map<String, dynamic> r, Size imageSize) {
    final List<RingPoint> control;
    if (r['path'] != null) {
      control = [
        for (final p in (r['path'] as List<dynamic>).cast<List<dynamic>>())
          RingPoint(
            (p[0] as num).toDouble(),
            (p[1] as num).toDouble(),
            p.length > 2 ? (p[2] as num).toDouble() : 0,
          ),
      ];
    } else {
      final e = r['ellipse'] as Map<String, dynamic>;
      final c = (e['center'] as List<dynamic>).cast<num>();
      final rad = (e['radii'] as List<dynamic>).cast<num>();
      final rot = (e['rotationDeg'] as num).toDouble() * math.pi / 180;
      control = [
        for (var i = 0; i < 48; i++)
          () {
            final s = 2 * math.pi * i / 48;
            // Measured in pixels so the tilt is not skewed by the aspect.
            final ex = rad[0] * imageSize.width * math.cos(s);
            final ey = rad[1] * imageSize.height * math.sin(s);
            final x = ex * math.cos(rot) - ey * math.sin(rot);
            final y = ex * math.sin(rot) + ey * math.cos(rot);
            // Lower half of the loop is nearer the viewer.
            return RingPoint(
              c[0] + x / imageSize.width,
              c[1] + y / imageSize.height,
              math.sin(s),
            );
          }(),
      ];
    }
    return RingSpec(
      id: r['id'] as String,
      baked: r['baked'] as bool? ?? false,
      color: _hex(r['color'] as String?, const Color(0xFFFFE9B8)),
      glow: _hex(r['glow'] as String?, const Color(0xFFB9CCFF)),
      period: (r['periodSec'] as num?)?.toDouble() ?? 20,
      samples: _resample(_catmullRom(control), imageSize, 240),
    );
  }

  static Color _hex(String? s, Color fallback) {
    if (s == null) return fallback;
    final v = int.tryParse(s.replaceFirst('#', ''), radix: 16);
    if (v == null) return fallback;
    return Color(s.length <= 7 ? 0xFF000000 | v : v);
  }

  /// Closed Catmull-Rom through the control points.
  static List<RingPoint> _catmullRom(List<RingPoint> p, {int steps = 16}) {
    final n = p.length;
    final out = <RingPoint>[];
    for (var i = 0; i < n; i++) {
      final p0 = p[(i - 1 + n) % n];
      final p1 = p[i];
      final p2 = p[(i + 1) % n];
      final p3 = p[(i + 2) % n];
      for (var s = 0; s < steps; s++) {
        final t = s / steps;
        double cr(double a, double b, double c, double d) =>
            0.5 *
            ((2 * b) +
                (-a + c) * t +
                (2 * a - 5 * b + 4 * c - d) * t * t +
                (-a + 3 * b - 3 * c + d) * t * t * t);
        out.add(
          RingPoint(
            cr(p0.x, p1.x, p2.x, p3.x),
            cr(p0.y, p1.y, p2.y, p3.y),
            (p1.z + (p2.z - p1.z) * t).clamp(-1.0, 1.0),
          ),
        );
      }
    }
    return out;
  }

  /// Resamples a closed polyline into [count] points evenly spaced by arc
  /// length in pixel space, so orbs move at a steady speed.
  static List<RingPoint> _resample(List<RingPoint> pts, Size img, int count) {
    final n = pts.length;
    final cum = <double>[0];
    for (var i = 0; i < n; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % n];
      final dx = (b.x - a.x) * img.width;
      final dy = (b.y - a.y) * img.height;
      cum.add(cum.last + math.sqrt(dx * dx + dy * dy));
    }
    final total = cum.last;
    final out = <RingPoint>[];
    var seg = 0;
    for (var k = 0; k < count; k++) {
      final target = total * k / count;
      while (seg < n - 1 && cum[seg + 1] < target) {
        seg++;
      }
      final a = pts[seg];
      final b = pts[(seg + 1) % n];
      final len = cum[seg + 1] - cum[seg];
      final t = len == 0 ? 0.0 : (target - cum[seg]) / len;
      out.add(
        RingPoint(
          a.x + (b.x - a.x) * t,
          a.y + (b.y - a.y) * t,
          a.z + (b.z - a.z) * t,
        ),
      );
    }
    return out;
  }
}
