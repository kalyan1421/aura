import 'dart:convert';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/orbit_loom/constellation_repository.dart';
import 'package:aura/src/features/orbit_loom/loom_shape.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// U07 Orbit Loom (RULES.md section 14): keeping a constellation is local
/// first and goes through the outbox like every write; five a day; letting
/// one go erases it; a refusal from the server drops the local copy.

LoomShape _triangle({double dx = 0}) => LoomShape.empty
    .addStar(0.2 + dx, 0.2)
    .addStar(0.8, 0.3)
    .addStar(0.5, 0.8)
    .toggleLink(0, 1);

void main() {
  late AppDatabase db;
  late ConstellationRepository repo;
  var notified = 0;

  setUp(() {
    db = memoryDb();
    notified = 0;
    repo = ConstellationRepository(
      db,
      OutboxRepository(db, const Ids()),
      testTime(),
      const Ids(),
      notifySync: () => notified++,
    );
  });
  tearDown(() => db.close());

  test(
    'keeping writes the row and one outbox upsert with only the shape',
    () async {
      final id = await repo.keep(
        _triangle(),
        meaning: ConstellationMeaning.carrying,
      );
      expect(id, isNotNull);
      final row = await db.select(db.loomConstellations).getSingle();
      expect(row.id, id);
      expect(jsonDecode(row.stars!), [
        [0.2, 0.2],
        [0.8, 0.3],
        [0.5, 0.8],
      ]);
      expect(jsonDecode(row.links!), [
        [0, 1],
      ]);
      expect(row.meaning, 'carrying');
      expect(row.localDay, '2026-10-08');
      expect(row.synced, isFalse);
      final o = await db.select(db.outbox).getSingle();
      expect(o.entity, 'loom_constellation');
      expect(o.op, 'upsert');
      expect(o.entityId, id);
      expect(o.localDay, '2026-10-08');
      expect(jsonDecode(o.payload), {
        'id': id,
        'stars': [
          [0.2, 0.2],
          [0.8, 0.3],
          [0.5, 0.8],
        ],
        'links': [
          [0, 1],
        ],
        'meaning': 'carrying',
      });
      expect(notified, 1);

      // Acknowledged by the server: synced.
      await OutboxRepository(db, const Ids()).acknowledge([o]);
      expect(
        (await db.select(db.loomConstellations).getSingle()).synced,
        isTrue,
      );
    },
  );

  test('a shape the rule refuses is not kept, and nothing is queued', () async {
    final two = LoomShape.empty.addStar(0.2, 0.2).addStar(0.8, 0.8);
    expect(await repo.keep(two), isNull);
    expect(await db.select(db.loomConstellations).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(notified, 0);
  });

  test('five a day; letting one go frees its place', () async {
    final ids = <String>[];
    for (var i = 0; i < maxLoomConstellationsPerDay; i++) {
      ids.add((await repo.keep(_triangle(dx: i * 0.01)))!);
    }
    expect(await repo.keep(_triangle()), isNull);
    expect(await repo.watchKeptOn(const LocalDay(2026, 10, 8)).first, 5);
    await repo.letGo(ids.first);
    expect(await repo.watchKeptOn(const LocalDay(2026, 10, 8)).first, 4);
    expect(await repo.keep(_triangle()), isNotNull);
  });

  test('letting go erases the shape here and queues one delete', () async {
    final id = (await repo.keep(
      _triangle(),
      meaning: ConstellationMeaning.noticed,
    ))!;
    await repo.letGo(id);
    final row = await db.select(db.loomConstellations).getSingle();
    expect(row.deletedAt, isNotNull);
    expect([row.stars, row.links, row.meaning], [null, null, null]);
    final ops = [for (final o in await db.select(db.outbox).get()) o.op];
    expect(ops, ['upsert', 'delete']);
    await repo.letGo(id); // again: nothing more
    expect(await db.select(db.outbox).get(), hasLength(2));
    expect(await repo.watchKept().first, isEmpty);
  });

  test('a server refusal drops the local copy', () async {
    final id = (await repo.keep(_triangle()))!;
    await repo.dropRejected(id);
    expect(await db.select(db.loomConstellations).get(), isEmpty);
  });

  test('kept constellations read back newest first; unreadable or let-go rows '
      'are left out', () async {
    Future<void> row(String id, int hour, {String? stars, DateTime? gone}) => db
        .into(db.loomConstellations)
        .insert(
          LoomConstellationsCompanion.insert(
            id: id,
            stars: Value(stars),
            links: const Value('[]'),
            localDay: '2026-10-08',
            deviceTs: DateTime.utc(2026, 10, 8, hour),
            deletedAt: Value(gone),
          ),
        );
    const three = '[[0.2,0.2],[0.8,0.3],[0.5,0.8]]';
    await row('old', 1, stars: three);
    await row('new', 5, stars: three);
    await row('broken', 3, stars: '{nope');
    await row('gone', 4, gone: DateTime.utc(2026, 10, 8, 4));
    final kept = await repo.watchKept().first;
    expect([for (final k in kept) k.id], ['new', 'old']);
    expect(kept.first.shape.stars, hasLength(3));
    expect(kept.first.meaning, isNull);
  });

  test('v6 → v7 adds the constellations table', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final old = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE key_values (key TEXT NOT NULL PRIMARY KEY, value TEXT NULL)',
          );
          raw.execute('PRAGMA user_version = 6');
        },
      ),
    );
    addTearDown(old.close);
    expect(await old.select(old.loomConstellations).get(), isEmpty);
    expect(old.schemaVersion, 7);
    final cols = await old
        .customSelect('PRAGMA table_info(loom_constellations)')
        .get();
    expect(
      [for (final c in cols) c.data['name']],
      [
        'id',
        'stars',
        'links',
        'meaning',
        'local_day',
        'device_ts',
        'tz',
        'deleted_at',
        'synced',
      ],
    );
  });
}
