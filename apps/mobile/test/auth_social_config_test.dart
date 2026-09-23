import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/auth/social_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Social sign-in configuration (F8 REQ-ACC-01): a button shows only when its
/// provider is configured, App Store 4.8 on iOS, and every failure maps to
/// calm copy (never the raw error).

const _web = '111-web.apps.googleusercontent.com';
const _ios = '111-ios.apps.googleusercontent.com';

SocialSignInConfig _iosConfig({
  String web = _web,
  String ios = _ios,
  bool apple = false,
  bool enabled = true,
  bool enforce = true,
}) => SocialSignInConfig(
  platform: SocialPlatform.ios,
  googleWebClientId: web,
  googleIosClientId: ios,
  appleNative: apple,
  enabled: enabled,
  enforceAppStoreRules: enforce,
);

SocialSignInConfig _androidConfig({
  String web = _web,
  bool appleBrowser = false,
  bool enabled = true,
}) => SocialSignInConfig(
  platform: SocialPlatform.android,
  googleWebClientId: web,
  appleBrowser: appleBrowser,
  enabled: enabled,
);

void main() {
  group('which buttons show', () {
    test('nothing configured → no social button on either platform', () {
      const none = SocialSignInConfig(platform: SocialPlatform.ios);
      expect(none.providers, isEmpty);
      const noneAndroid = SocialSignInConfig(platform: SocialPlatform.android);
      expect(noneAndroid.providers, isEmpty);
    });

    test('iOS: Apple and Google → Apple first, then Google', () {
      expect(_iosConfig(apple: true).providers, [
        SocialProvider.apple,
        SocialProvider.google,
      ]);
    });

    test('iOS: Apple alone is fine; Google alone is not (App Store 4.8)', () {
      expect(_iosConfig(web: '', ios: '', apple: true).providers, [
        SocialProvider.apple,
      ]);
      final googleOnly = _iosConfig();
      expect(googleOnly.googleConfigured, isTrue);
      expect(googleOnly.providers, isEmpty);
    });

    test('iOS debug builds may try Google before Apple is set up', () {
      expect(_iosConfig(enforce: false).providers, [SocialProvider.google]);
    });

    test('iOS: Google needs both the iOS and the Web client id', () {
      expect(_iosConfig(ios: '', apple: true).providers, [
        SocialProvider.apple,
      ]);
      expect(_iosConfig(web: '', apple: true).providers, [
        SocialProvider.apple,
      ]);
    });

    test(
      'a value that is not a client id (e.g. the reversed id) is ignored',
      () {
        expect(
          _iosConfig(
            ios: 'com.googleusercontent.apps.111-ios',
            apple: true,
          ).providers,
          [SocialProvider.apple],
        );
      },
    );

    test('Android: Google needs only the Web client id; Apple only with '
        'its browser flow configured', () {
      expect(_androidConfig().providers, [SocialProvider.google]);
      expect(_androidConfig(appleBrowser: true).providers, [
        SocialProvider.google,
        SocialProvider.apple,
      ]);
      expect(_androidConfig(web: '').providers, isEmpty);
      expect(_androidConfig(web: '', appleBrowser: true).providers, [
        SocialProvider.apple,
      ]);
    });

    test('AURA_SOCIAL_SIGNIN=false hides everything', () {
      expect(_iosConfig(apple: true, enabled: false).providers, isEmpty);
      expect(
        _androidConfig(appleBrowser: true, enabled: false).providers,
        isEmpty,
      );
    });

    test('other platforms never show social sign-in', () {
      const other = SocialSignInConfig(
        platform: SocialPlatform.other,
        googleWebClientId: _web,
        appleNative: true,
        appleBrowser: true,
      );
      expect(other.providers, isEmpty);
    });

    test('this test build (no defines) shows nothing', () {
      expect(SocialSignInConfig.fromEnv().providers, isEmpty);
    });
  });

  group('Supabase ID-token errors', () {
    test('provider disabled → not ready', () {
      expect(
        idTokenFailureKind(
          const sb.AuthApiException(
            'Provider (issuer "https://accounts.google.com") is not enabled',
            statusCode: '400',
            code: 'provider_disabled',
          ),
        ),
        AuthFailureKind.notConfigured,
      );
    });

    test('client id missing from the provider list → not ready', () {
      expect(
        idTokenFailureKind(
          const sb.AuthApiException(
            'Unacceptable audience in id_token: [111-web.apps.googleusercontent.com]',
            statusCode: '400',
          ),
        ),
        AuthFailureKind.notConfigured,
      );
    });

    test('no response → offline; a 5xx is not "offline"', () {
      expect(
        idTokenFailureKind(sb.AuthRetryableFetchException(message: 'x')),
        AuthFailureKind.network,
      );
      expect(
        idTokenFailureKind(
          sb.AuthRetryableFetchException(message: 'x', statusCode: '502'),
        ),
        AuthFailureKind.other,
      );
    });

    test('anything else (e.g. a nonce mismatch) → the generic message', () {
      expect(
        idTokenFailureKind(
          const sb.AuthApiException('Nonces mismatch', statusCode: '400'),
        ),
        AuthFailureKind.other,
      );
    });
  });

  group('Google SDK errors', () {
    GoogleSignInException g(GoogleSignInExceptionCode code, [String? d]) =>
        GoogleSignInException(code: code, description: d);

    test('closing the sheet says nothing', () {
      expect(
        googleFailureKind(g(GoogleSignInExceptionCode.canceled)),
        AuthFailureKind.cancelled,
      );
      expect(
        googleFailureKind(g(GoogleSignInExceptionCode.interrupted)),
        AuthFailureKind.cancelled,
      );
    });

    test('configuration problems → not ready', () {
      for (final e in [
        g(GoogleSignInExceptionCode.clientConfigurationError),
        g(GoogleSignInExceptionCode.providerConfigurationError),
        g(
          GoogleSignInExceptionCode.unknownError,
          '[28444] Developer console is not set up correctly.',
        ),
        g(GoogleSignInExceptionCode.unknownError, 'No credential available: x'),
        PlatformException(
          code: 'google_sign_in',
          message:
              'Your app is missing support for the following URL schemes: '
              'com.googleusercontent.apps.111-ios',
        ),
      ]) {
        expect(
          googleFailureKind(e),
          AuthFailureKind.notConfigured,
          reason: '$e',
        );
      }
    });

    test('network problems → offline', () {
      expect(
        googleFailureKind(
          PlatformException(
            code: 'NSURLErrorDomain: -1009',
            message: 'offline',
          ),
        ),
        AuthFailureKind.network,
      );
      expect(
        googleFailureKind(
          g(GoogleSignInExceptionCode.unknownError, '[7] Network error'),
        ),
        AuthFailureKind.network,
      );
    });

    test('anything else → the generic message', () {
      expect(
        googleFailureKind(g(GoogleSignInExceptionCode.uiUnavailable)),
        AuthFailureKind.other,
      );
      expect(googleFailureKind(StateError('x')), AuthFailureKind.other);
    });
  });

  group('Apple errors', () {
    test('cancel says nothing; 1000 (capability / no Apple Account) → not '
        'ready; others → generic', () {
      SignInWithAppleAuthorizationException a(AuthorizationErrorCode c) =>
          SignInWithAppleAuthorizationException(code: c, message: '');
      expect(
        appleFailureKind(a(AuthorizationErrorCode.canceled)),
        AuthFailureKind.cancelled,
      );
      expect(
        appleFailureKind(a(AuthorizationErrorCode.unknown)),
        AuthFailureKind.notConfigured,
      );
      expect(
        appleFailureKind(a(AuthorizationErrorCode.failed)),
        AuthFailureKind.other,
      );
      expect(
        appleFailureKind(
          const SignInWithAppleNotSupportedException(message: ''),
        ),
        AuthFailureKind.notConfigured,
      );
    });
  });

  group('nonces', () {
    test('SHA-256 hex, the form Supabase compares', () async {
      expect(
        await sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('a raw nonce is 32 random bytes in hex, fresh each time', () {
      final a = randomNonce();
      final b = randomNonce();
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(a, isNot(b));
    });

    test('credentials never print their tokens', () {
      const c = SocialCredential(
        idToken: 'secret-id-token',
        accessToken: 'secret-access',
        rawNonce: 'secret-nonce',
      );
      expect('$c', isNot(contains('secret')));
    });
  });
}
