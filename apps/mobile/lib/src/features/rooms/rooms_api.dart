import 'package:aura_domain/aura_domain.dart';
import 'package:dio/dio.dart';

import '../../core/net/aura_api.dart' show ApiException;
import 'room_models.dart';

/// `POST /v1/rooms/match` body.
class MatchRequest {
  const MatchRequest({
    required this.quadrant,
    required this.moodId,
    this.timezone,
    this.allowPoolFallback = false,
  });

  final Quadrant quadrant;

  /// The saved check-in's mood (a catalogue mood in [quadrant]).
  final String moodId;

  /// The device's IANA zone now: its UTC offset picks the room region.
  final String? timezone;

  /// "Join English room" after `409 language_pool_unavailable`.
  final bool allowPoolFallback;

  Map<String, dynamic> toJson() => {
    'quadrant': quadrant.name,
    'moodId': moodId,
    if (timezone != null) 'timezone': timezone,
    if (allowPoolFallback) 'allowPoolFallback': true,
  };
}

/// NestJS Mood Rooms (F5) and core safety (F9) routes,
/// contracts/api/v1-rooms.md. Every failure is an [ApiException] (same
/// codes and status as `AuraApi`). Rooms are online only: callers never
/// queue these (the repository refuses offline before calling).
abstract interface class RoomsApi {
  Future<MatchResult> match(MatchRequest request);

  /// Rooms you are in, newest first (active ones and memories).
  Future<List<RoomSummary>> rooms();

  /// Members only; anything else is `404 not_found`.
  Future<RoomDetail> room(String roomId);

  Future<HeartbeatResult> heartbeat(String roomId);

  /// A `member` gesture when [toMemberId] is set, else a `room` one.
  Future<GestureAck> sendGesture(
    String roomId,
    GestureType type, {
    String? toMemberId,
  });

  /// Leaves for good → whether to ask "Did you feel less alone?".
  Future<bool> leave(String roomId);

  Future<void> survey(String roomId, SurveyAnswer answer);

  Future<void> mute(String roomId, String memberId);

  Future<void> unmute(String roomId, String memberId);

  Future<ReportAck> report(
    ReportTarget target,
    ReportReason reason, {
    String? note,
  });

  /// → the block id (the person is resolved on the server; never told).
  Future<String> block(String roomId, String memberId);

  Future<SafetyStanding> standing();
}

/// [RoomsApi] over Dio, with the same auth, timeouts and error mapping as
/// `AuraApi` (core/net/aura_api.dart).
class HttpRoomsApi implements RoomsApi {
  HttpRoomsApi({
    required String baseUrl,
    required this._accessToken,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 6),
               sendTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 12),
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

  Future<Map<String, dynamic>> _get(String path) =>
      _call(() async => _dio.get<Map<String, dynamic>>(
        path,
        options: await _auth(),
      ));

  Future<Map<String, dynamic>> _post(String path, [Object? body]) =>
      _call(() async => _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: await _auth(),
      ));

  Future<Map<String, dynamic>> _call(
    Future<Response<Map<String, dynamic>>> Function() send,
  ) async {
    try {
      final res = await send();
      return res.data ?? const {};
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  static String _id(String id) => Uri.encodeComponent(id);

  @override
  Future<MatchResult> match(MatchRequest request) async =>
      MatchResult.fromJson(await _post('/v1/rooms/match', request.toJson()));

  @override
  Future<List<RoomSummary>> rooms() async {
    final data = await _get('/v1/rooms');
    final list = data['rooms'];
    if (list is! List) return const [];
    return [
      for (final r in list)
        if (r is Map<String, dynamic>) RoomSummary.fromJson(r),
    ];
  }

  @override
  Future<RoomDetail> room(String roomId) async =>
      RoomDetail.fromJson(await _get('/v1/rooms/${_id(roomId)}'));

  @override
  Future<HeartbeatResult> heartbeat(String roomId) async =>
      HeartbeatResult.fromJson(
        await _post('/v1/rooms/${_id(roomId)}/heartbeat'),
      );

  @override
  Future<GestureAck> sendGesture(
    String roomId,
    GestureType type, {
    String? toMemberId,
  }) async => GestureAck.fromJson(
    await _post('/v1/rooms/${_id(roomId)}/gestures', {
      'type': type.wire,
      'target': toMemberId == null ? 'room' : 'member',
      'toMemberId': ?toMemberId,
    }),
  );

  @override
  Future<bool> leave(String roomId) async =>
      (await _post('/v1/rooms/${_id(roomId)}/leave'))['surveyEligible'] ==
      true;

  @override
  Future<void> survey(String roomId, SurveyAnswer answer) async {
    await _post('/v1/rooms/${_id(roomId)}/survey', {'answer': answer.name});
  }

  @override
  Future<void> mute(String roomId, String memberId) async {
    await _post('/v1/rooms/${_id(roomId)}/mutes', {'memberId': memberId});
  }

  @override
  Future<void> unmute(String roomId, String memberId) => _call(
    () async => _dio.delete<Map<String, dynamic>>(
      '/v1/rooms/${_id(roomId)}/mutes/${_id(memberId)}',
      options: await _auth(),
    ),
  );

  @override
  Future<ReportAck> report(
    ReportTarget target,
    ReportReason reason, {
    String? note,
  }) async => ReportAck.fromJson(
    await _post('/v1/safety/reports', {
      'target': target.toJson(),
      'reason': reason.wire,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    }),
  );

  @override
  Future<String> block(String roomId, String memberId) async {
    final data = await _post('/v1/safety/blocks', {
      'roomId': roomId,
      'memberId': memberId,
    });
    return data['blockId'] as String? ?? '';
  }

  @override
  Future<SafetyStanding> standing() async =>
      SafetyStanding.fromJson(await _get('/v1/safety/me'));

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
