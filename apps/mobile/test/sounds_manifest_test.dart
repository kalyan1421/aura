import 'dart:convert';
import 'dart:io';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/features/sanctuary/sounds/procedural_synth.dart';
import 'package:aura/src/features/sanctuary/sounds/stem_labels.dart';
import 'package:aura/src/features/sanctuary/sounds/stem_manifest.dart';
import 'package:aura/src/features/sanctuary/sounds/stem_manifest_bundled.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Sounds stem manifest (`contracts/sounds/stems.v1.json`).
void main() {
  String entry(Map<String, Object?> fields) => jsonEncode(fields);
  String doc(List<String> stems, {Object version = 1, Object? maxLayers}) =>
      '{"version": ${jsonEncode(version)}, '
      '${maxLayers == null ? '' : '"max_layers": ${jsonEncode(maxLayers)}, '}'
      '"stems": [${stems.join(',')}]}';

  final sha = 'c' * 64;
  Map<String, Object?> fileStem([Map<String, Object?> over = const {}]) => {
    'id': 'rain',
    'title_key': 'sounds_stemRain',
    'tier': 'free',
    'role': 'bed',
    'kind': 'file',
    'file': 'base/rain.v1.m4a',
    'bytes': 2000000,
    'sha256': sha,
    'licence': 'CC0-1.0',
    'source_url': 'https://example.org/rain',
    'status': 'available',
    ...over,
  };
  Map<String, Object?> procStem([Map<String, Object?> over = const {}]) => {
    'id': 'brown_noise',
    'title_key': 'sounds_stemBrownNoise',
    'tier': 'free',
    'role': 'bed',
    'kind': 'procedural',
    'generator': 'brown_noise',
    'licence': 'generated-in-code',
    'status': 'available',
    ...over,
  };

  group('the bundled manifest', () {
    test('is the contract file, unchanged', () {
      final contract = File(
        '../../contracts/sounds/stems.v1.json',
      ).readAsStringSync();
      expect(jsonDecode(bundledStemManifestJson), jsonDecode(contract));
    });

    test('lists the PRD base set free, and Plus extras', () {
      final m = StemManifest.bundled;
      expect(m.maxLayers, 4);
      final free = {
        for (final s in m.listed)
          if (!s.isPlus) s.id,
      };
      expect(free, {
        'rain',
        'ocean',
        'wind',
        'night_insects',
        'singing_bowl',
        'chimes',
        'brown_noise',
      });
      expect(m.listed.where((s) => s.isPlus), isNotEmpty);
    });

    test('pending recordings without a stand-in stay hidden', () {
      final m = StemManifest.bundled;
      for (final s in m.stems) {
        if (s.status == StemStatus.pendingSourcing &&
            s.fallbackGenerator == null) {
          expect(s.listed, isFalse, reason: s.id);
        }
      }
      expect(m.byId('monsoon_roof')!.listed, isFalse);
      expect(m.byId('rain')!.listed, isTrue); // generated stand-in
      expect(m.byId('rain')!.hasRecording, isFalse);
    });

    test('brown noise plays with no download (fresh install)', () {
      final brown = StemManifest.bundled.byId('brown_noise')!;
      expect(brown.kind, StemKind.procedural);
      expect(brown.generatedSource, StemGenerator.brownNoise);
    });

    test('every title key is translated (en, te, te-Latn)', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final te = lookupAppLocalizations(const Locale('te'));
      final tl = lookupAppLocalizations(localeFromTag('te-Latn'));
      for (final s in StemManifest.bundled.stems) {
        expect(stemTitleForKey(en, s.titleKey), isNotNull, reason: s.id);
        expect(stemTitleForKey(te, s.titleKey), isNotNull, reason: s.id);
        expect(stemTitleForKey(tl, s.titleKey), isNotNull, reason: s.id);
        expect(
          stemTitleForKey(te, s.titleKey),
          isNot(stemTitleForKey(en, s.titleKey)),
          reason: '${s.id} has no Telugu name',
        );
      }
    });

    test('every stem has a row in the licence log', () {
      final log = File('../../docs/sounds/licence-log.md').readAsStringSync();
      for (final s in StemManifest.bundled.stems) {
        expect(log, contains('| ${s.id} |'), reason: s.id);
      }
    });

    test('no downloadable file without a licence, size and hash', () {
      for (final s in StemManifest.bundled.stems) {
        if (s.hasRecording) {
          expect(s.licence, isNotNull, reason: s.id);
          expect(s.file!.bytes, greaterThan(0), reason: s.id);
          expect(s.file!.sha256, hasLength(64), reason: s.id);
        }
      }
    });
  });

  group('parse', () {
    test('a valid file stem and a procedural stem', () {
      final m = StemManifest.parse(
        doc([entry(fileStem()), entry(procStem())], maxLayers: 3),
      );
      expect(m.maxLayers, 3);
      expect(m.stems, hasLength(2));
      final rain = m.byId('rain')!;
      expect(rain.hasRecording, isTrue);
      expect(rain.file!.bytes, 2000000);
      expect(rain.file!.sha256, sha);
      expect(rain.licence, 'CC0-1.0');
      expect(rain.sourceUrl, 'https://example.org/rain');
      expect(rain.generatedSource, isNull);
      final brown = m.byId('brown_noise')!;
      expect(brown.generator, StemGenerator.brownNoise);
      expect(brown.role, StemRole.bed);
    });

    test('max_layers defaults to 4; unknown fields are ignored', () {
      final m = StemManifest.parse(
        doc([
          entry(procStem({'future_field': 'x'})),
        ]),
      );
      expect(m.maxLayers, 4);
      expect(m.stems, hasLength(1));
    });

    test('a wrong version or shape throws', () {
      expect(
        () => StemManifest.parse(doc([entry(procStem())], version: 2)),
        throwsFormatException,
      );
      expect(() => StemManifest.parse('[]'), throwsFormatException);
      expect(
        () => StemManifest.parse('{"version": 1}'),
        throwsFormatException,
      );
      expect(() => StemManifest.parse('not json'), throwsFormatException);
    });

    test('bad entries are skipped, the rest survive', () {
      final bad = [
        fileStem({'id': 'no_sha', 'sha256': null}),
        fileStem({'id': 'short_sha', 'sha256': 'abc'}),
        fileStem({'id': 'upper_sha', 'sha256': 'C' * 64}),
        fileStem({'id': 'no_bytes', 'bytes': null}),
        fileStem({'id': 'zero_bytes', 'bytes': 0}),
        fileStem({'id': 'no_licence', 'licence': null}),
        fileStem({'id': 'escape', 'file': '../secrets.m4a'}),
        fileStem({'id': 'absolute', 'file': '/etc/rain.m4a'}),
        fileStem({'id': 'bad_tier', 'tier': 'gold'}),
        fileStem({'id': 'bad_status', 'status': 'maybe'}),
        fileStem({'id': 'bad_fallback', 'fallback_generator': 'binaural'}),
        procStem({'id': 'bad_generator', 'generator': 'binaural'}),
        procStem({'id': 'Bad Id'}),
        procStem({'id': 'no_title', 'title_key': ''}),
      ];
      final m = StemManifest.parse(
        doc([
          for (final b in bad) entry(b),
          entry(procStem()),
          entry(procStem({'title_key': 'sounds_stemPinkNoise'})), // dup id
        ]),
      );
      expect([for (final s in m.stems) s.id], ['brown_noise']);
      expect(m.byId('brown_noise')!.titleKey, 'sounds_stemBrownNoise');
    });

    test('a pending recording needs no size or hash, and is hidden unless '
        'it has a generated stand-in', () {
      final m = StemManifest.parse(
        doc([
          entry(
            fileStem({
              'id': 'stream',
              'status': 'pending_sourcing',
              'bytes': null,
              'sha256': null,
              'licence': null,
            }),
          ),
          entry(
            fileStem({
              'id': 'rain',
              'status': 'pending_sourcing',
              'bytes': null,
              'sha256': null,
              'licence': null,
              'fallback_generator': 'rain',
            }),
          ),
        ]),
      );
      expect(m.byId('stream')!.listed, isFalse);
      expect(m.byId('rain')!.listed, isTrue);
      expect(m.byId('rain')!.generatedSource, StemGenerator.rain);
      expect([for (final s in m.listed) s.id], ['rain']);
    });
  });
}
