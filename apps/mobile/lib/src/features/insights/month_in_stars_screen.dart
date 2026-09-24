import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/entitlements/plus.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../checkin/quadrant_glyph.dart';
import '../progress/progress_view.dart';
import 'insight_cards.dart';
import 'insights_copy.dart';
import 'insights_providers.dart';
import 'sky_painter.dart';

/// "Your month in stars" (`/insights/month`, PRD F10 Milestone B,
/// REQ-INS-07): last month's recap, from the first Aura day of the month.
///
/// Free (never gated): days checked in, lifetime glow days and the quadrant
/// mix drawn as a sky. Plus: the deeper monthly review (patterns across the
/// month, habit × mood), shown locked otherwise. There is no share button:
/// sharing comes only through F13 templates, which never carry a mood or
/// the sky's colours.
class MonthInStarsScreen extends ConsumerWidget {
  const MonthInStarsScreen({super.key});

  static const Key skyKey = ValueKey('month-sky');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final model = ref.watch(insightsModelProvider);
    final localeTag = ref.watch(localeControllerProvider);
    final plus = ref.watch(plusActiveProvider);
    final habits = ref.watch(insightsHabitsProvider).value ?? const {};
    final glow = ref.watch(
      progressViewProvider.select((v) => v.streak.lifetimeGlowDays),
    );
    final recap = monthRecap(model.checkIns, model.today);
    final from = recap.range.from;
    final monthName = monthYearLabel(localeTag, from.year, from.month);
    final soft = t.bodyLarge?.copyWith(color: AuraColors.textSoft);

    return Scaffold(
      appBar: helpAppBar(context, title: l.insights_monthTitle),
      body: CosmicBackground(
        child: ListView(
          key: const ValueKey('month-list'),
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.gutter,
            AuraSpace.s,
            AuraSpace.gutter,
            AuraSpace.xxl,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(monthName, style: t.headlineSmall),
            ),
            const SizedBox(height: AuraSpace.l),
            Semantics(
              container: true,
              image: true,
              label: l.insights_monthSkySemantic(recap.checkIns, monthName),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AuraRadius.l),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AuraColors.skyHigh, AuraColors.skyDeep],
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: CustomPaint(
                      key: skyKey,
                      painter: MixSkyPainter(
                        counts: recap.quadrantCounts,
                        seed: from.year * 100 + from.month,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.l),
            Text(
              l.insights_monthDays(recap.daysCheckedIn),
              key: const ValueKey('month-days'),
              style: soft,
            ),
            Text(
              l.home_lifetimeGlow(glow),
              key: const ValueKey('month-glow'),
              style: soft,
            ),
            const SizedBox(height: AuraSpace.xl),
            Semantics(
              header: true,
              child: Text(l.insights_monthMixTitle, style: t.titleMedium),
            ),
            const SizedBox(height: AuraSpace.s),
            for (final q in Quadrant.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.xs),
                child: Row(
                  children: [
                    ExcludeSemantics(child: QuadrantGlyph(q, size: 22)),
                    const SizedBox(width: AuraSpace.m),
                    Expanded(
                      child: Text(
                        l.insights_monthMixItem(
                          quadrantName(l, q),
                          recap.quadrantCounts[q] ?? 0,
                        ),
                        style: t.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AuraSpace.xl),
            Semantics(
              header: true,
              child: Text(l.insights_deeperTitle, style: t.titleMedium),
            ),
            const SizedBox(height: AuraSpace.s),
            if (!plus)
              PlusLocked(message: l.insights_deeperLocked)
            else
              _Deeper(model: model, recap: recap, habits: habits),
          ],
        ),
      ),
    );
  }
}

class _Deeper extends StatelessWidget {
  const _Deeper({
    required this.model,
    required this.recap,
    required this.habits,
  });

  final InsightsModel model;
  final MonthRecap recap;
  final Map<String, HabitRow> habits;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final patterns = findPatterns(
      checkIns: model.checkIns,
      habitLogs: model.habitLogs,
      range: recap.range,
      includeHabits: true,
    );
    if (patterns.isEmpty) {
      return Text(
        l.insights_deeperNone,
        key: const ValueKey('month-deeper-none'),
        style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
      );
    }
    return Column(
      key: const ValueKey('month-deeper'),
      children: [
        for (final p in patterns)
          Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s),
            child: InsightCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.l,
                vertical: AuraSpace.m,
              ),
              child: Text(
                patternSentence(l, p, habits: habits),
                style: t.bodyLarge,
              ),
            ),
          ),
      ],
    );
  }
}
