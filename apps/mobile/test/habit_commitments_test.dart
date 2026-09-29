import 'dart:convert';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// W02 (RULES.md section 13): a habit's commitment is the person's own opt-in
/// to reversible world decay. Local write + outbox mutation, never the ledger,
/// never under 18.

HabitRepository _repo(AppDatabase db) => HabitRepository(
  db,
  OutboxRepository(db, const Ids()),
  testTime(),
  const Ids(),
);

Future<List<Map<String, Object?>>> _mutations(AppDatabase db) async => [
  for (final r in await db.select(db.outbox).get())
    jsonDecode(r.payload) as Map<String, Object?>,
];

void main() {
  late AppDatabase db;
  late HabitRepository repo;
  late String habitId;

  setUp(() async {
    db = memoryDb();
    repo = _repo(db);
    await repo.addCustom('Read');
    habitId = (await db.select(db.habits).getSingle()).id;
    await db.delete(db.outbox).go(); // only what the commitment enqueues
  });
  tearDown(() => db.close());

  test('an adult commits: stored locally, one upsert with explicit fields, '
      'Starlight untouched', () async {
    expect(
      await repo.setCommitment(habitId, committed: true, ageYears: 30),
      CommitmentResult.saved,
    );
    final h = await db.select(db.habits).getSingle();
    expect(h.committedFrom, '2026-10-08'); // testNow in Asia/Kolkata
    expect(h.pausedThrough, isNull);
    expect(h.synced, isFalse);
    final m = await _mutations(db);
    expect(m, hasLength(1));
    expect(m.single, containsPair('committedFrom', '2026-10-08'));
    expect(m.single, containsPair('pausedThrough', null));
    expect(m.single, containsPair('name', 'Read'));
    expect(await db.select(db.habitLogs).get(), isEmpty); // no log, no credit
  });

  test('under 18 is refused: nothing written, nothing queued', () async {
    for (final age in [13, 17]) {
      expect(
        await repo.setCommitment(habitId, committed: true, ageYears: age),
        CommitmentResult.notAvailable,
      );
    }
    expect((await db.select(db.habits).getSingle()).committedFrom, isNull);
    expect(await _mutations(db), isEmpty);
  });

  test('ending a commitment is always allowed (also for someone who is now '
      'flagged under 18) and clears the pause', () async {
    await repo.setCommitment(habitId, committed: true, ageYears: 30);
    await repo.pauseCommitment(habitId, days: 3);
    await db.delete(db.outbox).go();
    expect(
      await repo.setCommitment(habitId, committed: false, ageYears: 15),
      CommitmentResult.saved,
    );
    final h = await db.select(db.habits).getSingle();
    expect(h.committedFrom, isNull);
    expect(h.pausedThrough, isNull);
    final m = await _mutations(db);
    expect(m.single, containsPair('committedFrom', null));
    expect(m.single, containsPair('pausedThrough', null));
  });

  test('committing again while committed changes nothing and queues nothing',
      () async {
    await repo.setCommitment(habitId, committed: true, ageYears: 30);
    await db.delete(db.outbox).go();
    expect(
      await repo.setCommitment(habitId, committed: true, ageYears: 30),
      CommitmentResult.saved,
    );
    expect(await _mutations(db), isEmpty);
  });

  test('a pause needs a commitment, lasts 1 to 60 days, and 0 ends it',
      () async {
    expect(
      await repo.pauseCommitment(habitId, days: 3),
      CommitmentResult.invalid,
    );
    await repo.setCommitment(habitId, committed: true, ageYears: 30);
    for (final bad in [-1, HabitRepository.maxPauseDays + 1]) {
      expect(
        await repo.pauseCommitment(habitId, days: bad),
        CommitmentResult.invalid,
      );
    }
    expect(
      await repo.pauseCommitment(habitId, days: HabitRepository.maxPauseDays),
      CommitmentResult.saved,
    );
    var h = await db.select(db.habits).getSingle();
    expect(h.committedFrom, '2026-10-08');
    expect(h.pausedThrough, '2026-12-07'); // 8 Oct + 60 days
    expect(
      await repo.pauseCommitment(habitId, days: 0),
      CommitmentResult.saved,
    );
    h = await db.select(db.habits).getSingle();
    expect(h.pausedThrough, isNull);
    expect(h.committedFrom, '2026-10-08');
  });

  test('unknown habit', () async {
    expect(
      await repo.setCommitment('nope', committed: true, ageYears: 30),
      CommitmentResult.notFound,
    );
    expect(
      await repo.pauseCommitment('nope', days: 2),
      CommitmentResult.notFound,
    );
  });

  test('an ordinary edit omits the commitment fields, so the server keeps '
      'them (an older phone never clears a commitment)', () async {
    await repo.setCommitment(habitId, committed: true, ageYears: 30);
    await db.delete(db.outbox).go();
    await repo.setCustomShown(habitId, false);
    final m = await _mutations(db);
    expect(m.single.containsKey('committedFrom'), isFalse);
    expect(m.single.containsKey('pausedThrough'), isFalse);
    expect(m.single, containsPair('active', false));
  });

  test('a commitment feeds the shared world rules end to end', () async {
    await repo.setCommitment(habitId, committed: true, ageYears: 30);
    final h = await db.select(db.habits).getSingle();
    Vitality at(String day) => habitVitality(
      decayActive: decayEligible(optedIn: true, ageYears: 30),
      committedFrom: LocalDay.tryParse(h.committedFrom),
      lastLogDay: null,
      pausedThrough: LocalDay.tryParse(h.pausedThrough),
      today: LocalDay.parse(day),
    );
    expect(at('2026-10-08'), Vitality.thriving);
    expect(at('2026-10-11'), Vitality.dimmed);
    expect(at('2026-10-20'), Vitality.dormant);
  });

  test('v5 → v6 keeps habits and adds the commitment columns (null)', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final old = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE habits (id TEXT NOT NULL PRIMARY KEY, kind TEXT NOT NULL, '
            'preset_key TEXT NULL, name TEXT NULL, active INTEGER NOT NULL DEFAULT 1 '
            'CHECK (active IN (0, 1)), created_at TEXT NOT NULL, '
            'updated_at TEXT NOT NULL, synced INTEGER NOT NULL DEFAULT 0 '
            'CHECK (synced IN (0, 1)))',
          );
          raw.execute(
            "INSERT INTO habits (id, kind, name, created_at, updated_at) "
            "VALUES ('h1', 'custom', 'Read', '2026-10-01T10:00:00.000Z', '2026-10-01T10:00:00.000Z')",
          );
          raw.execute('PRAGMA user_version = 5');
        },
      ),
    );
    addTearDown(old.close);
    final h = await old.select(old.habits).getSingle(); // opens + migrates
    expect(old.schemaVersion, 6);
    expect(h.name, 'Read');
    expect(h.committedFrom, isNull);
    expect(h.pausedThrough, isNull);
  });
}
