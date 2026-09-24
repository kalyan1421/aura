import 'dart:async';

import 'package:aura/src/core/entitlements/billing_api.dart';
import 'package:aura/src/core/entitlements/entitlement_controller.dart';
import 'package:aura/src/core/entitlements/plus.dart';
import 'package:aura/src/core/net/aura_api.dart' show ApiException;
import 'package:aura/src/features/plus/store_gateway.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'helpers.dart';

/// F12 test doubles: a store that never touches a platform channel, a
/// billing API that answers what the test says, and a fixed entitlement.

class FakeStore implements StoreGateway {
  FakeStore({
    this.platform = StorePlatform.google,
    Map<String, StoreProduct>? products,
  }) : _products =
           products ??
           {
             PlusProducts.monthly: const StoreProduct(
               id: PlusProducts.monthly,
               price: '₹49.00',
               trialOffered: true,
             ),
             PlusProducts.annual: const StoreProduct(
               id: PlusProducts.annual,
               price: '₹399.00',
               trialOffered: true,
             ),
             'sky_deep_ocean': const StoreProduct(
               id: 'sky_deep_ocean',
               price: '₹49.00',
             ),
             'gift_warm_tea': const StoreProduct(
               id: 'gift_warm_tea',
               price: '₹10.00',
             ),
             'gift_comfort_lantern': const StoreProduct(
               id: 'gift_comfort_lantern',
               price: '₹29.00',
             ),
             'gift_encouragement_bouquet': const StoreProduct(
               id: 'gift_encouragement_bouquet',
               price: '₹49.00',
             ),
           };

  @override
  final StorePlatform platform;
  final Map<String, StoreProduct> _products;
  bool available = true;
  final purchasesCtl = StreamController<List<StorePurchase>>.broadcast();
  final List<({String id, String token, bool consumable, String? giftId})>
  bought = [];
  final List<StorePurchase> completed = [];
  int restores = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Map<String, StoreProduct>> products(Set<String> ids) async => {
    for (final id in ids)
      if (_products[id] != null) id: _products[id]!,
  };

  @override
  Stream<List<StorePurchase>> get purchases => purchasesCtl.stream;

  @override
  Future<bool> buy(
    StoreProduct product, {
    required String accountToken,
    bool consumable = false,
    String? giftId,
  }) async {
    bought.add((
      id: product.id,
      token: accountToken,
      consumable: consumable,
      giftId: giftId,
    ));
    return true;
  }

  @override
  Future<void> restore({required String accountToken}) async => restores++;

  @override
  Future<void> complete(StorePurchase purchase) async =>
      completed.add(purchase);

  void emit(StorePurchase p) => purchasesCtl.add([p]);
}

StorePurchase purchased(String productId, {String token = 'tok-1'}) =>
    StorePurchase(
      productId: productId,
      status: StorePurchaseStatus.purchased,
      proof: GoogleProof(productId, token),
      needsCompletion: true,
    );

class FakeBillingApi implements BillingApi {
  FakeBillingApi({this.current = Entitlement.none});

  Entitlement current;
  VerifyStatus nextStatus = VerifyStatus.granted;
  Entitlement? onVerify;
  Object? verifyError;
  Object? giftError;
  final List<({StoreProof proof, String? price, String? giftId})> verified = [];
  final List<List<StoreProof>> restored = [];
  final List<String> cancelledGifts = [];
  List<ReceivedGift> gifts = const [];
  final List<List<String>> seen = [];

  @override
  Future<Entitlement> entitlement() async => current;

  @override
  Future<VerifyResult> verify(
    StoreProof proof, {
    String? priceDisplay,
    String? giftId,
  }) async {
    verified.add((proof: proof, price: priceDisplay, giftId: giftId));
    final e = verifyError;
    if (e != null) throw e;
    if (onVerify != null) current = onVerify!;
    return VerifyResult(
      nextStatus,
      current,
      gift: giftId == null ? null : 'delivered',
    );
  }

  @override
  Future<RestoreResult> restore(List<StoreProof> proofs) async {
    restored.add(proofs);
    return RestoreResult(
      restored: proofs.length,
      ownedElsewhere: 0,
      confirming: 0,
      invalid: 0,
      entitlement: current,
    );
  }

  @override
  Future<GiftCheck> checkGift({
    required String giftId,
    required String roomId,
    required String memberId,
    required String kind,
  }) async {
    final e = giftError;
    if (e != null) throw e;
    return GiftCheck(
      giftId: giftId,
      productId: PlusProducts.giftByKind[kind]!,
      accountToken: current.accountToken,
    );
  }

  @override
  Future<void> cancelGift(String giftId) async => cancelledGifts.add(giftId);

  @override
  Future<List<ReceivedGift>> receivedGifts() async => gifts;

  @override
  Future<void> giftsSeen(List<String> giftIds) async => seen.add(giftIds);

  @override
  Future<Entitlement> redeem(String cosmeticId, String redemptionId) async {
    if (current.stardust < 30) {
      throw const ApiException(code: 'not_enough_stardust', status: 409);
    }
    return current;
  }

  @override
  Future<Entitlement> setSky(String theme, String? soundscape) async => current;
}

/// An entitlement fixed by the test (the server's last answer).
class FixedEntitlement extends EntitlementController {
  FixedEntitlement(this.initial);
  final Entitlement initial;

  @override
  Entitlement build() => initial;

  @override
  Future<Entitlement> refresh() async => state;

  @override
  Future<void> apply(Entitlement e) async => state = e;
}

/// 24 h after onboarding has passed; no Plus.
Entitlement freeAccount({DateTime? allowedFrom}) => Entitlement(
  accountToken: '3f1c0c1a-51b2-4c3d-9e4f-5a6b7c8d9e0f',
  plusActive: false,
  status: PlusStatus.none,
  paywallAllowedFrom: allowedFrom ?? testNow.subtract(const Duration(days: 3)),
);

Entitlement plusAccount({
  PlusStatus status = PlusStatus.trial,
  DateTime? until,
  bool autoRenew = true,
  PlusStore store = PlusStore.google,
  List<PlusNotice> notices = const [],
}) {
  final end = until ?? testNow.add(const Duration(days: 20));
  return Entitlement(
    accountToken: '3f1c0c1a-51b2-4c3d-9e4f-5a6b7c8d9e0f',
    plusActive:
        status == PlusStatus.trial ||
        status == PlusStatus.active ||
        status == PlusStatus.cancelled ||
        status == PlusStatus.grace,
    status: status,
    store: store,
    productId: PlusProducts.monthly,
    autoRenew: autoRenew,
    trialEndsAt: status == PlusStatus.trial ? end : null,
    expiresAt: end,
    validUntil: end,
    notices: notices,
    availableSkies: const ['night', 'aurora', 'monsoon_dusk'],
    paywallAllowedFrom: testNow.subtract(const Duration(days: 30)),
  );
}

List<Override> plusOverrides({
  required Entitlement entitlement,
  FakeBillingApi? api,
  FakeStore? store,
}) => [
  entitlementProvider.overrideWith(() => FixedEntitlement(entitlement)),
  billingApiProvider.overrideWithValue(api),
  storeGatewayProvider.overrideWithValue(store ?? FakeStore()),
];
