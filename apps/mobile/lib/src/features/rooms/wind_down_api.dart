import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/net/aura_api.dart' show ApiException;
import '../../core/providers.dart';

/// F16 Lantern Hour wind-down in a room (contracts/api/v1-quiet.md §2). A
/// room total and presets only: never who is winding down. Plain classes,
/// no codegen.
@immutable
class WindDownCue {
  const WindDownCue(this.atS, this.key);

  final int atS;
  final String key;
}

@immutable
class WindDownView {
  const WindDownView({
    required this.state,
    required this.startsAtMs,
    required this.endsAtMs,
    required this.count,
    required this.joined,
    required this.stems,
    required this.cues,
    this.inhaleMs = 4000,
    this.exhaleMs = 6000,
  });

  factory WindDownView.fromJson(Map<String, dynamic> j) {
    int n(Object? v, int fallback) => v is num ? v.toInt() : fallback;
    final pacer = j['pacer'];
    final sound = j['soundscape'];
    return WindDownView(
      state: j['state'] is String ? j['state'] as String : 'open',
      startsAtMs: n(j['startsAtMs'], 0),
      endsAtMs: n(j['endsAtMs'], 0),
      count: n(j['count'], 0),
      joined: j['joined'] == true,
      inhaleMs: pacer is Map ? n(pacer['inhaleMs'], 4000) : 4000,
      exhaleMs: pacer is Map ? n(pacer['exhaleMs'], 6000) : 6000,
      stems: sound is Map && sound['stems'] is List
          ? [
              for (final s in sound['stems'] as List)
                if (s is String) s,
            ]
          : const [],
      cues: j['cues'] is List
          ? [
              for (final c in j['cues'] as List)
                if (c is Map && c['key'] is String)
                  WindDownCue(n(c['atS'], 0), c['key'] as String),
            ]
          : const [],
    );
  }

  /// `soon` (Lantern Hour, before 22:30) or `open`.
  final String state;

  /// The common start (server clock): pacer, cues and the sound run from it.
  final int startsAtMs;
  final int endsAtMs;

  /// "N winding down": a room total.
  final int count;

  /// You opted in (only ever about you).
  final bool joined;
  final List<String> stems;
  final List<WindDownCue> cues;
  final int inhaleMs;
  final int exhaleMs;

  bool get isOpen => state == 'open';

  WindDownView copyWith({String? state, int? count, bool? joined}) =>
      WindDownView(
        state: state ?? this.state,
        startsAtMs: startsAtMs,
        endsAtMs: endsAtMs,
        count: count ?? this.count,
        joined: joined ?? this.joined,
        stems: stems,
        cues: cues,
        inhaleMs: inhaleMs,
        exhaleMs: exhaleMs,
      );

  /// The cue on screen [elapsedS] seconds in (the last one that started).
  WindDownCue? cueAt(int elapsedS) {
    WindDownCue? out;
    for (final c in cues) {
      if (c.atS <= elapsedS) out = c;
    }
    return out;
  }
}

/// A response: the view (or none) and the server clock sample.
@immutable
class WindDownReply {
  const WindDownReply(this.view, this.serverTimeMs);

  final WindDownView? view;
  final int serverTimeMs;
}

abstract interface class WindDownApi {
  Future<WindDownReply> get(String roomId);

  /// Opt in (idempotent).
  Future<WindDownReply> join(String roomId);

  /// Opt out (idempotent). Costs nothing.
  Future<void> leave(String roomId);
}

class HttpWindDownApi implements WindDownApi {
  HttpWindDownApi({
    required String baseUrl,
    required this.accessToken,
    Dio? dio,
  }) : _dio =
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

  String _path(String roomId) =>
      '/v1/rooms/${Uri.encodeComponent(roomId)}/wind-down';

  Future<Map<String, dynamic>> _call(String method, String roomId) async {
    final token = await accessToken();
    if (token == null) {
      throw const ApiException(code: 'signed_out', status: 401);
    }
    try {
      final res = await _dio.request<dynamic>(
        _path(roomId),
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      final data = res.data;
      return data is Map<String, dynamic> ? data : const {};
    } on DioException catch (e) {
      final res = e.response;
      if (res == null) throw ApiException(code: e.type.name, isNetwork: true);
      final data = res.data;
      throw ApiException(
        code: data is Map && data['code'] is String
            ? data['code'] as String
            : 'http_${res.statusCode}',
        status: res.statusCode,
      );
    }
  }

  static WindDownReply _reply(Map<String, dynamic> data) {
    final v = data['windDown'];
    return WindDownReply(
      v is Map<String, dynamic> ? WindDownView.fromJson(v) : null,
      data['serverTimeMs'] is num ? (data['serverTimeMs'] as num).toInt() : 0,
    );
  }

  @override
  Future<WindDownReply> get(String roomId) async =>
      _reply(await _call('GET', roomId));

  @override
  Future<WindDownReply> join(String roomId) async =>
      _reply(await _call('POST', roomId));

  @override
  Future<void> leave(String roomId) async {
    await _call('DELETE', roomId);
  }
}

/// `null` when this build has no API (debug builds without config).
final windDownApiProvider = Provider<WindDownApi?>((ref) {
  if (!Env.hasApi) return null;
  final auth = ref.watch(authRepositoryProvider);
  return HttpWindDownApi(baseUrl: Env.apiUrl, accessToken: auth.accessToken);
});
