import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import 'package:aura/src/features/account/account_providers.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/profile/profile_service.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Account deletion client (F8 REQ-ACC-11, contracts/api/v1.md "Account
/// deletion"): the API calls, sync's hold on `403 account_deletion_pending`
/// and the "Keep my account?" state.

const _alice = AuthUser(id: 'user-a', email: 'a@aura.test');
const _bob = AuthUser(id: 'user-b', email: 'b@aura.test');
final _purge = DateTime.utc(2026, 10, 15, 10);

// ---- fakes -------------------------------------------------------------------

/// Answers every request with [status] + [body] and records it.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Object body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AuraApi _api(_Adapter adapter) => AuraApi(
  baseUrl: 'http://test',
  accessToken: () async => 'jwt',
  dio: Dio(
    BaseOptions(
      baseUrl: 'http://test',
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter,
);

class _Auth implements AuthRepository {
  _Auth(this.user);

  AuthUser? user;
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
  Future<void> signOut() async => signIn(null);

  void signIn(AuthUser? u) {
    user = u;
    _users.add(u);
  }
}

/// Push refuses with `403 account_deletion_pending` while [pending].
class _PendingApi extends AuraApi {
  _PendingApi() : super(baseUrl: 'http://test', accessToken: () async => 't');

  bool pending = true;
  int pushCalls = 0;
  final List<List<SyncMutation>> accepted = [];

  @override
  Future<PushResponse> push({
    required String deviceId,
    required List<SyncMutation> mutations,
  }) async {
    pushCalls++;
    if (pending) {
      throw const ApiException(code: 'account_deletion_pending', status: 403);
    }
    accepted.add(mutations);
    return PushResponse(
      results: [
        for (final m in mutations) MutationResult(id: m.id, status: 'applied'),
      ],
    );
  }
}

class _Account implements AccountRepository {
  DateTime? scheduled;
  int statusCalls = 0;
  int cancels = 0;
  Object? failStatus;
  Object? failCancel;

  @override
  Future<DateTime> requestDeletion() async => scheduled = _purge;

  @override
  Future<DateTime?> scheduledDeletion() async {
    statusCalls++;
    final e = failStatus;
    if (e != null) throw e;
    return scheduled;
  }

  @override
  Future<void> cancelDeletion() async {
    final e = failCancel;
    if (e != null) throw e;
    cancels++;
    scheduled = null;
  }
}

void main() {
  group('AuraApi account endpoints', () {
    test('GET /v1/account reads the scheduled date (or none)', () async {
      final adapter = _Adapter(200, {
        'deletionScheduledFor': '2026-10-15T10:00:00Z',
      });
      final status = await _api(adapter).account();
      expect(status.scheduledFor, _purge);
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/v1/account');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer jwt');

      final none = await _api(_Adapter(200, {'deletionScheduledFor': null}))
          .account();
      expect(none.scheduledFor, isNull);
    });

    test(
      'POST /v1/account/deletion → 202 with the date; DELETE cancels',
      () async {
        final post = _Adapter(202, {
          'deletionScheduledFor': '2026-10-15T10:00:00Z',
        });
        expect(
          await ApiAccountRepository(_api(post)).requestDeletion(),
          _purge,
        );
        expect(post.requests.single.method, 'POST');
        expect(post.requests.single.path, '/v1/account/deletion');

        final del = _Adapter(200, {'deletionScheduledFor': null});
        await ApiAccountRepository(_api(del)).cancelDeletion();
        expect(del.requests.single.method, 'DELETE');
        expect(del.requests.single.path, '/v1/account/deletion');
      },
    );

    test(
      '403 account_deletion_pending is recognised and never retried',
      () async {
        final adapter = _Adapter(403, {'code': 'account_deletion_pending'});
        try {
          await _api(adapter).push(deviceId: 'd', mutations: const []);
          fail('expected ApiException');
        } on ApiException catch (e) {
          expect(e.isDeletionPending, isTrue);
          expect(e.isRetryable, isFalse);
        }
        const other = ApiException(code: 'forbidden', status: 403);
        expect(other.isDeletionPending, isFalse);
      },
    );

    test('409 account_deletion_in_progress from "Keep my account" is '
        'recognised and never retried', () async {
      final adapter = _Adapter(409, {'code': 'account_deletion_in_progress'});
      try {
        await ApiAccountRepository(_api(adapter)).cancelDeletion();
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.isDeletionInProgress, isTrue);
        expect(e.isRetryable, isFalse);
      }
    });
  });

  group('sync holds on 403 account_deletion_pending', () {
    late AppDatabase db;
    late OutboxRepository outbox;
    late _PendingApi api;
    late _Auth auth;
    late SyncService sync;
    late StreamController<bool> online;
    late int holds;
    final time = testTime();

    setUp(() async {
      db = memoryDb();
      final kv = KvStore(db);
      outbox = OutboxRepository(db, const Ids());
      final progress = ProgressRepository(db, kv);
      api = _PendingApi();
      auth = _Auth(_alice);
      online = StreamController<bool>();
      holds = 0;
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
        dataKeys: DataKeyRepository(MemorySecureStore()),
        kv: kv,
        clock: time.clock,
        ids: const Ids(),
        connectivity: online.stream,
        pull: (_, _) async {},
        alreadyPulled: (_) async => true,
        onUnder13: () async {},
        onDeletionPending: () => holds++,
      );
      await CheckInRepository(
        db,
        outbox,
        time,
      ).save(id: const Ids().v7(), mood: moodById('calm')!);
    });

    tearDown(() async {
      await sync.dispose();
      unawaited(online.close());
      await db.close();
    });

    test('rows are kept as they are (no backoff, no dead letter) and nothing '
        'is retried until released', () async {
      await sync.kick();
      expect(api.pushCalls, 1);
      expect(holds, 1);
      expect(sync.isHeldForDeletion, isTrue);
      expect(sync.phase.value, SyncPhase.waiting);
      expect(await db.select(db.deadLetters).get(), isEmpty);
      final rows = await db.select(db.outbox).get();
      expect(rows, hasLength(1));
      expect(rows.single.attempts, 0);

      // Heartbeat, resume, local writes: still nothing goes out.
      await sync.kick();
      sync.onResume();
      await sync.kick();
      expect(api.pushCalls, 1);
      expect(holds, 1);

      // "Keep my account" succeeded.
      api.pending = false;
      sync.releaseDeletionHold();
      await Future<void>.delayed(Duration.zero);
      await sync.kick();
      expect(api.accepted, hasLength(1));
      expect(await outbox.count(), 0);
      expect(sync.isHeldForDeletion, isFalse);
    });

    test('another account signing in is never held', () async {
      await sync.kick();
      expect(sync.isHeldForDeletion, isTrue);
      auth.signIn(_bob);
      api.pending = false;
      await sync.kick();
      expect(sync.isHeldForDeletion, isFalse);
      expect(api.accepted, hasLength(1));
    });
  });

  group('DeletionHold', () {
    late AppDatabase db;
    late _Auth auth;
    late _Account account;
    late ProviderContainer container;

    setUp(() {
      db = memoryDb();
      auth = _Auth(_alice);
      account = _Account();
      container = ProviderContainer(
        overrides: [
          ...testOverrides(db: db, auth: auth),
          accountRepositoryProvider.overrideWithValue(account),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('check after sign-in: the date when scheduled, null otherwise or '
        'when the server is unreachable', () async {
      final hold = container.read(deletionHoldProvider.notifier);
      expect(await hold.check(), isNull);

      account.scheduled = _purge;
      final pending = await hold.check();
      expect(pending?.scheduledFor, _purge);
      expect(container.read(deletionHoldProvider), pending);

      account.failStatus = const ApiException(code: 'x', isNetwork: true);
      expect(await hold.check(), isNull);
    });

    test('a sync 403 holds at once, then fills in the date', () async {
      account.scheduled = _purge;
      final hold = container.read(deletionHoldProvider.notifier);
      final report = hold.reportFromSync();
      expect(container.read(deletionHoldProvider)?.scheduledFor, isNull);
      await report;
      expect(container.read(deletionHoldProvider)?.scheduledFor, _purge);
    });

    test(
      'keep: DELETE, then released; a failed keep changes nothing',
      () async {
        account.scheduled = _purge;
        final hold = container.read(deletionHoldProvider.notifier);
        await hold.check();

        account.failCancel = const ApiException(code: 'x', isNetwork: true);
        await expectLater(hold.keep(), throwsA(isA<ApiException>()));
        expect(container.read(deletionHoldProvider), isNotNull);

        account.failCancel = null;
        expect(await hold.keep(), KeepResult.kept);
        expect(account.cancels, 1);
        expect(container.read(deletionHoldProvider), isNull);
      },
    );

    test('keep after the grace period (409 account_deletion_in_progress): '
        'too late, the hold stays until the person signs out', () async {
      account.scheduled = _purge;
      final hold = container.read(deletionHoldProvider.notifier);
      await hold.check();
      account.failCancel = const ApiException(
        code: 'account_deletion_in_progress',
        status: 409,
      );
      expect(await hold.keep(), KeepResult.tooLate);
      expect(container.read(deletionHoldProvider), isNotNull);
      expect(account.cancels, 0);

      await hold.letGo();
      expect(auth.currentUser, isNull);
      expect(container.read(deletionHoldProvider), isNull);
    });

    test('let it go: the sign-out wipe, back to Welcome', () async {
      account.scheduled = _purge;
      final hold = container.read(deletionHoldProvider.notifier);
      await hold.check();
      await hold.letGo();
      expect(auth.currentUser, isNull);
      expect(container.read(deletionHoldProvider), isNull);
      expect(
        container.read(gateControllerProvider).stage,
        OnboardingStage.welcome,
      );
      expect(account.cancels, 0); // the deletion stays scheduled
    });

    test('signing out drops the hold', () async {
      // Keep the auth stream alive for the listener.
      final sub = container.listen(authUserProvider, (_, _) {});
      addTearDown(sub.close);
      account.scheduled = _purge;
      final hold = container.read(deletionHoldProvider.notifier);
      await hold.check();
      await Future<void>.delayed(Duration.zero);
      auth.signIn(null);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(deletionHoldProvider), isNull);
    });
  });

  test('right after the deletion request, the wipe\'s DELETE /v1/devices '
      'gets 403 account_deletion_pending: the wipe still completes', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final auth = _Auth(_alice);
    final api = _DeletingApi();
    final messaging = FakeMessaging();
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(db: db, auth: auth),
        auraApiProvider.overrideWithValue(api),
        pushMessagingProvider.overrideWithValue(messaging),
      ],
    );
    addTearDown(container.dispose);
    final kv = KvStore(db);
    await kv.setJson(KvKeys.pushRegistered, {
      'userId': _alice.id,
      'token': 'fcm-1',
    });
    await CheckInRepository(
      db,
      OutboxRepository(db, const Ids()),
      testTime(),
    ).save(id: const Ids().v7(), mood: moodById('calm')!);

    // What the deletion screen does: POST, then the sign-out wipe.
    final date = await container
        .read(accountRepositoryProvider)!
        .requestDeletion();
    expect(date, _purge);
    await container.read(signOutServiceProvider).signOut();

    expect(api.deleteDeviceCalls, 1); // tried, refused, carried on
    expect(messaging.deleteCalls, 1); // the local FCM token still goes
    expect(auth.currentUser, isNull);
    expect(await db.select(db.checkIns).get(), isEmpty);
    expect(await kv.get(KvKeys.pushRegistered), isNull);
    expect(
      container.read(gateControllerProvider).stage,
      OnboardingStage.welcome,
    );
  });
}

/// The server after `POST /v1/account/deletion`: every other route answers
/// `403 account_deletion_pending` (device tokens are already gone).
class _DeletingApi extends AuraApi {
  _DeletingApi() : super(baseUrl: 'http://test', accessToken: () async => 't');

  int deleteDeviceCalls = 0;
  static const _pending = ApiException(
    code: 'account_deletion_pending',
    status: 403,
  );

  @override
  Future<AccountStatus> requestDeletion() async =>
      const AccountStatus(deletionScheduledFor: '2026-10-15T10:00:00Z');

  @override
  Future<void> deleteDevice(String token) async {
    deleteDeviceCalls++;
    throw _pending;
  }

  @override
  Future<void> putDevice({
    required String token,
    required String platform,
  }) async => throw _pending;

  @override
  Future<PushResponse> push({
    required String deviceId,
    required List<SyncMutation> mutations,
  }) async => throw _pending;
}
