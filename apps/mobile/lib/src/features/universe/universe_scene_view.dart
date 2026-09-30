import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart' show SkyPhase;
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
    this.sky = SkyPhase.night,
    this.pose = CompanionPose.still,
    this.changes = const [],
    this.changeProgress = 1,
  });
  final IslandMesh mesh;
  final UniverseCamera camera;
  final WorldPoint companion;
  final UniverseDestination? selected;

  /// What the companion is doing (T04): standing, walking or celebrating.
  final CompanionPose pose;

  /// Plants in the middle of a moment (T04), drawn between how they were
  /// last seen and how they are now at [changeProgress] (0-1). The [mesh]
  /// leaves these slots out while they play.
  final List<WorldPlantChange> changes;
  final double changeProgress;

  /// The sky over the island (W06): the phone's own time of day, decoration
  /// only. Nothing personal reaches the renderer.
  final SkyPhase sky;
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
              painter: IslandPainter(
                mesh,
                camera,
                companion,
                selected,
                sky,
                pose,
                changes,
                changeProgress,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Which part of the picture a painter draws. The Canvas renderer draws
/// [all]; the GPU renderer (native/) draws the faces itself and asks the same
/// painter for the sky behind it ([background]) and the sparkles and place
/// lights over it ([overlay]), so nothing is drawn twice or drifts apart.
enum IslandLayer { all, background, overlay }

class IslandPainter extends CustomPainter {
  IslandPainter(
    this.mesh,
    this.camera,
    this.companion,
    this.selected,
    this.sky,
    this.pose,
    this.changes,
    this.changeProgress, {
    this.layer = IslandLayer.all,
  });
  final IslandLayer layer;
  final SkyPhase sky;
  final CompanionPose pose;
  final List<WorldPlantChange> changes;
  final double changeProgress;
  final IslandMesh mesh;
  final UniverseCamera camera;
  final WorldPoint companion;
  final UniverseDestination? selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (layer != IslandLayer.overlay) _paintSky(canvas, size);
    if (layer == IslandLayer.background) return;
    _paintWorld(canvas, size);
  }

  void _paintSky(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: switch (sky) {
            SkyPhase.dawn => const [Color(0xFF3B3A63), Color(0xFFB58A8F)],
            SkyPhase.day => const [Color(0xFF557AA6), Color(0xFFBBD5E3)],
            SkyPhase.dusk => const [Color(0xFF443C6A), Color(0xFFCF8D7C)],
            SkyPhase.night => const [Color(0xFF282D47), Color(0xFF4B4B67)],
          },
        ).createShader(Offset.zero & size),
    );
    // Stars fade out with the daylight.
    final starAlpha = switch (sky) {
      SkyPhase.night => 0.5,
      SkyPhase.dawn || SkyPhase.dusk => 0.25,
      SkyPhase.day => 0.0,
    };
    final starPaint = Paint()
      ..color = const Color(0xFFE7DFCD).withValues(alpha: starAlpha);
    for (var i = 0; starAlpha > 0 && i < 28; i++) {
      final x = ((i * 73 + 19) % 101) / 101 * size.width;
      final y = ((i * 37 + 7) % 89) / 89 * size.height;
      canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 1.4 : 0.7, starPaint);
    }
  }

  void _paintWorld(Canvas canvas, Size size) {
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
    // (The GPU renderer draws the faces itself, with a depth buffer.)
    if (layer == IslandLayer.all) {
      drawFaces(mesh.faces.take(mesh.terrainFaceCount).toList());
      drawFaces([
        ...mesh.faces.skip(mesh.terrainFaceCount),
        for (final change in changes)
          ...IslandMesh.changingPlant(
            change,
            changeProgress,
            lowDetail: mesh.lowDetail,
          ),
        ...IslandMesh.companion(
          companion,
          lowDetail: mesh.lowDetail,
          pose: pose,
        ),
      ]);
    }
    // A few soft sparkles mark what the moment is about: over each changing
    // plant, and around the companion while it celebrates.
    final glow = math.sin(changeProgress.clamp(0.0, 1.0) * math.pi);
    if (changes.isNotEmpty && glow > 0.01) {
      for (final change in changes) {
        _sparkles(
          canvas,
          projectPoint(IslandMesh.crownOf(change.to)),
          glow,
          changeProgress,
        );
      }
    }
    if (pose.motion == CompanionMotion.celebrate) {
      final cheer = math.sin(pose.phase.clamp(0.0, 1.0) * math.pi);
      _sparkles(
        canvas,
        projectPoint(
          WorldPoint(companion.x, 0.16 + pose.lift + 0.82, companion.z),
        ),
        cheer,
        pose.phase,
        radius: 20,
      );
    }
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

  /// Five small twinkles on a ring around [at], turning as [turn] runs.
  void _sparkles(
    Canvas canvas,
    ({Offset point, double depth})? at,
    double alpha,
    double turn, {
    double radius = 12,
  }) {
    if (at == null || alpha <= 0) return;
    final paint = Paint()
      ..color = const Color(0xFFFFE6AC).withValues(alpha: alpha * 0.9);
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 + turn * math.pi;
      final r = radius * (0.7 + 0.3 * alpha);
      canvas.drawCircle(
        at.point + Offset(math.cos(angle) * r, math.sin(angle) * r * 0.6),
        i.isEven ? 2.2 : 1.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(IslandPainter old) =>
      old.layer != layer ||
      old.mesh != mesh ||
      old.camera != camera ||
      old.companion != companion ||
      old.selected != selected ||
      old.sky != sky ||
      old.pose != pose ||
      old.changes != changes ||
      old.changeProgress != changeProgress;
}
