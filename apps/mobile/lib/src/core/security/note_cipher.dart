import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../net/aura_api.dart';
import 'secure_store.dart';

/// AES-256-GCM with the per-user data key (DS-1 envelope; the server only
/// ever stores the ciphertext): notes as text, voice notes as bytes.
///
/// Envelope: `0x01 | nonce(12) | ciphertext | tag(16)` — base64 for notes,
/// raw bytes for media files. The record id is bound as associated data, so
/// a ciphertext cannot be moved onto another check-in.
class NoteCipher {
  NoteCipher(this._key);

  static const int _version = 1;
  static const int _nonceLength = 12;
  static const int _tagLength = 16;

  /// Bytes the envelope adds to the plaintext (version + nonce + tag).
  static const int overhead = 1 + _nonceLength + _tagLength;

  static final AesGcm _algo = AesGcm.with256bits();

  final SecretKey _key;

  Future<String> encrypt(String plaintext, {required String recordId}) async =>
      base64.encode(
        await encryptBytes(utf8.encode(plaintext), recordId: recordId),
      );

  Future<String> decrypt(String ciphertext, {required String recordId}) async =>
      utf8.decode(
        await decryptBytes(base64.decode(ciphertext), recordId: recordId),
      );

  /// Seals [clear] (e.g. a voice recording) for the record [recordId].
  Future<Uint8List> encryptBytes(
    List<int> clear, {
    required String recordId,
  }) async {
    final box = await _algo.encrypt(
      clear,
      secretKey: _key,
      nonce: _algo.newNonce(),
      aad: utf8.encode(recordId),
    );
    final out = BytesBuilder(copy: false)
      ..addByte(_version)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  /// Opens an envelope made by [encryptBytes] for the same [recordId]. Throws
  /// on another key, another record id, a tampered or unknown envelope.
  Future<Uint8List> decryptBytes(
    List<int> sealed, {
    required String recordId,
  }) async {
    if (sealed.length < overhead || sealed[0] != _version) {
      throw const FormatException('Unknown ciphertext format');
    }
    final bytes = sealed is Uint8List ? sealed : Uint8List.fromList(sealed);
    final nonce = bytes.sublist(1, 1 + _nonceLength);
    final mac = Mac(bytes.sublist(bytes.length - _tagLength));
    final ct = bytes.sublist(1 + _nonceLength, bytes.length - _tagLength);
    final clear = await _algo.decrypt(
      SecretBox(ct, nonce: nonce, mac: mac),
      secretKey: _key,
      aad: utf8.encode(recordId),
    );
    return clear is Uint8List ? clear : Uint8List.fromList(clear);
  }
}

/// Loads the per-user data key from Keychain/Keystore, fetching it once from
/// `GET /v1/keys/data-key` after sign-in.
class DataKeyRepository {
  DataKeyRepository(this._secure);

  final SecureStore _secure;
  final Map<String, NoteCipher> _cache = {};

  /// The cipher for [userId]; fetches the key with [api] when not stored yet.
  /// Returns `null` if it is unavailable (e.g. offline before first fetch).
  Future<NoteCipher?> cipherFor(String userId, {AuraApi? api}) async {
    final cached = _cache[userId];
    if (cached != null) return cached;
    final stored = await _secure.read(SecureKeys.dataKey(userId));
    String? keyB64;
    if (stored != null) {
      keyB64 =
          (jsonDecode(stored) as Map<String, dynamic>)['dataKey'] as String?;
    } else if (api != null) {
      try {
        final res = await api.dataKey();
        await _secure.write(
          SecureKeys.dataKey(userId),
          jsonEncode({'keyId': res.keyId, 'dataKey': res.dataKey}),
        );
        keyB64 = res.dataKey;
      } on ApiException {
        return null;
      }
    }
    if (keyB64 == null) return null;
    final bytes = base64.decode(keyB64);
    if (bytes.length != 32) return null;
    return _cache[userId] = NoteCipher(SecretKey(bytes));
  }

  void forget() => _cache.clear();
}
