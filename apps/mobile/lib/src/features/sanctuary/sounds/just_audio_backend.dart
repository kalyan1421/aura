import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'sounds_backend.dart';

/// The real Sounds backend: one just_audio player per layer, audio_session
/// for focus, calls and headphones, and audio_service for the lock-screen /
/// notification controls and (Android) the media-playback foreground
/// service that keeps sound going with the screen off.
///
/// Nothing is set up until the first tap on a sound ([prepare]); the audio
/// session is released when Sounds stop, so other apps can resume.
class JustAudioSoundsBackend implements SoundsBackend {
  JustAudioSoundsBackend({required this._channelName});

  /// Android notification channel for the playback controls (PRD
  /// 15-permissions: "Sounds playback (media controls)").
  static const String channelId = 'sounds';

  final String Function() _channelName;
  final StreamController<SoundsInterruption> _interruptions =
      StreamController.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];
  AudioSession? _session;
  _SoundsHandler? _handler;
  SoundsTransport? _transport;
  Future<void>? _preparing;

  @override
  Stream<SoundsInterruption> get interruptions => _interruptions.stream;

  @override
  void bindTransport(SoundsTransport transport) => _transport = transport;

  @override
  Future<void> prepare() => _preparing ??= _prepare();

  Future<void> _prepare() async {
    try {
      final session = await AudioSession.instance;
      // Playback that continues with the screen locked and ignores the
      // silent switch (the person chose it). Not mixable: Sounds own the
      // audio while they play, which is also what gives them lock-screen
      // controls on iOS.
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );
      _session = session;
      _subs
        ..add(
          session.interruptionEventStream.listen((e) {
            final SoundsInterruption? event = switch (e.type) {
              AudioInterruptionType.duck =>
                e.begin ? SoundsInterruption.duck : SoundsInterruption.unduck,
              // Ended with "should resume" (a call that finished).
              AudioInterruptionType.pause =>
                e.begin ? SoundsInterruption.pause : SoundsInterruption.resume,
              // Maybe for good (another app took over): stay paused.
              AudioInterruptionType.unknown =>
                e.begin ? SoundsInterruption.pause : null,
            };
            if (event != null) _interruptions.add(event);
          }),
        )
        ..add(
          session.becomingNoisyEventStream.listen(
            (_) => _interruptions.add(SoundsInterruption.noisy),
          ),
        );
    } on Object catch (e) {
      debugPrint('sounds: audio session setup failed (${e.runtimeType})');
    }
    try {
      _handler = await AudioService.init(
        builder: () => _SoundsHandler(this),
        config: AudioServiceConfig(
          androidNotificationChannelId: channelId,
          androidNotificationChannelName: _channelName(),
          androidNotificationIcon: 'drawable/ic_stat_aura',
          androidStopForegroundOnPause: true,
        ),
      );
    } on Object catch (e) {
      // Sound still plays; only the lock-screen controls are missing.
      debugPrint('sounds: media controls unavailable (${e.runtimeType})');
    }
  }

  @override
  Future<SoundsLayer> openLayer(String path, {required int seed}) async {
    final player = AudioPlayer(
      // Interruptions are handled once for the whole mix (SoundsController),
      // not per player.
      handleInterruptions: false,
    );
    try {
      await player.setVolume(0);
      final duration = await player.setFilePath(path);
      await player.setLoopMode(LoopMode.one);
      final ms = duration?.inMilliseconds ?? 0;
      if (ms > 2000) {
        await player.seek(Duration(milliseconds: seed.abs() % ms));
      }
      return _JustAudioLayer(player);
    } on Object {
      await player.dispose();
      rethrow;
    }
  }

  @override
  void updateMediaState({required bool active, required bool playing}) =>
      _handler?.publish(active: active, playing: playing);

  @override
  Future<void> release() async {
    try {
      await _session?.setActive(
        false,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      );
    } on Object catch (e) {
      debugPrint('sounds: session release failed (${e.runtimeType})');
    }
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _interruptions.close();
  }
}

class _JustAudioLayer implements SoundsLayer {
  _JustAudioLayer(this._player);

  final AudioPlayer _player;

  // just_audio's play() completes only when playback stops: never awaited.
  @override
  Future<void> play() async => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  @override
  void setVolume(double volume) =>
      unawaited(_player.setVolume(volume.clamp(0.0, 1.0)));

  @override
  Future<void> dispose() => _player.dispose();
}

/// The media session: one item titled "Aura · Sounds", with play / pause
/// and stop. No seek, no queue, no artwork, no stem names.
class _SoundsHandler extends BaseAudioHandler {
  _SoundsHandler(this._backend);

  final JustAudioSoundsBackend _backend;

  static const MediaItem _item = MediaItem(
    id: 'aura-sounds',
    title: soundsMediaTitle,
  );

  void publish({required bool active, required bool playing}) {
    if (!active) {
      playbackState.add(
        PlaybackState(processingState: AudioProcessingState.idle),
      );
      return;
    }
    mediaItem.add(_item);
    playbackState.add(
      PlaybackState(
        controls: [
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1],
        processingState: AudioProcessingState.ready,
        playing: playing,
      ),
    );
  }

  @override
  Future<void> play() async => _backend._transport?.play();

  @override
  Future<void> pause() async => _backend._transport?.pause();

  @override
  Future<void> stop() async => _backend._transport?.stop();

  // Swiping the app away stops the sound (and the foreground service).
  @override
  Future<void> onTaskRemoved() async => _backend._transport?.stop();
}
