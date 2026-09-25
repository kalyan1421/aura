import 'package:aura_domain/aura_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/net/aura_api.dart' show ApiException;

/// One of the person's own keepsakes: a catalogue key and the Aura day it was
/// earned (contracts/api/v1-keepsakes.md). Nothing else exists.
@immutable
class OwnKeepsake {
  const OwnKeepsake(this.key, this.earnedOn);

  final String key;
  final LocalDay earnedOn;

  /// `null` for a malformed row (never shown).
  static OwnKeepsake? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final day = LocalDay.tryParse(json['earnedOn'] as String?);
    if (key is! String || day == null) return null;
    return OwnKeepsake(key, day);
  }

  Map<String, Object> toJson() => {'key': key, 'earnedOn': earnedOn.toIso()};

  @override
  bool operator ==(Object other) =>
      other is OwnKeepsake && other.key == key && other.earnedOn == earnedOn;

  @override
  int get hashCode => Object.hash(key, earnedOn);
}

/// `GET /v1/keepsakes`: the caller's own keepsakes, after the server awarded
/// anything newly reached. There is no call that names another person.
abstract interface class KeepsakesApi {
  Future<List<OwnKeepsake>> mine();
}

/// [KeepsakesApi] over Dio, with the same auth, timeouts and error mapping as
/// the other feature clients.
class HttpKeepsakesApi implements KeepsakesApi {
  HttpKeepsakesApi({
    required String baseUrl,
    required this.accessToken,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 6),
               receiveTimeout: const Duration(seconds: 8),
               responseType: ResponseType.json,
             ),
           );

  final Dio _dio;
  final Future<String?> Function() accessToken;

  @override
  Future<List<OwnKeepsake>> mine() async {
    final token = await accessToken();
    if (token == null) {
      throw const ApiException(code: 'signed_out', status: 401);
    }
    try {
      final res = await _dio.get<dynamic>(
        '/v1/keepsakes',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      final list = data is Map ? data['keepsakes'] : null;
      if (list is! List) return const [];
      return [for (final j in list) ?OwnKeepsake.tryFromJson(j)];
    } on DioException catch (e) {
      final r = e.response;
      if (r == null) throw ApiException(code: e.type.name, isNetwork: true);
      final d = r.data;
      throw ApiException(
        code: d is Map && d['code'] is String
            ? d['code'] as String
            : 'http_${r.statusCode}',
        status: r.statusCode,
      );
    }
  }
}
