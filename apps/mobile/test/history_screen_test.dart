import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/history/checkin_detail_screen.dart';
import 'package:aura/src/features/history/history_screen.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// Private history (`/history`): newest first, grouped by Aura day, discreet
/// rows (never note text), offline from Drift; calm empty state.
void main() {
  GoRouter router() => GoRouter(
    initialLocation: '/history',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const Text('home page')),
      GoRoute(path: '/checkin', builder: (_, _) => const Text('checkin page')),
      GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
      GoRoute(
        path: '/history/:id',
        builder: (_, s) => CheckInDetailScreen(id: s.pathParameters['id']!),
      ),
    ],
  );

  Future<void> pumpApp(WidgetTester tester, AppDatabase db) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: db),
        child: MaterialApp.router(
          theme: buildAuraTheme(const Locale('en')),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...systemLocalizationDelegates,
          ],
          routerConfig: router(),
        ),
      ),
    );
    await settleIo(tester);
  }

  /// Saves a check-in as if made at [at] (IST zone).
  Future<String> seed(
    WidgetTester tester,
    AppDatabase db,
    DateTime at,
    String mood, {
    List<String> tags = const [],
    String? note,
    bool delete = false,
  }) async {
    final repo = CheckInRepository(
      db,
      OutboxRepository(db, const Ids()),
      TimeContext(clock: FixedClock(at), timezone: 'Asia/Kolkata'),
    );
    final id = const Ids().v7();
    await io(tester, () async {
      await repo.save(id: id, mood: moodById(mood)!, tags: tags, note: note);
      if (delete) await repo.delete(id);
    });
    return id;
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('grouped by Aura day with headings, newest first; rows show '
      'mood, time, tag count and a note icon but never the note', (
    tester,
  ) async {
    final db = memoryDb();
    final handle = tester.ensureSemantics();
    final today = await seed(
      tester,
      db,
      testNow, // 15:30 IST
      'calm',
      tags: ['family', 'exams'],
      note: 'secret words',
    );
    await seed(
      tester,
      db,
      testNow.subtract(const Duration(hours: 2)), // 13:30 IST
      'joyful',
    );
    await seed(tester, db, testNow, 'proud', delete: true);
    await seed(tester, db, testNow.subtract(const Duration(days: 1)), 'lonely');
    await seed(
      tester,
      db,
      testNow.subtract(const Duration(days: 5)),
      'anxious',
    );
    await pumpApp(tester, db);

    expect(find.text('Your check-ins'), findsOneWidget);
    expect(find.byType(HelpNowButton), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Saturday, October 3'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Today')),
      matchesSemantics(label: 'Today', isHeader: true),
    );

    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Joyful'), findsOneWidget);
    expect(find.text('Lonely'), findsOneWidget);
    expect(find.text('Anxious'), findsOneWidget);
    expect(find.text('Proud'), findsNothing); // deleted
    expect(find.text('secret words'), findsNothing); // never in the list
    expect(find.byKey(const ValueKey('history-note-icon')), findsOneWidget);
    expect(find.text('1:30 PM'), findsOneWidget); // Joyful, IST wall time

    // Newest first within a day, days newest first.
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Calm'), lessThan(y('Joyful')));
    expect(y('Joyful'), lessThan(y('Yesterday')));
    expect(y('Lonely'), lessThan(y('Saturday, October 3')));

    // A row is one 48 dp target that reads mood, tags, note and time.
    final row = find.byKey(ValueKey('history-$today'));
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    final label = tester.getSemantics(row).label;
    expect(label, contains('Calm'));
    expect(label, contains('2 tags'));
    expect(label, contains('Has a note'));
    expect(label, contains('3:30 PM'));
    expect(label, isNot(contains('secret')));

    await tester.tap(row);
    await settleIo(tester);
    expect(find.text('Your check-in'), findsOneWidget);
    expect(find.text('secret words'), findsOneWidget); // only on its page

    handle.dispose();
    await done(tester);
  });

  testWidgets('empty: calm copy and a Check in button', (tester) async {
    await pumpApp(tester, memoryDb());
    expect(
      find.text(
        'Nothing here yet. Your check-ins will gather here, and only you '
        'can see them.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('history-checkin')));
    await tester.pumpAndSettle();
    expect(find.text('checkin page'), findsOneWidget);
    await done(tester);
  });
}
