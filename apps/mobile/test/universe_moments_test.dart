import 'dart:convert';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/l10n/locale_controller.dart'
    show systemLocalizationDelegates;
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura/src/features/universe/roam.dart';
import 'package:aura/src/features/universe/universe_scene.dart';
import 'package:aura/src/features/universe/universe_scene_view.dart';
import 'package:aura/src/features/universe/universe_screen.dart';
import 'package:aura/src/features/universe/world_moments.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// T04: a plant that grew, woke or was planted since the last look plays one
/// moment in the personal universe: the companion turns and hops, the plant
/// grows into its new shape, and words say what changed. Walking bobs and
/// faces the way it goes. Resting is never a moment.

const _changes = ValueKey('universe-changes');

HabitRepository _repo(AppDatabase db) => HabitRepository(
  db,
  OutboxRepository(db, const Ids()),
  testTime(),
  const Ids(),
);

Future<void> _seenAllSeeds(WidgetTester tester, AppDatabase db) =>
    io(tester, () async {
      await KvStore(db).set(
        KvKeys.worldSeen,
        jsonEncode({
          for (final p in presetHabits) 'p:${p.key}': ['seed', 'thriving'],
        }),
      );
    });

Future<GoRouter> _pump(
  WidgetTester tester,
  AppDatabase db, {
  bool reduceMotion = false,
}) async {
  // Tall enough that the whole universe screen is on stage.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => reduceMotion
            ? MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const UniverseScreen(),
              )
            : const UniverseScreen(),
      ),
    ],
  );
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
  return router;
}

Future<void> _end(WidgetTester tester, AppDatabase db, GoRouter router) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  router.dispose();
  await tester.runAsync(db.close);
}

UniverseSceneView _scene(WidgetTester tester) =>
    tester.widget<UniverseSceneView>(find.byType(UniverseSceneView));

/// Pumps [total] in small steps and records every pose and change list the
/// scene was drawn with.
Future<List<UniverseSceneView>> _watch(
  WidgetTester tester, {
  Duration total = const Duration(milliseconds: 2400),
}) async {
  final seen = <UniverseSceneView>[_scene(tester)];
  for (
    var t = Duration.zero;
    t < total;
    t += const Duration(milliseconds: 50)
  ) {
    await tester.pump(const Duration(milliseconds: 50));
    seen.add(_scene(tester));
  }
  return seen;
}

void main() {
  testWidgets('a plant that grew since the last look: the companion '
      'celebrates, the plant grows into its stage, and words say so', (
    tester,
  ) async {
    final db = memoryDb();
    await _seenAllSeeds(tester, db);
    await io(tester, () => _repo(db).toggleToday(PresetHabitKeys.hydrate));
    final router = await _pump(tester, db);
    await settleIo(tester, rounds: 3);

    final frames = await _watch(tester);
    final cheering = frames.where(
      (s) => s.pose.motion == CompanionMotion.celebrate,
    );
    expect(cheering, isNotEmpty);
    // The plant being celebrated is drawn between its two looks.
    final change = cheering.first.changes.single;
    expect(change.from?.stage, GrowthStage.seed);
    expect(change.to.stage, GrowthStage.sprout);
    expect(
      cheering.map((s) => s.changeProgress).toSet().length,
      greaterThan(3),
    );
    // Then it is over: standing again, the plant back in the island.
    expect(frames.last.pose.motion, CompanionMotion.idle);
    expect(frames.last.changes, isEmpty);
    expect(tester.hasRunningAnimations, isFalse);

    // The words stay for the visit, and they are only good news.
    expect(find.byKey(_changes), findsOneWidget);
    expect(find.text('New in your world'), findsOneWidget);
    expect(find.text('Hydrate grew to a new stage: Sprout'), findsOneWidget);
    // Recorded as seen on this phone: it will not play again.
    final seen = await io(tester, () => KvStore(db).get(KvKeys.worldSeen));
    expect((jsonDecode(seen!) as Map<String, dynamic>)['p:hydrate'], [
      'sprout',
      'thriving',
    ]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();

    final again = await _pump(tester, db);
    await settleIo(tester);
    expect(find.byKey(_changes), findsNothing);
    expect(_scene(tester).pose.motion, isNot(CompanionMotion.celebrate));
    await _end(tester, db, again);
  });

  testWidgets('logging in the Grove: the moment waits for the sheet to close, '
      'then plays where the person can see it', (tester) async {
    final db = memoryDb();
    final router = await _pump(tester, db);
    await settleIo(tester); // the first look is only a baseline
    expect(find.byKey(_changes), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UniverseScreen)),
    );

    await tester.tap(find.byKey(const ValueKey('universe-care-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('habit-hydrate')));
    await settleIo(tester);
    // Waiting, not played under the sheet.
    expect(container.read(worldMomentsProvider), isNotNull);
    expect(find.byKey(_changes), findsNothing);

    Navigator.of(tester.element(find.byKey(const ValueKey('habit-hydrate'))))
        .pop();
    await tester.pump();
    await tester.pump();
    expect(container.read(worldMomentsProvider), isNull); // taken: playing
    expect(find.text('Hydrate grew to a new stage: Sprout'), findsOneWidget);
    final frames = await _watch(tester);
    expect(
      frames.any((s) => s.pose.motion == CompanionMotion.celebrate),
      isTrue,
    );
    expect(frames.last.changes, isEmpty);
    expect(tester.takeException(), isNull);
    await _end(tester, db, router);
  });

  testWidgets('reduced motion: the new state and the words, with no hop and '
      'no growing', (tester) async {
    final db = memoryDb();
    await _seenAllSeeds(tester, db);
    await io(tester, () => _repo(db).toggleToday(PresetHabitKeys.hydrate));
    final router = await _pump(tester, db, reduceMotion: true);
    await settleIo(tester, rounds: 3);
    final frames = await _watch(tester);
    expect(
      frames.every(
        (s) => s.pose.motion == CompanionMotion.idle && s.changes.isEmpty,
      ),
      isTrue,
    );
    expect(find.text('Hydrate grew to a new stage: Sprout'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    await _end(tester, db, router);
  });

  testWidgets('a plant that starts to rest is shown as it is: no moment, no '
      'words', (tester) async {
    final db = memoryDb();
    await io(tester, () async {
      final kv = KvStore(db);
      await kv.set(KvKeys.birthDate, '1990-01-01');
      final id = await _repo(db).ensurePresetId(PresetHabitKeys.hydrate);
      await db.customStatement(
        "UPDATE habits SET committed_from = '2026-09-20' WHERE id = '$id'",
      );
      await kv.set(
        KvKeys.worldSeen,
        jsonEncode({
          for (final p in presetHabits) 'p:${p.key}': ['seed', 'thriving'],
        }),
      );
    });
    final router = await _pump(tester, db);
    await settleIo(tester);
    final frames = await _watch(tester, total: const Duration(seconds: 1));
    expect(frames.every((s) => s.changes.isEmpty), isTrue);
    expect(
      frames.every((s) => s.pose.motion != CompanionMotion.celebrate),
      isTrue,
    );
    expect(find.byKey(_changes), findsNothing);
    // The grove itself still says, warmly, that it is resting (W03).
    expect(find.byKey(const ValueKey('universe-plants-resting')), findsOne);
    await _end(tester, db, router);
  });

  testWidgets('walking: the companion faces where it goes and bobs on the '
      'way, then stands facing it', (tester) async {
    final db = memoryDb();
    final router = await _pump(tester, db);
    await settleIo(tester);
    final start = _scene(tester).companion;
    await tester.tap(find.byKey(const ValueKey('universe-tidePool')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final walking = _scene(tester);
    expect(walking.pose.motion, CompanionMotion.walk);
    final heading = headingToward(start, UniverseDestination.tidePool.walkStop);
    expect(walking.pose.heading, closeTo(heading, 1e-9));
    expect(walking.pose.phase, greaterThan(0));
    await tester.pumpAndSettle();
    final arrived = _scene(tester);
    expect(arrived.pose.motion, CompanionMotion.idle);
    expect(arrived.pose.heading, closeTo(heading, 1e-9));
    await _end(tester, db, router);
  });

  testWidgets('going to the background ends a moment at once', (tester) async {
    final db = memoryDb();
    await _seenAllSeeds(tester, db);
    await io(tester, () => _repo(db).toggleToday(PresetHabitKeys.hydrate));
    final router = await _pump(tester, db);
    await settleIo(tester, rounds: 3);
    // Find the moment playing, then leave the app.
    for (var i = 0; i < 20; i++) {
      if (_scene(tester).pose.motion == CompanionMotion.celebrate) break;
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(_scene(tester).pose.motion, CompanionMotion.celebrate);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(_scene(tester).pose.motion, CompanionMotion.idle);
    expect(_scene(tester).changes, isEmpty);
    expect(tester.hasRunningAnimations, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Hydrate grew to a new stage: Sprout'), findsOneWidget);
    await _end(tester, db, router);
  });
}
