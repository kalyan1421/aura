import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/history/checkin_detail_screen.dart';
import 'package:aura/src/features/history/history_screen.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// One check-in (`/history/:id`): view, edit within 24 h (same id, upsert),
/// delete any time (tombstone + delete mutation, Starlight kept). PRD F1.
void main() {
  late AppDatabase db;
  late String id;

  setUp(() => db = memoryDb());

  /// A check-in made at [testNow] (15:30 IST) with tags and a note.
  Future<void> seed(WidgetTester tester) async {
    final repo = CheckInRepository(
      db,
      OutboxRepository(db, const Ids()),
      testTime(),
    );
    id = const Ids().v7();
    await io(
      tester,
      () => repo.save(
        id: id,
        mood: moodById('calm')!,
        tags: ['family'],
        note: 'Tea on the terrace',
      ),
    );
  }

  /// Opens the history at [now] and taps the check-in.
  Future<void> open(WidgetTester tester, DateTime now) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: db, time: testTime(now)),
        child: MaterialApp.router(
          theme: buildAuraTheme(const Locale('en')),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...systemLocalizationDelegates,
          ],
          routerConfig: GoRouter(
            initialLocation: '/history',
            routes: [
              GoRoute(
                path: '/history',
                builder: (_, _) => const HistoryScreen(),
              ),
              GoRoute(
                path: '/history/:id',
                builder: (_, s) =>
                    CheckInDetailScreen(id: s.pathParameters['id']!),
              ),
            ],
          ),
        ),
      ),
    );
    await settleIo(tester);
    await tester.tap(find.byKey(ValueKey('history-$id')));
    await settleIo(tester);
  }

  Future<List<OutboxRow>> outbox(WidgetTester tester) => io(
    tester,
    () =>
        (db.select(db.outbox)..orderBy([(t) => OrderingTerm.asc(t.seq)])).get(),
  );

  Future<CheckInRow> row(WidgetTester tester) => io(
    tester,
    () => (db.select(db.checkIns)..where((t) => t.id.equals(id))).getSingle(),
  );

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  final edit = find.byKey(const ValueKey('history-edit'));
  final editClosed = find.byKey(const ValueKey('history-edit-closed'));
  final discardTitle = find.text('Leave without saving?');

  testWidgets('within a day: mood, time, tags, the private note, sync status '
      'and Edit', (tester) async {
    await seed(tester);
    await open(tester, testNow.add(const Duration(hours: 23)));

    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Moonlight'), findsOneWidget);
    expect(find.text('Yesterday, 3:30 PM'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Tea on the terrace'), findsOneWidget);
    expect(find.text('Only you can read this.'), findsOneWidget);
    expect(find.text('Saved on this phone'), findsOneWidget); // not synced
    expect(edit, findsOneWidget);
    expect(editClosed, findsNothing);
    await done(tester);
  });

  testWidgets('after 24 hours: a calm line instead of Edit; Delete stays', (
    tester,
  ) async {
    await seed(tester);
    await open(tester, testNow.add(const Duration(hours: 25)));

    expect(edit, findsNothing);
    expect(
      find.text('You can edit a check-in for a day after you make it.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('history-delete')), findsOneWidget);
    await done(tester);
  });

  testWidgets('an edit keeps the id and queues an upsert of it', (
    tester,
  ) async {
    await seed(tester);
    await open(tester, testNow.add(const Duration(hours: 2)));

    await tapVisible(tester, edit);
    await settleIo(tester); // the stored note is read first
    final save = find.byKey(const ValueKey('history-edit-save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull); // unchanged
    await tapVisible(tester, find.byKey(const ValueKey('mood-joyful')));
    await tapVisible(tester, save);
    await settleIo(tester);

    final r = await row(tester);
    expect(r.id, id);
    expect(r.moodId, 'joyful');
    expect(r.note, 'Tea on the terrace'); // kept
    expect(r.tags, ['family']);
    expect(await io(tester, () => db.select(db.checkIns).get()), hasLength(1));
    final m = await outbox(tester);
    expect(m, hasLength(2));
    expect(m.map((e) => e.op), [Ops.upsert, Ops.upsert]);
    expect(m.map((e) => e.entityId), [id, id]);

    expect(find.text('Joyful'), findsOneWidget); // back to the view
    expect(edit, findsOneWidget);
    await done(tester);
  });

  testWidgets('edited words that call for support: saved first, then the '
      'support sheet', (tester) async {
    await seed(tester);
    await open(tester, testNow.add(const Duration(hours: 2)));

    await tapVisible(tester, edit);
    await settleIo(tester); // the stored note is read first
    final note = find.byKey(const ValueKey('checkin-note'));
    await tester.scrollUntilVisible(note, 300);
    await tester.enterText(note, 'I want to die');
    await tester.pump();
    await tapVisible(tester, find.byKey(const ValueKey('history-edit-save')));
    await settleIo(tester);

    expect((await row(tester)).note, 'I want to die');
    expect(find.text('It sounds like a lot right now.'), findsOneWidget);
    await done(tester);
  });

  testWidgets('an unsaved edit: back and Cancel ask first; Discard keeps '
      'the check-in as it was', (tester) async {
    await seed(tester);
    await open(tester, testNow.add(const Duration(hours: 2)));

    await tapVisible(tester, edit);
    await settleIo(tester); // the stored note is read first
    await tapVisible(tester, find.byKey(const ValueKey('mood-anxious')));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(discardTitle, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('discard-keep')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history-edit-save')), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('history-edit-cancel')));
    expect(discardTitle, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('discard-confirm')));
    await tester.pumpAndSettle();
    expect(edit, findsOneWidget);
    expect((await row(tester)).moodId, 'calm');
    expect(await outbox(tester), hasLength(1));
    await done(tester);
  });

  testWidgets('delete asks first (Cancel is the default), then tombstones, '
      'queues a delete and keeps Starlight and glow days', (tester) async {
    await seed(tester);
    final progress = ProgressRepository(db, KvStore(db));
    Future<ProgressProjection> project() async => projectProgress(
      events: await io(tester, () => progress.watchEvents().first),
      now: testNow.add(const Duration(days: 3)),
      timezone: 'Asia/Kolkata',
    );
    final before = await project();
    expect(before.totalStarlight, 10);

    await open(tester, testNow.add(const Duration(days: 3)));
    final delete = find.byKey(const ValueKey('history-delete'));
    await tapVisible(tester, delete);
    expect(find.text('Delete this check-in?'), findsOneWidget);
    expect(
      find.text("This doesn't change your Starlight or glow days."),
      findsOneWidget,
    );
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
      focused?.findAncestorWidgetOfExactType<TextButton>()?.key,
      const ValueKey('delete-cancel'),
    );
    await tester.tap(find.byKey(const ValueKey('delete-cancel')));
    await tester.pumpAndSettle();
    expect((await row(tester)).deletedAt, isNull);

    await tapVisible(tester, delete);
    await tester.tap(find.byKey(const ValueKey('delete-confirm')));
    await settleIo(tester);

    final r = await row(tester);
    expect(r.deletedAt, isNotNull);
    final m = await outbox(tester);
    expect(m.last.op, Ops.delete);
    expect(m.last.entity, Entities.checkIn);
    expect(m.last.entityId, id);

    // Back on the (now empty) history.
    expect(find.text('Your check-ins'), findsOneWidget);
    expect(find.byKey(ValueKey('history-$id')), findsNothing);

    final after = await project();
    expect(after.totalStarlight, before.totalStarlight);
    expect(after.streak.lifetimeGlowDays, before.streak.lifetimeGlowDays);
    await done(tester);
  });
}
