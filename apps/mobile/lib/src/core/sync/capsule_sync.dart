import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../features/capsules/capsule_media_store.dart';
import '../../features/capsules/capsule_repository.dart';
import '../db/database.dart';
import '../db/kv_store.dart';
import '../net/aura_api.dart';
import '../security/note_cipher.dart';
import '../time/clock.dart';
import 'capsule_media_sync.dart';
import 'outbox_repository.dart';

/// What the push does with one `capsule` outbox row.
enum CapsulePushStep {
  /// Ready: send it (a `seal` now carries its ciphertext).
  send,

  /// No data key yet: the row waits (content never leaves unsealed).
  waitKey,

  /// Must never be sent (the capsule was deleted before its seal left the
  /// phone): drop it from the outbox.
  obsolete,

  /// A media upload failed for now: back the row off (after the outbox's
  /// max attempts the seal goes without waiting; uploads keep retrying).
  retryMedia,

  /// `403 account_deletion_pending`.
  held,

  /// The account changed meanwhile: stop.
  abort,
}

/// Seal rejections that are final for this capsule: it stays on this phone
/// (`CapsuleRow.rejected`) until the person changes it, e.g. makes a mood
/// capsule over the Free limit a date capsule.
const Set<String> finalSealRejections = {
  'trigger_capsule_limit',
  'date_capsule_limit',
  'invalid_unlock_date',
  'invalid_payload',
  'unknown_mood',
  'invalid_tz',
  'id_conflict',
};

/// One row of `public.capsules` (contracts/api/v1-capsules.md §3).
@immutable
class ServerCapsule {
  const ServerCapsule({
    required this.id,
    required this.unlockType,
    required this.sealedAt,
    required this.updatedAt,
    this.unlockLocalDate,
    this.triggerMoodId,
    this.triggerQuadrant,
    this.payloadCt,
    this.armedAt,
    this.cycle = 0,
    this.firedAt,
    this.cooldownUntil,
    this.openedAt,
    this.openedDeviceTs,
    this.deletedAt,
  });

  factory ServerCapsule.fromJson(Map<String, dynamic> j) {
    DateTime? ts(String k) {
      final v = j[k];
      return v is String ? DateTime.parse(v).toUtc() : null;
    }

    return ServerCapsule(
      id: (j['id'] as String).toLowerCase(),
      unlockType: j['unlock_type'] as String,
      unlockLocalDate: j['unlock_local_date'] as String?,
      triggerMoodId: j['trigger_mood_id'] as String?,
      triggerQuadrant: j['trigger_quadrant'] as String?,
      payloadCt: j['payload_ct'] as String?,
      sealedAt: ts('sealed_at')!,
      armedAt: ts('armed_at'),
      cycle: (j['cycle'] as num?)?.toInt() ?? 0,
      firedAt: ts('fired_at'),
      cooldownUntil: ts('cooldown_until'),
      openedAt: ts('opened_at'),
      openedDeviceTs: ts('opened_device_ts'),
      deletedAt: ts('deleted_at'),
      updatedAt: ts('updated_at')!,
    );
  }

  final String id;
  final String unlockType;
  final String? unlockLocalDate;
  final String? triggerMoodId;
  final String? triggerQuadrant;
  final String? payloadCt;
  final DateTime sealedAt;
  final DateTime? armedAt;
  final int cycle;
  final DateTime? firedAt;
  final DateTime? cooldownUntil;
  final DateTime? openedAt;
  final DateTime? openedDeviceTs;
  final DateTime? deletedAt;
  final DateTime updatedAt;
}

DateTime? _latest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

DateTime? _earliest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

/// Merges a pulled server row into this phone's copy (PRD 16-offline):
///
/// * **Delete wins**: a server tombstone erases the capsule here too
///   (content, target, media); a local tombstone stays deleted.
/// * With nothing of this capsule left in the outbox, the server row is the
///   truth and is adopted as is (contracts §3: "adopt the server row once
///   they are drained").
/// * While mutations are queued, only what can grow is taken: content and
///   the unlock target never change once sealed; opened is one-way; a fire
///   happens at most once per cycle and the **earliest** wins; the cooldown
///   is the latest; a newer cycle (another phone re-armed) replaces this
///   phone's cycle state.
///
/// Returns the full row for an insert ([local] null) or the fields to
/// update. This phone's own bookkeeping (`sealTz`, `notifyAt`) is kept.
CapsulesCompanion mergeServerCapsule(
  CapsuleRow? local,
  ServerCapsule s, {
  required bool hasPending,
}) {
  final cooldown = _latest(local?.cooldownUntil, s.cooldownUntil);
  if (s.deletedAt != null) {
    return CapsulesCompanion(
      id: Value(s.id),
      unlockType: Value(s.unlockType),
      unlockLocalDate: const Value(null),
      triggerMoodId: const Value(null),
      triggerQuadrant: const Value(null),
      payloadCt: const Value(null),
      payloadClear: const Value(null),
      sealedAt: Value(s.sealedAt),
      armedAt: Value(s.armedAt),
      cycle: Value(s.cycle),
      firedAt: Value(s.firedAt),
      cooldownUntil: Value(cooldown),
      openedAt: Value(s.openedAt),
      openedDeviceTs: Value(s.openedDeviceTs),
      deletedAt: Value(local?.deletedAt ?? s.deletedAt),
      serverUpdatedAt: Value(s.updatedAt),
      synced: const Value(true),
      rejected: const Value(null),
      notifyAt: const Value(null),
    );
  }
  if (local != null && local.deletedAt != null) {
    // Deleted here; its delete is on its way (or already applied).
    return CapsulesCompanion(
      cooldownUntil: Value(cooldown),
      serverUpdatedAt: Value(s.updatedAt),
      synced: const Value(true),
    );
  }
  if (local == null || !hasPending) {
    return CapsulesCompanion(
      id: Value(s.id),
      unlockType: Value(s.unlockType),
      unlockLocalDate: Value(s.unlockLocalDate),
      triggerMoodId: Value(s.triggerMoodId),
      triggerQuadrant: Value(s.triggerQuadrant),
      // Content never changes after sealing: the same ciphertext.
      payloadCt: Value(s.payloadCt ?? local?.payloadCt),
      payloadClear: Value(s.payloadCt != null ? null : local?.payloadClear),
      sealedAt: Value(s.sealedAt),
      armedAt: Value(s.armedAt),
      cycle: Value(s.cycle),
      firedAt: Value(s.firedAt),
      cooldownUntil: Value(s.cooldownUntil),
      openedAt: Value(s.openedAt),
      openedDeviceTs: Value(s.openedDeviceTs),
      deletedAt: const Value(null),
      serverUpdatedAt: Value(s.updatedAt),
      synced: const Value(true),
      rejected: const Value(null),
    );
  }
  // Mutations of this phone are still queued.
  DateTime? armedAt = local.armedAt;
  var cycle = local.cycle;
  DateTime? firedAt = local.firedAt;
  DateTime? openedAt = local.openedAt;
  DateTime? openedDeviceTs = local.openedDeviceTs;
  if (s.cycle > local.cycle) {
    // Another phone re-armed it: its cycle wins (ours will be refused as
    // stale and re-pulled).
    cycle = s.cycle;
    armedAt = s.armedAt;
    firedAt = s.firedAt;
    openedAt = s.openedAt;
    openedDeviceTs = s.openedDeviceTs;
  } else if (s.cycle == local.cycle) {
    armedAt = s.armedAt ?? local.armedAt;
    firedAt = _earliest(local.firedAt, s.firedAt);
    // One-way; the server's time is the real unlock time.
    openedAt = s.openedAt ?? local.openedAt;
    openedDeviceTs = s.openedDeviceTs ?? local.openedDeviceTs;
  }
  return CapsulesCompanion(
    payloadCt: Value(local.payloadCt ?? s.payloadCt),
    armedAt: Value(armedAt),
    cycle: Value(cycle),
    firedAt: Value(firedAt),
    cooldownUntil: Value(cooldown),
    openedAt: Value(openedAt),
    openedDeviceTs: Value(openedDeviceTs),
    serverUpdatedAt: Value(s.updatedAt),
    synced: const Value(true),
  );
}

/// Where pulled capsule rows come from (Supabase select-own; tests fake it).
abstract interface class CapsuleRowSource {
  /// Rows with `updated_at ≥ since` (all when [since] is null), ordered by
  /// `updated_at, id`, rows [from]…[to] inclusive.
  Future<List<Map<String, dynamic>>> changedSince(
    DateTime? since, {
    required int from,
    required int to,
  });

  /// These rows (after a rejection: take the server's truth).
  Future<List<Map<String, dynamic>>> byIds(List<String> ids);
}

/// `GET /rest/v1/capsules` with the user's JWT (RLS select-own). Never
/// writes: every capsule write is the sync push.
class SupabaseCapsuleRowSource implements CapsuleRowSource {
  SupabaseCapsuleRowSource(this._client);

  final sb.SupabaseClient Function() _client;

  static const String _columns =
      'id,unlock_type,unlock_local_date,trigger_mood_id,trigger_quadrant,'
      'payload_ct,sealed_at,armed_at,cycle,fired_at,cooldown_until,'
      'opened_at,opened_device_ts,deleted_at,updated_at';

  @override
  Future<List<Map<String, dynamic>>> changedSince(
    DateTime? since, {
    required int from,
    required int to,
  }) async {
    var q = _client().from('capsules').select(_columns);
    if (since != null) q = q.gte('updated_at', since.toUtc().toIso8601String());
    return q
        .order('updated_at', ascending: true)
        .order('id', ascending: true)
        .range(from, to);
  }

  @override
  Future<List<Map<String, dynamic>>> byIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return _client().from('capsules').select(_columns).inFilter('id', ids);
  }
}

/// F4 capsules in the sync loop ([SyncService]): fills a `seal` with its
/// ciphertext and uploads its media first, reacts to rejections, keeps
/// retrying media for capsules already on the server, and pulls
/// `public.capsules` by its `updated_at` cursor (5-minute overlap).
///
/// Never logs ids, titles, dates, targets or content.
class CapsuleSync {
  CapsuleSync({
    required this._db,
    required this._outbox,
    required this._kv,
    required this._capsules,
    required this._media,
    required this._store,
    this._rows,
    this._clock = const Clock(),
    this.pullEvery = const Duration(minutes: 5),
  });

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final KvStore _kv;
  final CapsuleRepository _capsules;
  final CapsuleMediaSync _media;
  final CapsuleMediaStore _store;
  final CapsuleRowSource? _rows;
  final Clock _clock;

  /// How often a pull runs without a reason (start, resume and rejections
  /// always pull).
  final Duration pullEvery;

  /// A transaction's `updated_at` is its start time: re-read a little.
  static const Duration pullOverlap = Duration(minutes: 5);
  static const int _page = 500;
  static const String cursorKey = 'capsules.pull_cursor';

  DateTime? _lastPull;
  String? _lastPullUser;
  bool _pullRequested = true;
  final Set<String> _refetch = {};

  /// The next drain pulls, whatever [pullEvery] says (app resumed).
  void requestPull() => _pullRequested = true;

  bool get pullRequested => _pullRequested;

  // ---- push ------------------------------------------------------------------------

  /// Prepares one capsule mutation for the push; a `seal` gets its
  /// `payloadCt` here (sealed with [cipher] if it still waited for the key)
  /// and its media uploaded first.
  Future<CapsulePushStep> prepare(
    OutboxRow r,
    Map<String, dynamic> payload, {
    required AuraApi api,
    required NoteCipher? cipher,
    required String userId,
    required bool Function() isCurrent,
  }) async {
    if (r.op != Ops.seal) return CapsulePushStep.send;
    final row = await _capsules.row(r.entityId);
    if (row == null || row.deletedAt != null) return CapsulePushStep.obsolete;
    var ct = row.payloadCt;
    if (ct == null) {
      if (cipher == null) return CapsulePushStep.waitKey;
      ct = await _capsules.sealPayload(r.entityId, cipher);
      if (ct == null) return CapsulePushStep.obsolete;
    }
    payload['payloadCt'] = ct;
    if (!r.needsMedia) return CapsulePushStep.send;
    final outcome = await _media.upload(
      r.entityId,
      api: api,
      cipher: cipher,
      userId: userId,
      isCurrent: isCurrent,
      now: _clock.now(),
    );
    return switch (outcome) {
      CapsuleMediaOutcome.done => CapsulePushStep.send,
      CapsuleMediaOutcome.waitKey => CapsulePushStep.waitKey,
      CapsuleMediaOutcome.retry => CapsulePushStep.retryMedia,
      CapsuleMediaOutcome.held => CapsulePushStep.held,
      CapsuleMediaOutcome.abort => CapsulePushStep.abort,
      // Deleted on the server (another phone): the seal can only be
      // refused; take the server's tombstone instead.
      CapsuleMediaOutcome.deleted => _obsoleteAndRefetch(r.entityId),
    };
  }

  CapsulePushStep _obsoleteAndRefetch(String id) {
    _refetch.add(id);
    _pullRequested = true;
    return CapsulePushStep.obsolete;
  }

  /// The server refused a capsule mutation for good (it is already in the
  /// dead-letter table). A refused seal keeps the capsule on this phone
  /// ([finalSealRejections], e.g. `trigger_capsule_limit` → "make it a date
  /// capsule"); anything else (`stale_cycle`, `capsule_deleted`, …) re-pulls
  /// the server's row and adopts it.
  Future<void> onRejected(OutboxRow r, String reason) async {
    if (r.op == Ops.seal && finalSealRejections.contains(reason)) {
      await (_db.update(_db.capsules)
            ..where((t) => t.id.equals(r.entityId) & t.deletedAt.isNull()))
          .write(CapsulesCompanion(rejected: Value(reason)));
      return;
    }
    _refetch.add(r.entityId);
    _pullRequested = true;
  }

  // ---- after the push ----------------------------------------------------------------

  /// Media of capsules already on the server that still has to go up, then
  /// a pull when one is due. Errors are the caller's to log.
  Future<void> afterPush({
    required AuraApi api,
    required NoteCipher? cipher,
    required String userId,
    required bool Function() isCurrent,
  }) async {
    await uploadPendingMedia(
      api: api,
      cipher: cipher,
      userId: userId,
      isCurrent: isCurrent,
    );
    if (!isCurrent()) return;
    await pull(userId, isCurrent);
  }

  /// Retries uploads the seal went without ("push the seal anyway and keep
  /// retrying the upload afterwards", contracts §5).
  Future<void> uploadPendingMedia({
    required AuraApi api,
    required NoteCipher? cipher,
    required String userId,
    required bool Function() isCurrent,
  }) async {
    for (final id in await _media.capsulesWithPendingMedia()) {
      if (!isCurrent()) return;
      final row = await _capsules.row(id);
      // A seal still in the outbox uploads its own media first.
      if (row == null || row.deletedAt != null || !row.synced) continue;
      final outcome = await _media.upload(
        id,
        api: api,
        cipher: cipher,
        userId: userId,
        isCurrent: isCurrent,
        now: _clock.now(),
        dueOnly: true,
      );
      switch (outcome) {
        case CapsuleMediaOutcome.held || CapsuleMediaOutcome.abort:
          return;
        case CapsuleMediaOutcome.deleted:
          _refetch.add(id);
          _pullRequested = true;
        case CapsuleMediaOutcome.done ||
            CapsuleMediaOutcome.retry ||
            CapsuleMediaOutcome.waitKey:
          break;
      }
    }
  }

  // ---- pull ----------------------------------------------------------------------------

  /// Pulls own capsule rows changed since the cursor (minus [pullOverlap])
  /// plus any row a rejection asked for, and merges them
  /// ([mergeServerCapsule]). Runs when requested, on the first drain, and
  /// then at most every [pullEvery]. Writes nothing once [isCurrent] is
  /// false (the account signed out meanwhile).
  Future<void> pull(
    String userId,
    bool Function() isCurrent, {
    bool force = false,
  }) async {
    final source = _rows;
    if (source == null) return;
    final now = _clock.now();
    final last = _lastPull;
    // Another account signed in: its first pull never waits.
    if (!force &&
        !_pullRequested &&
        last != null &&
        _lastPullUser == userId &&
        now.difference(last) < pullEvery) {
      return;
    }
    final refetch = _refetch.toList();
    _refetch.clear();
    _pullRequested = false;
    try {
      final cursor = await _cursor(userId);
      final since = cursor?.subtract(pullOverlap);
      final raw = <Map<String, dynamic>>[];
      for (var from = 0; ; from += _page) {
        final got = await source.changedSince(
          since,
          from: from,
          to: from + _page - 1,
        );
        raw.addAll(got);
        if (got.length < _page) break;
      }
      if (refetch.isNotEmpty) raw.addAll(await source.byIds(refetch));
      if (!isCurrent()) return;
      await apply(raw, userId: userId, isCurrent: isCurrent);
      _lastPull = now;
      _lastPullUser = userId;
    } catch (_) {
      // Try again next drain.
      _refetch.addAll(refetch);
      _pullRequested = true;
      rethrow;
    }
  }

  /// Merges pulled rows into the local table and advances the cursor.
  @visibleForTesting
  Future<void> apply(
    List<Map<String, dynamic>> raw, {
    required String userId,
    required bool Function() isCurrent,
  }) async {
    final byId = <String, ServerCapsule>{};
    for (final j in raw) {
      final ServerCapsule s;
      try {
        s = ServerCapsule.fromJson(j);
      } on Object {
        continue; // a row this version can't read
      }
      final seen = byId[s.id];
      if (seen == null || s.updatedAt.isAfter(seen.updatedAt)) byId[s.id] = s;
    }
    if (byId.isEmpty) return;
    final erased = <String>[];
    DateTime? newest;
    await _db.transaction(() async {
      if (!isCurrent()) return;
      for (final s in byId.values) {
        newest = _latest(newest, s.updatedAt);
        final local = await _capsules.row(s.id);
        final pending = await _outbox.hasPending(s.id);
        final merged = mergeServerCapsule(local, s, hasPending: pending);
        if (local == null) {
          await _db.into(_db.capsules).insert(merged);
        } else {
          await (_db.update(
            _db.capsules,
          )..where((t) => t.id.equals(s.id))).write(merged);
        }
        if (s.deletedAt != null && local?.deletedAt == null) {
          erased.add(s.id);
          await (_db.delete(
            _db.capsuleMedia,
          )..where((t) => t.capsuleId.equals(s.id))).go();
        }
      }
    });
    if (!isCurrent()) return;
    for (final id in erased) {
      await _store.deleteCapsule(id);
    }
    final cursor = await _cursor(userId);
    final advanced = _latest(cursor, newest);
    if (advanced != null) {
      await _kv.setJson(cursorKey, {
        'user': userId,
        'at': advanced.toUtc().toIso8601String(),
      });
    }
  }

  Future<DateTime?> _cursor(String userId) async {
    try {
      final j = await _kv.getJson(cursorKey);
      if (j == null || j['user'] != userId) return null;
      return DateTime.tryParse(j['at'] as String? ?? '')?.toUtc();
    } on FormatException {
      return null;
    }
  }

  /// For tests and diagnostics: the stored cursor (never logged).
  @visibleForTesting
  Future<String?> cursorJson() async {
    final j = await _kv.getJson(cursorKey);
    return j == null ? null : jsonEncode(j);
  }
}
