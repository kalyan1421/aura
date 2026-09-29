import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/l10n/locale_controller.dart' show systemLocalizationDelegates;
import 'package:aura/src/core/net/api_models.dart';
import 'package:aura/src/core/router/routes.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:aura/src/features/universe/universe_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// W04 (RULES.md section 13 `welcome`): coming back to the personal universe
/// after time away shows one warm card, once per absence. It never mentions
/// days away, streaks, loss or what was missed, and it asks for nothing.

const _welcome = ValueKey('universe-welcome');

Snapshot _snapshot(String lastActive) => Snapshot(
  avatar: const SnapshotAvatar(stage: 'spark', hue: 210),
  streak: SnapshotStreak(
    glowStreak: 1,
    lifetimeGlowDays: 4,
    lastActiveDay: lastActive,
  ),
  starlight: const SnapshotStarlight(total: 20, today: 0),
  serverTime: '2026-10-08T10:00:00Z',
  auraDay: '2026-10-08',
);

Future<void> _seed(
  WidgetTester tester,
  AppDatabase db, {
  String? lastActive,
  String? shownFor,
}) => io(tester, () async {
  final kv = KvStore(db);
  if (lastActive != null) {
    await ProgressRepository(db, kv).saveSnapshot(_snapshot(lastActive));
  }
  if (shownFor != null) await kv.set(KvKeys.welcomeShownFor, shownFor);
});

Future<GoRouter> _pump(WidgetTester tester, AppDatabase db) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const UniverseScreen()),
      GoRoute(
        path: Routes.checkIn,
        builder: (_, _) => const Scaffold(body: Text('Existing check-in')),
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
  await settleIo(tester);
  return router;
}

Future<void> _end(WidgetTester tester, AppDatabase db, GoRouter router) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  router.dispose();
  await tester.runAsync(db.close);
}

Future<String?> _shownFor(WidgetTester tester, AppDatabase db) =>
    io(tester, () => KvStore(db).get(KvKeys.welcomeShownFor));

void main() {
  testWidgets('after time away: one warm card that asks for nothing, and the '
      'moment is recorded', (tester) async {
    final db = memoryDb();
    await _seed(tester, db, lastActive: '2026-10-01');
    final router = await _pump(tester, db);

    expect(find.byKey(_welcome), findsOneWidget);
    expect(find.text('Your world is here'), findsOneWidget);
    expect(find.textContaining('right where you left it'), findsOneWidget);
    // Never guilt, loss, streaks or a count of days away.
    expect(
      find.textContaining(RegExp('miss|lost|streak|behind|failed|dead|away')),
      findsNothing,
    );
    expect(find.textContaining(RegExp(r'\d+ (days|day)')), findsNothing);
    expect(await _shownFor(tester, db), '2026-10-01');
    expect(tester.takeException(), isNull);
    await _end(tester, db, router);
  });

  testWidgets('"Just look around" closes it; opening the universe again for '
      'the same absence never repeats it', (tester) async {
    final db = memoryDb();
    await _seed(tester, db, lastActive: '2026-10-01');
    var router = await _pump(tester, db);

    await tester.tap(find.byKey(const ValueKey('universe-welcome-explore')));
    await settleIo(tester);
    expect(find.byKey(_welcome), findsNothing);

    // A fresh visit (new provider scope), same absence.
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    router = await _pump(tester, db);
    expect(find.byKey(_welcome), findsNothing);
    await _end(tester, db, router);
  });

  testWidgets('"Check in" opens the ordinary check-in', (tester) async {
    final db = memoryDb();
    await _seed(tester, db, lastActive: '2026-10-01');
    final router = await _pump(tester, db);
    await tester.tap(find.byKey(const ValueKey('universe-welcome-checkin')));
    await tester.pumpAndSettle();
    expect(find.text('Existing check-in'), findsOneWidget);
    await _end(tester, db, router);
  });

  testWidgets('no card when active recently, for a new person, or when it '
      'was already shown for this absence', (tester) async {
    for (final scenario in [
      (lastActive: '2026-10-07', shownFor: null), // two days: not an absence
      (lastActive: '2026-10-08', shownFor: null), // active today
      (lastActive: null, shownFor: null), // a new person
      (lastActive: '2026-10-01', shownFor: '2026-10-01'), // already shown
    ]) {
      final db = memoryDb();
      await _seed(
        tester,
        db,
        lastActive: scenario.lastActive,
        shownFor: scenario.shownFor,
      );
      final router = await _pump(tester, db);
      expect(
        find.byKey(_welcome),
        findsNothing,
        reason: '${scenario.lastActive} / ${scenario.shownFor}',
      );
      await _end(tester, db, router);
    }
  });

  testWidgets('a later absence shows it again', (tester) async {
    final db = memoryDb();
    await _seed(
      tester,
      db,
      lastActive: '2026-10-01',
      shownFor: '2026-09-01', // shown for an earlier absence
    );
    final router = await _pump(tester, db);
    expect(find.byKey(_welcome), findsOneWidget);
    expect(await _shownFor(tester, db), '2026-10-01');
    await _end(tester, db, router);
  });

  testWidgets('resting plants get the same warm line inside the card',
      (tester) async {
    final db = memoryDb();
    await _seed(tester, db, lastActive: '2026-10-01');
    await io(tester, () async {
      await KvStore(db).set(KvKeys.birthDate, '1996-01-01');
      await db
          .into(db.habits)
          .insert(
            HabitsCompanion.insert(
              id: 'h1',
              kind: 'custom',
              name: const Value('Read'),
              createdAt: testNow,
              updatedAt: testNow,
              committedFrom: const Value('2026-09-20'),
            ),
          );
    });
    final router = await _pump(tester, db);
    final card = find.byKey(_welcome);
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.text('One plant is resting. A single log wakes it.'),
      ),
      findsOneWidget,
    );
    await _end(tester, db, router);
  });
}
