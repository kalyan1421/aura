import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/router/routes.dart';
import 'package:aura/src/core/perf/device_profile.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/capsules/capsules_list_screen.dart';
import 'package:aura/src/features/progress/progress_view.dart';
import 'package:aura/src/features/sanctuary/breathe_session_screen.dart';
import 'package:aura/src/features/universe/universe_entry.dart';
import 'package:aura/src/features/universe/universe_scene.dart';
import 'package:aura/src/features/universe/universe_scene_view.dart';
import 'package:aura/src/features/universe/universe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

void main() {
  testWidgets('Grove reuses habits and existing progress grows the mesh', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final db = memoryDb();
    final sync = FakeSync();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(db.close);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: db, sync: sync),
        child: localized(const UniverseScreen()),
      ),
    );
    await settleIo(tester);
    final before = tester
        .widget<UniverseSceneView>(find.byType(UniverseSceneView))
        .mesh;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UniverseScreen)),
    );
    final total = container.read(progressViewProvider).totalStarlight;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('universe-care-action')),
      250,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('universe-care-action')));
    await tester.pumpAndSettle();
    await settleIo(tester);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('habit-hydrate'))),
      matchesSemantics(
        label: 'Hydrate, not yet today',
        hasEnabledState: true,
        isEnabled: true,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('habit-hydrate')));
    await settleIo(tester);
    expect(sync.writes, 1);
    expect(
      container.read(progressViewProvider).totalStarlight,
      greaterThan(total),
    );
    Navigator.of(tester.element(find.byKey(const ValueKey('habit-hydrate'))))
        .pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(UniverseSceneView), -250);
    await tester.pumpAndSettle();
    final after = tester
        .widget<UniverseSceneView>(find.byType(UniverseSceneView))
        .mesh;
    expect(identical(before, after), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    semantics.dispose();
  });

  testWidgets(
    'entry opens world and all care destinations use existing flows',
    (tester) async {
      final db = memoryDb();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: UniverseEntry()),
          ),
          GoRoute(
            path: Routes.universe,
            builder: (_, _) => const UniverseScreen(),
          ),
          GoRoute(
            path: Routes.checkIn,
            builder: (_, _) => const Scaffold(body: Text('Existing check-in')),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        router.dispose();
        await tester.runAsync(db.close);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db: db),
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildAuraTheme(const Locale('en')),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...systemLocalizationDelegates,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('universe-entry')));
      await tester.pumpAndSettle();
      expect(find.byType(UniverseSceneView), findsOneWidget);
      final fullMesh = tester
          .widget<UniverseSceneView>(find.byType(UniverseSceneView))
          .mesh;
      DeviceProfile.instance.apply(
        const DeviceProfileInfo(android: false, powerSave: true),
      );
      await tester.pump();
      final lowMesh = tester
          .widget<UniverseSceneView>(find.byType(UniverseSceneView))
          .mesh;
      expect(lowMesh.lowDetail, isTrue);
      expect(lowMesh.faces.length, lessThan(fullMesh.faces.length));
      DeviceProfile.instance.reset();
      await tester.pump();
      final originalCamera = tester
          .widget<UniverseSceneView>(find.byType(UniverseSceneView))
          .camera;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('universe-scene'))),
      );
      await gesture.moveBy(const Offset(25, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(45, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      final view = tester.widget<UniverseSceneView>(
        find.byType(UniverseSceneView),
      );
      expect(view.camera.yaw, isNot(originalCamera.yaw));
      final sceneBox = find.byKey(const ValueKey('universe-scene'));
      final light = view.camera
          .project(
            UniverseDestination.tidePool.position +
                const WorldPoint(0, 0.35, 0),
            tester.getSize(sceneBox),
          )!
          .point;
      await tester.tapAt(tester.getTopLeft(sceneBox) + light);
      await tester.pump(const Duration(milliseconds: 150));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final paused = tester.widget<UniverseSceneView>(
        find.byType(UniverseSceneView),
      );
      expect(paused.companion.x, UniverseDestination.tidePool.avatarStop.x);
      expect(paused.companion.z, UniverseDestination.tidePool.avatarStop.z);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<UniverseSceneView>(find.byType(UniverseSceneView))
            .selected,
        UniverseDestination.tidePool,
      );
      expect(tester.hasRunningAnimations, isFalse);
      await tester.tap(find.byKey(const ValueKey('universe-view-toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(UniverseSceneView), findsNothing);
      for (final (destination, screen) in [
        (UniverseDestination.tidePool, BreatheSessionScreen),
        (UniverseDestination.observatory, CapsulesListScreen),
      ]) {
        final button = find.byKey(ValueKey('universe-${destination.name}'));
        await tester.scrollUntilVisible(button, 250);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        final action = find.byKey(const ValueKey('universe-care-action'));
        await tester.scrollUntilVisible(action, 250);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await settleIo(tester);
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget);
        Navigator.of(tester.element(find.byType(screen))).pop();
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('universe-reflection')),
        250,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('universe-reflection')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('universe-care-action')),
        250,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('universe-care-action')));
      await tester.pumpAndSettle();
      expect(find.text('Existing check-in'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('320dp at 200% text and reduced motion: $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = memoryDb();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(db.close);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db: db),
          child: localized(
            const MediaQuery(
              data: MediaQueryData(
                size: Size(320, 740),
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: UniverseScreen(),
            ),
            locale: locale,
          ),
        ),
      );
      await settleIo(tester);
      for (final d in UniverseDestination.values) {
        final button = find.byKey(ValueKey('universe-${d.name}'));
        await tester.scrollUntilVisible(button, 250);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pump();
        await tester.scrollUntilVisible(find.byType(UniverseSceneView), -250);
        await tester.pumpAndSettle();
        final scene = tester.widget<UniverseSceneView>(
          find.byType(UniverseSceneView),
        );
        expect(scene.companion.x, d.avatarStop.x);
        expect(scene.companion.z, d.avatarStop.z);
        expect(tester.hasRunningAnimations, isFalse);
        expect(tester.takeException(), isNull);
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('universe-view-toggle')),
        -250,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('universe-view-toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(UniverseSceneView), findsNothing);
      for (final d in UniverseDestination.values) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('universe-${d.name}')),
          250,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('universe-${d.name}')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
