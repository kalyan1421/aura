import 'dart:convert';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura/src/features/checkin/post_save.dart';
import 'package:aura/src/features/companion/companion_response.dart';
import 'package:aura/src/features/companion/minute_for_you.dart';
import 'package:aura/src/features/history/checkin_detail_screen.dart';
import 'package:aura/src/features/history/history_screen.dart';
import 'package:aura/src/features/progress/progress_view.dart';
import 'package:aura/src/features/rooms/room_offer.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// F1 backfill: a check-in for one of the last 7 Aura days, added from
/// History. Stored with that day, it earns nothing, has no streak effect,
/// fires no capsule, completes no habit and gets no companion moment
/// (PRD F1, 06d; RULES.md §2).
void main() {
  final today = LocalDay.parse('2026-10-08'); // testNow, 15:30 IST

  /// Records whether the capsule step ever ran.
  final capsuleCalls = <String>[];
  Future<void> capsuleStep(
    BuildContext context,
    WidgetRef ref, {
    required String checkInId,
    required Mood mood,
    required bool crisisShown,
  }) async => capsuleCalls.add(checkInId);

  setUp(capsuleCalls.clear);

  Future<void> pumpHistory(
    WidgetTester tester,
    AppDatabase db, {
    TimeContext? time,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/history',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home page')),
        GoRoute(path: '/checkin', builder: (_, _) => const Text('checkin')),
        GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
        GoRoute(
          path: '/history/:id',
          builder: (_, s) => CheckInDetailScreen(id: s.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db, time: time),
          moodTriggerCapsuleStepProvider.overrideWithValue(capsuleStep),
        ],
        child: MaterialApp.router(
          theme: buildAuraTheme(const Locale('en')),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...systemLocalizationDelegates,
          ],
          routerConfig: router,
        ),
      ),
    );
    await settleIo(tester);
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tapVisible(tester, find.byKey(const ValueKey('history-add-past')));
    expect(find.text('Which day?'), findsOneWidget);
  }

  Future<void> pickDay(WidgetTester tester, LocalDay day) async {
    final tile = find.byKey(ValueKey('backfill-day-${day.toIso()}'));
    await tester.scrollUntilVisible(
      tile,
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tapVisible(tester, tile);
  }

  /// Picks [mood] (and a [note]) and saves the past check-in.
  Future<void> save(WidgetTester tester, String mood, {String? note}) async {
    await tapVisible(tester, find.byKey(ValueKey('mood-$mood')));
    if (note != null) {
      await tapVisible(tester, find.text('Add a tag or a few words'));
      final field = find.byKey(const ValueKey('checkin-note'));
      await tester.ensureVisible(field);
      await tester.enterText(field, note);
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

  /// Keeps the progress projection running (as Home does in the app) and
  /// returns a way to read it.
  Future<ProgressView Function()> watchProgress(WidgetTester tester) async {
    final sub = containerOf(tester).listen(progressViewProvider, (_, _) {});
    addTearDown(sub.close);
    await settleIo(tester);
    return sub.read;
  }

  testWidgets('"Add a past check-in" offers the last 7 days: yesterday back '
      'to a week ago, never today or 8 days back', (tester) async {
    await pumpHistory(tester, memoryDb());
    // Also in the empty state.
    expect(find.byKey(const ValueKey('history-add-past')), findsOneWidget);
    await openPicker(tester);
    expect(find.text('Yesterday'), findsOneWidget);
    for (var back = 1; back <= 7; back++) {
      final key = ValueKey('backfill-day-${today.addDays(-back).toIso()}');
      await tester.scrollUntilVisible(
        find.byKey(key),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byKey(key), findsOneWidget);
    }
    expect(find.byKey(ValueKey('backfill-day-${today.toIso()}')), findsNothing);
    expect(
      find.byKey(ValueKey('backfill-day-${today.addDays(-8).toIso()}')),
      findsNothing,
    );
    await end(tester);
  });

  testWidgets('a past check-in is saved for its day but stamped now; it '
      'earns nothing, leaves the streak alone, fires no capsule, gets no '
      'companion moment, and shows under its day as "Added later"', (
    tester,
  ) async {
    final db = memoryDb();
    await pumpHistory(tester, db);
    final progress = await watchProgress(tester);
    await openPicker(tester);
    final tuesday = today.addDays(-2);
    await pickDay(tester, tuesday);

    expect(find.text('How were you feeling?'), findsOneWidget);
    expect(find.text('Tuesday, October 6'), findsOneWidget);
    await save(tester, 'drained');

    // "Added to your sky": no Starlight, response, minute card or room.
    expect(find.text('Added to your sky'), findsOneWidget);
    expect(find.text('Saved for Tuesday, October 6.'), findsOneWidget);
    expect(find.textContaining('Starlight comes from'), findsOneWidget);
    expect(find.textContaining('+10'), findsNothing);
    expect(find.byType(CompanionReaction), findsNothing);
    expect(find.byType(CompanionLine), findsNothing);
    expect(find.byType(MinuteForYouCard), findsNothing);
    expect(find.byType(RoomOfferButton), findsNothing);
    expect(capsuleCalls, isEmpty);

    final row = (await io(tester, () => db.select(db.checkIns).get())).single;
    expect(row.localDay, '2026-10-06');
    expect(row.deviceTs.toUtc(), testNow);
    expect(row.tz, 'Asia/Kolkata');
    final m = (await io(tester, () => db.select(db.outbox).get())).single;
    expect(m.localDay, '2026-10-06');
    expect(m.deviceTs.toUtc(), testNow);
    final payload = jsonDecode(m.payload) as Map<String, dynamic>;
    expect(payload['source'], 'app'); // the server tells it by its day

    final view = progress();
    expect(view.loaded, isTrue);
    expect(view.awards[row.id], 0);
    expect(view.totalStarlight, 0);
    expect(view.todayStarlight, 0);
    expect(view.streak.lifetimeGlowDays, 0);
    expect(view.streak.glowStreak, 0);

    await tester.tap(find.byKey(const ValueKey('checkin-done')));
    await settleIo(tester);
    expect(find.byType(CheckInScreen), findsNothing);
    expect(find.text('Tuesday, October 6'), findsOneWidget); // its day
    expect(find.text('Drained'), findsOneWidget);
    expect(find.text('Added later'), findsOneWidget);
    await end(tester);
  });

  testWidgets('beside live check-ins: today\'s Starlight and the streak stay '
      'as they were, and a gap stays a gap', (tester) async {
    final db = memoryDb();
    await io(tester, () async {
      for (final at in [testNow.subtract(const Duration(days: 3)), testNow]) {
        await CheckInRepository(
          db,
          OutboxRepository(db, const Ids()),
          testTime(at),
        ).save(id: const Ids().v7(), mood: moodById('calm')!);
      }
    });
    await pumpHistory(tester, db);
    final progress = await watchProgress(tester);
    final before = progress();
    expect(before.todayStarlight, 10);
    expect(before.streak.lifetimeGlowDays, 2);

    // Fill the two days in between: they add nothing and bridge nothing.
    for (final back in [1, 2]) {
      await openPicker(tester);
      await pickDay(tester, today.addDays(-back));
      await save(tester, 'numb');
      await tester.tap(find.byKey(const ValueKey('checkin-done')));
      await settleIo(tester);
    }
    final after = progress();
    expect(after.todayStarlight, 10);
    expect(after.totalStarlight, before.totalStarlight);
    expect(after.streak, before.streak);
    await end(tester);
  });

  testWidgets('a long note on a past day completes no habit', (tester) async {
    final db = memoryDb();
    await pumpHistory(tester, db);
    await openPicker(tester);
    await pickDay(tester, today.addDays(-1));
    await save(
      tester,
      'content',
      note: 'Yesterday I finally called home and it was lovely to hear them.',
    );
    await settleIo(tester);
    expect(await io(tester, () => db.select(db.habitLogs).get()), isEmpty);
    expect(find.text('Journal is marked done for today.'), findsNothing);
    await end(tester);
  });

  testWidgets('the 04:00 rollover moved the day out of the window: a calm '
      'notice, nothing saved, the mood kept; another day saves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = memoryDb();
    final clock = FixedClock(testNow);
    final time = TimeContext(clock: clock, timezone: 'Asia/Kolkata');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db, time: time),
          moodTriggerCapsuleStepProvider.overrideWithValue(capsuleStep),
        ],
        child: localized(CheckInScreen(backfillDay: today.addDays(-7))),
      ),
    );
    await settleIo(tester);
    await tapVisible(tester, find.byKey(const ValueKey('mood-calm')));

    clock.instant = testNow.add(const Duration(days: 1)); // now 8 days back
    await tester.tap(find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('backfill-out-of-range')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('backfill-out-of-range')), findsOneWidget);
    expect(find.byKey(const ValueKey('mood-calm')), findsOneWidget);
    expect(await io(tester, () => db.select(db.checkIns).get()), isEmpty);

    // The notice's own "Change day".
    await tapVisible(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('backfill-out-of-range')),
        matching: find.text('Change day'),
      ),
    );
    final yesterday = today; // 8 Oct is yesterday now
    await pickDay(tester, yesterday);
    expect(
      find.byKey(const ValueKey('backfill-out-of-range'), skipOffstage: false),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);
    final row = (await io(tester, () => db.select(db.checkIns).get())).single;
    expect(row.moodId, 'calm');
    expect(row.localDay, '2026-10-08');
    await end(tester);
  });

  test('the repository refuses today and 8 days back', () async {
    final db = memoryDb();
    final repo = CheckInRepository(
      db,
      OutboxRepository(db, const Ids()),
      testTime(),
    );
    final mood = moodById('calm')!;
    await expectLater(
      repo.save(id: 'a', mood: mood, backfillDay: today),
      throwsA(isA<BackfillOutOfRange>()),
    );
    await expectLater(
      repo.save(id: 'b', mood: mood, backfillDay: today.addDays(-8)),
      throwsA(isA<BackfillOutOfRange>()),
    );
    final ok = await repo.save(
      id: 'c',
      mood: mood,
      backfillDay: today.addDays(-7),
    );
    expect(ok.localDay, '2026-10-01');
    expect(await db.select(db.checkIns).get(), hasLength(1));
    expect(isBackfillDay(today, today), isFalse);
    expect(isBackfillDay(today.addDays(-1), today), isTrue);
    await db.close();
  });

  testWidgets('its page reads "Yesterday · added later"', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = memoryDb();
    final id = await io(tester, () async {
      final row =
          await CheckInRepository(
            db,
            OutboxRepository(db, const Ids()),
            testTime(),
          ).save(
            id: const Ids().v7(),
            mood: moodById('grateful')!,
            backfillDay: today.addDays(-1),
          );
      return row.id;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: db),
        child: localized(CheckInDetailScreen(id: id)),
      ),
    );
    await settleIo(tester);
    expect(find.text('Yesterday · added later'), findsOneWidget);
    // Added a moment ago: the 24 h edit window is open.
    expect(find.byKey(const ValueKey('history-edit')), findsOneWidget);
    await end(tester);
  });

  test('aura_domain agrees (RULES.md §2): a backfill is no live event', () {
    const tz = 'Asia/Kolkata';
    final live = ProgressEvent.checkIn(
      id: 'live',
      deviceTs: testNow,
      localDay: today,
      quadrant: Quadrant.rain,
    );
    final back = ProgressEvent.checkIn(
      id: 'back',
      deviceTs: testNow,
      localDay: today.addDays(-1),
      quadrant: Quadrant.rain,
    );
    expect(
      isEligible(
        deviceTs: testNow,
        serverNow: testNow,
        timezone: tz,
        localDay: today.addDays(-1),
      ),
      isFalse,
    );
    final p = projectProgress(events: [back, live], now: testNow, timezone: tz);
    expect(p.awards['back'], 0);
    expect(p.awards['live'], 10); // the backfill takes no check-in slot
    expect(p.streak.lifetimeGlowDays, 1);
    expect(p.streak.lastActiveDay, today);
    final alone = projectProgress(events: [back], now: testNow, timezone: tz);
    expect(alone.totalStarlight, 0);
    expect(alone.streak.lastActiveDay, isNull);
    expect(alone.avatar.isResting, isFalse);
  });
}
