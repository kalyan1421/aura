import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../avatar/aura_avatar.dart';
import '../avatar/moments_controller.dart';
import '../checkin/quadrant_glyph.dart';
import '../habits/habit_repository.dart';
import '../progress/progress_view.dart';
import '../support/support_sheet.dart';

part 'home_screen.g.dart';

@riverpod
Stream<List<HabitToday>> habitsToday(Ref ref) {
  final day = ref.watch(progressViewProvider.select((v) => v.today));
  return ref.watch(habitRepositoryProvider).watchToday(day);
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final view = ref.watch(progressViewProvider);
    final moment = ref.watch(momentsControllerProvider);
    final hue = glowColorForHue(view.avatar.hue);

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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.gutter,
                    0,
                    AuraSpace.gutter,
                    AuraSpace.xl,
                  ),
                  children: [
                    Center(
                      child: AuraAvatar(
                        state: view.avatar,
                        size: const Size(340, 330),
                        moment: moment,
                        onMomentDone: (m) => ref
                            .read(momentsControllerProvider.notifier)
                            .markPlayed(m),
                      ),
                    ),
                    _StatusLine(view: view, moment: moment),
                    const SizedBox(height: AuraSpace.l),
                    _StarlightRow(view: view),
                    const SizedBox(height: AuraSpace.m),
                    _GlowCard(view: view),
                    const SizedBox(height: AuraSpace.xl),
                    Text(l.home_habitsTitle, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AuraSpace.m),
                    const _Habits(),
                  ],
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
          const _SyncIndicator(),
          IconButton(
            tooltip: l.home_settings,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
    );
  }
}

class _SyncIndicator extends ConsumerWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sync = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    return ValueListenableBuilder<SyncPhase>(
      valueListenable: sync.phase,
      builder: (context, phase, _) {
        final local = phase == SyncPhase.offline ||
            phase == SyncPhase.unavailable ||
            phase == SyncPhase.signedOut;
        final (icon, label) = local
            ? (Icons.cloud_off_outlined, l.home_syncLocal)
            : pending > 0
            ? (Icons.cloud_upload_outlined, l.home_syncPending(pending))
            : (Icons.cloud_done_outlined, l.home_syncIdle);
        return Tooltip(
          message: label,
          child: Semantics(
            label: label,
            child: SizedBox(
              width: 44,
              height: 48,
              child: Icon(icon, size: 20, color: AuraColors.textMuted),
            ),
          ),
        );
      },
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
      padding: const EdgeInsets.fromLTRB(AuraSpace.gutter, 6, AuraSpace.gutter, 0),
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
          onPressed: () => context.push('/sign-in'),
          child: Text(l.home_signIn),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

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
      AvatarMomentKind.evolve => l.home_evolved(stageName(l, view.avatar.stage)),
      _ => !view.loaded
          ? null
          : view.avatar.isResting
          ? l.home_resting
          : !view.hasActivity
          ? l.home_empty
          : null,
    };
    return AnimatedSwitcher(
      duration: AuraMotion.calm,
      child: text == null
          ? const SizedBox(height: 4)
          : Padding(
              key: ValueKey(text),
              padding: const EdgeInsets.symmetric(horizontal: AuraSpace.l),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
              ),
            ),
    );
  }
}

class _StarlightRow extends StatelessWidget {
  const _StarlightRow({required this.view});

  final ProgressView view;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AuraSpace.m,
        runSpacing: 4,
        children: [
          Text(
            stageName(l, view.avatar.stage),
            style: t.titleMedium?.copyWith(color: AuraColors.lavender),
          ),
          const Text('·', style: TextStyle(color: AuraColors.textMuted)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: AuraColors.starlight),
              const SizedBox(width: 4),
              Text(
                l.home_todayStarlight(view.todayStarlight),
                style: t.titleSmall?.copyWith(color: AuraColors.starlight),
              ),
            ],
          ),
          const Text('·', style: TextStyle(color: AuraColors.textMuted)),
          Text(l.home_totalStarlight(view.totalStarlight), style: t.bodyMedium),
        ],
      ),
    );
  }
}

/// Glow streak and rest days. Never guilt: no countdowns, no red, no
/// "lost". During a covered gap: "Resting · your glow is safe".
class _GlowCard extends StatelessWidget {
  const _GlowCard({required this.view});

  final ProgressView view;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final s = view.streak;
    if (s.lifetimeGlowDays == 0) return const SizedBox.shrink();

    final restarted = view.glow == GlowStatus.activeToday &&
        s.glowStreak == 1 &&
        s.lifetimeGlowDays > 1;
    final String? note = switch (view.glow) {
      GlowStatus.restCovered => l.home_restingSafe,
      _ when restarted => l.home_glowCarriesOn,
      _ => null,
    };
    final showStreak = view.glow != GlowStatus.carriesOn;

    return Container(
      padding: const EdgeInsets.all(AuraSpace.l),
      decoration: BoxDecoration(
        color: AuraColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AuraRadius.l),
        border: Border.all(color: AuraColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showStreak)
            Row(
              children: [
                const Icon(Icons.local_fire_department_outlined,
                    size: 20, color: AuraColors.starlight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.home_glowStreak(s.glowStreak), style: t.titleMedium),
                ),
              ],
            ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note, style: t.bodyMedium?.copyWith(color: AuraColors.lavender)),
          ],
          const SizedBox(height: AuraSpace.s),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    i < s.restBank ? Icons.nightlight_round : Icons.nightlight_outlined,
                    size: 16,
                    color: i < s.restBank ? AuraColors.moonlight : AuraColors.outline,
                  ),
                ),
              const SizedBox(width: 6),
              Expanded(child: Text(l.home_restDays(s.restBank), style: t.bodySmall)),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.home_lifetimeGlow(s.lifetimeGlowDays), style: t.bodySmall),
        ],
      ),
    );
  }
}

class _Habits extends ConsumerWidget {
  const _Habits();

  static const Map<String, IconData> _icons = {
    'hydrate': Icons.local_drink_outlined,
    'sleep_on_time': Icons.bedtime_outlined,
    'move': Icons.directions_walk,
    'breathe': Icons.air,
    'journal': Icons.edit_note,
    'go_outside': Icons.park_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final habits = ref.watch(habitsTodayProvider).value ??
        [for (final p in presetHabits) HabitToday(preset: p, done: false)];
    return Wrap(
      spacing: AuraSpace.s,
      runSpacing: AuraSpace.s,
      children: [
        for (final h in habits)
          Semantics(
            label: h.done
                ? l.home_habitDone(habitLabel(l, h.preset.key))
                : l.home_habitNotYet(habitLabel(l, h.preset.key)),
            toggled: h.done,
            excludeSemantics: true,
            child: FilterChip(
              key: ValueKey('habit-${h.preset.key}'),
              avatar: Icon(
                h.done ? Icons.check_rounded : _icons[h.preset.key],
                size: 18,
                color: h.done ? AuraColors.onAccent : AuraColors.textSoft,
              ),
              label: Text(habitLabel(l, h.preset.key)),
              selected: h.done,
              selectedColor: AuraColors.starlight,
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: h.done ? AuraColors.onAccent : AuraColors.text,
              ),
              onSelected: (_) async {
                HapticFeedback.selectionClick();
                await ref.read(habitRepositoryProvider).toggleToday(h.preset.key);
                ref.read(syncControllerProvider).notifyLocalWrite();
              },
            ),
          ),
      ],
    );
  }
}

class _CheckInBar extends StatelessWidget {
  const _CheckInBar({required this.pulse});

  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget button = SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton.icon(
        key: const ValueKey('home-checkin'),
        onPressed: () => context.push('/checkin'),
        icon: const Icon(Icons.auto_awesome),
        label: Text(l.home_checkIn),
      ),
    );
    if (pulse) {
      // Pulses once for a new user (PRD States: Home empty).
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
