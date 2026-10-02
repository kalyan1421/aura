import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/entitlements/plus.dart';
import '../../../core/providers.dart';
import 'saved_mixes.dart';
import 'sound_rng.dart';
import 'sounds_backend.dart';
import 'sounds_library.dart';
import 'sounds_session_log.dart';
import 'wind_down.dart';

/// The Sounds mixer (PRD 06d "Sounds", REQ-SAN-09…13).
///
/// - Silent until chosen: nothing is set up or plays until a tap
///   ([toggle], [startWindDown], [playMix]); every start, resume and added
///   layer fades in over [soundsFadeIn] (≥ 2 s).
/// - Up to `max_layers` (4) stems, each with its own volume.
/// - Timer: 15, 30 or 60 min, or off; the sound fades out over the last
///   [soundsTimerFade] and stops.
/// - Night wind-down: tonight's [WindDownPlan] drives the volumes until it
///   thins out to silence.
/// - Calls and other apps pause it (a call that ends resumes it, with the
///   same fade); headphones disconnecting pause it and it stays paused,
///   so it never moves to the speaker by itself.
///
/// Every fade runs on one [soundsTick] ticker that also counts heard time
/// (paused time excluded), the timer and the wind-down clock.
///
/// Shared soundscapes (F16 Quiet Together and the Lantern Hour wind-down):
/// [startShared] plays fixed base stems positioned on a shared clock, so
/// every phone hears the same moment; volume is per person
/// ([setSharedLevel]). Nothing about a shared sound is recorded (no session
/// log: nothing may depend on time spent together, REQ-QUIET-04).

enum SoundsPhase { idle, playing, paused }

enum SoundsMode { mix, windDown }

/// What a tap on a stem did.
enum SoundsToggle {
  added,
  removed,

  /// A Plus stem on Free: show the calm note, nothing plays.
  locked,

  /// Already [SoundsState.maxLayers] playing.
  full,

  /// Its recording must be downloaded first.
  needsDownload,

  /// The wind-down is playing; stems can't be changed under it.
  busy,

  /// Not in the manifest.
  unknown,
}

const Duration soundsFadeIn = Duration(milliseconds: 2500);
const Duration soundsQuickFade = Duration(milliseconds: 600);
const Duration soundsTimerFade = Duration(seconds: 30);
const Duration soundsTick = Duration(milliseconds: 200);
const double soundsDefaultVolume = 0.6;

/// Volume while another sound briefly needs the speaker.
const double soundsDuckLevel = 0.3;

/// The timer choices (plus "off"), PRD 06d.
const List<Duration> soundsTimerChoices = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 60),
];

@immutable
class SoundsLayerState {
  const SoundsLayerState(this.stemId, this.volume);

  final String stemId;

  /// The person's volume for this stem, 0…1 (the wind-down sets its own).
  final double volume;
}

const Object _keep = Object();

/// How far ahead of "now" a shared layer is positioned: it covers opening
/// the file before playback starts, so phones line up within ±1 s.
const Duration sharedSoundLead = Duration(milliseconds: 150);

/// The per-person volume a shared soundscape starts at.
const double sharedSoundDefaultLevel = 0.8;

/// A shared soundscape (PRD F16): base stems at fixed gains, positioned on a
/// clock every phone shares (the server's `t0`). Built by Quiet Together and
/// the Lantern Hour wind-down; plays only after a tap.
@immutable
class SharedSound {
  const SharedSound({
    required this.key,
    required this.layers,
    required this.elapsed,
    this.plan,
  });

  /// Which shared sound this is (e.g. `quiet:<sessionId>`), so a screen can
  /// tell whether its own sound is the one playing.
  final String key;

  /// Stem ids and their gains in the mix (0…1).
  final List<SoundsLayerState> layers;

  /// Time since the shared start on the (server-corrected) clock: each
  /// layer starts at this point of its loop.
  final Duration Function() elapsed;

  /// A volume envelope over [elapsed] (the wind-down: it thins out to
  /// silence and ends); `null` = steady gains, open-ended.
  final WindDownPlan? plan;
}

@immutable
class SoundsState {
  const SoundsState({
    this.phase = SoundsPhase.idle,
    this.mode = SoundsMode.mix,
    this.layers = const [],
    this.maxLayers = 4,
    this.timer,
    this.timerLeft,
    this.fadingOut = false,
    this.windDown,
    this.windDownLeft,
    this.shared,
    this.sharedLevel = sharedSoundDefaultLevel,
  });

  final SoundsPhase phase;
  final SoundsMode mode;
  final List<SoundsLayerState> layers;
  final int maxLayers;

  /// The timer the person chose (`null` = off).
  final Duration? timer;

  /// Time left before the sound has faded out (published about once a
  /// minute, and when the fade starts).
  final Duration? timerLeft;

  /// The timer's closing fade is running.
  final bool fadingOut;
  final WindDownPlan? windDown;
  final Duration? windDownLeft;

  /// The [SharedSound.key] playing (F16), or `null`.
  final String? shared;

  /// The person's own volume for a shared soundscape, 0…1.
  final double sharedLevel;

  bool get isIdle => phase == SoundsPhase.idle;
  bool get isPlaying => phase == SoundsPhase.playing;
  bool get isWindDown => mode == SoundsMode.windDown && !isIdle;
  bool get isFull => layers.length >= maxLayers;

  /// A shared soundscape is playing or paused.
  bool get isShared => shared != null && !isIdle;

  bool isOn(String stemId) => layers.any((l) => l.stemId == stemId);

  double? volumeOf(String stemId) {
    for (final l in layers) {
      if (l.stemId == stemId) return l.volume;
    }
    return null;
  }

  SoundsState copyWith({
    SoundsPhase? phase,
    SoundsMode? mode,
    List<SoundsLayerState>? layers,
    int? maxLayers,
    Object? timer = _keep,
    Object? timerLeft = _keep,
    bool? fadingOut,
    Object? windDown = _keep,
    Object? windDownLeft = _keep,
    Object? shared = _keep,
    double? sharedLevel,
  }) => SoundsState(
    phase: phase ?? this.phase,
    mode: mode ?? this.mode,
    layers: layers ?? this.layers,
    maxLayers: maxLayers ?? this.maxLayers,
    timer: identical(timer, _keep) ? this.timer : timer as Duration?,
    timerLeft: identical(timerLeft, _keep)
        ? this.timerLeft
        : timerLeft as Duration?,
    fadingOut: fadingOut ?? this.fadingOut,
    windDown: identical(windDown, _keep)
        ? this.windDown
        : windDown as WindDownPlan?,
    windDownLeft: identical(windDownLeft, _keep)
        ? this.windDownLeft
        : windDownLeft as Duration?,
    shared: identical(shared, _keep) ? this.shared : shared as String?,
    sharedLevel: sharedLevel ?? this.sharedLevel,
  );
}

final soundsControllerProvider =
    NotifierProvider<SoundsController, SoundsState>(SoundsController.new);

/// One layer's player and its own fade (a layer added mid-mix fades in; a
/// removed one fades out, then is released).
class _Voice {
  _Voice(this.stemId);

  final String stemId;
  SoundsLayer? layer;
  double fade = 0;
  double fadeTarget = 0;
  double fadeStep = 0;
  bool retired = false;
  double sent = -1;

  /// The master level when it was retired: a retiring layer fades on its
  /// own, whatever the next session does with the master.
  double? retiredMaster;
}

class SoundsController extends Notifier<SoundsState>
    implements SoundsTransport {
  late SoundsBackend _backend;
  final Map<String, _Voice> _voices = {};
  final List<_Voice> _retiring = [];
  Timer? _ticker;
  StreamSubscription<SoundsInterruption>? _interruptions;

  double _master = 0;
  double _masterTarget = 0;
  double _masterStep = 0;
  VoidCallback? _onMasterDone;
  double _duck = 1;
  bool _pausedByInterruption = false;

  Duration _heard = Duration.zero;
  Duration? _timerLeft;
  Duration _windElapsed = Duration.zero;
  LocalDay? _day;
  int _seeds = 0;
  SharedSound? _shared;

  @override
  SoundsState build() {
    _backend = ref.read(soundsBackendProvider);
    _backend.bindTransport(this);
    ref.onDispose(_dispose);
    return SoundsState(
      maxLayers: ref.read(stemManifestProvider).maxLayers,
    );
  }

  // ---- public API --------------------------------------------------------------

  /// A tap on a stem: adds it (starting the sound if nothing plays) or
  /// takes it out (stopping when it was the last one).
  SoundsToggle toggle(String stemId) {
    if (state.isWindDown || state.isShared) return SoundsToggle.busy;
    if (state.isOn(stemId)) {
      _removeLayer(stemId);
      return SoundsToggle.removed;
    }
    final library = ref.read(soundsLibraryProvider);
    final stem = library.manifest.byId(stemId);
    if (stem == null || !stem.listed) return SoundsToggle.unknown;
    if (stem.isPlus && !ref.read(plusActiveProvider)) {
      return SoundsToggle.locked;
    }
    if (library.needsDownload(stem)) return SoundsToggle.needsDownload;
    if (state.isFull) return SoundsToggle.full;

    final wasIdle = state.isIdle;
    state = state.copyWith(
      mode: SoundsMode.mix,
      layers: [
        ...state.layers,
        SoundsLayerState(stemId, soundsDefaultVolume),
      ],
    );
    _openVoice(stemId);
    if (wasIdle) {
      _begin();
    } else if (state.phase == SoundsPhase.paused) {
      play();
    }
    return SoundsToggle.added;
  }

  /// The person's volume for [stemId] (0…1).
  void setVolume(String stemId, double volume) {
    if (!state.isOn(stemId) || state.isWindDown || state.isShared) return;
    state = state.copyWith(
      layers: [
        for (final l in state.layers)
          l.stemId == stemId
              ? SoundsLayerState(stemId, volume.clamp(0.0, 1.0))
              : l,
      ],
    );
    _applyVolumes();
  }

  /// Resumes after a pause, fading in. Also the lock-screen "play".
  @override
  void play() {
    if (state.phase != SoundsPhase.paused) return;
    _pausedByInterruption = false;
    state = state.copyWith(phase: SoundsPhase.playing);
    if (_shared != null) {
      // A shared sound resumes where everyone else is, not where it paused.
      for (final v in _voices.values.toList()) {
        _retire(v);
      }
      _voices.clear();
      for (final l in state.layers) {
        _openVoice(l.stemId);
      }
    } else {
      for (final v in _voices.values) {
        v.layer?.play();
      }
    }
    _rampMaster(1, soundsFadeIn);
    if (state.fadingOut) _startTimerFade();
    _publishMedia();
  }

  /// Pauses with a short fade. Also the lock-screen "pause".
  @override
  void pause() {
    if (state.phase != SoundsPhase.playing) return;
    _pausedByInterruption = false;
    state = state.copyWith(phase: SoundsPhase.paused);
    _rampMaster(0, soundsQuickFade, onDone: () {
      for (final v in _voices.values) {
        v.layer?.pause();
      }
    });
    _publishMedia();
  }

  /// Ends the session (a short fade, then everything is released). Also
  /// the lock-screen "stop".
  @override
  void stop() {
    if (state.isIdle) return;
    _endSession();
  }

  /// Sets the timer (`null` = off). Setting it again during the closing
  /// fade brings the sound back up.
  void setTimer(Duration? length) {
    if (state.isWindDown || state.isShared) return;
    _timerLeft = length;
    final wasFading = state.fadingOut;
    state = state.copyWith(
      timer: length,
      timerLeft: length,
      fadingOut: false,
    );
    if (wasFading && state.isPlaying) _rampMaster(1, soundsFadeIn);
  }

  /// Tonight's wind-down: the base stems that play now, in the order for
  /// this Aura day. Returns false when no base stem can play.
  bool startWindDown() {
    final library = ref.read(soundsLibraryProvider);
    final pool = [
      for (final s in library.stems)
        if (!s.isPlus && library.isPlayable(s)) s,
    ];
    final plan = windDownPlanFor(ref.read(timeContextProvider).today(), pool);
    if (plan.order.isEmpty) return false;
    if (!state.isIdle) _endSession();
    _windElapsed = Duration.zero;
    _timerLeft = null;
    state = state.copyWith(
      mode: SoundsMode.windDown,
      layers: [for (final id in plan.order) SoundsLayerState(id, 1)],
      windDown: plan,
      windDownLeft: plan.length,
      timer: null,
      timerLeft: null,
      fadingOut: false,
    );
    for (final id in plan.order) {
      _openVoice(id);
    }
    _begin();
    return true;
  }

  /// Plays a saved mix (what can play of it: locked or not-yet-downloaded
  /// stems are left out). Returns false when none of it can.
  bool playMix(SavedMix mix) {
    if (state.isWindDown) return false;
    final library = ref.read(soundsLibraryProvider);
    final plus = ref.read(plusActiveProvider);
    final layers = <SoundsLayerState>[];
    for (final (id, volume) in mix.layers) {
      final stem = library.manifest.byId(id);
      if (stem == null || !stem.listed) continue;
      if (stem.isPlus && !plus) continue;
      if (!library.isPlayable(stem)) continue;
      if (layers.length >= state.maxLayers) break;
      layers.add(SoundsLayerState(id, volume));
    }
    if (layers.isEmpty) return false;
    if (!state.isIdle) _endSession();
    state = state.copyWith(mode: SoundsMode.mix, layers: layers);
    for (final l in layers) {
      _openVoice(l.stemId);
    }
    _begin();
    return true;
  }

  /// A shared soundscape (F16): its base stems, positioned at
  /// [SharedSound.elapsed] on the shared clock. Plus stems and stems that
  /// can't play here are left out (it never leads to a paywall). Ends
  /// whatever played before. Returns false when none of it can play.
  bool startShared(SharedSound sound) {
    final library = ref.read(soundsLibraryProvider);
    final layers = <SoundsLayerState>[];
    for (final l in sound.layers) {
      final stem = library.manifest.byId(l.stemId);
      if (stem == null || !stem.listed || stem.isPlus) continue;
      if (!library.isPlayable(stem)) continue;
      if (layers.any((x) => x.stemId == l.stemId)) continue;
      if (layers.length >= state.maxLayers) break;
      layers.add(SoundsLayerState(l.stemId, l.volume.clamp(0.0, 1.0)));
    }
    if (layers.isEmpty) return false;
    if (!state.isIdle) _endSession();
    _shared = sound;
    state = state.copyWith(
      mode: SoundsMode.mix,
      layers: layers,
      shared: sound.key,
      fadingOut: false,
    );
    for (final l in layers) {
      _openVoice(l.stemId);
    }
    _begin();
    return true;
  }

  /// The person's own volume for the shared soundscape (0…1).
  void setSharedLevel(double level) {
    state = state.copyWith(sharedLevel: level.clamp(0.0, 1.0));
    _applyVolumes();
  }

  /// Stops the shared soundscape [key] if it is the one playing (a screen
  /// closing never stops someone else's sound).
  void stopShared(String key) {
    if (state.shared == key && !state.isIdle) _endSession();
  }

  /// The current mix, to save.
  SavedMix? get currentMix =>
      state.isIdle || state.isWindDown || state.isShared
      ? null
      : SavedMix([for (final l in state.layers) (l.stemId, l.volume)]);

  // ---- session ---------------------------------------------------------------

  void _begin() {
    _heard = Duration.zero;
    _day = ref.read(timeContextProvider).today();
    _master = 0;
    _pausedByInterruption = false;
    // A shared sound follows its own clock, never the personal timer.
    _timerLeft = _shared == null ? state.timer : null;
    state = state.copyWith(
      phase: SoundsPhase.playing,
      timerLeft: _timerLeft,
      fadingOut: false,
    );
    _rampMaster(1, soundsFadeIn);
    _publishMedia();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      await _backend.prepare();
      _interruptions ??= _backend.interruptions.listen(_onInterruption);
      // The media session (Android: the foreground service and lock-screen controls) is built inside
      // prepare(), after _begin() published the state, so that first publish had nowhere to go. Publish
      // again now, or the first sound after launch plays with no foreground service and Android may
      // silence it once the screen locks. Found by running a release build on an emulator.
      _publishMedia();
    } on Object catch (e) {
      debugPrint('sounds: prepare failed (${e.runtimeType})');
    }
  }

  void _endSession() {
    final plan = state.windDown;
    final heard = _heard.inSeconds;
    final day = _day;
    // A shared sound (F16) leaves no record of time spent together.
    final shared = _shared != null;
    _shared = null;
    if (heard >= 1 && day != null && !shared) {
      final timer = state.timer;
      unawaited(
        ref
            .read(soundsSessionLogProvider)
            .record(
              SoundsSessionRecord(
                activity: plan != null ? 'night_wind_down' : 'sounds',
                variant: plan != null
                    ? 'v1'
                    : timer == null
                    ? 'open'
                    : 'timer_${timer.inMinutes}',
                durationS: heard,
                localDay: day,
              ),
            )
            .catchError((Object e) {
              debugPrint('sounds: session record failed (${e.runtimeType})');
            }),
      );
    }
    for (final v in _voices.values.toList()) {
      _retire(v);
    }
    _voices.clear();
    _heard = Duration.zero;
    _day = null;
    _timerLeft = null;
    _windElapsed = Duration.zero;
    _pausedByInterruption = false;
    _onMasterDone = null;
    _masterTarget = _master;
    state = SoundsState(
      maxLayers: state.maxLayers,
      timer: state.timer,
      sharedLevel: state.sharedLevel,
    );
    _publishMedia();
    _ensureTicker();
    if (_ticker == null) unawaited(_backend.release());
  }

  // ---- layers ------------------------------------------------------------------

  void _openVoice(String stemId) {
    final voice = _Voice(stemId);
    _voices[stemId] = voice;
    unawaited(_load(voice));
  }

  Future<void> _load(_Voice voice) async {
    try {
      final stem = ref.read(soundsLibraryProvider).manifest.byId(voice.stemId);
      final path = stem == null
          ? null
          : await ref.read(stemStoreProvider).playablePath(stem);
      if (path == null) throw StateError('not playable');
      await _prepare();
      final shared = _shared;
      // A shared layer starts at the shared moment of its loop (the backend
      // seeks to `seed mod length`); others at a random point.
      final seed = shared != null
          ? (shared.elapsed() + sharedSoundLead).inMilliseconds.clamp(
              0,
              0x7fffffff,
            )
          : SoundRng(
              fnv1a32(voice.stemId) ^ (DateTime.now().microsecond + _seeds++),
            ).nextUint32();
      final layer = await _backend.openLayer(path, seed: seed);
      if (voice.retired || _voices[voice.stemId] != voice) {
        await layer.dispose();
        return;
      }
      voice.layer = layer;
      layer.setVolume(0);
      voice.sent = 0;
      _fadeVoice(voice, 1, soundsFadeIn);
      if (state.isPlaying) await layer.play();
    } on Object catch (e) {
      debugPrint('sounds: a layer could not start (${e.runtimeType})');
      if (_voices[voice.stemId] == voice) {
        _voices.remove(voice.stemId);
        final rest = [
          for (final l in state.layers)
            if (l.stemId != voice.stemId) l,
        ];
        if (rest.isEmpty && !state.isIdle) {
          _endSession();
        } else {
          state = state.copyWith(layers: rest);
        }
      }
    }
  }

  void _removeLayer(String stemId) {
    final rest = [
      for (final l in state.layers)
        if (l.stemId != stemId) l,
    ];
    if (rest.isEmpty) {
      _endSession();
      return;
    }
    final voice = _voices.remove(stemId);
    if (voice != null) _retire(voice);
    state = state.copyWith(layers: rest);
  }

  void _retire(_Voice voice) {
    voice.retired = true;
    voice.retiredMaster = _master;
    if (voice.layer == null) return; // still loading: dropped on arrival
    _retiring.add(voice);
    _fadeVoice(voice, 0, soundsQuickFade);
  }

  // ---- fades and the ticker ------------------------------------------------------

  static int _steps(Duration d) =>
      (d.inMicroseconds / soundsTick.inMicroseconds).ceil().clamp(1, 1 << 20);

  void _rampMaster(double target, Duration over, {VoidCallback? onDone}) {
    _masterTarget = target;
    _masterStep = (target - _master) / _steps(over);
    _onMasterDone = onDone;
    if (_masterStep == 0) {
      _onMasterDone = null;
      onDone?.call();
    }
    _ensureTicker();
  }

  void _fadeVoice(_Voice v, double target, Duration over) {
    v.fadeTarget = target;
    v.fadeStep = (target - v.fade) / _steps(over);
    _ensureTicker();
  }

  bool get _ramping =>
      _master != _masterTarget ||
      _voices.values.any((v) => v.fade != v.fadeTarget) ||
      _retiring.isNotEmpty;

  void _ensureTicker() {
    if (_ticker != null) return;
    if (!state.isPlaying && !_ramping) return;
    _ticker = Timer.periodic(soundsTick, (_) => _tick());
  }

  static double _approach(double value, double target, double step) {
    final next = value + step;
    if (step == 0) return target;
    return (step > 0 ? next >= target : next <= target) ? target : next;
  }

  void _tick() {
    if (_master != _masterTarget) {
      _master = _approach(_master, _masterTarget, _masterStep);
      if (_master == _masterTarget) {
        final done = _onMasterDone;
        _onMasterDone = null;
        done?.call();
      }
    }
    for (final v in [..._voices.values, ..._retiring]) {
      if (v.fade != v.fadeTarget) {
        v.fade = _approach(v.fade, v.fadeTarget, v.fadeStep);
      }
    }
    for (final v in _retiring.toList()) {
      if (v.fade == 0) {
        _retiring.remove(v);
        final layer = v.layer;
        v.layer = null;
        if (layer != null) unawaited(layer.dispose());
      }
    }
    if (state.isPlaying) _advanceClock();
    _applyVolumes();
    if (!state.isPlaying && !_ramping) {
      _ticker?.cancel();
      _ticker = null;
      if (state.isIdle) unawaited(_backend.release());
    }
  }

  void _advanceClock() {
    _heard += soundsTick;
    final shared = _shared;
    if (shared != null) {
      final envelope = shared.plan;
      if (envelope != null && envelope.isOver(shared.elapsed())) {
        _endSession();
      }
      return;
    }
    final plan = state.windDown;
    if (plan != null) {
      _windElapsed += soundsTick;
      if (plan.isOver(_windElapsed)) {
        _endSession();
        return;
      }
      final left = plan.length - _windElapsed;
      if (_minutes(left) != _minutes(state.windDownLeft)) {
        state = state.copyWith(windDownLeft: left);
      }
      return;
    }
    final left = _timerLeft;
    if (left == null) return;
    final next = left - soundsTick;
    _timerLeft = next;
    if (next <= Duration.zero) {
      _endSession();
      return;
    }
    if (next <= soundsTimerFade && !state.fadingOut) {
      state = state.copyWith(fadingOut: true, timerLeft: next);
      _startTimerFade();
    } else if (_minutes(next) != _minutes(state.timerLeft)) {
      state = state.copyWith(timerLeft: next);
    }
  }

  /// The closing fade: to silence by the time the timer ends.
  void _startTimerFade() {
    final left = _timerLeft ?? Duration.zero;
    _rampMaster(0, left <= Duration.zero ? soundsTick : left);
  }

  static int? _minutes(Duration? d) =>
      d == null ? null : (d.inMilliseconds / 60000).ceil();

  void _applyVolumes() {
    final plan = state.windDown;
    final shared = _shared;
    final gains =
        plan?.gainsAt(_windElapsed) ??
        shared?.plan?.gainsAt(shared.elapsed());
    final level = shared != null ? state.sharedLevel : 1.0;
    for (final v in [..._voices.values, ..._retiring]) {
      final layer = v.layer;
      if (layer == null) continue;
      final base = gains != null
          ? gains[v.stemId] ?? 0
          : state.volumeOf(v.stemId) ?? 0;
      final master = v.retiredMaster ?? _master;
      final volume = (base * level * v.fade * master * _duck).clamp(
        0.0,
        1.0,
      );
      if ((volume - v.sent).abs() > 0.002 || (volume == 0 && v.sent != 0)) {
        v.sent = volume;
        layer.setVolume(volume);
      }
    }
  }

  // ---- outside events ------------------------------------------------------------

  void _onInterruption(SoundsInterruption event) {
    switch (event) {
      case SoundsInterruption.pause:
        if (state.isPlaying) {
          pause();
          _pausedByInterruption = true;
        }
      case SoundsInterruption.resume:
        if (state.phase == SoundsPhase.paused && _pausedByInterruption) {
          play();
        }
      case SoundsInterruption.noisy:
        // Headphones out: pause and stay paused (never to the speaker).
        if (state.isPlaying) pause();
        _pausedByInterruption = false;
      case SoundsInterruption.duck:
        _duck = soundsDuckLevel;
        _applyVolumes();
      case SoundsInterruption.unduck:
        _duck = 1;
        _applyVolumes();
    }
  }

  void _publishMedia() {
    try {
      _backend.updateMediaState(
        active: !state.isIdle,
        playing: state.isPlaying,
      );
    } on Object catch (e) {
      debugPrint('sounds: media state failed (${e.runtimeType})');
    }
  }

  void _dispose() {
    _ticker?.cancel();
    _ticker = null;
    unawaited(_interruptions?.cancel());
    for (final v in [..._voices.values, ..._retiring]) {
      final layer = v.layer;
      v.layer = null;
      if (layer != null) unawaited(layer.dispose());
    }
    _voices.clear();
    _retiring.clear();
  }
}
