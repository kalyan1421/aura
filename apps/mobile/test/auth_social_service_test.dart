import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/auth/social_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_social_fakes.dart';

/// SocialSignInService: the native credential goes to Supabase with the raw
/// nonce, Google's SDK session is always dropped afterwards, Apple on
/// Android is browser OAuth, and a provider this build doesn't offer is
/// never started.

void main() {
  test('Google: ID token, access token and the raw nonce go to Supabase; '
      "the SDK's Google session is dropped", () async {
    final exchange = FakeExchange();
    final google = FakeGoogle();
    final service = SocialSignInService(
      config: iosSocial,
      exchange: exchange,
      google: google,
      apple: FakeApple(),
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

  test(
    'Apple on iOS: native, raw nonce to Supabase, no access token',
    () async {
      final exchange = FakeExchange();
      final apple = FakeApple();
      final service = SocialSignInService(
        config: iosSocial,
        exchange: exchange,
        google: FakeGoogle(),
        apple: apple,
      );

      expect(
        await service.signIn(SocialProvider.apple),
        SocialSignInResult.signedIn,
      );
      expect(apple.calls, 1);
      expect(exchange.idTokens, [
        (SocialProvider.apple, 'apple-id-token', null, 'raw-nonce-a'),
      ]);
      expect(exchange.browser, isEmpty);
    },
  );

  test('Apple on Android: browser OAuth; the session comes back through '
      'aura://auth-callback', () async {
    final exchange = FakeExchange();
    final service = SocialSignInService(
      config: const SocialSignInConfig(
        platform: SocialPlatform.android,
        googleWebClientId: webClientId,
        appleBrowser: true,
      ),
      exchange: exchange,
      google: FakeGoogle(),
    );

    expect(
      await service.signIn(SocialProvider.apple),
      SocialSignInResult.browserOpened,
    );
    expect(exchange.browser, [SocialProvider.apple]);
    expect(exchange.idTokens, isEmpty);
  });

  test('a provider this build does not offer is never started', () async {
    final exchange = FakeExchange();
    final google = FakeGoogle();
    final service = SocialSignInService(
      // iOS release rules: Google without Apple is not offered (4.8).
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
