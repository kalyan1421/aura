import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/entitlements/plus.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../../core/widgets/legal_links.dart';
import 'paywall_gate.dart';
import 'plus_format.dart';
import 'purchase_controller.dart';
import 'store_gateway.dart';

/// The Aura Plus explainer (PRD F12, 14-states "Paywall, trial and store").
/// Honest by construction: the store's own price, "1 month free, then
/// {price}/month" only when this store account can still get the free month,
/// the trial end date, auto-renewal and how to cancel, Restore and Terms
/// (App Review 3.1.2), always a way out ("Not now"). No countdowns, no
/// urgency, no confirm-shaming (CCPA Dark Patterns Guidelines 2023).
///
/// Opened only from a limit screen or Settings (PaywallSurface); it re-checks
/// the P0 exclusions itself, so even a stray link shows only "Part of Aura
/// Plus" at an excluded moment.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.surface = PaywallSurface.settings});

  final PaywallSurface surface;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _plan = PlusProducts.monthly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(purchaseControllerProvider.notifier).reset();
      ref.read(purchaseControllerProvider.notifier).load(PlusProducts.plus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mode = ref.watch(paywallModeProvider(widget.surface));
    final e = ref.watch(entitlementProvider);
    return Scaffold(
      appBar: helpAppBar(context, title: l.plus_title),
      body: CosmicBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.gutter,
              AuraSpace.s,
              AuraSpace.gutter,
              AuraSpace.xxl,
            ),
            children: switch (mode) {
              PaywallMode.none => _plusOn(context, e),
              PaywallMode.lockedOnly => _quiet(context),
              PaywallMode.link || PaywallMode.explainer => _offer(context),
            },
          ),
        ),
      ),
    );
  }

  /// An excluded moment: no offer at all. Restore stays (it is the person's
  /// own purchase, not an offer).
  List<Widget> _quiet(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return [
      Text(
        l.plus_lockedOnly,
        key: const ValueKey('paywall-locked-only'),
        style: t.titleMedium,
      ),
      if (widget.surface == PaywallSurface.settings) ...[
        const SizedBox(height: AuraSpace.s),
        Text(
          l.plus_notYet,
          style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
        ),
      ],
      const SizedBox(height: AuraSpace.l),
      _restoreButton(context),
      _phaseNote(context),
      TextButton(
        key: const ValueKey('paywall-not-now'),
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text(l.common_notNow),
      ),
    ];
  }

  List<Widget> _plusOn(BuildContext context, Entitlement e) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return [
      Text(
        l.plus_welcome,
        key: const ValueKey('paywall-plus-on'),
        style: t.titleMedium,
      ),
      const SizedBox(height: AuraSpace.l),
      if (e.store != null)
        OutlinedButton(
          key: const ValueKey('paywall-manage'),
          onPressed: () => openStorePage(
            manageSubscriptionUri(e.store!, productId: e.productId),
          ),
          child: Text(l.plus_manage),
        ),
    ];
  }

  List<Widget> _offer(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final soft = t.bodyMedium?.copyWith(color: AuraColors.textSoft);
    final st = ref.watch(purchaseControllerProvider);
    final store = ref.watch(storeGatewayProvider).platform;
    final monthly = st.products[PlusProducts.monthly];
    final annual = st.products[PlusProducts.annual];
    final chosen = st.products[_plan] ?? monthly ?? annual;
    final loading =
        st.phase == PurchasePhase.loading ||
        (st.phase == PurchasePhase.idle && st.products.isEmpty);
    final now = ref.read(timeContextProvider).now();
    final trialEnd = DateTime.utc(now.year, now.month + 1, now.day, now.hour);
    final busy =
        st.phase == PurchasePhase.buying ||
        st.phase == PurchasePhase.confirming;

    Widget perk(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.auto_awesome_outlined,
                size: 16,
                color: AuraColors.lavender,
              ),
            ),
          ),
          const SizedBox(width: AuraSpace.s),
          Expanded(child: Text(text, style: t.bodyMedium)),
        ],
      ),
    );

    Widget plan(String id, StoreProduct? p, String label) {
      final selected = _plan == id;
      final annualPlan = id == PlusProducts.annual;
      final priceLine = p == null
          ? ''
          : p.trialOffered
          ? (annualPlan
                ? l.plus_trialLineAnnual(p.price)
                : l.plus_trialLineMonthly(p.price))
          : (annualPlan
                ? l.plus_priceAnnual(p.price)
                : l.plus_priceMonthly(p.price));
      return Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          key: ValueKey('paywall-plan-$id'),
          borderRadius: BorderRadius.circular(AuraRadius.m),
          onTap: p == null ? null : () => setState(() => _plan = id),
          child: Container(
            padding: const EdgeInsets.all(AuraSpace.l),
            decoration: BoxDecoration(
              color: AuraColors.surface.withValues(
                alpha: selected ? 0.9 : 0.55,
              ),
              borderRadius: BorderRadius.circular(AuraRadius.m),
              border: Border.all(
                color: selected ? AuraColors.accent : AuraColors.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.titleSmall),
                const SizedBox(height: AuraSpace.xs),
                Text(
                  priceLine,
                  key: ValueKey('paywall-price-$id'),
                  style: t.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return [
      Text(l.plus_intro, style: t.titleMedium),
      const SizedBox(height: AuraSpace.l),
      Text(l.plus_addsTitle, style: t.titleSmall),
      perk(l.plus_addCapsules),
      perk(l.plus_addVoice),
      perk(l.plus_addInsights),
      perk(l.plus_addSounds),
      const SizedBox(height: AuraSpace.l),
      Text(l.plus_freeTitle, style: t.titleSmall),
      const SizedBox(height: AuraSpace.xs),
      Text(
        l.plus_freeBody,
        key: const ValueKey('paywall-always-free'),
        style: soft,
      ),
      const SizedBox(height: AuraSpace.xl),
      if (loading)
        Semantics(
          label: l.plus_loadingPrices,
          child: Column(
            key: const ValueKey('paywall-skeleton'),
            children: [
              for (var i = 0; i < 2; i++)
                Container(
                  height: 72,
                  margin: const EdgeInsets.only(bottom: AuraSpace.s),
                  decoration: BoxDecoration(
                    color: AuraColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AuraRadius.m),
                  ),
                ),
            ],
          ),
        )
      else if (st.phase == PurchasePhase.storeUnavailable &&
          st.products.isEmpty) ...[
        Text(
          l.plus_storeUnavailable,
          key: const ValueKey('paywall-store-unavailable'),
          style: soft,
        ),
        TextButton(
          key: const ValueKey('paywall-retry'),
          onPressed: () => ref
              .read(purchaseControllerProvider.notifier)
              .load(PlusProducts.plus),
          child: Text(l.plus_retry),
        ),
      ] else ...[
        if (monthly != null)
          plan(PlusProducts.monthly, monthly, l.plus_planMonthly),
        const SizedBox(height: AuraSpace.s),
        if (annual != null)
          plan(PlusProducts.annual, annual, l.plus_planAnnual),
        const SizedBox(height: AuraSpace.l),
        if (chosen != null && chosen.trialOffered)
          Text(
            l.plus_trialEnds(plusDate(context, trialEnd)),
            key: const ValueKey('paywall-trial-end'),
            style: t.bodyMedium,
          ),
        const SizedBox(height: AuraSpace.xs),
        Text(
          l.plus_renews(
            storeName(
              l,
              store == StorePlatform.apple ? PlusStore.apple : PlusStore.google,
            ),
          ),
          style: soft,
        ),
        const SizedBox(height: AuraSpace.xs),
        Text(
          store == StorePlatform.apple
              ? l.plus_cancelApple
              : l.plus_cancelGoogle,
          key: const ValueKey('paywall-cancel-steps'),
          style: soft,
        ),
        const SizedBox(height: AuraSpace.l),
        FilledButton(
          key: const ValueKey('paywall-buy'),
          onPressed: chosen == null || busy
              ? null
              : () => ref
                    .read(purchaseControllerProvider.notifier)
                    .buy(chosen.id),
          child: Text(
            chosen?.trialOffered ?? false
                ? l.plus_startTrial
                : l.plus_subscribe,
          ),
        ),
      ],
      _phaseNote(context),
      const SizedBox(height: AuraSpace.s),
      TextButton(
        key: const ValueKey('paywall-not-now'),
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text(l.common_notNow),
      ),
      _restoreButton(context),
      const SizedBox(height: AuraSpace.m),
      const LegalLinks(),
    ];
  }

  Widget _restoreButton(BuildContext context) => TextButton(
    key: const ValueKey('paywall-restore'),
    onPressed: () => ref.read(purchaseControllerProvider.notifier).restore(),
    child: Text(AppLocalizations.of(context).plus_restore),
  );

  /// The current step, in the PRD's words. Live region for screen readers.
  Widget _phaseNote(BuildContext context) {
    final l = AppLocalizations.of(context);
    final st = ref.watch(purchaseControllerProvider);
    final text = switch (st.phase) {
      PurchasePhase.confirming => l.plus_confirming,
      PurchasePhase.confirmingLater => l.plus_confirmingLater,
      PurchasePhase.pendingApproval => l.plus_pendingApproval,
      PurchasePhase.declined => l.plus_declined,
      PurchasePhase.failed => l.plus_validationFailed,
      PurchasePhase.success => l.plus_welcome,
      PurchasePhase.ownedElsewhere => l.plus_ownedElsewhere,
      PurchasePhase.storeUnavailable when st.products.isNotEmpty =>
        l.plus_storeUnavailable,
      _ => st.restored != null ? l.plus_restored(st.restored!.restored) : null,
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.m),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          key: ValueKey('paywall-phase-${st.phase.name}'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
