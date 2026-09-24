import 'dart:convert';
import 'dart:io';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/core/remote_config/remote_config_store.dart';
import 'package:aura/src/core/remote_config/remote_helplines.dart';
import 'package:aura/src/core/remote_config/remote_lexicon.dart';
import 'package:aura/src/core/remote_config/signed_bundle.dart';
import 'package:aura/src/features/safety/helpline_list.dart';
import 'package:aura/src/features/support/helplines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';
import 'remote_config_fakes.dart';

/// The crisis helpline directory as a signed bundle (PRD 18 "Helplines by
/// country"; 06c F9; contracts/safety/helplines.schema.json). The safety
/// requirement: a bad or unsigned bundle never replaces working numbers —
/// unsigned, tampered, an unknown key, the wrong kind, a replay, a number
/// that doesn't match its dial string, a missing bundled region, vectors
/// that don't match: each leaves the numbers the phone shows as they were
/// (the bundled ones, or the last verified version). The bundle the NestJS
/// CLI signed verifies here (cross-implementation check).

Map<String, dynamic> baselineHelplinesJson() =>
    readSafetyJson('helplines.v1.json');

/// What NestJS puts in `vectors` (helplines/document.ts `resolutionVectors`).
List<Map<String, dynamic>> resolutionVectors(Map<String, dynamic> doc) {
  final countries = (doc['countries'] as Map<String, dynamic>).keys.toList()
    ..sort();
  List<String> dials(String c, bool minor) => [
    for (final l in (doc['countries'] as Map<String, dynamic>)[c] as List)
      if ((l as Map<String, dynamic>)['audience'] == 'everyone' || minor)
        l['dial'] as String,
  ];
  return [
    for (final c in countries)
      for (final minor in [false, true])
        {'country': c, 'minor': minor, 'dials': dials(c, minor)},
    {'country': 'ZZ', 'minor': false, 'dials': <String>[]},
  ];
}

Future<Map<String, dynamic>> helplinesBundle({
  required int seq,
  Map<String, dynamic>? content,
  List<dynamic>? vectors,
  String kind = 'helplines',
  List<int>? seed,
}) {
  final doc = content ?? baselineHelplinesJson();
  return signBundle({
    'kind': kind,
    'seq': seq,
    'issuedAt': '2026-09-24T00:00:00.000Z',
    'version': doc['version'],
    'content': doc,
    'vectors': vectors ?? resolutionVectors(doc),
  }, seed: seed);
}

/// The baseline with Tele-MANAS's number changed (what a real update does).
Map<String, dynamic> withNewTeleManas(int version) {
  final doc = baselineHelplinesJson();
  doc['version'] = version;
  final line =
      ((doc['countries'] as Map<String, dynamic>)['IN'] as List<dynamic>)[0]
          as Map<String, dynamic>;
  line['number'] = '14416-1';
  line['dial'] = '144161';
  return doc;
}

List<String> dialsNow(String? country, {bool minor = false}) => [
  for (final e in HelplineDirectory.active.resolve(country, isMinor: minor))
    e.dial,
];

const List<String> bundledIndia = ['14416', '18008914416', '112'];

void main() {
  final devKeys = BundleKeys.fromBase64(const [BundleKeys.devBundleKey]);

  tearDown(HelplineDirectory.resetToBundled);

  group('bundled directory', () {
    test('is contracts/safety/helplines.v1.json (tool/gen_helplines.py)', () {
      final compiled = compileHelplines(baselineHelplinesJson());
      final bundled = HelplineDirectory.bundled;
      expect(bundled.version, compiled.version);
      expect(bundled.countries.keys, compiled.countries.keys);
      for (final c in bundled.countries.keys) {
        final a = bundled.countries[c]!;
        final b = compiled.countries[c]!;
        expect(a.length, b.length);
        for (var i = 0; i < a.length; i++) {
          expect(
            (a[i].id, a[i].number, a[i].dial, a[i].minorsOnly),
            (b[i].id, b[i].number, b[i].dial, b[i].minorsOnly),
          );
          expect(a[i].names, b[i].names);
        }
      }
    });

    test('the generated Dart and server copies are up to date', () async {
      final r = await Process.run('python3', [
        'tool/gen_helplines.py',
        '--check',
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });

    test('PRD 06c F9: India 14416, 1-800-891-4416, 112 (+ Childline 1098 '
        'under 18), US 988, elsewhere none (the generic card)', () {
      expect(dialsNow('IN'), bundledIndia);
      expect(dialsNow('IN', minor: true), [
        '14416',
        '18008914416',
        '1098',
        '112',
      ]);
      expect(dialsNow('US'), ['988']);
      expect(dialsNow('GB'), isEmpty);
      expect(dialsNow(null), isEmpty);
    });

    test('names follow the app language, English where a line has none', () {
      final te = lookupAppLocalizations(const Locale('te'));
      final tl = lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'te', scriptCode: 'Latn'),
      );
      final hi = lookupAppLocalizations(const Locale('hi'));
      expect(helplinesFor('IN', te, isMinor: false).last.name, 'అత్యవసరం');
      expect(
        helplinesFor('IN', tl, isMinor: true)[2].name,
        'Childline · 18 ella lopu vaallaki',
      );
      final hl = lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
      );
      // Hindi and Hinglish names (Milestone B drafts).
      expect(
        helplinesFor('US', hi, isMinor: false).single.name,
        'Suicide & Crisis Lifeline · कॉल या टेक्स्ट करें',
      );
      expect(helplinesFor('IN', hi, isMinor: false).last.name, 'इमरजेंसी');
      expect(
        helplinesFor('IN', hl, isMinor: true)[2].name,
        'Childline · 18 se kam umar walon ke liye',
      );
      expect(helplinesFor('IN', te, isMinor: false).first.id, 'in.tele_manas');
      // A locale a line has no name in shows the English one.
      final us988 = HelplineDirectory.bundled.countries['US']!.single;
      expect(us988.nameFor('fr'), 'Suicide & Crisis Lifeline · call or text');
    });

    test('every bundled line has a name in all five app languages', () {
      for (final lines in HelplineDirectory.bundled.countries.values) {
        for (final line in lines) {
          for (final tag in ['en', 'te', 'te-Latn', 'hi', 'hi-Latn']) {
            expect(line.names[tag], isNotNull, reason: '${line.id} $tag');
          }
          expect(line.nameFor('hi'), matches(RegExp('[\u0900-\u097F]')));
        }
      }
    });
  });

  group('a good signed bundle', () {
    test('the bundle the server tooling signed verifies here', () async {
      final fixture = jsonDecode(
        File('$safetyDir/fixtures/helplines.v1.dev-signed.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final store = MemoryRemoteConfigStore();
      final remote = RemoteHelplines(keys: devKeys, store: store);
      expect(await remote.apply(fixture), isTrue);
      expect(remote.activeSeq, 1);
      expect(HelplineDirectory.active.source, HelplineSource.remote);
      expect(dialsNow('IN'), bundledIndia);
    });

    test('replaces the numbers, is kept, and comes back verified at the next '
        'start', () async {
      final store = MemoryRemoteConfigStore();
      final remote = RemoteHelplines(keys: devKeys, store: store);
      expect(
        await remote.apply(
          await helplinesBundle(seq: 10, content: withNewTeleManas(2)),
          etag: '"hl-10"',
        ),
        isTrue,
      );
      expect(dialsNow('IN').first, '144161');
      expect(store.files, contains(RemoteHelplines.storeName));

      HelplineDirectory.resetToBundled();
      final next = RemoteHelplines(keys: devKeys, store: store);
      await next.restore();
      expect(next.activeSeq, 10);
      expect(next.etag, '"hl-10"');
      expect(dialsNow('IN').first, '144161');
    });

    test(
      'a rollback on the server (older version, higher seq) is used',
      () async {
        final remote = RemoteHelplines(
          keys: devKeys,
          store: MemoryRemoteConfigStore(),
        );
        await remote.apply(
          await helplinesBundle(seq: 10, content: withNewTeleManas(2)),
        );
        expect(await remote.apply(await helplinesBundle(seq: 11)), isTrue);
        expect(dialsNow('IN'), bundledIndia);
      },
    );
  });

  group('a bad bundle never replaces working numbers', () {
    Future<void> refused(Object? envelope, {bool fromRemote = false}) async {
      final store = MemoryRemoteConfigStore();
      final remote = RemoteHelplines(keys: devKeys, store: store);
      var expected = bundledIndia;
      if (fromRemote) {
        await remote.apply(
          await helplinesBundle(seq: 10, content: withNewTeleManas(2)),
        );
        expected = dialsNow('IN');
      }
      final kept = store.files[RemoteHelplines.storeName];
      expect(await remote.apply(envelope), isFalse);
      expect(dialsNow('IN'), expected);
      expect(dialsNow('US'), ['988']);
      expect(store.files[RemoteHelplines.storeName], kept);
    }

    Map<String, dynamic> edit(void Function(Map<String, dynamic> doc) f) {
      final doc = withNewTeleManas(3);
      f(doc);
      return doc;
    }

    List<dynamic> india(Map<String, dynamic> doc) =>
        (doc['countries'] as Map<String, dynamic>)['IN'] as List<dynamic>;

    test('unsigned (not the envelope at all)', () async {
      await refused(withNewTeleManas(2));
      await refused({'format': bundleFormat, 'keyId': 'x', 'payload': 'e30='});
    });

    test('signed with a key this build does not trust', () async {
      await refused(
        await helplinesBundle(
          seq: 10,
          content: withNewTeleManas(2),
          seed: List.filled(32, 7),
        ),
      );
    });

    test('tampered after signing (a number swapped in transit)', () async {
      final good = await helplinesBundle(seq: 12, content: withNewTeleManas(2));
      await refused(
        tamper(good, (p) {
          final line =
              india(p['content'] as Map<String, dynamic>)[0]
                  as Map<String, dynamic>;
          line['number'] = '9999999999';
          line['dial'] = '9999999999';
        }),
      );
    });

    test('a crisis lexicon bundle where helplines were expected', () async {
      await refused(await lexiconBundle(seq: 20));
    });

    test('a replay of an older bundle', () async {
      await refused(await helplinesBundle(seq: 5), fromRemote: true);
      await refused(
        await helplinesBundle(seq: 10, content: withNewTeleManas(2)),
        fromRemote: true,
      );
    });

    test(
      'content against the contract (each on top of a working version)',
      () async {
        final bad = <Map<String, dynamic>>[
          edit((d) => (india(d)[0] as Map<String, dynamic>)['dial'] = '14417'),
          edit((d) => (d['countries'] as Map<String, dynamic>).remove('US')),
          edit(
            (d) => (d['countries'] as Map<String, dynamic>)['IN'] = <dynamic>[],
          ),
          edit(
            (d) => (d['countries'] as Map<String, dynamic>)['US'] = [
              {
                'id': 'us.988',
                'number': '988',
                'dial': '988',
                'audience': 'minors',
                'names': {'en': 'x'},
              },
            ],
          ),
          edit((d) => (india(d)[0] as Map<String, dynamic>)['id'] = 'us.x'),
          edit(
            (d) => (india(d)[0] as Map<String, dynamic>)['names'] = {'te': 'x'},
          ),
          edit(
            (d) => (india(d)[0] as Map<String, dynamic>)['audience'] = 'adults',
          ),
          edit((d) => d['name'] = 'aura.crisis_lexicon'),
          edit(
            (d) => (d['countries'] as Map<String, dynamic>)['gb'] = <dynamic>[],
          ),
        ];
        var seq = 20;
        for (final doc in bad) {
          await refused(
            await helplinesBundle(seq: seq++, content: doc),
            fromRemote: true,
          );
        }
      },
    );

    test('vectors this build resolves differently', () async {
      final doc = withNewTeleManas(2);
      final vectors = resolutionVectors(doc)
        ..[0] = {'country': 'IN', 'minor': false, 'dials': bundledIndia};
      await refused(
        await helplinesBundle(seq: 12, content: doc, vectors: vectors),
      );
      await refused(
        await helplinesBundle(seq: 13, content: doc, vectors: ['nope']),
      );
    });

    test('a kept envelope that no longer verifies falls back to the bundled '
        'numbers and is deleted', () async {
      final store = MemoryRemoteConfigStore({
        RemoteHelplines.storeName: jsonEncode({
          'etag': '"hl-9"',
          'bundle': tamper(
            await helplinesBundle(seq: 9, content: withNewTeleManas(2)),
            (p) => p['seq'] = 99,
          ),
        }),
      });
      final remote = RemoteHelplines(keys: devKeys, store: store);
      await remote.restore();
      expect(remote.activeSeq, 0);
      expect(dialsNow('IN'), bundledIndia);
      expect(store.files, isNot(contains(RemoteHelplines.storeName)));
    });
  });

  group('remote config controller', () {
    RemoteConfigController controller(
      FakeRemoteConfigApi api, {
      BundleKeys? keys,
    }) {
      final store = MemoryRemoteConfigStore();
      return RemoteConfigController(
        api: api,
        store: store,
        lexicon: RemoteLexicon(keys: keys ?? devKeys, store: store),
        helplines: RemoteHelplines(keys: keys ?? devKeys, store: store),
      );
    }

    test('downloads the directory when the config points at a newer seq, '
        'refreshed on each fetch', () async {
      final api = FakeRemoteConfigApi()
        ..configAnswers = [
          Got(configJson(helplines: (version: 2, seq: 10)), etag: '"c1"'),
        ]
        ..helplineAnswers = [
          Got(
            await helplinesBundle(seq: 10, content: withNewTeleManas(2)),
            etag: '"hl-10"',
          ),
        ];
      final c = controller(api);
      addTearDown(c.dispose);
      await c.refresh(force: true);
      expect(dialsNow('IN').first, '144161');
      expect(api.helplineEtags, [null]);
      // Same seq again: no download.
      await c.refresh(force: true);
      expect(api.helplineEtags, hasLength(1));
    });

    test(
      'a refused bundle is not downloaded again; the numbers stay',
      () async {
        final api = FakeRemoteConfigApi()
          ..configAnswers = [Got(configJson(helplines: (version: 2, seq: 10)))]
          ..helplineAnswers = [
            Got(
              await helplinesBundle(
                seq: 10,
                content: withNewTeleManas(2),
                seed: List.filled(32, 9),
              ),
            ),
          ];
        final c = controller(api);
        addTearDown(c.dispose);
        await c.refresh(force: true);
        await c.refresh(force: true);
        expect(api.helplineEtags, hasLength(1));
        expect(dialsNow('IN'), bundledIndia);
      },
    );

    test('no trusted key (a release build without AURA_BUNDLE_PUBLIC_KEYS): '
        'never downloads, bundled numbers', () async {
      final api = FakeRemoteConfigApi()
        ..configAnswers = [Got(configJson(helplines: (version: 2, seq: 10)))];
      final c = controller(api, keys: BundleKeys.fromBase64(const []));
      addTearDown(c.dispose);
      await c.refresh(force: true);
      expect(api.helplineEtags, isEmpty);
      expect(dialsNow('IN'), bundledIndia);
    });
  });

  group('the crisis sheet list', () {
    Future<void> pump(WidgetTester tester, String region) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: HelplineList()),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...testOverrides(db: memoryDb()),
            deviceRegionProvider.overrideWithValue(region),
          ],
          child: MaterialApp.router(
            theme: buildAuraTheme(localeFromTag('en')),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...systemLocalizationDelegates,
            ],
            routerConfig: router,
          ),
        ),
      );
      await settleIo(tester);
    }

    testWidgets('shows a verified update at once, and the bundled numbers '
        'after a refused one', (tester) async {
      await pump(tester, 'IN');
      expect(find.text('14416'), findsOneWidget);
      final remote = RemoteHelplines(
        keys: devKeys,
        store: MemoryRemoteConfigStore(),
      );
      await tester.runAsync(
        () async => remote.apply(
          await helplinesBundle(seq: 3, content: withNewTeleManas(2)),
        ),
      );
      await tester.pump();
      expect(find.text('14416-1'), findsOneWidget);
      expect(find.text('14416'), findsNothing);
      expect(find.byKey(const ValueKey('support-call-144161')), findsOneWidget);
      HelplineDirectory.resetToBundled();
      await tester.runAsync(
        () async => remote.apply(
          await helplinesBundle(seq: 9, seed: List.filled(32, 3)),
        ),
      );
      await tester.pump();
      expect(find.text('14416'), findsOneWidget);
    });

    testWidgets('a region with no listed line: the local emergency card, '
        'never an empty list', (tester) async {
      await pump(tester, 'DE');
      expect(
        find.byKey(const ValueKey('support-local-emergency')),
        findsOneWidget,
      );
    });
  });
}
