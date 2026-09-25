import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import 'quiet_models.dart';
import 'quiet_providers.dart';
import 'quiet_screen.dart';

/// The Rooms tab entry (PRD F16 "Entry is from the Rooms tab; choosing a
/// mode isn't browsing people"): three modes, one tap each. Hidden while
/// Quiet Together is switched off or rooms aren't usable here. No count or
/// invite is shown here: a live count would be social pressure (PRD 12).
class QuietTogetherCard extends ConsumerWidget {
  const QuietTogetherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(quietReadyProvider)) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    Widget mode(QuietMode m, IconData icon, String label) => Expanded(
      child: OutlinedButton.icon(
        key: ValueKey('quiet-mode-${m.wire}'),
        onPressed: () => openQuiet(context, m),
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 2, textAlign: TextAlign.center),
      ),
    );
    return Container(
      key: const ValueKey('quiet-card'),
      padding: const EdgeInsets.all(AuraSpace.l),
      decoration: BoxDecoration(
        color: AuraColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AuraRadius.l),
        border: Border.all(color: AuraColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.nights_stay_outlined,
                  color: AuraColors.moonlight,
                ),
              ),
              const SizedBox(width: AuraSpace.s),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.quiet_title, style: t.titleMedium),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.xs),
          Text(
            l.quiet_cardBody,
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.m),
          Row(
            children: [
              mode(
                QuietMode.study,
                Icons.menu_book_outlined,
                l.quiet_modeStudy,
              ),
              const SizedBox(width: AuraSpace.s),
              mode(
                QuietMode.read,
                Icons.auto_stories_outlined,
                l.quiet_modeRead,
              ),
              const SizedBox(width: AuraSpace.s),
              mode(QuietMode.rest, Icons.bedtime_outlined, l.quiet_modeRest),
            ],
          ),
        ],
      ),
    );
  }
}
