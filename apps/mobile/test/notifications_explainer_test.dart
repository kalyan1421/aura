import 'dart:convert';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/push/notification_prefs.dart';
import 'package:aura/src/features/push/push_explainer.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The post-check-in explainer (PRD 15-permissions "on the evening nudge
/// screen with a time picker"; 12-notifications rule 4 "discreet mode …
/// offered as a one-tap choice on the permission screen"): "Allow" turns the
/// daily reminder on at the time shown; the discreet choice applies whatever
/// the answer; "Not now" never shows the OS prompt.

class _Harness {
  _Harness(this.db, this.messaging, this.container);
  final AppDatabase db;
  final FakeMessaging messaging;
  final ProviderContainer container;

  Future<List<Map<String, dynamic>>> patches(WidgetTester tester) async {
    final rows = await io(tester, () => db.select(db.outbox).get());
    return [
      for (final r in rows)
        if (r.entity == 'notification_prefs')
          jsonDecode(r.payload) as Map<String, dynamic>,
    ];
  }

  Future<NotificationPrefs> prefs(WidgetTester tester) => io(
    tester,
    () => container.read(notificationPrefsRepositoryProvider).load(),
  );
}

Future<_Harness> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = memoryDb();
  // A saved check-in: the explainer is only ever offered after one.
  await io(
    tester,
    () => db
        .into(db.checkIns)
        .insert(
          CheckInsCompanion.insert(
            id: '0192f0c3-3333-7c1a-9b3d-000000000001',
            moodId: 'calm',
            quadrant: 'moonlight',
            localDay: '2026-10-08',
            tzOffsetMinutes: 330,
            deviceTs: testNow,
            tz: const Value('Asia/Kolkata'),
          ),
        ),
  );
  final messaging = FakeMessaging();
  final container = ProviderContainer(
    overrides: [
      ...testOverrides(db: db),
      pushMessagingProvider.overrideWithValue(messaging),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAuraTheme(const Locale('en')),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...systemLocalizationDelegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('offer'),
                onPressed: () => offerPushAfterCheckIn(context, ref),
                child: const Text('offer'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('offer')));
  await settleIo(tester);
  expect(find.text('Want a gentle nudge each evening?'), findsOneWidget);
  expect(find.text('Every evening at 20:00'), findsOneWidget);
  return _Harness(db, messaging, container);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('"Allow" at a picked time with discreet on: one OS prompt, the '
      'reminder on at that time, discreet on — one outbox patch', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('push-change-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '21');
    await tester.enterText(fields.at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Every evening at 21:30'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('push-discreet')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('push-allow')));
    await settleIo(tester);

    expect(h.messaging.requests, [false]);
    final p = await h.prefs(tester);
    expect(p.reminderEnabled, isTrue);
    expect(p.reminderTime, const DayTime(21, 30));
    expect(p.discreet, isTrue);
    expect(await h.patches(tester), [
      {'reminderEnabled': true, 'reminderTime': '21:30', 'discreet': true},
    ]);
    await _unmount(tester);
  });

  testWidgets('"Not now": no OS prompt (Android), the reminder stays off, but '
      'the discreet choice is kept', (tester) async {
    final h = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('push-discreet')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('push-not-now')));
    await settleIo(tester);

    expect(h.messaging.requests, isEmpty);
    final p = await h.prefs(tester);
    expect(p.reminderEnabled, isFalse);
    expect(p.discreet, isTrue);
    expect(await h.patches(tester), [
      {'discreet': true},
    ]);
    await _unmount(tester);
  });

  testWidgets(
    '"Allow" with the defaults: the reminder at the suggested 20:00',
    (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('push-allow')));
      await settleIo(tester);
      expect(await h.patches(tester), [
        {'reminderEnabled': true, 'reminderTime': '20:00'},
      ]);
      await _unmount(tester);
    },
  );
}
