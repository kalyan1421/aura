import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/net/api_models.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/security/note_cipher.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/core/sync/media_sync.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/sync/sync_service.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/profile/profile_service.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:aura/src/features/voice/voice_store.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _key = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8='; // 32 bytes
const _user = 'user-1';

class _Auth implements AuthRepository {
  AuthUser? user = const AuthUser(id: _user, email: 'a@b.c');
  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> watchUser() => Stream.value(user);
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<void> sendEmailCode(String email) async {}
  @override
  Future<void> verifyEmailCode(String email, String code) async {}
  @override
  Future<void> signOut() async {}
}

/// The API and Storage as the contract describes them, recording every call
/// in order.
class _Api extends AuraApi {
  _Api() : super(baseUrl: 'http://test', accessToken: () async => 't');

  final List<String> log = [];
  final List<List<SyncMutation>> pushes = [];
  final Map<String, Uint8List> objects = {};
  final Map<String, int> declared = {};

  /// Next upload-url calls fail with these (then succeed).
  final List<ApiException> uploadUrlErrors = [];
  bool failPut = false;
  bool noKey = false;

  @override
  Future<ProfileResult> postProfile(ProfileRequest body) async =>
      const ProfileSaved(null);

  @override
  Future<DataKeyResponse> dataKey() async {
    if (noKey) {
      throw const ApiException(code: 'connectionError', isNetwork: true);
    }
    return const DataKeyResponse(keyId: 'k1', dataKey: _key);
  }

  @override
  Future<MediaUploadUrl> mediaUploadUrl({
    required String recordId,
    required int bytes,
    String kind = 'voice',
  }) async {
    log.add('upload-url');
    if (uploadUrlErrors.isNotEmpty) throw uploadUrlErrors.removeAt(0);
    final path = '$_user/voice/${recordId.toLowerCase()}';
    declared[path] = bytes;
    return MediaUploadUrl(
      path: path,
      uploadUrl:
          'http://127.0.0.1:55521/storage/v1/object/upload/sign/'
          'private-media/$path?token=t',
    );
  }

  @override
  Future<void> putMedia(String uploadUrl, Uint8List ciphertext) async {
    log.add('put');
    if (failPut) throw const ApiException(code: 'http_400', status: 400);
    final path = Uri.parse(uploadUrl).path.split('private-media/').last;
    expect(ciphertext.length, declared[path]); // never more than declared
    objects[path] = ciphertext;
  }

  @override
  Future<PushResponse> push({
    required String deviceId,
    required List<SyncMutation> mutations,
  }) async {
    log.add('push');
    pushes.add(mutations);
    return PushResponse(
      results: [
        for (final m in mutations) MutationResult(id: m.id, status: 'applied'),
      ],
    );
  }

  @override
  Future<Snapshot> snapshot() =>
      throw const ApiException(code: 'x', status: 500);
}

void main() {
  late Directory root;
  late AppDatabase db;
  late KvStore kv;
  late OutboxRepository outbox;
  late VoiceStore store;
  late CheckInRepository checkIns;
  late _Api api;
  late _Auth auth;
  late SyncService sync;
  late StreamController<bool> online;
  late MemorySecureStore secure;
  var held = 0;
  final time = testTime();
  final audio = Uint8List.fromList(List<int>.generate(3000, (i) => i % 256));

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aura-voice-sync');
    db = memoryDb();
    kv = KvStore(db);
    outbox = OutboxRepository(db, const Ids());
    store = VoiceStore(
      root: () async => root,
      temp: () async => Directory('${root.path}/tmp'),
    );
    checkIns = CheckInRepository(db, outbox, time, voice: store);
    api = _Api();
    auth = _Auth();
    online = StreamController<bool>();
    secure = MemorySecureStore();
    held = 0;
    final progress = ProgressRepository(db, kv);
    sync = SyncService(
      auth: auth,
      api: api,
      outbox: outbox,
      checkIns: checkIns,
      profile: ProfileService(
        kv: kv,
        timezone: () => time.timezone,
        progress: progress,
        country: () => 'IN',
      ),
      progress: progress,
      dataKeys: DataKeyRepository(secure),
      kv: kv,
      clock: time.clock,
      ids: const Ids(),
      connectivity: online.stream,
      pull: (_, _) async {},
      alreadyPulled: (_) async => true,
      onUnder13: () async {},
      onDeletionPending: () => held++,
      media: MediaSync(db: db, checkIns: checkIns, store: store),
    );
  });

  tearDown(() async {
    await sync.dispose();
    unawaited(online.close());
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<String> saveWithVoice({String mood = 'calm'}) async {
    final path = await store.newDraftPath();
    await File(path).writeAsBytes(audio);
    final id = const Ids().v7();
    await checkIns.save(
      id: id,
      mood: moodById(mood)!,
      voice: VoiceClip(path: path, duration: const Duration(seconds: 9)),
    );
    return id;
  }

  Future<CheckInRow> rowOf(String id) =>
      (db.select(db.checkIns)..where((t) => t.id.equals(id))).getSingle();

  Future<List<OutboxRow>> queued() =>
      (db.select(db.outbox)..orderBy([(t) => OrderingTerm.asc(t.seq)])).get();

  Future<NoteCipher> key() async =>
      (await DataKeyRepository(secure).cipherFor(_user))!;

  test(
    'a voice check-in is pushed only after its upload: upload-url → PUT '
    '→ push with the returned path; only ciphertext leaves the phone',
    () async {
      final id = await saveWithVoice();
      await sync.kick();

      expect(api.log, ['upload-url', 'put', 'push']);
      final path = '$_user/voice/$id';
      final m = api.pushes.single.single;
      expect(m.payload['voicePath'], path);
      // The object is the sealed recording, bound to the check-in id.
      final object = api.objects[path]!;
      expect(object, isNot(audio));
      expect(await (await key()).decryptBytes(object, recordId: id), audio);
      final row = await rowOf(id);
      expect(row.voicePath, path);
      expect(VoiceStore.isSealed(row.voiceFile!), isTrue); // sealed at rest
      expect(await outbox.count(), 0);
    },
  );

  test('503 media_unavailable: the check-in waits (backoff), other records '
      'still go; the next attempt uploads and pushes', () async {
    final id = await saveWithVoice();
    final plain = const Ids().v7();
    await checkIns.save(id: plain, mood: moodById('joyful')!);
    api.uploadUrlErrors.add(
      const ApiException(code: 'media_unavailable', status: 503),
    );

    await sync.kick();
    expect(api.pushes.single.map((m) => m.payload['id']), [plain]);
    final waiting = (await queued()).single;
    expect(waiting.entityId, id);
    expect(waiting.mediaAttempts, 1);
    expect(waiting.needsMedia, isTrue);
    expect(waiting.nextAttemptAt, isNotNull);

    await sync.syncNow(); // backoff cleared
    expect(api.log, ['upload-url', 'push', 'upload-url', 'put', 'push']);
    expect(api.pushes.last.single.payload['voicePath'], '$_user/voice/$id');
  });

  test('after the max media attempts the check-in goes without voicePath and '
      'the recording stays on the phone', () async {
    final id = await saveWithVoice();
    final row = (await queued()).single;
    await (db.update(db.outbox)..where((t) => t.seq.equals(row.seq))).write(
      const OutboxCompanion(
        mediaAttempts: Value(OutboxRepository.maxAttempts - 1),
      ),
    );
    api.uploadUrlErrors.add(
      const ApiException(code: 'connectionError', isNetwork: true),
    );

    await sync.kick();

    final m = api.pushes.single.single;
    expect(m.payload['id'], id);
    expect(m.payload.containsKey('voicePath'), isFalse); // never blocked
    expect(await outbox.count(), 0);
    final after = await rowOf(id);
    expect(after.voiceFile, isNotNull);
    expect(after.voicePath, isNull);
    expect(File('${root.path}/voice/${after.voiceFile}').existsSync(), isTrue);

    // A later edit attaches it.
    await checkIns.edit(id: id, mood: moodById('joyful')!);
    await sync.kick();
    expect(api.pushes.last.single.payload['voicePath'], '$_user/voice/$id');
  });

  test('a PUT that fails is retried with a fresh URL', () async {
    final id = await saveWithVoice();
    api.failPut = true;
    await sync.kick();
    expect(api.pushes, isEmpty);
    api.failPut = false;
    await sync.syncNow();
    expect(api.log, ['upload-url', 'put', 'upload-url', 'put', 'push']);
    expect(api.pushes.single.single.payload['voicePath'], '$_user/voice/$id');
  });

  test('no data key yet: the raw recording waits, nothing is uploaded or '
      'pushed; once the key arrives it is sealed and sent', () async {
    final id = await saveWithVoice();
    api.noKey = true;
    await sync.kick();
    expect(api.log, isEmpty);
    expect(VoiceStore.isSealed((await rowOf(id)).voiceFile!), isFalse);

    api.noKey = false;
    await sync.kick();
    expect(api.log, ['upload-url', 'put', 'push']);
    expect(VoiceStore.isSealed((await rowOf(id)).voiceFile!), isTrue);
  });

  test('edit remove → voicePath null; an upload for a re-added recording '
      'happens only after that push', () async {
    final id = await saveWithVoice();
    await sync.kick();
    api.log.clear();

    await checkIns.edit(id: id, mood: moodById('calm')!, removeVoice: true);
    final path = await store.newDraftPath();
    await File(path).writeAsBytes([5, 6, 7]);
    await checkIns.edit(
      id: id,
      mood: moodById('calm')!,
      voice: VoiceClip(path: path, duration: const Duration(seconds: 1)),
    );
    await sync.kick();

    expect(api.log, ['push', 'upload-url', 'put', 'push']);
    final cleared = api.pushes[1].single.payload;
    expect(cleared.containsKey('voicePath'), isTrue);
    expect(cleared['voicePath'], isNull);
    expect(api.pushes[2].single.payload['voicePath'], '$_user/voice/$id');
  });

  test('a record waits for its earlier mutation that is backing off', () async {
    final id = await saveWithVoice();
    api.uploadUrlErrors.add(
      const ApiException(code: 'media_unavailable', status: 503),
    );
    await sync.kick(); // the insert backs off
    await checkIns.delete(id); // delete queued after it
    await sync.kick();
    expect(api.pushes, isEmpty); // the delete never overtakes the insert
    expect(await outbox.count(), 2);
  });

  test(
    '403 account_deletion_pending on upload-url holds sync like a push',
    () async {
      await saveWithVoice();
      api.uploadUrlErrors.add(
        const ApiException(code: ApiException.deletionPendingCode, status: 403),
      );
      await sync.kick();
      expect(held, 1);
      expect(sync.isHeldForDeletion, isTrue);
      expect(api.pushes, isEmpty);
      final row = (await queued()).single;
      expect(row.mediaAttempts, 0); // no backoff, nothing dropped
      await sync.kick();
      expect(api.log, ['upload-url']); // nothing more until released
    },
  );

  test('deleting a voice check-in before it synced removes the file; the '
      'insert goes without voicePath, then the delete', () async {
    final id = await saveWithVoice();
    final file = (await rowOf(id)).voiceFile!;
    await checkIns.delete(id);
    expect(File('${root.path}/voice/$file').existsSync(), isFalse);
    await sync.kick();
    expect(api.log, ['push']);
    final ops = api.pushes.single.map((m) => m.op).toList();
    expect(ops, [Ops.upsert, Ops.delete]);
    expect(api.pushes.single.first.payload.containsKey('voicePath'), isFalse);
  });

  test('a sign-out during the upload writes nothing afterwards', () async {
    final id = await saveWithVoice();
    final gate = Completer<void>();
    final slow = _SlowPutApi(gate.future);
    final media = MediaSync(db: db, checkIns: checkIns, store: store);
    final step = media.prepare(
      (await queued()).single,
      api: slow,
      cipher: await DataKeyRepository(
        MemorySecureStore({
          SecureKeys.dataKey(_user): jsonEncode({
            'keyId': 'k',
            'dataKey': _key,
          }),
        }),
      ).cipherFor(_user),
      isCurrent: () => auth.user != null,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    auth.user = null; // signed out meanwhile
    gate.complete();
    expect((await step).kind, MediaStepKind.abort);
    expect((await rowOf(id)).voicePath, isNull);
  });

  test('signed Storage URLs: loopback hosts take this build\'s Supabase '
      'host (Android emulator); real hosts are never touched', () {
    const signed =
        'http://127.0.0.1:55521/storage/v1/object/upload/sign/private-media/'
        'u/voice/x?token=abc';
    expect(
      mediaUrlFor(signed, supabaseUrl: 'http://10.0.2.2:55521').toString(),
      'http://10.0.2.2:55521/storage/v1/object/upload/sign/private-media/'
      'u/voice/x?token=abc',
    );
    expect(
      mediaUrlFor(signed, supabaseUrl: 'http://127.0.0.1:55521').toString(),
      signed,
    );
    const real = 'https://abc.supabase.co/storage/v1/object/sign/x?token=1';
    expect(
      mediaUrlFor(real, supabaseUrl: 'http://10.0.2.2:55521').toString(),
      real,
    );
    expect(mediaUrlFor(signed).toString(), signed);
  });

  test('the PUT carries the raw ciphertext as octet-stream, no auth header, '
      'on this build\'s Supabase host', () async {
    final capture = _Capture();
    final media = Dio()..httpClientAdapter = capture;
    final real = AuraApi(
      baseUrl: 'http://api.test',
      accessToken: () async => 'user-jwt',
      mediaDio: media,
      supabaseUrl: 'http://10.0.2.2:55521',
    );
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    await real.putMedia(
      'http://127.0.0.1:55521/storage/v1/object/upload/sign/private-media/'
      'u/voice/x?token=abc',
      bytes,
    );
    final r = capture.requests.single;
    expect(r.method, 'PUT');
    expect(r.uri.host, '10.0.2.2');
    expect(r.uri.queryParameters['token'], 'abc');
    expect(r.contentType, 'application/octet-stream');
    expect(
      r.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
    );
    expect(
      r.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('apikey')),
    );
    expect(capture.bodies.single, bytes);

    await real.getMedia('http://127.0.0.1:55521/storage/v1/object/sign/x?t=1');
    expect(capture.requests.last.method, 'GET');
    expect(capture.requests.last.uri.host, '10.0.2.2');
    expect(
      capture.requests.last.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
    );
  });

  test(
    'media_too_large is not retried: the check-in goes without voice',
    () async {
      final id = await saveWithVoice();
      api.uploadUrlErrors.add(
        const ApiException(code: 'media_too_large', status: 400),
      );
      await sync.kick();
      expect(api.log, ['upload-url', 'push']);
      expect(
        api.pushes.single.single.payload.containsKey('voicePath'),
        isFalse,
      );
      expect((await rowOf(id)).voiceFile, isNotNull); // kept on the phone
    },
  );
}

/// Captures what the real [AuraApi] sends to Storage.
class _Capture implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<List<int>> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        body.addAll(chunk);
      }
    }
    bodies.add(body);
    return ResponseBody.fromString(
      options.method == 'PUT' ? '{"Key":"private-media/x"}' : 'sealed',
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SlowPutApi extends _Api {
  _SlowPutApi(this.release);

  final Future<void> release;

  @override
  Future<void> putMedia(String uploadUrl, Uint8List ciphertext) async {
    await release;
    await super.putMedia(uploadUrl, ciphertext);
  }
}
