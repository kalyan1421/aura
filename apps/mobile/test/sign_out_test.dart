import 'dart:async';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/net/api_models.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/security/note_cipher.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/sync/sync_service.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/auth/sign_out_service.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/profile/profile_service.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _alice = AuthUser(id: 'user-a', email: 'a@aura.test');
const _bob = AuthUser(id: 'user-b', email: 'b@aura.test');

class _Auth implements AuthRepository {
  _Auth(this.user, [this.log]);

  AuthUser? user;
  final List<String>? log;
  bool failSignOut = false;
  final _users = StreamController<AuthUser?>.broadcast();

  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> watchUser() async* {
    yield user;
    yield* _users.stream;
  }

  @override
  Future<String?> accessToken() async => user == null ? null : 'jwt';
  @override
  Future<void> sendEmailCode(String email) async {}
  @override
  Future<void> verifyEmailCode(String email, String code) async {}
  @override
  Future<void> signOut() async {
    log?.add('auth.signOut');
    user = null;
    _users.add(null);
    if (failSignOut) throw Exception('network'); // session already dropped
  }

  void signIn(AuthUser u) {
    user = u;
    _users.add(u);
  }
}

class _RecordingApi extends AuraApi {
  _RecordingApi() : super(baseUrl: 'http://test', accessToken: () async => 't');

  final List<List<SyncMutation>> pushes = [];
  final List<ProfileRequest> profiles = [];

  @override
  Future<ProfileResult> postProfile(ProfileRequest body) async {
    profiles.add(body);
    return const ProfileSaved(null);
  }

  @override
  Future<PushResponse> push({
    required String deviceId,
    required List<SyncMutation> mutations,
  }) async {
    pushes.add(mutations);
    return PushResponse(
      results: [for (final m in mutations) MutationResult(id: m.id, status: 'applied')],
    );
  }

  @override
  Future<DataKeyResponse> dataKey() async => const DataKeyResponse(
    keyId: 'k1',
    dataKey: 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=',
  );
}

void main() {
  final time = testTime();
  late AppDatabase db;
  late KvStore kv;
  late MemorySecureStore secure;
  late OutboxRepository outbox;
  final lockUntil = testNow.add(const Duration(days: 20)).toIso8601String();

  /// Everything user A leaves on the phone: rows in every table, user and
  /// device keys, the note key, and the under-13 lock of an earlier attempt.
  Future<void> seedAlice() async {
    final checkIns = CheckInRepository(db, outbox, time);
    await checkIns.save(
      id: const Ids().v7(),
      mood: moodById('lonely')!,
      note: 'missing home',
    );
    await HabitRepository(db, outbox, time, const Ids()).toggleToday('breathe');
    final rows = await db.select(db.outbox).get();
    await outbox.reject([rows.first], 'unknown_mood', testNow); // a dead letter
    for (final (k, v) in [
      (KvKeys.birthDate, '2006-04-17'),
      (KvKeys.minorUntil, '2024-04-17'),
      (KvKeys.pendingProfile, '1'),
      (KvKeys.profileTimezone, 'Asia/Kolkata'),
      (KvKeys.pulledFor, _alice.id),
      (KvKeys.snapshot, '{"starlight":{"total":10}}'),
      (KvKeys.lastHue, '210.00'),
      (KvKeys.onboardingStage, 'done'),
      (KvKeys.playedMoments, '["evolve:ember"]'),
      (KvKeys.carriesOnShownFor, '2026-10-08'),
      (KvKeys.pushSoftAsk, '{"answer":"allow"}'),
      (KvKeys.pushRegistered, '{"userId":"user-a","token":"t"}'),
      // Device-scoped.
      (KvKeys.locale, 'te-Latn'),
      (KvKeys.deviceId, 'device-1'),
      (KvKeys.pushDeleteOwed, '1'),
      (KvKeys.comfort, '{"reduceMotion":true}'),
      (KvKeys.guidedPromptsOff, 'true'),
    ]) {
      await kv.set(k, v);
    }
    await secure.write(SecureKeys.ageBlockUntil, lockUntil);
    await secure.write(SecureKeys.dbKey, 'db-key-hex');
    await secure.write(SecureKeys.dataKey(_alice.id), '{"dataKey":"x"}');
  }

  Future<void> expectWiped() async {
    expect(await db.select(db.checkIns).get(), isEmpty);
    expect(await db.select(db.habits).get(), isEmpty);
    expect(await db.select(db.habitLogs).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(await db.select(db.deadLetters).get(), isEmpty);
    final keys = {for (final r in await db.select(db.keyValues).get()) r.key};
    expect(keys, KvKeys.deviceScoped);
    expect(await kv.get(KvKeys.locale), 'te-Latn');
    expect(await kv.get(KvKeys.deviceId), 'device-1');
    // The under-13 lock and the DB key stay; the note key is gone.
    expect(await secure.read(SecureKeys.ageBlockUntil), lockUntil);
    expect(await secure.read(SecureKeys.dbKey), 'db-key-hex');
    expect(await secure.read(SecureKeys.dataKey(_alice.id)), isNull);
  }

  setUp(() {
    db = memoryDb();
    kv = KvStore(db);
    secure = MemorySecureStore();
    outbox = OutboxRepository(db, const Ids());
  });

  tearDown(() => db.close());

  test('sign-out wipes every personal row and user key, keeps device-scoped '
      'items, and runs push → auth → wipe in order', () async {
    await seedAlice();
    expect(await db.select(db.checkIns).get(), isNotEmpty);
    final log = <String>[];
    final auth = _Auth(_alice, log);

    await SignOutService(
      auth: auth,
      db: db,
      secure: secure,
      dataKeys: DataKeyRepository(secure),
      unregisterPush: () async => log.add('push.unregister'),
      pauseSync: () async => log.add('sync.pause'),
      resumeSync: () => log.add('sync.resume'),
      afterWipe: () async {
        // Wiped before the UI state resets.
        expect(await db.select(db.checkIns).get(), isEmpty);
        log.add('afterWipe');
      },
    ).signOut();

    expect(log, [
      'sync.pause',
      'push.unregister',
      'auth.signOut',
      'afterWipe',
      'sync.resume',
    ]);
    expect(auth.currentUser, isNull);
    await expectWiped();
  });

  test('a failing push unregistration or auth call never stops the wipe',
      () async {
    await seedAlice();
    await SignOutService(
      auth: _Auth(_alice)..failSignOut = true,
      db: db,
      secure: secure,
      dataKeys: DataKeyRepository(secure),
      unregisterPush: () async => throw Exception('offline'),
      pauseSync: () async {},
      resumeSync: () {},
      afterWipe: () async {},
    ).signOut();
    await expectWiped();
  });

  test("the next account never receives A's outbox, DOB or profile", () async {
    await seedAlice();
    final auth = _Auth(_alice);
    final api = _RecordingApi();
    final progress = ProgressRepository(db, kv);
    final dataKeys = DataKeyRepository(secure);
    final online = StreamController<bool>();
    final sync = SyncService(
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
      dataKeys: dataKeys,
      kv: kv,
      clock: time.clock,
      ids: const Ids(),
      connectivity: online.stream,
      pull: (_, _) async {},
      alreadyPulled: (_) async => true,
      onUnder13: () async {},
    );
    addTearDown(() async {
      await sync.dispose();
      unawaited(online.close());
    });

    await SignOutService(
      auth: auth,
      db: db,
      secure: secure,
      dataKeys: dataKeys,
      unregisterPush: () async {},
      pauseSync: sync.pause,
      resumeSync: sync.resume,
      afterWipe: () async {},
    ).signOut();

    auth.signIn(_bob);
    await sync.kick();
    expect(api.pushes, isEmpty);
    expect(api.profiles, isEmpty); // no DOB carried over
    expect(await kv.get(KvKeys.birthDate), isNull);
  });

  test('a drain still in flight at sign-out writes nothing afterwards',
      () async {
    final auth = _Auth(_alice);
    final gate = Completer<void>();
    final api = _SlowApi(gate.future);
    final progress = ProgressRepository(db, kv);
    await CheckInRepository(db, outbox, time).save(
      id: const Ids().v7(),
      mood: moodById('calm')!,
    );
    final online = StreamController<bool>();
    final sync = SyncService(
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
      clock: time.clock,
      ids: const Ids(),
      connectivity: online.stream,
      pull: (_, _) async {},
      alreadyPulled: (_) async => true,
      onUnder13: () async {},
    );
    addTearDown(() async {
      await sync.dispose();
      unawaited(online.close());
    });

    final drain = sync.kick(); // blocks inside api.push
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final out = SignOutService(
      auth: auth,
      db: db,
      secure: secure,
      dataKeys: DataKeyRepository(secure),
      unregisterPush: () async {},
      pauseSync: () => sync.pause(timeout: const Duration(milliseconds: 50)),
      resumeSync: sync.resume,
      afterWipe: () async {},
    ).signOut();
    await out;
    gate.complete(); // the server answers after the wipe
    await drain;
    expect(await kv.get(KvKeys.snapshot), isNull);
    expect(await db.select(db.checkIns).get(), isEmpty);
  });

  test('provider wiring: sign-out lands on Welcome, the under-13 lock state '
      'is kept', () async {
    await seedAlice();
    final until = DateTime.parse(lockUntil);
    final container = ProviderContainer(
      overrides: testOverrides(
        db: db,
        secure: secure,
        auth: _Auth(_alice),
        gate: GateState(stage: OnboardingStage.done, blockedUntil: until),
      ),
    );
    addTearDown(container.dispose);

    await container.read(signOutServiceProvider).signOut();

    final gate = container.read(gateControllerProvider);
    expect(gate.stage, OnboardingStage.welcome);
    expect(gate.blockedUntil, until);
    expect(await db.select(db.checkIns).get(), isEmpty);
    expect(await kv.get(KvKeys.onboardingStage), 'welcome');
  });
}

/// Holds `push` until [release] completes, then answers with a snapshot.
class _SlowApi extends _RecordingApi {
  _SlowApi(this.release);

  final Future<void> release;

  @override
  Future<PushResponse> push({
    required String deviceId,
    required List<SyncMutation> mutations,
  }) async {
    await release;
    return PushResponse(
      results: [for (final m in mutations) MutationResult(id: m.id, status: 'applied')],
      snapshot: const Snapshot(
        avatar: SnapshotAvatar(stage: 'spark', hue: 210),
        streak: SnapshotStreak(glowStreak: 1, lifetimeGlowDays: 1),
        starlight: SnapshotStarlight(total: 10, today: 10),
        serverTime: '2026-10-08T10:00:00Z',
        auraDay: '2026-10-08',
      ),
    );
  }
}
