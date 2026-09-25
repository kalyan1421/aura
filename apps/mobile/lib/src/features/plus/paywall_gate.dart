import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/entitlements/plus.dart';
import '../../core/providers.dart';
import '../../core/remote_config/remote_config_providers.dart';
import '../onboarding/gate_controller.dart';

/// Where Aura Plus may be offered (PRD F12: "It shows only on limit screens
/// (4th mood-trigger capsule, long voice, Plus theme, extra Sounds stem,
/// deeper Insights) and in Settings"). There is deliberately no value for a
/// never-paywalled place — check-in, habits, rest days, rooms, Breath
/// Ripples, date capsules, crisis support, Sanctuary (Breathe, grounding,
/// Today's minute, base Sounds, the night wind-down), the companion response,
/// "A minute for you", Quiet Together, Lantern Hour, Look back, keepsakes,
/// Nebula wake-up — so no code can ask for a paywall there
/// (test/plus_paywall_exclusions_test.dart also scans those features).
enum PaywallSurface {
  capsuleTriggerLimit,
  capsuleLongVoice,
  plusSky,
  soundsStem,
  insightsDepth,
  settings;

  /// Limit screens count toward "at most once a day unprompted"; Settings is
  /// always the person's own choice.
  bool get isLimitScreen => this != settings;
}

/// What a surface may show.
enum PaywallMode {
  /// Plus is on: nothing to offer.
  none,

  /// Only the calm "Part of Aura Plus" line: no offer, no button, no price
  /// (a crisis flow that day, straight after a Storm or Rain check-in, within
  /// 24 h of onboarding, an under-13 locked device).
  lockedOnly,

  /// The line plus a small "About Aura Plus" link (the person chooses).
  link,

  /// The Plus explainer with its free path (the day's one unprompted showing).
  explainer,
}

/// "Straight after a Storm or Rain check-in" `[ASSUMPTION]`: within 3 hours.
const Duration heavyCheckInWindow = Duration(hours: 3);

@immutable
class PaywallContext {
  const PaywallContext({
    required this.now,
    required this.today,
    required this.plusActive,
    required this.deviceLocked,
    required this.allowedFrom,
    this.crisisDay,
    this.lastCheckInQuadrant,
    this.lastCheckInAt,
    this.unpromptedShownDay,
  });

  final DateTime now;

  /// The current Aura day.
  final LocalDay today;
  final bool plusActive;

  /// The under-13 device lock is active (the paywall never shows there).
  final bool deviceLocked;

  /// 24 h after onboarding (server: profile creation + 24 h). `null` = no
  /// profile / not known yet → never.
  final DateTime? allowedFrom;

  /// The Aura day the support / crisis sheet last opened on this phone.
  final LocalDay? crisisDay;
  final Quadrant? lastCheckInQuadrant;
  final DateTime? lastCheckInAt;

  /// The Aura day the unprompted explainer last showed.
  final LocalDay? unpromptedShownDay;

  /// Any P0 exclusion in force right now (PRD F12 "Paywall never appears").
  bool get excluded {
    if (deviceLocked) return true;
    final from = allowedFrom;
    if (from == null || now.isBefore(from)) return true;
    if (crisisDay != null && crisisDay == today) return true;
    final q = lastCheckInQuadrant;
    final at = lastCheckInAt;
    if (at != null &&
        (q == Quadrant.storm || q == Quadrant.rain) &&
        now.difference(at) < heavyCheckInWindow) {
      return true;
    }
    return false;
  }
}

/// The P0 decision (REQ-PAY-06), pure so every exclusion is a unit test.
PaywallMode decidePaywall(PaywallSurface surface, PaywallContext c) {
  if (c.plusActive) return PaywallMode.none;
  if (c.excluded) return PaywallMode.lockedOnly;
  if (surface == PaywallSurface.settings) return PaywallMode.explainer;
  return c.unpromptedShownDay == c.today
      ? PaywallMode.link
      : PaywallMode.explainer;
}

/// Local marks the gate needs (account-scoped KV: wiped at sign-out).
abstract final class PaywallKeys {
  static const String crisisDay = 'plus.crisis_day';
  static const String unpromptedDay = 'plus.unprompted_day';
}

/// Records that a crisis / support sheet opened today: no paywall for the
/// rest of this Aura day. Called by the support sheet (features/support).
Future<void> markCrisisFlow(WidgetRef ref) async {
  try {
    final today = ref.read(timeContextProvider).today();
    await ref.read(kvStoreProvider).set(PaywallKeys.crisisDay, today.toIso());
    ref.invalidate(paywallSignalsProvider);
  } on Object catch (e) {
    debugPrint('plus: crisis mark failed (${e.runtimeType})');
  }
}

/// Marks the day's one unprompted explainer as shown.
Future<void> markUnpromptedShown(WidgetRef ref) async {
  try {
    final today = ref.read(timeContextProvider).today();
    await ref
        .read(kvStoreProvider)
        .set(PaywallKeys.unpromptedDay, today.toIso());
  } on Object catch (e) {
    debugPrint('plus: mark failed (${e.runtimeType})');
  }
}

@immutable
class PaywallSignals {
  const PaywallSignals({
    this.crisisDay,
    this.unpromptedDay,
    this.lastQuadrant,
    this.lastAt,
  });

  final LocalDay? crisisDay;
  final LocalDay? unpromptedDay;
  final Quadrant? lastQuadrant;
  final DateTime? lastAt;
}

LocalDay? _day(String? v) => LocalDay.tryParse(v);

/// Reads the local signals: the crisis mark, the day's unprompted mark and
/// the latest live check-in (quadrant + time). Until they load, the gate
/// treats the moment as excluded (fail closed: never a paywall by accident).
final paywallSignalsProvider = FutureProvider.autoDispose<PaywallSignals>((
  ref,
) async {
  final kv = ref.read(kvStoreProvider);
  final db = ref.read(appDatabaseProvider);
  final last =
      await (db.select(db.checkIns)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([
              (c) =>
                  OrderingTerm(expression: c.deviceTs, mode: OrderingMode.desc),
            ])
            ..limit(1))
          .getSingleOrNull();
  return PaywallSignals(
    crisisDay: _day(await kv.get(PaywallKeys.crisisDay)),
    unpromptedDay: _day(await kv.get(PaywallKeys.unpromptedDay)),
    lastQuadrant: last == null ? null : _quadrant(last),
    lastAt: last?.deviceTs.toUtc(),
  );
});

Quadrant? _quadrant(CheckInRow row) =>
    Quadrant.values.asNameMap()[row.quadrant];

/// The decision for [surface] right now. Fails closed while the local
/// signals load or can't be read. With purchases switched off
/// ([plusEnabledProvider]) it is only ever the calm "Part of Aura Plus" line:
/// never an offer, a link or a price.
final paywallModeProvider = Provider.autoDispose
    .family<PaywallMode, PaywallSurface>((ref, surface) {
      if (ref.watch(plusActiveProvider)) return PaywallMode.none;
      if (!ref.watch(plusEnabledProvider)) return PaywallMode.lockedOnly;
      final signals = ref.watch(paywallSignalsProvider).value;
      if (signals == null) return PaywallMode.lockedOnly;
      final time = ref.read(timeContextProvider);
      final e = ref.watch(entitlementProvider);
      return decidePaywall(
        surface,
        PaywallContext(
          now: time.now(),
          today: time.today(),
          plusActive: false,
          deviceLocked: ref.watch(gateControllerProvider).isBlocked,
          allowedFrom: e.paywallAllowedFrom,
          crisisDay: signals.crisisDay,
          lastCheckInQuadrant: signals.lastQuadrant,
          lastCheckInAt: signals.lastAt,
          unpromptedShownDay: signals.unpromptedDay,
        ),
      );
    });
