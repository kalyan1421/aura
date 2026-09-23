import 'package:flutter/foundation.dart';

import '../../core/net/aura_api.dart';
import '../../core/security/note_cipher.dart';
import 'voice_store.dart';

/// A playable file. [isTemp] files are decrypted copies that the player
/// deletes when it is done with them.
@immutable
class VoiceSource {
  const VoiceSource(this.path, {this.isTemp = false});

  final String path;
  final bool isTemp;
}

/// A voice note that can't be played right now.
class VoiceUnavailable implements Exception {
  const VoiceUnavailable({this.offline = false});

  /// Only on the server and there is no connection: "plays when you're back
  /// online".
  final bool offline;

  @override
  String toString() => 'VoiceUnavailable(offline: $offline)';
}

/// Finds a check-in's voice note for playback: this phone's copy (raw →
/// played as is; sealed → decrypted into a temp file), or else the server's
/// object, fetched lazily (`POST /v1/media/download-url` → `GET` → decrypt →
/// temp file).
class VoiceLoader {
  VoiceLoader({
    required this._store,
    required this._api,
    required this._cipher,
    required this._online,
  });

  final VoiceStore _store;
  final AuraApi? _api;

  /// The signed-in person's data key; with `fetch` it may ask the API.
  final Future<NoteCipher?> Function({bool fetch}) _cipher;
  final bool Function() _online;

  Future<VoiceSource> load({
    required String checkInId,
    String? file,
    String? path,
  }) async {
    if (file != null) {
      if (!VoiceStore.isSealed(file)) {
        final raw = await _store.file(file);
        if (raw != null) return VoiceSource(raw.path);
      } else {
        final sealed = await _store.read(file);
        if (sealed != null) {
          return _open(sealed, checkInId, fetchKey: false);
        }
      }
    }
    final api = _api;
    if (path == null || api == null) throw const VoiceUnavailable();
    if (!_online()) throw const VoiceUnavailable(offline: true);
    final Uint8List sealed;
    try {
      final url = await api.mediaDownloadUrl(path);
      sealed = await api.getMedia(url.downloadUrl);
    } on ApiException catch (e) {
      debugPrint('voice: download ${e.code}');
      throw VoiceUnavailable(offline: e.isNetwork);
    }
    return _open(sealed, checkInId, fetchKey: true);
  }

  Future<VoiceSource> _open(
    Uint8List sealed,
    String checkInId, {
    required bool fetchKey,
  }) async {
    final cipher = await _cipher(fetch: fetchKey);
    if (cipher == null) throw const VoiceUnavailable();
    final Uint8List clear;
    try {
      clear = await cipher.decryptBytes(sealed, recordId: checkInId);
    } on Object catch (e) {
      debugPrint('voice: decrypt ${e.runtimeType}');
      throw const VoiceUnavailable();
    }
    final tmp = await _store.writeTemp(clear);
    return VoiceSource(tmp.path, isTemp: true);
  }
}
