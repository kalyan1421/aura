import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this account has Aura Plus (F12). Every Plus gate reads this one
/// provider: `ref.watch(plusActiveProvider)`.
///
/// Placeholder until F12 Monetization lands: always false, so every feature
/// ships its free tier and shows its Plus extras as locked. F12 replaces the
/// body with the server-validated entitlement; the provider name and type stay.
final plusActiveProvider = Provider<bool>((ref) => false);
