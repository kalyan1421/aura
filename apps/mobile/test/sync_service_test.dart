import 'dart:async';
import 'dart:convert';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/net/api_models.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/security/note_cipher.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/sync/sync_service.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/core/sync/pull_service.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura/src/features/profile/profile_service.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _key = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8='; // 32 bytes

class _FakeAuth implements AuthRepository {
  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => const AuthUser(id: 'user-1', email: 'a@b.c');
  @override
  Stream<AuthUser?> watchUser() => Stream.value(currentUser);
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<void> sendEmailCode(String email) async {}
  @override
  Future<void> verifyEmailCode(String email, String code) async {}
  @override
  Future<void> signOut() async {}
}

Snapshot _snapshot(int total) => Snapshot(
  avatar: const SnapshotAvatar(stage: 'spark', hue: 210),
  streak: const SnapshotStreak(glowStreak: 1, lifetimeGlowDays: 1, lastActiveDay: '2026-10-08'),
  starlight: SnapshotStarlight(total: total, today: total),
  serverTime: '2026-10-08T10:00:00Z',
  auraDay: '2026-10-08',
);

class _FakeApi extends AuraApi {
  _FakeApi() : super(baseUrl: 'http://test', accessToken: () async => 't');

  final List<List<SyncMutation>> pushes = [];
  final List<ProfileRequest> profiles = [];
  ApiException? failNextPush;
  ApiException? failNextProfile;
  String? rejectEntity;
  String rejectReason = 'unknown_mood';

  @override
  Future<ProfileResult> postProfile(ProfileRequest body) async {
    final fail = failNextProfile;
    if (fail != null) {
      failNextProfile = null;
      throw fail;
    }
    profiles.add(body);
    return ProfileSaved(_snapshot(0));
  }

  @override
  Future<PushResponse> push({
    required String deviceId,
    required List<SyncMutation> mutations,
  }) async {
    final fail = failNextPush;
    if (fail != null) {
      failNextPush = null;
      throw fail;
    }
    pushes.add(mutations);
    return PushResponse(
      results: [
        for (final m in mutations)
          MutationResult(
            id: m.id,
            status: m.entity == rejectEntity ? 'rejected' : 'applied',
            reason: m.entity == rejectEntity ? rejectReason : null,
          ),
      ],
      snapshot: _snapshot(10),
    );
  }

  @override
  Future<Snapshot> snapshot() async => _snapshot(10);

  @override
  Future<DataKeyResponse> dataKey() async =>
      const DataKeyResponse(keyId: 'k1', dataKey: _key);
}

void main() {
  late AppDatabase db;
  late KvStore kv;
  late OutboxRepository outbox;
  late CheckInRepository checkIns;
  late ProgressRepository progress;
  late _FakeApi api;
  late SyncService sync;
  late StreamController<bool> online;
  final time = testTime();

  setUp(() async {
    db = memoryDb();
    kv = KvStore(db);
    outbox = OutboxRepository(db, const Ids());
    checkIns = CheckInRepository(db, outbox, time);
    progress = ProgressRepository(db, kv);
    api = _FakeApi();
    online = StreamController<bool>();
    final profile = ProfileService(
      kv: kv,
      timezone: () => time.timezone,
      progress: progress,
      country: () => 'IN',
    );
    await profile.queue(birthDate: LocalDay.parse('2006-04-17'));
    await kv.set(KvKeys.locale, 'te-Latn');
    sync = SyncService(
      auth: _FakeAuth(),
      api: api,
      outbox: outbox,
      checkIns: checkIns,
      profile: profile,
      progress: progress,
      dataKeys: DataKeyRepository(MemorySecureStore()),
      kv: kv,
      clock: time.clock,
      ids: const Ids(),
      connectivity: online.stream,
      pull: (_, _) async {},
      alreadyPulled: (_) async => true,
      onUnder13: () async {},
      onCommitmentRejected: (habitId) =>
          HabitRepository(db, outbox, time, const Ids())
              .clearRejectedCommitment(habitId),
    );
  });

  tearDown(() async {
    await sync.dispose();
    unawaited(online.close()); // never listened to: close() would not complete
    await db.close();
  });

  test('sends the queued profile first, then pushes and acknowledges',
      () async {
    final c = await checkIns.save(id: const Ids().v7(), mood: moodById('calm')!);
    await sync.kick();

    expect(api.profiles.single.birthDate, '2006-04-17');
    expect(api.profiles.single.uiLocale, 'te-Latn');
    expect(api.profiles.single.timezone, 'Asia/Kolkata');
    expect(await kv.get(KvKeys.pendingProfile), isNull);
    expect(await kv.get(KvKeys.profileTimezone), 'Asia/Kolkata');

    final m = api.pushes.single.single;
    expect(m.entity, 'check_in');
    expect(m.localDay, '2026-10-08');
    expect(m.tz, 'Asia/Kolkata'); // the zone the day was stamped in
    expect(m.toJson()['tz'], 'Asia/Kolkata');
    expect(m.payload['moodId'], 'calm');
    expect(await outbox.count(), 0);
    final row = await (db.select(db.checkIns)..where((t) => t.id.equals(c.id))).getSingle();
    expect(row.synced, isTrue);
    // The server snapshot is adopted.
    final snap = await kv.getJson(KvKeys.snapshot);
    expect((snap!['starlight'] as Map)['total'], 10);
    expect(sync.phase.value, SyncPhase.idle);
  });

  test('PRD 16: after the push, a delta pull (then at most every 2 min, and '
      'again after a resume)', () async {
    final deltas = <String>[];
    final clock = FixedClock(testNow);
    final withDelta = SyncService(
      auth: _FakeAuth(),
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
      dataKeys: DataKeyRepository(MemorySecureStore()),
      kv: kv,
      clock: clock,
      ids: const Ids(),
      connectivity: const Stream.empty(),
      pull: (_, _) async {},
      alreadyPulled: (_) async => true,
      onUnder13: () async {},
      deltaPull: (userId, _) async => deltas.add(userId),
    );
    addTearDown(withDelta.dispose);
    await checkIns.save(id: const Ids().v7(), mood: moodById('calm')!);
    await withDelta.kick();
    expect(api.pushes, isNotEmpty);
    expect(deltas, ['user-1']);
    await withDelta.kick(); // a minute-heartbeat later: throttled
    expect(deltas, hasLength(1));
    clock.instant = testNow.add(SyncService.deltaPullEvery);
    await withDelta.kick();
    expect(deltas, hasLength(2));
    withDelta.onResume(); // foreground: always (its own kick)
    await withDelta.drainNow();
    expect(deltas, hasLength(3));
  });

  test('notes leave the device only as AES-GCM ciphertext', () async {
    final id = const Ids().v7();
    await checkIns.save(id: id, mood: moodById('lonely')!, note: 'missing home');
    await sync.kick();

    final m = api.pushes.single.single;
    final ct = m.payload['noteCt'] as String;
    expect(jsonEncode(m.toJson()).contains('missing home'), isFalse);
    final cipher = await DataKeyRepository(
      MemorySecureStore({
        SecureKeys.dataKey('user-1'): jsonEncode({'keyId': 'k1', 'dataKey': _key}),
      }),
    ).cipherFor('user-1');
    expect(await cipher!.decrypt(ct, recordId: id), 'missing home');
    // Bound to its record id.
    expect(() => cipher.decrypt(ct, recordId: 'other'), throwsA(anything));
  });

  test('a local duplicate preset habit merges into the server one and its '
      'logs are re-queued (duplicate_preset_habit)', () async {
    final habits = HabitRepository(db, outbox, time, const Ids());
    await habits.toggleToday('breathe'); // local habit + log, offline
    final local = (await db.select(db.habits).get()).single;
    // The server already has "breathe" under another id; our upsert and the
    // log that references it were rejected.
    await outbox.reject(
      await db.select(db.outbox).get(),
      'duplicate_preset_habit',
      testNow,
    );
    final pull = PullService(
      db: db,
      kv: kv,
      progress: progress,
      dataKeys: DataKeyRepository(MemorySecureStore()),
    );
    const serverId = '0199aaaa-0000-7000-8000-000000000001';
    await db.into(db.habits).insert(
      HabitsCompanion.insert(
        id: serverId,
        kind: 'preset',
        presetKey: const Value('breathe'),
        createdAt: testNow,
        updatedAt: testNow,
        synced: const Value(true),
      ),
    );
    final merged = await pull.mergePresetHabits([
      {'id': serverId, 'kind': 'preset', 'preset_key': 'breathe'},
    ]);
    expect(merged, 1);
    final left = await db.select(db.habits).get();
    expect(left.single.id, serverId);
    expect((await db.select(db.habitLogs).get()).single.habitId, serverId);
    expect(await db.select(db.deadLetters).get(), isEmpty);
    final requeued = (await db.select(db.outbox).get()).single;
    expect(requeued.entity, 'habit_log');
    expect(jsonDecode(requeued.payload)['habitId'], serverId);
    expect(requeued.tz, 'Asia/Kolkata');
    expect(local.id, isNot(serverId));
  });

  test('network failure backs off; nothing is lost; rejections dead-letter',
      () async {
    await checkIns.save(id: const Ids().v7(), mood: moodById('joyful')!);
    api.failNextPush = const ApiException(code: 'connectionError', isNetwork: true);
    await sync.kick();
    expect(await outbox.count(), 1);
    expect(sync.phase.value, SyncPhase.offline);
    final row = (await db.select(db.outbox).get()).single;
    expect(row.attempts, 1);
    expect(row.nextAttemptAt, isNotNull);

    await outbox.resetBackoff();
    api.rejectEntity = 'check_in';
    await sync.kick();
    expect(await outbox.count(), 0);
    final dead = await db.select(db.deadLetters).get();
    expect(dead.single.reason, 'unknown_mood');
  });

  test('a refused commitment is dead-lettered and dropped locally, so the '
      'world never shows stakes the server does not hold (W03)', () async {
    final habits = HabitRepository(db, outbox, time, const Ids());
    await habits.addCustom('Read');
    final id = (await db.select(db.habits).getSingle()).id;
    await habits.setCommitment(id, committed: true, ageYears: 30);
    // The phone believes an adult; the server has an under-18 age signal.
    api
      ..rejectEntity = 'habit'
      ..rejectReason = 'commitment_not_available';
    await sync.kick();

    final dead = await db.select(db.deadLetters).get();
    expect(dead.map((d) => d.reason), everyElement('commitment_not_available'));
    final habit = await db.select(db.habits).getSingle();
    expect(habit.committedFrom, isNull);
    expect(habit.pausedThrough, isNull);
    expect(habit.name, 'Read'); // the habit itself stays
    expect(await outbox.count(), 0); // nothing re-queued
  });

  // ---- M2: request-level errors never dead-letter a batch ------------------

  test('409 profile_required keeps the whole batch and re-queues the profile',
      () async {
    await checkIns.save(id: const Ids().v7(), mood: moodById('calm')!);
    api.failNextPush = const ApiException(code: 'profile_required', status: 409);
    await sync.kick();

    expect(api.profiles, hasLength(1)); // the first POST went through…
    expect(await outbox.count(), 1); // …but the server lost it: rows kept
    expect(await db.select(db.deadLetters).get(), isEmpty);
    expect(await kv.get(KvKeys.pendingProfile), '1'); // re-queued
    expect((await db.select(db.outbox).get()).single.attempts, 1);
    expect(sync.phase.value, SyncPhase.waiting);

    await outbox.resetBackoff();
    await sync.kick();
    expect(api.profiles, hasLength(2)); // profile first, then the rows
    expect(api.pushes, hasLength(1));
    expect(await outbox.count(), 0);
  });

  test('any other refused batch (400) is kept with a long backoff, never '
      'dead-lettered', () async {
    await checkIns.save(id: const Ids().v7(), mood: moodById('calm')!);
    await checkIns.save(id: const Ids().v7(), mood: moodById('joyful')!);
    api.failNextPush = const ApiException(code: 'invalid_request', status: 400);
    await sync.kick();

    expect(await db.select(db.deadLetters).get(), isEmpty);
    final rows = await db.select(db.outbox).get();
    expect(rows, hasLength(2));
    for (final r in rows) {
      expect(
        r.nextAttemptAt!.isBefore(testNow.add(const Duration(minutes: 59))),
        isFalse,
      );
    }
  });

  test('network failures never dead-letter, however many attempts', () async {
    await checkIns.save(id: const Ids().v7(), mood: moodById('calm')!);
    await (db.update(db.outbox)).write(const OutboxCompanion(attempts: Value(20)));
    api.failNextPush = const ApiException(code: 'connectionError', isNetwork: true);
    await sync.kick();
    expect(await outbox.count(), 1);
    expect(await db.select(db.deadLetters).get(), isEmpty);
  });

  test('a per-mutation rejection dead-letters only that row', () async {
    await checkIns.save(id: const Ids().v7(), mood: moodById('calm')!);
    await HabitRepository(db, outbox, time, const Ids()).toggleToday('breathe');
    expect(await outbox.count(), 3); // check-in, habit, habit log
    api.rejectEntity = 'check_in';
    await sync.kick();

    final dead = await db.select(db.deadLetters).get();
    expect(dead.single.entity, 'check_in');
    expect(dead.single.reason, 'unknown_mood');
    expect(await outbox.count(), 0);
    expect((await db.select(db.habits).get()).single.synced, isTrue);
  });

  test('a refused profile POST (400) stays pending and retries with backoff; '
      'birth_date_locked stops re-sending it', () async {
    final clock = FixedClock(testNow);
    final p = ProfileService(
      kv: kv,
      timezone: () => time.timezone,
      progress: progress,
      country: () => 'IN',
      clock: clock,
    );
    api.failNextProfile = const ApiException(code: 'invalid_request', status: 400);
    expect(await p.flush(api), ProfileFlush.failed);
    expect(await kv.get(KvKeys.pendingProfile), '1'); // never dropped
    expect(await p.flush(api), ProfileFlush.deferred); // backing off
    expect(api.profiles, isEmpty);

    clock.instant = testNow.add(const Duration(seconds: 31));
    expect(await p.flush(api), ProfileFlush.saved);
    expect(await kv.get(KvKeys.pendingProfile), isNull);

    await p.markDirty();
    api.failNextProfile = const ApiException(code: 'birth_date_locked', status: 409);
    expect(await p.flush(api), ProfileFlush.failed);
    expect(await kv.get(KvKeys.pendingProfile), isNull);
    expect(await p.isOnServer(), isTrue);
  });
}
