import 'dart:async';
import 'dart:convert';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/habits/decay_eligibility.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura/src/features/universe/world_moments.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// T04 (RULES.md section 13 `changes`): a plant that grew, woke or was
/// planted since the person last looked plays one moment. The first look is
/// a baseline; resting is never a moment; the record stays on the device.

HabitRepository _repo(AppDatabase db) => HabitRepository(
  db,
  OutboxRepository(db, const Ids()),
  testTime(),
  const Ids(),
);

/// Opens the world's moment provider the way the universe screen does.
ProviderContainer _open(AppDatabase db, {List<Override> extra = const []}) {
  final c = ProviderContainer(
    overrides: [
      ...testOverrides(db: db),
      ...extra,
    ],
  );
  c.listen(worldMomentsProvider, (_, _) {});
  return c;
}

Future<void> _settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

Future<Map<String, dynamic>?> _seen(AppDatabase db) async {
  final raw = await KvStore(db).get(KvKeys.worldSeen);
  return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
}

Future<void> _setSeen(AppDatabase db, Map<String, List<String>> seen) =>
    KvStore(db).set(KvKeys.worldSeen, jsonEncode(seen));

/// Every preset as a seed, thriving: what a first look at a new grove stores.
Map<String, List<String>> _allSeeds() => {
  for (final p in presetHabits) 'p:${p.key}': ['seed', 'thriving'],
};

Future<void> _log(AppDatabase db, String habitId, String day) => db
    .into(db.habitLogs)
    .insert(
      HabitLogsCompanion.insert(
        id: '$habitId-$day',
        habitId: habitId,
        localDay: day,
        deviceTs: testNow,
      ),
    );

/// An adult with Hydrate as a commitment, five logged days (a young plant),
/// the last one on 1 October: on 8 October it is wilting.
Future<String> _restingHydrate(AppDatabase db) async {
  await KvStore(db).set(KvKeys.birthDate, '1990-01-01');
  final id = await _repo(db).ensurePresetId(PresetHabitKeys.hydrate);
  for (final d in [
    '2026-09-24',
    '2026-09-26',
    '2026-09-28',
    '2026-09-30',
    '2026-10-01',
  ]) {
    await _log(db, id, d);
  }
  await db.customStatement(
    "UPDATE habits SET committed_from = '2026-09-20' WHERE id = '$id'",
  );
  return id;
}

void main() {
  late AppDatabase db;
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  test('the first look is a baseline: nothing plays, and it is recorded on '
      'the device', () async {
    final c = _open(db);
    addTearDown(c.dispose);
    await _settle();
    expect(c.read(worldMomentsProvider), isNull);
    expect(await _seen(db), _allSeeds());
  });

  test('a log since the last look grows that plant, once', () async {
    await _setSeen(db, _allSeeds());
    await _repo(db).toggleToday(PresetHabitKeys.hydrate);

    final c = _open(db);
    await _settle();
    final moment = c.read(worldMomentsProvider)!;
    expect(moment.plants, hasLength(1));
    final p = moment.plants.single;
    expect(p.kind, WorldChangeKind.grow);
    expect(p.habit.input.preset?.key, PresetHabitKeys.hydrate);
    expect(p.from?.stage, GrowthStage.seed);
    expect(p.change.to.stage, GrowthStage.sprout);
    expect(p.change.slot, p.habit.slot);
    // Until it plays, the old look is kept (so a later visit still plays it).
    expect((await _seen(db))!['p:hydrate'], ['seed', 'thriving']);

    expect(c.read(worldMomentsProvider.notifier).take(), same(moment));
    expect(c.read(worldMomentsProvider), isNull);
    await _settle();
    expect((await _seen(db))!['p:hydrate'], ['sprout', 'thriving']);
    c.dispose();

    final again = _open(db);
    addTearDown(again.dispose);
    await _settle();
    expect(again.read(worldMomentsProvider), isNull);
  });

  test('a moment that was never played waits for the next visit', () async {
    await _setSeen(db, _allSeeds());
    await _repo(db).toggleToday(PresetHabitKeys.hydrate);
    final c = _open(db);
    await _settle();
    expect(c.read(worldMomentsProvider), isNotNull);
    c.dispose(); // left before it played

    final again = _open(db);
    addTearDown(again.dispose);
    await _settle();
    expect(
      again.read(worldMomentsProvider)!.plants.single.kind,
      WorldChangeKind.grow,
    );
  });

  test('logging while the world is open offers a moment at once', () async {
    final c = _open(db);
    addTearDown(c.dispose);
    await _settle();
    expect(c.read(worldMomentsProvider), isNull);

    await _repo(db).toggleToday(PresetHabitKeys.move);
    await _settle();
    expect(
      c.read(worldMomentsProvider)!.plants.single.habit.input.preset?.key,
      PresetHabitKeys.move,
    );
  });

  test(
    'starting to rest is never a moment; the next log wakes the plant',
    () async {
      final id = await _restingHydrate(db);
      await _setSeen(db, {
        ..._allSeeds(),
        'p:hydrate': ['young', 'thriving'],
      });
      final c = _open(db);
      addTearDown(c.dispose);
      await _settle();
      // Wilting now, but that is shown as it is, silently.
      expect(c.read(worldMomentsProvider), isNull);
      expect((await _seen(db))!['p:hydrate'], ['young', 'wilting']);

      await _log(db, id, '2026-10-08'); // one log today: six days, still young
      await _settle();
      final p = c.read(worldMomentsProvider)!.plants.single;
      expect(p.kind, WorldChangeKind.wake);
      expect(p.from?.vitality, Vitality.wilting);
      expect(p.change.to.vitality, Vitality.thriving);
    },
  );

  test('until the age is known nothing is decided (every plant would look '
      'thriving, which is not a wake)', () async {
    await _restingHydrate(db);
    await _setSeen(db, {
      ..._allSeeds(),
      'p:hydrate': ['young', 'wilting'],
    });
    final age = Completer<int>();
    final c = _open(
      db,
      extra: [deviceAgeYearsProvider.overrideWith((ref) => age.future)],
    );
    addTearDown(c.dispose);
    await _settle();
    expect(c.read(worldMomentsProvider), isNull);
    expect((await _seen(db))!['p:hydrate'], ['young', 'wilting']);

    age.complete(36);
    await _settle();
    expect(c.read(worldMomentsProvider), isNull);
    expect((await _seen(db))!['p:hydrate'], ['young', 'wilting']);
  });

  test('a habit that leaves the grove is forgotten; showing it again plants '
      'it anew', () async {
    final repo = _repo(db);
    final c = _open(db);
    addTearDown(c.dispose);
    await _settle();

    await repo.setPresetShown(PresetHabitKeys.journal, false);
    await _settle();
    expect(c.read(worldMomentsProvider), isNull);
    expect((await _seen(db))!.containsKey('p:journal'), isFalse);

    await repo.setPresetShown(PresetHabitKeys.journal, true);
    await _settle();
    expect(
      c.read(worldMomentsProvider)!.plants.single.kind,
      WorldChangeKind.sprout,
    );
    expect(c.read(worldMomentsProvider)!.plants.single.from, isNull);
  });

  test('an unreadable record starts a new baseline', () async {
    await KvStore(db).set(KvKeys.worldSeen, 'not json');
    await _repo(db).toggleToday(PresetHabitKeys.hydrate);
    final c = _open(db);
    addTearDown(c.dispose);
    await _settle();
    expect(c.read(worldMomentsProvider), isNull);
    expect((await _seen(db))!['p:hydrate'], ['sprout', 'thriving']);
  });

  test('keys: a preset keeps its catalogue key when its row is first made; a '
      'custom habit is keyed by its id', () {
    expect(
      worldKeyOf(HabitWorldInput(preset: presetHabits.first)),
      'p:${presetHabits.first.key}',
    );
    expect(
      worldKeyOf(HabitWorldInput(habitId: 'abc', preset: presetHabits.first)),
      'p:${presetHabits.first.key}',
    );
    expect(worldKeyOf(const HabitWorldInput(habitId: 'abc')), 'c:abc');
  });
}
