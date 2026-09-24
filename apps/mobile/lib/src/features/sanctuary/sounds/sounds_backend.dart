import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import 'just_audio_backend.dart';

/// The audio side of Sounds, behind an interface so the mixer, timer and
/// wind-down logic are tested with a fake (no platform channels).

/// Something outside the app changed what Sounds may do.
enum SoundsInterruption {
  /// A call, an alarm or another app took the audio: pause.
  pause,

  /// That interruption ended and the system says playback may resume.
  resume,

  /// Another sound needs a moment (a notification): play quieter.
  duck,

  /// It passed.
  unduck,

  /// Headphones were unplugged or disconnected: pause, never move to the
  /// speaker (REQ-SAN-10).
  noisy,
}

/// The lock-screen / notification controls (and headset buttons) calling
/// back into Sounds.
abstract interface class SoundsTransport {
  void play();
  void pause();
  void stop();
}

/// One looping layer of the mix.
abstract interface class SoundsLayer {
  Future<void> play();
  Future<void> pause();

  /// 0…1. Called often while fading; must be cheap.
  void setVolume(double volume);
  Future<void> dispose();
}

abstract interface class SoundsBackend {
  /// Sets up the audio session and the media controls. Idempotent; called
  /// before the first sound plays (never at app start: nothing is set up
  /// until the person taps).
  Future<void> prepare();

  /// Opens [path] as a seamless loop at volume 0, starting from a point
  /// picked with [seed] (a random loop point, so a mix never starts the
  /// same way twice).
  Future<SoundsLayer> openLayer(String path, {required int seed});

  /// Calls, other apps, ducking and headphones (after [prepare]).
  Stream<SoundsInterruption> get interruptions;

  /// Where the media controls send play / pause / stop.
  void bindTransport(SoundsTransport transport);

  /// Keeps the lock-screen / notification controls in step. They only ever
  /// read "Aura · Sounds": stem names stay hidden ("Rain" is also a
  /// quadrant). [active] false removes them.
  void updateMediaState({required bool active, required bool playing});

  /// Releases the audio session when nothing is playing (other apps may
  /// resume).
  Future<void> release();
}

/// The name the controls show (PRD 06d: only "Aura · Sounds").
const String soundsMediaTitle = 'Aura · Sounds';

final soundsBackendProvider = Provider<SoundsBackend>((ref) {
  final backend = JustAudioSoundsBackend(
    channelName: () {
      final tag = ref.read(localeControllerProvider);
      return lookupAppLocalizations(
        localeFromTag(tag),
      ).sounds_notificationChannel;
    },
  );
  ref.onDispose(backend.dispose);
  return backend;
});
