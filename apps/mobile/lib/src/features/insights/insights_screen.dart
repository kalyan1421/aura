import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/entitlements/plus.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/help_app_bar.dart';
import '../plus/sky_themes.dart';
import '../progress/progress_view.dart';
import '../shell/app_shell.dart'
    show ShellSettingsButton, isShellTabRoot, openCheckIn;
import '../support/support_sheet.dart';
import 'day_sheet.dart';
import 'insight_cards.dart';
import 'insights_copy.dart';
import 'insights_providers.dart';
import 'sky_calendar.dart';

/// The Insights tab: Aura Sky (PRD F10, Milestone B).
///
/// From the top: the care card when the last two weeks were heavy, the
/// weekly insight card (first Aura day of the week), "Your month in stars"
/// (first Aura day of the month), the sky calendar, plain-language patterns
/// from the last 30 days, lifetime stats and the way into the full history.
///
/// Everything is worked out on this phone from Drift and works offline
/// (REQ-INS-02, 16-offline). Plus (F12) only adds depth: any range and
/// habit × mood; the sky, history, weekly card and the basic month in stars
/// are never gated (REQ-INS-05). Nothing here is ever pushed.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  /// Patterns shown at once (strongest first).
  static const int maxPatterns = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final model = ref.watch(insightsModelProvider);
    final localeTag = ref.watch(localeControllerProvider);

    return Scaffold(
      appBar: helpAppBar(
        context,
        title: l.insights_title,
        // The tab's first screen: Settings instead of Back (app shell).
        leading: isShellTabRoot(context) ? const ShellSettingsButton() : null,
      ),
      body: PersonalSkyBackground(
        // F12: the person's own sky theme
        child: !model.loaded
            ? const SizedBox.shrink() // local read: a blink at most
            : _Body(model: model, localeTag: localeTag),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.model, required this.localeTag});

  final InsightsModel model;
  final String localeTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final plus = ref.watch(plusActiveProvider);
    final habits = ref.watch(insightsHabitsProvider).value ?? const {};
    final today = model.today;
    final kv = ref.read(kvStoreProvider);

    String? hidden(String key) => ref.watch(insightsHiddenProvider(key)).value;

    // Care card (REQ-INS-04): in Insights only, set aside for the day.
    final care =
        showCareCard(model.checkIns, today) &&
        hidden(InsightsKeys.careHidden) != today.toIso();

    // Weekly card (REQ-INS-06): the week just ended, one pattern.
    final week = weeklyWindow(today);
    final weekly = hidden(InsightsKeys.weeklyHidden) == week.weekStart.toIso()
        ? null
        : weeklyInsight(
            checkIns: model.checkIns,
            habitLogs: model.habitLogs,
            today: today,
            includeHabits: plus,
          );

    // Month in stars (REQ-INS-07): last month, when it has anything to show.
    final recap = monthRecap(model.checkIns, today);
    final showRecap =
        recap.checkIns > 0 && hidden(InsightsKeys.monthHidden) != recap.month;

    return ListView(
      key: const ValueKey('insights-list'),
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.m,
        AuraSpace.s,
        AuraSpace.m,
        AuraSpace.xxl,
      ),
      children: [
        _Padded(
          child: Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: AuraColors.textMuted,
                ),
              ),
              const SizedBox(width: AuraSpace.xs),
              Expanded(
                child: Text(
                  l.insights_private,
                  style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
                ),
              ),
            ],
          ),
        ),
        if (model.isEmpty) ...[
          const SizedBox(height: AuraSpace.l),
          _Padded(
            child: Column(
              children: [
                Text(
                  l.insights_empty,
                  key: const ValueKey('insights-empty'),
                  textAlign: TextAlign.center,
                  style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
                ),
                const SizedBox(height: AuraSpace.m),
                FilledButton(
                  key: const ValueKey('insights-checkin'),
                  onPressed: () => openCheckIn(context),
                  child: Text(l.home_checkIn),
                ),
              ],
            ),
          ),
        ],
        if (care) ...[
          const SizedBox(height: AuraSpace.l),
          CareCard(
            onSupport: () => showSupportSheet(context),
            onRoom: () => context.go(Routes.rooms),
            onNotNow: () => kv.set(InsightsKeys.careHidden, today.toIso()),
          ),
        ],
        if (weekly != null) ...[
          const SizedBox(height: AuraSpace.l),
          WeeklyInsightCard(
            sentence: patternSentence(l, weekly, habits: habits),
            onHide: () =>
                kv.set(InsightsKeys.weeklyHidden, week.weekStart.toIso()),
          ),
        ],
        if (showRecap) ...[
          const SizedBox(height: AuraSpace.l),
          MonthInStarsCard(
            monthName: monthYearLabel(
              localeTag,
              recap.range.from.year,
              recap.range.from.month,
            ),
            onOpen: () => context.push(Routes.insightsMonth),
            onHide: () => kv.set(InsightsKeys.monthHidden, recap.month),
          ),
        ],
        const SizedBox(height: AuraSpace.l),
        SkyCalendar(
          model: model,
          localeTag: localeTag,
          onDayTap: (day) => showDaySheet(
            context,
            day: day,
            today: today,
            rows: model.byDay[day] ?? const <CheckInRow>[],
            localeTag: localeTag,
            timezone: ref.read(timeContextProvider).timezone,
          ),
        ),
        const SizedBox(height: AuraSpace.xl),
        _Padded(
          child: _PatternsSection(model: model, plus: plus, habits: habits),
        ),
        const SizedBox(height: AuraSpace.xl),
        _Padded(child: _Lifetime(model: model)),
        const SizedBox(height: AuraSpace.l),
        Center(
          child: OutlinedButton.icon(
            key: const ValueKey('insights-history'),
            onPressed: () => context.push(Routes.insightsHistory),
            icon: const Icon(Icons.list_alt_rounded),
            label: Text(l.insights_allCheckIns),
          ),
        ),
      ],
    );
  }
}

/// The list runs close to the edges so the sky's seven columns keep 48 dp
/// targets on narrow phones; text blocks get the rest of the page gutter.
class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AuraSpace.gutter - AuraSpace.m,
    ),
    child: child,
  );
}

class _PatternsSection extends ConsumerWidget {
  const _PatternsSection({
    required this.model,
    required this.plus,
    required this.habits,
  });

  final InsightsModel model;
  final bool plus;
  final Map<String, HabitRow> habits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final range = plus ? ref.watch(insightRangeProvider) : InsightRange.days30;
    final days = rangeDays(range, model.today, model.firstDay);
    final gate = patternGate(model.checkIns, days);
    final patterns = gate.passes
        ? findPatterns(
            checkIns: model.checkIns,
            habitLogs: model.habitLogs,
            range: days,
            includeHabits: plus,
          )
        : const <InsightPattern>[];

    final Widget body = switch (gate.status) {
      PatternGateStatus.needCheckIns => _Note(
        l.insights_patternsNeedCheckIns(gate.checkIns),
        key: const ValueKey('insights-patterns-gate'),
      ),
      PatternGateStatus.needDays => _Note(
        l.insights_patternsNeedDays(gate.days),
        key: const ValueKey('insights-patterns-gate'),
      ),
      PatternGateStatus.ok when patterns.isEmpty => _Note(
        l.insights_patternsNone,
        key: const ValueKey('insights-patterns-none'),
      ),
      PatternGateStatus.ok => Column(
        key: const ValueKey('insights-patterns'),
        children: [
          for (final p in patterns.take(InsightsScreen.maxPatterns))
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s),
              child: InsightCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.l,
                  vertical: AuraSpace.m,
                ),
                child: Row(
                  children: [
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.auto_awesome_outlined,
                        size: 18,
                        color: AuraColors.starlight,
                      ),
                    ),
                    const SizedBox(width: AuraSpace.m),
                    Expanded(
                      child: Text(
                        patternSentence(l, p, habits: habits),
                        style: t.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.insights_patternsTitle, style: t.titleMedium),
        ),
        const SizedBox(height: AuraSpace.xs),
        if (plus)
          _RangePicker(selected: range)
        else
          Text(
            l.insights_patternsLast30,
            style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
          ),
        const SizedBox(height: AuraSpace.m),
        body,
        if (!plus) ...[
          const SizedBox(height: AuraSpace.s),
          PlusLocked(message: l.insights_rangeLocked),
        ],
      ],
    );
  }
}

class _RangePicker extends ConsumerWidget {
  const _RangePicker({required this.selected});

  final InsightRange selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    String label(InsightRange r) => switch (r) {
      InsightRange.days7 => l.insights_range7,
      InsightRange.days30 => l.insights_range30,
      InsightRange.days90 => l.insights_range90,
      InsightRange.days365 => l.insights_range365,
      InsightRange.all => l.insights_rangeAll,
    };
    return Semantics(
      label: l.insights_rangeLabel,
      container: true,
      child: Wrap(
        key: const ValueKey('insights-range'),
        spacing: AuraSpace.s,
        runSpacing: AuraSpace.s,
        children: [
          for (final r in InsightRange.values)
            ChoiceChip(
              key: ValueKey('insights-range-${r.name}'),
              label: Text(label(r)),
              selected: r == selected,
              onSelected: (_) => ref.read(insightRangeProvider.notifier).set(r),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: AuraColors.textSoft),
  );
}

/// Lifetime stats (free): check-ins, days in the sky, glow days.
class _Lifetime extends ConsumerWidget {
  const _Lifetime({required this.model});

  final InsightsModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final glow = ref.watch(
      progressViewProvider.select((v) => v.streak.lifetimeGlowDays),
    );
    final style = t.bodyMedium?.copyWith(color: AuraColors.textSoft);
    return Column(
      key: const ValueKey('insights-lifetime'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l.insights_statsTitle, style: t.titleMedium),
        ),
        const SizedBox(height: AuraSpace.s),
        Text(l.insights_statsCheckIns(model.checkIns.length), style: style),
        Text(l.insights_statsDays(model.byDay.length), style: style),
        Text(l.home_lifetimeGlow(glow), style: style),
      ],
    );
  }
}
