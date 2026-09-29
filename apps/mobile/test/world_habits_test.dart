import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/habits/decay_eligibility.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura/src/features/universe/universe_scene.dart';
import 'package:aura/src/features/universe/world_habits.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// W03 (RULES.md section 13): each shown habit is a plant. Growth is permanent;
/// opt-in decay is reversible, adults only, and never touches the ledger.

const LocalDay _today = LocalDay(2026, 10, 8);

HabitRepository _repo(AppDatabase db) => HabitRepository(
  db,
  OutboxRepository(db, const Ids()),
  testTime(),
  const Ids(),
);

HabitWorldInput _in({
  int days = 0,
  LocalDay? last,
  LocalDay? committed,
  LocalDay? paused,
}) => HabitWorldInput(
  habitId: 'h',
  distinctLoggedDays: days,
  lastLogDay: last,
  committedFrom: committed,
  pausedThrough: paused,
);

void main() {
  group('ageYearsFor', () {
    test('completed years on the day, and never negative', () {
      expect(
        ageYearsFor(
          birthDate: const LocalDay(1996, 10, 9),
          minorUntil: null,
          today: _today,
        ),
        29, // birthday is tomorrow
      );
      expect(
        ageYearsFor(
          birthDate: const LocalDay(1996, 10, 8),
          minorUntil: null,
          today: _today,
        ),
        30,
      );
      expect(
        ageYearsFor(
          birthDate: const LocalDay(2030, 1, 1),
          minorUntil: null,
          today: _today,
        ),
        0,
      );
    });

    test('no DOB is never eligible; an under-18 age signal caps an adult DOB '
        'at 17 until it lapses', () {
      expect(
        ageYearsFor(birthDate: null, minorUntil: null, today: _today),
        0,
      );
      expect(
        ageYearsFor(
          birthDate: const LocalDay(1990, 1, 1),
          minorUntil: const LocalDay(2027, 1, 1),
          today: _today,
        ),
        17,
      );
      expect(
        ageYearsFor(
          birthDate: const LocalDay(1990, 1, 1),
          minorUntil: const LocalDay(2026, 10, 8), // lapsed today
          today: _today,
        ),
        36,
      );
    });
  });

  group('buildWorldHabits', () {
    test('growth comes from distinct logged days and keeps its place', () {
      final w = buildWorldHabits(
        [_in(), _in(days: 1), _in(days: 4), _in(days: 25), _in(days: 90)],
        today: _today,
        ageYears: 30,
      );
      expect(w.map((h) => h.stage), [
        GrowthStage.seed,
        GrowthStage.sprout,
        GrowthStage.young,
        GrowthStage.flourishing,
        GrowthStage.ancient,
      ]);
      expect(w.map((h) => h.slot), [0, 1, 2, 3, 4]);
      expect(w.every((h) => h.vitality == Vitality.thriving), isTrue);
    });

    test('an adult who committed sees decay; one log today restores it', () {
      final committed = const LocalDay(2026, 10, 1);
      Vitality at({LocalDay? last}) => buildWorldHabits(
        [_in(days: 3, last: last, committed: committed)],
        today: _today,
        ageYears: 30,
      ).single.vitality;
      expect(at(), Vitality.wilting); // 6 full days missed
      expect(at(last: const LocalDay(2026, 10, 2)), Vitality.wilting);
      expect(at(last: const LocalDay(2026, 10, 5)), Vitality.dimmed);
      expect(at(last: _today), Vitality.thriving);
    });

    test('a habit that is not a commitment never decays, even beside one', () {
      final w = buildWorldHabits(
        [
          _in(days: 2, committed: const LocalDay(2026, 9, 1)),
          _in(days: 2, last: const LocalDay(2026, 9, 1)),
        ],
        today: _today,
        ageYears: 30,
      );
      expect(w[0].vitality, Vitality.dormant);
      expect(w[1].vitality, Vitality.thriving);
    });

    test('under 18 (or unknown age) sees every plant thriving, whatever the '
        'stored commitment', () {
      for (final age in [0, 13, 17]) {
        final w = buildWorldHabits(
          [_in(days: 5, committed: const LocalDay(2026, 9, 1))],
          today: _today,
          ageYears: age,
        );
        expect(w.single.vitality, Vitality.thriving, reason: 'age $age');
        expect(w.single.stage, GrowthStage.young); // growth is unaffected
      }
    });

    test('a chosen pause holds a plant thriving; the grove holds nine', () {
      final w = buildWorldHabits(
        [
          _in(
            committed: const LocalDay(2026, 9, 1),
            paused: const LocalDay(2026, 10, 20),
          ),
          for (var i = 0; i < 12; i++) _in(),
        ],
        today: _today,
        ageYears: 30,
      );
      expect(w.first.vitality, Vitality.thriving);
      expect(w, hasLength(maxWorldPlants));
    });

    test('the renderer gets a slot, a stage and a vitality only', () {
      final h = buildWorldHabits(
        [
          const HabitWorldInput(
            habitId: 'secret-id',
            name: 'Call amma',
            distinctLoggedDays: 10,
          ),
        ],
        today: _today,
        ageYears: 30,
      ).single;
      expect(
        h.plant,
        const WorldPlant(slot: 0, stage: GrowthStage.grown),
      );
      expect(h.plant.toString(), isNot(contains('amma')));
      expect(h.plant.toString(), isNot(contains('secret-id')));
    });
  });

  group('HabitRepository.watchWorldInputs', () {
    late AppDatabase db;
    late HabitRepository repo;
    setUp(() {
      db = memoryDb();
      repo = _repo(db);
    });
    tearDown(() => db.close());

    test('all six presets start as seeds in catalogue order', () async {
      final inputs = await repo.watchWorldInputs().first;
      expect(inputs.map((i) => i.preset?.key), [
        for (final p in presetHabits) p.key,
      ]);
      expect(inputs.every((i) => i.habitId == null), isTrue);
      expect(inputs.every((i) => i.distinctLoggedDays == 0), isTrue);
    });

    test('hidden presets leave the grove; active customs join it', () async {
      await repo.setPresetShown(PresetHabitKeys.hydrate, false);
      await repo.addCustom('Read');
      await repo.addCustom('Stretch');
      final custom = (await db.select(db.habits).get()).where(
        (h) => h.kind == 'custom',
      );
      await repo.setCustomShown(custom.last.id, false);
      final inputs = await repo.watchWorldInputs().first;
      expect(inputs.map((i) => i.preset?.key), isNot(contains('hydrate')));
      expect(inputs, hasLength(6)); // 5 presets + Read
      expect(inputs.last.name, 'Read');
    });

    test('counts distinct live logged days and the last one', () async {
      await repo.addCustom('Read');
      final id = (await db.select(db.habits).getSingle()).id;
      for (final d in ['2026-10-05', '2026-10-06', '2026-10-06', '2026-10-07']) {
        await db
            .into(db.habitLogs)
            .insert(
              HabitLogsCompanion.insert(
                id: '$id-$d-${d.hashCode}-${DateTime.now().microsecondsSinceEpoch}',
                habitId: id,
                localDay: d,
                deviceTs: testNow,
                deletedAt: d == '2026-10-07'
                    ? Value(testNow)
                    : const Value(null),
              ),
            );
      }
      final read = (await repo.watchWorldInputs().first).firstWhere(
        (i) => i.name == 'Read',
      );
      expect(read.distinctLoggedDays, 2); // the deleted day is gone
      expect(read.lastLogDay, const LocalDay(2026, 10, 6));
    });

    test('a commitment shows up; logging today restores the plant end to end',
        () async {
      await repo.addCustom('Read');
      final id = (await db.select(db.habits).getSingle()).id;
      await db.delete(db.outbox).go();
      await db.customStatement(
        "UPDATE habits SET committed_from = '2026-10-01' WHERE id = '$id'",
      );
      List<WorldHabit> world(List<HabitWorldInput> i) =>
          buildWorldHabits(i, today: _today, ageYears: 30);
      var read = world(await repo.watchWorldInputs().first).firstWhere(
        (h) => h.input.name == 'Read',
      );
      expect(read.vitality, Vitality.wilting);
      expect(read.stage, GrowthStage.seed);

      await repo.toggleCustomToday(id); // one log today
      read = world(await repo.watchWorldInputs().first).firstWhere(
        (h) => h.input.name == 'Read',
      );
      expect(read.vitality, Vitality.thriving);
      expect(read.stage, GrowthStage.sprout);
    });

    test('a rejected commitment is dropped locally and queues nothing',
        () async {
      await repo.addCustom('Read');
      final id = (await db.select(db.habits).getSingle()).id;
      await repo.setCommitment(id, committed: true, ageYears: 30);
      await repo.pauseCommitment(id, days: 7);
      await db.delete(db.outbox).go();

      await repo.clearRejectedCommitment(id);
      final h = await db.select(db.habits).getSingle();
      expect(h.committedFrom, isNull);
      expect(h.pausedThrough, isNull);
      expect(await db.select(db.outbox).get(), isEmpty);
    });
  });

  group('the island mesh', () {
    /// Highest point of the plant standing at [slot] on the grove plaza.
    double top(IslandMesh mesh, int slot) {
      final at = UniverseDestination.grove.position +
          IslandMesh.plantOffset(slot);
      var best = 0.0;
      for (final f in mesh.faces.skip(mesh.terrainFaceCount)) {
        for (final p in [f.a, f.b, f.c]) {
          final near = (p.x - at.x).abs() < 0.16 && (p.z - at.z).abs() < 0.16;
          if (near && p.y > best) best = p.y;
        }
      }
      return best;
    }

    IslandMesh one(GrowthStage stage, Vitality v) => IslandMesh(
      growth: 0,
      plants: [WorldPlant(slot: 0, stage: stage, vitality: v)],
    );

    test('a plant grows with its stage and settles lower as it rests, never '
        'disappearing', () {
      final heights = [
        for (final s in GrowthStage.values)
          top(one(s, Vitality.thriving), 0),
      ];
      for (var i = 1; i < heights.length; i++) {
        expect(heights[i], greaterThan(heights[i - 1]), reason: '$i');
      }
      final thriving = top(one(GrowthStage.grown, Vitality.thriving), 0);
      final dimmed = top(one(GrowthStage.grown, Vitality.dimmed), 0);
      final wilting = top(one(GrowthStage.grown, Vitality.wilting), 0);
      final dormant = top(one(GrowthStage.grown, Vitality.dormant), 0);
      expect(thriving, greaterThan(dimmed));
      expect(dimmed, greaterThan(wilting));
      expect(wilting, greaterThan(dormant));
      expect(dormant, greaterThan(0.2)); // still there
    });

    test('nine full-grown plants stay inside the scene budget', () {
      final mesh = IslandMesh(
        growth: 1,
        plants: [
          for (var i = 0; i < maxWorldPlants; i++)
            WorldPlant(slot: i, stage: GrowthStage.ancient),
        ],
      );
      expect(mesh.faces.length, lessThan(3000));
      final low = IslandMesh(
        growth: 1,
        lowDetail: true,
        plants: [
          for (var i = 0; i < maxWorldPlants; i++)
            WorldPlant(slot: i, stage: GrowthStage.ancient),
        ],
      );
      expect(low.faces.length, lessThanOrEqualTo(mesh.faces.length));
    });

    test('each slot has its own place on the plaza, inside the terrain', () {
      final spots = {
        for (var i = 0; i < maxWorldPlants; i++)
          '${IslandMesh.plantOffset(i).x.toStringAsFixed(2)},'
              '${IslandMesh.plantOffset(i).z.toStringAsFixed(2)}',
      };
      expect(spots, hasLength(maxWorldPlants));
      for (var i = 0; i < maxWorldPlants; i++) {
        final o = IslandMesh.plantOffset(i);
        expect(o.x * o.x + o.z * o.z, lessThan(0.78 * 0.78));
      }
    });
  });
}
