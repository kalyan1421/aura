import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/net/aura_api.dart' show ApiException;

/// What a grievance is about (server `GRIEVANCE_CATEGORIES`,
/// `server/aura-api/src/admin/clocks.ts`). The wire value never changes
/// meaning; the timelines per category are the server's (IT Rules 2021).
enum GrievanceCategory {
  general('general'),
  unlawfulContent('unlawful_content'),
  nudityCsam('nudity_csam'),
  ncii('ncii'),
  dataRequest('data_request'),
  moderationAppeal('moderation_appeal');

  const GrievanceCategory(this.wire);

  final String wire;
}

/// Limits of `POST /v1/grievances` (server `publicGrievanceSchema`).
abstract final class GrievanceLimits {
  static const int descriptionMin = 10;
  static const int descriptionMax = 5000;
  static const int nameMax = 120;
  static const int emailMax = 254;
  static const int whereMax = 1000;
}

/// The acknowledgement: the ticket id and when it will be resolved by. The
/// server also emails it to [email].
@immutable
class GrievanceReceipt {
  const GrievanceReceipt({required this.ticket, required this.resolveBy});

  final String ticket;
  final DateTime resolveBy;
}

/// The Grievance Officer's public form (PRD F9 "ticketed form,
/// auto-acknowledged"; REQ-SAFE-11; contracts/api/v1.md "Grievances"). No
/// login: it works signed out, on a closed account and on a banned device.
abstract interface class GrievanceApi {
  Future<GrievanceReceipt> submit({
    required GrievanceCategory category,
    required String email,
    required String description,
    String? name,
    String? where,
    String? locale,
  });
}

/// [GrievanceApi] over Dio. The text is sent once, over TLS, and never
/// logged; errors carry only the server's code.
class HttpGrievanceApi implements GrievanceApi {
  HttpGrievanceApi({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 6),
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;

  @override
  Future<GrievanceReceipt> submit({
    required GrievanceCategory category,
    required String email,
    required String description,
    String? name,
    String? where,
    String? locale,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/v1/grievances',
        data: {
          'category': category.wire,
          'email': email,
          'description': description,
          if (name != null && name.isNotEmpty) 'name': name,
          if (where != null && where.isNotEmpty) 'contentLocation': where,
          'locale': ?locale,
          'channel': 'in_app',
        },
      );
      final data = res.data;
      final ticket = data is Map ? data['ticket'] : null;
      final resolveBy = data is Map
          ? DateTime.tryParse('${data['resolveBy']}')
          : null;
      if (ticket is! String || resolveBy == null) {
        throw const ApiException(code: 'bad_response', status: 200);
      }
      return GrievanceReceipt(ticket: ticket, resolveBy: resolveBy.toLocal());
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

/// `null` when this build has no API (the email route stays).
final grievanceApiProvider = Provider<GrievanceApi?>(
  (ref) => Env.hasApi ? HttpGrievanceApi(baseUrl: Env.apiUrl) : null,
);
