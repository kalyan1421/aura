import 'dart:async';

import 'package:aura_domain/aura_domain.dart';

import '../../core/db/database.dart';
import '../../core/db/kv_store.dart';
import '../../core/net/api_models.dart';

/// Reads the local rows the progression projection needs, and the cached
/// server snapshot.
class ProgressRepository {
  ProgressRepository(this._db, this._kv);

  final AppDatabase _db;
  final KvStore _kv;

  /// Every stored check-in and habit completion (tombstones included:
  /// deleting never removes Starlight or glow days).
  Stream<List<ProgressEvent>> watchEvents() {
    return _db
        .customSelect(
          'SELECT id, quadrant, local_day, device_ts, deleted_at, tz, '
          "  'c' AS kind, NULL AS habit_id, NULL AS preset_key "
          'FROM check_ins '
          'UNION ALL '
          'SELECT l.id, NULL, l.local_day, l.device_ts, l.deleted_at, l.tz, '
          "  'h', l.habit_id, h.preset_key "
          'FROM habit_logs l LEFT JOIN habits h ON h.id = l.habit_id',
          readsFrom: {_db.checkIns, _db.habitLogs, _db.habits},
        )
        .watch()
        .map((rows) {
          final out = <ProgressEvent>[];
          for (final r in rows) {
            final ts = DateTime.parse(r.read<String>('device_ts')).toUtc();
            final day = LocalDay.parse(r.read<String>('local_day'));
            final deleted = r.readNullable<String>('deleted_at') != null;
            final tz = r.readNullable<String>('tz');
            if (r.read<String>('kind') == 'c') {
              final q = quadrantByName(r.read<String>('quadrant'));
              if (q == null) continue;
              out.add(
                ProgressEvent.checkIn(
                  id: r.read<String>('id'),
                  deviceTs: ts,
                  localDay: day,
                  quadrant: q,
                  timezone: tz,
                  deleted: deleted,
                ),
              );
            } else {
              out.add(
                ProgressEvent.habit(
                  id: r.read<String>('id'),
                  deviceTs: ts,
                  localDay: day,
                  habitId: r.read<String>('habit_id'),
                  habitKey: r.readNullable<String>('preset_key'),
                  timezone: tz,
                  deleted: deleted,
                ),
              );
            }
          }
          return out;
        });
  }

  Stream<Snapshot?> watchSnapshot() => _kv
      .watchJson(KvKeys.snapshot)
      .map((j) => j == null ? null : Snapshot.fromJson(j));

  Future<void> saveSnapshot(Snapshot snapshot) =>
      _kv.setJson(KvKeys.snapshot, snapshot.toJson());

  Future<double?> lastHue() async {
    final v = await _kv.get(KvKeys.lastHue);
    return v == null ? null : double.tryParse(v);
  }

  Future<void> saveLastHue(double hue) =>
      _kv.set(KvKeys.lastHue, hue.toStringAsFixed(2));
}
