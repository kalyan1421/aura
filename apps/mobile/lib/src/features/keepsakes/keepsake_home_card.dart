import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/prefs/comfort_prefs.dart';
import '../../core/theme/aura_tokens.dart';
import '../share/share_prompt.dart';
import 'keepsake_seal.dart';
import 'keepsakes_providers.dart';
import 'keepsakes_screen.dart' show keepsakesRoute;

/// Home's one F13 slot: a new keepsake shows once as a small card (PRD "A new
/// seal shows once as a small card on Home"); otherwise the milestone share
/// prompt (offered once per milestone). Never both at once, so Home stays
/// calm. Also keeps the keepsake cache fresh after syncs.
class KeepsakeHomeCards extends ConsumerWidget {
  const KeepsakeHomeCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(keepsakesAutoRefreshProvider);
    final showing = ref.watch(keepsakeHomeProvider);
    if (showing != null && showing.isNotEmpty) {
      return _NewKeepsakeCard(keys: [for (final k in showing) k.key]);
    }
    final list = ref.watch(keepsakesProvider).value;
    final seen = ref.watch(seenKeepsakesProvider).value;
    if (list != null && seen != null) {
      final fresh = list.where((k) => !seen.contains(k.key)).toList();
      if (fresh.isNotEmpty) {
        final hideGlow = ref.read(comfortControllerProvider).hideStreak;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(
            ref
                .read(keepsakeHomeProvider.notifier)
                .show(
                  fresh,
                  quiet: {
                    if (hideGlow)
                      for (final k in fresh)
                        if (isGlowKeepsake(k.key)) k.key,
                  },
                ),
          ),
        );
        return const SizedBox.shrink();
      }
    }
    return const SharePromptCard();
  }
}

class _NewKeepsakeCard extends ConsumerWidget {
  const _NewKeepsakeCard({required this.keys});

  final List<String> keys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final single = keys.length == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s),
      child: Material(
        key: const ValueKey('keepsake-new-card'),
        color: AuraColors.surface.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.l),
          side: BorderSide(color: AuraColors.starlight.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AuraSpace.l,
            AuraSpace.m,
            AuraSpace.xs,
            AuraSpace.m,
          ),
          child: Row(
            children: [
              KeepsakeSeal(keepsakeKey: keys.first, size: 56),
              const SizedBox(width: AuraSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(l.keepsakes_newTitle, style: t.titleMedium),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      single
                          ? keepsakeLine(l, keys.first)
                          : l.keepsakes_newSeveral,
                      style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        key: const ValueKey('keepsake-new-open'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () {
                          ref.read(keepsakeHomeProvider.notifier).dismiss();
                          context.push(keepsakesRoute);
                        },
                        child: Text(l.keepsakes_newOpen),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('keepsake-new-hide'),
                tooltip: l.keepsakes_hideCard,
                onPressed: () =>
                    ref.read(keepsakeHomeProvider.notifier).dismiss(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
