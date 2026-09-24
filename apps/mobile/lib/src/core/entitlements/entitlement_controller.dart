import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../env/env.dart';
import '../providers.dart';
import 'billing_api.dart';
import 'entitlement.dart';

/// Where the last server answer is kept (account-scoped: wiped at sign-out,
/// so a shared phone never shows someone else's Plus).
const String entitlementCacheKey = 'plus.entitlement';

/// NestJS billing, or `null` when this build has no API (or no sign-in).
final billingApiProvider = Provider<BillingApi?>((ref) {
  if (!Env.hasApi) return null;
  final auth = ref.watch(authRepositoryProvider);
  if (!auth.isAvailable) return null;
  return HttpBillingApi(baseUrl: Env.apiUrl, accessToken: auth.accessToken);
});

/// The account's entitlement as the server last validated it (DS-9). Starts
/// from the cached answer, then asks the server when signed in and online,
/// on resume and after any purchase. Never computed on the phone.
final entitlementProvider =
    NotifierProvider<EntitlementController, Entitlement>(
      EntitlementController.new,
    );

class EntitlementController extends Notifier<Entitlement> {
  bool _loadedCache = false;

  @override
  Entitlement build() {
    ref.listen(authUserProvider, (prev, next) {
      final was = prev?.value?.id;
      final now = next.value?.id;
      if (was != now) {
        if (now == null) {
          state = Entitlement.none; // signed out: the cache was wiped too
        } else {
          unawaited(refresh());
        }
      }
    });
    scheduleMicrotask(_start);
    return Entitlement.none;
  }

  Future<void> _start() async {
    await _loadCache();
    await refresh();
  }

  Future<void> _loadCache() async {
    if (_loadedCache) return;
    _loadedCache = true;
    try {
      final json = await ref.read(kvStoreProvider).getJson(entitlementCacheKey);
      if (json != null && ref.mounted && state.status == PlusStatus.none) {
        state = Entitlement.fromJson(json);
      }
    } on Object catch (e) {
      debugPrint('plus: cache unavailable (${e.runtimeType})');
    }
  }

  /// Asks the server. Offline / signed out / no API: keeps what it has.
  Future<Entitlement> refresh() async {
    final api = ref.read(billingApiProvider);
    if (api == null) return state;
    try {
      if (ref.read(authUserProvider).value == null) return state;
      final e = await api.entitlement();
      await apply(e);
    } on Object catch (e) {
      debugPrint('plus: entitlement refresh failed (${e.runtimeType})');
    }
    return state;
  }

  /// Takes an entitlement the server returned (verify, restore, sky, redeem).
  Future<void> apply(Entitlement e) async {
    if (!ref.mounted) return;
    state = e;
    try {
      await ref.read(kvStoreProvider).setJson(entitlementCacheKey, e.toJson());
    } on Object catch (err) {
      debugPrint('plus: cache write failed (${err.runtimeType})');
    }
  }
}
