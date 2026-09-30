import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/features/universe/roam.dart';
import 'package:aura/src/features/universe/universe_scene.dart';
import 'package:aura/src/features/universe/universe_scene_view.dart';
import 'package:aura/src/features/universe/universe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// W05: the universe opens in the mode the person last chose (Tap to travel
/// or Free roam). Tap-to-travel is the default; the choice stays on this
/// phone and is wiped with the person's local data.

const _controls = ValueKey('universe-roam-controls');

void main() {
  late AppDatabase db;
  setUp(() => db = memoryDb());

  /// One visit to the universe: a fresh provider scope over the same phone.
  Future<void> visit(WidgetTester tester, {bool reduceMotion = false}) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
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
    await tester.pumpAndSettle();
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  }

  Future<String?> stored(WidgetTester tester) =>
      io(tester, () => KvStore(db).get(KvKeys.universeRoamMode));

  UniverseSceneView scene(WidgetTester tester) =>
      tester.widget<UniverseSceneView>(find.byType(UniverseSceneView));

  testWidgets('a new person opens in tap-to-travel', (tester) async {
    await visit(tester);
    expect(find.byKey(_controls), findsNothing);
    expect(await stored(tester), isNull);
    await end(tester);
  });

  testWidgets('choosing free roam is remembered: the next visit opens in it, '
      'the camera following', (tester) async {
    await visit(tester);
    await tester.tap(find.text('Free roam'));
    await tester.pumpAndSettle();
    expect(await stored(tester), 'roam');

    await visit(tester);
    expect(find.byKey(_controls), findsOneWidget);
    final s = scene(tester);
    expect(s.camera.target.x, closeTo(followTarget(s.companion, 1).x, 1e-9));
    expect(s.camera.target.z, closeTo(followTarget(s.companion, 1).z, 1e-9));

    // Back to tap-to-travel: forgotten, and the next visit is the default.
    await tester.tap(find.text('Tap to travel'));
    await tester.pumpAndSettle();
    expect(await stored(tester), isNull);
    await visit(tester);
    expect(find.byKey(_controls), findsNothing);
    expect(scene(tester).camera.target.x, UniverseCamera.home.x);
    await end(tester);
  });

  testWidgets('the list view has no roam controls; back in the world the '
      'remembered mode returns, and the list never changes it', (tester) async {
    await io(tester, () => KvStore(db).set(KvKeys.universeRoamMode, 'roam'));
    await visit(tester);
    expect(find.byKey(_controls), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('universe-view-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(_controls), findsNothing);
    await tester.tap(find.byKey(const ValueKey('universe-view-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(_controls), findsOneWidget);
    final s = scene(tester);
    expect(s.camera.target.x, closeTo(followTarget(s.companion, 1).x, 1e-9));
    expect(await stored(tester), 'roam');
    await end(tester);
  });

  testWidgets('a choice made before the remembered mode arrives is kept', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: db),
        child: localized(const UniverseScreen()),
      ),
    );
    await tester.pump();
    // Nothing has been read from the phone yet (no real I/O has run).
    await tester.tap(find.text('Free roam'));
    await tester.pump();
    await settleIo(tester); // now the stored "tap-to-travel" arrives
    await tester.pumpAndSettle();
    expect(find.byKey(_controls), findsOneWidget);
    expect(await stored(tester), 'roam');
    await end(tester);
  });

  testWidgets(
    'reduced motion: remembered free roam opens with a still camera',
    (tester) async {
      await io(tester, () => KvStore(db).set(KvKeys.universeRoamMode, 'roam'));
      await visit(tester, reduceMotion: true);
      expect(find.byKey(_controls), findsOneWidget);
      expect(scene(tester).camera.target.x, UniverseCamera.home.x);
      expect(scene(tester).camera.target.z, UniverseCamera.home.z);
      await end(tester);
    },
  );

  test('the choice belongs to the person: it is wiped on sign-out', () {
    expect(KvKeys.deviceScoped, isNot(contains(KvKeys.universeRoamMode)));
  });
}
