import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../features/checkin/checkin_repository.dart';
import '../../features/voice/voice_store.dart';
import '../db/database.dart';
import '../net/api_models.dart';
import '../net/aura_api.dart';
import '../security/note_cipher.dart';

/// What the push does with one `needsMedia` outbox row.
enum MediaStepKind {
  /// Uploaded (now or earlier): send [MediaStep.path] as `voicePath`.
  attach,

  /// Nothing to upload any more (removed, replaced, deleted, file gone):
  /// send the row without `voicePath`.
  omit,

  /// The recording can never be uploaded (e.g. too large): stop waiting and
  /// send the row without `voicePath`; the file stays on the phone.
  giveUp,

  /// No data key yet: the row waits (never sends plaintext).
  waitKey,

  /// Upload failed (network, `503 media_unavailable`, 5xx…): back off.
  retry,

  /// `403 account_deletion_pending`: hold like any push.
  held,

  /// The account changed meanwhile (sign-out): stop, write nothing.
  abort,
}

@immutable
class MediaStep {
  const MediaStep(this.kind, [this.path]);

  final MediaStepKind kind;
  final String? path;
}

/// Uploads a check-in's voice note before its upsert is pushed
/// (contracts/api/v1.md "Media: voice notes"):
/// seal with the data key if still raw → `POST /v1/media/upload-url`
/// {kind, recordId, bytes = exact ciphertext length} → `PUT` the ciphertext
/// → remember the returned `path` on the check-in → the push sends it as
/// `voicePath`, verbatim.
///
/// Never logs ids, paths or content; errors carry their type/code only.
class MediaSync {
  MediaSync({required this._db, required this._checkIns, required this._store});

  final AppDatabase _db;
  final CheckInRepository _checkIns;
  final VoiceStore _store;

  Future<MediaStep> prepare(
    OutboxRow r, {
    required AuraApi api,
    required NoteCipher? cipher,
    required bool Function() isCurrent,
  }) async {
    final id = r.entityId;
    var row = await _row(id);
    if (row == null || row.deletedAt != null) {
      return const MediaStep(MediaStepKind.omit);
    }
    // Uploaded already (by an earlier row for this check-in).
    if (row.voicePath != null) {
      return MediaStep(MediaStepKind.attach, row.voicePath);
    }
    if (row.voiceFile == null) return const MediaStep(MediaStepKind.omit);

    // 1. Sealed with the data key before anything leaves the phone.
    if (!VoiceStore.isSealed(row.voiceFile!)) {
      if (cipher == null) return const MediaStep(MediaStepKind.waitKey);
      try {
        await _checkIns.sealVoice(id, cipher: cipher);
      } on VoiceStoreException {
        return const MediaStep(MediaStepKind.retry);
      }
      if (!isCurrent()) return const MediaStep(MediaStepKind.abort);
      row = await _row(id);
      if (row == null || row.deletedAt != null || row.voiceFile == null) {
        return const MediaStep(MediaStepKind.omit);
      }
      if (!VoiceStore.isSealed(row.voiceFile!)) {
        return const MediaStep(MediaStepKind.retry);
      }
    }
    final file = row.voiceFile!;
    final bytes = await _store.read(file);
    if (bytes == null || bytes.isEmpty) {
      // The recording is gone from this phone: forget it.
      await (_db.update(
        _db.checkIns,
      )..where((t) => t.id.equals(id) & t.voiceFile.equals(file))).write(
        const CheckInsCompanion(voiceFile: Value(null), voiceMs: Value(null)),
      );
      return const MediaStep(MediaStepKind.omit);
    }
    if (bytes.length > maxVoiceUploadBytes) {
      return const MediaStep(MediaStepKind.giveUp);
    }

    // 2. A fresh signed URL for exactly these bytes…
    final MediaUploadUrl target;
    try {
      target = await api.mediaUploadUrl(recordId: id, bytes: bytes.length);
    } on ApiException catch (e) {
      if (e.isDeletionPending) return const MediaStep(MediaStepKind.held);
      debugPrint('media: upload-url failed (${e.code})');
      // 400 media_too_large / invalid_request: retrying can't help.
      final permanent = !e.isRetryable && e.status == 400;
      return MediaStep(permanent ? MediaStepKind.giveUp : MediaStepKind.retry);
    }
    if (!isCurrent()) return const MediaStep(MediaStepKind.abort);
    // …then one PUT. Any failure: a fresh URL next attempt.
    try {
      await api.putMedia(target.uploadUrl, bytes);
    } on ApiException catch (e) {
      debugPrint('media: upload failed (${e.code})');
      return const MediaStep(MediaStepKind.retry);
    }
    if (!isCurrent()) return const MediaStep(MediaStepKind.abort);
    final path = target.path;

    // 3. Only if the check-in still holds this recording (an edit may have
    //    replaced or removed it during the upload; its own row handles that).
    final kept =
        await (_db.update(_db.checkIns)
              ..where((t) => t.id.equals(id) & t.voiceFile.equals(file)))
            .write(CheckInsCompanion(voicePath: Value(path)));
    return kept > 0
        ? MediaStep(MediaStepKind.attach, path)
        : const MediaStep(MediaStepKind.omit);
  }

  Future<CheckInRow?> _row(String id) => (_db.select(
    _db.checkIns,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
}
