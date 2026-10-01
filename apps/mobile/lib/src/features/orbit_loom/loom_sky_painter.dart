import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'loom_shape.dart';

/// The Orbit Loom sky: a quiet night, the lines, then the stars. Every star
/// looks the same (no colour carries meaning); the chosen one gets a ring, a
/// shape difference rather than a colour one. Nothing is animated.
class LoomSkyPainter extends CustomPainter {
  const LoomSkyPainter({
    required this.shape,
    this.chosen,
    this.dragFrom,
    this.dragTo,
    this.thumbnail = false,
  });

  final LoomShape shape;
  final int? chosen;

  /// Drag mode: the line being drawn from a star to the finger.
  final int? dragFrom;
  final LoomStar? dragTo;

  /// A small kept constellation: no background dust, thinner marks.
  final bool thumbnail;

  static const Color _star = Color(0xFFFFE6AC);
  static const Color _line = Color(0xFFE9D8B4);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E2240), Color(0xFF3A3560)],
        ).createShader(rect),
    );
    Offset at(LoomStar s) => Offset(s.x * size.width, s.y * size.height);
    final scale = size.shortestSide / 320;
    if (!thumbnail) {
      // Fixed, faint dust: the same sky every time.
      final dust = Paint()..color = const Color(0x55E7DFCD);
      for (var i = 0; i < 40; i++) {
        final x = ((i * 73 + 19) % 101) / 101 * size.width;
        final y = ((i * 37 + 7) % 89) / 89 * size.height;
        canvas.drawCircle(Offset(x, y), i % 5 == 0 ? 1.2 : 0.6, dust);
      }
    }
    final line = Paint()
      ..color = _line.withValues(alpha: 0.75)
      ..strokeWidth = math.max(1, (thumbnail ? 1.2 : 2.2) * scale)
      ..strokeCap = StrokeCap.round;
    for (final l in shape.links) {
      if (l.a >= shape.stars.length || l.b >= shape.stars.length) continue;
      canvas.drawLine(at(shape.stars[l.a]), at(shape.stars[l.b]), line);
    }
    final from = dragFrom;
    final to = dragTo;
    if (from != null && to != null && from < shape.stars.length) {
      canvas.drawLine(
        at(shape.stars[from]),
        at(to),
        Paint()
          ..color = _line.withValues(alpha: 0.4)
          ..strokeWidth = 2 * scale
          ..strokeCap = StrokeCap.round,
      );
    }
    final glow = Paint()..color = _star.withValues(alpha: 0.18);
    final core = Paint()..color = _star;
    for (var i = 0; i < shape.stars.length; i++) {
      final p = at(shape.stars[i]);
      final r = (thumbnail ? 3.0 : 7.0) * scale;
      canvas.drawCircle(p, r * 2.2, glow);
      canvas.drawCircle(p, r, core);
      if (i == chosen) {
        canvas.drawCircle(
          p,
          r * 2.6,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * scale
            ..color = Colors.white.withValues(alpha: 0.9),
        );
      }
    }
  }

  @override
  bool shouldRepaint(LoomSkyPainter old) =>
      old.shape != shape ||
      old.chosen != chosen ||
      old.dragFrom != dragFrom ||
      old.dragTo != dragTo ||
      old.thumbnail != thumbnail;
}
