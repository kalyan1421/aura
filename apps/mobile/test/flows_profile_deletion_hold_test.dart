import 'dart:async';

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
import 'package:aura/src/features/account/account_providers.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/profile/profile_service.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// `POST /v1/profile` answered `403 account_deletion_pending` (the account is
/// in its 7-day deletion grace): the profile stays pending, is reported once
/// through the same deletion hold sync uses ("Keep my account?"), is not
/// retried in a loop, and goes out once the hold is released.

const _alice = AuthUser(id: 'user-a', email: 'a@aura.test');
final _purge = DateTime.utc(2026, 10, 15, 10);

/// Refuses the profile (and pushes) with 403 while [pending].
class _Api extends AuraApi {
  _Api() : super(baseUrl: 'http://test', accessToken: () async => 't');

  bool pending = true;
  int profileCalls = 0;
  int pushCalls = 0;
  final List<ProfileRequest> saved = [];

  static const _refused = ApiException(
    code: ApiException.deletionPendingCode,
    status: 403,
  );

  @override
  Future<ProfileResult> postProfile(ProfileRequest body) async {
    profileCalls++;
    if (pending) throw _refused;
    saved.add(body);
    return const ProfileSaved(null);
  }

  @override
  Future<PushResponse> push({
    required String deviceId,
    required List<SyncMutation> mutations,
  }) async {
    pushCalls++;
    if (pending) throw _refused;
    return PushResponse(
      results: [
        for (final m in mutations) MutationResult(id: m.id, status: 'applied'),
      ],
    );
  }
}

class _Auth implements AuthRepository {
  const _Auth();

  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => _alice;
  @override
  Stream<AuthUser?> watchUser() => Stream.value(_alice);
  @override
  Future<String?> accessToken() async => 'jwt';
  @override
  Future<void> sendEmailCode(String email) async {}
  @override
  Future<void> verifyEmailCode(String email, String code) async {}
  @override
  Future<void> signOut() async {}
}

class _Account implements AccountRepository {
  DateTime? scheduled = _purge;
  int cancels = 0;

  @override
  Future<DateTime> requestDeletion() async => scheduled = _purge;
  @override
  Future<DateTime?> scheduledDeletion() async => scheduled;
  @override
  Future<void> cancelDeletion() async {
    cancels++;
    scheduled = null;
  }
}

void main() {
  late AppDatabase db;
  late KvStore kv;
  late ProgressRepository progress;
  late FixedClock clock;
  late _Api api;
  late int reported;

  ProfileService service({void Function()? onDeletionPending}) =>
      ProfileService(
        kv: kv,
        timezone: () => 'Asia/Kolkata',
        progress: progress,
        country: () => 'IN',
        clock: clock,
        onDeletionPending: onDeletionPending ?? () => reported++,
      );

  setUp(() {
    db = memoryDb();
    kv = KvStore(db);
    progress = ProgressRepository(db, kv);
    clock = FixedClock(testNow);
    api = _Api();
    reported = 0;
  });

  tearDown(() => db.close());

  test('the 403 holds the profile: pending, reported once, never sent again '
      'while held (no backoff loop), however much time passes', () async {
    final p = service();
    await p.queue(birthDate: LocalDay.parse('2006-04-17'));

    expect(await p.flush(api), ProfileFlush.deferred);
    expect(await kv.get(KvKeys.pendingProfile), '1'); // never dropped
    expect(p.isHeldForDeletion, isTrue);
    expect(reported, 1);
    expect(api.profileCalls, 1);

    for (final wait in const [
      Duration(seconds: 31),
      Duration(hours: 2),
      Duration(days: 3),
    ]) {
      clock.instant = testNow.add(wait);
      expect(await p.flush(api), ProfileFlush.deferred);
    }
    // A locale change while held re-queues the profile but doesn't send it.
    await p.markDirty();
    expect(await p.flush(api), ProfileFlush.deferred);
    expect(api.profileCalls, 1);
    expect(reported, 1);
  });

  test('released ("Keep my account"): the profile goes on the next flush, '
      'without waiting out any backoff', () async {
    final p = service();
    await p.queue(birthDate: LocalDay.parse('2006-04-17'));
    await p.flush(api);

    api.pending = false;
    p.releaseDeletionHold();
    expect(p.isHeldForDeletion, isFalse);
    expect(await p.flush(api), ProfileFlush.saved);
    expect(api.saved.single.birthDate, '2006-04-17');
    expect(await kv.get(KvKeys.pendingProfile), isNull);
  });

  test(
    'a new onboarding (queue) is never held for an earlier account',
    () async {
      final p = service();
      await p.queue(birthDate: LocalDay.parse('2006-04-17'));
      await p.flush(api);
      expect(p.isHeldForDeletion, isTrue);

      api.pending = false;
      await p.queue(birthDate: LocalDay.parse('2001-01-02'));
      expect(await p.flush(api), ProfileFlush.saved);
      expect(api.saved.single.birthDate, '2001-01-02');
    },
  );

  test('other refusals still back off as before (not a hold)', () async {
    final p = service();
    await p.queue(birthDate: LocalDay.parse('2006-04-17'));
    final real = api;
    real.pending = false;
    final bad = _BadRequestApi();
    expect(await p.flush(bad), ProfileFlush.failed);
    expect(p.isHeldForDeletion, isFalse);
    expect(reported, 0);
    expect(await p.flush(real), ProfileFlush.deferred); // backing off
    clock.instant = testNow.add(const Duration(seconds: 31));
    expect(await p.flush(real), ProfileFlush.saved);
  });

  group('wired to the deletion hold (as sync is, in core/providers.dart)', () {
    late _Account account;
    late ProviderContainer container;

    setUp(() {
      account = _Account();
      container = ProviderContainer(
        overrides: [
          ...testOverrides(db: db, auth: const _Auth()),
          accountRepositoryProvider.overrideWithValue(account),
        ],
      );
    });

    tearDown(() => container.dispose());

    /// The proposed `profileServiceProvider` wiring: report through
    /// [DeletionHold.reportFromSync]; release when the hold clears.
    ProfileService wired() {
      final p = service(
        onDeletionPending: () => unawaited(
          container.read(deletionHoldProvider.notifier).reportFromSync(),
        ),
      );
      container.listen(deletionHoldProvider, (prev, next) {
        if (prev != null && next == null) p.releaseDeletionHold();
      });
      return p;
    }

    test(
      'the 403 asks "Keep my account?"; keeping it sends the profile',
      () async {
        final p = wired();
        await p.queue(birthDate: LocalDay.parse('2006-04-17'));

        expect(await p.flush(api), ProfileFlush.deferred);
        expect(container.read(deletionHoldProvider)?.userId, _alice.id);
        await Future<void>.delayed(Duration.zero); // the date lookup
        expect(container.read(deletionHoldProvider)?.scheduledFor, _purge);

        api.pending = false;
        expect(
          await container.read(deletionHoldProvider.notifier).keep(),
          KeepResult.kept,
        );
        expect(account.cancels, 1);
        expect(p.isHeldForDeletion, isFalse);
        expect(await p.flush(api), ProfileFlush.saved);
        expect(api.profileCalls, 2); // the refused one, then the sent one
      },
    );
  });

  test('through sync: with nothing to push, later syncs never re-send the '
      'refused profile; once released the next sync sends it', () async {
    final p = service();
    await p.queue(birthDate: LocalDay.parse('2006-04-17'));
    final outbox = OutboxRepository(db, const Ids());
    final time = testTime();
    final online = StreamController<bool>();
    final sync = SyncService(
      auth: const _Auth(),
      api: api,
      outbox: outbox,
      checkIns: CheckInRepository(db, outbox, time),
      profile: p,
      progress: progress,
      dataKeys: DataKeyRepository(MemorySecureStore()),
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

    await sync.kick();
    await sync.kick();
    await sync.kick(); // e.g. the 1-minute heartbeat
    expect(api.profileCalls, 1);
    expect(reported, 1);
    expect(await kv.get(KvKeys.pendingProfile), '1');

    api.pending = false;
    p.releaseDeletionHold();
    await sync.kick();
    expect(api.profileCalls, 2);
    expect(api.saved, hasLength(1));
    expect(await kv.get(KvKeys.pendingProfile), isNull);
  });
}

class _BadRequestApi extends AuraApi {
  _BadRequestApi()
    : super(baseUrl: 'http://test', accessToken: () async => 't');

  @override
  Future<ProfileResult> postProfile(ProfileRequest body) async =>
      throw const ApiException(code: 'invalid_request', status: 400);
}
