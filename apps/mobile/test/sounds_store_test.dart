import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aura/src/features/sanctuary/sounds/procedural_synth.dart';
import 'package:aura/src/features/sanctuary/sounds/stem_manifest.dart';
import 'package:aura/src/features/sanctuary/sounds/stem_store.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Sounds cache: downloads verified by size and SHA-256, generated
/// stems rendered once (PRD 16-offline "Full after one download").
class _Fetcher implements StemFetcher {
  _Fetcher(this.body);

  /// What the "server" sends, or an error to throw.
  Object body;
  final List<Uri> urls = [];

  @override
  Future<void> fetch(
    Uri url,
    File dest, {
    void Function(int received, int total)? onProgress,
  }) async {
    urls.add(url);
    final b = body;
    if (b is List<int>) {
      await dest.writeAsBytes(b);
      onProgress?.call(b.length, b.length);
      return;
    }
    throw b;
  }
}

Future<String> _sha(List<int> bytes) async {
  final h = await Sha256().hash(bytes);
  return [for (final v in h.bytes) v.toRadixString(16).padLeft(2, '0')].join();
}

Stem _stem(String sha, int bytes) => StemManifest.parse(
  jsonEncode({
    'version': 1,
    'stems': [
      {
        'id': 'rain',
        'title_key': 'sounds_stemRain',
        'tier': 'free',
        'role': 'bed',
        'kind': 'file',
        'file': 'base/rain.v1.m4a',
        'bytes': bytes,
        'sha256': sha,
        'licence': 'CC0-1.0',
        'status': 'available',
        'fallback_generator': 'rain',
      },
    ],
  }),
).byId('rain')!;

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('aura_sounds_'));
  tearDown(() => root.deleteSync(recursive: true));

  final audio = utf8.encode('pretend this is an m4a loop');

  StemStore store(_Fetcher f, {String base = 'https://cdn.example/sounds'}) =>
      StemStore(
        root: () async => root,
        fetcher: f,
        baseUrl: base,
        render: (g) async => Uint8List.fromList(List.filled(100, 1)),
      );

  group('sha256Matches', () {
    test('matches the known digest of "abc"', () async {
      final f = File('${root.path}/abc')..writeAsStringSync('abc');
      const digest =
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
      expect(await sha256Matches(f, digest), isTrue);
      expect(await sha256Matches(f, digest.toUpperCase()), isTrue);
      expect(await sha256Matches(f, 'f' * 64), isFalse);
    });
  });

  group('download', () {
    test('verified once, then played from the cache (offline after)', () async {
      final stem = _stem(await _sha(audio), audio.length);
      final f = _Fetcher(audio);
      final s = store(f);
      expect(await s.isDownloaded(stem), isFalse);
      // Before the download the generated stand-in plays.
      expect(await s.playablePath(stem), contains('/gen/rain.'));

      await s.download(stem);
      expect(f.urls.single.toString(), 'https://cdn.example/sounds/base/rain.v1.m4a');
      expect(await s.isDownloaded(stem), isTrue);
      final path = (await s.playablePath(stem))!;
      expect(path, contains('/rec/rain.'));
      expect(File(path).readAsBytesSync(), audio);

      // A second call downloads nothing.
      f.body = StateError('no network');
      await s.download(stem);
      expect(f.urls, hasLength(1));
      expect(await s.downloadedIds([stem]), {'rain'});
    });

    test('a wrong hash is rejected and deleted', () async {
      final stem = _stem('0' * 64, audio.length);
      final s = store(_Fetcher(audio));
      await expectLater(
        s.download(stem),
        throwsA(
          isA<StemDownloadException>().having(
            (e) => e.error,
            'error',
            StemDownloadError.integrity,
          ),
        ),
      );
      expect(await s.isDownloaded(stem), isFalse);
      final rec = Directory('${root.path}/rec');
      expect(rec.listSync(), isEmpty); // no .part left behind
    });

    test('a wrong size is rejected', () async {
      final stem = _stem(await _sha(audio), audio.length + 1);
      final s = store(_Fetcher(audio));
      await expectLater(
        s.download(stem),
        throwsA(
          isA<StemDownloadException>().having(
            (e) => e.error,
            'error',
            StemDownloadError.integrity,
          ),
        ),
      );
    });

    test('a full phone is "no space" (PRD: Storage full)', () async {
      final stem = _stem(await _sha(audio), audio.length);
      final s = store(
        _Fetcher(
          const FileSystemException(
            'write failed',
            'x',
            OSError('No space left on device', 28),
          ),
        ),
      );
      await expectLater(
        s.download(stem),
        throwsA(
          isA<StemDownloadException>().having(
            (e) => e.error,
            'error',
            StemDownloadError.noSpace,
          ),
        ),
      );
    });

    test('offline stays offline; no base URL is "unavailable"', () async {
      final stem = _stem(await _sha(audio), audio.length);
      await expectLater(
        store(
          _Fetcher(const StemDownloadException(StemDownloadError.offline)),
        ).download(stem),
        throwsA(
          isA<StemDownloadException>().having(
            (e) => e.error,
            'error',
            StemDownloadError.offline,
          ),
        ),
      );
      await expectLater(
        store(_Fetcher(audio), base: '').download(stem),
        throwsA(
          isA<StemDownloadException>().having(
            (e) => e.error,
            'error',
            StemDownloadError.unavailable,
          ),
        ),
      );
    });

    test('"Remove downloaded sounds" deletes recordings, keeps generated '
        'ones', () async {
      final stem = _stem(await _sha(audio), audio.length);
      final s = store(_Fetcher(audio));
      await s.download(stem);
      final generated = await s.generatedPath(StemGenerator.brownNoise);
      await s.removeDownloads();
      expect(await s.isDownloaded(stem), isFalse);
      expect(File(generated).existsSync(), isTrue);
      expect(await s.playablePath(stem), contains('/gen/rain.'));
    });
  });

  group('generated stems', () {
    test('rendered once, then reused from the cache', () async {
      var renders = 0;
      final s = StemStore(
        root: () async => root,
        fetcher: _Fetcher(audio),
        render: (g) async {
          renders++;
          return Uint8List.fromList(List.filled(200, 7));
        },
      );
      final results = await Future.wait([
        s.generatedPath(StemGenerator.chimes),
        s.generatedPath(StemGenerator.chimes),
      ]);
      expect(results[0], results[1]);
      expect(renders, 1);
      expect(await s.generatedPath(StemGenerator.chimes), results[0]);
      expect(renders, 1);
      expect(results[0], endsWith('chimes.v$proceduralVersion.16000.wav'));
    });
  });
}
