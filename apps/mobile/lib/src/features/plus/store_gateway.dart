import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import '../../core/entitlements/billing_api.dart';

/// F12 product ids (contracts/api/v1-billing.md §1), the same in both stores.
abstract final class PlusProducts {
  static const String monthly = 'aura_plus_monthly';
  static const String annual = 'aura_plus_annual';
  static const Set<String> plus = {monthly, annual};

  /// Play: the introductory free month is this offer on each base plan.
  static const String trialOfferId = 'first-month-free';

  static const Map<String, String> giftByKind = {
    'warm_tea': 'gift_warm_tea',
    'comfort_lantern': 'gift_comfort_lantern',
    'encouragement_bouquet': 'gift_encouragement_bouquet',
  };

  static String skyProduct(String skyId) => 'sky_$skyId';
}

enum StorePlatform { apple, google }

/// A product as the store lists it. [price] is the store's own localized,
/// tax-inclusive string — the only price the app ever shows (PRD 18).
@immutable
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.price,
    this.trialOffered = false,
    this.native,
  });

  final String id;

  /// For a subscription: the recurring price after any free month.
  final String price;

  /// This store account can still get the free month (Apple: intro-offer
  /// eligible; Play: the free-month offer is listed for it).
  final bool trialOffered;

  /// The plugin's own object (to buy it).
  final Object? native;
}

enum StorePurchaseStatus { pending, purchased, restored, error, canceled }

@immutable
class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.status,
    this.proof,
    this.needsCompletion = false,
    this.native,
  });

  final String productId;
  final StorePurchaseStatus status;

  /// What the server confirms with its store (null for pending / errors).
  final StoreProof? proof;
  final bool needsCompletion;
  final Object? native;
}

/// The store boundary (fakes in tests). Purchases go through the OS sheet;
/// the app never sees card, UPI or account details.
abstract interface class StoreGateway {
  StorePlatform get platform;
  Future<bool> isAvailable();
  Future<Map<String, StoreProduct>> products(Set<String> ids);
  Stream<List<StorePurchase>> get purchases;

  /// Opens the store sheet. [accountToken] is the server's store token
  /// (`appAccountToken` / `obfuscatedAccountId`). False = it didn't open.
  Future<bool> buy(
    StoreProduct product, {
    required String accountToken,
    bool consumable = false,
    String? giftId,
  });

  Future<void> restore({required String accountToken});
  Future<void> complete(StorePurchase purchase);
}

final storeGatewayProvider = Provider<StoreGateway>(
  (ref) => InAppPurchaseGateway(),
);

/// [StoreGateway] over `in_app_purchase` (StoreKit 2 on iOS, Play Billing
/// Library 8 on Android). Receipts / tokens are never logged.
class InAppPurchaseGateway implements StoreGateway {
  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  StorePlatform get platform => defaultTargetPlatform == TargetPlatform.iOS
      ? StorePlatform.apple
      : StorePlatform.google;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } on Object {
      return false;
    }
  }

  @override
  Stream<List<StorePurchase>> get purchases =>
      _iap.purchaseStream.map((list) => [for (final p in list) _map(p)]);

  StorePurchase _map(PurchaseDetails p) {
    final status = switch (p.status) {
      PurchaseStatus.pending => StorePurchaseStatus.pending,
      PurchaseStatus.purchased => StorePurchaseStatus.purchased,
      PurchaseStatus.restored => StorePurchaseStatus.restored,
      PurchaseStatus.error => StorePurchaseStatus.error,
      PurchaseStatus.canceled => StorePurchaseStatus.canceled,
    };
    final data = p.verificationData.serverVerificationData;
    final proof =
        (status == StorePurchaseStatus.purchased ||
                status == StorePurchaseStatus.restored) &&
            data.isNotEmpty
        ? (platform == StorePlatform.apple
              ? AppleProof(p.productID, data)
              : GoogleProof(p.productID, data))
        : null;
    return StorePurchase(
      productId: p.productID,
      status: status,
      proof: proof,
      needsCompletion: p.pendingCompletePurchase,
      native: p,
    );
  }

  @override
  Future<Map<String, StoreProduct>> products(Set<String> ids) async {
    final res = await _iap.queryProductDetails(ids);
    final out = <String, StoreProduct>{};
    for (final d in res.productDetails) {
      if (d is GooglePlayProductDetails && d.subscriptionIndex != null) {
        final offer =
            d.productDetails.subscriptionOfferDetails![d.subscriptionIndex!];
        final isTrial = offer.offerId == PlusProducts.trialOfferId;
        final recurring = offer.pricingPhases.last.formattedPrice;
        final existing = out[d.id];
        // Prefer the free-month offer (Play lists it only while eligible).
        if (existing == null || (isTrial && !existing.trialOffered)) {
          out[d.id] = StoreProduct(
            id: d.id,
            price: recurring,
            trialOffered: isTrial,
            native: d,
          );
        }
        continue;
      }
      var trial = false;
      if (platform == StorePlatform.apple && PlusProducts.plus.contains(d.id)) {
        try {
          trial = await SK2Product.isIntroductoryOfferEligible(d.id);
        } on Object {
          trial = false; // unknown → plain price, no trial wording
        }
      }
      out[d.id] = StoreProduct(
        id: d.id,
        price: d.price,
        trialOffered: trial,
        native: d,
      );
    }
    return out;
  }

  @override
  Future<bool> buy(
    StoreProduct product, {
    required String accountToken,
    bool consumable = false,
    String? giftId,
  }) async {
    final d = product.native;
    if (d is! ProductDetails) return false;
    final PurchaseParam param = d is GooglePlayProductDetails
        ? GooglePlayPurchaseParam(
            productDetails: d,
            applicationUserName: accountToken,
            offerToken: d.offerToken,
            // The gift id travels as the obfuscated profile id, so a
            // purchase confirmed only by RTDN still finds its gift.
            obfuscatedProfileId: giftId,
          )
        : PurchaseParam(productDetails: d, applicationUserName: accountToken);
    // Gifts are consumed by the server after delivery (autoConsume off).
    return consumable
        ? _iap.buyConsumable(purchaseParam: param, autoConsume: false)
        : _iap.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> restore({required String accountToken}) =>
      _iap.restorePurchases(applicationUserName: accountToken);

  @override
  Future<void> complete(StorePurchase purchase) async {
    final p = purchase.native;
    if (p is PurchaseDetails && p.pendingCompletePurchase) {
      await _iap.completePurchase(p);
    }
  }
}
