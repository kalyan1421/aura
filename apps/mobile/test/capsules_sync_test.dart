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
import 'package:aura/src/core/sync/capsule_media_sync.dart';
import 'package:aura/src/core/sync/capsule_sync.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/sync/sync_service.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/capsules/capsule_media_store.dart';
import 'package:aura/src/features/capsules/capsule_payload.dart';
import 'package:aura/src/features/capsules/capsule_repository.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/profile/profile_service.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'capsules_fakes.dart';
import 'helpers.dart';

/// The API and Storage as contracts/api/v1-capsules.md describes them,
/// recording every call in order.
class _Api extends AuraApi {
  _Api() : super(baseUrl: 'http://test', accessToken: () async => 't');

  final List<String> log = [];
  final List<SyncMutation> pushed = [];
  final Map<String, Uint8List> objects = {};
  final Map<String, int> declared = {};

  /// Next upload-url calls fail with these (then succeed).
  final List<ApiException> uploadUrlErrors = [];
  bool failUploads = false;
  bool noKey = false;

  /// `op` → rejection reason for the next matching mutation.
  final Map<String, String> reject = {};

  @override
  Future<ProfileResult> postProfile(ProfileRequest body) async =>
      const ProfileSaved(null);

  @override
  Future<DataKeyResponse> dataKey() async {
    log.add('data-key');
    if (noKey) {
      throw const ApiException(code: 'connectionError', isNetwork: true);
    }
    return const DataKeyResponse(keyId: 'k1', dataKey: capsuleTestKey);
  }

  @override
  Future<MediaUploadUrl> capsuleMediaUploadUrl({
    required String capsuleId,
    required String kind,
    required int bytes,
    int? index,
  }) async {
    log.add('upload-url $kind${index == null ? '' : ' $index'}');
    if (failUploads) {
      throw const ApiException(code: 'media_unavailable', status: 503);
    }
    if (uploadUrlErrors.isNotEmpty) throw uploadUrlErrors.removeAt(0);
    expect(kind == 'capsule_photo', index != null);
    final slot = kind == 'capsule_voice' ? 'voice' : 'photo-$index';
    final path = '$capsuleTestUser/capsules/${capsuleId.toLowerCase()}/$slot';
    declared[path] = bytes;
    return MediaUploadUrl(
      path: path,
      uploadUrl: 'http://127.0.0.1:55521/upload/private-media/$path?token=t',
    );
  }

  @override
  Future<void> putMedia(String uploadUrl, Uint8List ciphertext) async {
    log.add('put');
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
    pushed.addAll(mutations);
    return PushResponse(
      results: [
        for (final m in mutations)
          if (reject.remove(m.op) case final reason?)
            MutationResult(id: m.id, status: 'rejected', reason: reason)
          else
            MutationResult(id: m.id, status: 'applied'),
      ],
    );
  }

  @override
  Future<Snapshot> snapshot() =>
      throw const ApiException(code: 'x', status: 500);
}

/// `public.capsules` as select-own returns it.
class _Rows implements CapsuleRowSource {
  final List<Map<String, dynamic>> rows = [];
  final List<DateTime?> sinces = [];
  final List<List<String>> fetchedIds = [];

  @override
  Future<List<Map<String, dynamic>>> changedSince(
    DateTime? since, {
    required int from,
    required int to,
  }) async {
    sinces.add(since);
    final out =
        rows
            .where(
              (r) =>
                  since == null ||
                  !DateTime.parse(r['updated_at'] as String).isBefore(since),
            )
            .toList()
          ..sort(
            (a, b) =>
                (a['updated_at'] as String).compareTo(b['updated_at'] as String),
          );
    return out.skip(from).take(to - from + 1).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> byIds(List<String> ids) async {
    fetchedIds.add(ids);
    return rows.where((r) => ids.contains(r['id'])).toList();
  }
}

Map<String, dynamic> _server(
  String id, {
  String unlockType = 'date',
  String? unlockLocalDate = '2027-10-08',
  String? triggerMoodId,
  String? payloadCt = 'AAAA',
  String sealedAt = '2026-10-01T10:00:00+00:00',
  String? armedAt,
  int cycle = 0,
  String? firedAt,
  String? cooldownUntil,
  String? openedAt,
  String? deletedAt,
  required String updatedAt,
}) => {
  'id': id,
  'user_id': capsuleTestUser,
  'unlock_type': unlockType,
  'unlock_local_date': unlockLocalDate,
  'trigger_mood_id': triggerMoodId,
  'trigger_quadrant': null,
  'payload_ct': payloadCt,
  'sealed_at': sealedAt,
  'armed_at': armedAt,
  'cycle': cycle,
  'fired_at': firedAt,
  'cooldown_until': cooldownUntil,
  'opened_at': openedAt,
  'opened_device_ts': openedAt,
  'deleted_at': deletedAt,
  'server_ts': sealedAt,
  'updated_at': updatedAt,
};

void main() {
  late Directory root;
  late AppDatabase db;
  late KvStore kv;
  late OutboxRepository outbox;
  late CapsuleMediaStore store;
  late CapsuleRepository capsules;
  late CapsuleSync capsuleSync;
  late _Api api;
  late _Rows rows;
  late SignedInAuth auth;
  late SyncService sync;
  late StreamController<bool> online;
  late MemorySecureStore secure;
  late FixedClock clock;
  NoteCipher? repoKey;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aura-capsules-sync');
    db = memoryDb();
    kv = KvStore(db);
    outbox = OutboxRepository(db, const Ids());
    store = tempCapsuleStore(root);
    clock = FixedClock(testNow);
    final time = TimeContext(clock: clock, timezone: 'Asia/Kolkata');
    repoKey = testCipher();
    capsules = CapsuleRepository(
      db,
      outbox,
      time,
      store: store,
      cipher: () async => repoKey,
    );
    rows = _Rows();
    capsuleSync = CapsuleSync(
      db: db,
      outbox: outbox,
      kv: kv,
      capsules: capsules,
      media: CapsuleMediaSync(db: db, store: store),
      store: store,
      rows: rows,
      clock: clock,
    );
    api = _Api();
    auth = SignedInAuth();
    online = StreamController<bool>();
    secure = MemorySecureStore();
    final progress = ProgressRepository(db, kv);
    sync = SyncService(
      auth: auth,
      api: api,
      outbox: outbox,
      checkIns: CheckInRepository(db, outbox, time),
      profile: ProfileService(
        kv: kv,
        timezone: () => time.timezone,
        progress: progress,
        country: () => 'IN',
      ),
      progress: progress,
      dataKeys: DataKeyRepository(secure),
      kv: kv,
      clock: clock,
      ids: const Ids(),
      connectivity: online.stream,
      pull: (_, _) async {},
      alreadyPulled: (_) async => true,
      onUnder13: () async {},
      capsules: capsuleSync,
    );
  });

  tearDown(() async {
    await sync.dispose();
    unawaited(online.close());
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<CapsuleRow> rowOf(String id) async => (await capsules.row(id))!;

  List<SyncMutation> capsuleOps() =>
      api.pushed.where((m) => m.entity == Entities.capsule).toList();

  group('push', () {
    test('a seal carries its ciphertext, deviceTs and tz; then synced', () async {
      await capsules.seal(
        id: 'c1',
        content: const CapsuleContent(title: 'hi', text: 'there'),
        unlock: DateUnlock(LocalDay.parse('2027-10-08')),
      );
      await sync.kick();
      final seal = capsuleOps().single;
      expect(seal.op, Ops.seal);
      expect(seal.tz, 'Asia/Kolkata');
      expect(DateTime.parse(seal.deviceTs), testNow);
      final row = await rowOf('c1');
      expect(seal.payload, {
        'id': 'c1',
        'payloadCt': row.payloadCt,
        'unlockType': 'date',
        'unlockLocalDate': '2027-10-08',
      });
      expect(jsonEncode(seal.payload), isNot(contains('there')));
      expect(row.synced, isTrue);
      expect(await outbox.count(), 0);
    });

    test('a capsule sealed before the key arrived is sealed at push', () async {
      repoKey = null;
      await capsules.seal(
        id: 'c2',
        content: const CapsuleContent(text: 'no key yet'),
        unlock: DateUnlock(LocalDay.parse('2027-10-08')),
      );
      api.noKey = true;
      await sync.kick();
      expect(capsuleOps(), isEmpty, reason: 'never sends plaintext');
      expect((await rowOf('c2')).payloadClear, isNotNull);

      api.noKey = false;
      await sync.kick();
      final row = await rowOf('c2');
      expect(row.payloadClear, isNull);
      expect(capsuleOps().single.payload['payloadCt'], row.payloadCt);
      final clear = await testCipher().decrypt(row.payloadCt!, recordId: 'c2');
      expect(CapsulePayload.decode(clear).text, 'no key yet');
    });

    test('media upload first (kind, index, exact bytes), then the seal', () async {
      final voice = await store.newDraftVoicePath('d');
      await File(voice).writeAsBytes(List.generate(700, (i) => i % 256));
      final photo = await store.writeDraftPhoto('d', Uint8List(300)..[1] = 9);
      await capsules.seal(
        id: 'c3',
        content: CapsuleContent(
          text: 'x',
          voice: CapsuleVoiceDraft(path: voice, duration: const Duration(seconds: 5)),
          photos: [CapsulePhotoDraft(path: photo, width: 10, height: 10)],
        ),
        unlock: DateUnlock(LocalDay.parse('2027-10-08')),
      );
      await sync.kick();
      expect(api.log.where((e) => e != 'data-key'), [
        'upload-url capsule_photo 0',
        'put',
        'upload-url capsule_voice',
        'put',
        'push',
      ]);
      final voicePath = '$capsuleTestUser/capsules/c3/voice';
      final clear = await testCipher().decryptBytes(
        api.objects[voicePath]!,
        recordId: 'c3/voice',
      );
      expect(clear, List.generate(700, (i) => i % 256));
      final media = await capsules.mediaOf('c3');
      expect(media.map((m) => m.path), [
        '$capsuleTestUser/capsules/c3/photo-0',
        voicePath,
      ]);
    });

    test('409 capsule_sealed on a slot means it is already uploaded', () async {
      final photo = await store.writeDraftPhoto('d', Uint8List(40)..[0] = 1);
      await capsules.seal(
        id: 'c4',
        content: CapsuleContent(
          photos: [CapsulePhotoDraft(path: photo, width: 1, height: 1)],
        ),
        unlock: DateUnlock(LocalDay.parse('2027-10-08')),
      );
      api.uploadUrlErrors.add(
        const ApiException(code: 'capsule_sealed', status: 409),
      );
      await sync.kick();
      expect(
        (await capsules.mediaOf('c4')).single.path,
        '$capsuleTestUser/capsules/c4/photo-0',
      );
      expect(capsuleOps().single.op, Ops.seal);
    });

    test('uploads that keep failing: the seal goes, uploads retry later', () async {
      final photo = await store.writeDraftPhoto('d', Uint8List(40)..[0] = 1);
      await capsules.seal(
        id: 'c5',
        content: CapsuleContent(
          text: 'x',
          photos: [CapsulePhotoDraft(path: photo, width: 1, height: 1)],
        ),
        unlock: DateUnlock(LocalDay.parse('2027-10-08')),
      );
      api.failUploads = true;
      for (var i = 0; i < OutboxRepository.maxAttempts; i++) {
        await sync.kick();
        clock.instant = clock.instant.add(const Duration(hours: 2));
      }
      expect(capsuleOps().single.op, Ops.seal, reason: 'not blocked forever');
      expect((await rowOf('c5')).synced, isTrue);
      expect((await capsules.mediaOf('c5')).single.path, isNull);

      api.failUploads = false;
      clock.instant = clock.instant.add(const Duration(hours: 2));
      await sync.kick();
      expect(
        (await capsules.mediaOf('c5')).single.path,
        '$capsuleTestUser/capsules/c5/photo-0',
      );
    });

    test('a capsule deleted before its seal left never goes out', () async {
      await capsules.seal(
        id: 'c6',
        content: const CapsuleContent(text: 'x'),
        unlock: DateUnlock(LocalDay.parse('2027-10-08')),
      );
      await capsules.delete('c6');
      await sync.kick();
      expect(capsuleOps().map((m) => m.op), [Ops.delete]);
      expect(await outbox.count(), 0);
    });

    test('trigger_capsule_limit keeps the capsule here, marked', () async {
      await capsules.seal(
        id: 'c7',
        content: const CapsuleContent(text: 'x'),
        unlock: const MoodUnlock.mood('calm'),
      );
      api.reject[Ops.seal] = 'trigger_capsule_limit';
      await sync.kick();
      final row = await rowOf('c7');
      expect(row.rejected, 'trigger_capsule_limit');
      expect(row.synced, isFalse);
      final dead = await db.select(db.deadLetters).get();
      expect(dead.single.reason, 'trigger_capsule_limit');

      // "Make it a date capsule": the same id, sealed again as `date`.
      await capsules.convertToDate('c7', LocalDay.parse('2027-01-01'));
      await sync.kick();
      final reseal = capsuleOps().last;
      expect(reseal.op, Ops.seal);
      expect(reseal.payload['id'], 'c7');
      expect(reseal.payload['unlockType'], 'date');
      expect(reseal.id, isNot(capsuleOps().first.id));
      expect((await rowOf('c7')).synced, isTrue);
    });

    test('stale_cycle re-pulls the row and adopts the server', () async {
      await capsules.seal(
        id: 'c8',
        content: const CapsuleContent(text: 'x'),
        unlock: const MoodUnlock.mood('calm'),
      );
      await sync.kick();
      final ct = (await rowOf('c8')).payloadCt;
      clock.instant = testNow.add(const Duration(days: 2));
      await capsules.fire('c8');
      rows.rows.add(
        _server(
          'c8',
          unlockType: 'mood',
          unlockLocalDate: null,
          triggerMoodId: 'calm',
          payloadCt: ct,
          sealedAt: testNow.toIso8601String(),
          armedAt: testNow.add(const Duration(days: 1)).toIso8601String(),
          cycle: 1, // another phone re-armed it
          updatedAt: '2026-10-01T00:00:00+00:00', // before the cursor
        ),
      );
      api.reject[Ops.fire] = 'stale_cycle';
      await sync.kick();
      expect(rows.fetchedIds.expand((x) => x), contains('c8'));
      final row = await rowOf('c8');
      expect(row.cycle, 1);
      expect(row.firedAt, isNull);
    });
  });

  group('pull', () {
    test('select-own with an updated_at cursor and a 5-minute overlap', () async {
      rows.rows.addAll([
        _server('p1', updatedAt: '2026-10-08T09:00:00+00:00'),
        _server(
          'p2',
          unlockType: 'mood',
          unlockLocalDate: null,
          triggerMoodId: 'joyful',
          armedAt: '2026-10-02T10:00:00+00:00',
          updatedAt: '2026-10-08T09:30:00+00:00',
        ),
      ]);
      await sync.kick();
      expect(rows.sinces.first, isNull, reason: 'first pull: everything');
      final p1 = await rowOf('p1');
      expect(p1.payloadCt, 'AAAA');
      expect(p1.synced, isTrue);
      expect((await rowOf('p2')).triggerMoodId, 'joyful');
      final cursor = jsonDecode((await capsuleSync.cursorJson())!) as Map;
      expect(cursor['user'], capsuleTestUser);
      expect(DateTime.parse(cursor['at'] as String), DateTime.utc(2026, 10, 8, 9, 30));

      // Throttled until pullEvery passes (or a resume asks).
      await sync.kick();
      expect(rows.sinces, hasLength(1));
      sync.onResume();
      await pumpEventQueue();
      await sync.kick();
      expect(rows.sinces.last, DateTime.utc(2026, 10, 8, 9, 25));
    });

    test('a tombstone from another phone erases the capsule here', () async {
      final photo = await store.writeDraftPhoto('d', Uint8List(20)..[0] = 1);
      await capsules.seal(
        id: 't1',
        content: CapsuleContent(
          text: 'x',
          photos: [CapsulePhotoDraft(path: photo, width: 1, height: 1)],
        ),
        unlock: DateUnlock(LocalDay.parse('2027-10-08')),
      );
      await sync.kick();
      expect(Directory('${root.path}/capsules/t1').existsSync(), isTrue);
      rows.rows.add(
        _server(
          't1',
          unlockLocalDate: null,
          payloadCt: null,
          deletedAt: '2026-10-08T11:00:00+00:00',
          updatedAt: '2026-10-08T11:00:00+00:00',
        ),
      );
      await capsuleSync.pull(capsuleTestUser, () => true, force: true);
      final row = await rowOf('t1');
      expect(row.deletedAt, isNotNull);
      expect(row.payloadCt, isNull);
      expect(row.unlockLocalDate, isNull);
      expect(await capsules.mediaOf('t1'), isEmpty);
      expect(Directory('${root.path}/capsules/t1').existsSync(), isFalse);
    });

    test('nothing is written for an account that signed out meanwhile', () async {
      rows.rows.add(_server('late', updatedAt: '2026-10-08T09:00:00+00:00'));
      await capsuleSync.pull(capsuleTestUser, () => false, force: true);
      expect(await capsules.row('late'), isNull);
    });
  });

  group('merge rules', () {
    CapsuleRow local({
      int cycle = 0,
      DateTime? firedAt,
      DateTime? openedAt,
      DateTime? cooldownUntil,
      DateTime? deletedAt,
      DateTime? armedAt,
    }) => CapsuleRow(
      id: 'm',
      unlockType: 'mood',
      triggerMoodId: 'calm',
      payloadCt: 'LOCAL',
      sealedAt: DateTime.utc(2026, 10, 1),
      sealTz: 'Asia/Kolkata',
      armedAt: armedAt ?? DateTime.utc(2026, 10, 2),
      cycle: cycle,
      firedAt: firedAt,
      cooldownUntil: cooldownUntil,
      openedAt: openedAt,
      openedDeviceTs: openedAt,
      deletedAt: deletedAt,
      synced: true,
      notifyAt: null,
    );

    ServerCapsule server({
      int cycle = 0,
      String? firedAt,
      String? openedAt,
      String? cooldownUntil,
      String? deletedAt,
      String? armedAt = '2026-10-02T00:00:00Z',
    }) => ServerCapsule.fromJson(
      _server(
        'm',
        unlockType: 'mood',
        unlockLocalDate: null,
        triggerMoodId: deletedAt == null ? 'calm' : null,
        payloadCt: deletedAt == null ? 'LOCAL' : null,
        armedAt: armedAt,
        cycle: cycle,
        firedAt: firedAt,
        cooldownUntil: cooldownUntil,
        openedAt: openedAt,
        deletedAt: deletedAt,
        updatedAt: '2026-10-09T00:00:00Z',
      ),
    );

    test('delete wins, keeping the latest cooldown', () {
      final m = mergeServerCapsule(
        local(cooldownUntil: DateTime.utc(2026, 10, 20)),
        server(
          deletedAt: '2026-10-09T00:00:00Z',
          cooldownUntil: '2026-10-15T00:00:00Z',
        ),
        hasPending: true,
      );
      expect(m.deletedAt.value, DateTime.utc(2026, 10, 9));
      expect(m.payloadCt.value, isNull);
      expect(m.triggerMoodId.value, isNull);
      expect(m.cooldownUntil.value, DateTime.utc(2026, 10, 20));
    });

    test('a local delete stays a delete', () {
      final m = mergeServerCapsule(
        local(deletedAt: DateTime.utc(2026, 10, 9)),
        server(),
        hasPending: true,
      );
      expect(m.deletedAt.present, isFalse, reason: 'untouched: still deleted');
      expect(m.payloadCt.present, isFalse);
    });

    test('fire at most once: the earliest wins; the cooldown is the latest', () {
      final m = mergeServerCapsule(
        local(
          firedAt: DateTime.utc(2026, 10, 5, 12),
          cooldownUntil: DateTime.utc(2026, 10, 12, 12),
        ),
        server(
          firedAt: '2026-10-05T09:00:00Z',
          cooldownUntil: '2026-10-12T09:00:00Z',
        ),
        hasPending: true,
      );
      expect(m.firedAt.value, DateTime.utc(2026, 10, 5, 9));
      expect(m.cooldownUntil.value, DateTime.utc(2026, 10, 12, 12));
    });

    test('opened is one-way; the server time is the real unlock time', () {
      var m = mergeServerCapsule(
        local(openedAt: DateTime.utc(2026, 10, 6)),
        server(),
        hasPending: true,
      );
      expect(m.openedAt.value, DateTime.utc(2026, 10, 6), reason: 'kept');
      m = mergeServerCapsule(
        local(openedAt: DateTime.utc(2026, 10, 6)),
        server(openedAt: '2026-10-06T00:00:05Z', firedAt: '2026-10-06T00:00:00Z'),
        hasPending: true,
      );
      expect(m.openedAt.value, DateTime.utc(2026, 10, 6, 0, 0, 5));
    });

    test('content never changes once sealed', () {
      final m = mergeServerCapsule(local(), server(), hasPending: true);
      expect(m.payloadCt.value, 'LOCAL');
    });

    test('a newer cycle from another phone replaces the cycle state', () {
      final m = mergeServerCapsule(
        local(firedAt: DateTime.utc(2026, 10, 5), openedAt: DateTime.utc(2026, 10, 5)),
        server(cycle: 1, armedAt: '2026-10-07T00:00:00Z'),
        hasPending: true,
      );
      expect(m.cycle.value, 1);
      expect(m.firedAt.value, isNull);
      expect(m.openedAt.value, isNull);
      expect(m.armedAt.value, DateTime.utc(2026, 10, 7));
    });

    test('with nothing queued the server row is adopted as is', () {
      final m = mergeServerCapsule(
        local(cycle: 1, armedAt: DateTime.utc(2026, 10, 8)),
        server(openedAt: '2026-10-06T00:00:00Z', firedAt: '2026-10-06T00:00:00Z'),
        hasPending: false,
      );
      expect(m.cycle.value, 0, reason: 'a refused re-arm is undone');
      expect(m.openedAt.value, DateTime.utc(2026, 10, 6));
      expect(m.synced.value, isTrue);
      expect(m.rejected, const Value<String?>(null));
    });
  });
}
