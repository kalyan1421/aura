import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/prefs/comfort_prefs.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../avatar/aura_avatar.dart' show stageName;
import '../progress/progress_view.dart';
import 'share_card_data.dart';
import 'share_sheet.dart';

/// `{ids: [...]}`: milestones already offered on this phone (RULES.md §11
/// `share_prompt`). The signed-in person's (wiped at sign-out).
const String sharePromptOfferedKey = 'share.offered';

/// Milestones already offered.
final offeredMilestonesProvider = StreamProvider<Set<String>>(
  (ref) => ref
      .watch(kvStoreProvider)
      .watchJson(sharePromptOfferedKey)
      .map(
        (j) => {...((j?['ids'] as List<dynamic>?) ?? const []).cast<String>()},
      ),
);

/// The Aura day of the first capsule ever sealed on this phone (deleted ones
/// too), for the capsule-anniversary card. `null` without one.
final firstCapsuleSealDayProvider = StreamProvider<LocalDay?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final tz = ref.watch(timeContextProvider).timezone;
  final first = db.capsules.sealedAt.min();
  return (db.selectOnly(db.capsules)..addColumns([first])).watchSingle().map((
    row,
  ) {
    final t = row.read(first);
    return t == null ? null : auraDay(t, tz);
  });
});

/// The one share prompt showing on Home this session (a milestone id), or
/// `null`. Offered once per milestone: every new milestone is marked offered
/// the moment the prompt shows.
class SharePromptController extends Notifier<String?> {
  @override
  String? build() => null;

  Future<void> show(SharePromptResult r) async {
    if (r.prompt != null && state == null) state = r.prompt;
    if (r.offer.isEmpty) return;
    final kv = ref.read(kvStoreProvider);
    final current = await kv.getJson(sharePromptOfferedKey);
    final all = {
      ...((current?['ids'] as List<dynamic>?) ?? const []).cast<String>(),
      ...r.offer,
    };
    await kv.setJson(sharePromptOfferedKey, {'ids': all.toList()..sort()});
  }

  void dismiss() => state = null;
}

final sharePromptProvider = NotifierProvider<SharePromptController, String?>(
  SharePromptController.new,
);

/// The card a milestone id stands for, from the current avatar.
ShareCardData? shareCardFor(String milestone, AuraAvatarState avatar) {
  final i = milestone.indexOf(':');
  if (i < 0) return null;
  final kind = milestone.substring(0, i);
  final value = milestone.substring(i + 1);
  return switch (kind) {
    'evolution' => ShareCardData.evolution(avatar),
    'glow' => ShareCardData.glow(avatar, int.tryParse(value) ?? 0),
    'capsule_anniversary' => ShareCardData.capsuleAnniversary(
      avatar,
      int.tryParse(value) ?? 1,
    ),
    _ => null,
  };
}

String? _promptText(AppLocalizations l, ShareCardData d) => switch (d.kind) {
  ShareCardKind.evolution => l.share_promptEvolution(stageName(l, d.stage)),
  ShareCardKind.glow => l.share_promptGlow(d.value ?? 0),
  ShareCardKind.capsuleAnniversary => l.share_promptAnniversary(d.value ?? 1),
  ShareCardKind.keepsake => null,
};

/// Home: "Your Aura reached Ember. Share a card of it?" — offered once per
/// milestone; several at once → one prompt, for the highest (RULES.md §11).
/// Glow milestones never prompt while Comfort › hide streak number is on.
/// Nothing is earned for sharing (REQ-SHR-03).
class SharePromptCard extends ConsumerWidget {
  const SharePromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(progressViewProvider);
    final showing = ref.watch(sharePromptProvider);
    final offered = ref.watch(offeredMilestonesProvider).value;
    final firstSeal = ref.watch(firstCapsuleSealDayProvider);
    final hideGlow = ref.watch(
      comfortControllerProvider.select((c) => c.hideStreak),
    );

    if (showing == null) {
      // Decide once everything is loaded; then mark offered after this frame.
      if (!view.loaded || offered == null || !firstSeal.hasValue) {
        return const SizedBox.shrink();
      }
      final r = sharePrompt(
        stage: view.avatar.stage,
        lifetimeGlowDays: view.streak.lifetimeGlowDays,
        capsuleYears: capsuleYears(firstSeal.value, view.today),
        offered: offered,
        hideGlow: hideGlow,
      );
      if (r.offer.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(ref.read(sharePromptProvider.notifier).show(r)),
        );
      }
      return const SizedBox.shrink();
    }

    final data = shareCardFor(showing, view.avatar);
    final l = AppLocalizations.of(context);
    final text = data == null ? null : _promptText(l, data);
    if (data == null || text == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final card = Padding(
      key: ValueKey('share-prompt-$showing'),
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s),
      child: Material(
        color: AuraColors.surface.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.l),
          side: BorderSide(color: AuraColors.lavender.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      color: AuraColors.lavender,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.m),
                  Expanded(child: Text(text, style: t.titleMedium)),
                ],
              ),
              const SizedBox(height: AuraSpace.m),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AuraSpace.s,
                children: [
                  TextButton(
                    key: const ValueKey('share-prompt-not-now'),
                    onPressed: () =>
                        ref.read(sharePromptProvider.notifier).dismiss(),
                    child: Text(l.common_notNow),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey('share-prompt-share'),
                    onPressed: () {
                      ref.read(sharePromptProvider.notifier).dismiss();
                      unawaited(showShareCardSheet(context, data));
                    },
                    child: Text(l.share_button),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return card;
  }
}
