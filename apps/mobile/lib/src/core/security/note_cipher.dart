import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../net/aura_api.dart';
import 'secure_store.dart';

/// AES-256-GCM for notes with the per-user data key (DS-1 envelope; the
/// server only ever stores the ciphertext).
///
/// Wire format (base64): `0x01 | nonce(12) | ciphertext | tag(16)`.
/// The record id is bound as associated data, so a ciphertext cannot be moved
/// onto another check-in.
class NoteCipher {
  NoteCipher(this._key);

  static const int _version = 1;
  static final AesGcm _algo = AesGcm.with256bits();

  final SecretKey _key;

  Future<String> encrypt(String plaintext, {required String recordId}) async {
    final box = await _algo.encrypt(
      utf8.encode(plaintext),
      secretKey: _key,
      nonce: _algo.newNonce(),
      aad: utf8.encode(recordId),
    );
    final out = BytesBuilder(copy: false)
      ..addByte(_version)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return base64.encode(out.toBytes());
  }

  Future<String> decrypt(String ciphertext, {required String recordId}) async {
    final bytes = base64.decode(ciphertext);
    if (bytes.isEmpty || bytes[0] != _version || bytes.length < 1 + 12 + 16) {
      throw const FormatException('Unknown note ciphertext format');
    }
    final nonce = bytes.sublist(1, 13);
    final mac = Mac(bytes.sublist(bytes.length - 16));
    final ct = bytes.sublist(13, bytes.length - 16);
    final clear = await _algo.decrypt(
      SecretBox(ct, nonce: nonce, mac: mac),
      secretKey: _key,
      aad: utf8.encode(recordId),
    );
    return utf8.decode(clear);
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
      keyB64 = (jsonDecode(stored) as Map<String, dynamic>)['dataKey'] as String?;
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
