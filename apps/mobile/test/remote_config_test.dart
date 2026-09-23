import 'dart:convert';

import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/core/remote_config/remote_config_store.dart';
import 'package:aura/src/core/remote_config/remote_lexicon.dart';
import 'package:aura/src/core/remote_config/signed_bundle.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/support/crisis_lexicon.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'remote_config_fakes.dart';

/// Remote flags (PRD 19 REQ-ADM-12 "Flag changes reach clients within 5 min
/// without a release"): bundled safe defaults, the kept copy offline, the
/// fetch with If-None-Match, the foreground-only poll (≤ 240 s), and the
/// lexicon download when the server points at a newer signed version.
void main() {
  tearDown(CrisisLexicon.resetToBundled);

  RemoteConfigController controller(
    FakeRemoteConfigApi api, {
    MemoryRemoteConfigStore? store,
    FixedClock? clock,
  }) {
    final s = store ?? MemoryRemoteConfigStore();
    return RemoteConfigController(
      api: api,
      store: s,
      lexicon: RemoteLexicon(
        keys: BundleKeys.fromBase64(const [BundleKeys.devBundleKey]),
        store: s,
      ),
      clock: clock ?? FixedClock(testNow),
    );
  }

  test('bundled safe defaults before the server ever answered', () {
    const f = RemoteFlags.defaults;
    expect(f.roomsEnabled, isTrue, reason: 'the server still decides joins');
    expect(f.roomsPoolHi, isFalse);
    expect(f.enabled('something_new'), isFalse);
  });

  test('parses the contract document; malformed flags are skipped', () {
    final doc = RemoteConfigDoc.fromJson({
      ...configJson(flags: {'rooms_enabled': false}),
      'flags': {
        'rooms_enabled': {'enabled': false},
        'reflections_composer': {
          'enabled': true,
          'payload': {
            'pausedPools': ['te'],
          },
        },
        'broken': {'enabled': 'yes'},
      },
      'bundles': {
        'crisis_lexicon': {'version': 3, 'seq': 1727000000000},
      },
    });
    expect(doc.flags.roomsEnabled, isFalse);
    expect(doc.flags.payload('reflections_composer'), {
      'pausedPools': ['te'],
    });
    expect(doc.flags.keys, isNot(contains('broken')));
    expect(doc.bundles['crisis_lexicon']?.seq, 1727000000000);
    expect(
      () => RemoteConfigDoc.fromJson({'flags': {}}),
      throwsFormatException,
    );
  });

  test('start in the foreground: fetch, flags change, the copy is kept; the '
      'next fetch sends If-None-Match', () async {
    final api = FakeRemoteConfigApi()
      ..configAnswers = [
        Got(configJson(flags: {'rooms_enabled': false}), etag: '"c1-a"'),
        const NotModified(),
      ];
    final store = MemoryRemoteConfigStore();
    final c = controller(api, store: store);
    final seen = <bool>[];
    c.flags.addListener(() => seen.add(c.flags.value.roomsEnabled));
    await c.start(foreground: true);
    await c.refresh(force: true);
    expect(c.flags.value.roomsEnabled, isFalse);
    expect(seen, [false]);
    expect(api.configEtags, [null, '"c1-a"']);
    expect(
      jsonDecode(store.files[RemoteConfigController.storeName]!),
      containsPair('etag', '"c1-a"'),
    );
    c.dispose();
  });

  test(
    'offline at start: the kept copy applies; nothing kept: defaults',
    () async {
      final store = MemoryRemoteConfigStore({
        RemoteConfigController.storeName: jsonEncode({
          'etag': '"c1-kept"',
          'doc': configJson(
            flags: {'rooms_enabled': false, 'rooms_pool_hi': true},
          ),
        }),
      });
      final offline = FakeRemoteConfigApi()..configError = Exception('offline');
      final c = controller(offline, store: store);
      await c.start(foreground: true);
      expect(c.flags.value.roomsEnabled, isFalse);
      expect(c.flags.value.roomsPoolHi, isTrue);
      expect(offline.configEtags, ['"c1-kept"']);
      c.dispose();

      final fresh = controller(
        FakeRemoteConfigApi()..configError = Exception(),
      );
      await fresh.start(foreground: true);
      expect(fresh.flags.value, RemoteFlags.defaults);
      fresh.dispose();

      // An unreadable kept copy is dropped.
      final junk = MemoryRemoteConfigStore({
        RemoteConfigController.storeName: '{"doc": 1}',
      });
      final j = controller(FakeRemoteConfigApi(), store: junk);
      await j.start(foreground: false);
      expect(junk.files, isEmpty);
      j.dispose();
    },
  );

  testWidgets('polls every pollSeconds while in the foreground only (a flag '
      'change lands within 5 min)', (tester) async {
    final api = FakeRemoteConfigApi()
      ..configAnswers = [
        Got(configJson(pollSeconds: 240), etag: '"c1-a"'),
        const NotModified(),
        Got(configJson(flags: {'rooms_enabled': false}), etag: '"c1-b"'),
      ];
    final clock = FixedClock(testNow);
    final c = controller(api, clock: clock);
    await c.start(foreground: true);
    await tester.pump();
    expect(api.configEtags, hasLength(1));
    expect(c.polling, isTrue);
    expect(c.pollSeconds, 240);

    for (var i = 0; i < 2; i++) {
      clock.instant = clock.instant.add(const Duration(seconds: 240));
      await tester.pump(const Duration(seconds: 240));
      await tester.pump();
    }
    expect(api.configEtags, hasLength(3));
    expect(c.flags.value.roomsEnabled, isFalse);

    // In the background: no timer, no calls.
    c.onBackground();
    expect(c.polling, isFalse);
    await tester.pump(const Duration(minutes: 20));
    expect(api.configEtags, hasLength(3));

    // Back in the foreground: at once (a resume), then polling again.
    clock.instant = clock.instant.add(const Duration(minutes: 20));
    c.onForeground();
    await tester.pump();
    expect(api.configEtags, hasLength(4));
    expect(c.polling, isTrue);
    c.dispose();
    expect(c.polling, isFalse);
  });

  testWidgets('resume + sync right after each other make one call', (
    tester,
  ) async {
    final api = FakeRemoteConfigApi()
      ..configAnswers = [Got(configJson(), etag: '"c1-a"')];
    final clock = FixedClock(testNow);
    final c = controller(api, clock: clock);
    await c.start(foreground: true);
    await tester.pump();
    c.onForeground();
    await c.refresh();
    expect(api.configEtags, hasLength(1));
    clock.instant = clock.instant.add(const Duration(seconds: 30));
    await c.refresh();
    expect(api.configEtags, hasLength(2));
    c.dispose();
  });

  test('pollSeconds is clamped to 60–300 s', () async {
    for (final (server, used) in [(10, 60), (240, 240), (900, 300)]) {
      final api = FakeRemoteConfigApi()
        ..configAnswers = [Got(configJson(pollSeconds: server))];
      final c = controller(api);
      await c.start(foreground: false);
      await c.refresh(force: true);
      expect(c.pollSeconds, used);
      c.dispose();
    }
  });

  test('no trusted key (a release build without AURA_BUNDLE_PUBLIC_KEYS): '
      'nothing is downloaded, the bundled lexicon stays', () async {
    final api = FakeRemoteConfigApi()
      ..configAnswers = [Got(configJson(lexicon: (version: 2, seq: 500)))];
    final store = MemoryRemoteConfigStore();
    final c = RemoteConfigController(
      api: api,
      store: store,
      lexicon: RemoteLexicon(
        keys: BundleKeys.fromBase64(const []),
        store: store,
      ),
      clock: FixedClock(testNow),
    );
    await c.start(foreground: false);
    await c.refresh(force: true);
    expect(api.lexiconEtags, isEmpty);
    expect(CrisisLexicon.active.source, LexiconSource.bundled);
    c.dispose();
  });

  test('downloads the lexicon only when the server points at a newer seq, '
      'and activates it only after it verifies', () async {
    final v2 = await lexiconBundle(seq: 500, content: lexiconWithNewPhrase(2));
    final api = FakeRemoteConfigApi()
      ..configAnswers = [
        Got(configJson(lexicon: (version: 2, seq: 500)), etag: '"c1-a"'),
      ]
      ..lexiconAnswers = [Got(v2, etag: '"lx-500"')];
    final c = controller(api);
    await c.start(foreground: false);
    await c.refresh(force: true);
    expect(api.lexiconEtags, [null]);
    expect(CrisisLexicon.active.version, 2);
    expect(c.lexicon.activeSeq, 500);
    expect(noteNeedsSupport('no way out for me'), isTrue);

    // Same pointer again: no download.
    await c.refresh(force: true);
    expect(api.lexiconEtags, hasLength(1));
    c.dispose();
  });

  test(
    'a tampered download is never used: the bundled lexicon stays',
    () async {
      final forged = tamper(
        await lexiconBundle(seq: 500, content: lexiconWithNewPhrase(2)),
        (p) => (p['content']['entries'] as List<dynamic>).removeWhere(
          (e) => (e as Map<String, dynamic>)['kind'] == 'crisis',
        ),
      );
      final api = FakeRemoteConfigApi()
        ..configAnswers = [Got(configJson(lexicon: (version: 2, seq: 500)))]
        ..lexiconAnswers = [Got(forged)];
      final c = controller(api);
      await c.start(foreground: false);
      await c.refresh(force: true);
      expect(CrisisLexicon.active.source, LexiconSource.bundled);
      expect(noteNeedsSupport('I want to kill myself'), isTrue);
      // The same refused bundle is not downloaded again...
      await c.refresh(force: true);
      expect(api.lexiconEtags, hasLength(1));
      // ...until the server points at another one.
      api
        ..configAnswers = [Got(configJson(lexicon: (version: 2, seq: 600)))]
        ..lexiconAnswers = [
          Got(await lexiconBundle(seq: 600, content: lexiconWithNewPhrase(2))),
        ];
      await c.refresh(force: true);
      expect(api.lexiconEtags, hasLength(2));
      expect(CrisisLexicon.active.version, 2);
      c.dispose();
    },
  );
}
