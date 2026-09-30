import 'dart:math' as math;

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/features/universe/roam.dart';
import 'package:aura/src/features/universe/universe_scene.dart';
import 'package:aura/src/features/universe/universe_scene_view.dart';
import 'package:aura/src/features/universe/universe_screen.dart';
import 'package:aura_domain/aura_domain.dart' show GrowthStage;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// W05 camera follow: in free roam the camera's look-at point follows the
/// companion; yaw, pitch and zoom stay the person's own. Tap-to-travel keeps
/// the whole-island view, and reduced motion never moves the camera.

void _near(WorldPoint a, WorldPoint b, {double by = 1e-9}) {
  expect(a.x, closeTo(b.x, by));
  expect(a.y, closeTo(b.y, by));
  expect(a.z, closeTo(b.z, by));
}

void main() {
  group('the camera', () {
    test('by default it looks at the island centre, exactly as before', () {
      const c = UniverseCamera();
      _near(c.target, UniverseCamera.home);
      _near(
        c.eye,
        WorldPoint(
          math.sin(0.18) * math.cos(0.66) * 7.8,
          math.sin(0.66) * 7.8,
          math.cos(0.18) * math.cos(0.66) * 7.8,
        ),
      );
      _near(c.forward, (UniverseCamera.home - c.eye).unit);
    });

    test('looking elsewhere moves the eye with it and keeps the angle', () {
      final base = const UniverseCamera().orbit(0.7, 0.2).zoom(1);
      const point = WorldPoint(1.2, 0.25, -0.6);
      final moved = base.lookingAt(point);
      _near(moved.eye - base.eye, point - UniverseCamera.home);
      _near(moved.forward, base.forward);
      _near(moved.right, base.right);
      _near(moved.up, base.up);
      // Orbit and zoom keep the look-at point.
      _near(moved.orbit(0.3, -0.1).target, point);
      _near(moved.zoom(-0.5).target, point);
    });

    test('equal views are equal (so an unchanged view never repaints)', () {
      expect(const UniverseCamera(), const UniverseCamera());
      expect(
        const UniverseCamera().lookingAt(const WorldPoint(1, 0.25, 0)),
        const UniverseCamera().lookingAt(const WorldPoint(1, 0.25, 0)),
      );
      expect(
        const UniverseCamera(),
        isNot(const UniverseCamera().lookingAt(const WorldPoint(1, 0.25, 0))),
      );
    });

    test('picking follows the moved view', () {
      const size = Size(360, 310);
      for (final at in [
        const WorldPoint(1.5, 0.16, 0.2),
        const WorldPoint(-1.1, 0.16, -1.2),
      ]) {
        final camera = const UniverseCamera().lookingAt(followTarget(at, 1));
        for (final d in UniverseDestination.values) {
          final screen = camera.project(
            d.position + const WorldPoint(0, 0.35, 0),
            size,
          );
          if (screen == null) continue;
          expect(camera.pick(screen.point, size), d);
        }
      }
    });
  });

  group('the follow target', () {
    const at = WorldPoint(1.5, roamHeight, -1.0);

    test('0 is the island centre, 1 follows most of the way, and it stays at '
        'the look-at height', () {
      _near(followTarget(at, 0), UniverseCamera.home);
      _near(
        followTarget(at, 1),
        WorldPoint(
          at.x * roamFollowReach,
          UniverseCamera.home.y,
          at.z * roamFollowReach,
        ),
      );
      _near(followTarget(at, 2), followTarget(at, 1)); // clamped
      _near(followTarget(at, -1), UniverseCamera.home);
    });

    test('wherever the companion can walk, at every orbit and zoom limit, the '
        'whole island stays in front of the camera', () {
      final mesh = IslandMesh(
        growth: 1,
        plants: [
          for (var i = 0; i < maxWorldPlants; i++)
            WorldPlant(slot: i, stage: GrowthStage.ancient),
        ],
      );
      const size = Size(360, 310);
      final spots = [
        for (var i = 0; i < 16; i++)
          keepOnIsland(
            WorldPoint(
              math.cos(i * math.pi / 8) * roamRadius,
              roamHeight,
              math.sin(i * math.pi / 8) * roamRadius,
            ),
          ),
      ];
      for (final spot in spots) {
        for (final yaw in [0.18, 1.7, 3.3, 4.9]) {
          for (final pitch in [-100.0, 100.0]) {
            for (final zoom in [-100.0, 100.0]) {
              final camera = UniverseCamera(yaw: yaw)
                  .orbit(0, pitch)
                  .zoom(zoom)
                  .lookingAt(followTarget(spot, 1));
              final project = camera.projector(size);
              for (final f in mesh.faces) {
                for (final p in [f.a, f.b, f.c]) {
                  final s = project(p);
                  expect(s, isNotNull, reason: '$spot $yaw $pitch $zoom');
                  expect(s!.point.dx.isFinite && s.point.dy.isFinite, isTrue);
                }
              }
            }
          }
        }
      }
    });
  });

  group('on the universe screen', () {
    late AppDatabase db;

    Future<void> pump(WidgetTester tester, {bool reduceMotion = false}) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      db = memoryDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db: db),
          child: localized(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduceMotion),
                child: const UniverseScreen(),
              ),
            ),
          ),
        ),
      );
      await settleIo(tester);
    }

    Future<void> end(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(db.close);
    }

    UniverseSceneView scene(WidgetTester tester) =>
        tester.widget<UniverseSceneView>(find.byType(UniverseSceneView));

    Future<void> hold(WidgetTester tester, String arrow, int frames) async {
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey('roam-$arrow'))),
      );
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await g.up();
      await tester.pump();
    }

    testWidgets('tap-to-travel keeps the whole island in view, even while the '
        'companion walks', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('universe-tidePool')));
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        _near(scene(tester).camera.target, UniverseCamera.home);
      }
      await tester.pumpAndSettle();
      _near(scene(tester).camera.target, UniverseCamera.home);
      await end(tester);
    });

    testWidgets('free roam eases the camera onto the companion, keeps it there '
        'while walking, and eases back to the island on leaving', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('universe-tidePool')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free roam'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final halfway = scene(tester);
      final goal = followTarget(halfway.companion, 1);
      // On its way: past the centre, not there yet.
      expect(halfway.camera.target.x, greaterThan(0.01));
      expect(halfway.camera.target.x, lessThan(goal.x - 0.01));
      await tester.pumpAndSettle();
      _near(scene(tester).camera.target, goal);

      await hold(tester, 'left', 16);
      final walked = scene(tester);
      _near(walked.camera.target, followTarget(walked.companion, 1));
      expect(walked.companion.x, isNot(closeTo(halfway.companion.x, 0.2)));
      // Orbiting and zooming are still the person's; the follow keeps up.
      final before = walked.camera;
      await tester.tap(find.byTooltip('Rotate right'));
      await tester.pump();
      final turned = scene(tester).camera;
      expect(turned.yaw, isNot(before.yaw));
      _near(turned.target, before.target);

      await tester.tap(find.text('Tap to travel'));
      await tester.pumpAndSettle();
      _near(scene(tester).camera.target, UniverseCamera.home);
      await end(tester);
    });

    testWidgets('walking stays camera-relative while the view follows', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Free roam'));
      await tester.pumpAndSettle();
      final start = scene(tester);
      await hold(tester, 'forward', 10);
      final after = scene(tester);
      final step = after.companion - start.companion;
      final f = start.camera.forward;
      final ground = math.sqrt(f.x * f.x + f.z * f.z);
      final along = (step.x * f.x + step.z * f.z) / ground;
      final length = math.sqrt(step.x * step.x + step.z * step.z);
      expect(length, greaterThan(0.2));
      expect(along / length, greaterThan(0.99)); // straight "up the screen"
      await end(tester);
    });

    testWidgets('reduced motion: free roam works, the camera never moves', (
      tester,
    ) async {
      await pump(tester, reduceMotion: true);
      await tester.tap(find.text('Free roam'));
      await tester.pump();
      _near(scene(tester).camera.target, UniverseCamera.home);
      await hold(tester, 'left', 12);
      final s = scene(tester);
      expect(s.companion.x, lessThan(-0.2));
      _near(s.camera.target, UniverseCamera.home);
      await end(tester);
    });

    testWidgets('going to the background finishes the camera move at once', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('universe-observatory')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free roam'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final moving = scene(tester);
      final goal = followTarget(moving.companion, 1);
      expect(moving.camera.target.x.abs(), lessThan(goal.x.abs() - 0.01));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      _near(scene(tester).camera.target, goal);
      // Nothing is left to finish: another frame changes nothing.
      await tester.pump(const Duration(milliseconds: 100));
      _near(scene(tester).camera.target, goal);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await end(tester);
    });

    testWidgets('back from the list view the camera is already where the mode '
        'puts it: following in free roam, the whole island otherwise', (
      tester,
    ) async {
      Future<void> listAndBack() async {
        await tester.tap(find.byKey(const ValueKey('universe-view-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('universe-view-toggle')));
        await tester.pump();
      }

      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('universe-grove')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free roam'));
      await tester.pumpAndSettle();
      await listAndBack();
      // The view is new, so it starts in place rather than easing there.
      final s = scene(tester);
      _near(s.camera.target, followTarget(s.companion, 1));

      await tester.tap(find.text('Tap to travel'));
      await tester.pumpAndSettle();
      await listAndBack();
      _near(scene(tester).camera.target, UniverseCamera.home);
      await end(tester);
    });

    testWidgets('tapping a place in the followed view still picks that place', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('universe-observatory')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free roam'));
      await tester.pumpAndSettle();
      final view = scene(tester);
      final box = tester.getRect(find.byKey(const ValueKey('universe-scene')));
      final light = view.camera.project(
        UniverseDestination.tidePool.position + const WorldPoint(0, 0.35, 0),
        box.size,
      )!;
      await tester.tapAt(box.topLeft + light.point);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text(
            UniverseDestination.tidePool.title(
              lookupAppLocalizations(const Locale('en')),
            ),
          ),
        ),
        findsOneWidget,
      );
      await end(tester);
    });
  });
}
