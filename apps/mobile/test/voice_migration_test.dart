import 'package:aura/src/core/db/database.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Schema v3 → v4 (voice notes): existing check-ins and queued mutations are
/// kept; the new columns start empty / false / 0.
void main() {
  // The v3 schema exactly as drift created it (dumped before v4).
  const v3 = [
    'CREATE TABLE "check_ins" ("id" TEXT NOT NULL, "mood_id" TEXT NOT NULL, '
        '"quadrant" TEXT NOT NULL, "tags" TEXT NOT NULL DEFAULT \'[]\', '
        '"note" TEXT NULL, "local_day" TEXT NOT NULL, "device_ts" TEXT NOT NULL, '
        '"tz_offset_minutes" INTEGER NOT NULL, "tz" TEXT NULL, '
        '"source" TEXT NOT NULL DEFAULT \'app\', "deleted_at" TEXT NULL, '
        '"synced" INTEGER NOT NULL DEFAULT 0 CHECK ("synced" IN (0, 1)), '
        '"note_locked" INTEGER NOT NULL DEFAULT 0 CHECK ("note_locked" IN (0, 1)), '
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
        '"created_at" TEXT NOT NULL)',
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
        "device_ts, tz_offset_minutes, tz, synced) VALUES ('c1', 'calm', "
        "'moonlight', '[\"family\"]', 'tea', '2026-10-08', "
        "'2026-10-08T10:00:00.000Z', 330, 'Asia/Kolkata', 1)",
    "INSERT INTO outbox (mutation_id, entity, op, entity_id, device_ts, "
        "local_day, tz, payload, needs_note, attempts, created_at) VALUES "
        "('m1', 'check_in', 'upsert', 'c1', '2026-10-08T10:00:00.000Z', "
        "'2026-10-08', 'Asia/Kolkata', '{\"id\":\"c1\"}', 1, 2, "
        "'2026-10-08T10:00:00.000Z')",
    'PRAGMA user_version = 3',
  ];

  test('v3 → v4 keeps every row and adds the voice columns', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final sql in v3) {
            raw.execute(sql);
          }
        },
      ),
    );
    addTearDown(db.close);

    final c = await db.select(db.checkIns).getSingle(); // opens + migrates
    // Migrates through v4 to the current version (v5 added capsules).
    expect(db.schemaVersion, greaterThanOrEqualTo(4));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, db.schemaVersion);

    expect(c.id, 'c1');
    expect(c.note, 'tea');
    expect(c.tags, ['family']);
    expect(c.synced, isTrue);
    expect(c.voiceFile, isNull);
    expect(c.voiceMs, isNull);
    expect(c.voicePath, isNull);

    final o = await db.select(db.outbox).getSingle();
    expect(o.mutationId, 'm1');
    expect(o.needsNote, isTrue);
    expect(o.attempts, 2);
    expect(o.needsMedia, isFalse);
    expect(o.mediaAttempts, 0);

    // The new columns are usable.
    await (db.update(db.checkIns)..where((t) => t.id.equals('c1'))).write(
      const CheckInsCompanion(
        voiceFile: Value('r.enc'),
        voiceMs: Value(1200),
        voicePath: Value('u/voice/c1'),
      ),
    );
    final after = await db.select(db.checkIns).getSingle();
    expect(after.voiceFile, 'r.enc');
    expect(after.voiceMs, 1200);
    expect(after.voicePath, 'u/voice/c1');
  });

  test('a fresh install creates v4 directly', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db.customSelect("PRAGMA table_info('outbox')").get();
    expect(
      cols.map((r) => r.data['name']),
      containsAll(['needs_media', 'media_attempts']),
    );
    final ci = await db.customSelect("PRAGMA table_info('check_ins')").get();
    expect(
      ci.map((r) => r.data['name']),
      containsAll(['voice_file', 'voice_ms', 'voice_path']),
    );
  });
}
