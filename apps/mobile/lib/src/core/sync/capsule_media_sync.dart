import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../features/capsules/capsule_media_store.dart';
import '../../features/capsules/capsule_payload.dart';
import '../db/database.dart';
import '../net/api_models.dart';
import '../net/aura_api.dart';
import '../security/note_cipher.dart';

/// How uploading a capsule's media went.
enum CapsuleMediaOutcome {
  /// Every slot is on the server (or can never be: given up).
  done,

  /// No data key yet: nothing leaves the phone unsealed.
  waitKey,

  /// A slot failed for now (network, `503 media_unavailable`, 5xx…).
  retry,

  /// `403 account_deletion_pending`: hold like any push.
  held,

  /// `409 capsule_deleted`: the capsule is gone on the server.
  deleted,

  /// The account changed meanwhile (sign-out): stop, write nothing.
  abort,
}

/// Seals the raw file of [slot] (if it still is raw) with the data key and
/// points the media row at the sealed file. Guarded per slot, so the
/// repository (right after sealing) and sync (before uploading) never seal
/// the same file twice. Returns the file name the row holds afterwards.
Future<String?> sealCapsuleMediaSlot(
  AppDatabase db,
  CapsuleMediaStore store,
  String capsuleId,
  String slot, {
  required NoteCipher cipher,
}) => store.guard('$capsuleId/$slot', () async {
  final row = await _mediaRow(db, capsuleId, slot);
  final name = row?.file;
  if (name == null || CapsuleMediaStore.isSealed(name)) return name;
  final sealed = await store.seal(capsuleId, slot, name, cipher: cipher);
  if (sealed == null) return null;
  await (db.update(db.capsuleMedia)..where(
        (t) =>
            t.capsuleId.equals(capsuleId) &
            t.slot.equals(slot) &
            t.file.equals(name),
      ))
      .write(CapsuleMediaCompanion(file: Value(sealed)));
  return sealed;
});

Future<CapsuleMediaRow?> _mediaRow(
  AppDatabase db,
  String capsuleId,
  String slot,
) =>
    (db.select(db.capsuleMedia)
          ..where((t) => t.capsuleId.equals(capsuleId) & t.slot.equals(slot)))
        .getSingleOrNull();

/// Uploads a capsule's photos and voice note (contracts/api/v1-capsules.md
/// §5): seal with the data key if still raw → `POST /v1/media/upload-url`
/// {kind, recordId, index?, bytes = exact ciphertext length} → one `PUT` →
/// remember the returned `path` on the slot.
///
/// `409 capsule_sealed` means the slot is already on the server: done. A
/// slot that can never be uploaded (too large, the file is gone) is marked
/// failed and no longer blocks anything. Never logs ids, paths or content.
class CapsuleMediaSync {
  CapsuleMediaSync({required this._db, required this._store});

  final AppDatabase _db;
  final CapsuleMediaStore _store;

  static const Duration _maxBackoff = Duration(hours: 1);

  /// Uploads every slot of [capsuleId] that isn't on the server yet. With
  /// [dueOnly] only slots whose retry time has come are tried (the
  /// background retry after the seal was pushed).
  Future<CapsuleMediaOutcome> upload(
    String capsuleId, {
    required AuraApi api,
    required NoteCipher? cipher,
    required String userId,
    required bool Function() isCurrent,
    required DateTime now,
    bool dueOnly = false,
  }) async {
    final rows =
        await (_db.select(_db.capsuleMedia)..where(
              (t) =>
                  t.capsuleId.equals(capsuleId) &
                  t.path.isNull() &
                  t.failed.equals(false),
            ))
            .get();
    var outcome = CapsuleMediaOutcome.done;
    for (final m in rows) {
      if (dueOnly &&
          m.nextAttemptAt != null &&
          m.nextAttemptAt!.isAfter(now.toUtc())) {
        outcome = CapsuleMediaOutcome.retry;
        continue;
      }
      final r = await _uploadSlot(
        m,
        api: api,
        cipher: cipher,
        userId: userId,
        isCurrent: isCurrent,
      );
      switch (r) {
        case CapsuleMediaOutcome.done:
          break;
        case CapsuleMediaOutcome.retry:
          await _backoff(m, now);
          outcome = CapsuleMediaOutcome.retry;
        case CapsuleMediaOutcome.waitKey:
          if (outcome == CapsuleMediaOutcome.done) outcome = r;
        case CapsuleMediaOutcome.held ||
            CapsuleMediaOutcome.deleted ||
            CapsuleMediaOutcome.abort:
          return r;
      }
    }
    return outcome;
  }

  /// Capsules already on the server whose media still has to go up (the
  /// seal was pushed while an upload kept failing).
  Future<List<String>> capsulesWithPendingMedia() async {
    final rows =
        await (_db.selectOnly(_db.capsuleMedia, distinct: true)
              ..addColumns([_db.capsuleMedia.capsuleId])
              ..where(
                _db.capsuleMedia.path.isNull() &
                    _db.capsuleMedia.failed.equals(false) &
                    _db.capsuleMedia.file.isNotNull(),
              ))
            .get();
    return [for (final r in rows) r.read(_db.capsuleMedia.capsuleId)!];
  }

  Future<CapsuleMediaOutcome> _uploadSlot(
    CapsuleMediaRow m, {
    required AuraApi api,
    required NoteCipher? cipher,
    required String userId,
    required bool Function() isCurrent,
  }) async {
    final id = m.capsuleId;
    var name = m.file;
    if (name == null) {
      // Nothing on this phone to upload (e.g. pulled from another phone).
      return CapsuleMediaOutcome.done;
    }
    // 1. Sealed with the data key before anything leaves the phone.
    if (!CapsuleMediaStore.isSealed(name)) {
      if (cipher == null) return CapsuleMediaOutcome.waitKey;
      try {
        name = await sealCapsuleMediaSlot(
          _db,
          _store,
          id,
          m.slot,
          cipher: cipher,
        );
      } on CapsuleMediaException {
        return CapsuleMediaOutcome.retry;
      }
      if (!isCurrent()) return CapsuleMediaOutcome.abort;
      if (name == null || !CapsuleMediaStore.isSealed(name)) {
        await _giveUp(m);
        return CapsuleMediaOutcome.done;
      }
    }
    final bytes = await _store.read(id, name);
    if (bytes == null || bytes.isEmpty) {
      await _giveUp(m); // the file is gone from this phone
      return CapsuleMediaOutcome.done;
    }
    final isPhoto = CapsuleSlots.isPhoto(m.slot);
    final limit = isPhoto
        ? maxCapsulePhotoUploadBytes
        : maxCapsuleVoiceUploadBytes;
    if (bytes.length > limit) {
      await _giveUp(m);
      return CapsuleMediaOutcome.done;
    }

    // 2. A fresh signed URL for exactly these bytes…
    final MediaUploadUrl target;
    try {
      target = await api.capsuleMediaUploadUrl(
        capsuleId: id,
        kind: CapsuleSlots.kindOf(m.slot),
        index: CapsuleSlots.photoIndex(m.slot),
        bytes: bytes.length,
      );
    } on ApiException catch (e) {
      if (e.isDeletionPending) return CapsuleMediaOutcome.held;
      if (e.status == 409 && e.code == 'capsule_sealed') {
        // Already uploaded (an earlier attempt's PUT landed).
        await _uploaded(m, CapsuleSlots.objectPath(userId, id, m.slot));
        return CapsuleMediaOutcome.done;
      }
      if (e.status == 409 && e.code == 'capsule_deleted') {
        return CapsuleMediaOutcome.deleted;
      }
      debugPrint('capsule media: upload-url failed (${e.code})');
      if (!e.isRetryable && e.status == 400) {
        await _giveUp(m); // media_too_large / invalid_request
        return CapsuleMediaOutcome.done;
      }
      return CapsuleMediaOutcome.retry;
    }
    if (!isCurrent()) return CapsuleMediaOutcome.abort;
    // …then one PUT. Any failure: a fresh URL next attempt.
    try {
      await api.putMedia(target.uploadUrl, bytes);
    } on ApiException catch (e) {
      debugPrint('capsule media: upload failed (${e.code})');
      return CapsuleMediaOutcome.retry;
    }
    if (!isCurrent()) return CapsuleMediaOutcome.abort;
    await _uploaded(m, target.path);
    return CapsuleMediaOutcome.done;
  }

  Future<void> _uploaded(CapsuleMediaRow m, String path) =>
      (_db.update(_db.capsuleMedia)..where(
            (t) => t.capsuleId.equals(m.capsuleId) & t.slot.equals(m.slot),
          ))
          .write(
            CapsuleMediaCompanion(
              path: Value(path),
              nextAttemptAt: const Value(null),
            ),
          );

  Future<void> _giveUp(CapsuleMediaRow m) =>
      (_db.update(_db.capsuleMedia)..where(
            (t) => t.capsuleId.equals(m.capsuleId) & t.slot.equals(m.slot),
          ))
          .write(const CapsuleMediaCompanion(failed: Value(true)));

  Future<void> _backoff(CapsuleMediaRow m, DateTime now) async {
    final attempts = m.attempts + 1;
    final base = Duration(seconds: 2 << min(attempts, 11));
    final wait = base > _maxBackoff ? _maxBackoff : base;
    final jitter = Duration(milliseconds: Random().nextInt(1000));
    await (_db.update(_db.capsuleMedia)..where(
          (t) => t.capsuleId.equals(m.capsuleId) & t.slot.equals(m.slot),
        ))
        .write(
          CapsuleMediaCompanion(
            attempts: Value(attempts),
            nextAttemptAt: Value(now.toUtc().add(wait + jitter)),
          ),
        );
  }
}
