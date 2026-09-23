import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../sanctuary/sanctuary_activities.dart';

/// The activity "A minute for you" offers after a check-in in [quadrant]
/// (PRD 06d): Storm → thirty seconds to land, Rain → hand-on-heart comfort,
/// Moonlight → a minute of stillness, Sunrise → savour.
SanctuaryActivity minuteActivityFor(Quadrant quadrant) => switch (quadrant) {
  Quadrant.storm => SanctuaryActivity.land,
  Quadrant.rain => SanctuaryActivity.heart,
  Quadrant.moonlight => SanctuaryActivity.stillness,
  Quadrant.sunrise => SanctuaryActivity.savour,
};

/// The card's title and line for [quadrant].
(String, String) minuteCopyFor(AppLocalizations l, Quadrant quadrant) =>
    switch (quadrant) {
      Quadrant.storm => (l.minute_landTitle, l.minute_landBody),
      Quadrant.rain => (l.minute_comfortTitle, l.minute_comfortBody),
      Quadrant.moonlight => (l.minute_stillnessTitle, l.minute_stillnessBody),
      Quadrant.sunrise => (l.minute_savourTitle, l.minute_savourBody),
    };

/// "A minute for you" in the check-in saved moment: one optional card, for
/// every quadrant, with the same size, position and weight (REQ-CMP-05; the
/// copy of all four is laid out and the card takes the tallest, so no
/// quadrant's card is bigger). One tap opens the activity; ✕ ("Not now")
/// dismisses it. It never starts on its own and never leads to a paywall.
/// The caller doesn't show it after a crisis sheet (REQ-CMP-04).
class MinuteForYouCard extends StatelessWidget {
  const MinuteForYouCard({
    super.key,
    required this.quadrant,
    required this.onDismiss,
  });

  final Quadrant quadrant;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    // Reserve room for the ✕ in the header row.
    const closeSize = kMinInteractiveDimension;
    return Material(
      key: const ValueKey('minute-card'),
      color: AuraColors.surface.withValues(alpha: 0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        side: BorderSide(color: AuraColors.starlight.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          MergeSemantics(
            child: Semantics(
              button: true,
              child: InkWell(
                key: const ValueKey('minute-open'),
                onTap: () =>
                    openSanctuaryActivity(context, minuteActivityFor(quadrant)),
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: closeSize - AuraSpace.s,
                        ),
                        child: Row(
                          children: [
                            const ExcludeSemantics(
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: AuraColors.starlight,
                              ),
                            ),
                            const SizedBox(width: AuraSpace.s),
                            Flexible(
                              child: Text(
                                l.minute_forYou,
                                style: t.labelLarge?.copyWith(
                                  color: AuraColors.starlight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s),
                      // All four quadrants' copy is laid out; only this one is
                      // shown, painted and read (IndexedStack), and the card is
                      // as tall as the tallest: equal size for every feeling.
                      IndexedStack(
                        index: quadrant.index,
                        children: [
                          for (final q in Quadrant.values)
                            _Copy(copy: minuteCopyFor(l, q)),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.m),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.sanctuary_begin,
                              style: t.labelLarge?.copyWith(
                                color: AuraColors.lavender,
                              ),
                            ),
                            const SizedBox(width: AuraSpace.xs),
                            const ExcludeSemantics(
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: AuraColors.lavender,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: AuraSpace.xs,
            end: AuraSpace.xs,
            child: IconButton(
              key: const ValueKey('minute-dismiss'),
              tooltip: l.common_notNow,
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _Copy extends StatelessWidget {
  const _Copy({required this.copy});

  final (String, String) copy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (title, body) = copy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.titleMedium),
        const SizedBox(height: 2),
        Text(body, style: t.bodyMedium?.copyWith(color: AuraColors.textSoft)),
      ],
    );
  }
}
