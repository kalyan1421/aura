import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/a11y/haptics.dart';
import '../../core/env/env.dart';
import '../../core/providers.dart';
import '../../core/remote_config/remote_config_providers.dart';
import '../ripples/ripple_channel.dart';
import '../ripples/ripple_feedback.dart';
import '../ripples/ripples_providers.dart' show rippleChannelOpenerProvider;
import '../rooms/rooms_providers.dart' show roomsReadyProvider;
import '../sanctuary/breath_haptics.dart';
import '../sanctuary/breath_pacer.dart';
import 'quiet_api.dart';

/// Plain providers (no codegen). Tests override the API, the channel opener
/// and the cues.

/// `null` when this build has no API (debug builds without config).
final quietApiProvider = Provider<QuietApi?>((ref) {
  if (!Env.hasApi) return null;
  final auth = ref.watch(authRepositoryProvider);
  return HttpQuietApi(baseUrl: Env.apiUrl, accessToken: auth.accessToken);
});

/// Private Realtime channels (`quiet:<id>`, read only), or `null` without
/// Supabase: the session then runs on the heartbeat alone (never a failure).
final quietChannelOpenerProvider = Provider<RippleChannelOpener?>(
  (ref) => ref.watch(rippleChannelOpenerProvider),
);

/// Whether Quiet Together's entry shows: a signed-in, onboarded account (the
/// same as rooms) and the `quiet_enabled` kill switch on. The flag only hides
/// UI; the server decides, per region.
final quietReadyProvider = Provider<bool>(
  (ref) =>
      ref.watch(roomsReadyProvider) &&
      ref.watch(quietApiProvider) != null &&
      ref.watch(remoteFlagsProvider).quietEnabled,
);

/// Cues for the focus rhythm and the wind-down pacer (REQ-A11Y-15: each
/// change shows in at least two of text, haptics, tone).
abstract interface class QuietCues {
  /// The shared focus rhythm changed: a haptic (if on) and, only while the
  /// shared sound plays, a soft chime.
  void rhythm({required bool toBreak, required bool chime});

  /// A wind-down pacer phase began (the Sanctuary Breathe haptics).
  void breath(BreathPhase phase);

  Future<void> dispose();
}

class AuraQuietCues implements QuietCues {
  AuraQuietCues({this.tones, this.haptics = const AuraBreathHaptics()});

  final RippleTones? tones;
  final BreathHaptics haptics;

  @override
  void rhythm({required bool toBreak, required bool chime}) {
    AuraHaptics.light();
    if (chime) unawaited(tones?.play(inhale: !toBreak, volume: 0.3));
  }

  @override
  void breath(BreathPhase phase) => haptics.phaseStarted(phase);

  @override
  Future<void> dispose() async => tones?.dispose();
}

final quietCuesProvider = Provider<QuietCues>((ref) {
  final cues = AuraQuietCues(tones: JustAudioRippleTones());
  ref.onDispose(() => unawaited(cues.dispose()));
  return cues;
});
