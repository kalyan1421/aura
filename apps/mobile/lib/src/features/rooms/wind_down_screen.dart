import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../progress/progress_view.dart';
import '../quiet/quiet_providers.dart';
import '../quiet/quiet_sound_card.dart';
import '../quiet/shared_sound.dart';
import '../ripples/ripple_engine.dart' show ServerClock;
import '../sanctuary/breath_orb.dart';
import '../sanctuary/breath_pacer.dart';
import '../sanctuary/sounds/sounds_controller.dart';
import 'room_controller.dart';
import 'gesture_tray.dart';
import 'room_realtime.dart' show WindDownEvent;
import 'wind_down_api.dart';

String windDownCueLine(AppLocalizations l, String key) => switch (key) {
  'arrive' => l.rooms_windDownCue_arrive,
  'day_quieter' => l.rooms_windDownCue_day_quieter,
  'shoulders' => l.rooms_windDownCue_shoulders,
  'nothing_to_do' => l.rooms_windDownCue_nothing_to_do,
  'slower' => l.rooms_windDownCue_slower,
  'rest_well' => l.rooms_windDownCue_rest_well,
  _ => '',
};

/// The Lantern Hour wind-down (PRD 06b; REQ-QUIET-07; REQ-A11Y-15/16): the
/// F15 pacer (Calm 4/6) running from the common server `t0`, the phase words
/// (announced politely) with haptics, a few preset text cues, "N winding
/// down", the room's gestures, and one ambient track of base stems that plays
/// only after a tap. No voice, no narration. Leaving costs nothing.
class WindDownScreen extends ConsumerStatefulWidget {
  const WindDownScreen({
    super.key,
    required this.roomId,
    required this.view,
    required this.clock,
    this.wallMs,
  });

  final String roomId;
  final WindDownView view;
  final ServerClock clock;
  final int Function()? wallMs;

  @override
  ConsumerState<WindDownScreen> createState() => _WindDownScreenState();
}

class _WindDownScreenState extends ConsumerState<WindDownScreen> {
  late final BreathPacer _pacer;
  late final SoundsController _sounds;
  late final WindDownApi? _api;
  final ValueNotifier<double> _fill = ValueNotifier(BreathOrb.restingFill);
  StreamSubscription<WindDownEvent>? _events;
  Timer? _tick;
  late int _count;
  BreathPhase? _phase;
  int _step = -1;
  String? _cue;
  bool _over = false;

  int _wall() => widget.wallMs?.call() ?? DateTime.now().millisecondsSinceEpoch;
  int get _elapsedMs => widget.clock.toServer(_wall()) - widget.view.startsAtMs;

  @override
  void initState() {
    super.initState();
    final v = widget.view;
    _count = v.count;
    _sounds = ref.read(soundsControllerProvider.notifier);
    _api = ref.read(windDownApiProvider);
    _pacer = BreathPacer(
      pattern: v.inhaleMs == 4000 && v.exhaleMs == 6000
          ? BreathPattern.calm
          : BreathPattern(
              id: 'calm',
              inhale: Duration(milliseconds: v.inhaleMs),
              exhale: Duration(milliseconds: v.exhaleMs),
            ),
    );
    try {
      _events = ref
          .read(roomControllerProvider(widget.roomId).notifier)
          .windDownEvents
          .listen((e) {
            if (!mounted) return;
            if (e.state == 'ended') {
              setState(() => _over = true);
            } else {
              setState(() => _count = e.count);
            }
          });
    } on Object {
      // The count stays as opened.
    }
    _update();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) => _update());
  }

  void _update() {
    if (!mounted) return;
    final v = widget.view;
    final elapsed = _elapsedMs;
    if (!_over && _wall() + widget.clock.offsetMs >= v.endsAtMs) {
      setState(() => _over = true);
    }
    if (_over) {
      _tick?.cancel();
      return;
    }
    final m = _pacer.at(Duration(milliseconds: elapsed < 0 ? 0 : elapsed));
    _fill.value = m.fill;
    final cue = v.cueAt(elapsed ~/ 1000)?.key;
    if (m.step != _step || cue != _cue) {
      final newPhase = m.step != _step;
      setState(() {
        _step = m.step;
        _phase = m.phase;
        _cue = cue;
      });
      if (newPhase) ref.read(quietCuesProvider).breath(m.phase);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_events?.cancel());
    _fill.dispose();
    final api = _api;
    if (api != null) {
      unawaited(api.leave(widget.roomId).catchError((Object _) {}));
    }
    final sounds = _sounds;
    final key = windDownSoundKey(widget.roomId);
    scheduleMicrotask(() {
      try {
        sounds.stopShared(key);
      } on Object {
        // The app is closing: nothing to stop.
      }
    });
    super.dispose();
  }

  /// Leaving (this button or Back) costs nothing; the opt-out goes on
  /// dispose.
  void _leave() => Navigator.of(context).maybePop();

  String _word(AppLocalizations l, BreathPhase p) => switch (p) {
    BreathPhase.inhale => l.breathe_in,
    BreathPhase.holdIn || BreathPhase.holdOut => l.breathe_hold,
    BreathPhase.exhale => l.breathe_out,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final reduce = reduceMotionOf(context);
    final hue = ref.watch(progressViewProvider.select((v) => v.avatar.hue));
    final v = widget.view;
    final room = ref.watch(roomControllerProvider(widget.roomId));
    final canSend = room.canSend;
    final cue = _cue == null ? '' : windDownCueLine(l, _cue!);
    final start = DateTime.fromMillisecondsSinceEpoch(
      v.startsAtMs - widget.clock.offsetMs,
    );
    return Scaffold(
      appBar: helpAppBar(context, title: l.rooms_windDownTitle),
      body: CosmicBackground(
        tint: glowColorForHue(hue),
        child: SafeArea(
          top: false,
          child: ListView(
            key: const ValueKey('wind-down-screen'),
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.gutter,
              AuraSpace.s,
              AuraSpace.gutter,
              AuraSpace.xxl,
            ),
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  l.rooms_windDownCount(_count),
                  key: const ValueKey('wind-down-screen-count'),
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                ),
              ),
              const SizedBox(height: AuraSpace.l),
              Center(
                child: BreathOrb(
                  key: const ValueKey('wind-down-orb'),
                  hue: hue,
                  fill: _fill,
                  size: 220,
                  still: reduce || _over,
                ),
              ),
              const SizedBox(height: AuraSpace.l),
              if (_over)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l.rooms_windDownEnded,
                    key: const ValueKey('wind-down-ended'),
                    textAlign: TextAlign.center,
                    style: t.titleMedium,
                  ),
                )
              else ...[
                // The phase word: a polite live region, announced per phase.
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _phase == null ? '' : _word(l, _phase!),
                    key: const ValueKey('wind-down-phase'),
                    textAlign: TextAlign.center,
                    style: t.headlineSmall,
                  ),
                ),
                const SizedBox(height: AuraSpace.s),
                AnimatedSwitcher(
                  duration: reduce ? reducedMotionFade : AuraMotion.slow,
                  child: Text(
                    cue,
                    key: ValueKey('wind-down-cue-$_cue'),
                    textAlign: TextAlign.center,
                    style: t.bodyLarge?.copyWith(color: AuraColors.starlight),
                  ),
                ),
              ],
              const SizedBox(height: AuraSpace.xl),
              SharedSoundCard(
                soundKey: windDownSoundKey(widget.roomId),
                stemIds: v.stems,
                title: l.quiet_soundTitle,
                build: () => windDownSharedSound(
                  roomId: widget.roomId,
                  stems: v.stems,
                  t0Ms: v.startsAtMs,
                  day: LocalDay.fromDateTime(start),
                  clock: widget.clock,
                  wallMs: _wall,
                ),
              ),
              const SizedBox(height: AuraSpace.l),
              GestureTray(
                density: GestureTrayDensity.grid,
                items: presetGestureItems(
                  l,
                  hint: l.rooms_trayHint,
                  keyPrefix: 'wind-down-gesture-',
                  onSend: canSend
                      ? (g) => ref
                            .read(
                              roomControllerProvider(widget.roomId).notifier,
                            )
                            .sendGesture(g)
                      : null,
                ),
              ),
              const SizedBox(height: AuraSpace.xl),
              OutlinedButton(
                key: const ValueKey('wind-down-leave'),
                onPressed: _leave,
                child: Text(l.rooms_windDownLeave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
