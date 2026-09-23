import 'dart:io';
import 'dart:typed_data';

import 'package:aura/src/core/net/api_models.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/security/note_cipher.dart';
import 'package:aura/src/features/voice/voice_loader.dart';
import 'package:aura/src/features/voice/voice_store.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// Playback sources (F1): this phone's copy, or the server's object fetched
/// lazily (download-url → GET → decrypt → temp file).
class _Api extends AuraApi {
  _Api(this.sealed)
    : super(baseUrl: 'http://test', accessToken: () async => 't');

  final Uint8List sealed;
  final List<String> calls = [];
  ApiException? fail;

  @override
  Future<MediaDownloadUrl> mediaDownloadUrl(String path) async {
    calls.add('download-url $path');
    final e = fail;
    if (e != null) throw e;
    return const MediaDownloadUrl(downloadUrl: 'http://127.0.0.1:55521/dl?t=1');
  }

  @override
  Future<Uint8List> getMedia(String downloadUrl) async {
    calls.add('get');
    return sealed;
  }
}

void main() {
  late Directory root;
  late VoiceStore store;
  final cipher = NoteCipher(SecretKey(List<int>.generate(32, (i) => i)));
  const id = '0199aaaa-0000-7000-8000-000000000001';
  final audio = Uint8List.fromList(List<int>.generate(500, (i) => i % 200));

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aura-voice-loader');
    store = VoiceStore(
      root: () async => root,
      temp: () async => Directory('${root.path}/tmp'),
    );
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  VoiceLoader loader({AuraApi? api, bool online = true, NoteCipher? key}) =>
      VoiceLoader(
        store: store,
        api: api,
        cipher: ({bool fetch = false}) async => key ?? cipher,
        online: () => online,
      );

  Future<String> stored(List<int> bytes, String name) async {
    await store.newDraftPath(); // creates the directories
    File('${root.path}/voice/$name').writeAsBytesSync(bytes);
    return name;
  }

  test('a raw local recording plays as it is (no copy)', () async {
    final name = await stored(audio, 'rec.m4a');
    final s = await loader().load(checkInId: id, file: name);
    expect(s.path, '${root.path}/voice/rec.m4a');
    expect(s.isTemp, isFalse);
  });

  test('a sealed local copy is decrypted into a temp file', () async {
    final name = await stored(
      await cipher.encryptBytes(audio, recordId: id),
      'rec.enc',
    );
    final s = await loader().load(checkInId: id, file: name, path: 'u/voice/x');
    expect(s.isTemp, isTrue);
    expect(File(s.path).readAsBytesSync(), audio);
    await store.deleteTemp(s.path);
    expect(File(s.path).existsSync(), isFalse);
  });

  test('only on the server: download-url → GET → decrypt → temp', () async {
    final api = _Api(await cipher.encryptBytes(audio, recordId: id));
    final s = await loader(api: api).load(checkInId: id, path: 'u/voice/x');
    expect(api.calls, ['download-url u/voice/x', 'get']);
    expect(s.isTemp, isTrue);
    expect(File(s.path).readAsBytesSync(), audio);
  });

  test('offline (or a network error) → "plays when you are back online"; '
      'other failures → failed', () async {
    final api = _Api(Uint8List(0));
    await expectLater(
      loader(api: api, online: false).load(checkInId: id, path: 'u/voice/x'),
      throwsA(
        isA<VoiceUnavailable>().having((e) => e.offline, 'offline', true),
      ),
    );
    expect(api.calls, isEmpty);
    api.fail = const ApiException(code: 'connectionError', isNetwork: true);
    await expectLater(
      loader(api: api).load(checkInId: id, path: 'u/voice/x'),
      throwsA(
        isA<VoiceUnavailable>().having((e) => e.offline, 'offline', true),
      ),
    );
    api.fail = const ApiException(code: 'not_found', status: 404);
    await expectLater(
      loader(api: api).load(checkInId: id, path: 'u/voice/x'),
      throwsA(
        isA<VoiceUnavailable>().having((e) => e.offline, 'offline', false),
      ),
    );
  });

  test('another check-in id or key cannot open it', () async {
    final api = _Api(await cipher.encryptBytes(audio, recordId: 'other'));
    await expectLater(
      loader(api: api).load(checkInId: id, path: 'u/voice/x'),
      throwsA(isA<VoiceUnavailable>()),
    );
  });
}
