import 'package:flutter/foundation.dart';

/// The server-validated entitlement (`GET /v1/billing/entitlement`,
/// contracts/api/v1-billing.md §2.1). NestJS owns it (DS-9): the app only
/// caches the last answer and never grants anything itself.
enum PlusStatus {
  none,
  pending,
  trial,
  active,
  cancelled,
  grace,
  billingRetry,
  paused,
  expired,
  refunded,
  revoked;

  static PlusStatus parse(Object? v) => switch (v) {
    'pending' => pending,
    'trial' => trial,
    'active' => active,
    'cancelled' => cancelled,
    'grace' => grace,
    'billing_retry' => billingRetry,
    'paused' => paused,
    'expired' => expired,
    'refunded' => refunded,
    'revoked' => revoked,
    _ => none,
  };

  String get wire => switch (this) {
    billingRetry => 'billing_retry',
    _ => name,
  };
}

enum PlusStore {
  apple,
  google;

  static PlusStore? parse(Object? v) => switch (v) {
    'apple' => apple,
    'google' => google,
    _ => null,
  };
}

/// In-app notices (PRD 12 / 14-states). Unknown kinds are dropped.
enum PlusNoticeKind {
  trialEnding,
  trialCancelled,
  billingIssue,
  billingPaused,
  refunded,
  plusContinues;

  static PlusNoticeKind? parse(Object? v) => switch (v) {
    'trial_ending' => trialEnding,
    'trial_cancelled' => trialCancelled,
    'billing_issue' => billingIssue,
    'billing_paused' => billingPaused,
    'refunded' => refunded,
    'plus_continues' => plusContinues,
    _ => null,
  };

  String get wire => switch (this) {
    trialEnding => 'trial_ending',
    trialCancelled => 'trial_cancelled',
    billingIssue => 'billing_issue',
    billingPaused => 'billing_paused',
    refunded => 'refunded',
    plusContinues => 'plus_continues',
  };
}

@immutable
class PlusNotice {
  const PlusNotice({
    required this.kind,
    required this.key,
    this.date,
    this.price,
  });

  final PlusNoticeKind kind;
  final DateTime? date;

  /// The store's localized price string (trial ending), never hard-coded.
  final String? price;

  /// Stable per event: one-time notes are shown once per key.
  final String key;
}

enum GiftingState {
  ok,
  paused,
  disabled;

  static GiftingState parse(Object? v) => switch (v) {
    'paused' => paused,
    'disabled' => disabled,
    _ => ok,
  };
}

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toUtc() : null;

@immutable
class Entitlement {
  const Entitlement({
    required this.accountToken,
    required this.plusActive,
    required this.status,
    this.store,
    this.productId,
    this.autoRenew,
    this.trialEndsAt,
    this.expiresAt,
    this.graceEndsAt,
    this.validUntil,
    this.notices = const [],
    this.ownedCosmetics = const [],
    this.availableSkies = const ['night'],
    this.sky = 'night',
    this.soundscape,
    this.stardust = 0,
    this.gifting = GiftingState.ok,
    this.giftingUntil,
    this.giftsSentToday = 0,
    this.giftsDailyLimit = 5,
    this.giftsUnseen = 0,
    this.paywallAllowedFrom,
    this.serverTime,
  });

  /// Nothing known yet: Plus off, the free sky, no paywall (no profile).
  static const Entitlement none = Entitlement(
    accountToken: '',
    plusActive: false,
    status: PlusStatus.none,
  );

  /// The store token (`appAccountToken` / `obfuscatedAccountId`).
  final String accountToken;
  final bool plusActive;
  final PlusStatus status;
  final PlusStore? store;
  final String? productId;
  final bool? autoRenew;
  final DateTime? trialEndsAt;
  final DateTime? expiresAt;
  final DateTime? graceEndsAt;

  /// A cached `plusActive` is honoured until then (16-offline).
  final DateTime? validUntil;
  final List<PlusNotice> notices;
  final List<String> ownedCosmetics;
  final List<String> availableSkies;
  final String sky;
  final String? soundscape;
  final int stardust;
  final GiftingState gifting;
  final DateTime? giftingUntil;
  final int giftsSentToday;
  final int giftsDailyLimit;
  final int giftsUnseen;

  /// No paywall before this (24 h after onboarding). `null` = never.
  final DateTime? paywallAllowedFrom;
  final DateTime? serverTime;

  /// Plus is on at [now]: the server said so and the period hasn't run out.
  bool plusActiveAt(DateTime now) {
    final until = validUntil;
    return plusActive && until != null && now.isBefore(until);
  }

  bool get isAnnual => productId == 'aura_plus_annual';

  factory Entitlement.fromJson(Map<String, dynamic> j) {
    final plus = (j['plus'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cos = (j['cosmetics'] as Map?)?.cast<String, dynamic>() ?? const {};
    final sky = (j['sky'] as Map?)?.cast<String, dynamic>() ?? const {};
    final gifting = (j['gifting'] as Map?)?.cast<String, dynamic>() ?? const {};
    List<String> strings(Object? v) => v is List
        ? [
            for (final x in v)
              if (x is String) x,
          ]
        : const [];
    return Entitlement(
      accountToken: j['accountToken'] as String? ?? '',
      plusActive: plus['active'] == true,
      status: PlusStatus.parse(plus['status']),
      store: PlusStore.parse(plus['store']),
      productId: plus['productId'] as String?,
      autoRenew: plus['autoRenew'] as bool?,
      trialEndsAt: _date(plus['trialEndsAt']),
      expiresAt: _date(plus['expiresAt']),
      graceEndsAt: _date(plus['graceEndsAt']),
      validUntil: _date(plus['validUntil']),
      notices: [
        for (final n in (j['notices'] as List? ?? const []))
          if (n is Map && PlusNoticeKind.parse(n['kind']) != null)
            PlusNotice(
              kind: PlusNoticeKind.parse(n['kind'])!,
              key: n['key'] as String? ?? '${n['kind']}',
              date: _date(n['date']),
              price: n['price'] as String?,
            ),
      ],
      ownedCosmetics: strings(cos['owned']),
      availableSkies: cos['available'] == null
          ? const ['night']
          : strings(cos['available']),
      sky: sky['theme'] as String? ?? 'night',
      soundscape: sky['soundscape'] as String?,
      stardust: ((j['stardust'] as Map?)?['balance'] as num?)?.toInt() ?? 0,
      gifting: GiftingState.parse(gifting['state']),
      giftingUntil: _date(gifting['until']),
      giftsSentToday: (gifting['sentToday'] as num?)?.toInt() ?? 0,
      giftsDailyLimit: (gifting['dailyLimit'] as num?)?.toInt() ?? 5,
      giftsUnseen: (j['giftsUnseen'] as num?)?.toInt() ?? 0,
      paywallAllowedFrom: _date((j['paywall'] as Map?)?['allowedFrom']),
      serverTime: _date(j['serverTime']),
    );
  }

  Map<String, dynamic> toJson() => {
    'accountToken': accountToken,
    'plus': {
      'active': plusActive,
      'status': status.wire,
      'store': store?.name,
      'productId': productId,
      'autoRenew': autoRenew,
      'trialEndsAt': trialEndsAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'graceEndsAt': graceEndsAt?.toIso8601String(),
      'validUntil': validUntil?.toIso8601String(),
    },
    'notices': [
      for (final n in notices)
        {
          'kind': n.kind.wire,
          'key': n.key,
          'date': n.date?.toIso8601String(),
          'price': n.price,
        },
    ],
    'cosmetics': {'owned': ownedCosmetics, 'available': availableSkies},
    'sky': {'theme': sky, 'soundscape': soundscape},
    'stardust': {'balance': stardust},
    'gifting': {
      'state': gifting.name,
      'until': giftingUntil?.toIso8601String(),
      'sentToday': giftsSentToday,
      'dailyLimit': giftsDailyLimit,
    },
    'giftsUnseen': giftsUnseen,
    'paywall': {'allowedFrom': paywallAllowedFrom?.toIso8601String()},
    'serverTime': serverTime?.toIso8601String(),
  };
}
