import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/db/database.dart';
import '../../core/net/aura_api.dart';
import '../../core/security/note_cipher.dart';
import '../voice/voice_loader.dart';
import 'capsule_media_store.dart';
import 'capsule_payload.dart';

/// A capsule photo or voice note that can't be shown right now.
class CapsuleMediaUnavailable implements Exception {
  const CapsuleMediaUnavailable({this.offline = false});

  /// Only on the server and there is no connection: "arrives when you're
  /// back online".
  final bool offline;

  @override
  String toString() => 'CapsuleMediaUnavailable(offline: $offline)';
}

/// Loads an opened capsule's media lazily (PRD 16-offline "Capsule media
/// downloads when opened"): this phone's copy (raw → as is; sealed →
/// decrypted), else the server's object (`POST /v1/media/download-url` →
/// `GET` → the ciphertext is cached here for next time → decrypted).
///
/// Photos are decrypted into memory only; a voice note into a temp file for
/// the player (deleted when playback is disposed).
class CapsuleMediaLoader {
  CapsuleMediaLoader({
    required this._db,
    required this._store,
    required this._api,
    required this._cipher,
    required this._online,
    required this._userId,
  });

  final AppDatabase _db;
  final CapsuleMediaStore _store;
  final AuraApi? _api;

  /// The signed-in person's data key; with `fetch` it may ask the API.
  final Future<NoteCipher?> Function({bool fetch}) _cipher;
  final bool Function() _online;
  final String? Function() _userId;

  /// A photo's JPEG bytes (decrypted in memory).
  Future<Uint8List> photo(String capsuleId, String slot) =>
      _clear(capsuleId, slot);

  /// The voice note as a playable file ([VoiceSource.isTemp] when it is a
  /// decrypted copy). Throws [VoiceUnavailable] so the voice player can say
  /// "plays when you're back online".
  Future<VoiceSource> voice(String capsuleId) async {
    final row = await _row(capsuleId, CapsuleSlots.voice);
    final name = row?.file;
    if (name != null && !CapsuleMediaStore.isSealed(name)) {
      final raw = await _store.read(capsuleId, name);
      if (raw != null) {
        final f = await _store.writeTemp(raw, extension: '.m4a');
        return VoiceSource(f.path, isTemp: true);
      }
    }
    try {
      final clear = await _clear(capsuleId, CapsuleSlots.voice);
      final f = await _store.writeTemp(clear, extension: '.m4a');
      return VoiceSource(f.path, isTemp: true);
    } on CapsuleMediaUnavailable catch (e) {
      throw VoiceUnavailable(offline: e.offline);
    }
  }

  Future<Uint8List> _clear(String capsuleId, String slot) async {
    final row = await _row(capsuleId, slot);
    final name = row?.file;
    if (name != null) {
      final bytes = await _store.read(capsuleId, name);
      if (bytes != null) {
        if (!CapsuleMediaStore.isSealed(name)) return bytes;
        return _open(bytes, capsuleId, slot, fetchKey: false);
      }
    }
    final api = _api;
    final user = _userId();
    if (api == null || user == null) throw const CapsuleMediaUnavailable();
    if (!_online()) throw const CapsuleMediaUnavailable(offline: true);
    final path = row?.path ?? CapsuleSlots.objectPath(user, capsuleId, slot);
    final Uint8List sealed;
    try {
      final url = await api.mediaDownloadUrl(path);
      sealed = await api.getMedia(url.downloadUrl);
    } on ApiException catch (e) {
      debugPrint('capsule media: download ${e.code}');
      throw CapsuleMediaUnavailable(offline: e.isNetwork);
    }
    final clear = await _open(sealed, capsuleId, slot, fetchKey: true);
    // Keep the ciphertext: it opens offline next time.
    final cached = await _store.cacheSealed(capsuleId, slot, sealed);
    if (cached != null) {
      await _db
          .into(_db.capsuleMedia)
          .insertOnConflictUpdate(
            CapsuleMediaCompanion.insert(
              capsuleId: capsuleId,
              slot: slot,
              file: Value(cached),
              path: Value(path),
            ),
          );
    }
    return clear;
  }

  Future<Uint8List> _open(
    Uint8List sealed,
    String capsuleId,
    String slot, {
    required bool fetchKey,
  }) async {
    final cipher = await _cipher(fetch: fetchKey);
    if (cipher == null) throw const CapsuleMediaUnavailable();
    try {
      return await cipher.decryptBytes(
        sealed,
        recordId: CapsuleSlots.aadOf(capsuleId, slot),
      );
    } on Object catch (e) {
      debugPrint('capsule media: decrypt ${e.runtimeType}');
      throw const CapsuleMediaUnavailable();
    }
  }

  Future<CapsuleMediaRow?> _row(String capsuleId, String slot) =>
      (_db.select(_db.capsuleMedia)
            ..where((t) => t.capsuleId.equals(capsuleId) & t.slot.equals(slot)))
          .getSingleOrNull();
}
