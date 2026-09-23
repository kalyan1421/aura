import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';

/// Signed bundles from NestJS (PRD 19 REQ-ADM-12 "lexicon versions are signed
/// and reversible"; contracts/api/v1.md "Crisis lexicon versions";
/// server/aura-api/src/remote-config/signing.ts is the other half).
///
/// ```json
/// { "format": "aura.signed-bundle.v1", "keyId": "<16 hex>",
///   "payload": "<base64>", "signature": "<base64>" }
/// ```
/// `payload` is the exact bytes of a JSON object `{kind, seq, issuedAt,
/// version, content, vectors}`; `signature` is Ed25519 over
/// `"aura.signed-bundle.v1\n" + payload bytes`, made with a private key only
/// the server holds. The app embeds the public key(s) ([BundleKeys.forBuild])
/// and uses nothing that doesn't verify.
const String bundleFormat = 'aura.signed-bundle.v1';

final Uint8List _signingPrefix = Uint8List.fromList(
  utf8.encode('$bundleFormat\n'),
);

/// Why a bundle was not used. Never carries the bundle itself.
enum BundleRejection {
  /// Not the envelope shape at all.
  malformed,

  /// Signed with a key this build doesn't trust.
  unknownKey,

  /// The signature doesn't match the bytes (tampered, or a forged key id).
  badSignature,

  /// A bundle of another kind (e.g. helplines where a lexicon was expected).
  wrongKind,

  /// Signed, but the payload isn't the expected JSON.
  badPayload,

  /// Older than the one this phone already has (a replay).
  replayed,

  /// The content doesn't follow its contract (schema).
  invalidContent,

  /// The bundle's own test cases fail with this build's matcher.
  vectorsFailed,
}

class BundleRejected implements Exception {
  const BundleRejected(this.reason);

  final BundleRejection reason;

  @override
  String toString() => 'BundleRejected(${reason.name})';
}

/// The public keys this build trusts, by key id (first 8 bytes of the
/// SHA-256 of the raw 32-byte key, hex).
class BundleKeys {
  BundleKeys._(this._byId);

  /// Raw 32-byte Ed25519 public keys, base64. Malformed ones are skipped.
  factory BundleKeys.fromBase64(Iterable<String> keys) {
    final byId = <String, Uint8List>{};
    for (final k in keys) {
      final trimmed = k.trim();
      if (trimmed.isEmpty) continue;
      try {
        final raw = base64.decode(trimmed);
        if (raw.length != 32) continue;
        byId[keyIdOf(raw)] = raw;
      } on FormatException {
        continue;
      }
    }
    return BundleKeys._(byId);
  }

  /// `AURA_BUNDLE_PUBLIC_KEYS` (comma-separated base64 public keys, see
  /// docs/setup/lexicon-and-flags.md). Debug and profile builds without it
  /// trust the public development key, so a local API works out of the box;
  /// release builds never do — without the define they use only the bundled
  /// lexicon.
  factory BundleKeys.forBuild() {
    const defined = String.fromEnvironment('AURA_BUNDLE_PUBLIC_KEYS');
    if (defined.isNotEmpty) return BundleKeys.fromBase64(defined.split(','));
    return BundleKeys.fromBase64(
      kReleaseMode ? const [] : const [devBundleKey],
    );
  }

  /// The server's public development key (seed derived from a published
  /// string: NOT a secret, refused by a production API).
  static const String devBundleKey =
      'c8HcqQhqAfZ/Q0f+tf7I7n7meei0mzldCIbFYLYSfko=';

  final Map<String, Uint8List> _byId;

  bool get isEmpty => _byId.isEmpty;
  Iterable<String> get keyIds => _byId.keys;
  Uint8List? operator [](String keyId) => _byId[keyId];

  static String keyIdOf(List<int> rawPublicKey) {
    final digest = const DartSha256().hashSync(rawPublicKey).bytes;
    return [for (final b in digest.take(8)) b.toRadixString(16).padLeft(2, '0')]
        .join();
  }
}

/// A bundle whose signature checked out.
class VerifiedBundle {
  const VerifiedBundle({
    required this.kind,
    required this.seq,
    required this.issuedAt,
    required this.version,
    required this.content,
    required this.vectors,
    required this.keyId,
  });

  final String kind;

  /// Only grows on the server (a rollback is a new signature with a higher
  /// seq): a lower one than the phone already has is a replay.
  final int seq;
  final String issuedAt;
  final int version;
  final Map<String, dynamic> content;
  final List<dynamic> vectors;
  final String keyId;
}

/// Verifies [json] (the decoded envelope) with [keys] and returns its
/// payload; throws [BundleRejected] otherwise. The signature is checked over
/// the exact payload bytes before anything in them is read.
Future<VerifiedBundle> verifySignedBundle(
  Object? json,
  BundleKeys keys, {
  required String kind,
}) async {
  if (json is! Map<String, dynamic>) {
    throw const BundleRejected(BundleRejection.malformed);
  }
  final format = json['format'];
  final keyId = json['keyId'];
  final payload = json['payload'];
  final signature = json['signature'];
  if (format != bundleFormat ||
      keyId is! String ||
      payload is! String ||
      signature is! String) {
    throw const BundleRejected(BundleRejection.malformed);
  }
  final publicKey = keys[keyId];
  if (publicKey == null) throw const BundleRejected(BundleRejection.unknownKey);
  final Uint8List bytes;
  final Uint8List sig;
  try {
    bytes = base64.decode(payload);
    sig = base64.decode(signature);
  } on FormatException {
    throw const BundleRejected(BundleRejection.malformed);
  }
  if (sig.length != 64) {
    throw const BundleRejected(BundleRejection.badSignature);
  }
  var ok = false;
  try {
    ok = await DartEd25519().verify(
      [..._signingPrefix, ...bytes],
      signature: Signature(
        sig,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
  } on Object {
    ok = false;
  }
  if (!ok) throw const BundleRejected(BundleRejection.badSignature);

  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const BundleRejected(BundleRejection.badPayload);
  }
  if (decoded is! Map<String, dynamic>) {
    throw const BundleRejected(BundleRejection.badPayload);
  }
  final seq = decoded['seq'];
  final version = decoded['version'];
  final content = decoded['content'];
  final vectors = decoded['vectors'];
  if (seq is! int ||
      version is! int ||
      content is! Map<String, dynamic> ||
      vectors is! List<dynamic>) {
    throw const BundleRejected(BundleRejection.badPayload);
  }
  if (decoded['kind'] != kind) {
    throw const BundleRejected(BundleRejection.wrongKind);
  }
  final issuedAt = decoded['issuedAt'];
  return VerifiedBundle(
    kind: kind,
    seq: seq,
    issuedAt: issuedAt is String ? issuedAt : '',
    version: version,
    content: content,
    vectors: vectors,
    keyId: keyId,
  );
}
