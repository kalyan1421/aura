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
}

abstract final class Ops {
  static const String upsert = 'upsert';
  static const String delete = 'delete';
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

  /// The server accepted (or already had) these: drop them and mark the
  /// records synced.
  Future<void> acknowledge(List<OutboxRow> rows) async {
    if (rows.isEmpty) return;
    await _db.transaction(() async {
      for (final r in rows) {
        await (_db.delete(
          _db.outbox,
        )..where((t) => t.seq.equals(r.seq))).go();
        if (r.op != Ops.upsert) continue;
        switch (r.entity) {
          case Entities.checkIn:
            await (_db.update(_db.checkIns)
                  ..where((t) => t.id.equals(r.entityId)))
                .write(const CheckInsCompanion(synced: Value(true)));
          case Entities.habit:
            await (_db.update(_db.habits)..where((t) => t.id.equals(r.entityId)))
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
