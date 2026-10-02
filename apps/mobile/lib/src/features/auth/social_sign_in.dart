import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/env/env.dart';
import 'auth_repository.dart';

/// Native Google sign-in (F8 REQ-ACC-01): Google's own sheet returns an ID
/// token, and Supabase exchanges it for a session (`signInWithIdToken`).
/// Email scope only: Aura reads nothing else from the credential. Aura ships
/// no Sign in with Apple (v1 is email code + Google on Android), so iOS
/// offers no social button. Setup: docs/setup/social-sign-in.md.
///
/// Tokens, nonces and emails are never logged; failures log only a type.

enum SocialPlatform { ios, android, other }

SocialPlatform currentSocialPlatform() {
  if (kIsWeb) return SocialPlatform.other;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => SocialPlatform.ios,
    TargetPlatform.android => SocialPlatform.android,
    _ => SocialPlatform.other,
  };
}

/// Which social buttons this build offers. A button shows only when its
/// provider is configured, so there is never a dead button.
///
/// - **Google**: needs the Web client id (`AURA_GOOGLE_WEB_CLIENT_ID`), plus
///   the iOS client id on iOS (`AURA_GOOGLE_IOS_CLIENT_ID`).
/// - **App Store 4.8**: an iOS app that offers a third-party login must also
///   offer Sign in with Apple, and Aura doesn't, so on iOS Google is never
///   offered in a release build. Debug builds relax this
///   ([enforceAppStoreRules]) so Google can be tried on a simulator.
/// - `AURA_SOCIAL_SIGNIN=false` ([enabled]) hides it everywhere.
@immutable
class SocialSignInConfig {
  const SocialSignInConfig({
    required this.platform,
    this.enabled = true,
    this.googleWebClientId = '',
    this.googleIosClientId = '',
    this.enforceAppStoreRules = true,
  });

  factory SocialSignInConfig.fromEnv() => SocialSignInConfig(
    platform: currentSocialPlatform(),
    enabled: Env.socialSignIn,
    googleWebClientId: Env.googleWebClientId.trim(),
    googleIosClientId: Env.googleIosClientId.trim(),
    enforceAppStoreRules: !kDebugMode,
  );

  final SocialPlatform platform;
  final bool enabled;
  final String googleWebClientId;
  final String googleIosClientId;
  final bool enforceAppStoreRules;

  static bool _isClientId(String id) =>
      id.endsWith('.apps.googleusercontent.com');

  /// Google's client ids are present for this platform.
  bool get googleConfigured =>
      _isClientId(googleWebClientId) &&
      switch (platform) {
        SocialPlatform.ios => _isClientId(googleIosClientId),
        SocialPlatform.android => true,
        SocialPlatform.other => false,
      };

  bool get showGoogle =>
      enabled &&
      googleConfigured &&
      (platform != SocialPlatform.ios || !enforceAppStoreRules);

  List<SocialProvider> get providers => [if (showGoogle) SocialProvider.google];
}

/// What a native sheet hands back. [rawNonce] goes to Supabase, which checks
/// its SHA-256 against the token's `nonce` claim.
@immutable
class SocialCredential {
  const SocialCredential({
    required this.idToken,
    this.accessToken,
    this.rawNonce,
  });

  final String idToken;
  final String? accessToken;
  final String? rawNonce;

  @override
  String toString() => 'SocialCredential(<redacted>)';
}

/// Google's native sheet (google_sign_in 7: Credential Manager on Android,
/// GoogleSignIn-iOS). Throws [AuthFailure].
abstract interface class NativeGoogleSignIn {
  Future<SocialCredential> signIn();

  /// Drops the SDK's own Google session (local only; nothing is revoked).
  /// Aura keeps none, so a shared phone never offers the last person's
  /// account. Never throws.
  Future<void> forget();
}

// ---- nonces ------------------------------------------------------------------

/// 32 random bytes, hex (a raw nonce).
String randomNonce([Random? random]) {
  final r = random ?? Random.secure();
  final b = StringBuffer();
  for (var i = 0; i < 32; i++) {
    b.write(r.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return b.toString();
}

/// Lower-case hex SHA-256, the form Supabase compares with the token's
/// `nonce` claim (`hex(sha256(raw))`).
Future<String> sha256Hex(String raw) async {
  final hash = await Sha256().hash(utf8.encode(raw));
  return hash.bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}

// ---- Google --------------------------------------------------------------------

class PluginGoogleSignIn implements NativeGoogleSignIn {
  PluginGoogleSignIn({
    required this.serverClientId,
    this.clientId,
    this.fetchAccessToken = false,
  });

  /// The Web client id: the ID token's audience.
  final String serverClientId;

  /// The iOS client id (`null` on Android, which identifies the app by its
  /// package name and signing SHA-1 instead).
  final String? clientId;

  /// iOS ID tokens carry `at_hash`, so Supabase verifies the access token
  /// with them. Android (Credential Manager) issues no access token.
  final bool fetchAccessToken;

  /// `GoogleSignIn.initialize` may run once per process, so the nonce it
  /// carries lives for the process, in memory only. Reset if it failed.
  static Future<String>? _ready;

  Future<String> _init() {
    final pending = _ready;
    if (pending != null) return pending;
    final started = () async {
      final raw = randomNonce();
      await GoogleSignIn.instance.initialize(
        clientId: clientId,
        serverClientId: serverClientId,
        nonce: await sha256Hex(raw),
      );
      return raw;
    }();
    _ready = started;
    unawaited(started.then((_) {}, onError: (Object _) => _ready = null));
    return started;
  }

  @override
  Future<SocialCredential> signIn() async {
    try {
      final rawNonce = await _init();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email'],
      );
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure(AuthFailureKind.other);
      }
      String? accessToken;
      if (fetchAccessToken) {
        try {
          // Already granted by the sign-in: no second prompt.
          final auth = await account.authorizationClient.authorizationForScopes(
            const ['email'],
          );
          accessToken = auth?.accessToken;
        } on Object catch (e) {
          debugPrint('auth: google access token ${e.runtimeType}');
        }
      }
      return SocialCredential(
        idToken: idToken,
        accessToken: accessToken,
        rawNonce: rawNonce,
      );
    } on AuthFailure {
      rethrow;
    } on Object catch (e) {
      final kind = googleFailureKind(e);
      debugPrint('auth: google ${e.runtimeType} → ${kind.name}');
      throw AuthFailure(kind);
    }
  }

  @override
  Future<void> forget() async {
    try {
      if (_ready == null) return;
      await _ready;
      await GoogleSignIn.instance.signOut().timeout(const Duration(seconds: 3));
    } on Object catch (e) {
      debugPrint('auth: google forget ${e.runtimeType}');
    }
  }
}

/// google_sign_in failures → what the person is told.
AuthFailureKind googleFailureKind(Object e) {
  if (e is GoogleSignInException) {
    final text = '${e.description ?? ''} ${e.details ?? ''}'.toLowerCase();
    return switch (e.code) {
      // Closed the sheet, or the app went to the background: say nothing.
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted => AuthFailureKind.cancelled,
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        AuthFailureKind.notConfigured,
      _ when _looksMisconfigured(text) => AuthFailureKind.notConfigured,
      _ when _looksOffline(text) => AuthFailureKind.network,
      _ => AuthFailureKind.other,
    };
  }
  if (e is PlatformException) {
    final text = '${e.code} ${e.message ?? ''}'.toLowerCase();
    if (text.contains('nsurlerrordomain')) return AuthFailureKind.network;
    // GIDSignIn raises for a missing URL scheme or client id (iOS).
    if (text.contains('url scheme') ||
        text.contains('configuration') ||
        text.contains('client id') ||
        text.contains('clientid')) {
      return AuthFailureKind.notConfigured;
    }
  }
  return AuthFailureKind.other;
}

/// Android Credential Manager: no OAuth client for this package + SHA-1, or
/// the wrong server client id ("[28444] Developer console is not set up
/// correctly", "[10]", "No credential available").
bool _looksMisconfigured(String text) =>
    text.contains('28444') ||
    text.contains('developer console') ||
    text.contains('[10]') ||
    text.contains('no credential available');

bool _looksOffline(String text) =>
    text.contains('network') || text.contains('[7]');

// ---- orchestration ---------------------------------------------------------------

enum SocialSignInResult {
  /// The Supabase session exists now.
  signedIn,
}

class SocialSignInService {
  SocialSignInService({
    required this.config,
    required this._exchange,
    this.google,
  });

  final SocialSignInConfig config;
  final SocialSessionExchange _exchange;
  final NativeGoogleSignIn? google;

  List<SocialProvider> get providers => config.providers;

  /// Throws [AuthFailure]; [AuthFailureKind.cancelled] means say nothing.
  Future<SocialSignInResult> signIn(SocialProvider provider) async {
    if (!providers.contains(provider)) {
      throw const AuthFailure(AuthFailureKind.notConfigured);
    }
    switch (provider) {
      case SocialProvider.google:
        final g = google;
        if (g == null) throw const AuthFailure(AuthFailureKind.notConfigured);
        try {
          final c = await g.signIn();
          await _exchange.signInWithIdToken(
            provider: SocialProvider.google,
            idToken: c.idToken,
            accessToken: c.accessToken,
            nonce: c.rawNonce,
          );
          return SocialSignInResult.signedIn;
        } finally {
          await g.forget();
        }
    }
  }
}
