import 'dart:async';

import 'package:aura/src/features/account/account_providers.dart';
import 'package:aura/src/features/auth/age_signals.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/auth/social_sign_in.dart';

/// Fakes for the social sign-in tests (auth_social_*_test.dart). Nothing
/// here touches a platform channel or the network.

const webClientId = '111-web.apps.googleusercontent.com';
const iosClientId = '111-ios.apps.googleusercontent.com';

/// iOS with Apple and Google set up (App Store 4.8 satisfied).
const iosSocial = SocialSignInConfig(
  platform: SocialPlatform.ios,
  googleWebClientId: webClientId,
  googleIosClientId: iosClientId,
  appleNative: true,
);

/// Android with Google set up (Apple's browser flow isn't).
const androidSocial = SocialSignInConfig(
  platform: SocialPlatform.android,
  googleWebClientId: webClientId,
);

const socialUser = AuthUser(
  id: 'user-social',
  email: 'relay@privaterelay.test',
);

/// Records what reaches Supabase.
class FakeExchange implements SocialSessionExchange {
  final List<(SocialProvider, String, String?, String?)> idTokens = [];
  final List<SocialProvider> browser = [];
  AuthFailure? fail;

  @override
  Future<void> signInWithIdToken({
    required SocialProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  }) async {
    idTokens.add((provider, idToken, accessToken, nonce));
    final f = fail;
    if (f != null) throw f;
    onSignedIn();
  }

  @override
  Future<void> signInWithBrowser(SocialProvider provider) async {
    browser.add(provider);
    final f = fail;
    if (f != null) throw f;
  }

  void onSignedIn() {}
}

/// Supabase auth for widget tests: email calls are counted, and a successful
/// ID-token exchange signs in (the session event fires before it returns,
/// like Supabase).
class FakeSocialAuth extends FakeExchange implements AuthRepository {
  AuthUser? user;
  final _users = StreamController<AuthUser?>.broadcast();
  int emailSends = 0;

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
  Future<void> sendEmailCode(String email) async => emailSends++;

  @override
  Future<void> verifyEmailCode(String email, String code) async {}

  @override
  Future<void> signOut() async => signIn(null);

  @override
  void onSignedIn() => signIn(socialUser);

  void signIn(AuthUser? u) {
    user = u;
    _users.add(u);
  }
}

class FakeGoogle implements NativeGoogleSignIn {
  int calls = 0;
  int forgets = 0;
  AuthFailure? fail;

  /// Keeps Google's sheet "open" until completed.
  Completer<void>? hold;

  @override
  Future<SocialCredential> signIn() async {
    calls++;
    await hold?.future;
    final f = fail;
    if (f != null) throw f;
    return const SocialCredential(
      idToken: 'google-id-token',
      accessToken: 'google-access',
      rawNonce: 'raw-nonce-g',
    );
  }

  @override
  Future<void> forget() async => forgets++;
}

class FakeApple implements NativeAppleSignIn {
  int calls = 0;
  AuthFailure? fail;

  @override
  Future<SocialCredential> signIn() async {
    calls++;
    final f = fail;
    if (f != null) throw f;
    return const SocialCredential(
      idToken: 'apple-id-token',
      rawNonce: 'raw-nonce-a',
    );
  }
}

/// A platform age signal; [gate] holds the answer back until completed.
class FakeAgeSource implements AgeSignalSource {
  FakeAgeSource([this.signal = AgeSignal.none]);

  AgeSignal signal;
  Completer<AgeSignal>? gate;
  int reads = 0;

  @override
  Future<AgeSignal> read() {
    reads++;
    return gate?.future ?? Future.value(signal);
  }
}

class FakeAccount implements AccountRepository {
  int statusCalls = 0;

  @override
  Future<DateTime> requestDeletion() async => DateTime.utc(2026, 10, 15);
  @override
  Future<DateTime?> scheduledDeletion() async {
    statusCalls++;
    return null;
  }

  @override
  Future<void> cancelDeletion() async {}
}
