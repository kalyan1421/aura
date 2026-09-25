import 'package:flutter/foundation.dart';

import '../rooms/room_models.dart' show GestureType;

/// F16 Quiet Together wire shapes (contracts/api/v1-quiet.md "Shared
/// shapes"). There are no people in here: other people exist only as a
/// [QuietSession.count] (REQ-QUIET-01). Plain immutable classes: no codegen.

/// Study, read or rest (PRD F16 "Modes"). Choosing one isn't browsing people.
enum QuietMode {
  study('study'),
  read('read'),
  rest('rest');

  const QuietMode(this.wire);

  final String wire;

  static QuietMode? fromWire(Object? v) {
    for (final m in values) {
      if (m.wire == v) return m;
    }
    return null;
  }
}

/// One stem of the shared soundscape and its gain in the mix.
@immutable
class QuietStem {
  const QuietStem(this.id, this.gain);

  final String id;
  final double gain;
}

/// The optional 25/5 focus rhythm (Study only), from the block's start.
@immutable
class QuietRhythm {
  const QuietRhythm({this.focusMin = 25, this.breakMin = 5});

  final int focusMin;
  final int breakMin;
}

@immutable
class QuietSession {
  const QuietSession({
    required this.sessionId,
    required this.mode,
    required this.t0Ms,
    required this.endsAtMs,
    required this.count,
    required this.stems,
    required this.serverTimeMs,
    this.rhythm,
    this.gestureMinIntervalMs = 10000,
    this.heartbeatMs = 30000,
    this.topic,
  });

  factory QuietSession.fromJson(Map<String, dynamic> j) {
    final sound = j['soundscape'];
    final stems = sound is Map && sound['stems'] is List
        ? [
            for (final s in sound['stems'] as List)
              if (s is Map && s['id'] is String)
                QuietStem(
                  s['id'] as String,
                  (s['gain'] is num ? (s['gain'] as num).toDouble() : 0.5)
                      .clamp(0.0, 1.0),
                ),
          ]
        : const <QuietStem>[];
    final rhythm = j['rhythm'];
    final gestures = j['gestures'];
    final realtime = j['realtime'];
    int n(Object? v, int fallback) => v is num ? v.toInt() : fallback;
    return QuietSession(
      sessionId: j['sessionId'] as String,
      mode: QuietMode.fromWire(j['mode']) ?? QuietMode.study,
      t0Ms: n(j['t0Ms'], 0),
      endsAtMs: n(j['endsAtMs'], 0),
      count: n(j['count'], 1),
      stems: stems,
      serverTimeMs: n(j['serverTimeMs'], 0),
      rhythm: rhythm is Map
          ? QuietRhythm(
              focusMin: n(rhythm['focusMin'], 25),
              breakMin: n(rhythm['breakMin'], 5),
            )
          : null,
      gestureMinIntervalMs: gestures is Map
          ? n(gestures['minIntervalMs'], 10000)
          : 10000,
      heartbeatMs: n(j['heartbeatMs'], 30000),
      topic: realtime is Map && realtime['topic'] is String
          ? realtime['topic'] as String
          : null,
    );
  }

  final String sessionId;
  final QuietMode mode;

  /// The block's start (server clock): the shared start for the sound and
  /// the focus rhythm.
  final int t0Ms;
  final int endsAtMs;

  /// Live people here, including you. A number, never a list.
  final int count;
  final List<QuietStem> stems;
  final int serverTimeMs;

  /// Study only; the phone keeps it off until the person turns it on.
  final QuietRhythm? rhythm;
  final int gestureMinIntervalMs;
  final int heartbeatMs;
  final String? topic;

  String get realtimeTopic => topic ?? 'quiet:$sessionId';
}

/// Where the shared focus rhythm is (REQ-QUIET-05): focus :00–:25, break
/// :25–:30, focus :30–:55, break :55–:00 from [t0Ms]. [nextChangeMs] is
/// shown as a clock time, never as a countdown.
@immutable
class RhythmMoment {
  const RhythmMoment({required this.onBreak, required this.nextChangeMs});

  final bool onBreak;
  final int nextChangeMs;
}

RhythmMoment rhythmAt(int t0Ms, int nowMs, QuietRhythm r) {
  final cycle = (r.focusMin + r.breakMin) * 60000;
  final into = ((nowMs - t0Ms) % cycle + cycle) % cycle;
  final start = nowMs - into;
  if (into < r.focusMin * 60000) {
    return RhythmMoment(
      onBreak: false,
      nextChangeMs: start + r.focusMin * 60000,
    );
  }
  return RhythmMoment(onBreak: true, nextChangeMs: start + cycle);
}

/// One unnamed gesture on screen ("Someone lit a candle"), or your own.
@immutable
class QuietMoment {
  const QuietMoment({
    required this.id,
    required this.type,
    required this.mine,
    required this.serial,
  });

  final String id;
  final GestureType type;
  final bool mine;

  /// Increases with every moment (animations key on it).
  final int serial;
}

/// Why the session can't show (calm copy for each).
enum QuietUnavailable {
  offline,
  paused,
  suspended,
  closed,
  guidelines,
  signedOut,
  failed,
}
