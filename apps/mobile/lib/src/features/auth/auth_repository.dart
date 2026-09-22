import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/env/env.dart';

/// The signed-in account. Email only; Aura never asks for a name or phone.
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}

enum AuthFailureKind { invalidEmail, invalidCode, expired, network, other }

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

class SupabaseAuthRepository implements AuthRepository {
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
