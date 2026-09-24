// Pure Dart on purpose (no Flutter, no timers, no I/O): the session timeline
// on the F15 pacer engine, the on-device group sync, the player's own echo
// trace and the event budgets. The same inputs always give the same answer.

import 'dart:collection';
import 'dart:math' as math;

import '../sanctuary/breath_pacer.dart';
import 'ripple_models.dart';

/// Where a session is.
enum RippleStage {
  /// The 10 s settle-in before the first breath.
  settle,
  breathing,

  /// The 10 s fade-out after the last breath.
  fade,
  done,
}

/// A session's shared timeline: everyone's phone runs the same F15
/// [BreathPacer] from the server's `t0` (PRD F7 "the pacer runs locally from
/// `t0` on the F15 pacer engine"), so all lights are in phase without any
/// breath crossing the network.
class RippleTimeline {
  RippleTimeline(this.session)
    : pacer = BreathPacer(
        pattern: BreathPattern(
          id: 'ripples',
          inhale: Duration(milliseconds: session.inhaleMs),
          exhale: Duration(milliseconds: session.exhaleMs),
        ),
        length: Duration(milliseconds: session.cycles * session.cycleMs),
      );

  final RippleSession session;
  final BreathPacer pacer;

  int get _base => session.t0Ms + session.settleMs;
  int get transitions => 2 * session.cycles;

  RippleStage stageAt(int serverMs) {
    final rel = serverMs - session.t0Ms;
    if (rel < session.settleMs) return RippleStage.settle;
    if (rel < session.settleMs + session.cycles * session.cycleMs) {
      return RippleStage.breathing;
    }
    if (serverMs < session.endsAtMs) return RippleStage.fade;
    return RippleStage.done;
  }

  /// The pacer at [serverMs] (clamped into the breathing part).
  BreathMoment momentAt(int serverMs) =>
      pacer.at(Duration(milliseconds: math.max(0, serverMs - _base)));

  /// Transition [k] (even = an inhale starts, odd = an exhale starts).
  int transitionAt(int k) =>
      _base + (k ~/ 2) * session.cycleMs + (k.isOdd ? session.inhaleMs : 0);

  /// The same-kind transition nearest to [t], clamped into the session.
  int nearestTransition(int t, {required bool inhale}) {
    final offset = inhale ? 0 : session.inhaleMs;
    final n = ((t - _base - offset) / session.cycleMs).round();
    final cycle = n.clamp(0, session.cycles - 1);
    return 2 * cycle + (inhale ? 0 : 1);
  }

  /// Whole cycles breathed by [serverMs].
  int cyclesAt(int serverMs) =>
      ((serverMs - _base) ~/ session.cycleMs).clamp(0, session.cycles);

  /// Transitions whose moment has passed by [serverMs].
  int transitionsBy(int serverMs) {
    var k = 0;
    while (k < transitions && transitionAt(k) <= serverMs) {
      k++;
    }
    return k;
  }

  /// "In" or "out" for a light that follows the pacer shifted by
  /// [offsetMs], and how far into that phase (0–1): the lung fill.
  double pacerFill(int serverMs, {int offsetMs = 0}) {
    final m = momentAt(serverMs - offsetMs);
    return m.fill;
  }
}

/// PRD F7 "Sync" — client-side only; never shown as a number, never sent
/// (REQ-GAME-06). For each inhale / exhale start k: ref = median of the
/// seats' times, alignment = max(0, 1 − |t − ref| / 1500 ms), 0 if missed;
/// S = mean, smoothed with an EMA (α 0.3). The reference is the group
/// median, so players drifting together still count as in sync.
class GroupSync {
  GroupSync(
    this.timeline, {
    this.toleranceMs = 1500,
    this.alpha = 0.3,
    this.closeAfterMs = 2000,
  });

  final RippleTimeline timeline;
  final int toleranceMs;
  final double alpha;

  /// A transition is scored once this long after it (late events still
  /// count, up to the tolerance).
  final int closeAfterMs;

  final Map<int, Map<int, int>> _times = {};
  int _next = 0;
  double _s = 0;

  /// Smoothed group sync, 0–1.
  double get value => _s;

  /// Seat [seat] started transition [k] at [t] (the first one counts).
  void record(int seat, int k, int t) {
    if (k < _next || k >= timeline.transitions) return;
    _times.putIfAbsent(k, () => {}).putIfAbsent(seat, () => t);
  }

  /// Scores every transition that is due by [nowMs] over [seats] (every
  /// light on the ocean, missing ones count 0).
  void close(int nowMs, Iterable<int> seats) {
    final all = seats.toList();
    if (all.isEmpty) return;
    while (_next < timeline.transitions &&
        timeline.transitionAt(_next) + closeAfterMs <= nowMs) {
      final got = _times.remove(_next) ?? const <int, int>{};
      _s = alpha * alignmentOf(got, all, toleranceMs) + (1 - alpha) * _s;
      _next++;
    }
  }

  /// Mean alignment of [seats] around the median of [times].
  static double alignmentOf(
    Map<int, int> times,
    List<int> seats,
    int toleranceMs,
  ) {
    if (times.isEmpty) return 0;
    final sorted = times.values.toList()..sort();
    final mid = sorted.length ~/ 2;
    final ref = sorted.length.isOdd
        ? sorted[mid].toDouble()
        : (sorted[mid - 1] + sorted[mid]) / 2;
    var sum = 0.0;
    for (final seat in seats) {
      final t = times[seat];
      if (t == null) continue;
      sum += math.max(0, 1 - (t - ref).abs() / toleranceMs);
    }
    return sum / seats.length;
  }
}

/// Ripple radius from sync: never below the minimum (REQ-GAME-03).
double rippleRadius(double s, {double min = 0.35, double max = 1}) =>
    min + s.clamp(0, 1) * (max - min);

/// Fish: 3 at S = 0, up to 15 (REQ-GAME-03: "Minimum ripple and 3 fish").
int fishCount(double s) => 3 + (12 * s.clamp(0, 1)).round();

/// This player's own transitions relative to the pacer, in 50 ms steps
/// (`null` = missed): the echo recording, if they haven't opted out (§2.3).
class EchoTrace {
  EchoTrace(this.timeline)
    : offsets = List<int?>.filled(timeline.transitions, null);

  static const int stepMs = 50;
  static const int maxSteps = 40;

  final RippleTimeline timeline;
  final List<int?> offsets;

  /// Records a press (inhale) or release (exhale) at [t].
  void record(int t, {required bool inhale}) {
    final k = timeline.nearestTransition(t, inhale: inhale);
    final steps = ((t - timeline.transitionAt(k)) / stepMs).round();
    if (steps.abs() > maxSteps || offsets[k] != null) return;
    offsets[k] = steps;
  }

  /// The transitions that have happened by [serverMs] (what is sent).
  List<int?> upTo(int serverMs) =>
      offsets.sublist(0, timeline.transitionsBy(serverMs));

  int get hits => offsets.where((v) => v != null).length;
}

/// A sliding one-second window: at most [perSecond] events (PRD F7 "hard
/// cap 10 events/s/player": the sender throttles, receivers drop excess).
class EventBudget {
  EventBudget(this.perSecond);

  final int perSecond;
  final Queue<int> _times = Queue();

  bool allow(int nowMs) {
    while (_times.isNotEmpty && _times.first <= nowMs - 1000) {
      _times.removeFirst();
    }
    if (_times.length >= perSecond) return false;
    _times.addLast(nowMs);
    return true;
  }
}

/// At most one event per [minMs] (pulses 3 s, gestures 5 s).
class MinInterval {
  MinInterval(this.minMs);

  final int minMs;
  int? _last;

  bool allow(int nowMs) {
    final last = _last;
    if (last != null && nowMs - last < minMs) return false;
    _last = nowMs;
    return true;
  }
}

/// Estimates the server clock from request round trips: the sample with the
/// shortest round trip wins (PRD F7 "Clients estimate server clock offset at
/// lobby").
class ServerClock {
  int _offset = 0;
  int? _bestRtt;

  /// server − local, in ms.
  int get offsetMs => _offset;

  void sample({
    required int sentMs,
    required int receivedMs,
    required int serverMs,
  }) {
    final rtt = receivedMs - sentMs;
    if (rtt < 0) return;
    final best = _bestRtt;
    if (best != null && rtt > best) return;
    _bestRtt = rtt;
    _offset = serverMs - (sentMs + rtt ~/ 2);
  }

  int toServer(int localMs) => localMs + _offset;
}
