import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'entitlement_controller.dart';

export 'entitlement.dart';
export 'entitlement_controller.dart'
    show entitlementProvider, billingApiProvider;

/// Whether this account has Aura Plus (F12). Every Plus gate reads this one
/// provider: `ref.watch(plusActiveProvider)`.
///
/// Server-validated (DS-9): true only while the entitlement NestJS last
/// returned says Plus is on AND its period (or grace) hasn't run out on this
/// phone's clock — a cached answer is honoured offline until then
/// (16-offline), never longer. Nothing on the phone can turn it on.
final plusActiveProvider = Provider<bool>((ref) {
  final e = ref.watch(entitlementProvider);
  if (!e.plusActive) return false;
  final now =
      ref.watch(nowProvider).value ?? ref.read(timeContextProvider).now();
  return e.plusActiveAt(now);
});
