import 'dart:convert';
import 'dart:math';

import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';
import '../ids/ids.dart';

/// Mutation entities accepted by `POST /v1/sync/push`.
abstract final class Entities {
  static const String checkIn = 'check_in';
  static const String habit = 'habit';
  static const String habitLog = 'habit_log';

  /// F4 time capsules (contracts/api/v1-capsules.md §2): ops [Ops.seal],
  /// [Ops.open], [Ops.fire], [Ops.rearm], [Ops.delete].
  static const String capsule = 'capsule';
}

abstract final class Ops {
  static const String upsert = 'upsert';
  static const String delete = 'delete';

  // Capsule ops.
  static const String seal = 'seal';
  static const String open = 'open';
  static const String fire = 'fire';
  static const String rearm = 'rearm';
}

/// The local outbox. Writers call [enqueue] inside the same transaction as
/// the domain row, so a record and its mutation always land together.
class OutboxRepository {
  OutboxRepository(this._db, this._ids);

  final AppDatabase _db;
  final Ids _ids;

  static const int batchSize = 50;
  static const int maxAttempts = 10;
  static const Duration maxBackoff = Duration(hours: 1);

  Future<void> enqueue({
    required String entity,
    required String op,
    required String entityId,
    required DateTime deviceTs,
    required LocalDay localDay,
    required Map<String, Object?> payload,
    required String tz,
    bool needsNote = false,
    bool needsMedia = false,
  }) async {
    await _db
        .into(_db.outbox)
        .insert(
          OutboxCompanion.insert(
            mutationId: _ids.v7(),
            entity: entity,
            op: op,
            entityId: entityId,
            deviceTs: deviceTs.toUtc(),
            localDay: localDay.toIso(),
            tz: Value(tz),
            payload: jsonEncode(payload),
            needsNote: Value(needsNote),
            needsMedia: Value(needsMedia),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  /// Oldest-first rows whose backoff has elapsed.
  Future<List<OutboxRow>> due(DateTime now, {int limit = batchSize}) =>
      (_db.select(_db.outbox)
            ..where(
              (t) =>
                  t.nextAttemptAt.isNull() |
                  t.nextAttemptAt.isSmallerOrEqualValue(now.toUtc()),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.seq)])
            ..limit(limit))
          .get();

  Stream<int> watchCount() {
    final count = _db.outbox.seq.count();
    return (_db.selectOnly(
      _db.outbox,
    )..addColumns([count])).watchSingle().map((r) => r.read(count) ?? 0);
  }

  Future<int> count() async {
    final count = _db.outbox.seq.count();
    final r = await (_db.selectOnly(
      _db.outbox,
    )..addColumns([count])).getSingle();
    return r.read(count) ?? 0;
  }

  /// Sequence numbers of every pending row, per record id (ascending), for
  /// keeping one record's mutations in order across batches and backoff.
  Future<Map<String, List<int>>> seqsByEntity() async {
    final rows =
        await (_db.selectOnly(_db.outbox)
              ..addColumns([_db.outbox.seq, _db.outbox.entityId])
              ..orderBy([OrderingTerm.asc(_db.outbox.seq)]))
            .get();
    final out = <String, List<int>>{};
    for (final r in rows) {
      final String entityId = r.read(_db.outbox.entityId)!;
      final int seq = r.read(_db.outbox.seq)!;
      (out[entityId] ??= <int>[]).add(seq);
    }
    return out;
  }

  /// A voice upload for [row] failed (network, `503 media_unavailable`…).
  /// Backs the row off like a failed push. After [maxAttempts] failed uploads
  /// the outbox gives up on the media: the row no longer waits for it and
  /// goes out without `voicePath` (the recording stays on the phone for a
  /// later edit). Returns true when it gave up.
  Future<bool> mediaFailed(OutboxRow row, DateTime now) async {
    final attempts = row.mediaAttempts + 1;
    if (attempts >= maxAttempts) {
      await (_db.update(_db.outbox)..where((t) => t.seq.equals(row.seq))).write(
        OutboxCompanion(
          mediaAttempts: Value(attempts),
          needsMedia: const Value(false),
        ),
      );
      return true;
    }
    final base = Duration(seconds: 2 << min(attempts, 11));
    final wait = base > maxBackoff ? maxBackoff : base;
    final jitter = Duration(milliseconds: Random().nextInt(1000));
    await (_db.update(_db.outbox)..where((t) => t.seq.equals(row.seq))).write(
      OutboxCompanion(
        mediaAttempts: Value(attempts),
        nextAttemptAt: Value(now.toUtc().add(wait + jitter)),
      ),
    );
    return false;
  }

  /// The row no longer waits for media (nothing to upload, or it can never
  /// be uploaded, e.g. `media_too_large`).
  Future<void> dropMedia(OutboxRow row) =>
      (_db.update(_db.outbox)..where((t) => t.seq.equals(row.seq))).write(
        const OutboxCompanion(needsMedia: Value(false)),
      );

  /// Earliest scheduled retry, if any row is waiting on backoff.
  Future<DateTime?> nextRetryAt() async {
    final row =
        await (_db.select(_db.outbox)
              ..where((t) => t.nextAttemptAt.isNotNull())
              ..orderBy([(t) => OrderingTerm.asc(t.nextAttemptAt)])
              ..limit(1))
            .getSingleOrNull();
    return row?.nextAttemptAt;
  }

  /// Whether a mutation for [entityId] still waits in the outbox (a pulled
  /// row must not overwrite what this phone hasn't sent yet).
  Future<bool> hasPending(String entityId) async {
    final row =
        await (_db.select(_db.outbox)
              ..where((t) => t.entityId.equals(entityId))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Removes mutations that must never be sent (e.g. the seal of a capsule
  /// deleted before it left the phone). Not dead-lettered: nothing failed.
  Future<void> drop(List<OutboxRow> rows) async {
    if (rows.isEmpty) return;
    await _db.transaction(() async {
      for (final r in rows) {
        await (_db.delete(_db.outbox)..where((t) => t.seq.equals(r.seq))).go();
      }
    });
  }

  /// The server accepted (or already had) these: drop them and mark the
  /// records synced.
  Future<void> acknowledge(List<OutboxRow> rows) async {
    if (rows.isEmpty) return;
    await _db.transaction(() async {
      for (final r in rows) {
        await (_db.delete(_db.outbox)..where((t) => t.seq.equals(r.seq))).go();
        if (r.entity == Entities.capsule) {
          // The seal is on the server: the capsule is no longer local-only.
          if (r.op == Ops.seal) {
            await (_db.update(
              _db.capsules,
            )..where((t) => t.id.equals(r.entityId))).write(
              const CapsulesCompanion(
                synced: Value(true),
                rejected: Value(null),
              ),
            );
          }
          continue;
        }
        if (r.op != Ops.upsert) continue;
        switch (r.entity) {
          case Entities.checkIn:
            await (_db.update(_db.checkIns)
                  ..where((t) => t.id.equals(r.entityId)))
                .write(const CheckInsCompanion(synced: Value(true)));
          case Entities.habit:
            await (_db.update(_db.habits)
                  ..where((t) => t.id.equals(r.entityId)))
                .write(const HabitsCompanion(synced: Value(true)));
          case Entities.habitLog:
            await (_db.update(_db.habitLogs)
                  ..where((t) => t.id.equals(r.entityId)))
                .write(const HabitLogsCompanion(synced: Value(true)));
        }
      }
    });
  }

  /// Exponential backoff (4 s … 1 h, at least [minWait]).
  ///
  /// With [deadLetter] (a row the server answered for but didn't resolve),
  /// the row moves to the dead-letter table after [maxAttempts]. Request-level
  /// failures (network, 5xx, 401, a refused batch) pass `deadLetter: false`:
  /// they say nothing about the rows, so the rows are never dropped for them.
  Future<void> backoff(
    List<OutboxRow> rows,
    DateTime now, {
    bool deadLetter = true,
    Duration minWait = Duration.zero,
  }) async {
    final rnd = Random();
    await _db.transaction(() async {
      for (final r in rows) {
        final attempts = r.attempts + 1;
        if (deadLetter && attempts >= maxAttempts) {
          await _toDeadLetter(r, 'max_attempts', now);
          continue;
        }
        final base = Duration(seconds: 2 << min(attempts, 11));
        var wait = base > maxBackoff ? maxBackoff : base;
        if (wait < minWait) wait = minWait;
        final jitter = Duration(milliseconds: rnd.nextInt(1000));
        await (_db.update(_db.outbox)..where((t) => t.seq.equals(r.seq))).write(
          OutboxCompanion(
            attempts: Value(attempts),
            nextAttemptAt: Value(now.toUtc().add(wait + jitter)),
          ),
        );
      }
    });
  }

  /// A per-mutation `rejected` result: dead-letter at once. Never used for a
  /// request-level error (that would drop a whole batch).
  Future<void> reject(List<OutboxRow> rows, String reason, DateTime now) async {
    await _db.transaction(() async {
      for (final r in rows) {
        await _toDeadLetter(r, reason, now);
      }
    });
  }

  /// Clears backoff so a reconnect retries immediately.
  Future<void> resetBackoff() => _db
      .update(_db.outbox)
      .write(const OutboxCompanion(nextAttemptAt: Value(null)));

  Future<void> _toDeadLetter(OutboxRow r, String reason, DateTime now) async {
    await _db
        .into(_db.deadLetters)
        .insert(
          DeadLettersCompanion.insert(
            mutationId: r.mutationId,
            entity: r.entity,
            op: r.op,
            entityId: r.entityId,
            payload: r.payload,
            reason: reason,
            failedAt: now.toUtc(),
            deviceTs: Value(r.deviceTs),
            localDay: Value(r.localDay),
            tz: Value(r.tz),
          ),
        );
    await (_db.delete(_db.outbox)..where((t) => t.seq.equals(r.seq))).go();
  }
}
