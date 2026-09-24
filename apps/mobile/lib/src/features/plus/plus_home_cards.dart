import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/entitlements/billing_api.dart';
import '../../core/entitlements/plus.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import 'paywall_gate.dart';
import 'plus_format.dart';

/// Quiet Home notices for Aura Plus and gifts (PRD 12 "Trial ending" in-app
/// card, "Billing issue" banner — in-app only, no push; 14-states "Trial
/// converted", "Trial cancelled"; F12 gifts "Someone here sent you a Comfort
/// Lantern."). Rules:
/// - the trial-ending card shows at most once a day in the last 2 days, and
///   never straight after a Storm or Rain check-in or in a crisis flow;
/// - one-time notes (trial cancelled, Plus continues) show once per event;
/// - every card is dismissible and opens the store's own page, nothing else.
class PlusHomeCards extends ConsumerStatefulWidget {
  const PlusHomeCards({super.key, this.opener = openStorePage});

  final PlusUrlOpener opener;

  @override
  ConsumerState<PlusHomeCards> createState() => _PlusHomeCardsState();
}

/// Notice keys already shown (one-time notes) and the day the trial card last
/// showed: account-scoped KV.
const String _seenKey = 'plus.notices_seen';

class _PlusHomeCardsState extends ConsumerState<PlusHomeCards> {
  Map<String, dynamic> _seen = const {};
  bool _loaded = false;
  List<ReceivedGift> _gifts = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final kv = ref.read(kvStoreProvider);
      final seen = await kv.getJson(_seenKey) ?? {};
      final api = ref.read(billingApiProvider);
      final gifts = api != null && ref.read(entitlementProvider).giftsUnseen > 0
          ? await api.receivedGifts()
          : const <ReceivedGift>[];
      if (!mounted) return;
      setState(() {
        _seen = seen;
        _gifts = gifts;
        _loaded = true;
      });
    } on Object {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _markSeen(String key, String value) async {
    final next = {..._seen, key: value};
    setState(() => _seen = next);
    try {
      await ref.read(kvStoreProvider).setJson(_seenKey, next);
    } on Object {
      // best-effort: at worst the card shows once more
    }
  }

  Future<void> _giftsSeen() async {
    final ids = [for (final g in _gifts) g.giftId];
    setState(() => _gifts = const []);
    try {
      await ref.read(billingApiProvider)?.giftsSeen(ids);
      unawaited(ref.read(entitlementProvider.notifier).refresh());
    } on Object {
      // shown again next time; harmless
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final e = ref.watch(entitlementProvider);
    final today = ref.read(timeContextProvider).today().toIso();
    // Fails closed: until the local signals load, the trial card waits.
    final signals = ref.watch(paywallSignalsProvider).value;
    final now = ref.read(timeContextProvider).now();
    final heavy =
        signals == null ||
        (signals.crisisDay?.toIso() == today) ||
        (signals.lastAt != null &&
            (signals.lastQuadrant == Quadrant.storm ||
                signals.lastQuadrant == Quadrant.rain) &&
            now.difference(signals.lastAt!) < heavyCheckInWindow);

    final cards = <Widget>[];
    for (final n in e.notices) {
      switch (n.kind) {
        case PlusNoticeKind.trialEnding:
          if (heavy || _seen['trial_ending_day'] == today || n.date == null) {
            continue;
          }
          final date = plusDate(context, n.date!);
          cards.add(
            _card(
              key: const ValueKey('plus-card-trial-ending'),
              text: n.price == null
                  ? l.plus_cardTrialEndingNoPrice(date)
                  : e.isAnnual
                  ? l.plus_cardTrialEndingYear(date, n.price!)
                  : l.plus_cardTrialEnding(date, n.price!),
              primary: l.plus_cardKeep,
              onPrimary: () => _markSeen('trial_ending_day', today),
              secondary: l.plus_manage,
              onSecondary: e.store == null
                  ? null
                  : () {
                      unawaited(_markSeen('trial_ending_day', today));
                      widget.opener(
                        manageSubscriptionUri(e.store!, productId: e.productId),
                      );
                    },
            ),
          );
        case PlusNoticeKind.trialCancelled || PlusNoticeKind.plusContinues:
          if (_seen[n.key] != null) continue;
          final text = n.kind == PlusNoticeKind.plusContinues
              ? l.plus_cardContinues
              : l.plus_cardTrialCancelled(
                  n.date == null ? '' : plusDate(context, n.date!),
                );
          cards.add(
            _card(
              key: ValueKey('plus-card-${n.kind.name}'),
              text: text,
              primary: l.plus_dismiss,
              onPrimary: () => _markSeen(n.key, today),
            ),
          );
        case PlusNoticeKind.billingIssue:
          if (_seen['billing_issue_day'] == today) continue;
          cards.add(
            _card(
              key: const ValueKey('plus-card-billing-issue'),
              text: l.plus_cardBillingIssue,
              primary: l.plus_dismiss,
              onPrimary: () => _markSeen('billing_issue_day', today),
              secondary: l.plus_updatePayment,
              onSecondary: e.store == null
                  ? null
                  : () => widget.opener(
                      manageSubscriptionUri(e.store!, productId: e.productId),
                    ),
            ),
          );
        case PlusNoticeKind.billingPaused || PlusNoticeKind.refunded:
          break; // Settings says it; no Home card
      }
    }
    for (final g in _gifts.take(1)) {
      cards.add(
        _card(
          key: const ValueKey('plus-card-gift'),
          text:
              '${l.plus_giftReceived(giftName(l, g.kind))} ${l.plus_giftStardust(g.stardust)}',
          primary: l.plus_dismiss,
          onPrimary: _giftsSeen,
        ),
      );
    }
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: cards);
  }

  Widget _card({
    required Key key,
    required String text,
    required String primary,
    required VoidCallback onPrimary,
    String? secondary,
    VoidCallback? onSecondary,
  }) {
    final t = Theme.of(context).textTheme;
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AuraSpace.m),
      padding: const EdgeInsets.all(AuraSpace.l),
      decoration: BoxDecoration(
        color: AuraColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AuraRadius.m),
        border: Border.all(color: AuraColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: t.bodyMedium),
          const SizedBox(height: AuraSpace.s),
          Wrap(
            spacing: AuraSpace.s,
            children: [
              TextButton(onPressed: onPrimary, child: Text(primary)),
              if (secondary != null && onSecondary != null)
                TextButton(onPressed: onSecondary, child: Text(secondary)),
            ],
          ),
        ],
      ),
    );
  }
}
