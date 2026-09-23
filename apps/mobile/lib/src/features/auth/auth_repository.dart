import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/env/env.dart';

/// The signed-in account. Email only; Aura never asks for a name or phone.
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}

enum AuthFailureKind {
  invalidEmail,
  invalidCode,
  expired,
  network,
  other,

  /// The person closed the Apple / Google sheet: say nothing.
  cancelled,

  /// The provider isn't set up for this build or this Supabase project
  /// (disabled provider, unknown client id / audience, missing capability).
  notConfigured,
}

/// Social sign-in providers (see `SocialSignInConfig` for when each shows).
enum SocialProvider { apple, google }

class AuthFailure implements Exception {
  const AuthFailure(this.kind);
  final AuthFailureKind kind;

  @override
  String toString() => 'AuthFailure(${kind.name})';
}

/// Sign-in (Supabase Auth: passwordless email code + magic link).
abstract interface class AuthRepository {
  /// False when this build has no Supabase configuration.
  bool get isAvailable;

  AuthUser? get currentUser;

  Stream<AuthUser?> watchUser();

  /// A fresh access token for NestJS, or `null` when signed out.
  Future<String?> accessToken();

  Future<void> sendEmailCode(String email);

  Future<void> verifyEmailCode(String email, String code);

  Future<void> signOut();
}

/// Turns an Apple / Google credential into a Supabase session. Kept apart
/// from [AuthRepository] so builds (and fakes) without social sign-in need
/// nothing new.
abstract interface class SocialSessionExchange {
  /// Native sign-in: exchanges the provider's ID token (+ its access token
  /// when the token carries `at_hash`) for a session. [nonce] is the *raw*
  /// nonce whose SHA-256 went to the provider. Throws [AuthFailure].
  Future<void> signInWithIdToken({
    required SocialProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  });

  /// Browser OAuth (Apple on Android). Returns once the browser opened; the
  /// session arrives later through `aura://auth-callback`. Throws
  /// [AuthFailure].
  Future<void> signInWithBrowser(SocialProvider provider);
}

class SupabaseAuthRepository implements AuthRepository, SocialSessionExchange {
  SupabaseAuthRepository(this._client);

  final sb.SupabaseClient _client;

  sb.GoTrueClient get _auth => _client.auth;

  @override
  bool get isAvailable => true;

  @override
  AuthUser? get currentUser => _toUser(_auth.currentUser);

  @override
  Stream<AuthUser?> watchUser() async* {
    yield currentUser;
    yield* _auth.onAuthStateChange.map((s) => _toUser(s.session?.user));
  }

  @override
  Future<String?> accessToken() async {
    var session = _auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      try {
        session = (await _auth.refreshSession()).session;
      } on sb.AuthException {
        return null;
      }
    }
    return session?.accessToken;
  }

  @override
  Future<void> sendEmailCode(String email) async {
    try {
      await _auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: true,
        emailRedirectTo: Env.authRedirect,
      );
    } on sb.AuthException catch (e) {
      throw AuthFailure(_kind(e));
    } catch (_) {
      throw const AuthFailure(AuthFailureKind.network);
    }
  }

  @override
  Future<void> verifyEmailCode(String email, String code) async {
    try {
      await _auth.verifyOTP(
        type: sb.OtpType.email,
        email: email.trim(),
        token: code.trim(),
      );
    } on sb.AuthException catch (e) {
      throw AuthFailure(_kind(e));
    } catch (_) {
      throw const AuthFailure(AuthFailureKind.network);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> signInWithIdToken({
    required SocialProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  }) async {
    try {
      // Fires the signedIn event before returning, like verifyOTP.
      await _auth.signInWithIdToken(
        provider: _oauth(provider),
        idToken: idToken,
        accessToken: accessToken,
        nonce: nonce,
      );
    } on sb.AuthException catch (e) {
      throw AuthFailure(idTokenFailureKind(e));
    } catch (_) {
      throw const AuthFailure(AuthFailureKind.network);
    }
    if (provider == SocialProvider.google) {
      // GoTrue builds this first session from the ID token's claims, so
      // Google's name and picture ride along in its user_metadata. The
      // database never keeps them (migration 000011); refreshing now
      // replaces the session the SDK persists on the phone with one built
      // from the stored, stripped user. Best effort: the next refresh does
      // the same.
      try {
        await _auth.refreshSession();
      } on Object catch (e) {
        debugPrint('auth: post-sign-in refresh ${e.runtimeType}');
      }
    }
  }

  @override
  Future<void> signInWithBrowser(SocialProvider provider) async {
    final bool opened;
    try {
      opened = await _auth.signInWithOAuth(
        _oauth(provider),
        redirectTo: Env.authRedirect,
        scopes: 'email',
      );
    } on sb.AuthException catch (e) {
      throw AuthFailure(idTokenFailureKind(e));
    } catch (_) {
      throw const AuthFailure(AuthFailureKind.other);
    }
    if (!opened) throw const AuthFailure(AuthFailureKind.other);
  }

  static sb.OAuthProvider _oauth(SocialProvider p) => switch (p) {
    SocialProvider.apple => sb.OAuthProvider.apple,
    SocialProvider.google => sb.OAuthProvider.google,
  };

  AuthFailureKind _kind(sb.AuthException e) {
    final code = e.code ?? '';
    if (code.contains('expired')) return AuthFailureKind.expired;
    if (code.contains('otp') || code.contains('token')) {
      return AuthFailureKind.invalidCode;
    }
    if (code.contains('email')) return AuthFailureKind.invalidEmail;
    if (e is sb.AuthRetryableFetchException) return AuthFailureKind.network;
    return AuthFailureKind.other;
  }

  static AuthUser? _toUser(sb.User? u) =>
      u == null ? null : AuthUser(id: u.id, email: u.email);
}

/// Maps a Supabase `grant_type=id_token` (or OAuth) error to what the person
/// is told. Only the code and GoTrue's fixed message are read; nothing from
/// the token is logged or shown.
///
/// - `provider_disabled` (provider off in config.toml / the dashboard) and
///   "Unacceptable audience in id_token" (the client id isn't in the
///   provider's Client IDs list) → [AuthFailureKind.notConfigured].
/// - No response at all → [AuthFailureKind.network]; a 5xx → other.
AuthFailureKind idTokenFailureKind(sb.AuthException e) {
  if (e is sb.AuthRetryableFetchException) {
    return e.statusCode == null
        ? AuthFailureKind.network
        : AuthFailureKind.other;
  }
  final code = e.code ?? '';
  final message = e.message.toLowerCase();
  if (code == 'provider_disabled' ||
      message.contains('audience') ||
      message.contains('provider is not enabled') ||
      message.contains('is not enabled')) {
    return AuthFailureKind.notConfigured;
  }
  return AuthFailureKind.other;
}

/// Used when the build has no Supabase config: everything stays on device.
class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository();

  @override
  bool get isAvailable => false;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> watchUser() => Stream.value(null);

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<void> sendEmailCode(String email) async =>
      throw const AuthFailure(AuthFailureKind.other);

  @override
  Future<void> verifyEmailCode(String email, String code) async =>
      throw const AuthFailure(AuthFailureKind.other);

  @override
  Future<void> signOut() async {}
}
