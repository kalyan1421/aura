import 'package:drift/drift.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [CheckIns, Habits, HabitLogs, Outbox, DeadLetters, KeyValues],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS check_ins_day ON check_ins (local_day)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS habit_logs_day '
        'ON habit_logs (habit_id, local_day)',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2: per-record IANA zone (the day was stamped in it).
        await m.addColumn(checkIns, checkIns.tz);
        await m.addColumn(habitLogs, habitLogs.tz);
        await m.addColumn(outbox, outbox.tz);
        await m.addColumn(deadLetters, deadLetters.deviceTs);
        await m.addColumn(deadLetters, deadLetters.localDay);
        await m.addColumn(deadLetters, deadLetters.tz);
      }
      if (from < 3) {
        // v3: a pulled note this phone can't read yet blocks edits.
        await m.addColumn(checkIns, checkIns.noteLocked);
      }
      if (from < 4) {
        // v4: voice notes (F1) — the local file, its length, the server
        // object, and outbox rows that wait for their upload.
        await m.addColumn(checkIns, checkIns.voiceFile);
        await m.addColumn(checkIns, checkIns.voiceMs);
        await m.addColumn(checkIns, checkIns.voicePath);
        await m.addColumn(outbox, outbox.needsMedia);
        await m.addColumn(outbox, outbox.mediaAttempts);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ---- sign-out ------------------------------------------------------------

  /// Sign-out on a shared phone: deletes every personal row (all tables,
  /// including ones added later) and every key/value except [keepKeys]
  /// (device-scoped settings), in one transaction.
  Future<void> wipeUserData({required Set<String> keepKeys}) =>
      transaction(() async {
        for (final table in allTables) {
          if (table is $KeyValuesTable) continue;
          await delete(table).go();
        }
        await (delete(keyValues)..where((t) => t.key.isNotIn(keepKeys))).go();
      });

  // ---- key/value ---------------------------------------------------------

  Future<String?> getValue(String key) async {
    final row = await (select(
      keyValues,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchValue(String key) => (select(
    keyValues,
  )..where((t) => t.key.equals(key))).watchSingleOrNull().map((r) => r?.value);

  Future<void> setValue(String key, String? value) async {
    if (value == null) {
      await (delete(keyValues)..where((t) => t.key.equals(key))).go();
    } else {
      await into(keyValues).insertOnConflictUpdate(
        KeyValuesCompanion.insert(key: key, value: value),
      );
    }
  }
}
