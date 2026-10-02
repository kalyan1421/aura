import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/auth/social_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_social_fakes.dart';

/// SocialSignInService: the native credential goes to Supabase with the raw
/// nonce, Google's SDK session is always dropped afterwards, and a provider
/// this build doesn't offer is never started.

void main() {
  test('Google: ID token, access token and the raw nonce go to Supabase; '
      "the SDK's Google session is dropped", () async {
    final exchange = FakeExchange();
    final google = FakeGoogle();
    final service = SocialSignInService(
      config: iosSocial,
      exchange: exchange,
      google: google,
    );

    expect(
      await service.signIn(SocialProvider.google),
      SocialSignInResult.signedIn,
    );
    expect(exchange.idTokens, [
      (
        SocialProvider.google,
        'google-id-token',
        'google-access',
        'raw-nonce-g',
      ),
    ]);
    expect(google.forgets, 1);
  });

  test('Google: a failed exchange still drops the SDK session', () async {
    final exchange = FakeExchange()
      ..fail = const AuthFailure(AuthFailureKind.notConfigured);
    final google = FakeGoogle();
    final service = SocialSignInService(
      config: androidSocial,
      exchange: exchange,
      google: google,
    );

    await expectLater(
      service.signIn(SocialProvider.google),
      throwsA(
        isA<AuthFailure>().having(
          (f) => f.kind,
          'kind',
          AuthFailureKind.notConfigured,
        ),
      ),
    );
    expect(google.forgets, 1);
  });

  test('Google cancelled: nothing reaches Supabase', () async {
    final exchange = FakeExchange();
    final google = FakeGoogle()
      ..fail = const AuthFailure(AuthFailureKind.cancelled);
    final service = SocialSignInService(
      config: androidSocial,
      exchange: exchange,
      google: google,
    );

    await expectLater(
      service.signIn(SocialProvider.google),
      throwsA(
        isA<AuthFailure>().having(
          (f) => f.kind,
          'kind',
          AuthFailureKind.cancelled,
        ),
      ),
    );
    expect(exchange.idTokens, isEmpty);
  });

  test('a provider this build does not offer is never started', () async {
    final exchange = FakeExchange();
    final google = FakeGoogle();
    final service = SocialSignInService(
      // iOS release rules: Google is not offered without Sign in with Apple
      // (4.8), and Aura has none.
      config: const SocialSignInConfig(
        platform: SocialPlatform.ios,
        googleWebClientId: webClientId,
        googleIosClientId: iosClientId,
      ),
      exchange: exchange,
      google: google,
    );

    expect(service.providers, isEmpty);
    await expectLater(
      service.signIn(SocialProvider.google),
      throwsA(
        isA<AuthFailure>().having(
          (f) => f.kind,
          'kind',
          AuthFailureKind.notConfigured,
        ),
      ),
    );
    expect(google.calls, 0);
  });
}
