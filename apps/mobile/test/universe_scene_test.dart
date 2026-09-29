import 'dart:ui';

import 'package:aura/src/features/universe/universe_scene.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('growth is bounded, monotonic and handles missing progression', () {
    expect(universeGrowth(-10), 0);
    expect(universeGrowth(0), 0);
    expect(universeGrowth(10), greaterThan(universeGrowth(1)));
    expect(universeGrowth(1000), 1);
    expect(universeGrowth(1000000), 1);
  });

  test(
    'destination picking follows projection through camera orbit and zoom',
    () {
      const size = Size(360, 310);
      for (final yaw in [-2.5, -1.0, 0.18, 1.5, 3.0]) {
        final camera = UniverseCamera(yaw: yaw).zoom(0.5);
        for (final destination in UniverseDestination.values) {
          final screen = camera.project(
            destination.position + const WorldPoint(0, 0.35, 0),
            size,
          )!;
          expect(camera.pick(screen.point, size), destination);
          expect(screen.depth, greaterThan(0));
        }
      }
      expect(const UniverseCamera().pick(Offset.zero, size), isNull);
    },
  );

  test('camera bounds keep the island above the near plane', () {
    final low = const UniverseCamera().orbit(0, -100).zoom(-100);
    final high = const UniverseCamera().orbit(0, 100).zoom(100);
    expect(low.pitch, 0.35);
    expect(high.pitch, 1.15);
    expect(low.distance, 6.5);
    expect(high.distance, 11);
    for (final camera in [low, high]) {
      for (final face in IslandMesh(growth: 1).faces) {
        for (final point in [face.a, face.b, face.c]) {
          final projected = camera.project(point, const Size(300, 300));
          expect(projected, isNotNull);
          expect(projected!.point.dx.isFinite, isTrue);
          expect(projected.point.dy.isFinite, isTrue);
        }
      }
    }
    expect(low.project(const WorldPoint(0, 0, 0), Size.zero), isNull);
    expect(low.project(low.eye, const Size(300, 300)), isNull);
  });

  test('mesh stays bounded and low detail reduces work', () {
    final normal = IslandMesh(growth: 1);
    final low = IslandMesh(growth: 1, lowDetail: true);
    expect(normal.faces.length, lessThan(3000));
    expect(low.faces.length, lessThan(normal.faces.length));
    expect(low.terrainFaceCount, normal.terrainFaceCount);
    expect(
      IslandMesh.companion(const WorldPoint(0, 0, 0)).length,
      lessThan(400),
    );
  });
}
