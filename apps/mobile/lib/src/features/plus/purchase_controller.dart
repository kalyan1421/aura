import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/billing_api.dart';
import '../../core/entitlements/plus.dart';
import '../../core/net/aura_api.dart' show ApiException;
import '../../core/providers.dart';
import '../../core/remote_config/remote_config_providers.dart';
import 'store_gateway.dart';

/// Where a purchase stands (PRD 14-states "Paywall, trial and store").
enum PurchasePhase {
  idle,
  loading,
  ready,

  /// "The store isn't reachable right now. Nothing was charged."
  storeUnavailable,
  buying,

  /// "Confirming with the store…" (the server is asking the store).
  confirming,

  /// Confirming took longer / the server couldn't ask the store yet:
  /// "The store has your request. Plus unlocks the moment it's confirmed."
  confirmingLater,

  /// UPI mandate / Ask to Buy: "Waiting for approval. You won't be charged
  /// until it goes through."
  pendingApproval,
  success,

  /// "Payment didn't go through. You weren't charged."
  declined,

  /// "We couldn't confirm this yet. If you were charged, it's safe."
  failed,

  /// The purchase belongs to another Aura account on this store account.
  ownedElsewhere,
}

@immutable
class PurchaseState {
  const PurchaseState({
    this.phase = PurchasePhase.idle,
    this.products = const {},
    this.productId,
    this.restored,
  });

  final PurchasePhase phase;
  final Map<String, StoreProduct> products;

  /// The product the current flow is about.
  final String? productId;

  /// After a restore: how many purchases came back to this account.
  final RestoreResult? restored;

  PurchaseState copyWith({
    PurchasePhase? phase,
    Map<String, StoreProduct>? products,
    String? productId,
    RestoreResult? restored,
  }) => PurchaseState(
    phase: phase ?? this.phase,
    products: products ?? this.products,
    productId: productId ?? this.productId,
    restored: restored ?? this.restored,
  );
}

/// Gifts waiting for their store purchase: productId → giftId (so a purchase
/// that completes after a restart still delivers the right gift).
const String pendingGiftsKey = 'plus.pending_gifts';

final purchaseControllerProvider =
    NotifierProvider<PurchaseController, PurchaseState>(PurchaseController.new);

/// Runs purchases: store sheet → NestJS confirms with the store → the
/// server's entitlement is applied → only then the store transaction is
/// finished. Nothing is ever granted on the phone, and a purchase the server
/// couldn't confirm yet is left unfinished so the store delivers it again.
class PurchaseController extends Notifier<PurchaseState> {
  StreamSubscription<List<StorePurchase>>? _sub;
  Timer? _retry;
  int _retries = 0;
  final List<StorePurchase> _awaiting = [];
  bool _restoring = false;
  final List<StorePurchase> _restoredBatch = [];
  Timer? _restoreDebounce;

  StoreGateway get _store => ref.read(storeGatewayProvider);
  BillingApi? get _api => ref.read(billingApiProvider);

  /// Purchases switched off (`plus_enabled`): the store plugin is never
  /// initialised, listened to or asked for products, and nothing is bought
  /// or restored — every flow answers "store unavailable" without a call.
  bool get _off => !ref.read(plusEnabledProvider);

  @override
  PurchaseState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _retry?.cancel();
      _restoreDebounce?.cancel();
    });
    // The store listener starts with the first Plus flow (load / buy /
    // restore): the store re-delivers anything unfinished then, and the
    // server has meanwhile settled it from the store notification anyway.
    return const PurchaseState();
  }

  void _listen() {
    if (_off) return;
    try {
      _sub = _store.purchases.listen(
        (list) => unawaited(_onPurchases(list)),
        onError: (Object e) =>
            debugPrint('plus: store stream ${e.runtimeType}'),
      );
    } on Object catch (e) {
      debugPrint('plus: store unavailable (${e.runtimeType})');
    }
  }

  /// Loads the store's own products and prices (skeleton until then).
  Future<void> load(Set<String> ids) async {
    if (_off) {
      state = state.copyWith(phase: PurchasePhase.storeUnavailable);
      return;
    }
    if (_sub == null && _api != null) _listen();
    state = state.copyWith(phase: PurchasePhase.loading);
    try {
      if (!await _store.isAvailable()) {
        state = state.copyWith(phase: PurchasePhase.storeUnavailable);
        return;
      }
      final products = await _store.products(ids);
      if (products.isEmpty) {
        state = state.copyWith(phase: PurchasePhase.storeUnavailable);
        return;
      }
      state = state.copyWith(
        phase: PurchasePhase.ready,
        products: {...state.products, ...products},
      );
    } on Object {
      state = state.copyWith(phase: PurchasePhase.storeUnavailable);
    }
  }

  /// Opens the store sheet for [productId] (Plus, a sky, or a gift checked
  /// before with [giftId]).
  Future<void> buy(String productId, {String? giftId}) async {
    final product = state.products[productId];
    final api = _api;
    if (_off || product == null || api == null) {
      state = state.copyWith(phase: PurchasePhase.storeUnavailable);
      return;
    }
    if (_sub == null) _listen();
    state = state.copyWith(phase: PurchasePhase.buying, productId: productId);
    try {
      final token = ref.read(entitlementProvider).accountToken;
      final account = token.isNotEmpty
          ? token
          : (await api.entitlement()).accountToken;
      if (giftId != null) await _rememberGift(productId, giftId);
      final opened = await _store.buy(
        product,
        accountToken: account,
        consumable: giftId != null,
        giftId: giftId,
      );
      if (!opened) state = state.copyWith(phase: PurchasePhase.declined);
    } on ApiException catch (e) {
      state = state.copyWith(
        phase: e.isNetwork
            ? PurchasePhase.storeUnavailable
            : PurchasePhase.failed,
      );
    } on Object {
      state = state.copyWith(phase: PurchasePhase.declined);
    }
  }

  /// "Restore purchases": the store re-delivers this store account's
  /// purchases; the server confirms each and follows the account (§2.3).
  Future<void> restore() async {
    final api = _api;
    if (_off || api == null) {
      state = state.copyWith(phase: PurchasePhase.storeUnavailable);
      return;
    }
    if (_sub == null) _listen();
    _restoring = true;
    _restoredBatch.clear();
    state = state.copyWith(phase: PurchasePhase.confirming);
    try {
      final token = ref.read(entitlementProvider).accountToken;
      await _store.restore(
        accountToken: token.isNotEmpty
            ? token
            : (await api.entitlement()).accountToken,
      );
      // Nothing to restore: the store sends nothing. Settle after a pause.
      _restoreDebounce?.cancel();
      _restoreDebounce = Timer(const Duration(seconds: 4), _finishRestore);
    } on Object {
      _restoring = false;
      state = state.copyWith(phase: PurchasePhase.storeUnavailable);
    }
  }

  Future<void> _finishRestore() async {
    if (!_restoring) return;
    _restoring = false;
    final api = _api;
    if (api == null) return;
    final batch = [
      for (final p in _restoredBatch)
        if (p.proof != null) p,
    ];
    _restoredBatch.clear();
    try {
      final r = await api.restore([for (final p in batch) p.proof!]);
      await ref.read(entitlementProvider.notifier).apply(r.entitlement);
      for (final p in batch) {
        await _complete(p);
      }
      state = state.copyWith(phase: PurchasePhase.idle, restored: r);
    } on Object {
      state = state.copyWith(phase: PurchasePhase.failed);
    }
  }

  Future<void> _onPurchases(List<StorePurchase> list) async {
    for (final p in list) {
      switch (p.status) {
        case StorePurchaseStatus.pending:
          state = state.copyWith(
            phase: PurchasePhase.pendingApproval,
            productId: p.productId,
          );
        case StorePurchaseStatus.canceled:
          await _forgetGift(p.productId, cancel: true);
          state = state.copyWith(phase: PurchasePhase.idle);
          await _complete(p);
        case StorePurchaseStatus.error:
          await _forgetGift(p.productId, cancel: true);
          state = state.copyWith(phase: PurchasePhase.declined);
          await _complete(p);
        case StorePurchaseStatus.restored when _restoring:
          _restoredBatch.add(p);
          _restoreDebounce?.cancel();
          _restoreDebounce = Timer(
            const Duration(milliseconds: 800),
            _finishRestore,
          );
        case StorePurchaseStatus.purchased || StorePurchaseStatus.restored:
          await _verify(p);
      }
    }
  }

  Future<void> _verify(StorePurchase p) async {
    final api = _api;
    final proof = p.proof;
    if (api == null || proof == null) return;
    state = state.copyWith(
      phase: PurchasePhase.confirming,
      productId: p.productId,
    );
    try {
      final giftId = await _giftFor(p.productId);
      final r = await api
          .verify(
            proof,
            priceDisplay: state.products[p.productId]?.price,
            giftId: giftId,
          )
          .timeout(const Duration(seconds: 25));
      await ref.read(entitlementProvider.notifier).apply(r.entitlement);
      if (!r.status.settled) {
        _later(p);
        return;
      }
      await _complete(p);
      if (giftId != null) await _forgetGift(p.productId);
      state = state.copyWith(
        phase: switch (r.status) {
          VerifyStatus.granted => PurchasePhase.success,
          VerifyStatus.pending => PurchasePhase.pendingApproval,
          VerifyStatus.ownedElsewhere => PurchasePhase.ownedElsewhere,
          VerifyStatus.refunded || VerifyStatus.notActive => PurchasePhase.idle,
          VerifyStatus.confirming => PurchasePhase.confirmingLater,
        },
      );
      _retries = 0;
    } on ApiException catch (e) {
      if (e.isRetryable) {
        _later(p);
      } else {
        // The server refused it (not this app's, not a real purchase):
        // nothing granted. Never asks to pay again.
        state = state.copyWith(phase: PurchasePhase.failed);
      }
    } on TimeoutException {
      _later(p);
    }
  }

  /// Not confirmed yet: keep the transaction open and try again with backoff
  /// (the store also re-delivers it on the next start; the server settles it
  /// from the store notification meanwhile).
  void _later(StorePurchase p) {
    state = state.copyWith(phase: PurchasePhase.confirmingLater);
    if (!_awaiting.any((x) => identical(x, p))) _awaiting.add(p);
    _retry?.cancel();
    final delay = Duration(seconds: (15 * (1 << _retries.clamp(0, 6))));
    _retries++;
    _retry = Timer(delay, () {
      final again = List<StorePurchase>.of(_awaiting);
      _awaiting.clear();
      for (final x in again) {
        unawaited(_verify(x));
      }
    });
  }

  Future<void> _complete(StorePurchase p) async {
    if (!p.needsCompletion) return;
    try {
      await _store.complete(p);
    } on Object catch (e) {
      debugPrint('plus: complete failed (${e.runtimeType})');
    }
  }

  // ---- pending gifts -----------------------------------------------------------

  Future<Map<String, dynamic>> _gifts() async {
    try {
      return await ref.read(kvStoreProvider).getJson(pendingGiftsKey) ?? {};
    } on Object {
      return {};
    }
  }

  Future<void> _rememberGift(String productId, String giftId) async {
    final g = await _gifts();
    await ref.read(kvStoreProvider).setJson(pendingGiftsKey, {
      ...g,
      productId: giftId,
    });
  }

  Future<String?> _giftFor(String productId) async =>
      (await _gifts())[productId] as String?;

  Future<void> _forgetGift(String productId, {bool cancel = false}) async {
    final g = await _gifts();
    final id = g.remove(productId) as String?;
    if (id == null) return;
    try {
      await ref.read(kvStoreProvider).setJson(pendingGiftsKey, g);
      if (cancel) await _api?.cancelGift(id); // frees today's slot
    } on Object catch (e) {
      debugPrint('plus: gift cleanup ${e.runtimeType}');
    }
  }

  /// Back to a clean state (the screen closed).
  void reset() {
    if (state.phase == PurchasePhase.confirming ||
        state.phase == PurchasePhase.buying) {
      return;
    }
    state = PurchaseState(products: state.products);
  }
}
