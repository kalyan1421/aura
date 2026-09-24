import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sanctuary_session_log.dart';

/// A finished Sounds session as PRD 10-data-model's `sanctuary_sessions`
/// row describes it: content-free (no stems, no text, no audio, no mood).
///
/// - [activity]: `sounds` (a mix) or `night_wind_down`.
/// - [variant]: `timer_15` / `timer_30` / `timer_60` when a timer was set,
///   `open` otherwise; `v1` for the wind-down.
/// - [durationS]: seconds actually heard (paused time excluded).
/// - [localDay]: the Aura day it started.
@immutable
class SoundsSessionRecord {
  const SoundsSessionRecord({
    required this.activity,
    required this.variant,
    required this.durationS,
    required this.localDay,
  });

  final String activity;
  final String variant;
  final int durationS;
  final LocalDay localDay;

  @override
  String toString() =>
      'SoundsSessionRecord($activity, $variant, ${durationS}s, $localDay)';
}

/// Where finished Sounds sessions go.
///
/// PRD 06d: "A finished activity writes one content-free session record
/// … through POST /v1/sync/push". A session ends when it stops (Stop, the
/// timer's fade, the wind-down thinning to silence) with at least a second
/// heard; [soundsSessionLogProvider] writes it as a `sanctuary_session`
/// (activity `sounds` or `night_wind_down`) through the outbox.
abstract interface class SoundsSessionLog {
  Future<void> record(SoundsSessionRecord session);
}

class NoopSoundsSessionLog implements SoundsSessionLog {
  const NoopSoundsSessionLog();

  @override
  Future<void> record(SoundsSessionRecord session) async {}
}

/// Sounds sessions as Sanctuary session records (sanctuary_session_log.dart).
class SanctuarySoundsSessionLog implements SoundsSessionLog {
  const SanctuarySoundsSessionLog(this._log);

  final SanctuarySessionLog _log;

  @override
  Future<void> record(SoundsSessionRecord session) => _log.record(
    SanctuarySession(
      activity: session.activity,
      variant: session.variant,
      durationS: session.durationS,
      localDay: session.localDay,
    ),
  );
}

final soundsSessionLogProvider = Provider<SoundsSessionLog>(
  (ref) => SanctuarySoundsSessionLog(ref.watch(sanctuarySessionLogProvider)),
);
