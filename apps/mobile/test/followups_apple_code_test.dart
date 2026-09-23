import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/auth/social_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_social_fakes.dart';

/// Sign in with Apple token revocation, app side (App Review 5.1.1(v); PRD F8
/// REQ-ACC-11 "Apple token revoked"; contracts/api/v1.md "Sign in with Apple
/// token"): after a native Apple sign-in the one-time authorization code goes
/// to `POST /v1/account/apple-auth`, once, in the background. Sign-in never
/// waits for it and never fails because of it.

/// Apple's sheet, with the one-time code it hands back next to the ID token.
class _AppleWithCode implements NativeAppleSignIn {
  _AppleWithCode([this.code = 'c-one-time-code']);

  final String? code;

  @override
  Future<SocialCredential> signIn() async => SocialCredential(
    idToken: 'apple-id-token',
    rawNonce: 'raw-nonce-a',
    authorizationCode: code,
  );
}

/// Answers every request with [status] + [body]; records them.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, [this.body = const {}]);

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
    if (status == 0) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      status == 204 ? '' : jsonEncode(body),
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

void main() {
  group(
    'SocialSignInService hands Apple’s code over after the session exists',
    () {
      test(
        'native Apple: the code goes out once, after the Supabase exchange',
        () async {
          final exchange = FakeExchange();
          final order = <String>[];
          final codes = <String>[];
          final service = SocialSignInService(
            config: iosSocial,
            exchange: exchange,
            google: FakeGoogle(),
            apple: _AppleWithCode(),
            onAppleAuthorizationCode: (code) {
              order.add('code after ${exchange.idTokens.length} exchange(s)');
              codes.add(code);
            },
          );
          expect(
            await service.signIn(SocialProvider.apple),
            SocialSignInResult.signedIn,
          );
          expect(codes, ['c-one-time-code']);
          expect(order, ['code after 1 exchange(s)']);
          // Supabase gets the ID token and nonce only — never the code.
          expect(exchange.idTokens.single, (
            SocialProvider.apple,
            'apple-id-token',
            null,
            'raw-nonce-a',
          ));
        },
      );

      test('no code, a failed exchange, or Google → nothing is sent', () async {
        final codes = <String>[];
        void sink(String c) => codes.add(c);

        final noCode = SocialSignInService(
          config: iosSocial,
          exchange: FakeExchange(),
          apple: _AppleWithCode(null),
          onAppleAuthorizationCode: sink,
        );
        await noCode.signIn(SocialProvider.apple);

        final failing = FakeExchange()
          ..fail = const AuthFailure(AuthFailureKind.notConfigured);
        final refused = SocialSignInService(
          config: iosSocial,
          exchange: failing,
          apple: _AppleWithCode(),
          onAppleAuthorizationCode: sink,
        );
        await expectLater(
          refused.signIn(SocialProvider.apple),
          throwsA(isA<AuthFailure>()),
        );

        final google = SocialSignInService(
          config: iosSocial,
          exchange: FakeExchange(),
          google: FakeGoogle(),
          apple: _AppleWithCode(),
          onAppleAuthorizationCode: sink,
        );
        await google.signIn(SocialProvider.google);
        expect(codes, isEmpty);
      });

      test('a sink that throws never breaks the sign-in', () async {
        final service = SocialSignInService(
          config: iosSocial,
          exchange: FakeExchange(),
          apple: _AppleWithCode(),
          onAppleAuthorizationCode: (_) => throw StateError('boom'),
        );
        expect(
          await service.signIn(SocialProvider.apple),
          SocialSignInResult.signedIn,
        );
      });

      test('the credential never prints its code', () {
        const c = SocialCredential(
          idToken: 't',
          authorizationCode: 'secret-code',
        );
        expect('$c', isNot(contains('secret-code')));
      });
    },
  );

  group('linkAppleAuthorization → POST /v1/account/apple-auth', () {
    test('posts the code with the session token', () async {
      final adapter = _Adapter(204);
      await linkAppleAuthorization(_api(adapter), 'c-one-time-code');
      final r = adapter.requests.single;
      expect(r.method, 'POST');
      expect(r.path, '/v1/account/apple-auth');
      expect(r.headers['Authorization'], 'Bearer jwt');
      expect(r.data, {'authorizationCode': 'c-one-time-code'});
    });

    test('every failure is ignored: no Apple key on the server (503), a '
        'rejected code, offline, or no API in this build', () async {
      for (final adapter in [
        _Adapter(503, {'code': 'apple_unavailable', 'message': 'x'}),
        _Adapter(400, {'code': 'apple_code_rejected', 'message': 'x'}),
        _Adapter(409, {'code': 'apple_identity_mismatch', 'message': 'x'}),
        _Adapter(0),
      ]) {
        await expectLater(
          linkAppleAuthorization(_api(adapter), 'code'),
          completes,
        );
        expect(adapter.requests, hasLength(1));
      }
      await expectLater(linkAppleAuthorization(null, 'code'), completes);
    });
  });
}
