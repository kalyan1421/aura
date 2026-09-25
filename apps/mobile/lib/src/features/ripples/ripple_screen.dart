import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aura_tokens.dart';
import '../avatar/aura_avatar.dart' show FrameBudget;
import '../avatar/aura_avatar_painter.dart' show AvatarTier;
import '../sanctuary/breath_pacer.dart';
import '../sanctuary/breathe_session_screen.dart';
import '../sanctuary/calm_route.dart';
import '../sanctuary/habit_auto_complete.dart';
import '../support/support_sheet.dart' show HelpNowButton;
import '../rooms/gesture_tray.dart';
import '../rooms/room_copy.dart' show gestureIcon;
import '../rooms/room_models.dart' show GestureType;
import 'ocean_painter.dart';
import 'ripple_controller.dart';
import 'ripple_engine.dart';
import 'ripple_feedback.dart';
import 'ripple_models.dart';
import 'ripple_seat_sheet.dart';
import 'ripples_providers.dart';

/// Opens Breath Ripples full screen, above the tab bar.
Future<void> openRipples(
  BuildContext context, {
  RippleEntry entry = RippleEntry.quick,
  String? roomId,
}) =>
    pushCalm<void>(context, (_) => RippleScreen(entry: entry, roomId: roomId));

/// F7 Breath Ripples: lobby → a 3-minute co-breath on a procedural night
/// ocean → the end screen (PRD 06b F7, 14 "Breath Ripples lobby and
/// session"). No score, number, countdown, leaderboard, voice or text chat.
/// "I need help now" sits top-right for the whole session; leaving is silent;
/// a lost connection keeps the session going on this phone.
class RippleScreen extends ConsumerStatefulWidget {
  const RippleScreen({
    super.key,
    this.entry = RippleEntry.quick,
    this.roomId,
    this.wallMs,
    this.onFeelNow,
    this.isOnline,
  });

  final RippleEntry entry;
  final String? roomId;

  /// The wall clock (tests pin it).
  final int Function()? wallMs;

  /// "How do you feel now?" (defaults to the check-in route).
  final VoidCallback? onFeelNow;

  /// Connectivity (defaults to the app's; tests pin it).
  final bool Function()? isOnline;

  @override
  ConsumerState<RippleScreen> createState() => _RippleScreenState();
}

class _RippleScreenState extends ConsumerState<RippleScreen>
    with SingleTickerProviderStateMixin {
  late final RippleController _c;
  late final Ticker _ticker = createTicker(_c.advance);
  AvatarTier _tier = AvatarTier.high;
  bool? _accessibleSet;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _c = RippleController(
      api: ref.read(ripplesApiProvider),
      openChannel: ref.read(rippleChannelOpenerProvider),
      entry: widget.entry,
      roomId: widget.roomId,
      newTicketId: ref.read(idsProvider).v7,
      isOnline:
          widget.isOnline ?? () => ref.read(connectivityProvider).value ?? true,
      wallMs: widget.wallMs ?? () => DateTime.now().millisecondsSinceEpoch,
      feedback: ref.read(rippleFeedbackProvider),
      onBreatheHabit: () =>
          autoCompleteHabitToday(ref, PresetHabitKeys.breathe),
    );
    _c.addListener(_changed);
    FrameBudget.instance.ensureStarted();
    FrameBudget.instance.overBudget.addListener(_budget);
    _ticker.start();
    unawaited(_c.start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveTier();
    // Accessible mode switches itself on with a screen reader (REQ-A11Y-07).
    if (_accessibleSet == null && MediaQuery.accessibleNavigationOf(context)) {
      _c.accessibleMode = true;
    }
  }

  void _budget() => setState(_resolveTier);

  void _resolveTier() {
    _tier = reduceMotionOf(context)
        ? AvatarTier.still
        : FrameBudget.instance.overBudget.value
        ? AvatarTier.low
        : AvatarTier.high;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FrameBudget.instance.overBudget.removeListener(_budget);
    _c.removeListener(_changed);
    if (!_left) unawaited(_c.leave()); // back gesture: the same silent leave
    _ticker.dispose();
    _c.dispose();
    super.dispose();
  }

  // ---- actions ----------------------------------------------------------------------
  Future<void> _close() async {
    _left = true;
    unawaited(_c.leave());
    if (mounted) await Navigator.of(context).maybePop();
  }

  void _again() {
    _left = true;
    Navigator.of(context).pushReplacement(
      calmRoute<void>(
        context,
        (_) => RippleScreen(
          entry: widget.entry,
          roomId: widget.roomId,
          wallMs: widget.wallMs,
          onFeelNow: widget.onFeelNow,
        ),
      ),
    );
  }

  void _solo() {
    _left = true;
    Navigator.of(context).pushReplacement(
      calmRoute<void>(context, (_) => const BreatheSessionScreen()),
    );
  }

  void _feelNow() {
    _left = true;
    final cb = widget.onFeelNow;
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).maybePop();
    if (cb != null) {
      cb();
    } else {
      router?.push<void>(Routes.checkIn);
    }
  }

  Future<void> _tapLight(LightView v) async {
    final l = AppLocalizations.of(context);
    if (v.me || v.kind != SeatKind.human || v.label == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final r = await showSeatSheet(
      context,
      controller: _c,
      seat: v.seat,
      name: v.label!,
    );
    if (!mounted || r == null) return;
    switch (r) {
      case SeatSheetResult.blocked:
        messenger?.showSnackBar(SnackBar(content: Text(l.ripples_blocked)));
      case SeatSheetResult.reported:
        messenger?.showSnackBar(SnackBar(content: Text(l.ripples_reported)));
      case SeatSheetResult.helpNow:
        unawaited(GoRouter.maybeOf(context)?.push<void>(Routes.safety));
      case SeatSheetResult.muted || SeatSheetResult.unmuted:
        break;
    }
  }

  // ---- copy ---------------------------------------------------------------------------
  String _phaseWord(AppLocalizations l) {
    if (_c.phase == RipplePhase.playing) {
      switch (_c.stage) {
        case RippleStage.settle:
          return l.ripples_settle;
        case RippleStage.fade || RippleStage.done:
          return l.ripples_fade;
        case RippleStage.breathing:
          break;
      }
    }
    return _c.moment.phase == BreathPhase.inhale ? l.breathe_in : l.breathe_out;
  }

  String _lightLabel(AppLocalizations l, LightView v) {
    if (v.me) return l.ripples_lightMe;
    return switch (v.mode) {
      LightMode.echo => l.ripples_lightEcho,
      LightMode.guide => l.ripples_lightGuide,
      _ => l.ripples_lightHuman(v.label ?? ''),
    };
  }

  /// The short name drawn under a light, or null (other people's lights
  /// carry no visible name).
  String? _shortLightName(AppLocalizations l, LightView v) => v.me
      ? l.ripples_you
      : switch (v.mode) {
          LightMode.echo => l.ripples_echo,
          LightMode.guide => l.ripples_guide,
          _ => null,
        };

  static String gestureName(AppLocalizations l, RippleGesture g) => switch (g) {
    RippleGesture.hug => l.ripples_gestureHug,
    RippleGesture.deepBreath => l.ripples_gestureDeepBreath,
    RippleGesture.youreNotAlone => l.ripples_gestureNotAlone,
  };

  List<String> _intro(AppLocalizations l) {
    final s = _c.session;
    if (s == null) return const [];
    return [
      if (s.humans > 1) l.ripples_together(s.humans),
      if (s.echoes > 0) l.ripples_echoesJoined(s.echoes),
      if (s.guides > 0) l.ripples_guides(s.guides),
      if (s.humans == 1 && s.echoes == 0 && s.guides == 0) l.ripples_solo,
    ];
  }

  // ---- view ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AuraColors.skyDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            label: l.ripples_oceanSemantic(_c.lights().length),
            image: true,
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  key: ValueKey('ripple-ocean-${_tier.name}'),
                  painter: OceanPainter(
                    lights: _c.lights,
                    sync: () => _c.sync,
                    timeMs: () => _c.elapsedMs,
                    tier: _tier,
                    repaint: _c.frame,
                  ),
                ),
              ),
            ),
          ),
          if (_c.phase == RipplePhase.playing || _c.phase == RipplePhase.lobby)
            _lightTargets(l),
          SafeArea(
            child: Column(
              children: [
                _topBar(l),
                Expanded(
                  child: switch (_c.phase) {
                    RipplePhase.unavailable => _unavailable(l),
                    RipplePhase.ended => _ended(l),
                    _ => _session(l),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(AppLocalizations l) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 0),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('ripple-close'),
          tooltip: _c.phase == RipplePhase.ended
              ? l.common_close
              : l.ripples_leave,
          onPressed: _close,
          icon: const Icon(Icons.close_rounded),
        ),
        if (_c.phase == RipplePhase.playing || _c.phase == RipplePhase.lobby)
          Semantics(
            toggled: _c.accessibleMode,
            child: IconButton(
              key: const ValueKey('ripple-accessible'),
              tooltip: l.ripples_accessibleMode,
              isSelected: _c.accessibleMode,
              onPressed: () {
                _accessibleSet = true;
                setState(() => _c.accessibleMode = !_c.accessibleMode);
              },
              icon: const Icon(Icons.accessibility_new_rounded),
            ),
          ),
        const Spacer(),
        // "I need help now": top-right, the whole session (PRD 06b HUD).
        const Flexible(
          flex: 3,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: HelpNowButton(compact: true),
          ),
        ),
      ],
    ),
  );

  Widget _session(AppLocalizations l) {
    final t = Theme.of(context).textTheme;
    final lobby = _c.phase == RipplePhase.lobby;
    final settle = !lobby && _c.stage == RippleStage.settle;
    final lines = <String>[
      if (lobby) l.ripples_lobby,
      if (settle) ..._intro(l),
      if (!lobby && _c.alone)
        l.ripples_alone
      else if (!lobby && _c.linkLost)
        l.ripples_linkLost,
    ];
    final invite = _c.invite;
    final notice = _c.notice;
    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: AuraSpace.s),
            // The phase word: a polite live region (announced per phase, not per frame).
            Semantics(
              liveRegion: true,
              container: true,
              child: AnimatedSwitcher(
                duration: reduceMotionOf(context)
                    ? reducedMotionFade
                    : AuraMotion.calm,
                child: Text(
                  _phaseWord(l),
                  key: ValueKey('ripple-phase-${_phaseWord(l)}'),
                  style: t.headlineSmall?.copyWith(color: AuraColors.text),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.gutter,
                  vertical: 2,
                ),
                child: _Scrim(
                  child: Text(
                    line,
                    key: ValueKey('ripple-line-$line'),
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                  ),
                ),
              ),
            if (lobby && invite != null)
              _Scrim(
                child: Text(
                  invite.mine
                      ? l.ripples_inviteMine(invite.humans, invite.capacity)
                      : l.ripples_invite(
                          invite.fromPseudonym,
                          invite.humans,
                          invite.capacity,
                        ),
                  style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
                ),
              ),
            const Spacer(),
            if (notice != null)
              Semantics(
                liveRegion: true,
                child: _Scrim(
                  child: Text(
                    notice.gesture == null
                        ? l.ripples_pulseFrom(notice.label ?? '')
                        : l.ripples_gestureFrom(
                            notice.label ?? '',
                            gestureName(l, notice.gesture!),
                          ),
                    key: const ValueKey('ripple-notice'),
                    style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
                  ),
                ),
              ),
            _breathArea(l),
            if (!lobby) _tray(l),
            if (lobby) _echoToggle(l),
            const SizedBox(height: AuraSpace.s),
          ],
        ),
      ],
    );
  }

  /// Tap targets over each light (≥ 48 dp), where the painter draws them:
  /// mute / block / report for people; labels for echoes and guides.
  Widget _lightTargets(AppLocalizations l) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) {
        final views = _c.lights();
        final h = box.maxHeight;
        final lightY =
            h * OceanPainter.horizon + (h - h * OceanPainter.horizon) * 0.42;
        return Stack(
          children: [
            // Tap targets over each light (48 dp): mute / block / report.
            for (final (i, v) in views.indexed)
              Positioned(
                left: box.maxWidth * OceanPainter.seatX(i, views.length) - 28,
                top: lightY - 60,
                width: 56,
                child: Semantics(
                  button: !v.me && v.kind == SeatKind.human && v.label != null,
                  label: _lightLabel(l, v),
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: ValueKey('ripple-light-${v.seat}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _tapLight(v),
                    child: SizedBox(
                      height: 72,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (v.gesture != null)
                            Text(
                              gestureName(l, v.gesture!),
                              key: ValueKey('ripple-gesture-${v.seat}'),
                              style: t.labelSmall?.copyWith(
                                color: AuraColors.starlight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                            ),
                          if (v.pulseAge != null)
                            Icon(
                              Icons.radio_button_unchecked_rounded,
                              key: ValueKey('ripple-visual-pulse-${v.seat}'),
                              size: 16,
                              color: AuraColors.starlight,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // "you / echo / guide" under each light (never inside its
            // glow): 12 pt textSoft. Screen readers get it from the target.
            for (final (i, v) in views.indexed)
              if (_shortLightName(l, v) case final name?)
                Positioned(
                  left: box.maxWidth * OceanPainter.seatX(i, views.length) - 48,
                  top: lightY + 30,
                  width: 96,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Text(
                        name,
                        key: ValueKey('ripple-light-label-${v.seat}'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: t.labelSmall?.copyWith(
                          fontSize: 12,
                          color: AuraColors.textSoft,
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _breathArea(AppLocalizations l) {
    final t = Theme.of(context).textTheme;
    final tap = _c.accessibleMode;
    return Semantics(
      button: true,
      label: l.ripples_breathArea,
      hint: tap ? l.ripples_tapHint : l.ripples_holdHint,
      toggled: tap ? _c.inhaling : null,
      onTap: tap ? _c.toggle : null,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('ripple-breath-area'),
        behavior: HitTestBehavior.opaque,
        onTap: tap ? _c.toggle : null,
        onTapDown: tap ? null : (_) => _c.press(),
        onTapUp: tap ? null : (_) => _c.release(),
        onTapCancel: tap ? null : _c.release,
        onLongPressEnd: tap ? null : (_) => _c.release(),
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AuraSpace.gutter,
            vertical: AuraSpace.s,
          ),
          constraints: const BoxConstraints(minHeight: 88),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AuraColors.surface.withValues(
              alpha: _c.inhaling ? 0.7 : 0.45,
            ),
            borderRadius: BorderRadius.circular(AuraRadius.l),
            border: Border.all(color: AuraColors.outline),
          ),
          padding: const EdgeInsets.all(AuraSpace.m),
          child: Text(
            tap ? l.ripples_tapHint : l.ripples_holdHint,
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: AuraColors.text),
          ),
        ),
      ),
    );
  }

  Widget _tray(AppLocalizations l) => Semantics(
    container: true,
    label: l.ripples_contactTray,
    // The shared tray: a pulse, then the three Ripples gestures with the
    // same icons (and order) as the room presets they mirror.
    child: Center(
      child: GestureTray(
        // Four tiles: one full row, nothing hidden off the edge.
        density: GestureTrayDensity.grid,
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.gutter),
        items: [
          GestureTrayItem(
            key: const ValueKey('ripple-pulse'),
            icon: Icons.flare_rounded,
            label: l.ripples_pulse,
            hint: l.ripples_contactTray,
            onPressed: () => _c.sendPulse(),
          ),
          for (final g in RippleGesture.values)
            GestureTrayItem(
              key: ValueKey('ripple-gesture-send-${g.wire}'),
              icon: gestureIcon(
                GestureType.fromWire(g.wire) ?? GestureType.hug,
              ),
              label: gestureName(l, g),
              hint: l.ripples_contactTray,
              onPressed: () => _c.sendGesture(g),
            ),
        ],
      ),
    ),
  );

  Widget _echoToggle(AppLocalizations l) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AuraSpace.gutter),
    child: _Scrim(
      child: SwitchListTile(
        key: const ValueKey('ripple-echo-toggle'),
        contentPadding: EdgeInsets.zero,
        value: _c.echoConsent,
        onChanged: (v) => unawaited(_c.setEchoConsent(v)),
        title: Text(l.ripples_echoToggle),
        subtitle: Text(l.ripples_echoToggleHint),
      ),
    ),
  );

  Widget _unavailable(AppLocalizations l) {
    final t = Theme.of(context).textTheme;
    final line = switch (_c.unavailable) {
      RipplesUnavailable.paused => l.ripples_paused,
      RipplesUnavailable.suspended => l.ripples_suspended,
      RipplesUnavailable.closed => l.ripples_closed,
      RipplesUnavailable.guidelines => l.ripples_guidelines,
      _ => l.ripples_offline,
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AuraSpace.gutter),
        child: _Scrim(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                line,
                key: const ValueKey('ripple-unavailable'),
                textAlign: TextAlign.center,
                style: t.titleMedium,
              ),
              const SizedBox(height: AuraSpace.l),
              FilledButton(
                key: const ValueKey('ripple-solo'),
                onPressed: _solo,
                child: Text(l.ripples_breatheSolo),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ended(AppLocalizations l) {
    final t = Theme.of(context).textTheme;
    final room = _c.session?.entry == RippleEntry.room;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AuraSpace.gutter),
        child: _Scrim(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  l.ripples_endTitle,
                  key: const ValueKey('ripple-end'),
                  textAlign: TextAlign.center,
                  style: t.titleLarge,
                ),
              ),
              if (_c.habitLogged) ...[
                const SizedBox(height: AuraSpace.s),
                Text(
                  l.habits_autoLogged(l.habit_breathe),
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                ),
              ],
              const SizedBox(height: AuraSpace.l),
              FilledButton(
                key: const ValueKey('ripple-again'),
                onPressed: _again,
                child: Text(l.ripples_again),
              ),
              const SizedBox(height: AuraSpace.s),
              if (room) ...[
                OutlinedButton(
                  key: const ValueKey('ripple-back-to-room'),
                  onPressed: _close,
                  child: Text(l.ripples_backToRoom),
                ),
                const SizedBox(height: AuraSpace.s),
              ],
              OutlinedButton(
                key: const ValueKey('ripple-done'),
                onPressed: _close,
                child: Text(l.common_done),
              ),
              TextButton(
                key: const ValueKey('ripple-feel-now'),
                onPressed: _feelNow,
                child: Text(l.ripples_feelNow),
              ),
              const SizedBox(height: AuraSpace.s),
              _echoToggle(l),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text never sits straight on the ocean's glow (REQ-A11Y-03).
class _Scrim extends StatelessWidget {
  const _Scrim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: AuraColors.skyDeep.withValues(alpha: 0.72),
    borderRadius: BorderRadius.circular(AuraRadius.m),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.m,
        vertical: AuraSpace.s,
      ),
      child: child,
    ),
  );
}
