import 'package:aura/src/core/db/database.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Schema v4 → v5 (F4 time capsules): existing check-ins, habits and queued
/// mutations are kept; the capsule tables are created empty and usable.
void main() {
  // The v4 schema as drift created it (v3 + the v4 voice columns).
  const v4 = [
    'CREATE TABLE "check_ins" ("id" TEXT NOT NULL, "mood_id" TEXT NOT NULL, '
        '"quadrant" TEXT NOT NULL, "tags" TEXT NOT NULL DEFAULT \'[]\', '
        '"note" TEXT NULL, "local_day" TEXT NOT NULL, "device_ts" TEXT NOT NULL, '
        '"tz_offset_minutes" INTEGER NOT NULL, "tz" TEXT NULL, '
        '"source" TEXT NOT NULL DEFAULT \'app\', "deleted_at" TEXT NULL, '
        '"synced" INTEGER NOT NULL DEFAULT 0 CHECK ("synced" IN (0, 1)), '
        '"note_locked" INTEGER NOT NULL DEFAULT 0 CHECK ("note_locked" IN (0, 1)), '
        '"voice_file" TEXT NULL, "voice_ms" INTEGER NULL, "voice_path" TEXT NULL, '
        'PRIMARY KEY ("id"))',
    'CREATE TABLE "habits" ("id" TEXT NOT NULL, "kind" TEXT NOT NULL, '
        '"preset_key" TEXT NULL, "name" TEXT NULL, '
        '"active" INTEGER NOT NULL DEFAULT 1 CHECK ("active" IN (0, 1)), '
        '"created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, '
        '"synced" INTEGER NOT NULL DEFAULT 0 CHECK ("synced" IN (0, 1)), '
        'PRIMARY KEY ("id"))',
    'CREATE TABLE "habit_logs" ("id" TEXT NOT NULL, "habit_id" TEXT NOT NULL, '
        '"local_day" TEXT NOT NULL, "device_ts" TEXT NOT NULL, "tz" TEXT NULL, '
        '"deleted_at" TEXT NULL, '
        '"synced" INTEGER NOT NULL DEFAULT 0 CHECK ("synced" IN (0, 1)), '
        'PRIMARY KEY ("id"))',
    'CREATE TABLE "outbox" ("seq" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        '"mutation_id" TEXT NOT NULL UNIQUE, "entity" TEXT NOT NULL, '
        '"op" TEXT NOT NULL, "entity_id" TEXT NOT NULL, '
        '"device_ts" TEXT NOT NULL, "local_day" TEXT NOT NULL, "tz" TEXT NULL, '
        '"payload" TEXT NOT NULL, '
        '"needs_note" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_note" IN (0, 1)), '
        '"attempts" INTEGER NOT NULL DEFAULT 0, "next_attempt_at" TEXT NULL, '
        '"created_at" TEXT NOT NULL, '
        '"needs_media" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_media" IN (0, 1)), '
        '"media_attempts" INTEGER NOT NULL DEFAULT 0)',
    'CREATE TABLE "dead_letters" ("seq" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        '"mutation_id" TEXT NOT NULL, "entity" TEXT NOT NULL, "op" TEXT NOT NULL, '
        '"entity_id" TEXT NOT NULL, "payload" TEXT NOT NULL, '
        '"reason" TEXT NOT NULL, "failed_at" TEXT NOT NULL, '
        '"device_ts" TEXT NULL, "local_day" TEXT NULL, "tz" TEXT NULL)',
    'CREATE TABLE "key_values" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, '
        'PRIMARY KEY ("key"))',
    'CREATE INDEX check_ins_day ON check_ins (local_day)',
    'CREATE INDEX habit_logs_day ON habit_logs (habit_id, local_day)',
    "INSERT INTO check_ins (id, mood_id, quadrant, tags, note, local_day, "
        "device_ts, tz_offset_minutes, tz, synced, voice_file, voice_ms) "
        "VALUES ('c1', 'calm', 'moonlight', '[]', 'tea', '2026-10-08', "
        "'2026-10-08T10:00:00.000Z', 330, 'Asia/Kolkata', 1, 'r.enc', 1200)",
    "INSERT INTO outbox (mutation_id, entity, op, entity_id, device_ts, "
        "local_day, tz, payload, needs_note, attempts, created_at, needs_media) "
        "VALUES ('m1', 'check_in', 'upsert', 'c1', '2026-10-08T10:00:00.000Z', "
        "'2026-10-08', 'Asia/Kolkata', '{\"id\":\"c1\"}', 1, 2, "
        "'2026-10-08T10:00:00.000Z', 1)",
    "INSERT INTO key_values (key, value) VALUES ('app.locale', 'te')",
    'PRAGMA user_version = 4',
  ];

  test('v4 → v5 keeps every row and adds the capsule tables', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final sql in v4) {
            raw.execute(sql);
          }
        },
      ),
    );
    addTearDown(db.close);

    final c = await db.select(db.checkIns).getSingle(); // opens + migrates
    expect(db.schemaVersion, 5);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 5);
    expect(c.note, 'tea');
    expect(c.voiceFile, 'r.enc');
    final o = await db.select(db.outbox).getSingle();
    expect(o.needsMedia, isTrue);
    expect(o.attempts, 2);
    expect(await db.getValue('app.locale'), 'te');

    expect(await db.select(db.capsules).get(), isEmpty);
    expect(await db.select(db.capsuleMedia).get(), isEmpty);
    final index = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'capsules_unlock'",
        )
        .get();
    expect(index, hasLength(1));

    // The new tables are usable.
    await db
        .into(db.capsules)
        .insert(
          CapsulesCompanion.insert(
            id: 'k1',
            unlockType: 'date',
            unlockLocalDate: const Value('2027-10-08'),
            payloadCt: const Value('AAAA'),
            sealedAt: DateTime.utc(2026, 10, 8, 10),
          ),
        );
    await db
        .into(db.capsuleMedia)
        .insert(
          CapsuleMediaCompanion.insert(
            capsuleId: 'k1',
            slot: 'photo-0',
            file: const Value('photo-0.enc'),
          ),
        );
    final k = await db.select(db.capsules).getSingle();
    expect(k.cycle, 0);
    expect(k.synced, isFalse);
    expect(k.rejected, isNull);
    final m = await db.select(db.capsuleMedia).getSingle();
    expect(m.attempts, 0);
    expect(m.failed, isFalse);
  });

  test('a fresh install creates v5 directly', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db.customSelect("PRAGMA table_info('capsules')").get();
    expect(
      cols.map((r) => r.data['name']),
      containsAll([
        'id',
        'unlock_type',
        'unlock_local_date',
        'trigger_mood_id',
        'trigger_quadrant',
        'payload_ct',
        'payload_clear',
        'sealed_at',
        'armed_at',
        'cycle',
        'fired_at',
        'cooldown_until',
        'opened_at',
        'deleted_at',
        'notify_at',
      ]),
    );
    final media = await db
        .customSelect("PRAGMA table_info('capsule_media')")
        .get();
    expect(
      media.map((r) => r.data['name']),
      containsAll(['capsule_id', 'slot', 'file', 'path', 'failed']),
    );
  });

  test('sign-out wipes capsules and their media rows too', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.capsules)
        .insert(
          CapsulesCompanion.insert(
            id: 'k1',
            unlockType: 'mood',
            triggerMoodId: const Value('calm'),
            payloadCt: const Value('AAAA'),
            sealedAt: DateTime.utc(2026, 10, 8, 10),
          ),
        );
    await db
        .into(db.capsuleMedia)
        .insert(CapsuleMediaCompanion.insert(capsuleId: 'k1', slot: 'voice'));
    await db.wipeUserData(keepKeys: const {});
    expect(await db.select(db.capsules).get(), isEmpty);
    expect(await db.select(db.capsuleMedia).get(), isEmpty);
  });
}
