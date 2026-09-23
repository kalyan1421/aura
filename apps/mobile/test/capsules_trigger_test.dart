import 'dart:convert';
import 'dart:io';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/capsules/capsule_hooks.dart';
import 'package:aura/src/features/capsules/capsule_media_store.dart';
import 'package:aura/src/features/capsules/capsule_repository.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capsules_fakes.dart';
import 'helpers.dart';
import 'voice_fakes.dart';

/// The F4 step of the check-in post-save order: RULES.md §9 on this phone —
/// a matching armed capsule fires as its card appears ("Now" opens it,
/// "Later" leaves it fired and unopened); after a crisis sheet it is held
/// ("Now" counts as the fire, "Later" records nothing, no cooldown);
/// backfills and the 7-day cooldown fire nothing. In-app only.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  late Directory root;
  late AppDatabase db;
  late CapsuleMediaStore store;

  void capsuleWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aura-capsule-trigger');
    db = memoryDb();
    store = tempCapsuleStore(root);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  CapsuleRepository repo(DateTime at) => CapsuleRepository(
    db,
    OutboxRepository(db, const Ids()),
    TimeContext(clock: FixedClock(at), timezone: 'Asia/Kolkata'),
    store: store,
    cipher: () async => testCipher(),
  );

  /// A storm capsule sealed two days ago (armed), and a check-in now.
  Future<String> seed(
    WidgetTester tester, {
    String mood = 'anxious',
    bool backfill = false,
    DateTime? firedElsewhere,
  }) => io(tester, () async {
    final r = repo(testNow.subtract(const Duration(days: 2)));
    await r.seal(
      id: 'cap',
      content: const CapsuleContent(
        title: 'For a storm',
        text: 'You got this.',
      ),
      unlock: const MoodUnlock.quadrant(Quadrant.storm),
    );
    if (firedElsewhere != null) {
      await r.seal(
        id: 'other',
        content: const CapsuleContent(text: 'x'),
        unlock: const MoodUnlock.mood('calm'),
      );
      await repo(firedElsewhere).fire('other');
    }
    final checkIns = CheckInRepository(
      db,
      OutboxRepository(db, const Ids()),
      testTime(),
    );
    final id = const Ids().v7();
    await checkIns.save(
      id: id,
      mood: moodById(mood)!,
      backfillDay: backfill ? testTime().today().addDays(-1) : null,
    );
    return id;
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    required String checkInId,
    String mood = 'anxious',
    bool crisis = false,
    required List<String> steps,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(
            db: db,
            auth: SignedInAuth(),
            secure: secureWithKey(),
          ),
          ...capsuleOverrides(store: store),
          ...voiceOverrides(),
        ],
        child: MaterialApp(
          theme: buildAuraTheme(const Locale('en')),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...systemLocalizationDelegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    steps.add('capsule step');
                    await runMoodTriggerCapsuleStep(
                      context,
                      ref,
                      checkInId: checkInId,
                      mood: moodById(mood)!,
                      crisisShown: crisis,
                    );
                    steps.add('saved moment');
                  },
                  child: const Text('saved'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleIo(tester);
  }

  Future<CapsuleRow> row(WidgetTester tester, [String id = 'cap']) async =>
      (await io<CapsuleRow?>(tester, () => repo(testNow).row(id)))!;

  Future<List<String>> ops(WidgetTester tester) async {
    final rows = await io(tester, () => db.select(db.outbox).get());
    return [
      for (final r in rows)
        if (r.entity == Entities.capsule && r.entityId == 'cap') r.op,
    ];
  }

  Future<void> run(WidgetTester tester) async {
    await tester.tap(find.text('saved'));
    await settleIo(tester);
  }

  capsuleWidgets(
    'a match fires as the card appears; "Later" keeps it unopened',
    (tester) async {
      final ci = await seed(tester);
      final steps = <String>[];
      await pumpHost(tester, checkInId: ci, steps: steps);
      await run(tester);
      expect(find.text(en.capsules_triggerTitle), findsOneWidget);
      expect(steps, ['capsule step'], reason: 'the next step waits');
      var r = await row(tester);
      expect(r.firedAt, testNow, reason: 'fired when the card appears');
      expect(r.cooldownUntil, testNow.add(const Duration(hours: 168)));

      await tester.tap(find.byKey(const ValueKey('capsule-later')));
      await settleIo(tester);
      expect(steps, ['capsule step', 'saved moment']);
      r = await row(tester);
      expect(r.openedAt, isNull);
      expect(await ops(tester), [Ops.seal, Ops.fire]);
      final fire = (await io(tester, () => db.select(db.outbox).get())).last;
      expect(jsonDecode(fire.payload), {'id': 'cap', 'cycle': 0});
    },
  );

  capsuleWidgets('"Now" opens it (ceremony, then the note) — one-way', (
    tester,
  ) async {
    final ci = await seed(tester);
    final steps = <String>[];
    await pumpHost(tester, checkInId: ci, steps: steps);
    await run(tester);
    await tester.tap(find.byKey(const ValueKey('capsule-now')));
    await settleIo(tester);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('You got this.'), findsOneWidget);
    expect((await row(tester)).openedAt, isNotNull);
    expect(await ops(tester), [Ops.seal, Ops.fire, Ops.open]);
    expect(
      find.byKey(const ValueKey('capsule-keep-next-time')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('capsule-done')));
    await settleIo(tester);
    expect(steps, ['capsule step', 'saved moment']);
  });

  capsuleWidgets(
    'crisis collision: held; "Later" records nothing (no cooldown)',
    (tester) async {
      final ci = await seed(tester);
      final steps = <String>[];
      await pumpHost(tester, checkInId: ci, crisis: true, steps: steps);
      await run(tester);
      expect(find.text(en.capsules_holdTitle), findsOneWidget);
      expect(find.text(en.capsules_triggerTitle), findsNothing);
      await tester.tap(find.byKey(const ValueKey('capsule-later')));
      await settleIo(tester);
      final r = await row(tester);
      expect(r.firedAt, isNull, reason: 'stays armed');
      expect(r.cooldownUntil, isNull, reason: 'no cooldown');
      expect(await ops(tester), [Ops.seal]);
      expect(steps, ['capsule step', 'saved moment']);
    },
  );

  capsuleWidgets('crisis collision: "Now" counts as the fire, then opens', (
    tester,
  ) async {
    final ci = await seed(tester);
    await pumpHost(tester, checkInId: ci, crisis: true, steps: []);
    await run(tester);
    await tester.tap(find.byKey(const ValueKey('capsule-now')));
    await settleIo(tester);
    await tester.pump(const Duration(milliseconds: 350));
    final r = await row(tester);
    expect(r.firedAt, testNow);
    expect(r.cooldownUntil, isNotNull);
    expect(r.openedAt, isNotNull);
    expect(await ops(tester), [Ops.seal, Ops.fire, Ops.open]);
  });

  capsuleWidgets('a backfill fires nothing', (tester) async {
    final ci = await seed(tester, backfill: true);
    final steps = <String>[];
    await pumpHost(tester, checkInId: ci, steps: steps);
    await run(tester);
    expect(find.text(en.capsules_triggerTitle), findsNothing);
    expect(steps, ['capsule step', 'saved moment']);
    expect((await row(tester)).firedAt, isNull);
  });

  capsuleWidgets('REQ-CAP-03: nothing fires within 7 days of the last fire', (
    tester,
  ) async {
    final ci = await seed(
      tester,
      firedElsewhere: testNow.subtract(const Duration(days: 1)),
    );
    final steps = <String>[];
    await pumpHost(tester, checkInId: ci, steps: steps);
    await run(tester);
    expect(find.text(en.capsules_triggerTitle), findsNothing);
    expect(steps, ['capsule step', 'saved moment']);
  });

  capsuleWidgets('another feeling fires nothing', (tester) async {
    final ci = await seed(tester, mood: 'calm');
    final steps = <String>[];
    await pumpHost(tester, checkInId: ci, mood: 'calm', steps: steps);
    await run(tester);
    expect(find.text(en.capsules_triggerTitle), findsNothing);
    expect(steps, ['capsule step', 'saved moment']);
  });
}
