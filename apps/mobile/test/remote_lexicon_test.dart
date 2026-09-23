import 'dart:convert';
import 'dart:io';

import 'package:aura/src/core/remote_config/remote_config_store.dart';
import 'package:aura/src/core/remote_config/remote_lexicon.dart';
import 'package:aura/src/core/remote_config/signed_bundle.dart';
import 'package:aura/src/features/support/crisis_lexicon.dart';
import 'package:flutter_test/flutter_test.dart';

import 'remote_config_fakes.dart';

/// Signed, reversible crisis lexicon versions on the phone (PRD 19
/// REQ-ADM-12; 06c F9): only a bundle whose Ed25519 signature verifies with
/// an embedded key, whose seq is newer, whose content follows contracts/safety
/// and whose vectors pass here is used; otherwise the last verified one
/// stays, else the bundled v1. Includes the bundle the NestJS CLI signed
/// (cross-implementation check) and tampered payloads.
void main() {
  final devKeys = BundleKeys.fromBase64(const [BundleKeys.devBundleKey]);
  const newPhrase = 'there is no way out for me';

  tearDown(CrisisLexicon.resetToBundled);

  group('signature', () {
    test('the bundle signed by the server tooling (contracts/safety/fixtures) '
        'verifies here with the dev key', () async {
      final fixture = jsonDecode(
        File('$safetyDir/fixtures/crisis_lexicon.v1.dev-signed.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final b = await verifySignedBundle(
        fixture,
        devKeys,
        kind: 'crisis_lexicon',
      );
      expect(b.keyId, 'ba9afcf9c1f7ab25');
      expect(b.version, 1);
      expect(b.seq, 1);
      expect(b.content, baselineLexiconJson());
      expect(b.vectors, contractVectors());
    });

    test('this build trusts the dev key only outside release builds', () {
      final keys = BundleKeys.forBuild();
      expect(keys.keyIds, contains('ba9afcf9c1f7ab25'));
      expect(
        BundleKeys.keyIdOf(base64.decode(BundleKeys.devBundleKey)),
        'ba9afcf9c1f7ab25',
      );
      expect(BundleKeys.fromBase64(const ['nope', 'AAAA', '']).isEmpty, isTrue);
    });

    Future<BundleRejection> reason(
      Object? json, {
      String kind = 'crisis_lexicon',
    }) async {
      try {
        await verifySignedBundle(json, devKeys, kind: kind);
        fail('accepted');
      } on BundleRejected catch (e) {
        return e.reason;
      }
    }

    test('tampered payload, bad signature, unknown key, other kind, junk: '
        'refused before anything is read', () async {
      final good = await lexiconBundle(seq: 5);
      // One crisis entry removed after signing.
      final removed = tamper(good, (p) {
        (p['content']['entries'] as List<dynamic>).removeWhere(
          (e) => (e as Map<String, dynamic>)['id'] == 'en.kill_myself',
        );
      });
      expect(await reason(removed), BundleRejection.badSignature);
      // A replay with a bumped seq.
      expect(
        await reason(tamper(good, (p) => p['seq'] = 999)),
        BundleRejection.badSignature,
      );
      final sig = base64.decode(good['signature'] as String);
      sig[0] ^= 1;
      expect(
        await reason({...good, 'signature': base64.encode(sig)}),
        BundleRejection.badSignature,
      );
      expect(
        await reason({...good, 'signature': 'AAAA'}),
        BundleRejection.badSignature,
      );
      final other = await lexiconBundle(seq: 5, seed: List.filled(32, 7));
      expect(await reason(other), BundleRejection.unknownKey);
      // Another key claiming the dev key id.
      expect(
        await reason({...other, 'keyId': good['keyId']}),
        BundleRejection.badSignature,
      );
      expect(
        await reason(await lexiconBundle(seq: 5, kind: 'helplines')),
        BundleRejection.wrongKind,
      );
      expect(await reason({...good, 'format': 'x'}), BundleRejection.malformed);
      expect(await reason(null), BundleRejection.malformed);
      expect(await reason('text'), BundleRejection.malformed);
    });
  });

  group('RemoteLexicon', () {
    late MemoryRemoteConfigStore store;
    late RemoteLexicon lexicon;

    setUp(() {
      store = MemoryRemoteConfigStore();
      lexicon = RemoteLexicon(keys: devKeys, store: store);
    });

    test('nothing downloaded: the bundled v1 is active', () async {
      await lexicon.restore();
      expect(CrisisLexicon.active.source, LexiconSource.bundled);
      expect(CrisisLexicon.active.version, 1);
      expect(noteNeedsSupport(newPhrase), isFalse);
      expect(noteNeedsSupport('I want to kill myself'), isTrue);
    });

    test('a signed v2 becomes active: noteNeedsSupport / lexiconVerdict use '
        'it, and it is kept for the next start', () async {
      final v2 = await lexiconBundle(
        seq: 100,
        content: lexiconWithNewPhrase(2),
        extraVectors: [
          {'text': newPhrase, 'verdict': 'crisis'},
        ],
      );
      expect(await lexicon.apply(v2, etag: '"lx-100"'), isTrue);
      expect(CrisisLexicon.active.source, LexiconSource.remote);
      expect(CrisisLexicon.active.version, 2);
      expect(noteNeedsSupport(newPhrase), isTrue);
      expect(lexiconVerdict('dying of boredom'), LexiconVerdict.soft);
      expect(lexicon.activeSeq, 100);
      expect(lexicon.etag, '"lx-100"');

      // Next start: verified again, then active.
      CrisisLexicon.resetToBundled();
      final next = RemoteLexicon(keys: devKeys, store: store);
      await next.restore();
      expect(CrisisLexicon.active.version, 2);
      expect(next.activeSeq, 100);
      expect(noteNeedsSupport(newPhrase), isTrue);
    });

    test('a rollback (older version, newer seq) is applied; a replay (older '
        'seq) is not', () async {
      await lexicon.apply(
        await lexiconBundle(seq: 100, content: lexiconWithNewPhrase(2)),
      );
      final replayOfOld = await lexiconBundle(seq: 50);
      expect(await lexicon.apply(replayOfOld), isFalse);
      expect(CrisisLexicon.active.version, 2);
      final rollback = await lexiconBundle(seq: 200);
      expect(await lexicon.apply(rollback), isTrue);
      expect(CrisisLexicon.active.version, 1);
      expect(CrisisLexicon.active.source, LexiconSource.remote);
      expect(noteNeedsSupport(newPhrase), isFalse);
      // The same seq again is not newer.
      expect(await lexicon.apply(rollback), isFalse);
    });

    test('never applies a tampered, unsigned or unknown-key bundle: the last '
        'verified one stays', () async {
      await lexicon.apply(
        await lexiconBundle(seq: 100, content: lexiconWithNewPhrase(2)),
      );
      final weakened = tamper(await lexiconBundle(seq: 300), (p) {
        (p['content']['entries'] as List<dynamic>).removeWhere(
          (e) => (e as Map<String, dynamic>)['kind'] == 'crisis',
        );
      });
      expect(await lexicon.apply(weakened), isFalse);
      final unsigned = {
        'format': bundleFormat,
        'keyId': 'ba9afcf9c1f7ab25',
        'payload': base64.encode(
          utf8.encode(jsonEncode({'kind': 'crisis_lexicon'})),
        ),
        'signature': '',
      };
      expect(await lexicon.apply(unsigned), isFalse);
      expect(
        await lexicon.apply(
          await lexiconBundle(seq: 300, seed: List.filled(32, 9)),
        ),
        isFalse,
      );
      expect(CrisisLexicon.active.version, 2);
      expect(lexicon.activeSeq, 100);
      expect(noteNeedsSupport(newPhrase), isTrue);
    });

    test(
      'a signed bundle whose vectors fail with this build is refused',
      () async {
        final wrong = await lexiconBundle(
          seq: 100,
          vectors: [
            ...contractVectors(),
            {'text': 'I want to kill myself', 'verdict': 'none'},
          ],
        );
        expect(await lexicon.apply(wrong), isFalse);
        expect(CrisisLexicon.active.source, LexiconSource.bundled);
        // And vectors that need an entry the content doesn't have.
        final missing = await lexiconBundle(
          seq: 101,
          extraVectors: [
            {'text': newPhrase, 'verdict': 'crisis'},
          ],
        );
        expect(await lexicon.apply(missing), isFalse);
      },
    );

    test('a signed bundle with invalid content (schema) is refused', () async {
      for (final edit in <void Function(Map<String, dynamic>)>[
        (d) => d['name'] = 'other',
        (d) => d['version'] = 0,
        (d) => (d['languages'] as Map<String, dynamic>).remove('hi'),
        (d) => d['entries'] = <dynamic>[],
        (d) => (d['entries'] as List<dynamic>).add({
          'id': 'en.kill_myself',
          'language': 'en',
          'kind': 'crisis',
          'phrase': 'x',
        }),
        (d) => (d['entries'] as List<dynamic>).add({
          'id': 'en.bad',
          'language': 'en',
          'kind': 'maybe',
          'phrase': 'x',
        }),
        (d) => (d['entries'] as List<dynamic>).add({
          'id': 'te.bad',
          'language': 'te',
          'kind': 'crisis',
          'phrase': 'die',
        }),
      ]) {
        final doc = baselineLexiconJson();
        edit(doc);
        final b = await lexiconBundle(seq: 100, content: doc);
        expect(await lexicon.apply(b), isFalse);
      }
      expect(CrisisLexicon.active.source, LexiconSource.bundled);
    });

    test('a kept bundle that no longer verifies (e.g. its key was retired) is '
        'dropped at start; the bundled v1 is used', () async {
      await lexicon.apply(
        await lexiconBundle(seq: 100, content: lexiconWithNewPhrase(2)),
      );
      CrisisLexicon.resetToBundled();
      final noKeys = RemoteLexicon(
        keys: BundleKeys.fromBase64(const []),
        store: store,
      );
      await noKeys.restore();
      expect(CrisisLexicon.active.source, LexiconSource.bundled);
      expect(store.files[RemoteLexicon.storeName], isNull);

      // A tampered file on disk is dropped too.
      store.files[RemoteLexicon.storeName] = jsonEncode({
        'etag': null,
        'bundle': tamper(
          await lexiconBundle(seq: 100, content: lexiconWithNewPhrase(2)),
          (p) => p['version'] = 3,
        ),
      });
      await RemoteLexicon(keys: devKeys, store: store).restore();
      expect(CrisisLexicon.active.source, LexiconSource.bundled);
      expect(store.files[RemoteLexicon.storeName], isNull);
    });

    test('compileLexicon + vectorsPass: the baseline passes every contract '
        'vector with this matcher', () {
      final compiled = compileLexicon(baselineLexiconJson());
      expect(compiled.version, 1);
      expect(vectorsPass(compiled, contractVectors()), isTrue);
      expect(
        vectorsPass(compiled, [
          {'text': 'x', 'verdict': 'maybe'},
        ]),
        isFalse,
      );
    });
  });
}
