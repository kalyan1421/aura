import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/net/aura_api.dart' show ApiException;
import '../rooms/room_models.dart' show GestureType, ReportReason;
import 'quiet_models.dart';

/// NestJS Quiet Together routes (contracts/api/v1-quiet.md §1). Every
/// failure is an [ApiException] (same codes and status as `AuraApi`).
/// Online only: callers never queue these.
abstract interface class QuietApi {
  Future<QuietSession> join(QuietMode mode, {String? timezone});

  /// Keeps you counted; at a block's end answers with the next block's
  /// session (a different id).
  Future<QuietSession> heartbeat(String sessionId);

  Future<void> leave(String sessionId);

  /// A preset to the whole session → the gesture id (dedupes the echo).
  Future<String> gesture(String sessionId, GestureType type);

  /// → whether the Safety Center should open (reason 1).
  Future<bool> report(String sessionId, ReportReason reason, {String? note});
}

class HttpQuietApi implements QuietApi {
  HttpQuietApi({required String baseUrl, required this.accessToken, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 6),
              sendTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;
  final Future<String?> Function() accessToken;

  static const String _base = '/v1/quiet';
  static String _id(String id) => Uri.encodeComponent(id);

  Future<Map<String, dynamic>> _post(String path, [Object? body]) async {
    final token = await accessToken();
    if (token == null) {
      throw const ApiException(code: 'signed_out', status: 401);
    }
    try {
      final res = await _dio.post<dynamic>(
        path,
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      return data is Map<String, dynamic> ? data : const {};
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  static QuietSession _session(Map<String, dynamic> data) {
    final s = data['session'];
    if (s is! Map<String, dynamic>) {
      throw const ApiException(code: 'bad_response');
    }
    return QuietSession.fromJson(s);
  }

  @override
  Future<QuietSession> join(QuietMode mode, {String? timezone}) async =>
      _session(
        await _post('$_base/join', {'mode': mode.wire, 'timezone': ?timezone}),
      );

  @override
  Future<QuietSession> heartbeat(String sessionId) async =>
      _session(await _post('$_base/sessions/${_id(sessionId)}/heartbeat'));

  @override
  Future<void> leave(String sessionId) async {
    await _post('$_base/sessions/${_id(sessionId)}/leave');
  }

  @override
  Future<String> gesture(String sessionId, GestureType type) async {
    final data = await _post('$_base/sessions/${_id(sessionId)}/gestures', {
      'type': type.wire,
    });
    return data['gestureId'] is String ? data['gestureId'] as String : '';
  }

  @override
  Future<bool> report(
    String sessionId,
    ReportReason reason, {
    String? note,
  }) async {
    final data = await _post('$_base/sessions/${_id(sessionId)}/reports', {
      'reason': reason.wire,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return data['showHelplines'] == true;
  }

  /// Same mapping as `AuraApi`: a response's `code`, else `http_<status>`;
  /// no response at all is a network failure. Never carries bodies.
  static ApiException _map(DioException e) {
    final res = e.response;
    if (res == null) return ApiException(code: e.type.name, isNetwork: true);
    final data = res.data;
    final code = data is Map && data['code'] is String
        ? data['code'] as String
        : 'http_${res.statusCode}';
    if (res.statusCode != null && res.statusCode! >= 500) {
      debugPrint('quiet: server answered ${res.statusCode} ($code)');
    }
    return ApiException(code: code, status: res.statusCode);
  }
}

/// Which calm state an error means, or `null` for "keep going quietly".
QuietUnavailable? quietUnavailableFor(Object error) {
  if (error is! ApiException) return null;
  if (error.isNetwork) return QuietUnavailable.offline;
  return switch (error.code) {
    'quiet_paused' => QuietUnavailable.paused,
    'rooms_suspended' => QuietUnavailable.suspended,
    'account_closed' => QuietUnavailable.closed,
    'guidelines_required' => QuietUnavailable.guidelines,
    'signed_out' => QuietUnavailable.signedOut,
    _ => null,
  };
}
