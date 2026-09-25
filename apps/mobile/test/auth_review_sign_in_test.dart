import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/src/app.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'helpers.dart';

/// App Review sign-in (docs/setup/app-review.md): the review account can't
/// receive an email code, so when Supabase refuses a typed code the app asks
/// `POST /v1/auth/review-sign-in` with the same email + code and, on success,
/// makes that session its Supabase session. Nothing in the UI hints at it: a
/// wrong code still reads exactly like a wrong code.
///
/// Runs the REAL SupabaseAuthRepository over a real Supabase client whose
/// HTTP is a MockClient (GoTrue's /verify refuses every code, /user answers
/// for the minted token).

const _reviewEmail = 'review@aura.test';
const _reviewCode = '739150';
const _userId = '0199a1b2-0000-7000-8000-00000000abcd';

String _b64(Map<String, Object?> m) =>
    base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');

/// An unsigned JWT the client can decode (the client never checks signatures).
final String _accessToken = [
  _b64({'alg': 'HS256', 'typ': 'JWT'}),
  _b64({
    'sub': _userId,
    'email': _reviewEmail,
    'aud': 'authenticated',
    'role': 'authenticated',
    'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
  }),
  'c2ln',
].join('.');

class _FakeReview implements ReviewSignInApi {
  final calls = <(String, String)>[];

  @override
  Future<ReviewSession?> signIn(String email, String code) async {
    calls.add((email, code));
    return email.trim().toLowerCase() == _reviewEmail && code == _reviewCode
        ? ReviewSession(accessToken: _accessToken, refreshToken: 'rt-review')
        : null;
  }
}

/// GoTrue: every typed code is refused (403 otp_expired, what GoTrue answers
/// for a wrong or old code); `/user` answers for the minted token.
class _GoTrue {
  final requests = <String>[];
  bool offline = false;

  late final http.Client client = MockClient((req) async {
    requests.add('${req.method} ${req.url.path}');
    if (offline) throw http.ClientException('offline');
    if (req.url.path.endsWith('/auth/v1/otp')) {
      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (req.url.path.endsWith('/auth/v1/verify')) {
      return http.Response(
        jsonEncode({
          'code': 403,
          'error_code': 'otp_expired',
          'msg': 'Token has expired or is invalid',
        }),
        403,
        headers: {'content-type': 'application/json'},
      );
    }
    if (req.url.path.endsWith('/auth/v1/user') &&
        req.headers['Authorization'] == 'Bearer $_accessToken') {
      return http.Response(
        jsonEncode({
          'id': _userId,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': _reviewEmail,
          'app_metadata': {'provider': 'email'},
          'user_metadata': <String, Object?>{},
          'created_at': '2026-09-20T10:00:00Z',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{"msg":"unexpected"}', 500);
  });
}

sb.SupabaseClient _client(_GoTrue gotrue) => sb.SupabaseClient(
  'http://supabase.test',
  'anon-key',
  httpClient: gotrue.client,
  authOptions: const sb.AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: sb.AuthFlowType.implicit,
  ),
);

void main() {
  group('SupabaseAuthRepository.verifyEmailCode', () {
    test('Supabase refuses the review code → review-sign-in → the session is set (signed in as the review account)', () async {
      final gotrue = _GoTrue();
      final review = _FakeReview();
      final client = _client(gotrue);
      addTearDown(client.dispose);
      final repo = SupabaseAuthRepository(client, reviewSignIn: review);
      final events = <sb.AuthChangeEvent>[];
      final sub = client.auth.onAuthStateChange.listen(
        (s) => events.add(s.event),
      );
      addTearDown(sub.cancel);

      await repo.verifyEmailCode(' Review@Aura.test ', _reviewCode);

      expect(review.calls, [(' Review@Aura.test ', _reviewCode)]);
      expect(repo.currentUser?.id, _userId);
      expect(await repo.accessToken(), _accessToken);
      expect(client.auth.currentSession?.refreshToken, 'rt-review');
      await Future<void>.delayed(Duration.zero);
      expect(events, contains(sb.AuthChangeEvent.signedIn));
      // Supabase was asked first, like any sign-in.
      expect(gotrue.requests.first, 'POST /auth/v1/verify');
    });

    test('a wrong code (not the review account) keeps the ORIGINAL failure and no session', () async {
      final gotrue = _GoTrue();
      final review = _FakeReview();
      final client = _client(gotrue);
      addTearDown(client.dispose);
      final repo = SupabaseAuthRepository(client, reviewSignIn: review);

      await expectLater(
        repo.verifyEmailCode('someone@aura.test', '123456'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.kind,
            'kind',
            AuthFailureKind.expired,
          ),
        ),
      );
      expect(review.calls, [('someone@aura.test', '123456')]);
      expect(repo.currentUser, isNull);

      // The review email with a wrong code: same answer.
      await expectLater(
        repo.verifyEmailCode(_reviewEmail, '000000'),
        throwsA(isA<AuthFailure>()),
      );
      expect(repo.currentUser, isNull);
    });

    test('offline: no review call, the network failure as before', () async {
      final gotrue = _GoTrue()..offline = true;
      final review = _FakeReview();
      final client = _client(gotrue);
      addTearDown(client.dispose);
      final repo = SupabaseAuthRepository(client, reviewSignIn: review);
      await expectLater(
        repo.verifyEmailCode(_reviewEmail, _reviewCode),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.kind,
            'kind',
            AuthFailureKind.network,
          ),
        ),
      );
      expect(review.calls, isEmpty);
    });

    test('a build without the API has no fallback', () async {
      final client = _client(_GoTrue());
      addTearDown(client.dispose);
      final repo = SupabaseAuthRepository(client);
      await expectLater(
        repo.verifyEmailCode(_reviewEmail, _reviewCode),
        throwsA(isA<AuthFailure>()),
      );
      expect(repo.currentUser, isNull);
    });
  });

  group('HttpReviewSignInApi', () {
    test(
      'only a 200 with both tokens is a session; anything else is null',
      () async {
        // Covered through Dio in the server e2e; here: the shape handling.
        final ok = await _api({
          'access_token': 'a',
          'refresh_token': 'r',
          'expires_in': 3600,
          'token_type': 'bearer',
        }, 200).signIn('r@a.test', '739150');
        expect(ok?.accessToken, 'a');
        expect(ok?.refreshToken, 'r');
        for (final (body, status) in [
          (<String, Object?>{'code': 'invalid_code'}, 401),
          (<String, Object?>{'code': 'not_found'}, 404),
          (<String, Object?>{'code': 'rate_limited'}, 429),
          (<String, Object?>{'access_token': 'a'}, 200),
        ]) {
          expect(await _api(body, status).signIn('r@a.test', '1'), isNull);
        }
      },
    );
  });

  group('the sign-in screen (no UI hint)', () {
    Future<ProviderContainer> onboarding(
      WidgetTester tester,
      AuthRepository auth,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: testOverrides(
          db: memoryDb(),
          auth: auth,
          gate: const GateState(stage: OnboardingStage.signIn),
        ),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const AuraApp()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      return container;
    }

    Future<void> typeCode(
      WidgetTester tester,
      String email,
      String code,
    ) async {
      await tester.enterText(find.byKey(const ValueKey('signin-email')), email);
      await tester.tap(find.byKey(const ValueKey('signin-send')));
      await settleIo(tester);
      await tester.enterText(find.byKey(const ValueKey('signin-code')), code);
      await tester.tap(find.byKey(const ValueKey('signin-verify')));
      await settleIo(tester, rounds: 10);
    }

    Future<void> end(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a wrong code shows the normal wrong-code message', (
      tester,
    ) async {
      final review = _FakeReview();
      final gotrue = _GoTrue();
      // Not disposed: its dispose waits on timers that never fire under the
      // widget test's fake clock (nothing is connected anyway).
      final client = _client(gotrue);
      final auth = SupabaseAuthRepository(client, reviewSignIn: review);
      await onboarding(tester, auth);
      await typeCode(tester, 'someone@aura.test', '123456');
      expect(review.calls, [('someone@aura.test', '123456')]);
      expect(auth.currentUser, isNull);
      // The screen's own message for a refused code, as before.
      expect(find.byKey(const ValueKey('signin-code')), findsOneWidget);
      expect(find.textContaining('review'), findsNothing);
      expect(find.textContaining('Review'), findsNothing);
      // GoTrue's "expired or invalid" → a fresh code, exactly as before.
      expect(gotrue.requests.where((r) => r == 'POST /auth/v1/otp').length, 2);
      expect(
        find.text("This code has timed out. We'll send a fresh one."),
        findsOneWidget,
      );
      await end(tester);
    });

    testWidgets('the review code signs in and onboarding continues', (
      tester,
    ) async {
      final review = _FakeReview();
      final gotrue = _GoTrue();
      // Not disposed: its dispose waits on timers that never fire under the
      // widget test's fake clock (nothing is connected anyway).
      final client = _client(gotrue);
      final auth = SupabaseAuthRepository(client, reviewSignIn: review);
      final c = await onboarding(tester, auth);
      await typeCode(tester, _reviewEmail, _reviewCode);
      expect(review.calls, [(_reviewEmail, _reviewCode)]);
      expect(auth.currentUser?.email, _reviewEmail);
      expect(
        c.read(gateControllerProvider).stage,
        isNot(OnboardingStage.signIn),
      );
      await end(tester);
    });
  });
}

HttpReviewSignInApi _api(Map<String, Object?> body, int status) =>
    HttpReviewSignInApi(
      baseUrl: 'http://api.test',
      dio: Dio(
        BaseOptions(baseUrl: 'http://api.test', validateStatus: (_) => true),
      )..httpClientAdapter = _Answer(body, status),
    );

class _Answer implements HttpClientAdapter {
  _Answer(this.body, this.status);

  final Map<String, Object?> body;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
