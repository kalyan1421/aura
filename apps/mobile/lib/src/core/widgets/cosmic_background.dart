import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/aura_tokens.dart';

/// The night sky behind every screen: a deep gradient, two faint nebula
/// washes and a sparse, static starfield. Stars are dim and small so text
/// always sits on a calm ground (REQ-A11Y-03).
class CosmicBackground extends StatelessWidget {
  const CosmicBackground({super.key, required this.child, this.tint});

  final Widget child;

  /// Optional accent wash (e.g. the avatar hue or a quadrant colour).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D1030), AuraColors.sky, AuraColors.skyDeep],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _SkyPainter(tint ?? AuraColors.lavender),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.tint);

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    void wash(Offset c, double r, Color color, double a) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: a),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    wash(
      Offset(size.width * 0.15, size.height * 0.12),
      size.width * 0.7,
      tint,
      0.10,
    );
    wash(
      Offset(size.width * 0.95, size.height * 0.55),
      size.width * 0.8,
      const Color(0xFF3B6FB6),
      0.08,
    );

    final star = Paint();
    const n = 70;
    for (var i = 0; i < n; i++) {
      final x = _r(i, 1) * size.width;
      final y = _r(i, 2) * size.height;
      final big = _r(i, 3) > 0.92;
      star.color = Colors.white.withValues(alpha: 0.10 + 0.22 * _r(i, 4));
      canvas.drawCircle(Offset(x, y), big ? 1.3 : 0.7, star);
    }
  }

  static double _r(int i, int s) {
    final v = math.sin(i * 91.7 + s * 47.3) * 24634.6345;
    return v - v.floorToDouble();
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.tint != tint;
}
