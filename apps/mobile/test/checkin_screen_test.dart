import 'dart:convert';

import 'package:aura/src/app.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Scrolls a mood tile into view (large layouts scroll), then taps it.
Future<void> tapMood(WidgetTester tester, String id) async {
  final tile = find.byKey(ValueKey('mood-$id'));
  await tester.ensureVisible(tile);
  await tester.pump();
  await tester.tap(tile);
}

void main() {
  testWidgets('mood-only check-in: 2 taps saves locally and queues one '
      'outbox mutation (REQ-CHK-01/02)', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = memoryDb();
    final sync = FakeSync();
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: db, sync: sync),
        child: localized(const CheckInScreen()),
      ),
    );
    await tester.pump();

    // Tap 1: a mood. Tap 2: Save.
    await tapMood(tester, 'calm');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);

    final checkIns = await io(tester, () => db.select(db.checkIns).get());
    expect(checkIns, hasLength(1));
    final c = checkIns.single;
    expect(c.moodId, 'calm');
    expect(c.quadrant, 'moonlight');
    expect(c.localDay, '2026-10-08'); // Aura day in Asia/Kolkata
    expect(c.note, isNull);

    final outbox = await io(tester, () => db.select(db.outbox).get());
    expect(outbox, hasLength(1));
    final m = outbox.single;
    expect(m.entity, 'check_in');
    expect(m.op, 'upsert');
    expect(m.entityId, c.id);
    expect(m.needsNote, isFalse);
    final payload = jsonDecode(m.payload) as Map<String, dynamic>;
    expect(payload['moodId'], 'calm');
    expect(payload['noteCt'], isNull);
    expect(payload.containsKey('note'), isFalse); // never plaintext
    expect(sync.writes, 1);

    // The reward moment: the first check-in of the day earns 10.
    expect(find.text('+10 Starlight'), findsOneWidget);
    // F5 Mood Rooms don't exist yet: no disabled "coming soon" button.
    expect(find.text('Join a room of people feeling this'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('first check-in: Done finishes onboarding and lands on Home',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = memoryDb();
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          db: db,
          gate: const GateState(stage: OnboardingStage.firstCheckIn),
        ),
        child: const AuraApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tapMood(tester, 'joyful');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);
    await tester.tap(find.byKey(const ValueKey('checkin-done')));
    await settleIo(tester);

    expect(find.byKey(const ValueKey('home-checkin')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('after the first check-in, Done offers notifications once: the '
      'warm explainer comes before any OS prompt', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = memoryDb();
    final messaging = FakeMessaging();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(
            db: db,
            gate: const GateState(stage: OnboardingStage.firstCheckIn),
          ),
          pushMessagingProvider.overrideWithValue(messaging),
        ],
        child: const AuraApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Nothing at launch.
    expect(find.byKey(const ValueKey('push-allow')), findsNothing);

    await tapMood(tester, 'calm');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);
    expect(messaging.requests, isEmpty); // not on save either
    await tester.tap(find.byKey(const ValueKey('checkin-done')));
    await settleIo(tester);

    expect(find.text('Want a gentle nudge each evening?'), findsOneWidget);
    expect(messaging.requests, isEmpty); // explainer first
    await tester.tap(find.byKey(const ValueKey('push-allow')));
    await settleIo(tester);

    expect(messaging.requests, [false]); // the one real OS prompt
    expect(find.byKey(const ValueKey('home-checkin')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Save is disabled until a mood is picked; a double tap saves '
      'once', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = memoryDb();
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: db),
        child: localized(const CheckInScreen()),
      ),
    );
    await tester.pump();

    final save = find.byKey(const ValueKey('checkin-save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tapMood(tester, 'anxious');
    await tester.pump();
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await settleIo(tester);

    expect(await io(tester, () => db.select(db.checkIns).get()), hasLength(1));
    expect(await io(tester, () => db.select(db.outbox).get()), hasLength(1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a note is flagged for encryption and kept out of the payload',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = memoryDb();
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: db),
        child: localized(const CheckInScreen()),
      ),
    );
    await tester.pump();

    await tapMood(tester, 'grateful');
    // The details row grows in (AnimatedSize) before it can be tapped.
    await tester.pumpAndSettle();
    final list = find.byType(ListView).first;
    Future<void> reveal(Finder f) async {
      for (var i = 0; i < 30 && f.hitTestable().evaluate().isEmpty; i++) {
        await tester.drag(list, const Offset(0, -120));
        await tester.pumpAndSettle();
      }
    }

    await reveal(find.text('Add a tag or a few words'));
    await tester.tap(find.text('Add a tag or a few words').hitTestable());
    await tester.pumpAndSettle();
    await reveal(find.text('Family'));
    await tester.tap(find.text('Family').hitTestable());
    await tester.pumpAndSettle();
    final note = find.widgetWithText(TextField, 'A few words, if you like');
    await reveal(note);
    await tester.enterText(note, 'Dinner with Amma');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);

    final row = (await io(tester, () => db.select(db.checkIns).get())).single;
    expect(row.note, 'Dinner with Amma');
    expect(row.tags, ['family']);
    final m = (await io(tester, () => db.select(db.outbox).get())).single;
    expect(m.needsNote, isTrue);
    expect(m.payload.contains('Amma'), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
