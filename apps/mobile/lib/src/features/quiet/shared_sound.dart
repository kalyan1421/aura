import 'package:aura_domain/aura_domain.dart';

import '../ripples/ripple_engine.dart' show ServerClock;
import '../sanctuary/sounds/sounds_controller.dart';
import '../sanctuary/sounds/wind_down.dart';
import 'quiet_models.dart';

/// The shared soundscapes (PRD F16 "Shared soundscape, played locally"):
/// base stems from the phone's own cache, positioned at `now − t0` on the
/// server-corrected clock, so phones that joined minutes apart hear the same
/// moment. Played through the Sanctuary Sounds engine (background audio,
/// lock-screen "Aura · Sounds", calls and headphones handled there). No
/// microphone, no audio between users.

/// A Quiet Together session's mix.
SharedSound quietSharedSound(
  QuietSession session,
  ServerClock clock,
  int Function() wallMs,
) => SharedSound(
  key: quietSoundKey(session.sessionId),
  layers: [for (final s in session.stems) SoundsLayerState(s.id, s.gain)],
  elapsed: () =>
      Duration(milliseconds: clock.toServer(wallMs()) - session.t0Ms),
);

String quietSoundKey(String sessionId) => 'quiet:$sessionId';

/// The Lantern Hour wind-down's one ambient track: the server's lineup under
/// the F15 night wind-down envelope, from the common `t0` (it thins out to
/// silence and ends by itself).
SharedSound windDownSharedSound({
  required String roomId,
  required List<String> stems,
  required int t0Ms,
  required LocalDay day,
  required ServerClock clock,
  required int Function() wallMs,
}) {
  final plan = windDownPlanWith(day, stems);
  return SharedSound(
    key: windDownSoundKey(roomId),
    layers: [for (final id in plan.order) SoundsLayerState(id, 1)],
    elapsed: () => Duration(milliseconds: clock.toServer(wallMs()) - t0Ms),
    plan: plan,
  );
}

String windDownSoundKey(String roomId) => 'wind_down:$roomId';
