import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../features/progress/progress_repository.dart';
import '../db/database.dart';
import '../db/kv_store.dart';
import '../ids/ids.dart';
import '../net/aura_api.dart';
import '../security/note_cipher.dart';
import 'outbox_repository.dart';

/// Pulls the user's own rows from Supabase (RLS select-own). Never writes to
/// Supabase (all writes go through NestJS).
///
/// - [pullAll]: everything, once per user per install (e.g. a new phone).
/// - [pullDelta]: afterwards, per-entity deltas since server cursors
///   (PRD 16 "Pull: per-entity delta since a server sequence cursor, after
///   each push and on foreground"), so two phones' pulls merge: rows changed
///   or added on another phone, and deletions there (`sync_tombstones`,
///   migration 20261005000032). A row this phone hasn't sent yet is never
///   overwritten; a server tombstone always wins.
class PullService {
  PullService({
    required this._db,
    required this._kv,
    required this._progress,
    required this._dataKeys,
    this._ids = const Ids(),
  }) : _outbox = OutboxRepository(_db, _ids);

  final AppDatabase _db;
  final OutboxRepository _outbox;
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

    final checkIns = await _all(client, 'check_ins', _checkInColumns);
    final habits = await _all(client, 'habits', _habitColumns);
    final logs = await _all(client, 'habit_logs', _logColumns);
    final tombstones = await client
        .from('sync_tombstones')
        .select('deleted_at')
        .order('deleted_at', ascending: false)
        .limit(1);

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
    if (!notesPending) {
      await _saveCursor(
        PullCursor(
          userId: userId,
          checkIns: _maxTs(checkIns, 'updated_at'),
          habits: _maxTs(habits, 'updated_at'),
          habitLogs: _maxTs(logs, 'server_ts'),
          tombstones: _maxTs(tombstones, 'deleted_at'),
          at: DateTime.now().toUtc(),
        ),
      );
      await _kv.set(KvKeys.pulledFor, userId);
    }
  }

  // ---- delta pulls (PRD 16) -------------------------------------------------------

  static const String _checkInColumns =
      'id,mood_id,quadrant,tags,note_ct,voice_path,local_day,device_ts,source,'
      'updated_at';
  static const String _habitColumns =
      'id,kind,preset_key,name,active,created_at,updated_at';
  static const String _logColumns = 'id,habit_id,local_day,device_ts,server_ts';

  /// Server tombstones are kept this long (server `SYNC_TOMBSTONE_RETENTION_DAYS`
  /// is 400); a phone whose last pull is older re-reads everything instead.
  static const Duration tombstoneHorizon = Duration(days: 390);

  /// Rows changed on the server since this phone's cursors, and deletions
  /// there. Without a cursor (a phone that pulled before cursors existed) or
  /// with one older than [tombstoneHorizon], re-reads everything and drops
  /// synced rows the server no longer has. Writes nothing once [isCurrent]
  /// turns false.
  Future<void> pullDelta({
    required sb.SupabaseClient client,
    required String userId,
    required AuraApi api,
    bool Function()? isCurrent,
    DateTime? now,
  }) async {
    bool current() => isCurrent?.call() ?? true;
    final at = (now ?? DateTime.now()).toUtc();
    final saved = await _readCursor(userId);
    final full = saved == null || at.difference(saved.at) > tombstoneHorizon;
    final cursor = full ? PullCursor(userId: userId, at: at) : saved;

    final checkIns = await _since(
      client,
      'check_ins',
      _checkInColumns,
      'updated_at',
      cursor.checkIns,
    );
    final habits = await _since(
      client,
      'habits',
      _habitColumns,
      'updated_at',
      cursor.habits,
    );
    final logs = await _since(
      client,
      'habit_logs',
      _logColumns,
      'server_ts',
      cursor.habitLogs,
    );
    final tombstones = await _since(
      client,
      'sync_tombstones',
      'entity,entity_id,deleted_at',
      'deleted_at',
      cursor.tombstones,
      idColumn: 'entity_id',
    );
    if (!current()) return;

    final cipher = await _dataKeys.cipherFor(userId, api: api);
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
        // Undecryptable: the entry keeps (or gets) a locked note.
      }
    }
    if (!current()) return;

    await _db.transaction(() async {
      for (final c in checkIns) {
        await _mergeCheckIn(c, notes[c['id'] as String]);
      }
      for (final h in habits) {
        await _mergeHabit(h);
      }
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
      for (final t in tombstones) {
        await _applyTombstone(t['entity'] as String, t['entity_id'] as String);
      }
      if (full) {
        await _prune(
          checkIns: {for (final c in checkIns) c['id'] as String},
          habits: {for (final h in habits) h['id'] as String},
          logs: {for (final l in logs) l['id'] as String},
        );
      }
    });
    if (habits.isNotEmpty) await mergePresetHabits(habits);
    if (!current()) return;

    await _saveCursor(
      PullCursor(
        userId: userId,
        checkIns: _maxTs(checkIns, 'updated_at') ?? cursor.checkIns,
        habits: _maxTs(habits, 'updated_at') ?? cursor.habits,
        habitLogs: _maxTs(logs, 'server_ts') ?? cursor.habitLogs,
        tombstones: _maxTs(tombstones, 'deleted_at') ?? cursor.tombstones,
        at: at,
      ),
    );
  }

  /// A check-in changed (or added) on the server. This phone's own unsent
  /// change, or its local delete, wins until it is sent.
  Future<void> _mergeCheckIn(Map<String, dynamic> c, String? note) async {
    final id = c['id'] as String;
    final existing = await (_db.select(
      _db.checkIns,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final serverHasNote = c['note_ct'] != null;
    final voicePath = c['voice_path'] as String?;
    final tags = ((c['tags'] as List<dynamic>?) ?? const []).cast<String>();
    if (existing == null) {
      await _db
          .into(_db.checkIns)
          .insert(
            CheckInsCompanion.insert(
              id: id,
              moodId: c['mood_id'] as String,
              quadrant: c['quadrant'] as String,
              tags: Value(tags),
              note: Value(note),
              noteLocked: Value(serverHasNote && note == null),
              localDay: c['local_day'] as String,
              deviceTs: DateTime.parse(c['device_ts'] as String).toUtc(),
              tzOffsetMinutes: 0,
              source: Value((c['source'] as String?) ?? 'app'),
              synced: const Value(true),
              voicePath: Value(voicePath),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      return;
    }
    if (existing.deletedAt != null || await _outbox.hasPending(id)) return;
    final voiceChanged = voicePath != existing.voicePath;
    await (_db.update(_db.checkIns)..where((t) => t.id.equals(id))).write(
      CheckInsCompanion(
        moodId: Value(c['mood_id'] as String),
        quadrant: Value(c['quadrant'] as String),
        tags: Value(tags),
        // A note edited on another phone: the new text, or locked when this
        // phone can't read it yet. No note on the server: none here either.
        note: Value(serverHasNote ? (note ?? existing.note) : null),
        noteLocked: Value(
          serverHasNote && note == null && existing.note == null,
        ),
        // The voice note was replaced or removed elsewhere: follow the server
        // (the old local file becomes unreferenced and is swept).
        voicePath: Value(voicePath),
        voiceFile: voiceChanged ? const Value(null) : const Value.absent(),
        voiceMs: voiceChanged ? const Value(null) : const Value.absent(),
        synced: const Value(true),
      ),
    );
  }

  Future<void> _mergeHabit(Map<String, dynamic> h) async {
    final id = h['id'] as String;
    final existing = await (_db.select(
      _db.habits,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      await _insertHabits([h]);
      return;
    }
    if (await _outbox.hasPending(id)) return;
    await (_db.update(_db.habits)..where((t) => t.id.equals(id))).write(
      HabitsCompanion(
        name: Value(h['name'] as String?),
        active: Value((h['active'] as bool?) ?? true),
        updatedAt: Value(DateTime.parse(h['updated_at'] as String).toUtc()),
        synced: const Value(true),
      ),
    );
  }

  /// Deleted on the server (by this account, on any phone): a tombstone
  /// always wins. Mirrors what a local delete leaves behind.
  Future<void> _applyTombstone(String entity, String id) async {
    await (_db.delete(_db.outbox)..where((t) => t.entityId.equals(id))).go();
    switch (entity) {
      case Entities.checkIn:
        await (_db.update(
          _db.checkIns,
        )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
          CheckInsCompanion(
            deletedAt: Value(DateTime.now().toUtc()),
            note: const Value(null),
            tags: const Value([]),
            voiceFile: const Value(null),
            voiceMs: const Value(null),
            voicePath: const Value(null),
            synced: const Value(true),
          ),
        );
      case Entities.habit:
        await (_db.update(
          _db.habitLogs,
        )..where((t) => t.habitId.equals(id) & t.deletedAt.isNull())).write(
          HabitLogsCompanion(deletedAt: Value(DateTime.now().toUtc())),
        );
        await (_db.delete(_db.habits)..where((t) => t.id.equals(id))).go();
      case Entities.habitLog:
        await (_db.update(
          _db.habitLogs,
        )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
          HabitLogsCompanion(deletedAt: Value(DateTime.now().toUtc())),
        );
    }
  }

  /// After a full re-read: synced rows the server no longer has were deleted
  /// elsewhere longer ago than tombstones are kept. Unsent rows stay.
  Future<void> _prune({
    required Set<String> checkIns,
    required Set<String> habits,
    required Set<String> logs,
  }) async {
    final ci = await (_db.select(
      _db.checkIns,
    )..where((t) => t.synced.equals(true) & t.deletedAt.isNull())).get();
    for (final r in ci) {
      if (!checkIns.contains(r.id) && !await _outbox.hasPending(r.id)) {
        await _applyTombstone(Entities.checkIn, r.id);
      }
    }
    final hs = await (_db.select(
      _db.habits,
    )..where((t) => t.synced.equals(true))).get();
    for (final r in hs) {
      if (!habits.contains(r.id) && !await _outbox.hasPending(r.id)) {
        await _applyTombstone(Entities.habit, r.id);
      }
    }
    final ls = await (_db.select(
      _db.habitLogs,
    )..where((t) => t.synced.equals(true) & t.deletedAt.isNull())).get();
    for (final r in ls) {
      if (!logs.contains(r.id) && !await _outbox.hasPending(r.id)) {
        await _applyTombstone(Entities.habitLog, r.id);
      }
    }
  }

  Future<PullCursor?> _readCursor(String userId) async {
    final raw = await _kv.get(KvKeys.pullCursor);
    if (raw == null) return null;
    try {
      final c = PullCursor.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return c.userId == userId ? c : null;
    } on Object {
      return null;
    }
  }

  Future<void> _saveCursor(PullCursor c) =>
      _kv.set(KvKeys.pullCursor, jsonEncode(c.toJson()));

  /// The latest server timestamp among [rows] (the raw string, so no
  /// precision is lost), or null.
  static String? _maxTs(List<Map<String, dynamic>> rows, String column) {
    String? best;
    DateTime? bestAt;
    for (final r in rows) {
      final v = r[column] as String?;
      final t = v == null ? null : DateTime.tryParse(v);
      if (t != null && (bestAt == null || t.isAfter(bestAt))) {
        best = v;
        bestAt = t;
      }
    }
    return best;
  }

  /// Rows with [tsColumn] ≥ [since] (all when null), oldest first, paged.
  /// "≥", not ">": rows sharing the cursor's timestamp are read again rather
  /// than missed (applying them twice changes nothing).
  Future<List<Map<String, dynamic>>> _since(
    sb.SupabaseClient client,
    String table,
    String columns,
    String tsColumn,
    String? since, {
    String idColumn = 'id',
  }) async {
    final out = <Map<String, dynamic>>[];
    for (var from = 0; ; from += _page) {
      var q = client.from(table).select(columns);
      if (since != null) q = q.gte(tsColumn, since);
      final rows = await q
          .order(tsColumn)
          .order(idColumn)
          .range(from, from + _page - 1);
      out.addAll(rows);
      if (rows.length < _page) break;
    }
    return out;
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

/// Where the last delta pull got to: the newest server timestamp seen per
/// entity (raw strings), and when it ran (device time, for the tombstone
/// horizon only).
@immutable
class PullCursor {
  const PullCursor({
    required this.userId,
    required this.at,
    this.checkIns,
    this.habits,
    this.habitLogs,
    this.tombstones,
  });

  factory PullCursor.fromJson(Map<String, dynamic> j) => PullCursor(
    userId: j['userId'] as String,
    at: DateTime.parse(j['at'] as String).toUtc(),
    checkIns: j['checkIns'] as String?,
    habits: j['habits'] as String?,
    habitLogs: j['habitLogs'] as String?,
    tombstones: j['tombstones'] as String?,
  );

  final String userId;
  final DateTime at;
  final String? checkIns;
  final String? habits;
  final String? habitLogs;
  final String? tombstones;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'at': at.toIso8601String(),
    'checkIns': checkIns,
    'habits': habits,
    'habitLogs': habitLogs,
    'tombstones': tombstones,
  };
}
