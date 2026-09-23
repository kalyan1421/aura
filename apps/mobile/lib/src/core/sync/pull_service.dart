import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../features/progress/progress_repository.dart';
import '../db/database.dart';
import '../db/kv_store.dart';
import '../ids/ids.dart';
import '../net/aura_api.dart';
import '../security/note_cipher.dart';
import 'outbox_repository.dart';

/// Pulls the user's own rows from Supabase (RLS select-own) after sign-in,
/// e.g. on a new phone. Never writes to Supabase (all writes go through
/// NestJS).
///
/// TODO(sync): per-entity delta pulls with a server cursor (PRD Offline); this
/// is a full pull once per user per install.
class PullService {
  PullService({
    required this._db,
    required this._kv,
    required this._progress,
    required this._dataKeys,
    this._ids = const Ids(),
  });

  final AppDatabase _db;
  final KvStore _kv;
  final ProgressRepository _progress;
  final DataKeyRepository _dataKeys;
  final Ids _ids;

  static const int _page = 500;

  Future<bool> alreadyPulled(String userId) async =>
      await _kv.get(KvKeys.pulledFor) == userId;

  /// [isCurrent] turns false if the account signs out meanwhile: nothing
  /// fetched for it is written after that (sign-out wipes this phone).
  Future<void> pullAll({
    required sb.SupabaseClient client,
    required String userId,
    required AuraApi api,
    bool Function()? isCurrent,
  }) async {
    bool current() => isCurrent?.call() ?? true;
    final cipher = await _dataKeys.cipherFor(userId, api: api);

    final checkIns = await _all(
      client,
      'check_ins',
      'id,mood_id,quadrant,tags,note_ct,voice_path,local_day,device_ts,source',
    );
    final habits = await _all(
      client,
      'habits',
      'id,kind,preset_key,name,active,created_at,updated_at',
    );
    final logs = await _all(
      client,
      'habit_logs',
      'id,habit_id,local_day,device_ts',
    );

    final notes = <String, String?>{};
    for (final c in checkIns) {
      final ct = c['note_ct'] as String?;
      if (ct == null || cipher == null) continue;
      try {
        notes[c['id'] as String] = await cipher.decrypt(
          ct,
          recordId: c['id'] as String,
        );
      } on Object {
        // Undecryptable (other key / corrupt): keep the entry without its note.
      }
    }

    if (!current()) return;
    await _db.transaction(() async {
      for (final c in checkIns) {
        final ts = DateTime.parse(c['device_ts'] as String).toUtc();
        final id = c['id'] as String;
        final existing = await (_db.select(
          _db.checkIns,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        final serverHasNote = c['note_ct'] != null;
        // Voice notes are fetched lazily when played (download-url → GET →
        // decrypt); only the server object's path is kept here.
        final voicePath = c['voice_path'] as String?;
        if (existing != null) {
          if (voicePath != null &&
              existing.voicePath == null &&
              existing.voiceFile == null &&
              existing.synced) {
            await (_db.update(_db.checkIns)..where((t) => t.id.equals(id)))
                .write(CheckInsCompanion(voicePath: Value(voicePath)));
          }
          // A later pull may bring a note the first one could not decrypt.
          if (existing.note == null && notes[id] != null) {
            await (_db.update(
              _db.checkIns,
            )..where((t) => t.id.equals(id))).write(
              CheckInsCompanion(
                note: Value(notes[id]),
                noteLocked: const Value(false),
              ),
            );
          } else if (existing.note == null &&
              serverHasNote &&
              !existing.noteLocked) {
            await (_db.update(_db.checkIns)..where((t) => t.id.equals(id)))
                .write(const CheckInsCompanion(noteLocked: Value(true)));
          }
          continue;
        }
        await _db
            .into(_db.checkIns)
            .insert(
              CheckInsCompanion.insert(
                id: c['id'] as String,
                moodId: c['mood_id'] as String,
                quadrant: c['quadrant'] as String,
                tags: Value(
                  ((c['tags'] as List<dynamic>?) ?? const []).cast<String>(),
                ),
                note: Value(notes[id]),
                noteLocked: Value(serverHasNote && notes[id] == null),
                localDay: c['local_day'] as String,
                deviceTs: ts,
                tzOffsetMinutes: 0,
                source: Value((c['source'] as String?) ?? 'app'),
                synced: const Value(true),
                voicePath: Value(voicePath),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      await _insertHabits(habits);
      for (final l in logs) {
        await _db
            .into(_db.habitLogs)
            .insert(
              HabitLogsCompanion.insert(
                id: l['id'] as String,
                habitId: l['habit_id'] as String,
                localDay: l['local_day'] as String,
                deviceTs: DateTime.parse(l['device_ts'] as String).toUtc(),
                synced: const Value(true),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });

    await mergePresetHabits(habits);

    try {
      final snapshot = await api.snapshot();
      if (!current()) return;
      await _progress.saveSnapshot(snapshot);
    } on ApiException {
      // The next push returns a snapshot anyway.
    }
    if (!current()) return;
    // Without the data key (API unreachable) encrypted notes could not be
    // read yet: stay un-pulled so the next sync fills them in.
    final notesPending =
        cipher == null && checkIns.any((c) => c['note_ct'] != null);
    if (!notesPending) await _kv.set(KvKeys.pulledFor, userId);
  }

  /// After a `duplicate_preset_habit` rejection: fetch the server's habits
  /// and merge local duplicates into them.
  Future<void> reconcilePresetHabits(sb.SupabaseClient client) async {
    final habits = await _all(
      client,
      'habits',
      'id,kind,preset_key,name,active,created_at,updated_at',
    );
    await _db.transaction(() => _insertHabits(habits));
    await mergePresetHabits(habits);
  }

  Future<void> _insertHabits(List<Map<String, dynamic>> habits) async {
    for (final h in habits) {
      await _db
          .into(_db.habits)
          .insert(
            HabitsCompanion.insert(
              id: h['id'] as String,
              kind: h['kind'] as String,
              presetKey: Value(h['preset_key'] as String?),
              name: Value(h['name'] as String?),
              active: Value((h['active'] as bool?) ?? true),
              createdAt: DateTime.parse(h['created_at'] as String).toUtc(),
              updatedAt: DateTime.parse(h['updated_at'] as String).toUtc(),
              synced: const Value(true),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  /// Each preset key exists once per user (server: `duplicate_preset_habit`).
  /// A local preset habit that duplicates a server one (same key, other id —
  /// e.g. created offline before the first pull) is merged into the server's:
  /// its logs move over (a day the server already has is dropped), pending
  /// and dead-lettered log mutations are re-pointed and re-queued, and the
  /// duplicate habit with its pending upsert is removed. Returns merges done.
  Future<int> mergePresetHabits(List<Map<String, dynamic>> serverHabits) {
    return _db.transaction(() async {
      var merged = 0;
      for (final s in serverHabits) {
        final key = s['preset_key'] as String?;
        if (s['kind'] != 'preset' || key == null) continue;
        final serverId = s['id'] as String;
        final dups =
            await (_db.select(_db.habits)..where(
                  (t) =>
                      t.kind.equals('preset') &
                      t.presetKey.equals(key) &
                      t.id.equals(serverId).not(),
                ))
                .get();
        for (final d in dups) {
          merged++;
          final logs = await (_db.select(
            _db.habitLogs,
          )..where((t) => t.habitId.equals(d.id))).get();
          for (final l in logs) {
            final clash =
                await (_db.select(_db.habitLogs)..where(
                      (t) =>
                          t.habitId.equals(serverId) &
                          t.localDay.equals(l.localDay),
                    ))
                    .getSingleOrNull();
            if (clash != null) {
              await (_db.delete(
                _db.habitLogs,
              )..where((t) => t.id.equals(l.id))).go();
              await (_db.delete(
                _db.outbox,
              )..where((t) => t.entityId.equals(l.id))).go();
            } else {
              await (_db.update(_db.habitLogs)..where((t) => t.id.equals(l.id)))
                  .write(HabitLogsCompanion(habitId: Value(serverId)));
            }
          }

          final pending = await (_db.select(
            _db.outbox,
          )..where((t) => t.entity.equals(Entities.habitLog))).get();
          for (final p in pending) {
            final payload = jsonDecode(p.payload) as Map<String, dynamic>;
            if (payload['habitId'] != d.id) continue;
            payload['habitId'] = serverId;
            await (_db.update(
              _db.outbox,
            )..where((t) => t.seq.equals(p.seq))).write(
              OutboxCompanion(
                payload: Value(jsonEncode(payload)),
                nextAttemptAt: const Value(null),
              ),
            );
          }

          final dead = await (_db.select(
            _db.deadLetters,
          )..where((t) => t.entity.equals(Entities.habitLog))).get();
          for (final x in dead) {
            final payload = jsonDecode(x.payload) as Map<String, dynamic>;
            if (payload['habitId'] != d.id) continue;
            final stillThere = await (_db.select(
              _db.habitLogs,
            )..where((t) => t.id.equals(x.entityId))).getSingleOrNull();
            if (stillThere != null &&
                x.op == Ops.upsert &&
                x.deviceTs != null &&
                x.localDay != null) {
              payload['habitId'] = serverId;
              await _db
                  .into(_db.outbox)
                  .insert(
                    OutboxCompanion.insert(
                      mutationId: _ids.v7(),
                      entity: x.entity,
                      op: x.op,
                      entityId: x.entityId,
                      deviceTs: x.deviceTs!,
                      localDay: x.localDay!,
                      tz: Value(x.tz),
                      payload: jsonEncode(payload),
                      createdAt: DateTime.now().toUtc(),
                    ),
                  );
            }
            await (_db.delete(
              _db.deadLetters,
            )..where((t) => t.seq.equals(x.seq))).go();
          }

          await (_db.delete(_db.outbox)..where(
                (t) =>
                    t.entity.equals(Entities.habit) & t.entityId.equals(d.id),
              ))
              .go();
          await (_db.delete(_db.deadLetters)..where(
                (t) =>
                    t.entity.equals(Entities.habit) & t.entityId.equals(d.id),
              ))
              .go();
          await (_db.delete(_db.habits)..where((t) => t.id.equals(d.id))).go();
        }
      }
      return merged;
    });
  }

  Future<List<Map<String, dynamic>>> _all(
    sb.SupabaseClient client,
    String table,
    String columns,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (var from = 0; ; from += _page) {
      final rows = await client
          .from(table)
          .select(columns)
          .order('id')
          .range(from, from + _page - 1);
      out.addAll(rows);
      if (rows.length < _page) break;
    }
    return out;
  }
}
