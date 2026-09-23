import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'api_models.dart';

/// A failed API call. Never carries request bodies (notes, DOB) in messages.
class ApiException implements Exception {
  const ApiException({required this.code, this.status, this.isNetwork = false});

  final int? status;
  final String code;

  /// No response at all (offline, DNS, refused, timeout).
  final bool isNetwork;

  /// Worth retrying later with backoff (network, 5xx, 429, auth refresh).
  bool get isRetryable =>
      isNetwork ||
      status == null ||
      status! >= 500 ||
      status == 429 ||
      status == 401 ||
      status == 408;

  /// `403 account_deletion_pending`: the account is in its 7-day deletion
  /// grace period and the server refuses every route but `/v1/account*`
  /// (contracts/api/v1.md "Account deletion"). Retrying won't help; the
  /// person chooses "Keep my account" or "Let it go".
  bool get isDeletionPending => status == 403 && code == deletionPendingCode;

  static const String deletionPendingCode = 'account_deletion_pending';

  /// `409 account_deletion_in_progress` from "Keep my account": the grace
  /// period is over and the purge may be running — the account can't be
  /// kept. The app explains and signs out; never retried.
  bool get isDeletionInProgress =>
      status == 409 && code == deletionInProgressCode;

  static const String deletionInProgressCode = 'account_deletion_in_progress';

  /// `403 account_closed`: the account was closed for breaking the rules
  /// (contracts/api/v1.md "Account closed"). Every route but `/v1/account*`
  /// and the safety reads refuses it; never retried. The app shows the calm
  /// closed screen (features/auth/account_closed.dart).
  bool get isAccountClosed => status == 403 && code == accountClosedCode;

  static const String accountClosedCode = 'account_closed';

  @override
  String toString() => 'ApiException($status, $code)';
}

/// Result of `POST /v1/profile`.
sealed class ProfileResult {
  const ProfileResult();
}

class ProfileSaved extends ProfileResult {
  const ProfileSaved(this.snapshot);
  final Snapshot? snapshot;
}

/// `403 under_13`: nothing was stored server-side.
class ProfileUnder13 extends ProfileResult {
  const ProfileUnder13();
}

/// Signed Storage URLs are absolute URLs on the API's own `SUPABASE_URL`
/// (`http://127.0.0.1:55521/…` locally). A local build that reaches Supabase
/// under another host — the Android emulator's `10.0.2.2`, a LAN address on
/// a phone — swaps in its own scheme, host and port; path and query (the
/// token) stay as they are. Only loopback hosts are ever rewritten, so a
/// real project URL is used exactly as signed.
Uri mediaUrlFor(String signed, {String? supabaseUrl}) {
  final url = Uri.parse(signed);
  final own = supabaseUrl == null || supabaseUrl.isEmpty
      ? null
      : Uri.tryParse(supabaseUrl);
  if (own == null || own.host.isEmpty) return url;
  const loopback = {'127.0.0.1', 'localhost', '::1', '[::1]'};
  if (!loopback.contains(url.host) || url.host == own.host) return url;
  return url.replace(scheme: own.scheme, host: own.host, port: own.port);
}

/// Thin client for NestJS `server/aura-api` (contracts/api/v1.md).
class AuraApi {
  AuraApi({
    required String baseUrl,
    required this._accessToken,
    Dio? dio,
    Dio? mediaDio,
    this._supabaseUrl,
    this._onAccountClosed,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 6),
               sendTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 20),
               contentType: Headers.jsonContentType,
               responseType: ResponseType.json,
             ),
           ),
       // Signed Storage URLs: no base URL, never an auth header.
       _mediaDio =
           mediaDio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               sendTimeout: const Duration(seconds: 60),
               receiveTimeout: const Duration(seconds: 60),
             ),
           );

  final Dio _dio;
  final Dio _mediaDio;
  final Future<String?> Function() _accessToken;

  /// This build's Supabase URL, for [mediaUrlFor].
  final String? _supabaseUrl;

  /// Told (in a microtask) about every `403 account_closed`, whichever call
  /// got it ([ApiException.isAccountClosed]).
  final void Function()? _onAccountClosed;

  Future<Options> _auth() async {
    final token = await _accessToken();
    if (token == null) {
      throw const ApiException(code: 'signed_out', status: 401);
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<ProfileResult> postProfile(ProfileRequest body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/profile',
        data: body.toJson(),
        options: await _auth(),
      );
      final snap = res.data?['snapshot'];
      return ProfileSaved(
        snap is Map<String, dynamic> ? Snapshot.fromJson(snap) : null,
      );
    } on DioException catch (e) {
      final ex = _map(e);
      if (ex.status == 403 && ex.code == 'under_13') {
        return const ProfileUnder13();
      }
      throw ex;
    }
  }

  Future<PushResponse> push({
    required String deviceId,
    required List<SyncMutation> mutations,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/sync/push',
        data: {
          'deviceId': deviceId,
          'mutations': [for (final m in mutations) m.toJson()],
        },
        options: await _auth(),
      );
      return PushResponse.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<Snapshot> snapshot() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/me/snapshot',
        options: await _auth(),
      );
      return Snapshot.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<DataKeyResponse> dataKey() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/keys/data-key',
        options: await _auth(),
      );
      return DataKeyResponse.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// `PUT /v1/devices` → 204. Registers this install's FCM token for the
  /// signed-in account (a token that moved from another account is
  /// reassigned server-side). The token is never logged.
  Future<void> putDevice({
    required String token,
    required String platform,
  }) async {
    try {
      await _dio.put<void>(
        '/v1/devices',
        data: {'token': token, 'platform': platform},
        options: await _auth(),
      );
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// `DELETE /v1/devices` → 204 (idempotent, scoped to the caller).
  Future<void> deleteDevice(String token) async {
    try {
      await _dio.delete<void>(
        '/v1/devices',
        data: {'token': token},
        options: await _auth(),
      );
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  // ---- account deletion (F8 REQ-ACC-11, contracts/api/v1.md) ---------------

  /// `GET /v1/account` → whether a deletion is scheduled.
  Future<AccountStatus> account() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/account',
        options: await _auth(),
      );
      return AccountStatus.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// `POST /v1/account/deletion` → 202 with the purge date, 7 days after the
  /// first request. Idempotent: a repeat returns the same date.
  Future<AccountStatus> requestDeletion() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/account/deletion',
        options: await _auth(),
      );
      return AccountStatus.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// `DELETE /v1/account/deletion` → 200, cancels a scheduled deletion
  /// ("Keep my account"). Idempotent. After the grace period:
  /// `409 account_deletion_in_progress` ([ApiException.isDeletionInProgress]).
  Future<AccountStatus> cancelDeletion() async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>(
        '/v1/account/deletion',
        options: await _auth(),
      );
      return AccountStatus.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// `GET /v1/account` → `accountClosed: true` when the account was closed
  /// for breaking the rules (the key is absent otherwise; contracts/api/v1.md
  /// "Account closed").
  Future<bool> accountClosed() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/account',
        options: await _auth(),
      );
      return res.data?['accountClosed'] == true;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// `POST /v1/account/apple-auth` → 204: the one-time Sign in with Apple
  /// authorization code, so the server can revoke the Apple token when the
  /// account is deleted (App Review 5.1.1(v)). `503 apple_unavailable` when
  /// the server has no Apple key; callers ignore every failure. The code is
  /// never logged.
  Future<void> postAppleAuth(String authorizationCode) async {
    try {
      await _dio.post<void>(
        '/v1/account/apple-auth',
        data: {'authorizationCode': authorizationCode},
        options: await _auth(),
      );
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  // ---- analytics consent (PRD 13-analytics; contracts/api/v1-analytics.md)

  /// `PUT /v1/analytics/consent` → records "Help improve Aura" for the
  /// account and answers whether it may be tracked, as which random
  /// analytics id, and the account's signup day (for `signup_age_bucket`).
  /// The server never says why tracking is off.
  Future<({bool tracking, String? distinctId, String? signupDay})>
  putAnalyticsConsent({
    required bool granted,
    required String policyVersion,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/v1/analytics/consent',
        data: {'granted': granted, 'policyVersion': policyVersion},
        options: await _auth(),
      );
      final data = res.data ?? const <String, dynamic>{};
      final id = data['distinctId'];
      final day = data['signupDay'];
      return (
        tracking: data['tracking'] == true && id is String,
        distinctId: id is String ? id : null,
        signupDay: day is String ? day : null,
      );
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  // ---- media: voice notes (F1 · DS-1, contracts/api/v1.md) ------------------

  /// `POST /v1/media/upload-url`. [bytes] is the exact ciphertext length
  /// that will be uploaded (never more). `503 media_unavailable` and network
  /// errors are retryable ([ApiException.isRetryable]).
  Future<MediaUploadUrl> mediaUploadUrl({
    required String recordId,
    required int bytes,
    String kind = 'voice',
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/media/upload-url',
        data: {'kind': kind, 'recordId': recordId, 'bytes': bytes},
        options: await _auth(),
      );
      return MediaUploadUrl.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// `POST /v1/media/upload-url` for F4 capsule media
  /// (contracts/api/v1-capsules.md §5): [kind] `capsule_voice` (no [index])
  /// or `capsule_photo` with [index] 0–2. [bytes] is the exact ciphertext
  /// length. A slot that already holds an object of a sealed capsule →
  /// `409 capsule_sealed` (already uploaded); a deleted capsule →
  /// `409 capsule_deleted`.
  Future<MediaUploadUrl> capsuleMediaUploadUrl({
    required String capsuleId,
    required String kind,
    required int bytes,
    int? index,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/media/upload-url',
        data: {
          'kind': kind,
          'recordId': capsuleId,
          'bytes': bytes,
          'index': ?index,
        },
        options: await _auth(),
      );
      return MediaUploadUrl.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// `POST /v1/media/download-url` for an own object ([path] as stored).
  /// Anything else, or a missing object → `404 not_found`.
  Future<MediaDownloadUrl> mediaDownloadUrl(String path) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/media/download-url',
        data: {'path': path},
        options: await _auth(),
      );
      return MediaDownloadUrl.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// One `PUT` of the raw ciphertext to a signed upload URL: no
  /// `Authorization`/`apikey` header (the token is in the URL's query).
  /// Success is a 2xx; anything else throws (ask for a fresh URL, retry).
  Future<void> putMedia(String uploadUrl, Uint8List ciphertext) async {
    try {
      await _mediaDio.putUri<void>(
        mediaUrlFor(uploadUrl, supabaseUrl: _supabaseUrl),
        data: ciphertext,
        options: Options(
          contentType: 'application/octet-stream',
          responseType: ResponseType.plain,
          headers: {Headers.contentLengthHeader: ciphertext.length},
        ),
      );
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// `GET` of a signed download URL (no headers) → the ciphertext bytes.
  Future<Uint8List> getMedia(String downloadUrl) async {
    try {
      final res = await _mediaDio.getUri<List<int>>(
        mediaUrlFor(downloadUrl, supabaseUrl: _supabaseUrl),
        options: Options(responseType: ResponseType.bytes),
      );
      final data = res.data ?? const <int>[];
      return data is Uint8List ? data : Uint8List.fromList(data);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  ApiException _map(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException(code: e.type.name, isNetwork: true);
    }
    final data = res.data;
    final code = data is Map && data['code'] is String
        ? data['code'] as String
        : 'http_${res.statusCode}';
    final ex = ApiException(code: code, status: res.statusCode);
    final onClosed = _onAccountClosed;
    if (onClosed != null && ex.isAccountClosed) {
      // Outside the caller's error path: a UI hiccup never changes the error.
      scheduleMicrotask(() {
        try {
          onClosed();
        } on Object catch (e) {
          debugPrint('api: account closed hook ${e.runtimeType}');
        }
      });
    }
    return ex;
  }
}
