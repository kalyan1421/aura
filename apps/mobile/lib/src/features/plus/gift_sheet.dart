import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/entitlements/plus.dart';
import '../../core/net/aura_api.dart' show ApiException;
import '../../core/remote_config/remote_config_providers.dart';
import '../../core/theme/aura_tokens.dart';
import 'plus_format.dart';
import 'purchase_controller.dart';
import 'store_gateway.dart';

/// Kill switch key (PRD 19; server `@KillSwitch`, contracts v1.md flags).
const String giftsEnabledFlag = 'gifts_enabled';

/// Whether this person can open the gift sheet at all (the member sheet's
/// entry): purchases are on (`plus_enabled`), the gifts switch is on and gifting isn't paused / disabled. Blocked
/// people never appear in a room's member list, so their entry never shows
/// (REQ-PAY-04 "Blocked recipient → gift icon hidden").
final giftEntryVisibleProvider = Provider<bool>((ref) {
  if (!ref.watch(plusEnabledProvider)) return false;
  final flags = ref.watch(remoteFlagsProvider);
  if (!flags.enabled(giftsEnabledFlag)) return false;
  if (ref.watch(billingApiProvider) == null) return false;
  return ref.watch(entitlementProvider).gifting == GiftingState.ok;
});

/// "Send a gift" on a room member (06b REQ-ROOM-09; never in Breath Ripples).
/// Checked by the server BEFORE the store sheet (no block either way, not
/// sanctioned, ≤ 5 a day) — a refusal never opens the store and never says
/// why. No message; the recipient never learns who sent it.
Future<void> showGiftSheet(
  BuildContext context, {
  required String roomId,
  required String memberId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  showDragHandle: true,
  builder: (_) => GiftSheet(roomId: roomId, memberId: memberId),
);

class GiftSheet extends ConsumerStatefulWidget {
  const GiftSheet({super.key, required this.roomId, required this.memberId});

  final String roomId;
  final String memberId;

  @override
  ConsumerState<GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends ConsumerState<GiftSheet> {
  String _kind = 'warm_tea';
  String? _message;
  bool _checking = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = ref.read(purchaseControllerProvider.notifier)..reset();
      c.load(PlusProducts.giftByKind.values.toSet());
    });
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final api = ref.read(billingApiProvider);
    if (api == null) return;
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final check = await api.checkGift(
        giftId: const Uuid().v7(),
        roomId: widget.roomId,
        memberId: widget.memberId,
        kind: _kind,
      );
      _started = true;
      await ref
          .read(purchaseControllerProvider.notifier)
          .buy(check.productId, giftId: check.giftId);
    } on ApiException catch (e) {
      setState(
        () => _message = switch (e.code) {
          'gift_daily_limit' => l.plus_giftDailyLimit,
          'gifting_paused' ||
          'gifting_disabled' ||
          'gifting_unavailable' => l.plus_giftPaused,
          'gifts_paused' => l.plus_giftsOff,
          _ => l.plus_giftUnavailable,
        },
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final st = ref.watch(purchaseControllerProvider);
    final productId = PlusProducts.giftByKind[_kind]!;
    final price = st.products[productId]?.price;
    final phaseText = !_started
        ? null
        : switch (st.phase) {
            PurchasePhase.success => l.plus_giftSent,
            PurchasePhase.confirming => l.plus_confirming,
            PurchasePhase.confirmingLater => l.plus_confirmingLater,
            PurchasePhase.pendingApproval => l.plus_pendingApproval,
            PurchasePhase.declined => l.plus_declined,
            PurchasePhase.failed => l.plus_validationFailed,
            _ => null,
          };
    final busy =
        _checking ||
        st.phase == PurchasePhase.buying ||
        st.phase == PurchasePhase.confirming;
    return Padding(
      key: const ValueKey('gift-sheet'),
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        0,
        AuraSpace.gutter,
        AuraSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l.plus_giftTitle, style: t.titleLarge),
          ),
          const SizedBox(height: AuraSpace.xs),
          Text(
            l.plus_giftBody,
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.l),
          Wrap(
            spacing: AuraSpace.s,
            runSpacing: AuraSpace.s,
            children: [
              for (final kind in PlusProducts.giftByKind.keys)
                ChoiceChip(
                  key: ValueKey('gift-kind-$kind'),
                  label: Text(giftName(l, kind)),
                  selected: _kind == kind,
                  onSelected: busy ? null : (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.l),
          if (st.phase == PurchasePhase.storeUnavailable && price == null)
            Text(l.plus_storeUnavailable, style: t.bodyMedium)
          else
            FilledButton(
              key: const ValueKey('gift-send'),
              onPressed: price == null || busy ? null : _send,
              child: Text(
                price == null ? l.plus_loadingPrices : l.plus_giftSend(price),
              ),
            ),
          if (_message != null || phaseText != null)
            Padding(
              padding: const EdgeInsets.only(top: AuraSpace.m),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _message ?? phaseText!,
                  key: const ValueKey('gift-message'),
                ),
              ),
            ),
          TextButton(
            key: const ValueKey('gift-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.common_close),
          ),
        ],
      ),
    );
  }
}
