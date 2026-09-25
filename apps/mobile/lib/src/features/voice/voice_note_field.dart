import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/haptics.dart';
import '../../core/a11y/motion.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/inline_notice.dart';
import '../checkin/checkin_details.dart';
import 'voice_devices.dart';
import 'voice_loader.dart';
import 'voice_playback.dart';
import 'voice_store.dart';

/// Key/value flag: the microphone explainer was answered with "Allow" once,
/// so later mic taps go straight to the OS (which never re-prompts on iOS).
const String voiceMicExplainedKey = 'voice.mic_explained';

/// `m:ss` (voice lengths are at most a minute).
String formatVoiceTime(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Whole seconds for speech, rounded (a 59.6 s note reads "60 seconds").
int voiceSeconds(Duration d) => (d.inMilliseconds + 500) ~/ 1000;

/// Announces [message] to VoiceOver / TalkBack.
void announceVoice(BuildContext context, String message) {
  final view = View.maybeOf(context);
  if (view == null) return;
  unawaited(
    SemanticsService.sendAnnouncement(
      view,
      message,
      Directionality.of(context),
    ),
  );
}

enum _Phase { idle, starting, recording, denied, failed }

/// What a [VoiceNoteField] records into: a check-in draft (F1) or a capsule
/// draft (F4). The field keeps the recording in the draft through this; the
/// draft notifies when its voice changes.
abstract interface class VoiceDraftBinding implements Listenable {
  /// A new, unsaved recording.
  VoiceClip? get newVoice;

  /// The voice note the record already has (a check-in edit), if any.
  SavedVoice? get savedVoice;

  /// [savedVoice] is kept as it is (shown for playback).
  bool get keepsSavedVoice;

  set isRecording(bool value);

  /// The field went away mid-recording (its recording is dropped). Silent.
  void recordingDropped();

  /// A finished recording: replaces any earlier one of this draft.
  void setNewVoice(VoiceClip clip);

  /// No voice note at all.
  void removeVoice();

  /// The field registers how to finish a recording in progress, so saving
  /// never waits on (or loses) it.
  void attachRecorder(Future<void> Function()? finish);
}

/// [CheckInDraft] as a [VoiceDraftBinding] (it has these members already).
class _CheckInVoiceBinding implements VoiceDraftBinding {
  _CheckInVoiceBinding(this._d);

  final CheckInDraft _d;

  @override
  void addListener(VoidCallback listener) => _d.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _d.removeListener(listener);

  @override
  VoiceClip? get newVoice => _d.newVoice;

  @override
  SavedVoice? get savedVoice => _d.savedVoice;

  @override
  bool get keepsSavedVoice => _d.keepsSavedVoice;

  @override
  set isRecording(bool value) => _d.isRecording = value;

  @override
  void recordingDropped() => _d.recordingDropped();

  @override
  void setNewVoice(VoiceClip clip) => _d.setNewVoice(clip);

  @override
  void removeVoice() => _d.removeVoice();

  @override
  void attachRecorder(Future<void> Function()? finish) =>
      _d.attachRecorder(finish);
}

/// The voice note of a check-in draft (F1: optional, ≤ 60 s, private).
///
/// * First mic tap: a short explainer (PRD 15-permissions wording); only
///   "Allow" shows the OS prompt, "Not now" never does.
/// * Denied: "Voice is off. Type instead, or turn it on in Settings." with a
///   link to this app's page in Settings; typing works as before.
/// * Recording shows the elapsed time calmly (no countdown) and stops by
///   itself at 60 s with a calm note; it can be stopped any time. Under
///   Reduce Motion the level ring stays still.
/// * Afterwards: play/pause, record again, remove.
///
/// Save is never blocked by voice: it finishes a recording in progress
/// ([CheckInDraft.finishVoice]) and saves with it.
///
/// [VoiceNoteField.custom] records into any [VoiceDraftBinding] with its own
/// limit, storage and copy (the F4 capsule composer: ≤ 2:00, recordings kept
/// with the capsule draft).
class VoiceNoteField extends ConsumerStatefulWidget {
  const VoiceNoteField({super.key, required CheckInDraft this.draft})
    : binding = null,
      maxDuration = maxVoiceDuration,
      newRecordingPath = null,
      recordHint = null,
      limitReachedText = null,
      limitReachedExtra = null;

  const VoiceNoteField.custom({
    super.key,
    required VoiceDraftBinding this.binding,
    required this.maxDuration,
    required Future<String> Function() this.newRecordingPath,
    this.recordHint,
    this.limitReachedText,
    this.limitReachedExtra,
  }) : draft = null;

  /// The check-in draft (F1), or `null` for [VoiceNoteField.custom].
  final CheckInDraft? draft;

  /// Any other draft ([VoiceNoteField.custom]).
  final VoiceDraftBinding? binding;

  /// Recording stops by itself here.
  final Duration maxDuration;

  /// Where a new recording goes (default: the voice store's drafts).
  final Future<String> Function()? newRecordingPath;

  /// The hint under "Record a voice note" (default: the F1 minute).
  final String? recordHint;

  /// The calm note after recording stopped at [maxDuration].
  final String? limitReachedText;

  /// Shown under that note (the capsule composer's Aura Plus entry for a
  /// longer voice note, under the F12 paywall rules). Nothing else knows
  /// about Plus here: the check-in's voice note is never paywalled.
  final Widget? limitReachedExtra;

  /// How often the elapsed time advances.
  static const Duration tick = Duration(milliseconds: 250);

  @override
  ConsumerState<VoiceNoteField> createState() => _VoiceNoteFieldState();
}

class _VoiceNoteFieldState extends ConsumerState<VoiceNoteField>
    with WidgetsBindingObserver {
  VoiceRecorder? _recorder;
  _Phase _phase = _Phase.idle;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  String? _recordingPath;
  StreamSubscription<double>? _levels;
  double _level = 0;

  /// Stopped by itself at the limit: the calm note shows.
  bool _limitReached = false;

  VoicePlaybackController? _playback;
  Object? _playbackOf;

  late VoiceDraftBinding _draft = _bindingOf(widget);

  static VoiceDraftBinding _bindingOf(VoiceNoteField w) =>
      w.binding ?? _CheckInVoiceBinding(w.draft!);

  Duration get _max => widget.maxDuration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draft.attachRecorder(_finish);
    _draft.addListener(_onDraft);
  }

  @override
  void didUpdateWidget(VoiceNoteField old) {
    super.didUpdateWidget(old);
    if (old.draft != widget.draft || old.binding != widget.binding) {
      _draft
        ..attachRecorder(null)
        ..removeListener(_onDraft);
      _draft = _bindingOf(widget)
        ..attachRecorder(_finish)
        ..addListener(_onDraft);
    }
  }

  void _onDraft() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _draft
      ..attachRecorder(null)
      ..removeListener(_onDraft);
    _ticker?.cancel();
    unawaited(_levels?.cancel());
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      unawaited(() async {
        try {
          // Leaving mid-recording keeps nothing (never saved).
          if (_phase == _Phase.recording) await recorder.cancel();
        } catch (_) {}
        await recorder.dispose();
      }());
    }
    // The draft outlives this field (e.g. "Start over" collapses it).
    if (_phase == _Phase.recording) _draft.recordingDropped();
    _playback?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        // Foreground recording only (PRD 15-permissions): keep what's there.
        if (_phase == _Phase.recording) unawaited(_finish());
        unawaited(_playback?.stop());
      case AppLifecycleState.resumed:
        // Back from Settings: the mic may be on now.
        if (_phase == _Phase.denied) unawaited(_recheckPermission());
      case AppLifecycleState.inactive:
        break;
    }
  }

  VoiceRecorder get _rec =>
      _recorder ??= ref.read(voiceRecorderFactoryProvider)();

  Future<void> _recheckPermission() async {
    try {
      if (await _rec.hasPermission() && mounted) {
        setState(() => _phase = _Phase.idle);
      }
    } catch (_) {}
  }

  // ---- recording ---------------------------------------------------------

  Future<void> _onRecord() async {
    if (_phase == _Phase.starting || _phase == _Phase.recording) return;
    AuraHaptics.selection();
    final recorder = _rec;
    setState(() => _phase = _Phase.starting);
    try {
      var granted = await recorder.hasPermission();
      if (!granted) {
        final kv = ref.read(kvStoreProvider);
        if (await kv.get(voiceMicExplainedKey) == null) {
          if (!mounted) return;
          final allow = await showVoiceExplainer(context);
          if (allow != true) {
            // "Not now": no OS prompt; the mic stays as it was.
            if (mounted) setState(() => _phase = _Phase.idle);
            return;
          }
          await kv.set(voiceMicExplainedKey, '1');
        }
        granted = await recorder.hasPermission(request: true);
      }
      if (!mounted) return;
      if (!granted) {
        setState(() => _phase = _Phase.denied);
        return;
      }
      await _start(recorder);
    } catch (e) {
      debugPrint('voice: record ${e.runtimeType}');
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _start(VoiceRecorder recorder) async {
    await _playback?.stop();
    final path =
        await (widget.newRecordingPath ??
            ref.read(voiceStoreProvider).newDraftPath)();
    await recorder.start(path);
    if (!mounted) {
      await recorder.cancel();
      return;
    }
    final l = AppLocalizations.of(context);
    final reduce = reduceMotionOf(context);
    _recordingPath = path;
    setState(() {
      _elapsed = Duration.zero;
      _level = 0;
      _limitReached = false;
      _phase = _Phase.recording;
    });
    _draft.isRecording = true;
    _ticker = Timer.periodic(VoiceNoteField.tick, (t) {
      final elapsed = VoiceNoteField.tick * t.tick;
      if (elapsed >= _max) {
        _elapsed = _max;
        unawaited(_finish(atLimit: true));
      } else if (mounted) {
        setState(() => _elapsed = elapsed);
      }
    });
    // Reduce Motion: no moving level ring at all.
    if (!reduce) {
      _levels = recorder.levels().listen((v) {
        if (mounted) setState(() => _level = v);
      }, onError: (Object _) {});
    }
    announceVoice(context, l.voice_started);
  }

  /// Stops a recording in progress and keeps it in the draft.
  Future<void> _finish({bool atLimit = false}) async {
    if (_phase != _Phase.recording) return;
    _ticker?.cancel();
    _ticker = null;
    unawaited(_levels?.cancel());
    _levels = null;
    final elapsed = _elapsed > _max ? _max : _elapsed;
    String? out;
    try {
      out = await _recorder?.stop();
    } catch (e) {
      debugPrint('voice: stop ${e.runtimeType}');
    }
    final path = out ?? _recordingPath;
    _recordingPath = null;
    _draft.isRecording = false;
    if (path == null || elapsed == Duration.zero) {
      if (mounted) setState(() => _phase = _Phase.failed);
      return;
    }
    _draft.setNewVoice(VoiceClip(path: path, duration: elapsed));
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _limitReached = atLimit;
    });
    final l = AppLocalizations.of(context);
    announceVoice(context, l.voice_recorded(voiceSeconds(elapsed)));
    _revealActions();
  }

  Timer? _revealTimer;

  /// The recorded card is taller than the recording row: once it has grown
  /// in (and any AnimatedSize around it has settled), scroll just enough to
  /// show "Record again / Remove" above the screen's pinned Save.
  void _revealActions() {
    _revealTimer?.cancel();
    final reduce = reduceMotionOf(context);
    _revealTimer = Timer(
      reduce ? Duration.zero : AuraMotion.calm + AuraMotion.quick,
      () {
        _revealTimer = null;
        if (!mounted) return;
        unawaited(
          Scrollable.ensureVisible(
            context,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            duration: reduce ? Duration.zero : AuraMotion.quick,
            curve: AuraMotion.ease,
          ),
        );
      },
    );
  }

  void _remove() {
    AuraHaptics.selection();
    unawaited(_playback?.stop());
    setState(() => _limitReached = false);
    _draft.removeVoice();
  }

  // ---- playback ------------------------------------------------------------

  /// The controller for what the draft holds now (a new recording or the
  /// saved one), rebuilt when that changes.
  VoicePlaybackController? _playbackFor(VoiceClip? clip, SavedVoice? saved) {
    final Object? of = clip ?? saved;
    if (of == null) {
      _disposePlayback();
      return null;
    }
    if (identical(of, _playbackOf) && _playback != null) return _playback;
    _disposePlayback();
    final store = ref.read(voiceStoreProvider);
    final c = VoicePlaybackController(
      createPlayer: ref.read(voicePlayerFactoryProvider),
      load: clip != null
          ? () async => VoiceSource(clip.path)
          : () => ref
                .read(voiceLoaderProvider)
                .load(
                  checkInId: saved!.checkInId,
                  file: saved.file,
                  path: saved.path,
                ),
      deleteTemp: store.deleteTemp,
      duration: clip?.duration ?? saved?.duration,
    );
    _playbackOf = of;
    return _playback = c;
  }

  void _disposePlayback() {
    final c = _playback;
    _playback = null;
    _playbackOf = null;
    if (c != null) {
      // After this frame: its row is still mounted in this one.
      WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final clip = _draft.newVoice;
    final saved = _draft.keepsSavedVoice ? _draft.savedVoice : null;
    final recording = _phase == _Phase.recording;
    final hasVoice = !recording && (clip != null || saved != null);
    final playback = hasVoice ? _playbackFor(clip, saved) : null;
    if (!hasVoice && _playback != null && !recording) _playbackFor(null, null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: recording
              ? _RecordingRow(
                  elapsed: _elapsed,
                  limit: _max,
                  level: _level,
                  onStop: () {
                    AuraHaptics.selection();
                    unawaited(_finish());
                  },
                )
              : hasVoice
              ? _VoiceRow(
                  controller: playback!,
                  actions: [
                    TextButton.icon(
                      key: const ValueKey('voice-rerecord'),
                      onPressed: _phase == _Phase.starting ? null : _onRecord,
                      icon: const Icon(Icons.mic_none_rounded),
                      label: Text(l.voice_reRecord),
                    ),
                    Semantics(
                      label: l.voice_removeSemantic,
                      button: true,
                      excludeSemantics: true,
                      onTap: _remove,
                      child: TextButton.icon(
                        key: const ValueKey('voice-remove'),
                        onPressed: _remove,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(l.voice_remove),
                      ),
                    ),
                  ],
                )
              : _RecordTile(
                  busy: _phase == _Phase.starting,
                  onTap: _onRecord,
                  hint: widget.recordHint ?? l.voice_recordHint,
                ),
        ),
        if (_limitReached && hasVoice) ...[
          const SizedBox(height: AuraSpace.s),
          Semantics(
            liveRegion: true,
            container: true,
            child: Text(
              widget.limitReachedText ?? l.voice_limitReached,
              key: const ValueKey('voice-limit-note'),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AuraColors.textSoft),
            ),
          ),
          if (widget.limitReachedExtra case final extra?) ...[
            const SizedBox(height: AuraSpace.s),
            extra,
          ],
        ],
        if (_phase == _Phase.denied) ...[
          const SizedBox(height: AuraSpace.s),
          InlineNotice(
            l.voice_denied,
            key: const ValueKey('voice-denied'),
            icon: Icons.mic_off_outlined,
          ),
          // Below the notice, not beside it: it must fit at 200% text.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('voice-settings'),
              onPressed: () =>
                  unawaited(ref.read(auraPlatformProvider).openAppSettings()),
              icon: const Icon(Icons.settings_outlined),
              label: Text(l.voice_openSettings),
            ),
          ),
        ],
        if (_phase == _Phase.failed) ...[
          const SizedBox(height: AuraSpace.s),
          InlineNotice(
            l.voice_recordFailed,
            key: const ValueKey('voice-failed'),
          ),
        ],
      ],
    );
  }
}

/// "Add your voice?" before the OS microphone prompt. True for "Allow".
Future<bool?> showVoiceExplainer(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      // Over the navigation bar too: a modal never leaves the tabs tappable.
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => const VoiceExplainerSheet(),
    );

class VoiceExplainerSheet extends StatelessWidget {
  const VoiceExplainerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.xl,
        AuraSpace.gutter,
        AuraSpace.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.mic_none_rounded,
              size: 40,
              color: AuraColors.lavender,
            ),
          ),
          const SizedBox(height: AuraSpace.l),
          Semantics(
            header: true,
            child: Text(
              l.voice_rationaleTitle,
              textAlign: TextAlign.center,
              style: t.headlineSmall,
            ),
          ),
          const SizedBox(height: AuraSpace.s),
          Text(
            l.voice_rationaleBody,
            key: const ValueKey('voice-explainer-body'),
            textAlign: TextAlign.center,
            style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.xl),
          FilledButton(
            key: const ValueKey('voice-allow'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.voice_rationaleAllow),
          ),
          const SizedBox(height: AuraSpace.s),
          TextButton(
            key: const ValueKey('voice-not-now'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.common_notNow),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AuraSpace.m),
    decoration: BoxDecoration(
      color: AuraColors.skyHigh,
      borderRadius: BorderRadius.circular(AuraRadius.m),
      border: Border.all(color: AuraColors.outline),
    ),
    child: child,
  );
}

/// Mic + "Record a voice note" + the limit hint; one control.
class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.busy,
    required this.onTap,
    required this.hint,
  });

  final bool busy;
  final VoidCallback onTap;

  /// The limit hint ("Up to a minute. Only you can hear it.").
  final String hint;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    // One screen-reader stop: "Record a voice note" + the limit hint.
    return Semantics(
      button: true,
      enabled: !busy,
      label: l.voice_record,
      hint: hint,
      onTap: busy ? null : onTap,
      excludeSemantics: true,
      child: Row(
        children: [
          IconButton.filledTonal(
            key: const ValueKey('voice-record'),
            tooltip: l.voice_record,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: busy ? null : onTap,
            icon: const Icon(Icons.mic_none_rounded),
          ),
          const SizedBox(width: AuraSpace.m),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: busy ? null : onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.voice_record, style: t.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
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

/// Stop + level + elapsed time. Calm: the time counts up, never down.
class _RecordingRow extends StatelessWidget {
  const _RecordingRow({
    required this.elapsed,
    required this.limit,
    required this.level,
    required this.onStop,
  });

  final Duration elapsed;

  /// Where recording stops by itself.
  final Duration limit;
  final double level;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final reduce = reduceMotionOf(context);
    const dot = DecoratedBox(
      decoration: BoxDecoration(
        color: AuraColors.accent,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(dimension: 12),
    );
    return Row(
      children: [
        IconButton.filled(
          key: const ValueKey('voice-stop'),
          tooltip: l.voice_stop,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: onStop,
          icon: const Icon(Icons.stop_rounded),
        ),
        const SizedBox(width: AuraSpace.m),
        ExcludeSemantics(
          child: SizedBox.square(
            dimension: 24,
            child: Center(
              child: reduce
                  // Reduce Motion: a still dot, no level animation.
                  ? const KeyedSubtree(
                      key: ValueKey('voice-level-still'),
                      child: dot,
                    )
                  : AnimatedScale(
                      key: const ValueKey('voice-level'),
                      scale: 1 + level.clamp(0.0, 1.0),
                      duration: AuraMotion.quick,
                      curve: AuraMotion.ease,
                      child: dot,
                    ),
            ),
          ),
        ),
        const SizedBox(width: AuraSpace.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.voice_recording, style: t.bodyLarge),
              const SizedBox(height: 2),
              Semantics(
                container: true,
                label: l.voice_recordingFor(elapsed.inSeconds),
                excludeSemantics: true,
                child: Text(
                  l.voice_elapsed(
                    formatVoiceTime(elapsed),
                    formatVoiceTime(limit),
                  ),
                  key: const ValueKey('voice-elapsed'),
                  style: t.bodySmall?.copyWith(
                    color: AuraColors.textSoft,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Play/pause, length and state of one voice note, plus optional actions
/// (record again / remove in the editor). Shared with the history entry.
class VoicePlaybackRow extends StatelessWidget {
  const VoicePlaybackRow({
    super.key,
    required this.controller,
    this.actions = const [],
  });

  final VoicePlaybackController controller;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) =>
      _VoiceRow(controller: controller, actions: actions);
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({required this.controller, this.actions = const []});

  final VoicePlaybackController controller;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final playing = state == VoicePlaybackState.playing;
        final loading = state == VoicePlaybackState.loading;
        final duration = controller.duration;
        final String? status = switch (state) {
          VoicePlaybackState.loading => l.voice_loading,
          VoicePlaybackState.offline => l.voice_offline,
          VoicePlaybackState.failed => l.voice_failed,
          _ => null,
        };
        final time = duration == null
            ? null
            : state == VoicePlaybackState.playing ||
                  state == VoicePlaybackState.paused
            ? '${formatVoiceTime(controller.position)} / '
                  '${formatVoiceTime(duration)}'
            : formatVoiceTime(duration);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: loading
                      ? Semantics(
                          label: l.voice_loading,
                          child: const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton.filledTonal(
                          key: const ValueKey('voice-play'),
                          tooltip: playing ? l.voice_pause : l.voice_play,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: () {
                            AuraHaptics.selection();
                            unawaited(controller.toggle());
                          },
                          icon: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                ),
                const SizedBox(width: AuraSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.voice_note, style: t.bodyLarge),
                      if (time != null) ...[
                        const SizedBox(height: 2),
                        Semantics(
                          container: true,
                          label: l.voice_length(voiceSeconds(duration!)),
                          excludeSemantics: true,
                          child: Text(
                            time,
                            key: const ValueKey('voice-duration'),
                            style: t.bodySmall?.copyWith(
                              color: AuraColors.textSoft,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (status != null && !loading) ...[
              const SizedBox(height: AuraSpace.s),
              Semantics(
                liveRegion: true,
                container: true,
                child: Text(
                  status,
                  key: ValueKey('voice-status-${state.name}'),
                  style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.xs),
              Wrap(
                spacing: AuraSpace.s,
                runSpacing: AuraSpace.xs,
                children: actions,
              ),
            ],
          ],
        );
      },
    );
  }
}
