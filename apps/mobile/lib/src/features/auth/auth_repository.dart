import 'dart:async';

import 'package:dio/dio.dart';
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
enum SocialProvider { google }

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

/// Turns a Google credential into a Supabase session. Kept apart
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
}

/// A session minted by `POST /v1/auth/review-sign-in`.
@immutable
class ReviewSession {
  const ReviewSession({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// The store-review account's fixed code (docs/setup/app-review.md). App
/// Review can't receive an emailed code, so NestJS lets that ONE account sign
/// in with a code from the review notes. Nothing in the UI mentions it: the
/// app only asks after Supabase refused a typed code, with the same email and
/// code, and a refusal is indistinguishable from a wrong code.
abstract interface class ReviewSignInApi {
  /// The review account's session, or `null` for anything else (a wrong
  /// code, not the review account, the route off, rate-limited, offline).
  /// Never throws.
  Future<ReviewSession?> signIn(String email, String code);
}

class HttpReviewSignInApi implements ReviewSignInApi {
  HttpReviewSignInApi({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 20),
              responseType: ResponseType.json,
              validateStatus: (_) => true,
            ),
          );

  final Dio _dio;

  @override
  Future<ReviewSession?> signIn(String email, String code) async {
    try {
      final res = await _dio.post<Object?>(
        '/v1/auth/review-sign-in',
        data: {'email': email.trim(), 'code': code.trim()},
      );
      if (res.statusCode != 200) return null;
      if (res.data case {
        'access_token': final String access,
        'refresh_token': final String refresh,
      }) {
        return ReviewSession(accessToken: access, refreshToken: refresh);
      }
      return null;
    } on Object catch (e) {
      debugPrint('auth: review sign-in ${e.runtimeType}');
      return null;
    }
  }
}

class SupabaseAuthRepository implements AuthRepository, SocialSessionExchange {
  SupabaseAuthRepository(this._client, {ReviewSignInApi? reviewSignIn})
    : _review = reviewSignIn;

  final sb.SupabaseClient _client;

  /// `null` in builds without the API (no review fallback).
  final ReviewSignInApi? _review;

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
    final AuthFailure failure;
    try {
      await _auth.verifyOTP(
        type: sb.OtpType.email,
        email: email.trim(),
        token: code.trim(),
      );
      return;
    } on sb.AuthException catch (e) {
      failure = AuthFailure(_kind(e));
    } catch (_) {
      throw const AuthFailure(AuthFailureKind.network);
    }
    // Supabase refused the code: the store-review account's fixed code is
    // the only other way in. Any refusal there leaves the original failure,
    // so a person's wrong or expired code reads exactly as before.
    if (failure.kind != AuthFailureKind.network &&
        await _reviewSignIn(email, code)) {
      return;
    }
    throw failure;
  }

  /// `POST /v1/auth/review-sign-in`, then the session it minted becomes this
  /// app's Supabase session (fires `signedIn`, like verifyOTP).
  Future<bool> _reviewSignIn(String email, String code) async {
    final review = _review;
    if (review == null) return false;
    final session = await review.signIn(email, code);
    if (session == null) return false;
    try {
      await _auth.setSession(
        session.refreshToken,
        accessToken: session.accessToken,
      );
      return true;
    } on Object catch (e) {
      debugPrint('auth: review session ${e.runtimeType}');
      return false;
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

  static sb.OAuthProvider _oauth(SocialProvider p) => switch (p) {
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
