import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../plus/paywall_gate.dart' show PaywallSurface;
import '../plus/plus_entry.dart' show PlusOpenButton;

/// A quiet card on the sky: translucent surface, hairline border, 26 dp
/// radius (design system "Cards"). One screen-reader container.
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(AuraSpace.l),
  });

  final Widget child;

  /// Optional border tint (the lantern for the care card).
  final Color? accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AuraColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AuraRadius.l),
        border: Border.all(
          color: accent?.withValues(alpha: 0.55) ?? AuraColors.hairline,
        ),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// The weekly insight card (PRD F10, REQ-INS-06): one pattern from the week
/// just ended, in words only. Lives in Insights; never pushed.
class WeeklyInsightCard extends StatelessWidget {
  const WeeklyInsightCard({
    super.key,
    required this.sentence,
    required this.onHide,
  });

  final String sentence;
  final VoidCallback onHide;

  static const Key cardKey = ValueKey('insights-weekly');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return InsightCard(
      key: cardKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: AuraColors.starlight,
                ),
              ),
              const SizedBox(width: AuraSpace.s),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.insights_weeklyTitle,
                    style: t.titleSmall?.copyWith(color: AuraColors.textSoft),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s),
          Text(
            sentence,
            key: const ValueKey('insights-weekly-text'),
            style: t.titleMedium,
          ),
          const SizedBox(height: AuraSpace.xs),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const ValueKey('insights-weekly-hide'),
              onPressed: onHide,
              child: Text(l.insights_weeklyHide),
            ),
          ),
        ],
      ),
    );
  }
}

/// "It's been a heavy couple of weeks" (PRD F10 care card, REQ-INS-04):
/// support and a room, never pushed, never a label. Uses the lantern tone
/// that marks support, not the Storm/Rain colours.
class CareCard extends StatelessWidget {
  const CareCard({
    super.key,
    required this.onSupport,
    required this.onRoom,
    required this.onNotNow,
  });

  final VoidCallback onSupport;
  final VoidCallback onRoom;
  final VoidCallback onNotNow;

  static const Key cardKey = ValueKey('insights-care');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return InsightCard(
      key: cardKey,
      accent: AuraColors.lantern,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(l.insights_careTitle, style: t.titleMedium),
          ),
          const SizedBox(height: AuraSpace.s),
          Text(
            l.insights_careBody,
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.m),
          Wrap(
            spacing: AuraSpace.s,
            runSpacing: AuraSpace.s,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('insights-care-support'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AuraColors.lantern,
                  side: const BorderSide(color: AuraColors.lantern),
                ),
                onPressed: onSupport,
                icon: const Icon(Icons.favorite_outline_rounded),
                label: Text(l.insights_careSupport),
              ),
              OutlinedButton.icon(
                key: const ValueKey('insights-care-room'),
                onPressed: onRoom,
                icon: const Icon(Icons.groups_outlined),
                label: Text(l.insights_careRoom),
              ),
              TextButton(
                key: const ValueKey('insights-care-later'),
                onPressed: onNotNow,
                child: Text(l.common_notNow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Your month in stars" in the Insights list (PRD F10, REQ-INS-07): from
/// the first Aura day of the month, a way into last month's recap.
class MonthInStarsCard extends StatelessWidget {
  const MonthInStarsCard({
    super.key,
    required this.monthName,
    required this.onOpen,
    required this.onHide,
  });

  final String monthName;
  final VoidCallback onOpen;
  final VoidCallback onHide;

  static const Key cardKey = ValueKey('insights-month');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return InsightCard(
      key: cardKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.nights_stay_outlined,
                  size: 18,
                  color: AuraColors.starlight,
                ),
              ),
              const SizedBox(width: AuraSpace.s),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.insights_monthTitle, style: t.titleMedium),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.xs),
          Text(
            l.insights_monthCardBody(monthName),
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.s),
          Wrap(
            spacing: AuraSpace.s,
            runSpacing: AuraSpace.xs,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                key: const ValueKey('insights-month-hide'),
                onPressed: onHide,
                child: Text(l.insights_monthHide),
              ),
              FilledButton(
                key: const ValueKey('insights-month-open'),
                onPressed: onOpen,
                child: Text(l.insights_monthOpen),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A Plus-only extra shown locked (PRD 14-states "Plus preview": a blurred
/// deeper chart; the basic sky stays free). Calm copy, no countdown, no
/// pressure; the way to the F12 paywall follows its P0 rules (PlusOpenButton).
class PlusLocked extends StatelessWidget {
  const PlusLocked({super.key, required this.message});

  final String message;

  static const Key lockedKey = ValueKey('insights-plus-locked');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      key: lockedKey,
      container: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        child: Stack(
          children: [
            // A blurred stand-in for the deeper chart: decorative only.
            Positioned.fill(
              child: ExcludeSemantics(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: const CustomPaint(painter: _PreviewBarsPainter()),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AuraSpace.l),
              color: AuraColors.skyHigh.withValues(alpha: 0.78),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ExcludeSemantics(
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: AuraColors.lavender,
                        ),
                      ),
                      const SizedBox(width: AuraSpace.xs),
                      Text(
                        l.insights_plusBadge,
                        style: t.labelMedium?.copyWith(
                          color: AuraColors.lavender,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.xs),
                  Text(
                    message,
                    style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                  ),
                  // F12: the way to Aura Plus, under the paywall rules
                  // (nothing at an excluded moment; the free sky stays).
                  const PlusOpenButton(surface: PaywallSurface.insightsDepth),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBarsPainter extends CustomPainter {
  const _PreviewBarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      AuraColors.storm,
      AuraColors.rain,
      AuraColors.moonlight,
      AuraColors.sunrise,
    ];
    final w = size.width / 9;
    for (var i = 0; i < 8; i++) {
      final h = size.height * (0.3 + 0.08 * ((i * 5) % 7));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * (i + 0.5), size.height - h, w * 0.6, h),
          const Radius.circular(4),
        ),
        Paint()..color = colors[i % 4].withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_PreviewBarsPainter old) => false;
}
