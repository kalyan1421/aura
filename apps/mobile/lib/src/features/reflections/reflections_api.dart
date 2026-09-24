import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/net/aura_api.dart' show ApiException;
import '../rooms/room_models.dart' show GestureAck, GestureType;
import 'reflection_models.dart';

/// NestJS Reflections (F6), contracts/api/v1-reflections.md §1. Every
/// failure is an [ApiException] (same codes and status as `AuraApi`).
/// Reflections are online only: callers never queue these (the repository
/// refuses offline before calling). Reports on a reflection go through the
/// rooms report route (`RoomsApi.report` with a `ReflectionReportTarget`).
abstract interface class ReflectionsApi {
  /// §1.1: newest first, plus your own not-yet-published ones.
  Future<ReflectionList> list(String roomId);

  /// §1.2.
  Future<Reflection> get(String roomId, String reflectionId);

  /// §1.3: [reflectionId] is generated once per draft (UUIDv7) and reused on
  /// a retry (idempotent).
  Future<SendOutcome> send(
    String roomId, {
    required String reflectionId,
    required String text,
  });

  /// §1.4: delete (published) or withdraw (pending / held). Idempotent.
  Future<void> delete(String roomId, String reflectionId);

  /// §1.5: a gesture on someone's published reflection.
  Future<GestureAck> sendGesture(
    String roomId,
    GestureType type, {
    required String reflectionId,
  });
}

/// [ReflectionsApi] over Dio, with the same auth, timeouts and error mapping
/// as `HttpRoomsApi`. Bodies are never logged (reflection text, DS-10).
class HttpReflectionsApi implements ReflectionsApi {
  HttpReflectionsApi({
    required String baseUrl,
    required this._accessToken,
    Dio? dio,
    this._onDeviceBanned,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 6),
               sendTimeout: const Duration(seconds: 10),
               // The server waits up to ~1.8 s for the automatic check.
               receiveTimeout: const Duration(seconds: 12),
               contentType: Headers.jsonContentType,
               responseType: ResponseType.json,
             ),
           );

  final Dio _dio;
  final Future<String?> Function() _accessToken;

  /// `403 device_banned`: the app-wide screen.
  final void Function()? _onDeviceBanned;

  Future<Options> _auth() async {
    final token = await _accessToken();
    if (token == null) {
      throw const ApiException(code: 'signed_out', status: 401);
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> _call(
    Future<Response<Map<String, dynamic>>> Function(Options auth) send,
  ) async {
    try {
      final res = await send(await _auth());
      return res.data ?? const {};
    } on DioException catch (e) {
      final ex = _map(e);
      final onBanned = _onDeviceBanned;
      if (onBanned != null && ex.isDeviceBanned) {
        scheduleMicrotask(() {
          try {
            onBanned();
          } on Object catch (e) {
            debugPrint('reflections: device banned hook ${e.runtimeType}');
          }
        });
      }
      throw ex;
    }
  }

  static String _id(String id) => Uri.encodeComponent(id);

  static String _base(String roomId) => '/v1/rooms/${_id(roomId)}/reflections';

  @override
  Future<ReflectionList> list(String roomId) async => ReflectionList.fromJson(
    await _call(
      (auth) => _dio.get<Map<String, dynamic>>(_base(roomId), options: auth),
    ),
  );

  @override
  Future<Reflection> get(String roomId, String reflectionId) async =>
      Reflection.fromJson(
        await _call(
          (auth) => _dio.get<Map<String, dynamic>>(
            '${_base(roomId)}/${_id(reflectionId)}',
            options: auth,
          ),
        ),
      );

  @override
  Future<SendOutcome> send(
    String roomId, {
    required String reflectionId,
    required String text,
  }) async => SendOutcome.fromJson(
    await _call(
      (auth) => _dio.post<Map<String, dynamic>>(
        _base(roomId),
        // Exactly the two keys: no parentId (no replies, REQ-REF-05).
        data: {'reflectionId': reflectionId, 'text': text},
        options: auth,
      ),
    ),
  );

  @override
  Future<void> delete(String roomId, String reflectionId) async {
    await _call(
      (auth) => _dio.delete<Map<String, dynamic>>(
        '${_base(roomId)}/${_id(reflectionId)}',
        options: auth,
      ),
    );
  }

  @override
  Future<GestureAck> sendGesture(
    String roomId,
    GestureType type, {
    required String reflectionId,
  }) async => GestureAck.fromJson(
    await _call(
      (auth) => _dio.post<Map<String, dynamic>>(
        '/v1/rooms/${_id(roomId)}/gestures',
        data: {
          'type': type.wire,
          'target': 'reflection',
          'toReflectionId': reflectionId,
        },
        options: auth,
      ),
    ),
  );

  /// Same mapping as `AuraApi`: a response's `code`, else `http_<status>`;
  /// no response at all is a network failure. Never carries bodies.
  static ApiException _map(DioException e) {
    final res = e.response;
    if (res == null) return ApiException(code: e.type.name, isNetwork: true);
    final data = res.data;
    final code = data is Map && data['code'] is String
        ? data['code'] as String
        : 'http_${res.statusCode}';
    return ApiException(code: code, status: res.statusCode);
  }
}
