import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/net/aura_api.dart' show ApiException;
import 'ripple_models.dart';

/// NestJS Breath Ripples routes (contracts/api/v1-ripples.md). Every failure
/// is an [ApiException] (same codes and status as `AuraApi`). Online only:
/// callers never queue these.
abstract interface class RipplesApi {
  /// Enqueue (first call) or poll (same [ticketId]).
  Future<MatchPoll> match(String ticketId, RippleEntry entry, {String? roomId});

  /// Leave the lobby.
  Future<void> cancel(String ticketId);

  Future<RippleSession> session(String sessionId);

  /// Silent leave: the light dims into an echo for the others.
  Future<void> leave(String sessionId);

  /// Cycles completed and this player's own transitions (50 ms steps).
  Future<void> complete(String sessionId, int cycles, List<int?>? offsets);

  /// → whether the Safety Center should open (reason 1).
  Future<bool> report(String sessionId, int seat, int reason, {String? note});

  Future<void> block(String sessionId, int seat);

  /// A seat went over the event budget (receivers already drop the excess).
  Future<void> flood(String sessionId, int seat);

  Future<RippleInvite?> roomInvite(String roomId);

  Future<bool> echoConsent();

  Future<bool> setEchoConsent(bool enabled);
}

/// [RipplesApi] over Dio, with the same auth, timeouts and error mapping as
/// `AuraApi` / `HttpRoomsApi`.
class HttpRipplesApi implements RipplesApi {
  HttpRipplesApi({required String baseUrl, required this.accessToken, Dio? dio})
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

  Future<Options> _auth() async {
    final token = await accessToken();
    if (token == null) {
      throw const ApiException(code: 'signed_out', status: 401);
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> _call(
    Future<Response<dynamic>> Function(Options auth) send,
  ) async {
    try {
      final res = await send(await _auth());
      final data = res.data;
      return data is Map<String, dynamic> ? data : const {};
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  static String _id(String id) => Uri.encodeComponent(id);
  static const String _base = '/v1/ripples';

  @override
  Future<MatchPoll> match(
    String ticketId,
    RippleEntry entry, {
    String? roomId,
  }) async => MatchPoll.fromJson(
    await _call(
      (o) => _dio.post<dynamic>(
        '$_base/match',
        data: {'ticketId': ticketId, 'entry': entry.name, 'roomId': ?roomId},
        options: o,
      ),
    ),
  );

  @override
  Future<void> cancel(String ticketId) async {
    await _call(
      (o) => _dio.delete<dynamic>('$_base/match/${_id(ticketId)}', options: o),
    );
  }

  @override
  Future<RippleSession> session(String sessionId) async =>
      RippleSession.fromJson(
        await _call(
          (o) => _dio.get<dynamic>(
            '$_base/sessions/${_id(sessionId)}',
            options: o,
          ),
        ),
      );

  @override
  Future<void> leave(String sessionId) async {
    await _call(
      (o) => _dio.post<dynamic>(
        '$_base/sessions/${_id(sessionId)}/leave',
        options: o,
      ),
    );
  }

  @override
  Future<void> complete(
    String sessionId,
    int cycles,
    List<int?>? offsets,
  ) async {
    await _call(
      (o) => _dio.post<dynamic>(
        '$_base/sessions/${_id(sessionId)}/complete',
        data: {
          'cycles': cycles,
          if (offsets != null && offsets.isNotEmpty)
            'trace': {'offsets': offsets},
        },
        options: o,
      ),
    );
  }

  @override
  Future<bool> report(
    String sessionId,
    int seat,
    int reason, {
    String? note,
  }) async {
    final data = await _call(
      (o) => _dio.post<dynamic>(
        '$_base/sessions/${_id(sessionId)}/reports',
        data: {
          'seat': seat,
          'reason': reason,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
        options: o,
      ),
    );
    return data['showHelplines'] == true;
  }

  @override
  Future<void> block(String sessionId, int seat) async {
    await _call(
      (o) => _dio.post<dynamic>(
        '$_base/sessions/${_id(sessionId)}/blocks',
        data: {'seat': seat},
        options: o,
      ),
    );
  }

  @override
  Future<void> flood(String sessionId, int seat) async {
    await _call(
      (o) => _dio.post<dynamic>(
        '$_base/sessions/${_id(sessionId)}/flood',
        data: {'seat': seat},
        options: o,
      ),
    );
  }

  @override
  Future<RippleInvite?> roomInvite(String roomId) async {
    final data = await _call(
      (o) =>
          _dio.get<dynamic>('$_base/rooms/${_id(roomId)}/invite', options: o),
    );
    final invite = data['invite'];
    return invite is Map<String, dynamic>
        ? RippleInvite.fromJson(invite)
        : null;
  }

  @override
  Future<bool> echoConsent() async {
    final data = await _call(
      (o) => _dio.get<dynamic>('$_base/echo-consent', options: o),
    );
    return data['enabled'] != false;
  }

  @override
  Future<bool> setEchoConsent(bool enabled) async {
    final data = await _call(
      (o) => _dio.put<dynamic>(
        '$_base/echo-consent',
        data: {'enabled': enabled},
        options: o,
      ),
    );
    return data['enabled'] != false;
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
      debugPrint('ripples: server answered ${res.statusCode} ($code)');
    }
    return ApiException(code: code, status: res.statusCode);
  }
}

/// Which lobby state an error means, or `null` for "keep trying quietly".
RipplesUnavailable? unavailableFor(Object error) {
  if (error is! ApiException) return null;
  if (error.isNetwork) return RipplesUnavailable.offline;
  return switch (error.code) {
    'ripples_paused' => RipplesUnavailable.paused,
    'rooms_suspended' => RipplesUnavailable.suspended,
    'account_closed' => RipplesUnavailable.closed,
    'guidelines_required' => RipplesUnavailable.guidelines,
    _ => null,
  };
}
