import 'dart:convert';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/a11y/haptics.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura/src/features/habits/habits_section.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

HabitRepository _repo(AppDatabase db) =>
    HabitRepository(db, OutboxRepository(db, const Ids()), testTime(), const Ids());

Future<List<Map<String, Object?>>> _mutations(AppDatabase db) async => [
  for (final r in await db.select(db.outbox).get())
    {
      'entity': r.entity,
      'op': r.op,
      ...(jsonDecode(r.payload) as Map<String, Object?>),
    },
];

const LocalDay _today = LocalDay(2026, 10, 8);

void main() {
  group('HabitRepository', () {
    late AppDatabase db;
    late HabitRepository repo;

    setUp(() {
      db = memoryDb();
      repo = _repo(db);
    });
    tearDown(() => db.close());

    test('hiding a preset: habit upsert with active false; Home drops it; '
        'showing it again re-sends active true', () async {
      await repo.setPresetShown(PresetHabitKeys.hydrate, false);
      var today = await repo.watchToday(_today).first;
      expect(today.map((h) => h.key), isNot(contains('hydrate')));
      expect(today, hasLength(5));

      await repo.setPresetShown(PresetHabitKeys.hydrate, true);
      today = await repo.watchToday(_today).first;
      expect(today.first.key, 'hydrate');

      final m = await _mutations(db);
      expect(m, hasLength(2));
      expect(m.map((x) => x['entity']), everyElement('habit'));
      expect(m.first, containsPair('presetKey', 'hydrate'));
      expect(m.first, containsPair('kind', 'preset'));
      expect(m.first, containsPair('active', false));
      expect(m.last, containsPair('active', true));
      expect(m.first['id'], m.last['id']); // one row per preset key
    });

    test('custom habits: at most 3 active, ≤ 30 characters, each an upsert '
        'with kind custom', () async {
      for (final n in ['Water plants', 'Call amma', 'Stretch']) {
        expect(await repo.addCustom(n), CustomHabitResult.saved);
      }
      expect(await repo.canAddCustomHabit(), isFalse);
      expect(await repo.addCustom('Read'), CustomHabitResult.tooMany);
      expect(
        await _repo(memoryDb()).addCustom('x' * 31),
        CustomHabitResult.invalid,
      );

      final today = await repo.watchToday(_today).first;
      expect(today.where((h) => h.isCustom).map((h) => h.name),
          ['Water plants', 'Call amma', 'Stretch']);

      final m = await _mutations(db);
      expect(m, hasLength(3));
      expect(m.first, containsPair('kind', 'custom'));
      expect(m.first, containsPair('name', 'Water plants'));
      expect(m.first, containsPair('presetKey', null));
      expect(m.first, containsPair('active', true));
    });

    test('names: trimmed, ≤ 30 characters counted as grapheme clusters '
        '(no UTF-16 cap)', () {
      expect(HabitRepository.cleanCustomName('  Walk   the dog '), 'Walk the dog');
      expect(HabitRepository.cleanCustomName('   '), isNull);
      expect(HabitRepository.cleanCustomName('a' * 30), 'a' * 30);
      expect(HabitRepository.cleanCustomName('a' * 31), isNull);
      // A Telugu name within 30 characters but over 40 UTF-16 units saves:
      // the server counts grapheme clusters too.
      final conjuncts = 'క్ష' * 14;
      expect(conjuncts.length, greaterThan(40));
      expect(conjuncts.characters.length, lessThanOrEqualTo(30));
      expect(HabitRepository.cleanCustomName(conjuncts), conjuncts);
      // Emoji with modifiers are one character each.
      final waves = '👋🏽' * 30;
      expect(HabitRepository.cleanCustomName(waves), waves);
      expect(HabitRepository.cleanCustomName('👋🏽' * 31), isNull);
      expect(HabitRepository.cleanCustomName('క్ష' * 31), isNull);
    });

    test('a long Telugu name within 30 characters is added and synced as is',
        () async {
      final name = 'క్ష' * 14;
      expect(await repo.addCustom(name), CustomHabitResult.saved);
      final m = await _mutations(db);
      expect(m.single, containsPair('name', name));
    });

    test('hiding a custom habit frees a slot; showing it at the limit is '
        'refused', () async {
      for (final n in ['A', 'B', 'C']) {
        await repo.addCustom(n);
      }
      final a = (await repo.watchSettings().first).firstWhere((h) => h.name == 'A');
      expect(await repo.setCustomShown(a.habitId!, false), CustomHabitResult.saved);
      expect(await repo.addCustom('D'), CustomHabitResult.saved);
      expect(await repo.setCustomShown(a.habitId!, true), CustomHabitResult.tooMany);

      final settings = await repo.watchSettings().first;
      expect(settings.where((h) => h.isCustom).map((h) => (h.name, h.shown)), [
        ('A', false),
        ('B', true),
        ('C', true),
        ('D', true),
      ]);
    });

    test('removing a custom habit: delete mutation; earned logs stay as '
        'tombstones', () async {
      await repo.addCustom('Stretch');
      final id = (await repo.watchToday(_today).first).last.habitId!;
      expect(await repo.toggleCustomToday(id), isTrue);

      await repo.removeCustom(id);
      expect(await (db.select(db.habits)..where((t) => t.id.equals(id))).get(),
          isEmpty);
      final logs = await db.select(db.habitLogs).get();
      expect(logs, hasLength(1));
      expect(logs.single.deletedAt, isNotNull);
      final m = await _mutations(db);
      expect(m.last, containsPair('entity', 'habit'));
      expect(m.last, containsPair('op', 'delete'));
      expect(m.last, containsPair('id', id));
      expect(await repo.canAddCustomHabit(), isTrue);
    });

    test('completeToday (Breathe auto-complete): logs once, never un-marks, '
        'skips a hidden Breathe', () async {
      expect(await repo.completeToday(PresetHabitKeys.breathe), isTrue);
      expect(await repo.completeToday(PresetHabitKeys.breathe), isFalse);
      final today = await repo.watchToday(_today).first;
      expect(today.firstWhere((h) => h.key == 'breathe').done, isTrue);
      expect(await db.select(db.habitLogs).get(), hasLength(1));

      final other = _repo(memoryDb());
      await other.setPresetShown(PresetHabitKeys.breathe, false);
      expect(await other.completeToday(PresetHabitKeys.breathe), isFalse);
    });
  });

  group('Home habits and the editor (item 5)', () {
    Future<void> pumpSection(WidgetTester tester, AppDatabase db,
        {FakeSync? sync}) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db: db, sync: sync),
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
    }

    /// Unmounts the tree so Drift/Riverpod timers stop before the test ends.
    Future<void> end(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> openEditor(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('habits-edit')));
      await settleIo(tester);
    }

    Future<void> closeEditor(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('habits-close')));
      await settleIo(tester);
    }

    testWidgets('Edit sits next to the title (48 dp); a preset switch hides '
        'its chip through the outbox', (tester) async {
      final db = memoryDb();
      final sync = FakeSync();
      await pumpSection(tester, db, sync: sync);
      final edit = find.byKey(const ValueKey('habits-edit'));
      expect(tester.getSize(edit).height, greaterThanOrEqualTo(48));

      await openEditor(tester);
      expect(find.text('Your small things'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('habit-switch-hydrate')));
      await settleIo(tester);
      await closeEditor(tester);

      expect(find.byKey(const ValueKey('habit-hydrate')), findsNothing);
      expect(find.byKey(const ValueKey('habit-move')), findsOneWidget);
      final m = await io(tester, () => _mutations(db));
      expect(m.single, containsPair('active', false));
      expect(sync.writes, 1);
      await end(tester);
    });

    testWidgets('adding a custom habit shows a chip with the generic icon',
        (tester) async {
      final db = memoryDb();
      await pumpSection(tester, db);
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('habits-add-field')),
        'Water plants',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('habits-add')));
      await settleIo(tester);
      await closeEditor(tester);

      final chip = find.ancestor(
        of: find.text('Water plants'),
        matching: find.byType(FilterChip),
      );
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.byIcon(customHabitIcon)),
        findsOneWidget,
      );
      await end(tester);
    });

    testWidgets('at 3 custom habits: the swap message instead of the field',
        (tester) async {
      final db = memoryDb();
      for (final n in ['A', 'B', 'C']) {
        await io(tester, () => _repo(db).addCustom(n));
      }
      await pumpSection(tester, db);
      await openEditor(tester);

      final limit = find.text(
        'You have 3 custom habits. Swap one to add another.',
      );
      await tester.scrollUntilVisible(
        limit,
        200,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(limit, findsOneWidget);
      expect(find.byKey(const ValueKey('habits-add-field')), findsNothing);
      await end(tester);
    });

    testWidgets('the field stops at 30 characters (grapheme clusters); a '
        'long Telugu name saves with no "too long" note', (tester) async {
      final db = memoryDb();
      await pumpSection(tester, db);
      await openEditor(tester);
      final field = find.byKey(const ValueKey('habits-add-field'));
      await tester.enterText(field, 'a' * 35);
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'a' * 30);

      final telugu = 'క్ష' * 14; // > 40 UTF-16 units, ≤ 30 characters
      await tester.enterText(field, telugu);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('habits-add')));
      await settleIo(tester);

      expect(find.byKey(const ValueKey('habits-notice')), findsNothing);
      final rows = await io(tester, () => db.select(db.habits).get());
      expect(rows.single.name, telugu);
      await end(tester);
    });

    testWidgets('crisis words in a custom name: the habit saves and the '
        'support sheet opens', (tester) async {
      final db = memoryDb();
      await pumpSection(tester, db);
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('habits-add-field')),
        'I want to die',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('habits-add')));
      await settleIo(tester);

      expect(find.byType(SupportSheet), findsOneWidget);
      final rows = await io(tester, () => db.select(db.habits).get());
      expect(rows.single.kind, 'custom');
      await end(tester);
    });

    testWidgets('every habit hidden: "Pick one small thing to start."',
        (tester) async {
      final db = memoryDb();
      for (final p in presetHabits) {
        await io(tester, () => _repo(db).setPresetShown(p.key, false));
      }
      await pumpSection(tester, db);

      expect(find.text('Pick one small thing to start.'), findsOneWidget);
      expect(find.byKey(const ValueKey('habits-edit')), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      await end(tester);
    });

    testWidgets('the editor scrolls at 200% text without overflow',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final db = memoryDb();
      await pumpSection(tester, db);
      await openEditor(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('habits-close')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('habits-add-field')),
        200,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
      await end(tester);
    });

    testWidgets('chips use restrained haptics that Comfort can switch off',
        (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(() {
        AuraHaptics.enabled = true;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      final db = memoryDb();
      await pumpSection(tester, db);

      await tester.tap(find.byKey(const ValueKey('habit-move')));
      await settleIo(tester);
      expect(calls, ['HapticFeedbackType.selectionClick']);

      AuraHaptics.enabled = false;
      await tester.tap(find.byKey(const ValueKey('habit-move')));
      await settleIo(tester);
      expect(calls, hasLength(1));
      await end(tester);
    });
  });

  testWidgets('Tenglish preset names match Telugu (item 6)', (tester) async {
    late AppLocalizations l;
    await tester.pumpWidget(
      localized(
        Builder(
          builder: (context) {
            l = AppLocalizations.of(context);
            return const SizedBox();
          },
        ),
        locale: localeFromTag('te-Latn'),
      ),
    );
    expect(l.habit_breathe, 'Shwaasa');
    expect(l.habit_journal, 'Diary');
  });
}
