import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'universe_scene.dart';

/// Replaceable renderer boundary: only geometry, camera and a companion
/// position cross it. Care tools and personal records stay in Flutter UI.
class UniverseSceneView extends StatelessWidget {
  const UniverseSceneView({
    super.key,
    required this.mesh,
    required this.camera,
    required this.companion,
    required this.selected,
    required this.onOrbit,
    required this.onSelect,
  });
  final IslandMesh mesh;
  final UniverseCamera camera;
  final WorldPoint companion;
  final UniverseDestination? selected;
  final void Function(double horizontal, double vertical) onOrbit;
  final ValueChanged<UniverseDestination> onSelect;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: LayoutBuilder(
        builder: (context, box) => ExcludeSemantics(
          // The labelled destination buttons below provide equivalent access.
          child: GestureDetector(
            key: const ValueKey('universe-scene'),
            behavior: HitTestBehavior.opaque,
            // Horizontal orbit coexists with vertical page scrolling.
            onHorizontalDragUpdate: (d) => onOrbit(-d.delta.dx * 0.009, 0),
            onTapUp: (d) {
              final destination = camera.pick(d.localPosition, box.biggest);
              if (destination != null) onSelect(destination);
            },
            child: CustomPaint(
              size: box.biggest,
              painter: _IslandPainter(mesh, camera, companion, selected),
            ),
          ),
        ),
      ),
    ),
  );
}

class _IslandPainter extends CustomPainter {
  _IslandPainter(this.mesh, this.camera, this.companion, this.selected);
  final IslandMesh mesh;
  final UniverseCamera camera;
  final WorldPoint companion;
  final UniverseDestination? selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF282D47), Color(0xFF4B4B67)],
        ).createShader(Offset.zero & size),
    );
    final starPaint = Paint()
      ..color = const Color(0xFFE7DFCD).withValues(alpha: 0.5);
    for (var i = 0; i < 28; i++) {
      final x = ((i * 73 + 19) % 101) / 101 * size.width;
      final y = ((i * 37 + 7) % 89) / 89 * size.height;
      canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 1.4 : 0.7, starPaint);
    }
    final projectPoint = camera.projector(size);
    final eye = camera.eye;
    void drawFaces(List<WorldFace> faces) {
      final visible =
          faces
              .map(
                (face) => (
                  face: face,
                  a: projectPoint(face.a),
                  b: projectPoint(face.b),
                  c: projectPoint(face.c),
                  depth: projectPoint(face.center)?.depth ?? -1,
                ),
              )
              .where(
                (f) =>
                    f.a != null &&
                    f.b != null &&
                    f.c != null &&
                    f.face.normal.dot(eye - f.face.center) > 0,
              )
              .toList()
            ..sort((a, b) => b.depth.compareTo(a.depth));
      final light = const WorldPoint(-0.5, 1, 0.6).unit;
      final paint = Paint()..isAntiAlias = true;
      for (final f in visible) {
        final brightness = 0.68 + 0.32 * math.max(0, f.face.normal.dot(light));
        paint.color = Color.from(
          alpha: 1,
          red: f.face.color.r * brightness,
          green: f.face.color.g * brightness,
          blue: f.face.color.b * brightness,
        );
        final path = Path()
          ..moveTo(f.a!.point.dx, f.a!.point.dy)
          ..lineTo(f.b!.point.dx, f.b!.point.dy)
          ..lineTo(f.c!.point.dx, f.c!.point.dy)
          ..close();
        canvas.drawPath(path, paint);
      }
    }

    // All landmarks are above the terrain. Draw the terrain first so the
    // large ground triangles cannot cover smaller objects at oblique angles.
    drawFaces(mesh.faces.take(mesh.terrainFaceCount).toList());
    drawFaces([
      ...mesh.faces.skip(mesh.terrainFaceCount),
      ...IslandMesh.companion(companion, lowDetail: mesh.lowDetail),
    ]);
    for (final d in UniverseDestination.values) {
      final p = projectPoint(d.position + const WorldPoint(0, 0.35, 0));
      if (p == null) continue;
      canvas.drawCircle(
        p.point,
        selected == d ? 13 : 7,
        Paint()
          ..color = const Color(0xFFF9E9BC)
              .withValues(alpha: selected == d ? 0.28 : 0.12),
      );
      canvas.drawCircle(p.point, 4, Paint()..color = const Color(0xFFFFE6AC));
    }
  }

  @override
  bool shouldRepaint(_IslandPainter old) =>
      old.mesh != mesh ||
      old.camera != camera ||
      old.companion != companion ||
      old.selected != selected;
}
