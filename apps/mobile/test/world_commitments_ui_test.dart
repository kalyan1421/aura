import 'dart:convert';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura/src/features/habits/habits_section.dart';
import 'package:aura/src/features/universe/universe_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// W03: the Grove shows one plant per habit with an accessible list, decay is
/// warm and reversible, and Commitments in the editor are for adults only.

const _adultDob = '1996-01-01';
const _teenDob = '2012-01-01';

Future<void> _seed(
  WidgetTester tester,
  AppDatabase db, {
  required String dob,
  String? committedFrom,
}) => io(tester, () async {
  await KvStore(db).set(KvKeys.birthDate, dob);
  await db
      .into(db.habits)
      .insert(
        HabitsCompanion.insert(
          id: 'h1',
          kind: 'custom',
          name: const Value('Read'),
          createdAt: testNow,
          updatedAt: testNow,
          committedFrom: Value(committedFrom),
        ),
      );
});

HabitRepository _repo(AppDatabase db) => HabitRepository(
  db,
  OutboxRepository(db, const Ids()),
  testTime(),
  const Ids(),
);

Future<void> _end(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

Future<void> _pumpGrove(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(db: db),
      child: localized(const UniverseScreen()),
    ),
  );
  await settleIo(tester);
}

void main() {
  testWidgets('an adult who committed sees a warm resting plant; one log '
      'wakes it and it grows', (tester) async {
    final db = memoryDb();
    await _seed(tester, db, dob: _adultDob, committedFrom: '2026-10-01');
    await _pumpGrove(tester, db);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('universe-plants-resting')),
      250,
    );
    expect(
      find.text('One plant is resting. A single log wakes it.'),
      findsOneWidget,
    );
    expect(find.text('Your plants'), findsOneWidget);
    expect(find.text('Read, Seed, Drooping a little'), findsOneWidget);
    // Presets are plants too, and a thriving one needs no extra word.
    expect(find.text('Hydrate, Seed'), findsOneWidget);
    // Never dead, lost or a count of missed days.
    expect(find.textContaining(RegExp('dead|lost|failed|streak')), findsNothing);
    expect(find.textContaining(RegExp(r'\d+ (days|day)')), findsNothing);

    await io(tester, () => _repo(db).toggleCustomToday('h1'));
    await settleIo(tester);
    expect(find.byKey(const ValueKey('universe-plants-resting')), findsNothing);
    expect(find.text('Read, Sprout'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _end(tester, db);
  });

  testWidgets('under 18 the same stored commitment never shows a resting '
      'plant', (tester) async {
    final db = memoryDb();
    await _seed(tester, db, dob: _teenDob, committedFrom: '2026-10-01');
    await _pumpGrove(tester, db);
    await tester.scrollUntilVisible(find.text('Your plants'), 250);
    expect(find.byKey(const ValueKey('universe-plants-resting')), findsNothing);
    expect(find.text('Read, Seed'), findsOneWidget);
    await _end(tester, db);
  });

  group('Commitments in the habits editor', () {
    /// The sheet's own list (the add field holds another Scrollable inside it).
    final sheetList = find
        .descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.byType(Scrollable),
        )
        .first;

    Future<void> openEditor(WidgetTester tester, AppDatabase db) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db: db),
          child: localized(
            const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: HabitsSection(),
              ),
            ),
          ),
        ),
      );
      await settleIo(tester);
      await tester.tap(find.byKey(const ValueKey('habits-edit')));
      await settleIo(tester);
    }

    Future<List<Map<String, Object?>>> outbox(
      WidgetTester tester,
      AppDatabase db,
    ) => io(
      tester,
      () async => [
        for (final r in await db.select(db.outbox).get())
          jsonDecode(r.payload) as Map<String, Object?>,
      ],
    );

    testWidgets('an adult commits a habit, pauses it and ends the pause; '
        'each change is one explicit upsert', (tester) async {
      final db = memoryDb();
      await _seed(tester, db, dob: _adultDob);
      await openEditor(tester, db);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('habits-commitments-body')),
        250,
        scrollable: sheetList,
      );
      expect(find.text('Commitments'), findsOneWidget);
      expect(
        find.textContaining('Starlight and glow days are never touched'),
        findsOneWidget,
      );

      final sw = find.byKey(const ValueKey('commitment-switch-h1'));
      await tester.scrollUntilVisible(
        sw,
        150,
        scrollable: sheetList,
      );
      await tester.tap(sw);
      await settleIo(tester);
      var row = await io(tester, () => db.select(db.habits).getSingle());
      expect(row.committedFrom, '2026-10-08');
      var sent = await outbox(tester, db);
      expect(sent.last, containsPair('committedFrom', '2026-10-08'));
      expect(sent.last, containsPair('pausedThrough', null));

      await tester.tap(find.byKey(const ValueKey('commitment-pause-h1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days'));
      await settleIo(tester);
      row = await io(tester, () => db.select(db.habits).getSingle());
      expect(row.pausedThrough, '2026-10-15');
      expect(find.textContaining('Paused until'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('commitment-pause-h1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End pause'));
      await settleIo(tester);
      row = await io(tester, () => db.select(db.habits).getSingle());
      expect(row.pausedThrough, isNull);
      expect(row.committedFrom, '2026-10-08');

      await tester.tap(sw); // off again
      await settleIo(tester);
      row = await io(tester, () => db.select(db.habits).getSingle());
      expect(row.committedFrom, isNull);
      sent = await outbox(tester, db);
      expect(sent.last, containsPair('committedFrom', null));
      expect(tester.takeException(), isNull);
      await _end(tester, db);
    });

    testWidgets('a preset that was never used gets its row when committed',
        (tester) async {
      final db = memoryDb();
      await io(tester, () => KvStore(db).set(KvKeys.birthDate, _adultDob));
      await openEditor(tester, db);
      final sw = find.byKey(const ValueKey('commitment-switch-hydrate'));
      await tester.scrollUntilVisible(
        sw,
        150,
        scrollable: sheetList,
      );
      await tester.tap(sw);
      await settleIo(tester);
      final rows = await io(tester, () => db.select(db.habits).get());
      final hydrate = rows.singleWhere((h) => h.presetKey == 'hydrate');
      expect(hydrate.committedFrom, '2026-10-08');
      await _end(tester, db);
    });

    testWidgets('under 18 there is no Commitments section at all',
        (tester) async {
      final db = memoryDb();
      await _seed(tester, db, dob: _teenDob);
      await openEditor(tester, db);
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('habits-add-field')),
        sheetList,
        const Offset(0, -200),
      );
      expect(find.text('Commitments'), findsNothing);
      expect(
        find.byKey(const ValueKey('habits-commitments-body')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('commitment-switch-h1')), findsNothing);
      await _end(tester, db);
    });
  });
}
