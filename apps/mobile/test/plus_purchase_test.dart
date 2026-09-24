import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/entitlements/billing_api.dart';
import 'package:aura/src/core/entitlements/entitlement_controller.dart';
import 'package:aura/src/core/entitlements/plus.dart';
import 'package:aura/src/core/net/aura_api.dart' show ApiException;
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/features/plus/purchase_controller.dart';
import 'package:aura/src/features/plus/store_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'plus_fakes.dart';

/// F12 purchase flow and the server-validated entitlement: nothing is granted
/// on the phone (REQ-PAY-10), pending purchases grant nothing (REQ-PAY-07), a
/// purchase the server couldn't confirm stays open for the store to deliver
/// again, and a cached entitlement is honoured offline only until its period
/// ends (16-offline).
void main() {
  late AppDatabase db;
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  ProviderContainer container({
    required FakeBillingApi api,
    required FakeStore store,
    Entitlement? e,
    DateTime? now,
  }) {
    final c = ProviderContainer(
      overrides: [
        ...testOverrides(db: db, time: testTime(now)),
        ...plusOverrides(
          entitlement: e ?? freeAccount(),
          api: api,
          store: store,
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> flush() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  group('purchase flow', () {
    test('buy → purchased → server grants → entitlement applied, then the transaction is finished', () async {
      final api = FakeBillingApi(current: freeAccount())
        ..onVerify = plusAccount();
      final store = FakeStore();
      final c = container(api: api, store: store);
      final ctl = c.read(purchaseControllerProvider.notifier);
      await ctl.load(PlusProducts.plus);
      await ctl.buy(PlusProducts.annual);
      expect(store.bought.single.token, freeAccount().accountToken);
      store.emit(purchased(PlusProducts.annual));
      await flush();
      expect(api.verified.single.price, '₹399.00');
      expect(c.read(purchaseControllerProvider).phase, PurchasePhase.success);
      expect(c.read(entitlementProvider).plusActive, isTrue);
      expect(store.completed, hasLength(1));
      expect(c.read(plusActiveProvider), isTrue);
    });

    test('REQ-PAY-07: a pending purchase (UPI mandate / Ask to Buy) grants nothing and is not sent for verification', () async {
      final api = FakeBillingApi(current: freeAccount());
      final store = FakeStore();
      final c = container(api: api, store: store);
      await c.read(purchaseControllerProvider.notifier).load(PlusProducts.plus);
      store.emit(
        const StorePurchase(
          productId: PlusProducts.monthly,
          status: StorePurchaseStatus.pending,
        ),
      );
      await flush();
      expect(
        c.read(purchaseControllerProvider).phase,
        PurchasePhase.pendingApproval,
      );
      expect(api.verified, isEmpty);
      expect(c.read(plusActiveProvider), isFalse);
    });

    test('the server says "pending": nothing granted, the store transaction is finished (the server has it)', () async {
      final api = FakeBillingApi(current: freeAccount())
        ..nextStatus = VerifyStatus.pending;
      final store = FakeStore();
      final c = container(api: api, store: store);
      await c.read(purchaseControllerProvider.notifier).load(PlusProducts.plus);
      store.emit(purchased(PlusProducts.monthly));
      await flush();
      expect(
        c.read(purchaseControllerProvider).phase,
        PurchasePhase.pendingApproval,
      );
      expect(c.read(plusActiveProvider), isFalse);
    });

    test('"confirming" (the store was unreachable for the server): nothing granted, the transaction stays open', () async {
      final api = FakeBillingApi(current: freeAccount())
        ..nextStatus = VerifyStatus.confirming;
      final store = FakeStore();
      final c = container(api: api, store: store);
      await c.read(purchaseControllerProvider.notifier).load(PlusProducts.plus);
      store.emit(purchased(PlusProducts.monthly));
      await flush();
      expect(
        c.read(purchaseControllerProvider).phase,
        PurchasePhase.confirmingLater,
      );
      expect(store.completed, isEmpty);
      expect(c.read(plusActiveProvider), isFalse);
    });

    test('offline while confirming: "We\'ll keep checking", never asks to pay again, transaction stays open', () async {
      final api = FakeBillingApi(current: freeAccount())
        ..verifyError = const ApiException(code: 'network', isNetwork: true);
      final store = FakeStore();
      final c = container(api: api, store: store);
      await c.read(purchaseControllerProvider.notifier).load(PlusProducts.plus);
      store.emit(purchased(PlusProducts.monthly));
      await flush();
      expect(
        c.read(purchaseControllerProvider).phase,
        PurchasePhase.confirmingLater,
      );
      expect(store.completed, isEmpty);
      expect(store.bought, isEmpty);
    });

    test(
      'REQ-PAY-10 Neg: the server refuses a receipt → nothing granted',
      () async {
        final api = FakeBillingApi(current: freeAccount())
          ..verifyError = const ApiException(
            code: 'invalid_purchase',
            status: 422,
          );
        final store = FakeStore();
        final c = container(api: api, store: store);
        await c
            .read(purchaseControllerProvider.notifier)
            .load(PlusProducts.plus);
        store.emit(purchased(PlusProducts.monthly));
        await flush();
        expect(c.read(purchaseControllerProvider).phase, PurchasePhase.failed);
        expect(c.read(plusActiveProvider), isFalse);
      },
    );

    test('declined / cancelled: "You weren\'t charged"; a checked gift frees its slot', () async {
      final api = FakeBillingApi(current: freeAccount());
      final store = FakeStore();
      final c = container(api: api, store: store);
      final ctl = c.read(purchaseControllerProvider.notifier);
      await ctl.load({'gift_warm_tea'});
      await ctl.buy(
        'gift_warm_tea',
        giftId: '0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b',
      );
      expect(store.bought.single.consumable, isTrue);
      store.emit(
        const StorePurchase(
          productId: 'gift_warm_tea',
          status: StorePurchaseStatus.error,
        ),
      );
      await flush();
      expect(c.read(purchaseControllerProvider).phase, PurchasePhase.declined);
      expect(api.cancelledGifts, ['0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b']);
    });

    test('a gift purchase is verified with its gift id (also after a restart: kept on the phone)', () async {
      final api = FakeBillingApi(current: freeAccount());
      final store = FakeStore();
      final c = container(api: api, store: store);
      final ctl = c.read(purchaseControllerProvider.notifier);
      await ctl.load({'gift_comfort_lantern'});
      await ctl.buy(
        'gift_comfort_lantern',
        giftId: '0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5c',
      );
      store.emit(purchased('gift_comfort_lantern', token: 'gtok'));
      await flush();
      expect(
        api.verified.single.giftId,
        '0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5c',
      );
      expect(store.completed, hasLength(1));
      expect(await c.read(kvStoreProvider).getJson(pendingGiftsKey), isEmpty);
    });

    test(
      'owned by another Aura account: nothing moves, the note says so',
      () async {
        final api = FakeBillingApi(current: freeAccount())
          ..nextStatus = VerifyStatus.ownedElsewhere;
        final store = FakeStore();
        final c = container(api: api, store: store);
        await c
            .read(purchaseControllerProvider.notifier)
            .load(PlusProducts.plus);
        store.emit(purchased(PlusProducts.monthly));
        await flush();
        expect(
          c.read(purchaseControllerProvider).phase,
          PurchasePhase.ownedElsewhere,
        );
        expect(c.read(plusActiveProvider), isFalse);
      },
    );

    test('REQ-PAY-08: Restore sends every restored purchase to the server in one call and finishes them', () async {
      final api = FakeBillingApi(current: plusAccount());
      final store = FakeStore();
      final c = container(api: api, store: store);
      final ctl = c.read(purchaseControllerProvider.notifier);
      await ctl.restore();
      store.emit(
        const StorePurchase(
          productId: PlusProducts.monthly,
          status: StorePurchaseStatus.restored,
          proof: GoogleProof(PlusProducts.monthly, 'r1'),
          needsCompletion: true,
        ),
      );
      store.emit(
        const StorePurchase(
          productId: 'sky_deep_ocean',
          status: StorePurchaseStatus.restored,
          proof: GoogleProof('sky_deep_ocean', 'r2'),
          needsCompletion: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(store.restores, 1);
      expect(api.restored.single.map((p) => p.productId), [
        PlusProducts.monthly,
        'sky_deep_ocean',
      ]);
      expect(c.read(purchaseControllerProvider).restored?.restored, 2);
      expect(store.completed, hasLength(2));
      expect(c.read(plusActiveProvider), isTrue);
    });
  });

  group('entitlement (server-validated)', () {
    test('plusActive only while the server said so AND its period has not run out on this clock', () {
      final e = plusAccount(until: testNow.add(const Duration(hours: 1)));
      expect(e.plusActiveAt(testNow), isTrue);
      expect(e.plusActiveAt(testNow.add(const Duration(hours: 2))), isFalse);
      expect(freeAccount().plusActiveAt(testNow), isFalse);
      // Active without a period end is never trusted.
      expect(
        const Entitlement(
          accountToken: '',
          plusActive: true,
          status: PlusStatus.active,
        ).plusActiveAt(testNow),
        isFalse,
      );
    });

    test('JSON from the server round-trips through the cache', () {
      final json = {
        'accountToken': 'tok',
        'plus': {
          'active': true,
          'status': 'billing_retry',
          'store': 'apple',
          'productId': 'aura_plus_annual',
          'autoRenew': false,
          'validUntil': '2026-11-03T06:30:00.000Z',
        },
        'notices': [
          {
            'kind': 'trial_ending',
            'date': '2026-11-03T06:30:00.000Z',
            'price': '₹49.00',
            'key': 'k',
          },
          {'kind': 'something_new', 'key': 'x'},
        ],
        'cosmetics': {
          'owned': ['deep_ocean'],
          'available': ['night', 'deep_ocean'],
        },
        'sky': {'theme': 'deep_ocean', 'soundscape': 'shore'},
        'stardust': {'balance': 30},
        'gifting': {
          'state': 'paused',
          'until': '2027-01-01T00:00:00.000Z',
          'sentToday': 2,
          'dailyLimit': 5,
        },
        'giftsUnseen': 1,
        'paywall': {'allowedFrom': '2026-10-06T10:00:00.000Z'},
      };
      final e = Entitlement.fromJson(json);
      expect(e.status, PlusStatus.billingRetry);
      expect(e.store, PlusStore.apple);
      expect(e.isAnnual, isTrue);
      expect(
        e.notices.single.kind,
        PlusNoticeKind.trialEnding,
      ); // unknown kinds dropped
      expect(e.gifting, GiftingState.paused);
      final again = Entitlement.fromJson(e.toJson());
      expect(again.toJson(), e.toJson());
    });

    test('the cached answer is used offline (and only it): no API → Plus from the cache until validUntil', () async {
      await db.setValue(entitlementCacheKey, null);
      final kv = ProviderContainer(overrides: testOverrides(db: db));
      addTearDown(kv.dispose);
      await kv
          .read(kvStoreProvider)
          .setJson(entitlementCacheKey, plusAccount().toJson());
      final c = ProviderContainer(
        overrides: [
          ...testOverrides(db: db),
          billingApiProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
      c.read(entitlementProvider);
      await flush();
      expect(c.read(entitlementProvider).status, PlusStatus.trial);
      expect(c.read(plusActiveProvider), isTrue);
      // A day after the period ended on this clock: off, even from the cache.
      final later = ProviderContainer(
        overrides: [
          ...testOverrides(
            db: db,
            time: testTime(testNow.add(const Duration(days: 21))),
          ),
          billingApiProvider.overrideWithValue(null),
        ],
      );
      addTearDown(later.dispose);
      later.read(entitlementProvider);
      await flush();
      expect(
        later.read(entitlementProvider).plusActive,
        isTrue,
      ); // what the server said…
      expect(
        later.read(plusActiveProvider),
        isFalse,
      ); // …but the period is over
    });

    test('with no cache and no server there is no Plus (nothing is ever granted on the phone)', () async {
      final c = ProviderContainer(
        overrides: [
          ...testOverrides(db: db),
          billingApiProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
      c.read(entitlementProvider);
      await flush();
      expect(c.read(plusActiveProvider), isFalse);
      expect(c.read(entitlementProvider).status, PlusStatus.none);
    });
  });
}
