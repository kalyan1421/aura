import 'dart:convert';
import 'dart:math';

import 'package:aura/src/core/net/api_models.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/remote_config/device_ban.dart';
import 'package:aura/src/core/remote_config/install_id.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/rooms/rooms_api.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Device bans on the phone (PRD 19 REQ-ADM-14): a random install id kept in
/// secure storage (so it survives sign-out, and on iOS a reinstall), sent
/// only on the profile, push registration and room match; a
/// `403 device_banned` shows the calm "This device can't use Aura" screen.

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, [this.body = const <String, dynamic>{}]);

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

Dio _dio(_Adapter adapter) => Dio(
  BaseOptions(
    baseUrl: 'http://test',
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
  ),
)..httpClientAdapter = adapter;

const _banned = {
  'code': 'device_banned',
  'message': "This device can't use Aura.",
};

const _profile = ProfileRequest(
  birthDate: '1994-07-21',
  uiLocale: 'en',
  timezone: 'Asia/Kolkata',
);

void main() {
  group('InstallId', () {
    test('made once (32 random bytes, base64url), kept in secure storage and '
        'reused by a later install of the same keychain', () async {
      final secure = MemorySecureStore();
      final a = InstallId(secure, random: Random(1));
      final id = await a.value();
      expect(id, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(await a.value(), id);
      expect(secure.values[InstallId.secureKey], id);
      // The app deleted and reinstalled (iOS keeps the Keychain item).
      expect(await InstallId(secure, random: Random(2)).value(), id);
      // Another phone.
      expect(
        await InstallId(MemorySecureStore(), random: Random(3)).value(),
        isNot(id),
      );
    });

    test(
      'a damaged stored value is replaced; storage failing → no header',
      () async {
        final secure = MemorySecureStore({InstallId.secureKey: 'x'});
        final id = await InstallId(secure).value();
        expect(id, isNot('x'));
        expect(await InstallId(_Broken()).headers(), isEmpty);
      },
    );

    test(
      'headers: the id (and the platform where known), nothing else',
      () async {
        final headers = await InstallId(MemorySecureStore()).headers();
        expect(headers.keys, contains(InstallId.header));
        expect(
          headers.keys.toSet().difference({
            InstallId.header,
            InstallId.platformHeader,
          }),
          isEmpty,
        );
      },
    );
  });

  group('AuraApi', () {
    const headers = {
      'X-Aura-Install': 'install-abc_123',
      'X-Aura-Platform': 'ios',
    };

    AuraApi api(_Adapter adapter, {void Function()? onBanned}) => AuraApi(
      baseUrl: 'http://test',
      accessToken: () async => 'jwt',
      dio: _dio(adapter),
      deviceHeaders: () async => headers,
      onDeviceBanned: onBanned,
    );

    test(
      'the install id goes only with the profile and push registration',
      () async {
        final ok = _Adapter(200, {'profile': {}, 'snapshot': null});
        await api(ok).postProfile(_profile);
        final devices = _Adapter(204);
        await api(devices).putDevice(token: 'fcm', platform: 'ios');
        final other = _Adapter(200, {'deletionScheduledFor': null});
        await api(other).account();
        await api(_Adapter(204)).deleteDevice('fcm');
        expect(
          ok.requests.single.headers,
          containsPair('X-Aura-Install', 'install-abc_123'),
        );
        expect(
          ok.requests.single.headers,
          containsPair('X-Aura-Platform', 'ios'),
        );
        expect(
          ok.requests.single.headers,
          containsPair('Authorization', 'Bearer jwt'),
        );
        expect(
          devices.requests.single.headers,
          containsPair('X-Aura-Install', 'install-abc_123'),
        );
        expect(
          other.requests.single.headers.keys,
          isNot(contains('X-Aura-Install')),
        );
      },
    );

    test(
      '403 device_banned: a non-retryable error, and the hook is told once',
      () async {
        var told = 0;
        final err = await api(_Adapter(403, _banned), onBanned: () => told++)
            .postProfile(_profile)
            .then<Object?>((_) => null, onError: (Object e) => e);
        expect(
          err,
          isA<ApiException>()
              .having((e) => e.isDeviceBanned, 'isDeviceBanned', isTrue)
              .having((e) => e.isRetryable, 'isRetryable', isFalse),
        );
        await Future<void>.delayed(Duration.zero);
        expect(told, 1);
        // Other 403s are not a device ban.
        await api(
          _Adapter(403, {'code': 'account_closed', 'message': 'x'}),
          onBanned: () => told++,
        ).snapshot().then((_) {}, onError: (Object _) {});
        await Future<void>.delayed(Duration.zero);
        expect(told, 1);
      },
    );
  });

  group('HttpRoomsApi', () {
    test('the match carries the install id; other rooms calls do not; a ban '
        'from any of them tells the hook', () async {
      var told = 0;
      final adapter = _Adapter(403, _banned);
      final rooms = HttpRoomsApi(
        baseUrl: 'http://test',
        accessToken: () async => 'jwt',
        dio: _dio(adapter),
        deviceHeaders: () async => {'X-Aura-Install': 'install-abc_123'},
        onDeviceBanned: () => told++,
      );
      await expectLater(
        rooms.match(
          const MatchRequest(quadrant: Quadrant.rain, moodId: 'lonely'),
        ),
        throwsA(
          isA<ApiException>().having((e) => e.isDeviceBanned, 'ban', isTrue),
        ),
      );
      expect(
        adapter.requests.single.headers,
        containsPair('X-Aura-Install', 'install-abc_123'),
      );
      expect(
        adapter.requests.single.headers,
        containsPair('Authorization', 'Bearer jwt'),
      );
      await Future<void>.delayed(Duration.zero); // the hook runs in a microtask
      expect(told, 1);
      await expectLater(rooms.rooms(), throwsA(isA<ApiException>()));
      expect(
        adapter.requests.last.headers.keys,
        isNot(contains('X-Aura-Install')),
      );
    });
  });

  group('DeviceBannedScreen', () {
    Future<void> pump(WidgetTester tester, {bool signedIn = true}) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final db = memoryDb();
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...testOverrides(db: db),
            authUserProvider.overrideWith(
              (ref) => Stream.value(signedIn ? const AuthUser(id: 'u1') : null),
            ),
          ],
          child: localized(
            const DeviceBannedScreen(
              reviewName: 'Grievance Officer',
              reviewEmail: 'grievance@example.com',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('calm, no reason; review, delete, sign out, help', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text("This device can't use Aura"), findsOneWidget);
      expect(find.text("Aura isn't available on this phone."), findsOneWidget);
      expect(
        find.byKey(const ValueKey('device-banned-review')),
        findsOneWidget,
      );
      expect(find.textContaining('grievance@example.com'), findsOneWidget);
      // The in-app review (REQ-SAFE-11): a ticket id at once, no mail app.
      expect(
        find.byKey(const ValueKey('device-banned-review-form')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('device-banned-sign-out')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('device-banned-delete')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('device-banned-delete')),
        findsOneWidget,
      );
      expect(
        find.textContaining('rules'),
        findsNothing,
        reason: 'no reason given',
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'signed out (a new sign-in was refused): review and help only',
      (tester) async {
        await pump(tester, signedIn: false);
        expect(find.text("This device can't use Aura"), findsOneWidget);
        expect(
          find.byKey(const ValueKey('device-banned-sign-out')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('device-banned-delete')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('device-banned-review')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );

    test('report() shows the screen through the presenter, once per call', () {
      final shown = <int>[];
      final container = ProviderContainer(
        overrides: [
          deviceBannedPresenterProvider.overrideWithValue(_Presenter(shown)),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(deviceBannedProvider), isFalse);
      container.read(deviceBannedProvider.notifier).report();
      expect(container.read(deviceBannedProvider), isTrue);
      expect(shown, [1]);
    });
  });
}

class _Presenter implements DeviceBannedPresenter {
  _Presenter(this.shown);

  final List<int> shown;

  @override
  void show() => shown.add(shown.length + 1);
}

class _Broken implements SecureStore {
  @override
  Future<String?> read(String key) async =>
      throw PlatformException(code: 'keychain');

  @override
  Future<void> write(String key, String value) async =>
      throw PlatformException(code: 'keychain');

  @override
  Future<void> delete(String key) async {}
}
