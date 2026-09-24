import 'dart:async';

import 'package:dio/dio.dart';

import '../net/aura_api.dart' show ApiException;
import 'entitlement.dart';

/// `POST /v1/billing/purchases` outcome (contracts/api/v1-billing.md §2.2).
enum VerifyStatus {
  granted,
  pending,
  confirming,
  notActive,
  refunded,
  ownedElsewhere;

  static VerifyStatus parse(Object? v) => switch (v) {
    'granted' => granted,
    'pending' => pending,
    'confirming' => confirming,
    'refunded' => refunded,
    'owned_elsewhere' => ownedElsewhere,
    _ => notActive,
  };

  /// The store transaction can be finished: the server has it for good.
  bool get settled => this != confirming;
}

class VerifyResult {
  const VerifyResult(this.status, this.entitlement, {this.gift});

  final VerifyStatus status;
  final Entitlement entitlement;

  /// `delivered` · `already` · `unmatched` for a gift.
  final String? gift;
}

class RestoreResult {
  const RestoreResult({
    required this.restored,
    required this.ownedElsewhere,
    required this.confirming,
    required this.invalid,
    required this.entitlement,
  });

  final int restored;
  final int ownedElsewhere;
  final int confirming;
  final int invalid;
  final Entitlement entitlement;
}

class GiftCheck {
  const GiftCheck({
    required this.giftId,
    required this.productId,
    required this.accountToken,
  });

  final String giftId;
  final String productId;
  final String accountToken;
}

class ReceivedGift {
  const ReceivedGift({
    required this.giftId,
    required this.kind,
    required this.stardust,
    this.roomId,
  });

  final String giftId;
  final String kind;
  final int stardust;
  final String? roomId;
}

/// A purchase for the server to confirm with its store.
sealed class StoreProof {
  const StoreProof(this.productId);
  final String productId;
}

class AppleProof extends StoreProof {
  const AppleProof(super.productId, this.signedTransaction);

  /// StoreKit 2 `jwsRepresentation`.
  final String signedTransaction;
}

class GoogleProof extends StoreProof {
  const GoogleProof(super.productId, this.purchaseToken);
  final String purchaseToken;
}

/// NestJS billing (F12). Purchases, restores and gifts are online only
/// (16-offline): nothing here is ever queued. Receipts are never logged.
abstract interface class BillingApi {
  Future<Entitlement> entitlement();

  Future<VerifyResult> verify(
    StoreProof proof, {
    String? priceDisplay,
    String? giftId,
  });

  Future<RestoreResult> restore(List<StoreProof> proofs);

  /// §4.1 pre-check before the store sheet. Throws [ApiException] with the
  /// refusal code (`gift_unavailable`, `gift_daily_limit`, …).
  Future<GiftCheck> checkGift({
    required String giftId,
    required String roomId,
    required String memberId,
    required String kind,
  });

  Future<void> cancelGift(String giftId);

  Future<List<ReceivedGift>> receivedGifts();

  Future<void> giftsSeen(List<String> giftIds);

  Future<Entitlement> redeem(String cosmeticId, String redemptionId);

  Future<Entitlement> setSky(String theme, String? soundscape);
}

class HttpBillingApi implements BillingApi {
  HttpBillingApi({
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
               // The server asks the store (up to 10 s) before answering.
               receiveTimeout: const Duration(seconds: 20),
               contentType: Headers.jsonContentType,
               responseType: ResponseType.json,
               // 202 "confirming" is a normal answer.
               validateStatus: (s) => s != null && s >= 200 && s < 300,
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

  Future<Map<String, dynamic>> _call(
    String method,
    String path, [
    Object? body,
  ]) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(
        path,
        data: body,
        options: (await _auth()).copyWith(method: method),
      );
      return res.data ?? const {};
    } on DioException catch (e) {
      final res = e.response;
      if (res == null) {
        throw const ApiException(code: 'network', isNetwork: true);
      }
      final data = res.data;
      final code = data is Map && data['code'] is String
          ? data['code'] as String
          : 'http_${res.statusCode}';
      throw ApiException(code: code, status: res.statusCode);
    }
  }

  Map<String, dynamic> _proof(StoreProof p) => switch (p) {
    AppleProof() => {
      'store': 'apple',
      'productId': p.productId,
      'signedTransaction': p.signedTransaction,
    },
    GoogleProof() => {
      'store': 'google',
      'productId': p.productId,
      'purchaseToken': p.purchaseToken,
    },
  };

  static Entitlement _ent(Object? v) =>
      v is Map<String, dynamic> ? Entitlement.fromJson(v) : Entitlement.none;

  @override
  Future<Entitlement> entitlement() async =>
      Entitlement.fromJson(await _call('GET', '/v1/billing/entitlement'));

  @override
  Future<VerifyResult> verify(
    StoreProof proof, {
    String? priceDisplay,
    String? giftId,
  }) async {
    final r = await _call('POST', '/v1/billing/purchases', {
      ..._proof(proof),
      'priceDisplay': ?priceDisplay,
      'giftId': ?giftId,
    });
    return VerifyResult(
      VerifyStatus.parse(r['status']),
      _ent(r['entitlement']),
      gift: r['gift'] as String?,
    );
  }

  @override
  Future<RestoreResult> restore(List<StoreProof> proofs) async {
    final apple = [
      for (final p in proofs)
        if (p is AppleProof) p.signedTransaction,
    ];
    final google = [
      for (final p in proofs)
        if (p is GoogleProof)
          {'productId': p.productId, 'purchaseToken': p.purchaseToken},
    ];
    final r = await _call('POST', '/v1/billing/restore', {
      if (apple.isNotEmpty) 'apple': {'signedTransactions': apple},
      if (google.isNotEmpty) 'google': {'purchases': google},
    });
    int n(String k) => (r[k] as num?)?.toInt() ?? 0;
    return RestoreResult(
      restored: n('restored'),
      ownedElsewhere: n('ownedElsewhere'),
      confirming: n('confirming'),
      invalid: n('invalid'),
      entitlement: _ent(r['entitlement']),
    );
  }

  @override
  Future<GiftCheck> checkGift({
    required String giftId,
    required String roomId,
    required String memberId,
    required String kind,
  }) async {
    final r = await _call('POST', '/v1/billing/gifts', {
      'giftId': giftId,
      'roomId': roomId,
      'memberId': memberId,
      'kind': kind,
    });
    return GiftCheck(
      giftId: r['giftId'] as String? ?? giftId,
      productId: r['productId'] as String? ?? '',
      accountToken: r['accountToken'] as String? ?? '',
    );
  }

  @override
  Future<void> cancelGift(String giftId) async {
    await _call('DELETE', '/v1/billing/gifts/${Uri.encodeComponent(giftId)}');
  }

  @override
  Future<List<ReceivedGift>> receivedGifts() async {
    final r = await _call('GET', '/v1/billing/gifts/received');
    return [
      for (final g in (r['gifts'] as List? ?? const []))
        if (g is Map && g['giftId'] is String)
          ReceivedGift(
            giftId: g['giftId'] as String,
            kind: g['kind'] as String? ?? '',
            stardust: (g['stardust'] as num?)?.toInt() ?? 0,
            roomId: g['roomId'] as String?,
          ),
    ];
  }

  @override
  Future<void> giftsSeen(List<String> giftIds) async {
    if (giftIds.isEmpty) return;
    await _call('POST', '/v1/billing/gifts/received/seen', {
      'giftIds': giftIds,
    });
  }

  @override
  Future<Entitlement> redeem(String cosmeticId, String redemptionId) async =>
      Entitlement.fromJson(
        await _call('POST', '/v1/billing/stardust/redeem', {
          'cosmeticId': cosmeticId,
          'redemptionId': redemptionId,
        }),
      );

  @override
  Future<Entitlement> setSky(String theme, String? soundscape) async =>
      Entitlement.fromJson(
        await _call('PUT', '/v1/billing/sky', {
          'theme': theme,
          'soundscape': soundscape,
        }),
      );
}
