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
    final modes = [
      (QuietMode.study, Icons.menu_book_outlined, l.quiet_modeStudy),
      (QuietMode.read, Icons.auto_stories_outlined, l.quiet_modeRead),
      (QuietMode.rest, Icons.bedtime_outlined, l.quiet_modeRest),
    ];
    // Three tiles, icon above a one-line label that never breaks mid-word
    // (it scales down a little instead). When even that is too tight (large
    // text, a longer language) the modes become full-width rows.
    final labelStyle = t.labelLarge;
    Widget tile(QuietMode m, IconData icon, String label) => Expanded(
      child: OutlinedButton(
        key: ValueKey('quiet-mode-${m.wire}'),
        onPressed: () => openQuiet(context, m),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s,
            vertical: AuraSpace.m,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.m),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: AuraSpace.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, softWrap: false),
            ),
          ],
        ),
      ),
    );
    Widget row(QuietMode m, IconData icon, String label) => Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s),
      child: OutlinedButton.icon(
        key: ValueKey('quiet-mode-${m.wire}'),
        onPressed: () => openQuiet(context, m),
        style: OutlinedButton.styleFrom(
          alignment: AlignmentDirectional.centerStart,
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
    Widget buttons(double width) {
      final slot = (width - 2 * AuraSpace.s) / 3 - 2 * AuraSpace.s - 2;
      final scaler = MediaQuery.textScalerOf(context);
      bool fits(String label) {
        final p = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final w = p.width;
        p.dispose();
        return w <= slot;
      }

      final asTiles =
          scaler.scale(100) / 100 <= 1.3 && modes.every((m) => fits(m.$3));
      if (!asTiles) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final m in modes) row(m.$1, m.$2, m.$3)],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in modes) ...[
            tile(m.$1, m.$2, m.$3),
            if (m != modes.last) const SizedBox(width: AuraSpace.s),
          ],
        ],
      );
    }

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
          LayoutBuilder(builder: (context, box) => buttons(box.maxWidth)),
        ],
      ),
    );
  }
}
