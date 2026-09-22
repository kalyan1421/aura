import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart';

import '../../core/db/database.dart';
import '../../core/ids/ids.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/time/clock.dart';

/// A preset habit and whether it is done on the current Aura day.
class HabitToday {
  const HabitToday({required this.preset, required this.done});

  final PresetHabit preset;
  final bool done;
}

/// Preset habits: binary, self-reported, per Aura day (F2). No "missed" state.
class HabitRepository {
  HabitRepository(this._db, this._outbox, this._time, this._ids);

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final TimeContext _time;
  final Ids _ids;

  /// At most 3 active custom habits (server: `too_many_custom_habits`).
  /// There is no custom-habit UI yet; whatever adds one must check
  /// [canAddCustomHabit] first. Presets are never duplicated: [toggleToday]
  /// reuses the one row per preset key (server: `duplicate_preset_habit`).
  static const int maxActiveCustomHabits = 3;

  Future<bool> canAddCustomHabit() async {
    final active = await (_db.select(
      _db.habits,
    )..where((t) => t.kind.equals('custom') & t.active.equals(true))).get();
    return active.length < maxActiveCustomHabits;
  }

  /// Today's state for the six presets, in catalogue order.
  Stream<List<HabitToday>> watchToday(LocalDay day) {
    return _db
        .customSelect(
          'SELECT h.preset_key AS preset_key, COUNT(l.id) AS done '
          'FROM habits h LEFT JOIN habit_logs l '
          '  ON l.habit_id = h.id AND l.local_day = ? AND l.deleted_at IS NULL '
          "WHERE h.kind = 'preset' AND h.active = 1 "
          'GROUP BY h.preset_key',
          variables: [Variable.withString(day.toIso())],
          readsFrom: {_db.habits, _db.habitLogs},
        )
        .watch()
        .map((rows) {
          final done = <String>{
            for (final r in rows)
              if (r.read<int>('done') > 0) r.read<String>('preset_key'),
          };
          return [
            for (final p in presetHabits)
              HabitToday(preset: p, done: done.contains(p.key)),
          ];
        });
  }

  /// Marks [presetKey] done today, or un-marks it. The habit row itself is
  /// created lazily the first time it is used.
  Future<bool> toggleToday(String presetKey) async {
    final now = _time.now();
    final day = _time.dayOf(now);
    return _db.transaction(() async {
      var habit =
          await (_db.select(_db.habits)..where(
                (t) => t.kind.equals('preset') & t.presetKey.equals(presetKey),
              ))
              .getSingleOrNull();
      if (habit == null) {
        final id = _ids.v7();
        await _db
            .into(_db.habits)
            .insert(
              HabitsCompanion.insert(
                id: id,
                kind: 'preset',
                presetKey: Value(presetKey),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _outbox.enqueue(
          entity: Entities.habit,
          op: Ops.upsert,
          entityId: id,
          deviceTs: now,
          localDay: day,
          tz: _time.timezone,
          payload: {
            'id': id,
            'kind': 'preset',
            'presetKey': presetKey,
            'name': null,
            'active': true,
          },
        );
        habit = await (_db.select(
          _db.habits,
        )..where((t) => t.id.equals(id))).getSingle();
      }

      final logs = await (_db.select(_db.habitLogs)..where(
            (t) =>
                t.habitId.equals(habit!.id) & t.localDay.equals(day.toIso()),
          ))
          .get();
      final live = logs.where((l) => l.deletedAt == null).firstOrNull;

      if (live == null) {
        // One log per habit per Aura day: re-marking after an un-mark reuses
        // the same id (the server rejects a second id as `already_logged`).
        final previous = logs.firstOrNull;
        final logId = previous?.id ?? _ids.v7();
        if (previous != null) {
          await (_db.update(_db.habitLogs)..where((t) => t.id.equals(logId)))
              .write(
                HabitLogsCompanion(
                  deletedAt: const Value(null),
                  synced: const Value(false),
                  tz: Value(_time.timezone),
                ),
              );
        } else {
          await _db
              .into(_db.habitLogs)
              .insert(
                HabitLogsCompanion.insert(
                  id: logId,
                  habitId: habit.id,
                  localDay: day.toIso(),
                  deviceTs: now,
                  tz: Value(_time.timezone),
                ),
              );
        }
        await _outbox.enqueue(
          entity: Entities.habitLog,
          op: Ops.upsert,
          entityId: logId,
          deviceTs: now,
          localDay: day,
          tz: _time.timezone,
          payload: {'id': logId, 'habitId': habit.id},
        );
        return true;
      }

      // Un-mark: a tombstone locally (Starlight already earned stays, as on
      // the server) and a delete mutation.
      await (_db.update(_db.habitLogs)..where((t) => t.id.equals(live.id)))
          .write(HabitLogsCompanion(deletedAt: Value(now)));
      await _outbox.enqueue(
        entity: Entities.habitLog,
        op: Ops.delete,
        entityId: live.id,
        deviceTs: now,
        localDay: day,
        tz: _time.timezone,
        payload: {'id': live.id},
      );
      return false;
    });
  }
}
