import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/entitlements/plus.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import 'paywall_gate.dart';
import 'plus_entry.dart';
import 'plus_format.dart';
import 'purchase_controller.dart';

/// Settings › Aura Plus (PRD 14-states "Trial active" … "refunded"; F12
/// "Restore in Settings", "Plus follows the account across platforms").
/// Status in plain words, the store's own manage page, Restore, and the way
/// to the personal sky + Stardust.
class PlusSettingsSection extends ConsumerWidget {
  const PlusSettingsSection({super.key, this.opener = openStorePage});

  /// Opens the store page (tests inject one).
  final PlusUrlOpener opener;

  static const Key statusKey = ValueKey('plus-settings-status');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final e = ref.watch(entitlementProvider);
    final now = ref.read(timeContextProvider).now();
    final mode = ref.watch(paywallModeProvider(PaywallSurface.settings));
    final st = ref.watch(purchaseControllerProvider);
    String date(DateTime? d) => d == null ? '' : plusDate(context, d);
    final onThisStore =
        e.store == null ||
        (e.store == PlusStore.apple) ==
            (defaultTargetPlatform == TargetPlatform.iOS);

    final status = switch (e.status) {
      PlusStatus.trial when e.autoRenew == false => l.plus_statusTrialCancelled(
        date(e.trialEndsAt ?? e.expiresAt),
      ),
      PlusStatus.trial => l.plus_statusTrial(
        e.trialEndsAt == null
            ? 0
            : e.trialEndsAt!.difference(now).inDays.clamp(0, 31),
        date(e.trialEndsAt),
      ),
      PlusStatus.cancelled
          when e.trialEndsAt != null && e.expiresAt == e.trialEndsAt =>
        l.plus_statusTrialCancelled(date(e.expiresAt)),
      PlusStatus.cancelled => l.plus_statusCancelled(date(e.expiresAt)),
      PlusStatus.active => l.plus_statusActive(date(e.expiresAt)),
      PlusStatus.grace => l.plus_statusGrace,
      PlusStatus.billingRetry || PlusStatus.paused => l.plus_statusBillingRetry,
      PlusStatus.expired => l.plus_statusExpired,
      PlusStatus.refunded || PlusStatus.revoked => l.plus_statusRefunded,
      PlusStatus.pending => l.plus_statusPending,
      PlusStatus.none => l.plus_statusFree,
    };
    final manageLabel = switch (e.status) {
      PlusStatus.grace || PlusStatus.billingRetry => l.plus_updatePayment,
      PlusStatus.cancelled => l.plus_turnBackOn,
      _ => l.plus_manage,
    };
    final hasSubscription = e.store != null && e.status != PlusStatus.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(status, key: statusKey, style: t.bodyMedium),
        if (hasSubscription && !onThisStore) ...[
          const SizedBox(height: AuraSpace.xs),
          Text(
            l.plus_managedElsewhere(storeName(l, e.store!)),
            key: const ValueKey('plus-settings-elsewhere'),
            style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
          ),
        ],
        const SizedBox(height: AuraSpace.s),
        if (hasSubscription)
          OutlinedButton(
            key: const ValueKey('plus-settings-manage'),
            onPressed: () =>
                opener(manageSubscriptionUri(e.store!, productId: e.productId)),
            child: Text(manageLabel),
          )
        else if (mode == PaywallMode.explainer || mode == PaywallMode.link)
          OutlinedButton(
            key: const ValueKey('plus-settings-see'),
            onPressed: () => openPlus(context, PaywallSurface.settings),
            child: Text(l.plus_seePlus),
          )
        else if (mode == PaywallMode.lockedOnly &&
            e.paywallAllowedFrom != null &&
            now.isBefore(e.paywallAllowedFrom!))
          Text(
            l.plus_notYet,
            key: const ValueKey('plus-settings-not-yet'),
            style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
          ),
        TextButton(
          key: const ValueKey('plus-settings-restore'),
          onPressed: () =>
              ref.read(purchaseControllerProvider.notifier).restore(),
          child: Text(l.plus_restore),
        ),
        if (st.restored != null)
          Semantics(
            liveRegion: true,
            child: Text(
              l.plus_restored(st.restored!.restored),
              key: const ValueKey('plus-settings-restored'),
              style: t.bodySmall,
            ),
          ),
        ListTile(
          key: const ValueKey('plus-settings-skies'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.nights_stay_outlined),
          title: Text(l.plus_settingsSky),
          subtitle: Text(l.plus_stardustBalance(e.stardust)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(plusSkiesRoute),
        ),
      ],
    );
  }
}
