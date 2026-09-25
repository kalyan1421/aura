import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../../core/widgets/inline_notice.dart';
import '../rooms/room_copy.dart';
import '../rooms/room_guidelines.dart';
import '../rooms/room_models.dart' show GestureType;
import '../rooms/rooms_providers.dart' show roomsRepositoryProvider;
import '../sanctuary/calm_route.dart';
import '../sanctuary/sounds/sounds_controller.dart';
import '../support/support_sheet.dart';
import 'quiet_controller.dart';
import 'quiet_models.dart';
import 'quiet_providers.dart';
import 'quiet_report_sheet.dart';
import 'quiet_sound_card.dart';
import 'shared_sound.dart';

/// Opens a Quiet Together session above the shell.
Future<void> openQuiet(BuildContext context, QuietMode mode) =>
    pushCalm<void>(context, (_) => QuietScreen(mode: mode));

String quietTitle(AppLocalizations l, QuietMode m) => switch (m) {
  QuietMode.study => l.quiet_titleStudy,
  QuietMode.read => l.quiet_titleRead,
  QuietMode.rest => l.quiet_titleRest,
};

String quietMomentLine(AppLocalizations l, GestureType g) => switch (g) {
  GestureType.warmTea => l.quiet_moment_warm_tea,
  GestureType.lightACandle => l.quiet_moment_light_a_candle,
  GestureType.hug => l.quiet_moment_hug,
  GestureType.meToo => l.quiet_moment_me_too,
  GestureType.softRain => l.quiet_moment_soft_rain,
  GestureType.stargaze => l.quiet_moment_stargaze,
  GestureType.deepBreath => l.quiet_moment_deep_breath,
  GestureType.youreNotAlone => l.quiet_moment_youre_not_alone,
};

/// F16 Quiet Together (PRD 06b; 14-states "Quiet Together (F16)"): a count,
/// a shared sound and gestures, nothing else. No names, silhouettes, moods
/// or join/leave messages; no text input. "I need help now" stays in the top
/// bar for the whole session (REQ-A11Y-11); the session menu holds "Report a
/// problem here" and "Hide gestures" (for yourself). Leaving costs nothing.
class QuietScreen extends ConsumerStatefulWidget {
  const QuietScreen({
    super.key,
    required this.mode,
    this.wallMs,
    this.isOnline,
  });

  final QuietMode mode;

  /// The wall clock (tests pin it).
  final int Function()? wallMs;

  /// Connectivity (tests pin it); default: the app's connectivity stream.
  final bool Function()? isOnline;

  @override
  ConsumerState<QuietScreen> createState() => _QuietScreenState();
}

class _QuietScreenState extends ConsumerState<QuietScreen>
    with SingleTickerProviderStateMixin {
  late final QuietController _c;
  late final AnimationController _glow;
  late final SoundsController _sounds;
  bool _guidelinesAsked = false;
  int _seenCues = 0;
  String? _cueLine;

  int _wall() => widget.wallMs?.call() ?? DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
    _sounds = ref.read(soundsControllerProvider.notifier);
    _c = QuietController(
      api: ref.read(quietApiProvider),
      openChannel: ref.read(quietChannelOpenerProvider),
      mode: widget.mode,
      isOnline:
          widget.isOnline ?? () => ref.read(connectivityProvider).value ?? true,
      cues: ref.read(quietCuesProvider),
      timezone: () => ref.read(timeContextProvider).timezone,
      chimeAllowed: () {
        final s = ref.read(soundsControllerProvider);
        final id = _c.session?.sessionId;
        return id != null && s.shared == quietSoundKey(id) && s.isPlaying;
      },
      wallMs: _wall,
    );
    _c.onSessionChanged = _onSessionChanged;
    _c.addListener(_onChange);
    unawaited(_c.start());
  }

  /// A new block: the shared sound (if it plays) re-aligns to the new t0.
  void _onSessionChanged(QuietSession previous, QuietSession next) {
    final s = ref.read(soundsControllerProvider);
    if (s.shared == quietSoundKey(previous.sessionId) && !s.isIdle) {
      _sounds.startShared(quietSharedSound(next, _c.clock, _wall));
    }
  }

  void _onChange() {
    if (!mounted) return;
    if (_c.unavailable == QuietUnavailable.guidelines && !_guidelinesAsked) {
      _guidelinesAsked = true;
      unawaited(_guidelines());
    }
    if (_c.rhythmCues != _seenCues) {
      _seenCues = _c.rhythmCues;
      final l = AppLocalizations.of(context);
      _cueLine = (_c.rhythmNow?.onBreak ?? false)
          ? l.quiet_rhythmToBreak
          : l.quiet_rhythmToFocus;
    }
    setState(() {});
  }

  /// `409 guidelines_required`: the community guidelines first (once), then
  /// the same join again.
  Future<void> _guidelines() async {
    final agreed = await showRoomGuidelines(context);
    if (!mounted || !agreed) return;
    try {
      await ref
          .read(roomsRepositoryProvider)
          .acceptGuidelines(roomGuidelinesVersion);
      await cacheRoomGuidelines(
        ref.read(kvStoreProvider),
        roomGuidelinesVersion,
      );
      if (mounted) unawaited(_c.start());
    } on Object {
      // The notice stays; "Try again" repeats the join.
    }
  }

  @override
  void dispose() {
    final id = _c.session?.sessionId;
    // Leaving the screen is leaving: the shared sound stops with it (after
    // this frame: providers can't change while the tree is finalizing).
    if (id != null) {
      final sounds = _sounds;
      scheduleMicrotask(() {
        try {
          sounds.stopShared(quietSoundKey(id));
        } on Object {
          // The app is closing: nothing to stop.
        }
      });
    }
    _c.removeListener(_onChange);
    _c.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _leave() {
    _c.leave();
    Navigator.of(context).maybePop();
  }

  Future<void> _report() async {
    final outcome = await showQuietReportSheet(context, _c.report);
    if (!mounted || outcome == null) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(l.quiet_reportThanks),
        duration: const Duration(seconds: 5),
      ),
    );
    if (outcome.showHelplines) openSafetyCenter(context);
  }

  void _openSanctuary() {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).maybePop();
    router?.go(Routes.sanctuary);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityProvider, (prev, next) {
      final v = next.value;
      final was = prev?.value;
      // A real change only (not the first reading).
      if (v != null && was != null && v != was) _c.onConnectivity(v);
    });
    final l = AppLocalizations.of(context);
    final reduce = reduceMotionOf(context);
    if (reduce) {
      if (_glow.isAnimating) _glow.stop();
    } else if (!_glow.isAnimating) {
      unawaited(_glow.repeat(reverse: true));
    }
    return Scaffold(
      appBar: helpAppBar(context, title: quietTitle(l, widget.mode)),
      body: CosmicBackground(
        tint: AuraColors.moonlight,
        child: SafeArea(
          top: false,
          child: switch (_c.phase) {
            QuietPhase.joining => _joining(context),
            QuietPhase.unavailable => _unavailable(context),
            QuietPhase.here || QuietPhase.left => _here(context, reduce),
          },
        ),
      ),
    );
  }

  Widget _joining(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Text(l.quiet_joining, key: const ValueKey('quiet-joining')),
      ),
    );
  }

  Widget _unavailable(BuildContext context) {
    final l = AppLocalizations.of(context);
    final why = _c.unavailable ?? QuietUnavailable.failed;
    final text = switch (why) {
      QuietUnavailable.offline => l.quiet_offline,
      QuietUnavailable.paused => l.quiet_paused,
      QuietUnavailable.suspended => l.rooms_suspended,
      QuietUnavailable.closed => l.rooms_accountClosed,
      QuietUnavailable.signedOut => l.rooms_signedOut,
      QuietUnavailable.guidelines || QuietUnavailable.failed => l.quiet_failed,
    };
    final sanctuary =
        why == QuietUnavailable.offline || why == QuietUnavailable.paused;
    final retry =
        why == QuietUnavailable.offline ||
        why == QuietUnavailable.failed ||
        why == QuietUnavailable.guidelines;
    return ListView(
      padding: const EdgeInsets.all(AuraSpace.gutter),
      children: [
        InlineNotice(text, key: ValueKey('quiet-unavailable-${why.name}')),
        const SizedBox(height: AuraSpace.l),
        if (sanctuary)
          FilledButton(
            key: const ValueKey('quiet-open-sanctuary'),
            onPressed: _openSanctuary,
            child: Text(l.quiet_openSanctuary),
          ),
        if (retry)
          TextButton(
            key: const ValueKey('quiet-retry'),
            onPressed: () {
              if (why == QuietUnavailable.guidelines) {
                _guidelinesAsked = true;
                unawaited(_guidelines());
              } else {
                unawaited(_c.start());
              }
            },
            child: Text(l.quiet_tryAgain),
          ),
      ],
    );
  }

  Widget _here(BuildContext context, bool reduce) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final s = _c.session;
    if (s == null) return const SizedBox.shrink();
    final count = _c.count;
    return ListView(
      key: const ValueKey('quiet-session'),
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.s,
        AuraSpace.gutter,
        AuraSpace.xxl,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _c.linkLost
                  ? Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Chip(
                        key: const ValueKey('quiet-reconnecting'),
                        avatar: const Icon(
                          Icons.wifi_tethering_rounded,
                          size: 16,
                        ),
                        label: Text(l.quiet_reconnecting),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            _Menu(
              hidden: _c.hideGestures,
              onReport: _report,
              onToggleGestures: () => _c.setHideGestures(!_c.hideGestures),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.m),
        _Presence(glow: _glow, still: reduce),
        const SizedBox(height: AuraSpace.l),
        Semantics(
          liveRegion: true,
          container: true,
          child: Column(
            children: [
              Text(
                l.quiet_count(count),
                key: const ValueKey('quiet-count'),
                style: t.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (count <= 1)
                Padding(
                  padding: const EdgeInsets.only(top: AuraSpace.xs),
                  child: Text(
                    l.quiet_justYou,
                    key: const ValueKey('quiet-just-you'),
                    style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.m),
        _MomentLine(moment: _c.moment, hidden: _c.hideGestures, reduce: reduce),
        if (_c.hideGestures)
          Text(
            l.quiet_gesturesHidden,
            key: const ValueKey('quiet-gestures-hidden'),
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
          ),
        if (_c.nearBlockEnd)
          Padding(
            padding: const EdgeInsets.only(top: AuraSpace.s),
            child: Text(
              l.quiet_nextBlock(roomTime(context, _local(s.endsAtMs))),
              key: const ValueKey('quiet-next-block'),
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
            ),
          ),
        const SizedBox(height: AuraSpace.xl),
        SharedSoundCard(
          soundKey: quietSoundKey(s.sessionId),
          stemIds: [for (final x in s.stems) x.id],
          build: () => quietSharedSound(s, _c.clock, _wall),
        ),
        if (s.rhythm != null) ...[
          const SizedBox(height: AuraSpace.l),
          _Rhythm(
            on: _c.rhythmOn,
            moment: _c.rhythmNow,
            cueLine: _cueLine,
            at: (ms) => roomTime(context, _local(ms)),
            onChanged: (v) {
              _cueLine = null;
              _c.setRhythm(v);
            },
          ),
        ],
        const SizedBox(height: AuraSpace.l),
        _GestureTray(
          enabled: !_c.coolingDown && _c.phase == QuietPhase.here,
          onSend: _c.sendGesture,
        ),
        const SizedBox(height: AuraSpace.xl),
        OutlinedButton(
          key: const ValueKey('quiet-leave'),
          onPressed: _leave,
          child: Text(l.quiet_leave),
        ),
        const SizedBox(height: AuraSpace.xs),
        Text(
          l.quiet_leaveNote,
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
        ),
      ],
    );
  }

  /// A server-clock instant as this phone's local time.
  DateTime _local(int serverMs) =>
      DateTime.fromMillisecondsSinceEpoch(serverMs - _c.clock.offsetMs);
}

/// The session menu: "Report a problem here" and "Hide gestures" (for you).
class _Menu extends StatelessWidget {
  const _Menu({
    required this.hidden,
    required this.onReport,
    required this.onToggleGestures,
  });

  final bool hidden;
  final VoidCallback onReport;
  final VoidCallback onToggleGestures;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<int>(
      key: const ValueKey('quiet-menu'),
      tooltip: l.quiet_menu,
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (v) => v == 0 ? onReport() : onToggleGestures(),
      itemBuilder: (_) => [
        PopupMenuItem(
          key: const ValueKey('quiet-menu-report'),
          value: 0,
          child: Text(l.quiet_report),
        ),
        PopupMenuItem(
          key: const ValueKey('quiet-menu-gestures'),
          value: 1,
          child: Text(hidden ? l.quiet_showGestures : l.quiet_hideGestures),
        ),
      ],
    );
  }
}

/// A soft, slow glow: company without faces. Holds still under Reduce
/// Motion (REQ-A11Y-16). Decorative (hidden from screen readers).
class _Presence extends StatelessWidget {
  const _Presence({required this.glow, required this.still});

  final Animation<double> glow;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 160,
        child: Center(
          child: AnimatedBuilder(
            animation: glow,
            builder: (context, _) {
              final v = still ? 0.5 : glow.value;
              final size = 120 + 18 * v;
              return Container(
                key: const ValueKey('quiet-presence'),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AuraColors.starlight.withValues(alpha: 0.55 + 0.2 * v),
                      AuraColors.moonlight.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The latest gesture: "Someone lit a candle" (never who). A polite live
/// region; under Reduce Motion a still line with a ≤ 300 ms crossfade.
class _MomentLine extends StatelessWidget {
  const _MomentLine({
    required this.moment,
    required this.hidden,
    required this.reduce,
  });

  final QuietMoment? moment;
  final bool hidden;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final m = moment;
    final Widget child;
    if (m == null || hidden) {
      child = const SizedBox(key: ValueKey('quiet-moment-none'), height: 24);
    } else {
      final line = m.mine
          ? l.quiet_gestureSent(gestureName(l, m.type))
          : quietMomentLine(l, m.type);
      child = Row(
        key: ValueKey('quiet-moment-${m.serial}'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Icon(
              gestureIcon(m.type),
              size: 18,
              color: AuraColors.starlight,
            ),
          ),
          const SizedBox(width: AuraSpace.s),
          Flexible(
            child: Text(
              line,
              style: t.bodyMedium?.copyWith(color: AuraColors.starlight),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return Semantics(
      liveRegion: true,
      container: true,
      child: AnimatedSwitcher(
        duration: reduce ? reducedMotionFade : AuraMotion.calm,
        transitionBuilder: (c, a) => reduce
            ? FadeTransition(opacity: a, child: c)
            : FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(a),
                  child: c,
                ),
              ),
        child: child,
      ),
    );
  }
}

/// The optional 25/5 focus rhythm (Study; REQ-QUIET-05): off by default; when
/// on, the next change as a clock time ("Break at 9:25"), never a countdown.
class _Rhythm extends StatelessWidget {
  const _Rhythm({
    required this.on,
    required this.moment,
    required this.cueLine,
    required this.at,
    required this.onChanged,
  });

  final bool on;
  final RhythmMoment? moment;
  final String? cueLine;
  final String Function(int serverMs) at;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final m = moment;
    return Material(
      color: AuraColors.surface.withValues(alpha: 0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuraRadius.l),
        side: const BorderSide(color: AuraColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            key: const ValueKey('quiet-rhythm-switch'),
            value: on,
            onChanged: onChanged,
            title: Text(l.quiet_rhythm),
            subtitle: Text(l.quiet_rhythmBody),
          ),
          if (on && m != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.l,
                0,
                AuraSpace.l,
                AuraSpace.s,
              ),
              child: Semantics(
                liveRegion: true,
                container: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cueLine != null)
                      Text(
                        cueLine!,
                        key: const ValueKey('quiet-rhythm-cue'),
                        style: t.titleSmall,
                      ),
                    Text(
                      m.onBreak
                          ? l.quiet_rhythmBreak(at(m.nextChangeMs))
                          : l.quiet_rhythmFocus(at(m.nextChangeMs)),
                      key: const ValueKey('quiet-rhythm-line'),
                      style: t.bodyMedium?.copyWith(
                        color: m.onBreak
                            ? AuraColors.rain
                            : AuraColors.lavender,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The 8 F5 presets, to the whole session (never to a person, no text).
class _GestureTray extends StatelessWidget {
  const _GestureTray({required this.enabled, required this.onSend});

  final bool enabled;
  final ValueChanged<GestureType> onSend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.quiet_gesturesTitle, style: t.titleSmall),
        ),
        const SizedBox(height: AuraSpace.s),
        Wrap(
          spacing: AuraSpace.s,
          runSpacing: AuraSpace.s,
          children: [
            for (final g in GestureType.values)
              ActionChip(
                key: ValueKey('quiet-gesture-${g.wire}'),
                avatar: Icon(gestureIcon(g), size: 18),
                label: Text(gestureName(l, g)),
                onPressed: enabled ? () => onSend(g) : null,
              ),
          ],
        ),
      ],
    );
  }
}
