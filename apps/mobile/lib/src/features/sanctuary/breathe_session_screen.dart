import 'dart:async';
import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/theme/aura_tokens.dart';
import '../checkin/quadrant_glyph.dart' show habitLabel;
import '../habits/habit_repository.dart' show breatheAutoCompleteAfter;
import '../progress/progress_view.dart';
import 'activity_scaffold.dart';
import 'breath_haptics.dart';
import 'breath_orb.dart';
import 'breath_pacer.dart';
import 'calm_route.dart';
import 'habit_auto_complete.dart';

/// How a paced breathing session is framed.
enum BreathGuide {
  /// Sanctuary › Breathe: a rhythm and a length (set up first, unless
  /// started from a card).
  breathe,

  /// Storm's "A minute for you": three slow breaths (30 s) with grounding
  /// cues; "Keep going" then opens Breathe.
  land,

  /// Moonlight's minute: one quiet minute with the orb, no instructions.
  stillness,

  /// Hand on heart: a hand on the chest, a minute of slow breaths with the
  /// orb and a few gentle lines.
  heart,
}

/// Session lengths offered in Breathe (`null` = until the person stops).
const List<Duration?> breatheLengths = [
  Duration(minutes: 1),
  Duration(minutes: 3),
  Duration(minutes: 5),
  null,
];

/// A breathing session with the avatar-orb pacer (F15 Breathe, and the paced
/// "A minute for you" activities). The [BreathPacer] turns active time into
/// phases; a ticker feeds it, with each frame's step capped at
/// [maxFrameStep] so time away from the screen never counts.
///
/// No score, no count, no numeric countdown: a quiet ring, words for the
/// phase (a live region, so screen readers hear each change, not every
/// second) and a haptic pattern per phase. Pause, resume or leave at any
/// time; "I need help now", a call or the app going to the background pauses
/// it. Under Reduce Motion the orb holds still and the phase words crossfade.
///
/// ≥ [breatheAutoCompleteAfter] of active breathing in one session ticks off
/// today's Breathe habit ([autoCompleteHabitToday]).
class BreatheSessionScreen extends ConsumerStatefulWidget {
  const BreatheSessionScreen({
    super.key,
    this.guide = BreathGuide.breathe,
    this.pattern = BreathPattern.calm,
    this.length = const Duration(minutes: 1),
    this.autoStart = false,
  });

  final BreathGuide guide;

  /// The rhythm (Breathe: the initial choice).
  final BreathPattern pattern;

  /// `null` = until the person stops (Breathe only).
  final Duration? length;

  /// Breathe: skip the setup (one tap from a card starts breathing). The
  /// other guides always start at once.
  final bool autoStart;

  /// The largest step one frame may add (time away never counts).
  static const Duration maxFrameStep = Duration(seconds: 1);

  @override
  ConsumerState<BreatheSessionScreen> createState() =>
      _BreatheSessionScreenState();
}

enum _Stage { setup, running, done }

class _BreatheSessionScreenState extends ConsumerState<BreatheSessionScreen>
    with SingleTickerProviderStateMixin {
  late BreathPattern _pattern = widget.pattern;
  late Duration? _length = switch (widget.guide) {
    BreathGuide.land => const Duration(seconds: 30),
    BreathGuide.stillness || BreathGuide.heart => const Duration(minutes: 1),
    BreathGuide.breathe => widget.length,
  };
  late _Stage _stage = widget.guide == BreathGuide.breathe && !widget.autoStart
      ? _Stage.setup
      : _Stage.running;

  late BreathPacer _pacer = BreathPacer(pattern: _pattern, length: _length);
  late final Ticker _ticker = createTicker(_onTick);
  late final AppLifecycleListener _lifecycle;

  /// Breath fill (orb size) and session progress (ring), per frame.
  final ValueNotifier<double> _fill = ValueNotifier(0);
  final ValueNotifier<double?> _progress = ValueNotifier(0);

  Duration _active = Duration.zero;
  Duration _lastTick = Duration.zero;
  BreathMoment? _moment;
  bool _paused = false;
  bool _reduce = false;

  /// The Breathe auto-complete was tried this session / wrote a completion.
  bool _breatheTried = false;
  bool _breatheLogged = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _autoPause, onPause: _autoPause);
    if (_stage == _Stage.running) _begin();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = reduceMotionOf(context);
    // Help (or anything else) opened on top: the pacer pauses (REQ-SAN-08).
    // The build that follows shows it.
    if (!(ModalRoute.isCurrentOf(context) ?? true)) _pause(notify: false);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ticker.dispose();
    _fill.dispose();
    _progress.dispose();
    super.dispose();
  }

  // ---- pacing ----------------------------------------------------------------

  void _begin() {
    _pacer = BreathPacer(pattern: _pattern, length: _length);
    _active = Duration.zero;
    _moment = null;
    _paused = false;
    _stage = _Stage.running;
    _lastTick = Duration.zero;
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
    // The caller rebuilds (initState, or inside setState).
    _apply(_pacer.at(Duration.zero), notify: false);
  }

  void _onTick(Duration elapsed) {
    var step = elapsed - _lastTick;
    _lastTick = elapsed;
    if (step < Duration.zero) step = Duration.zero;
    if (step > BreatheSessionScreen.maxFrameStep) {
      step = BreatheSessionScreen.maxFrameStep;
    }
    _active += step;
    _apply(_pacer.at(_active));
  }

  void _apply(BreathMoment m, {bool notify = true}) {
    final changed = m.step != _moment?.step;
    _moment = m;
    _fill.value = m.fill;
    // Under Reduce Motion the ring moves only when the phase changes.
    if (!_reduce || changed || m.done) _progress.value = m.progress;
    if (!_breatheTried && _active >= breatheAutoCompleteAfter) {
      _breatheTried = true;
      unawaited(_logBreathe());
    }
    if (m.done) {
      _finish(notify: notify);
      return;
    }
    if (changed) {
      ref.read(breathHapticsProvider).phaseStarted(m.phase);
      if (notify && mounted) setState(() {});
    }
  }

  Future<void> _logBreathe() async {
    final logged = await autoCompleteHabitToday(ref, PresetHabitKeys.breathe);
    if (logged && mounted) setState(() => _breatheLogged = true);
  }

  void _pause({bool notify = true}) {
    if (_stage != _Stage.running || _paused) return;
    _ticker.stop();
    _paused = true;
    if (notify) setState(() {});
  }

  void _autoPause() {
    if (mounted) _pause();
  }

  void _resume() {
    if (_stage != _Stage.running || !_paused) return;
    _lastTick = Duration.zero; // a restarted ticker counts from zero
    _ticker.start();
    setState(() => _paused = false);
  }

  void _finish({bool notify = true}) {
    if (_ticker.isActive) _ticker.stop();
    _stage = _Stage.done;
    _paused = false;
    if (notify && mounted) setState(() {});
  }

  void _keepGoing() => Navigator.of(context).pushReplacement(
    calmRoute<void>(context, (_) => const BreatheSessionScreen()),
  );

  // ---- view --------------------------------------------------------------------

  String _title(AppLocalizations l) => switch (widget.guide) {
    BreathGuide.breathe => l.sanctuary_breatheSection,
    BreathGuide.land => l.minute_landTitle,
    BreathGuide.stillness => l.minute_stillnessTitle,
    BreathGuide.heart => l.heart_title,
  };

  /// A gentle cue per breath, or `null` (Breathe, stillness).
  String? _cue(AppLocalizations l, int breath) {
    final cues = switch (widget.guide) {
      BreathGuide.land => [l.breathe_land1, l.breathe_land2, l.breathe_land3],
      BreathGuide.heart => [
        l.heart_intro,
        l.heart_1,
        l.heart_2,
        l.heart_3,
        l.heart_4,
      ],
      BreathGuide.breathe || BreathGuide.stillness => const <String>[],
    };
    if (cues.isEmpty) return null;
    return cues[math.min(breath, cues.length - 1)];
  }

  static String phaseWord(AppLocalizations l, BreathPhase p) => switch (p) {
    BreathPhase.inhale => l.breathe_in,
    BreathPhase.holdIn || BreathPhase.holdOut => l.breathe_hold,
    BreathPhase.exhale => l.breathe_out,
  };

  @override
  Widget build(BuildContext context) {
    final hue = ref.watch(progressViewProvider.select((v) => v.avatar.hue));
    return ActivityScaffold(
      tint: glowColorForHue(hue),
      // "I need help now" pauses the pacer first (REQ-SAN-08).
      onHelp: _autoPause,
      child: AnimatedSwitcher(
        duration: _reduce ? reducedMotionFade : AuraMotion.calm,
        child: switch (_stage) {
          _Stage.setup => _setup(context, hue),
          _Stage.running => _running(context, hue),
          _Stage.done => _done(context, hue),
        },
      ),
    );
  }

  Widget _setup(BuildContext context, double hue) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: AuraSpace.xl, bottom: AuraSpace.s),
      child: Semantics(
        header: true,
        container: true,
        child: Text(text, style: t.titleSmall),
      ),
    );
    String body(BreathPattern p) => switch (p.id) {
      'box' => l.breathe_boxBody,
      '478' => l.breathe_478Body,
      _ => l.breathe_calmBody,
    };
    String name(BreathPattern p) => switch (p.id) {
      'box' => l.breathe_box,
      '478' => l.breathe_478,
      _ => l.breathe_calm,
    };
    return Column(
      key: const ValueKey('breathe-setup'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.gutter,
              AuraSpace.s,
              AuraSpace.gutter,
              AuraSpace.xl,
            ),
            children: [
              ActivityTitle(l.sanctuary_breatheSection),
              const SizedBox(height: AuraSpace.l),
              Center(child: BreathOrb(hue: hue, size: 150, still: true)),
              header(l.breathe_rhythm),
              Wrap(
                spacing: AuraSpace.s,
                runSpacing: AuraSpace.s,
                children: [
                  for (final p in BreathPattern.values)
                    ChoiceChip(
                      key: ValueKey('breathe-pattern-${p.id}'),
                      label: Text(name(p)),
                      selected: _pattern == p,
                      onSelected: (_) => setState(() => _pattern = p),
                    ),
                ],
              ),
              const SizedBox(height: AuraSpace.s),
              Text(
                body(_pattern),
                style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
              ),
              if (_pattern.lightHeadedCaution) ...[
                const SizedBox(height: AuraSpace.s),
                _LightHeadedNote(text: l.breathe_lightHeaded),
              ],
              header(l.breathe_length),
              Wrap(
                spacing: AuraSpace.s,
                runSpacing: AuraSpace.s,
                children: [
                  for (final d in breatheLengths)
                    ChoiceChip(
                      key: ValueKey('breathe-length-${d?.inMinutes ?? 'open'}'),
                      label: Text(
                        d == null
                            ? l.breathe_openEnded
                            : l.breathe_minutes(d.inMinutes),
                      ),
                      selected: _length == d,
                      onSelected: (_) => setState(() => _length = d),
                    ),
                ],
              ),
            ],
          ),
        ),
        _Pinned(
          child: FilledButton(
            key: const ValueKey('breathe-start'),
            onPressed: () => setState(_begin),
            child: Text(l.sanctuary_start),
          ),
        ),
      ],
    );
  }

  Widget _running(BuildContext context, double hue) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final m = _moment ?? _pacer.at(Duration.zero);
    final phase = _paused ? l.breathe_paused : phaseWord(l, m.phase);
    final cue = _cue(l, m.breath);
    return Column(
      key: const ValueKey('breathe-running'),
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final orb = math
                  .min(
                    math.min(box.maxWidth - 2 * AuraSpace.gutter, 300.0),
                    box.maxHeight * 0.5,
                  )
                  .clamp(120.0, 300.0);
              return CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AuraSpace.gutter,
                        AuraSpace.s,
                        AuraSpace.gutter,
                        AuraSpace.l,
                      ),
                      child: Column(
                        children: [
                          Text(
                            _title(l),
                            textAlign: TextAlign.center,
                            style: t.titleMedium?.copyWith(
                              color: AuraColors.textSoft,
                            ),
                          ),
                          const Spacer(),
                          SizedBox.square(
                            dimension: orb + 24,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_pacer.total != null)
                                  _QuietRing(progress: _progress),
                                BreathOrb(
                                  hue: hue,
                                  fill: _fill,
                                  size: orb,
                                  still: _reduce,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AuraSpace.l),
                          // The phase: announced when it changes (a live
                          // region), crossfaded on screen. Never a number.
                          Semantics(
                            liveRegion: true,
                            container: true,
                            label: phase,
                            child: ExcludeSemantics(
                              child: _WordPill(
                                child: AnimatedSwitcher(
                                  duration: _reduce
                                      ? reducedMotionFade
                                      : AuraMotion.quick,
                                  child: Text(
                                    phase,
                                    key: ValueKey(phase),
                                    textAlign: TextAlign.center,
                                    style: t.titleLarge?.copyWith(
                                      color: AuraColors.text,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (cue != null) ...[
                            const SizedBox(height: AuraSpace.m),
                            Semantics(
                              liveRegion: true,
                              container: true,
                              child: Text(
                                cue,
                                key: const ValueKey('breathe-cue'),
                                textAlign: TextAlign.center,
                                style: t.bodyLarge?.copyWith(
                                  color: AuraColors.textSoft,
                                ),
                              ),
                            ),
                          ],
                          if (_pattern.lightHeadedCaution) ...[
                            const SizedBox(height: AuraSpace.m),
                            _LightHeadedNote(text: l.breathe_lightHeaded),
                          ],
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        _Pinned(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('breathe-toggle'),
                  onPressed: _paused ? _resume : _pause,
                  child: Text(_paused ? l.sanctuary_resume : l.sanctuary_pause),
                ),
              ),
              const SizedBox(width: AuraSpace.m),
              Expanded(
                child: TextButton(
                  key: const ValueKey('breathe-finish'),
                  onPressed: _finish,
                  child: Text(l.sanctuary_finish),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _done(BuildContext context, double hue) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final text = widget.guide == BreathGuide.heart
        ? l.heart_done
        : l.breathe_done;
    return Column(
      key: const ValueKey('breathe-done'),
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.gutter),
                  child: Column(
                    children: [
                      const Spacer(),
                      BreathOrb(hue: hue, size: 170, still: true),
                      const SizedBox(height: AuraSpace.xl),
                      Semantics(
                        liveRegion: true,
                        container: true,
                        child: Text(
                          text,
                          key: const ValueKey('breathe-done-line'),
                          textAlign: TextAlign.center,
                          style: t.titleLarge,
                        ),
                      ),
                      if (_breatheLogged) ...[
                        const SizedBox(height: AuraSpace.s),
                        Semantics(
                          liveRegion: true,
                          container: true,
                          child: Text(
                            l.habits_autoLogged(
                              habitLabel(l, PresetHabitKeys.breathe),
                            ),
                            key: const ValueKey('breathe-logged'),
                            textAlign: TextAlign.center,
                            style: t.bodyMedium?.copyWith(
                              color: AuraColors.textSoft,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _Pinned(
          child: Row(
            children: [
              Expanded(
                child: widget.guide == BreathGuide.land
                    ? OutlinedButton(
                        key: const ValueKey('breathe-keep-going'),
                        onPressed: _keepGoing,
                        child: Text(l.breathe_keepGoing),
                      )
                    : OutlinedButton(
                        key: const ValueKey('breathe-again'),
                        onPressed: () => setState(_begin),
                        child: Text(l.breathe_again),
                      ),
              ),
              const SizedBox(width: AuraSpace.m),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('breathe-done-button'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(l.common_done),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The quiet progress ring: no numbers, no countdown. Screen readers hear a
/// word for how far through ("About halfway").
class _QuietRing extends StatelessWidget {
  const _QuietRing({required this.progress});

  final ValueListenable<double?> progress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<double?>(
      valueListenable: progress,
      builder: (context, p, _) => Semantics(
        container: true,
        label: l.sanctuary_progress,
        value: progressWord(l, p ?? 0),
        child: ExcludeSemantics(
          child: SizedBox.expand(
            child: CircularProgressIndicator(
              key: const ValueKey('breathe-progress'),
              value: p ?? 0,
              strokeWidth: 3,
              color: AuraColors.starlight.withValues(alpha: 0.7),
              backgroundColor: AuraColors.outline.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

/// A gentle word for how far through a session [p] (0–1) is. Never a
/// number.
String progressWord(AppLocalizations l, double p) {
  if (p >= 1) return l.sanctuary_progressDone;
  if (p < 1 / 3) return l.sanctuary_progressBegun;
  if (p < 2 / 3) return l.sanctuary_progressHalf;
  return l.sanctuary_progressNearly;
}

/// Words on a soft scrim, so they never sit straight on the glow or the
/// stars (REQ-A11Y-03).
class _WordPill extends StatelessWidget {
  const _WordPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 160),
    padding: const EdgeInsets.symmetric(
      horizontal: AuraSpace.xl,
      vertical: AuraSpace.s,
    ),
    decoration: BoxDecoration(
      color: AuraColors.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      border: Border.all(color: AuraColors.hairline),
    ),
    child: child,
  );
}

/// "If you feel light-headed, stop and breathe normally." (4-7-8).
class _LightHeadedNote extends StatelessWidget {
  const _LightHeadedNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('breathe-light-headed'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 2),
        child: ExcludeSemantics(
          child: Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AuraColors.textSoft,
          ),
        ),
      ),
      const SizedBox(width: AuraSpace.s),
      Flexible(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AuraColors.textSoft),
        ),
      ),
    ],
  );
}

/// Buttons pinned under the scrolling content.
class _Pinned extends StatelessWidget {
  const _Pinned({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AuraSpace.gutter,
      AuraSpace.s,
      AuraSpace.gutter,
      AuraSpace.l,
    ),
    child: SizedBox(width: double.infinity, child: child),
  );
}
