import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/kv_store.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import 'support_sheet.dart';

/// Crisis follow-up (PRD 12 catalogue: "Support sheet shown 12–72 h ago ·
/// **In-app card on next open only** · Once per event"; "Why some items are
/// never pushed": no push ever mentions distress, Aura is not an emergency
/// service).
///
/// Entirely on this phone: when the crisis support sheet shows, its time is
/// kept in the local encrypted store (never synced, never logged, never in
/// analytics). The next time Aura opens 12–72 h later, Home shows one calm,
/// dismissible card with "I need help now" (the Safety Center: helplines for
/// the locale). The event is used up when the card appears, so it never
/// comes back for the same event.
const String crisisSheetShownKey = 'support.crisisShownAt';
const String crisisFollowUpDoneKey = 'support.crisisFollowUpFor';
const Duration crisisFollowUpFrom = Duration(hours: 12);
const Duration crisisFollowUpUntil = Duration(hours: 72);

/// The crisis support sheet just showed (called by [SupportSheet]).
Future<void> recordCrisisSheetShown(KvStore kv, DateTime now) async {
  try {
    await kv.set(crisisSheetShownKey, now.toUtc().toIso8601String());
  } on Object catch (e) {
    debugPrint('support: follow-up mark (${e.runtimeType})');
  }
}

/// Whether the follow-up is due now; when it is, it is marked done for this
/// event at once (shown once). Never throws.
Future<bool> takeCrisisFollowUp(KvStore kv, DateTime now) async {
  try {
    final raw = await kv.get(crisisSheetShownKey);
    final at = DateTime.tryParse(raw ?? '');
    if (at == null || raw == null) return false;
    final age = now.toUtc().difference(at.toUtc());
    if (age < crisisFollowUpFrom || age > crisisFollowUpUntil) return false;
    if (await kv.get(crisisFollowUpDoneKey) == raw) return false;
    await kv.set(crisisFollowUpDoneKey, raw);
    return true;
  } on Object catch (e) {
    debugPrint('support: follow-up check (${e.runtimeType})');
    return false;
  }
}

/// The card on Home (nothing when no follow-up is due). Checks when Home
/// first shows and whenever Aura comes back to the foreground.
class CrisisFollowUpCard extends ConsumerStatefulWidget {
  const CrisisFollowUpCard({super.key});

  @override
  ConsumerState<CrisisFollowUpCard> createState() => _CrisisFollowUpCardState();
}

class _CrisisFollowUpCardState extends ConsumerState<CrisisFollowUpCard> {
  bool _show = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_check()));
    unawaited(_check());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_show) return;
    final kv = ref.read(kvStoreProvider);
    final now = ref.read(timeContextProvider).now();
    if (await takeCrisisFollowUp(kv, now) && mounted) {
      setState(() => _show = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s),
      child: Material(
        key: const ValueKey('crisis-follow-up'),
        color: AuraColors.surface.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.m),
          side: const BorderSide(color: AuraColors.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                container: true,
                child: Text(l.notif_crisisFollowUp, style: t.bodyLarge),
              ),
              const SizedBox(height: AuraSpace.m),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AuraSpace.s,
                children: [
                  TextButton(
                    key: const ValueKey('crisis-follow-up-close'),
                    onPressed: () => setState(() => _show = false),
                    child: Text(l.notif_crisisFollowUpDismiss),
                  ),
                  FilledButton(
                    key: const ValueKey('crisis-follow-up-help'),
                    onPressed: () => openSafetyCenter(context),
                    child: Text(l.help_button),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
