import 'dart:math' as math;

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/features/universe/roam.dart';
import 'package:aura/src/features/universe/universe_scene.dart';
import 'package:aura/src/features/universe/universe_scene_view.dart';
import 'package:aura/src/features/universe/universe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// W05: optional free roam. Movement is camera-relative, bounded to the island,
/// blocked by the pool and tower, and presentation-only. Tap-to-travel and the
/// place list stay available, and nothing runs while nobody is moving.

const _start = WorldPoint(0, roamHeight, 0);
const _camera = UniverseCamera(); // default yaw 0.18

double _dist(WorldPoint a, WorldPoint b) =>
    math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.z - b.z, 2));

/// Camera-relative input that points on the ground from [from] toward [to].
RoamInput _toward(UniverseCamera cam, WorldPoint from, WorldPoint to) {
  final dx = to.x - from.x;
  final dz = to.z - from.z;
  final len = math.sqrt(dx * dx + dz * dz);
  if (len < 1e-9) return RoamInput.zero;
  final f = cam.forward;
  final r = cam.right;
  final fl = math.sqrt(f.x * f.x + f.z * f.z);
  final rl = math.sqrt(r.x * r.x + r.z * r.z);
  return RoamInput(
    right: (dx / len) * (r.x / rl) + (dz / len) * (r.z / rl),
    forward: (dx / len) * (f.x / fl) + (dz / len) * (f.z / fl),
  );
}

void main() {
  group('the movement model', () {
    test('forward is away from the camera, right is screen-right', () {
      final f = stepRoam(_start, const RoamInput(forward: 1), _camera, 0.05);
      final r = stepRoam(_start, const RoamInput(right: 1), _camera, 0.05);
      // The default camera sits on +z, so forward is toward -z.
      expect(f.z, lessThan(0));
      expect(r.x, greaterThan(0));
      expect(f.y, roamHeight);
    });

    test('turning the camera turns the walk', () {
      final quarter = _camera.orbit(math.pi / 2, 0);
      final f = stepRoam(_start, const RoamInput(forward: 1), quarter, 0.05);
      expect(f.x.abs(), greaterThan(f.z.abs())); // now mostly along x
    });

    test('a diagonal is no faster than a straight walk, and a light push is '
        'slower', () {
      final straight = _dist(
        _start,
        stepRoam(_start, const RoamInput(forward: 1), _camera, 0.05),
      );
      final diagonal = _dist(
        _start,
        stepRoam(
          _start,
          const RoamInput(right: 1, forward: 1) + RoamInput.zero,
          _camera,
          0.05,
        ),
      );
      final light = _dist(
        _start,
        stepRoam(_start, const RoamInput(forward: 0.4), _camera, 0.05),
      );
      expect(straight, closeTo(roamSpeed * 0.05, 1e-9));
      expect(diagonal, closeTo(straight, 1e-9));
      expect(light, closeTo(straight * 0.4, 1e-9));
    });

    test('combined inputs never exceed one full push', () {
      final both = const RoamInput(right: 1) + const RoamInput(right: 1);
      expect(both.right, 1);
      final diagonal =
          const RoamInput(right: 1) + const RoamInput(forward: 1);
      expect(
        math.sqrt(diagonal.right * diagonal.right + diagonal.forward * diagonal.forward),
        closeTo(1, 1e-9),
      );
    });

    test('a stalled frame cannot teleport the companion; no input or no '
        'time changes nothing', () {
      final long = stepRoam(_start, const RoamInput(forward: 1), _camera, 5);
      expect(_dist(_start, long), closeTo(roamSpeed * roamMaxStep, 1e-9));
      expect(stepRoam(_start, RoamInput.zero, _camera, 1), _start);
      expect(stepRoam(_start, const RoamInput(forward: 1), _camera, 0), _start);
      expect(nudgeRoam(_start, RoamInput.zero, _camera), _start);
    });

    test('a nudge is one small fixed step in any direction', () {
      for (final input in const [
        RoamInput(forward: 1),
        RoamInput(forward: -1),
        RoamInput(right: 1),
        RoamInput(right: -1),
      ]) {
        expect(
          _dist(_start, nudgeRoam(_start, input, _camera)),
          closeTo(roamNudge, 1e-9),
        );
      }
    });

    test('the island edge holds, whatever the direction', () {
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        var p = _start;
        for (var t = 0; t < 400; t++) {
          p = stepRoam(
            p,
            RoamInput(right: math.cos(a), forward: math.sin(a)),
            _camera,
            0.05,
          );
        }
        expect(math.sqrt(p.x * p.x + p.z * p.z), lessThanOrEqualTo(roamRadius + 1e-9));
      }
    });

    test('the pool wall and the tower are solid', () {
      for (final o in roamObstacles) {
        // Straight through the middle of each obstacle from the centre.
        var p = _start;
        var closest = 99.0;
        for (var t = 0; t < 300; t++) {
          p = stepRoam(p, _toward(_camera, p, o.center), _camera, 0.05);
          closest = math.min(closest, _dist(p, o.center));
        }
        expect(closest, greaterThanOrEqualTo(o.radius + roamBody - 1e-9));
      }
      // Dropped inside one, the companion is pushed out.
      final out = keepOnIsland(const WorldPoint(1.3, roamHeight, 0.8));
      expect(_dist(out, roamObstacles.first.center), greaterThanOrEqualTo(0.61 + roamBody - 1e-9));
    });

    test('every place can be reached on foot and is then chosen', () {
      for (final d in UniverseDestination.values) {
        var p = _start;
        for (var t = 0; t < 400; t++) {
          p = stepRoam(p, _toward(_camera, p, d.position), _camera, 0.05);
        }
        expect(nearestPlace(p), d, reason: d.name);
        for (final o in roamObstacles) {
          expect(_dist(p, o.center), greaterThanOrEqualTo(o.radius + roamBody - 1e-9));
        }
      }
    });

    test('walking is deterministic and the nearest place wins', () {
      WorldPoint walk() {
        var p = _start;
        for (var t = 0; t < 100; t++) {
          p = stepRoam(p, const RoamInput(right: 0.6, forward: -0.3), _camera, 0.016);
        }
        return p;
      }

      final a = walk();
      final b = walk();
      expect([a.x, a.z], [b.x, b.z]);
      expect(nearestPlace(_start), isNull); // the centre is far from every place
      // Halfway between two places, the closer one is chosen.
      expect(
        nearestPlace(const WorldPoint(-1.3, roamHeight, 0.3)),
        UniverseDestination.grove,
      );
    });
  });

  group('free roam on the universe screen', () {
    late AppDatabase db;
    setUp(() => db = memoryDb());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db: db),
          child: localized(const UniverseScreen()),
        ),
      );
      await settleIo(tester);
    }

    Future<void> end(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(db.close);
    }

    WorldPoint companion(WidgetTester tester) => tester
        .widget<UniverseSceneView>(find.byType(UniverseSceneView))
        .companion;

    Future<void> enableRoam(WidgetTester tester) async {
      await tester.tap(find.text('Free roam'));
      await tester.pumpAndSettle();
    }

    testWidgets('tap-to-travel is the default; free roam is opt-in and the '
        'controls only appear in it', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('universe-roam-controls')), findsNothing);
      expect(find.text('Tap to travel'), findsOneWidget);
      await enableRoam(tester);
      expect(find.byKey(const ValueKey('universe-roam-controls')), findsOneWidget);
      expect(find.textContaining('Drag the pad or hold an arrow'), findsOneWidget);
      await tester.tap(find.text('Tap to travel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('universe-roam-controls')), findsNothing);
      await end(tester);
    });

    testWidgets('the flat list has no roam controls and always works',
        (tester) async {
      await pump(tester);
      await enableRoam(tester);
      await tester.tap(find.byKey(const ValueKey('universe-view-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('universe-mode')), findsNothing);
      expect(find.byKey(const ValueKey('universe-roam-controls')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('universe-tidePool')));
      await tester.pumpAndSettle();
      expect(find.text('Tide Pool'), findsWidgets);
      await end(tester);
    });

    testWidgets('holding an arrow walks; letting go stops and nothing keeps '
        'running', (tester) async {
      await pump(tester);
      await enableRoam(tester);
      final idleFrames = tester.binding.transientCallbackCount;
      final before = companion(tester);
      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('roam-forward'))),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final moved = companion(tester);
      expect(moved.z, lessThan(before.z - 0.5)); // about a second of walking
      await hold.up();
      await tester.pump();
      final stopped = companion(tester);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(companion(tester), stopped);
      expect(tester.binding.transientCallbackCount, idleFrames);
      await end(tester);
    });

    testWidgets('the pad walks toward where it is dragged', (tester) async {
      await pump(tester);
      await enableRoam(tester);
      final pad = find.byKey(const ValueKey('roam-pad'));
      final before = companion(tester);
      // Hold the knob at the right edge of the pad.
      final hold = await tester.startGesture(
        tester.getCenter(pad) + const Offset(40, 0),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final after = companion(tester);
      expect(after.x, greaterThan(before.x + 0.3));
      await hold.up();
      await tester.pump();
      await end(tester);
    });

    testWidgets('walking up to the tide pool chooses it and its care card '
        'takes over', (tester) async {
      await pump(tester);
      await enableRoam(tester);
      expect(find.text('Habit Grove'), findsWidgets);
      final right = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('roam-right'))),
      );
      final back = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('roam-back'))),
      );
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byKey(const ValueKey('universe-care-action')).evaluate().isNotEmpty &&
            nearestPlace(companion(tester)) == UniverseDestination.tidePool) {
          break;
        }
      }
      await right.up();
      await back.up();
      await tester.pump();
      expect(nearestPlace(companion(tester)), UniverseDestination.tidePool);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('universe-care-action')),
        200,
      );
      final action = tester.widget<FilledButton>(
        find.byKey(const ValueKey('universe-care-action')),
      );
      expect(action.onPressed, isNotNull);
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Tide Pool'),
        ),
        findsOneWidget,
      );
      await end(tester);
    });

    testWidgets('a screen reader activates an arrow for one small step; '
        'each arrow is a labelled 48 dp button', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await enableRoam(tester);
      for (final label in [
        'Walk forward',
        'Walk back',
        'Walk left',
        'Walk right',
      ]) {
        final finder = find.bySemanticsLabel(label);
        expect(finder, findsOneWidget, reason: label);
        expect(tester.getSemantics(finder).flagsCollection.isButton, isTrue);
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      final before = companion(tester);
      await tester.tap(find.bySemanticsLabel('Walk right'));
      // A plain tap is a press and release: no continuous walk, no nudge.
      await tester.pump(const Duration(milliseconds: 50));
      final afterTap = companion(tester);
      expect(afterTap.z, closeTo(before.z, 0.2));
      tester.semantics.tap(find.semantics.byLabel('Walk forward'));
      await tester.pump();
      final nudged = companion(tester);
      expect(_dist(afterTap, nudged), closeTo(roamNudge, 1e-6));
      semantics.dispose();
      await end(tester);
    });

    testWidgets('backgrounding stops a walk in progress', (tester) async {
      await pump(tester);
      await enableRoam(tester);
      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('roam-forward'))),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final paused = companion(tester);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(companion(tester), paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await hold.up();
      await tester.pump();
      await end(tester);
    });

    testWidgets('tap-to-travel still walks to a place after roaming',
        (tester) async {
      await pump(tester);
      await enableRoam(tester);
      await tester.tap(find.byKey(const ValueKey('universe-observatory')));
      await tester.pumpAndSettle();
      final p = companion(tester);
      expect(
        _dist(p, UniverseDestination.observatory.avatarStop),
        lessThan(0.05),
      );
      await end(tester);
    });
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('free roam fits at 320 dp and 200% text: $locale', (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = memoryDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db: db),
          child: localized(
            const MediaQuery(
              data: MediaQueryData(
                size: Size(320, 740),
                textScaler: TextScaler.linear(2),
              ),
              child: UniverseScreen(),
            ),
            locale: locale,
          ),
        ),
      );
      await settleIo(tester);
      final mode = find.byKey(const ValueKey('universe-mode'));
      await tester.scrollUntilVisible(mode, -250);
      await tester.pumpAndSettle();
      // The second segment is free roam in every language.
      await tester.tap(
        find.descendant(
          of: mode,
          matching: find.byIcon(Icons.directions_walk_rounded),
        ),
      );
      await tester.pumpAndSettle();
      final controls = find.byKey(const ValueKey('universe-roam-controls'));
      await tester.scrollUntilVisible(controls, 250);
      await tester.pumpAndSettle();
      expect(controls, findsOneWidget);
      // Nothing overflows the phone's width, and the arrows stay touch-sized.
      final box = tester.getRect(controls);
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(320));
      for (final key in ['forward', 'back', 'left', 'right']) {
        final size = tester.getSize(find.byKey(ValueKey('roam-$key')));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(db.close);
    });
  }
}

