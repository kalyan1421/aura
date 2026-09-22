import 'dart:async';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/push/push_messaging.dart';
import 'package:aura/src/features/push/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class FakeAuth implements AuthRepository {
  FakeAuth([this.user]);

  AuthUser? user;
  final _users = StreamController<AuthUser?>.broadcast();

  void emit(AuthUser? u) {
    user = u;
    _users.add(u);
  }

  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> watchUser() => _users.stream;
  @override
  Future<String?> accessToken() async => user == null ? null : 'jwt';
  @override
  Future<void> sendEmailCode(String email) async {}
  @override
  Future<void> verifyEmailCode(String email, String code) async {}
  @override
  Future<void> signOut() async => emit(null);
}

class DevicesApi extends AuraApi {
  DevicesApi() : super(baseUrl: 'http://test', accessToken: () async => 't');

  final List<(String token, String platform)> puts = [];
  final List<String> deletes = [];
  ApiException? failNextPut;

  @override
  Future<void> putDevice({
    required String token,
    required String platform,
  }) async {
    final f = failNextPut;
    if (f != null) {
      failNextPut = null;
      throw f;
    }
    puts.add((token, platform));
  }

  @override
  Future<void> deleteDevice(String token) async => deletes.add(token);
}

const _alice = AuthUser(id: 'user-a', email: 'a@aura.test');

void main() {
  late AppDatabase db;
  late KvStore kv;
  late FakeMessaging messaging;
  late FakeAuth auth;
  late DevicesApi api;
  late StreamController<void> synced;
  late PushService push;
  late bool hasProfile;
  late bool hasCheckedIn;
  late int sleeps;

  PushService build({bool ios = false}) {
    messaging = FakeMessaging(ios: ios);
    return push = PushService(
      messaging: messaging,
      auth: auth,
      api: api,
      kv: kv,
      hasProfile: () async => hasProfile,
      hasCheckedIn: () async => hasCheckedIn,
      clock: testTime().clock,
      syncSucceeded: synced.stream,
      sleep: (_) async => sleeps++,
    )..start();
  }

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await push.settled(); // everything queued so far has run
  }

  setUp(() {
    db = memoryDb();
    kv = KvStore(db);
    auth = FakeAuth(_alice);
    api = DevicesApi();
    synced = StreamController<void>.broadcast();
    hasProfile = true;
    hasCheckedIn = false;
    sleeps = 0;
  });

  tearDown(() async {
    await push.dispose();
    await synced.close();
    await db.close();
  });

  test('nothing at launch: no prompt, no token, no registration before the '
      'first check-in', () async {
    build();
    messaging.granted = PushPermission.authorized; // e.g. Android 12
    auth.emit(_alice); // app start / sign-in
    synced.add(null); // a successful sync
    messaging.refresh.add('fcm-9'); // a stray token event
    await settle();

    // Offered before any check-in exists: the explainer isn't even shown.
    var shown = 0;
    await push.offerAfterCheckIn(() async {
      shown++;
      return SoftAskAnswer.allow;
    });
    await settle();

    expect(shown, 0);
    expect(messaging.requests, isEmpty);
    expect(messaging.tokenCalls, 0);
    expect(messaging.autoInit, isNull); // auto-init stays off
    expect(api.puts, isEmpty);
    expect(await kv.get(KvKeys.pushSoftAsk), isNull);
  });

  test('after the first check-in: explainer → Allow → OS prompt → token '
      'registered; the explainer never shows again', () async {
    build();
    hasCheckedIn = true;
    var shown = 0;
    await push.offerAfterCheckIn(() async {
      shown++;
      return SoftAskAnswer.allow;
    });
    await settle();

    expect(shown, 1);
    expect(messaging.requests, [false]); // one real OS prompt
    expect(messaging.autoInit, isTrue);
    expect(api.puts, [('fcm-1', 'android')]);
    expect(await kv.getJson(KvKeys.pushRegistered), {
      'userId': 'user-a',
      'token': 'fcm-1',
    });
    expect((await kv.getJson(KvKeys.pushSoftAsk))!['answer'], 'allow');

    await push.offerAfterCheckIn(() async {
      shown++;
      return SoftAskAnswer.allow;
    });
    // Re-running (app start, sync) doesn't re-register an unchanged token.
    auth.emit(_alice);
    synced.add(null);
    await settle();
    expect(shown, 1);
    expect(api.puts, hasLength(1));
  });

  test('dismissing the explainer records nothing: it is offered again after '
      'the next check-in', () async {
    build();
    hasCheckedIn = true;
    await push.offerAfterCheckIn(() async => null);
    expect(await push.shouldOffer(), isTrue);
    expect(messaging.requests, isEmpty);
  });

  test('Android "Not now" never fires the OS prompt and registers nothing '
      'while notifications are off', () async {
    build();
    hasCheckedIn = true;
    messaging.granted = PushPermission.denied; // Android 13+, never asked
    await push.offerAfterCheckIn(() async => SoftAskAnswer.notNow);
    await settle();
    expect(messaging.requests, isEmpty);
    expect(api.puts, isEmpty);
    expect((await kv.getJson(KvKeys.pushSoftAsk))!['answer'], 'notNow');
  });

  test('iOS "Not now" registers provisional authorisation only (no prompt), '
      'then registers after the APNs token', () async {
    build(ios: true);
    hasCheckedIn = true;
    await push.offerAfterCheckIn(() async => SoftAskAnswer.notNow);
    await settle();
    expect(messaging.requests, [true]); // provisional only
    expect(messaging.apnsCalls, greaterThan(0));
    expect(api.puts, [('fcm-1', 'ios')]);
  });

  test('iOS without an APNs token (simulator): owed, then registered after '
      'the next successful sync once it arrives', () async {
    build(ios: true);
    hasCheckedIn = true;
    messaging.apns = null;
    await push.offerAfterCheckIn(() async => SoftAskAnswer.allow);
    await settle();
    expect(messaging.tokenCalls, 0); // FCM is never asked before APNs
    expect(sleeps, greaterThan(0)); // it waited, then gave up gracefully
    expect(api.puts, isEmpty);
    expect(await kv.get(KvKeys.pushPending), '1');

    messaging.apns = 'apns-late';
    synced.add(null);
    await settle();
    expect(api.puts, [('fcm-1', 'ios')]);
    expect(await kv.get(KvKeys.pushPending), isNull);
  });

  test('offline: the registration is queued and retried on the next '
      'successful sync', () async {
    build();
    hasCheckedIn = true;
    api.failNextPut = const ApiException(code: 'connectionError', isNetwork: true);
    await push.offerAfterCheckIn(() async => SoftAskAnswer.allow);
    await settle();
    expect(api.puts, isEmpty);
    expect(await kv.get(KvKeys.pushPending), '1');
    expect(await kv.get(KvKeys.pushRegistered), isNull);

    synced.add(null);
    await settle();
    expect(api.puts, [('fcm-1', 'android')]);
    expect(await kv.get(KvKeys.pushPending), isNull);
  });

  test('waits for the profile to reach the server', () async {
    build();
    hasCheckedIn = true;
    hasProfile = false;
    await push.offerAfterCheckIn(() async => SoftAskAnswer.allow);
    await settle();
    expect(api.puts, isEmpty);
    expect(await kv.get(KvKeys.pushPending), '1');

    hasProfile = true;
    synced.add(null);
    await settle();
    expect(api.puts, hasLength(1));
  });

  test('a token refresh re-registers and drops the old token', () async {
    build();
    hasCheckedIn = true;
    await push.offerAfterCheckIn(() async => SoftAskAnswer.allow);
    await settle();
    expect(api.puts, [('fcm-1', 'android')]);

    messaging.fcmToken = 'fcm-2'; // FCM rotated the token
    messaging.refresh.add('fcm-2');
    await settle();
    expect(api.puts, [('fcm-1', 'android'), ('fcm-2', 'android')]);
    expect(api.deletes, ['fcm-1']);
    expect((await kv.getJson(KvKeys.pushRegistered))!['token'], 'fcm-2');
  });

  test('sign-out unregisters: DELETE with the current token, deleteToken, '
      'auto-init off', () async {
    build();
    hasCheckedIn = true;
    await push.offerAfterCheckIn(() async => SoftAskAnswer.allow);
    await settle();

    await push.unregister();
    expect(api.deletes, ['fcm-1']);
    expect(messaging.deleteCalls, 1);
    expect(messaging.autoInit, isFalse);
    expect(await kv.get(KvKeys.pushRegistered), isNull);
    expect(await kv.get(KvKeys.pushPending), isNull);

    // The auth stream then reports the sign-out: nothing more to do.
    auth.emit(null);
    await settle();
    expect(messaging.deleteCalls, 1);
    expect(api.puts, hasLength(1));
  });

  test('sign-out offline: deleteToken is owed and paid before the next '
      'registration', () async {
    build();
    hasCheckedIn = true;
    await push.offerAfterCheckIn(() async => SoftAskAnswer.allow);
    await settle();

    messaging.deleteError = Exception('SERVICE_NOT_AVAILABLE');
    await push.unregister();
    expect(await kv.get(KvKeys.pushDeleteOwed), '1');

    messaging.deleteError = null;
    auth.emit(null);
    await settle();
    expect(messaging.deleteCalls, 2);
    expect(await kv.get(KvKeys.pushDeleteOwed), isNull);
  });

  test('a session that ends elsewhere (revoked) still drops the local token',
      () async {
    build();
    hasCheckedIn = true;
    await push.offerAfterCheckIn(() async => SoftAskAnswer.allow);
    await settle();

    auth.emit(null);
    await settle();
    expect(messaging.deleteCalls, 1);
    expect(await kv.get(KvKeys.pushRegistered), isNull);
  });

  test('only a short machine `type` is ever read from a payload', () {
    expect(
      pushType({'type': 'capsule_unlocked', 'id': 'abc', 'mood': 'sad'}),
      'capsule_unlocked',
    );
    expect(pushType({'type': 'Still feeling anxious?'}), 'unrecognised');
    expect(pushType({'id': 'abc'}), isNull);
    expect(pushType({'type': 42}), isNull);
  });

  test('push off (Firebase failed to start): inert, never offers', () async {
    push = PushService(
      messaging: null,
      auth: auth,
      api: api,
      kv: kv,
      hasProfile: () async => true,
      hasCheckedIn: () async => true,
    )..start();
    expect(push.isAvailable, isFalse);
    expect(await push.shouldOffer(), isFalse);
    await push.register();
    await push.unregister();
    expect(api.puts, isEmpty);
    expect(api.deletes, isEmpty);
  });
}
