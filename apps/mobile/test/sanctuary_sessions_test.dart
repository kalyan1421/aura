import 'dart:convert';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/sanctuary/breath_haptics.dart';
import 'package:aura/src/features/sanctuary/breath_pacer.dart';
import 'package:aura/src/features/sanctuary/breathe_session_screen.dart';
import 'package:aura/src/features/sanctuary/sanctuary_session_log.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_session_log.dart';
import 'package:aura/src/features/sanctuary/steps_activity_screen.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _QuietHaptics implements BreathHaptics {
  @override
  void phaseStarted(BreathPhase phase) {}
}

class FakeSessionLog implements SanctuarySessionLog {
  final List<SanctuarySession> records = [];

  @override
  Future<bool> record(SanctuarySession session) async {
    records.add(session);
    return true;
  }
}

/// F15 session records (PRD 06d "A finished activity writes one
/// content-free session record"): each Sanctuary activity writes exactly one
/// record when it is finished and none when it is abandoned; Sounds and the
/// wind-down go through the same log; the real log is one `sanctuary_session`
/// mutation in the outbox, content-free, only for an onboarded person.
void main() {
  final today = testTime().today();

  Future<FakeSessionLog> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final log = FakeSessionLog();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: memoryDb()),
          breathHapticsProvider.overrideWithValue(_QuietHaptics()),
          sanctuarySessionLogProvider.overrideWithValue(log),
        ],
        child: localized(screen),
      ),
    );
    await tester.pump();
    return log;
  }

  Future<void> breathe(WidgetTester tester, Duration d) async {
    var left = d;
    const step = Duration(milliseconds: 250);
    while (left > Duration.zero) {
      final s = left < step ? left : step;
      await tester.pump(s);
      left -= s;
    }
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  group('breathing sessions', () {
    testWidgets('a finished 1-minute Calm session → one breathe/calm record', (
      tester,
    ) async {
      final log = await open(
        tester,
        const BreatheSessionScreen(autoStart: true),
      );
      await breathe(tester, const Duration(seconds: 62));
      expect(find.byKey(const ValueKey('breathe-done')), findsOneWidget);
      expect(log.records, [
        SanctuarySession(
          activity: 'breathe',
          variant: 'calm',
          durationS: 60,
          localDay: today,
        ),
      ]);
      await leave(tester);
      expect(log.records, hasLength(1));
    });

    testWidgets('abandoned mid-way (left without Finish) → no record', (
      tester,
    ) async {
      final log = await open(
        tester,
        const BreatheSessionScreen(pattern: BreathPattern.box, autoStart: true),
      );
      await breathe(tester, const Duration(seconds: 20));
      await leave(tester);
      expect(log.records, isEmpty);
    });

    testWidgets('"Finish" early is a finished session (its active seconds); '
        '"Again" starts a new one', (tester) async {
      final log = await open(
        tester,
        const BreatheSessionScreen(
          pattern: BreathPattern.fourSevenEight,
          autoStart: true,
        ),
      );
      await breathe(tester, const Duration(seconds: 10));
      await tester.tap(find.byKey(const ValueKey('breathe-finish')));
      await tester.pump();
      expect(log.records.single.variant, '478');
      expect(log.records.single.durationS, inInclusiveRange(9, 11));
      await tester.tap(find.byKey(const ValueKey('breathe-again')));
      await tester.pump();
      await breathe(tester, const Duration(seconds: 5));
      await leave(tester);
      expect(log.records, hasLength(1)); // the second one was abandoned
    });

    for (final (guide, activity, variant, length) in [
      (BreathGuide.land, 'grounding', 'land', 30),
      (BreathGuide.heart, 'grounding', 'heart', 60),
      (BreathGuide.stillness, 'stillness', 'orb', 60),
    ]) {
      testWidgets('${guide.name} → $activity/$variant once finished', (
        tester,
      ) async {
        final log = await open(tester, BreatheSessionScreen(guide: guide));
        await breathe(tester, Duration(seconds: length + 2));
        expect(log.records, [
          SanctuarySession(
            activity: activity,
            variant: variant,
            durationS: length,
            localDay: today,
          ),
        ]);
        await leave(tester);
      });
    }
  });

  group('step-through activities', () {
    for (final (a, activity, variant, steps) in [
      (StepsActivity.senses, 'grounding', 'senses', 5),
      (StepsActivity.gratitude, 'grounding', 'gratitude', 3),
      (StepsActivity.savour, 'savour', 'moment', 3),
    ]) {
      testWidgets('${a.name}: through every step → one $activity/$variant', (
        tester,
      ) async {
        final log = await open(tester, StepsActivityScreen(activity: a));
        for (var i = 0; i < steps; i++) {
          await tester.tap(find.byKey(const ValueKey('steps-next')));
          await tester.pump(const Duration(milliseconds: 400));
        }
        expect(find.byKey(const ValueKey('steps-done')), findsOneWidget);
        expect(log.records, hasLength(1));
        expect(log.records.single.activity, activity);
        expect(log.records.single.variant, variant);
        expect(log.records.single.localDay, today);
        expect(log.records.single.durationS, greaterThanOrEqualTo(1));
        await tester.tap(find.byKey(const ValueKey('steps-finish')));
        await tester.pump();
        expect(log.records, hasLength(1));
        await leave(tester);
      });
    }

    testWidgets('left before the end → no record', (tester) async {
      final log = await open(
        tester,
        const StepsActivityScreen(activity: StepsActivity.senses),
      );
      await tester.tap(find.byKey(const ValueKey('steps-next')));
      await tester.pump(const Duration(milliseconds: 400));
      await leave(tester);
      expect(log.records, isEmpty);
    });
  });

  group('Sounds and the night wind-down', () {
    test('Sounds sessions go into the Sanctuary log unchanged', () async {
      final log = FakeSessionLog();
      final sounds = SanctuarySoundsSessionLog(log);
      await sounds.record(
        SoundsSessionRecord(
          activity: 'sounds',
          variant: 'timer_30',
          durationS: 1790,
          localDay: today,
        ),
      );
      await sounds.record(
        SoundsSessionRecord(
          activity: 'night_wind_down',
          variant: 'v1',
          durationS: 1200,
          localDay: today,
        ),
      );
      expect(log.records.map((r) => '${r.activity}/${r.variant}'), [
        'sounds/timer_30',
        'night_wind_down/v1',
      ]);
    });

    test('the app default is no longer a no-op', () {
      final c = ProviderContainer(
        overrides: [
          sanctuarySessionLogProvider.overrideWithValue(FakeSessionLog()),
        ],
      );
      addTearDown(c.dispose);
      expect(
        c.read(soundsSessionLogProvider),
        isA<SanctuarySoundsSessionLog>(),
      );
    });
  });

  group('OutboxSanctuarySessionLog', () {
    OutboxSanctuarySessionLog make(
      AppDatabase db,
      GateState gate,
      FakeSync sync,
    ) => OutboxSanctuarySessionLog(
      db: db,
      outbox: OutboxRepository(db, const Ids()),
      ids: const Ids(),
      time: testTime,
      gate: () => gate,
      notifySync: sync.notifyLocalWrite,
    );

    test(
      'one content-free sanctuary_session mutation, then a sync nudge',
      () async {
        final db = memoryDb();
        addTearDown(db.close);
        final sync = FakeSync();
        final log = make(
          db,
          const GateState(stage: OnboardingStage.done),
          sync,
        );
        const day = LocalDay(2026, 10, 7);
        expect(
          await log.record(
            const SanctuarySession(
              activity: 'grounding',
              variant: 'senses',
              durationS: 95,
              localDay: day,
            ),
          ),
          isTrue,
        );
        final rows = await db.select(db.outbox).get();
        expect(rows, hasLength(1));
        final r = rows.single;
        expect(r.entity, 'sanctuary_session');
        expect(r.op, 'upsert');
        expect(r.localDay, '2026-10-07');
        expect(r.tz, 'Asia/Kolkata');
        final payload = jsonDecode(r.payload) as Map<String, dynamic>;
        expect(payload.keys.toSet(), {
          'id',
          'activity',
          'variant',
          'durationS',
        });
        expect(payload['id'], r.entityId);
        expect(payload, containsPair('durationS', 95));
        expect(sync.writes, 1);
      },
    );

    test('nothing before onboarding / behind the lock, or under a second; '
        'longer than 12 h is clamped', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final s = SanctuarySession(
        activity: 'sounds',
        variant: 'open',
        durationS: 60,
        localDay: today,
      );
      expect(
        await make(
          db,
          const GateState(stage: OnboardingStage.dob),
          FakeSync(),
        ).record(s),
        isFalse,
      );
      final ok = make(
        db,
        const GateState(stage: OnboardingStage.done),
        FakeSync(),
      );
      expect(
        await ok.record(
          SanctuarySession(
            activity: 'sounds',
            variant: 'open',
            durationS: 0,
            localDay: today,
          ),
        ),
        isFalse,
      );
      expect(await db.select(db.outbox).get(), isEmpty);
      await ok.record(
        SanctuarySession(
          activity: 'sounds',
          variant: 'open',
          durationS: 50000,
          localDay: today,
        ),
      );
      final p = jsonDecode((await db.select(db.outbox).getSingle()).payload);
      expect((p as Map)['durationS'], maxSessionSeconds);
    });
  });

  test('"Sanctuary opened this evening" (local only) counts from 18:00 of '
      'the Aura day', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final kv = KvStore(db);
    final evening = DateTime(2026, 10, 8, 22, 30);
    expect(await sanctuaryOpenedThisEvening(kv, evening), isFalse);
    await markSanctuaryOpened(kv, DateTime(2026, 10, 8, 17, 30));
    expect(await sanctuaryOpenedThisEvening(kv, evening), isFalse);
    await markSanctuaryOpened(kv, DateTime(2026, 10, 8, 19, 0));
    expect(await sanctuaryOpenedThisEvening(kv, evening), isTrue);
    // After midnight it is still the same evening; the next evening isn't.
    expect(
      await sanctuaryOpenedThisEvening(kv, DateTime(2026, 10, 9, 1, 0)),
      isTrue,
    );
    expect(
      await sanctuaryOpenedThisEvening(kv, DateTime(2026, 10, 9, 22, 0)),
      isFalse,
    );
  });
}
