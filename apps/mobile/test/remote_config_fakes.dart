import 'dart:convert';
import 'dart:io';

import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/core/remote_config/signed_bundle.dart';
import 'package:cryptography/dart.dart';

/// Test doubles for remote config (PRD 19 REQ-ADM-12): bundles signed here
/// with the public development key (the same key the server's dev mode uses,
/// server/aura-api/src/remote-config/signing.ts), the shared contract files,
/// and a scripted [RemoteConfigApi].

const String safetyDir = '../../contracts/safety';

Map<String, dynamic> readSafetyJson(String name) =>
    jsonDecode(File('$safetyDir/$name').readAsStringSync())
        as Map<String, dynamic>;

/// contracts/safety/crisis_lexicon.v1.json.
Map<String, dynamic> baselineLexiconJson() =>
    readSafetyJson('crisis_lexicon.v1.json');

/// contracts/safety/crisis_lexicon.vectors.json `cases`.
List<dynamic> contractVectors() =>
    readSafetyJson('crisis_lexicon.vectors.json')['cases'] as List<dynamic>;

/// The dev key's seed: SHA-256 of the published label (NOT a secret).
List<int> devSeed() => const DartSha256()
    .hashSync(
      utf8.encode(
        'aura/dev-bundle-signing-key/v1 -- PUBLIC, DEVELOPMENT ONLY, NEVER '
        'PRODUCTION',
      ),
    )
    .bytes;

/// An envelope exactly like `GET /v1/lexicon/crisis` serves.
Future<Map<String, dynamic>> signBundle(
  Map<String, dynamic> payload, {
  List<int>? seed,
}) async {
  final bytes = utf8.encode(jsonEncode(payload));
  final algorithm = DartEd25519();
  final keyPair = await algorithm.newKeyPairFromSeed(seed ?? devSeed());
  final signature = await algorithm.sign([
    ...utf8.encode('$bundleFormat\n'),
    ...bytes,
  ], keyPair: keyPair);
  final publicKey = await keyPair.extractPublicKey();
  return {
    'format': bundleFormat,
    'keyId': BundleKeys.keyIdOf(publicKey.bytes),
    'payload': base64.encode(bytes),
    'signature': base64.encode(signature.bytes),
  };
}

/// A signed crisis lexicon bundle: [content] (default the baseline) with the
/// contract vectors plus [extraVectors].
Future<Map<String, dynamic>> lexiconBundle({
  required int seq,
  Map<String, dynamic>? content,
  List<Map<String, dynamic>> extraVectors = const [],
  List<dynamic>? vectors,
  String kind = 'crisis_lexicon',
  List<int>? seed,
}) {
  final doc = content ?? baselineLexiconJson();
  return signBundle({
    'kind': kind,
    'seq': seq,
    'issuedAt': '2026-09-24T00:00:00.000Z',
    'version': doc['version'],
    'content': doc,
    'vectors': vectors ?? [...contractVectors(), ...extraVectors],
  }, seed: seed);
}

/// The baseline plus one more crisis entry ("no way out for me"), as
/// [version].
Map<String, dynamic> lexiconWithNewPhrase(int version) {
  final doc = baselineLexiconJson();
  doc['version'] = version;
  (doc['entries'] as List<dynamic>).add({
    'id': 'en.no_way_out',
    'language': 'en',
    'kind': 'crisis',
    'phrase': 'no way out for me',
    'variants': ['theres no way out for me'],
  });
  return doc;
}

/// Re-encodes a signed envelope's payload after [edit] (the signature stays:
/// what a tampered cache or a man in the middle would produce).
Map<String, dynamic> tamper(
  Map<String, dynamic> envelope,
  void Function(Map<String, dynamic> payload) edit,
) {
  final payload = jsonDecode(
    utf8.decode(base64.decode(envelope['payload'] as String)),
  ) as Map<String, dynamic>;
  edit(payload);
  return {
    ...envelope,
    'payload': base64.encode(utf8.encode(jsonEncode(payload))),
  };
}

/// Scripted `GET /v1/config` / `GET /v1/lexicon/crisis`.
class FakeRemoteConfigApi implements RemoteConfigApi {
  final List<String?> configEtags = [];
  final List<String?> lexiconEtags = [];

  /// The next answers, in order (the last one repeats).
  List<Fetched<Object?>> configAnswers = [const NotModified()];
  List<Fetched<Object?>> lexiconAnswers = [const NotPublished()];
  Object? configError;

  @override
  Future<Fetched<Object?>> config({String? etag}) async {
    configEtags.add(etag);
    final e = configError;
    if (e != null) throw e;
    return configAnswers.length > 1
        ? configAnswers.removeAt(0)
        : configAnswers.first;
  }

  @override
  Future<Fetched<Object?>> lexicon({String? etag}) async {
    lexiconEtags.add(etag);
    return lexiconAnswers.length > 1
        ? lexiconAnswers.removeAt(0)
        : lexiconAnswers.first;
  }
}

/// A `GET /v1/config` body.
Map<String, dynamic> configJson({
  String version = 'c1-aaaa',
  int pollSeconds = 240,
  Map<String, bool> flags = const {
    'rooms_enabled': true,
    'rooms_pool_hi': false,
  },
  ({int version, int seq})? lexicon,
}) => {
  'configVersion': version,
  'pollSeconds': pollSeconds,
  'flags': {
    for (final e in flags.entries) e.key: {'enabled': e.value},
  },
  'bundles': {
    if (lexicon != null)
      'crisis_lexicon': {'version': lexicon.version, 'seq': lexicon.seq},
  },
};
