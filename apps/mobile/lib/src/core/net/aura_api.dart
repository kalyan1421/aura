import 'package:dio/dio.dart';

import 'api_models.dart';

/// A failed API call. Never carries request bodies (notes, DOB) in messages.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    this.status,
    this.isNetwork = false,
  });

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

/// Thin client for NestJS `server/aura-api` (contracts/api/v1.md).
class AuraApi {
  AuraApi({
    required String baseUrl,
    required this._accessToken,
    Dio? dio,
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
           );

  final Dio _dio;
  final Future<String?> Function() _accessToken;

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

  ApiException _map(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException(code: e.type.name, isNetwork: true);
    }
    final data = res.data;
    final code = data is Map && data['code'] is String
        ? data['code'] as String
        : 'http_${res.statusCode}';
    return ApiException(code: code, status: res.statusCode);
  }
}
