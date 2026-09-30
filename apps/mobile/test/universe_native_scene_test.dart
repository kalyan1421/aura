import 'dart:math' as math;

import 'package:aura/src/core/perf/device_profile.dart';
import 'package:aura/src/features/universe/native/gpu_camera.dart';
import 'package:aura/src/features/universe/native/gpu_faces.dart';
import 'package:aura/src/features/universe/native/native_scene_view.dart';
import 'package:aura/src/features/universe/native/scene_probe.dart';
import 'package:aura/src/features/universe/universe_scene.dart';
import 'package:aura/src/features/universe/universe_scene_host.dart';
import 'package:aura/src/features/universe/universe_scene_view.dart';
import 'package:aura_domain/aura_domain.dart' show GrowthStage, Vitality;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// T01: the GPU renderer's testable parts (no GPU needed): the shading baked
/// into vertex colours, the camera that frames the island like the Canvas one,
/// and the host that falls back to Canvas whenever the GPU renderer cannot run.

IslandMesh _island() => IslandMesh(
  growth: 1,
  litStones: 16,
  plants: [
    for (var i = 0; i < maxWorldPlants; i++)
      WorldPlant(
        slot: i,
        stage: GrowthStage.values[i % GrowthStage.values.length],
        vitality: Vitality.values[i % Vitality.values.length],
      ),
  ],
);

void main() {
  group('baked faces', () {
    test('shading: a face turned up is lit, one turned down gets the shadow '
        'floor, and the light direction is the Canvas painter\'s', () {
      const origin = WorldPoint(0, 0, 0);
      // Normal (b-a) x (c-a): this winding points up, its reverse points down.
      const up = WorldFace(
        origin,
        WorldPoint(0, 0, 1),
        WorldPoint(1, 0, 0),
        Color(0xFFFF8000),
      );
      const down = WorldFace(
        origin,
        WorldPoint(1, 0, 0),
        WorldPoint(0, 0, 1),
        Color(0xFFFF8000),
      );
      expect(up.normal.y, closeTo(1, 1e-9));
      expect(down.normal.y, closeTo(-1, 1e-9));
      // 0.68 + 0.32 x (the light's y component).
      expect(faceBrightness(up), closeTo(0.68 + 0.32 * islandLight.y, 1e-9));
      expect(faceBrightness(down), closeTo(0.68, 1e-9));
      // The same constant the Canvas painter shades with.
      expect(islandLight.x, closeTo(-0.5 / math.sqrt(1.61), 1e-9));
      expect(islandLight.z, closeTo(0.6 / math.sqrt(1.61), 1e-9));
    });

    test('the arrays match the faces: three vertices each, shaded colours, '
        'flat normals, opaque', () {
      final faces = _island().faces;
      final baked = bakeFaces(faces);
      expect(baked.faceCount, faces.length);
      expect(baked.positions.length, faces.length * 9);
      expect(baked.normals.length, faces.length * 9);
      expect(baked.colors.length, faces.length * 12);
      final f = faces[10];
      final b = faceBrightness(f);
      // Shaded in sRGB like Canvas, then linearised for the GPU.
      expect(baked.colors[10 * 12], closeTo(srgbToLinear(f.color.r * b), 1e-6));
      expect(
        baked.colors[10 * 12 + 1],
        closeTo(srgbToLinear(f.color.g * b), 1e-6),
      );
      expect(
        baked.colors[10 * 12 + 2],
        closeTo(srgbToLinear(f.color.b * b), 1e-6),
      );
      for (var v = 0; v < 3; v++) {
        expect(baked.colors[10 * 12 + v * 4 + 3], 1);
        // The GPU world is mirrored in x (see mirrorX).
        expect(baked.normals[10 * 9 + v * 3], closeTo(-f.normal.x, 1e-6));
        expect(baked.normals[10 * 9 + v * 3 + 1], closeTo(f.normal.y, 1e-6));
      }
      expect(baked.positions.every((x) => x.isFinite), isTrue);
      expect(baked.colors.every((x) => x >= 0 && x <= 1), isTrue);
    });

    test('the GPU world is the Canvas world mirrored in x, and colours are '
        'linearised', () {
      final f = _island().faces[25];
      final baked = bakeFaces([f]);
      expect(baked.positions[0], closeTo(-f.a.x, 1e-6));
      expect(baked.positions[1], closeTo(f.a.y, 1e-6));
      expect(baked.positions[2], closeTo(f.a.z, 1e-6));
      expect(mirrorX(mirrorX(1.25)), 1.25);
      expect(srgbToLinear(0), 0);
      expect(srgbToLinear(1), closeTo(1, 1e-9));
      // Mid grey in sRGB is much darker in linear light.
      expect(srgbToLinear(0.5), closeTo(0.2140, 1e-3));
    });

    test('the whole island, its companion and plants in a moment fit the GPU '
        'budget for a phone', () {
      final island = bakeFaces(_island().faces);
      final moving = bakeFaces([
        ...IslandMesh.companion(const WorldPoint(0, 0.16, 0)),
      ]);
      expect(island.faceCount, lessThan(3500));
      expect(moving.faceCount, lessThan(400));
    });
  });

  group('the GPU camera frames the island like the Canvas one', () {
    /// A pinhole camera built from [GpuCameraParams] alone (what a GPU
    /// camera does), for comparing with [UniverseCamera.project].
    Offset pinhole(GpuCameraParams p, WorldPoint at, double w, double h) {
      final f = (p.target - p.eye).unit;
      final r = f.cross(const WorldPoint(0, 1, 0)).unit;
      final u = r.cross(f).unit;
      final rel = at - p.eye;
      final depth = rel.dot(f);
      final focal = (h / 2) / math.tan(p.fovYRadians / 2);
      return Offset(
        w / 2 + rel.dot(r) * focal / depth,
        h / 2 - rel.dot(u) * focal / depth,
      );
    }

    test('places, the plaza, the pool and the centre land within a few pixels '
        'across orbit, zoom and phone shapes', () {
      var worst = 0.0;
      for (final size in const [
        Size(342, 291),
        Size(342, 400),
        Size(720, 400),
        Size(320, 250),
      ]) {
        for (final yaw in [0.18, -1.2, 2.4]) {
          for (final zoom in [6.5, 7.8, 11.0]) {
            final cam = UniverseCamera(yaw: yaw, distance: zoom);
            final params = gpuCameraFor(cam, size.width, size.height);
            for (final d in UniverseDestination.values) {
              final at = d.position + const WorldPoint(0, 0.35, 0);
              final canvas = cam.project(at, size)!.point;
              final gpu = pinhole(params, at, size.width, size.height);
              worst = math.max(worst, (canvas - gpu).distance);
            }
            final centre = cam
                .project(const WorldPoint(0, 0.25, 0), size)!
                .point;
            final gpuCentre = pinhole(
              params,
              const WorldPoint(0, 0.25, 0),
              size.width,
              size.height,
            );
            worst = math.max(worst, (centre - gpuCentre).distance);
          }
        }
      }
      // Taps are matched to a place within 42 px, so a few pixels of
      // difference between the two projections never changes which place a
      // tap chooses.
      expect(worst, lessThan(6), reason: 'worst gap $worst px');
    });

    test('the field of view reproduces the Canvas focal length', () {
      for (final size in const [Size(342, 291), Size(720, 400)]) {
        final p = gpuCameraFor(const UniverseCamera(), size.width, size.height);
        final focal = (size.height / 2) / math.tan(p.fovYRadians / 2);
        expect(focal, closeTo(math.min(size.width, size.height) * 1.65, 1e-6));
      }
    });
  });

  group('the host falls back to Canvas', () {
    setUp(resetNativeSceneProbe);

    Future<void> pump(
      WidgetTester tester, {
      required bool enabled,
      bool lowTier = false,
    }) async {
      DeviceProfile.instance.apply(
        DeviceProfileInfo(android: false, powerSave: lowTier),
      );
      addTearDown(DeviceProfile.instance.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [nativeSceneEnabledProvider.overrideWithValue(enabled)],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 300,
                child: UniverseSceneHost(
                  mesh: _island(),
                  camera: const UniverseCamera(),
                  companion: const WorldPoint(0, 0.16, 0),
                  selected: UniverseDestination.grove,
                  onOrbit: (_, _) {},
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    testWidgets('off (the default): the Canvas renderer', (tester) async {
      await pump(tester, enabled: false);
      expect(find.byType(UniverseSceneView), findsOneWidget);
      expect(find.byType(NativeSceneView), findsNothing);
    });

    testWidgets('on, but Flutter GPU cannot start (as under the test engine): '
        'still the Canvas renderer, nothing thrown', (tester) async {
      await pump(tester, enabled: true);
      expect(find.byType(UniverseSceneView), findsOneWidget);
      expect(find.byType(NativeSceneView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on, on the low tier: the Canvas renderer', (tester) async {
      await pump(tester, enabled: true, lowTier: true);
      expect(find.byType(UniverseSceneView), findsOneWidget);
    });

    testWidgets('a GPU view that cannot start tells its host', (tester) async {
      var told = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 340,
            height: 300,
            child: NativeSceneView(
              mesh: _island(),
              camera: const UniverseCamera(),
              companion: const WorldPoint(0, 0.16, 0),
              selected: null,
              onOrbit: (_, _) {},
              onSelect: (_) {},
              onUnavailable: () => told++,
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(told, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
