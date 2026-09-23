// Pure Dart on purpose: no Flutter, no timers, no I/O. The Sanctuary's
// Breathe session drives it from a ticker today; F7 Breath Ripples can drive
// the same pacer from a shared start time so everyone in a room is in step.

import 'dart:math' as math;

/// One phase of a breath.
enum BreathPhase {
  inhale,

  /// Holding after breathing in (box, 4-7-8).
  holdIn,
  exhale,

  /// Holding after breathing out (box).
  holdOut,
}

/// One phase of a [BreathPattern] with its place inside a breath.
final class BreathStep {
  const BreathStep(this.phase, this.start, this.length);

  final BreathPhase phase;

  /// Offset from the start of the breath.
  final Duration start;
  final Duration length;

  Duration get end => start + length;
}

/// A breathing rhythm: how long each phase of one breath lasts. [inhale] and
/// [exhale] must be positive; holds may be zero (they are then skipped).
final class BreathPattern {
  const BreathPattern({
    required this.id,
    required this.inhale,
    this.holdIn = Duration.zero,
    required this.exhale,
    this.holdOut = Duration.zero,
    this.lightHeadedCaution = false,
  });

  /// Calm (the default): in for 4, out for 6.
  static const BreathPattern calm = BreathPattern(
    id: 'calm',
    inhale: Duration(seconds: 4),
    exhale: Duration(seconds: 6),
  );

  /// Box: in, hold, out, hold, 4 s each.
  static const BreathPattern box = BreathPattern(
    id: 'box',
    inhale: Duration(seconds: 4),
    holdIn: Duration(seconds: 4),
    exhale: Duration(seconds: 4),
    holdOut: Duration(seconds: 4),
  );

  /// 4-7-8: in for 4, hold for 7, out for 8. Long holds can make some
  /// people light-headed, so it carries a gentle "stop if…" note.
  static const BreathPattern fourSevenEight = BreathPattern(
    id: '478',
    inhale: Duration(seconds: 4),
    holdIn: Duration(seconds: 7),
    exhale: Duration(seconds: 8),
    lightHeadedCaution: true,
  );

  /// The patterns the Sanctuary offers, default first.
  static const List<BreathPattern> values = [calm, box, fourSevenEight];

  /// A shipped pattern by [id], or `null`.
  static BreathPattern? byId(String id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Stable id (`calm`, `box`, `478`), e.g. for a remembered choice.
  final String id;
  final Duration inhale;
  final Duration holdIn;
  final Duration exhale;
  final Duration holdOut;

  /// Show "If you feel light-headed, stop and breathe normally".
  final bool lightHeadedCaution;

  /// One whole breath.
  Duration get breath => inhale + holdIn + exhale + holdOut;

  /// The phases of one breath in order, zero-length holds left out.
  List<BreathStep> get steps {
    final out = <BreathStep>[];
    var at = Duration.zero;
    for (final (phase, length) in [
      (BreathPhase.inhale, inhale),
      (BreathPhase.holdIn, holdIn),
      (BreathPhase.exhale, exhale),
      (BreathPhase.holdOut, holdOut),
    ]) {
      if (length <= Duration.zero) continue;
      out.add(BreathStep(phase, at, length));
      at += length;
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is BreathPattern &&
      other.id == id &&
      other.inhale == inhale &&
      other.holdIn == holdIn &&
      other.exhale == exhale &&
      other.holdOut == holdOut &&
      other.lightHeadedCaution == lightHeadedCaution;

  @override
  int get hashCode =>
      Object.hash(id, inhale, holdIn, exhale, holdOut, lightHeadedCaution);

  @override
  String toString() => 'BreathPattern($id)';
}

/// Where a [BreathPacer] is at one instant.
final class BreathMoment {
  const BreathMoment({
    required this.elapsed,
    required this.phase,
    required this.phaseProgress,
    required this.phaseRemaining,
    required this.breath,
    required this.step,
    required this.fill,
    required this.progress,
    required this.done,
  });

  /// Active time into the session (pauses excluded), clamped to the
  /// session's length.
  final Duration elapsed;
  final BreathPhase phase;

  /// 0–1 through [phase].
  final double phaseProgress;
  final Duration phaseRemaining;

  /// 0-based index of the current breath.
  final int breath;

  /// 0-based index of the current phase across the whole session. It only
  /// changes at a phase boundary, so a change means "a new phase began"
  /// (cue a haptic, update a live region).
  final int step;

  /// How full the lungs are, 0–1: eases up while breathing in, stays full
  /// through a hold after it, eases down while breathing out, stays empty
  /// through a hold after that. Drives the orb's size.
  final double fill;

  /// 0–1 through a timed session; `null` when open-ended.
  final double? progress;

  /// A timed session has ended (never for open-ended ones).
  final bool done;

  @override
  String toString() =>
      'BreathMoment(${phase.name} ${phaseProgress.toStringAsFixed(2)}, '
      'breath $breath, step $step${done ? ', done' : ''})';
}

/// A time-driven breathing pacer. Pure: the caller passes active elapsed
/// time (pauses excluded) and the pacer says which phase that is, how far
/// through it, and how full the breath is. The same inputs always give the
/// same answer, so it is trivially testable and can be shared: F7 Breath
/// Ripples can feed it `now − sharedStart`.
///
/// A timed session never ends mid-breath: [length] is rounded up to whole
/// breaths ([total]), e.g. box breathing for 1 minute is 4 breaths (64 s).
final class BreathPacer {
  const BreathPacer({this.pattern = BreathPattern.calm, this.length});

  final BreathPattern pattern;

  /// What was asked for; `null` = open-ended (until the person stops). A
  /// timed session is always at least one breath.
  final Duration? length;

  bool get openEnded => length == null;

  /// Whole breaths in a timed session (at least 1); `null` when open-ended.
  int? get breaths {
    final l = length;
    if (l == null) return null;
    final per = pattern.breath.inMicroseconds;
    return math.max(1, (l.inMicroseconds + per - 1) ~/ per);
  }

  /// The session's real length: [length] rounded up to whole breaths;
  /// `null` when open-ended.
  Duration? get total {
    final n = breaths;
    return n == null ? null : pattern.breath * n;
  }

  /// The pacer at [elapsed] active time.
  BreathMoment at(Duration elapsed) {
    final steps = pattern.steps;
    final cycle = pattern.breath.inMicroseconds;
    final end = total;
    var t = elapsed < Duration.zero ? Duration.zero : elapsed;
    final done = end != null && t >= end;
    if (done) t = end;

    final int breath;
    final int inBreath;
    if (done) {
      // The very end: the last phase of the last breath, complete.
      breath = breaths! - 1;
      inBreath = cycle;
    } else {
      breath = t.inMicroseconds ~/ cycle;
      inBreath = t.inMicroseconds - breath * cycle;
    }
    var i = 0;
    while (i < steps.length - 1 && inBreath >= steps[i].end.inMicroseconds) {
      i++;
    }
    final s = steps[i];
    final into = (inBreath - s.start.inMicroseconds).clamp(
      0,
      s.length.inMicroseconds,
    );
    final p = into / s.length.inMicroseconds;
    return BreathMoment(
      elapsed: t,
      phase: s.phase,
      phaseProgress: p,
      phaseRemaining: Duration(microseconds: s.length.inMicroseconds - into),
      breath: breath,
      step: breath * steps.length + i,
      fill: _fill(s.phase, p),
      progress: end == null ? null : t.inMicroseconds / end.inMicroseconds,
      done: done,
    );
  }

  /// The next phase boundary strictly after [elapsed] (for a one-shot timer
  /// instead of a frame ticker), or `null` once a timed session is over.
  Duration? nextBoundary(Duration elapsed) {
    final t = elapsed < Duration.zero ? Duration.zero : elapsed;
    final end = total;
    if (end != null && t >= end) return null;
    final cycle = pattern.breath.inMicroseconds;
    final breathStart = t.inMicroseconds ~/ cycle * cycle;
    for (final s in pattern.steps) {
      final boundary = Duration(
        microseconds: breathStart + s.end.inMicroseconds,
      );
      if (boundary > t) {
        return end != null && boundary > end ? end : boundary;
      }
    }
    return Duration(microseconds: breathStart + cycle); // unreachable
  }

  static double _fill(BreathPhase phase, double p) => switch (phase) {
    BreathPhase.inhale => _ease(p),
    BreathPhase.holdIn => 1,
    BreathPhase.exhale => 1 - _ease(p),
    BreathPhase.holdOut => 0,
  };

  /// Sine ease-in-out: a breath starts and ends softly.
  static double _ease(double t) => 0.5 - 0.5 * math.cos(math.pi * t);
}
