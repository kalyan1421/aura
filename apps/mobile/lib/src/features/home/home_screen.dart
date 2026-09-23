import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../capsules/capsule_ready_card.dart';
import '../avatar/moments_controller.dart';
import '../habits/habits_section.dart';
import '../progress/progress_view.dart';
import '../rooms/your_rooms_strip.dart';
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

/// The avatar never grows past this, however much room is left.
const double homeAvatarMax = 340;

/// The smallest avatar on common phones (390×844, 402×874 and taller):
/// when the content below needs more room than that leaves, Home scrolls
/// instead of the hero shrinking further.
const double homeAvatarFloor = 180;

/// The smallest avatar on short screens (< 700 dp tall, e.g. 375×667),
/// where at least the first habit row still sits above the fold.
const double homeAvatarFloorCompact = 140;

/// The avatar's height in a scroll viewport [viewport] dp tall when the
/// content under it (status line, stats, history line, glow card, habits)
/// needs [below] dp: everything that is left above the check-in bar, never
/// under [floor] (then Home scrolls) nor over [homeAvatarMax]. No extra gap
/// above the bar: the last chip row's 48 dp tap targets already keep its
/// pills clear of it.
double homeAvatarHeight({
  required double viewport,
  required double below,
  double floor = homeAvatarFloor,
}) => (viewport - below).clamp(floor, homeAvatarMax);

/// Screens shorter than this (iPhone SE, small Android phones) get tighter
/// spacing, a slimmer check-in bar and the smaller avatar floor.
const double _shortScreen = 700;

/// Painter aspect (width / height) the avatar art was composed for.
const double _avatarAspect = 340 / 330;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final view = ref.watch(progressViewProvider);
    final moment = ref.watch(momentsControllerProvider);
    final hue = glowColorForHue(view.avatar.hue);
    // A scheduled account deletion (sync saw `account_deletion_pending`):
    // "Keep my account?" right on Home, first in the scroll (REQ-ACC-11).
    // It sits above the fitted hero, so Home scrolls while it shows.
    final deletionHeld = ref.watch(deletionHoldProvider) != null;
    final compact = MediaQuery.sizeOf(context).height < _shortScreen;

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
                  builder: (context, box) => ListView(
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
                      // F4: a date capsule is ready (nothing when none is).
                      const CapsuleReadyCard(),
                      _HeroFit(
                        viewport: box.maxHeight,
                        floor: compact
                            ? homeAvatarFloorCompact
                            : homeAvatarFloor,
                        fitStatus: _StatusLine.steadyText(l, view) != null,
                        avatar: LayoutBuilder(
                          builder: (context, fit) => AuraAvatar(
                            key: const ValueKey('home-avatar'),
                            state: view.avatar,
                            size: fit.biggest,
                            moment: moment,
                            onMomentDone: (m) => ref
                                .read(momentsControllerProvider.notifier)
                                .markPlayed(m),
                          ),
                        ),
                        status: _StatusLine(view: view, moment: moment),
                        below: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: compact ? AuraSpace.xs : AuraSpace.s,
                            ),
                            _StarlightRow(view: view),
                            const _HistoryLine(),
                            // F5: rooms to return to (nothing when none).
                            const YourRoomsStrip(),
                            const SizedBox(height: AuraSpace.xs),
                            _GlowCard(view: view, compact: compact),
                            SizedBox(
                              height: compact ? AuraSpace.s : AuraSpace.l,
                            ),
                            const HabitsSection(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _CheckInBar(
                pulse: view.loaded && !view.hasActivity,
                compact: compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home's avatar and everything under it, in one box. The content below is
/// laid out first, at the real width, text scale and language; the avatar
/// then gets what is left of [viewport] ([homeAvatarHeight]). So on common
/// phones the stats, glow card and every habit row sit above the check-in
/// bar without scrolling, and the avatar stays the hero. Children, top to
/// bottom: avatar (tight size, centred), status line, the rest.
class _HeroFit extends MultiChildRenderObjectWidget {
  _HeroFit({
    required this.viewport,
    required this.floor,
    required this.fitStatus,
    required Widget avatar,
    required Widget status,
    required Widget below,
  }) : super(children: [avatar, status, below]);

  /// Height of the scroll viewport between the top bar and the check-in bar.
  final double viewport;

  /// The avatar's minimum height.
  final double floor;

  /// Whether the status line's height counts. Only a steady line (new user,
  /// resting) does: a moment's line is brief, so it nudges the content down
  /// for a moment rather than resizing the avatar mid-moment.
  final bool fitStatus;

  @override
  _RenderHeroFit createRenderObject(BuildContext context) =>
      _RenderHeroFit(viewport: viewport, floor: floor, fitStatus: fitStatus);

  @override
  void updateRenderObject(BuildContext context, _RenderHeroFit renderObject) {
    renderObject
      ..viewport = viewport
      ..floor = floor
      ..fitStatus = fitStatus;
  }
}

class _HeroFitParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderHeroFit extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeroFitParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeroFitParentData> {
  _RenderHeroFit({
    required this._viewport,
    required this._floor,
    required this._fitStatus,
  });

  double _viewport;
  set viewport(double value) {
    if (value == _viewport) return;
    _viewport = value;
    markNeedsLayout();
  }

  double _floor;
  set floor(double value) {
    if (value == _floor) return;
    _floor = value;
    markNeedsLayout();
  }

  bool _fitStatus;
  set fitStatus(bool value) {
    if (value == _fitStatus) return;
    _fitStatus = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeroFitParentData) {
      child.parentData = _HeroFitParentData();
    }
  }

  /// Sizes the three children with [layoutChild] (a real or a dry layout)
  /// and returns this box's size.
  Size _fit(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layoutChild,
  ) {
    assert(constraints.hasBoundedWidth);
    assert(childCount == 3);
    final avatar = firstChild!;
    final status = childAfter(avatar)!;
    final below = childAfter(status)!;
    final width = constraints.maxWidth;
    final rows = BoxConstraints.tightFor(width: width);
    final statusHeight = layoutChild(status, rows).height;
    final belowHeight = layoutChild(below, rows).height;
    final h = homeAvatarHeight(
      viewport: _viewport,
      below: belowHeight + (_fitStatus ? statusHeight : 0),
      floor: _floor,
    );
    layoutChild(
      avatar,
      BoxConstraints.tight(Size(math.min(width, h * _avatarAspect), h)),
    );
    return constraints.constrain(Size(width, h + statusHeight + belowHeight));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => _fit(
    constraints,
    // The avatar's constraints are tight: its size is known without it.
    (child, c) => c.isTight ? c.smallest : child.getDryLayout(c),
  );

  @override
  void performLayout() {
    size = _fit(constraints, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    var y = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      (child.parentData! as _HeroFitParentData).offset = Offset(
        (size.width - child.size.width) / 2,
        y,
      );
      y += child.size.height;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  /// The sync and settings icon buttons.
  static const double _icons = 2 * kMinInteractiveDimension;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final wordmarkStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      letterSpacing: 2,
      fontWeight: FontWeight.w300,
      color: AuraColors.lavender,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(AuraSpace.gutter, 6, 6, 0),
      child: LayoutBuilder(
        builder: (context, box) {
          // The wordmark is decorative: it steps aside whenever "I need
          // help now" would otherwise have to wrap next to it (small
          // phones, large text, longer languages).
          final wordmark = TextPainter(
            text: TextSpan(text: 'Aura', style: wordmarkStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final showWordmark =
              wordmark.width +
                  AuraSpace.s +
                  HelpNowButton.oneLineWidth(context, compact: true) +
                  _icons <=
              box.maxWidth;
          wordmark.dispose();
          return Row(
            children: [
              if (showWordmark) ...[
                ExcludeSemantics(
                  child: Text(
                    'Aura',
                    key: const ValueKey('home-wordmark'),
                    style: wordmarkStyle,
                  ),
                ),
                const SizedBox(width: AuraSpace.s),
              ],
              // Within the first focus stops (REQ-A11Y-11). Flexible so
              // large text wraps the label instead of overflowing the bar.
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
          );
        },
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

  /// The line while no moment plays: new user or resting, else null.
  static String? steadyText(AppLocalizations l, ProgressView view) =>
      !view.loaded
      ? null
      : view.avatar.isResting
      ? l.home_resting
      : !view.hasActivity
      ? l.home_empty
      : null;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final String? text = switch (moment?.kind) {
      AvatarMomentKind.wakeUp => l.home_welcomeBack,
      AvatarMomentKind.evolve => l.home_evolved(
        stageName(l, view.avatar.stage),
      ),
      _ => steadyText(l, view),
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
  const _GlowCard({required this.view, this.compact = false});

  final ProgressView view;

  /// Short screens: tighter top and bottom padding.
  final bool compact;

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
      padding: EdgeInsetsDirectional.fromSTEB(
        AuraSpace.l,
        compact ? AuraSpace.s : AuraSpace.m,
        AuraSpace.l,
        compact ? AuraSpace.s : AuraSpace.m,
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
  const _CheckInBar({required this.pulse, this.compact = false});

  final bool pulse;

  /// Short screens: the filled-button minimum (56) and tighter padding.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pad = compact ? AuraSpace.s : AuraSpace.m;
    Widget button = ConstrainedBox(
      // Grows with large text instead of clipping the label.
      constraints: BoxConstraints(
        minHeight: compact ? 56 : 60,
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
        pad,
        AuraSpace.gutter,
        pad + MediaQuery.paddingOf(context).bottom,
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
