import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/prefs/comfort_prefs.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../account/account_providers.dart';
import '../account/deletion_pending.dart';
import '../avatar/aura_avatar.dart';
import '../avatar/moments_controller.dart';
import '../habits/habits_section.dart';
import '../progress/progress_view.dart';
import '../support/support_sheet.dart';
import 'rest_days_sheet.dart';
import 'sync_status_sheet.dart';

part 'home_screen.g.dart';

/// Check-ins saved on this phone for the current Aura day (deleted ones
/// excluded), for the history line.
@riverpod
int checkInsToday(Ref ref) {
  final today = ref.watch(progressViewProvider.select((v) => v.today));
  final events = ref.watch(progressEventsProvider).value ?? const [];
  return events
      .where(
        (e) =>
            e.kind == ProgressKind.checkIn && !e.deleted && e.localDay == today,
      )
      .length;
}

/// The avatar's height for a scroll viewport [available] dp tall: ≈ 40% of
/// it, within 200–340 dp, so the stats, glow card and first habits stay above
/// the fold on common phones (375×667, 390×844).
double homeAvatarHeight(double available) =>
    (available * 0.40).clamp(200.0, 340.0);

/// Painter aspect (width / height) the avatar art was composed for.
const double _avatarAspect = 340 / 330;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(progressViewProvider);
    final moment = ref.watch(momentsControllerProvider);
    final hue = glowColorForHue(view.avatar.hue);
    // A scheduled account deletion (sync saw `account_deletion_pending`):
    // "Keep my account?" right on Home, first in the scroll (REQ-ACC-11).
    final deletionHeld = ref.watch(deletionHoldProvider) != null;

    return Scaffold(
      body: CosmicBackground(
        tint: hue,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _TopBar(),
              const _Banners(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final h = homeAvatarHeight(box.maxHeight);
                    final w = math.min(
                      box.maxWidth - 2 * AuraSpace.gutter,
                      h * _avatarAspect,
                    );
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AuraSpace.gutter,
                        0,
                        AuraSpace.gutter,
                        AuraSpace.xl,
                      ),
                      children: [
                        if (deletionHeld) ...[
                          const SizedBox(height: AuraSpace.s),
                          const DeletionPendingCard(),
                          const SizedBox(height: AuraSpace.s),
                        ],
                        Center(
                          child: AuraAvatar(
                            key: const ValueKey('home-avatar'),
                            state: view.avatar,
                            size: Size(w, h),
                            moment: moment,
                            onMomentDone: (m) => ref
                                .read(momentsControllerProvider.notifier)
                                .markPlayed(m),
                          ),
                        ),
                        _StatusLine(view: view, moment: moment),
                        const SizedBox(height: AuraSpace.s),
                        _StarlightRow(view: view),
                        const _HistoryLine(),
                        const SizedBox(height: AuraSpace.xs),
                        _GlowCard(view: view),
                        const SizedBox(height: AuraSpace.l),
                        const HabitsSection(),
                      ],
                    );
                  },
                ),
              ),
              _CheckInBar(pulse: view.loaded && !view.hasActivity),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(AuraSpace.gutter, 6, 6, 0),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Text(
              'Aura',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.w300,
                color: AuraColors.lavender,
              ),
            ),
          ),
          const SizedBox(width: AuraSpace.s),
          // Within the first focus stops (REQ-A11Y-11). Flexible so large
          // text wraps the label instead of overflowing the bar.
          const Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: HelpNowButton(compact: true),
            ),
          ),
          const SyncIndicator(),
          IconButton(
            tooltip: l.home_settings,
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
    );
  }
}

class _Banners extends ConsumerWidget {
  const _Banners();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final online = ref.watch(connectivityProvider).value ?? true;
    final auth = ref.watch(authRepositoryProvider);
    final user = ref.watch(authUserProvider).value;
    final t = Theme.of(context).textTheme;

    Widget banner(IconData icon, String text, {Widget? action}) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        6,
        AuraSpace.gutter,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AuraColors.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AuraRadius.m),
          border: Border.all(color: AuraColors.hairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AuraColors.textSoft),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: t.bodySmall)),
            ?action,
          ],
        ),
      ),
    );

    if (!online) return banner(Icons.cloud_off_outlined, l.home_offline);
    if (auth.isAvailable && user == null) {
      return banner(
        Icons.lock_outline_rounded,
        l.home_finishSetup,
        action: TextButton(
          onPressed: () => context.push(Routes.signIn),
          child: Text(l.home_signIn),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// One calm line under the avatar (new user, resting, welcome back,
/// evolved). Takes no space when there is nothing to say.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.view, required this.moment});

  final ProgressView view;
  final AvatarMoment? moment;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final String? text = switch (moment?.kind) {
      AvatarMomentKind.wakeUp => l.home_welcomeBack,
      AvatarMomentKind.evolve => l.home_evolved(
        stageName(l, view.avatar.stage),
      ),
      _ =>
        !view.loaded
            ? null
            : view.avatar.isResting
            ? l.home_resting
            : !view.hasActivity
            ? l.home_empty
            : null,
    };
    return AnimatedSwitcher(
      // A plain crossfade; ≤ 300 ms under Reduce Motion.
      duration: reduceMotionOf(context) ? reducedMotionFade : AuraMotion.calm,
      child: text == null
          ? const SizedBox.shrink()
          : Padding(
              key: ValueKey(text),
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.l,
                AuraSpace.xs,
                AuraSpace.l,
                AuraSpace.s,
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
              ),
            ),
    );
  }
}

/// Stage name, a quiet thin bar toward the next stage (F2 thresholds from
/// aura_domain) and today's Starlight. At Constellation the bar becomes its
/// stars. No countdown or "N to go".
class _StarlightRow extends StatelessWidget {
  const _StarlightRow({required this.view});

  final ProgressView view;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final stage = stageName(l, view.avatar.stage);
    final progress = view.stageProgress;
    final stars = view.avatar.constellationStars;

    final Widget track = progress == null
        ? Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < maxConstellationStars; i++)
                Icon(
                  i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 14,
                  color: i < stars ? AuraColors.starlight : AuraColors.outline,
                ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  child: LinearProgressIndicator(
                    key: const ValueKey('home-stage-progress'),
                    value: progress.fraction,
                    minHeight: 4,
                    color: AuraColors.starlight,
                    backgroundColor: AuraColors.outline.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s),
              Text(
                stageName(l, progress.next),
                style: t.bodySmall?.copyWith(color: AuraColors.textMuted),
              ),
            ],
          );

    // One node: "Spark, 15 of 100 Starlight toward Ember" then today's
    // Starlight (the visible stage name and track are folded into it).
    return Semantics(
      container: true,
      label: progress == null
          ? l.home_constellationProgress(stage, stars, maxConstellationStars)
          : l.home_stageProgress(
              stage,
              stageName(l, progress.next),
              progress.total,
              progress.next.threshold,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AuraSpace.m,
            runSpacing: AuraSpace.xs,
            children: [
              ExcludeSemantics(
                child: Text(
                  stage,
                  style: t.titleMedium?.copyWith(color: AuraColors.lavender),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AuraColors.starlight,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      l.home_todayStarlight(view.todayStarlight),
                      style: t.titleSmall?.copyWith(
                        color: AuraColors.starlight,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s),
          ExcludeSemantics(child: track),
        ],
      ),
    );
  }
}

/// "2 check-ins today · See all" (or "Your check-ins") → check-in history.
class _HistoryLine extends ConsumerWidget {
  const _HistoryLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final count = ref.watch(checkInsTodayProvider);
    final link = t.labelLarge?.copyWith(color: AuraColors.lavender);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        child: InkWell(
          key: const ValueKey('home-history'),
          borderRadius: BorderRadius.circular(AuraRadius.s),
          onTap: () => context.push(Routes.history),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                0,
                4,
                AuraSpace.s,
                4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: AuraColors.textMuted,
                  ),
                  const SizedBox(width: AuraSpace.s),
                  Flexible(
                    child: count == 0
                        ? Text(l.home_yourCheckIns, style: link)
                        : Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AuraSpace.s,
                            children: [
                              Text(
                                l.home_checkInsToday(count),
                                style: t.bodyMedium,
                              ),
                              const ExcludeSemantics(
                                child: Text(
                                  '·',
                                  style: TextStyle(color: AuraColors.textMuted),
                                ),
                              ),
                              Text(l.home_seeAll, style: link),
                            ],
                          ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AuraColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glow streak and rest days. Never guilt: no countdowns, no red, no
/// "lost". During a covered gap: "Resting · your glow is safe". Honours
/// Settings → Hide streak number (F3): the number goes, lifetime glow days
/// and rest days stay. The rest-day row opens a short explainer.
class _GlowCard extends ConsumerWidget {
  const _GlowCard({required this.view});

  final ProgressView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final hideStreak = ref.watch(
      comfortControllerProvider.select((p) => p.hideStreak),
    );
    final s = view.streak;
    if (s.lifetimeGlowDays == 0) return const SizedBox.shrink();

    final restarted =
        view.glow == GlowStatus.activeToday &&
        s.glowStreak == 1 &&
        s.lifetimeGlowDays > 1;
    final String? note = switch (view.glow) {
      GlowStatus.restCovered => l.home_restingSafe,
      _ when restarted => l.home_glowCarriesOn,
      _ => null,
    };
    // No old number after a run ends, and none when hidden.
    final showStreak = view.glow != GlowStatus.carriesOn && !hideStreak;

    return Container(
      key: const ValueKey('home-glow-card'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AuraSpace.l,
        AuraSpace.m,
        AuraSpace.l,
        AuraSpace.m,
      ),
      decoration: BoxDecoration(
        color: AuraColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AuraRadius.l),
        border: Border.all(color: AuraColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 20,
                color: AuraColors.starlight,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  showStreak
                      ? l.home_glowStreak(s.glowStreak)
                      : l.home_glowTitle,
                  key: const ValueKey('home-glow-title'),
                  style: t.titleMedium,
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(
              note,
              style: t.bodyMedium?.copyWith(color: AuraColors.lavender),
            ),
          ],
          const SizedBox(height: AuraSpace.xs),
          Semantics(
            button: true,
            hint: l.home_restDaysHint,
            child: InkWell(
              key: const ValueKey('home-rest-days'),
              borderRadius: BorderRadius.circular(AuraRadius.s),
              onTap: () => showRestDaysSheet(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < maxRestBank; i++)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 4),
                              child: Icon(
                                i < s.restBank
                                    ? Icons.nightlight_round
                                    : Icons.nightlight_outlined,
                                size: 16,
                                color: i < s.restBank
                                    ? AuraColors.moonlight
                                    : AuraColors.outline,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.home_restDays(s.restBank),
                        style: t.bodySmall,
                      ),
                    ),
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AuraColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text(l.home_lifetimeGlow(s.lifetimeGlowDays), style: t.bodySmall),
        ],
      ),
    );
  }
}

class _CheckInBar extends StatelessWidget {
  const _CheckInBar({required this.pulse});

  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget button = ConstrainedBox(
      // Grows with large text instead of clipping the label.
      constraints: const BoxConstraints(
        minHeight: 60,
        minWidth: double.infinity,
      ),
      child: FilledButton.icon(
        key: const ValueKey('home-checkin'),
        onPressed: () => context.push(Routes.checkIn),
        icon: const Icon(Icons.auto_awesome),
        label: Text(l.home_checkIn, textAlign: TextAlign.center),
      ),
    );
    // Pulses once for a new user (PRD States: Home empty); never under
    // Reduce Motion (REQ-A11Y-08).
    if (pulse && !reduceMotionOf(context)) {
      button = button
          .animate(delay: 600.ms)
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.03, 1.03),
            duration: 450.ms,
            curve: Curves.easeInOut,
          )
          .then()
          .scale(
            begin: const Offset(1.03, 1.03),
            end: const Offset(1, 1),
            duration: 450.ms,
          );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.m,
        AuraSpace.gutter,
        AuraSpace.m + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AuraColors.skyDeep.withValues(alpha: 0), AuraColors.skyDeep],
        ),
      ),
      child: button,
    );
  }
}
