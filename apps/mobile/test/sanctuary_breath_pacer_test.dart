import 'package:aura/src/features/sanctuary/breath_pacer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pure, time-driven pacer (F15 Breathe; reused later by F7 Breath
/// Ripples): same input, same phase, with no timers.
void main() {
  Duration s(num seconds) => Duration(
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );

  group('patterns', () {
    test('calm 4/6 is the default; box 4-4-4-4; 4-7-8 with its caution', () {
      expect(const BreathPacer().pattern, BreathPattern.calm);
      expect(BreathPattern.values.first, BreathPattern.calm);
      expect(BreathPattern.calm.breath, s(10));
      expect(BreathPattern.box.breath, s(16));
      expect(BreathPattern.fourSevenEight.breath, s(19));
      expect(BreathPattern.calm.steps.map((x) => x.phase), [
        BreathPhase.inhale,
        BreathPhase.exhale,
      ]);
      expect(BreathPattern.box.steps.map((x) => x.phase), [
        BreathPhase.inhale,
        BreathPhase.holdIn,
        BreathPhase.exhale,
        BreathPhase.holdOut,
      ]);
      expect(BreathPattern.fourSevenEight.steps.map((x) => x.length), [
        s(4),
        s(7),
        s(8),
      ]);
      expect(BreathPattern.fourSevenEight.lightHeadedCaution, isTrue);
      expect(BreathPattern.calm.lightHeadedCaution, isFalse);
      expect(BreathPattern.byId('box'), BreathPattern.box);
      expect(BreathPattern.byId('nope'), isNull);
    });
  });

  group('phases over time', () {
    test('calm: in for 4 s, out for 6 s, then the next breath', () {
      const p = BreathPacer(
        pattern: BreathPattern.calm,
        length: Duration(minutes: 1),
      );
      expect(p.at(s(0)).phase, BreathPhase.inhale);
      expect(p.at(s(3.99)).phase, BreathPhase.inhale);
      expect(p.at(s(4)).phase, BreathPhase.exhale);
      expect(p.at(s(9.99)).phase, BreathPhase.exhale);
      final next = p.at(s(10));
      expect(next.phase, BreathPhase.inhale);
      expect(next.breath, 1);
      expect(p.at(s(2)).phaseProgress, closeTo(0.5, 1e-9));
      expect(p.at(s(5)).phaseRemaining, s(5));
    });

    test('box and 4-7-8 hold between in and out', () {
      const box = BreathPacer(pattern: BreathPattern.box);
      expect(
        [
          for (final t in [0, 4, 8, 12, 16]) box.at(s(t)).phase,
        ],
        [
          BreathPhase.inhale,
          BreathPhase.holdIn,
          BreathPhase.exhale,
          BreathPhase.holdOut,
          BreathPhase.inhale,
        ],
      );
      const f = BreathPacer(pattern: BreathPattern.fourSevenEight);
      expect(f.at(s(10.9)).phase, BreathPhase.holdIn);
      expect(f.at(s(11)).phase, BreathPhase.exhale);
      expect(f.at(s(19)).phase, BreathPhase.inhale);
    });

    test('the step index changes exactly at phase boundaries, and only '
        'there', () {
      const p = BreathPacer(
        pattern: BreathPattern.box,
        length: Duration(minutes: 1),
      );
      var last = p.at(Duration.zero).step;
      final changes = <Duration>[];
      for (var ms = 0; ms <= 64000; ms += 50) {
        final m = p.at(Duration(milliseconds: ms));
        if (m.step != last) changes.add(Duration(milliseconds: ms));
        last = m.step;
      }
      expect(changes.first, s(4));
      for (final c in changes) {
        expect(c.inMilliseconds % 4000, 0, reason: '$c');
      }
      // 4 breaths × 4 phases: 15 changes before the end.
      expect(changes, hasLength(15));
    });

    test('fill rises on the inhale, stays full on a hold, falls on the '
        'exhale and stays empty after it', () {
      const p = BreathPacer(pattern: BreathPattern.box);
      expect(p.at(s(0)).fill, 0);
      expect(p.at(s(2)).fill, closeTo(0.5, 1e-9));
      expect(p.at(s(1)).fill, lessThan(p.at(s(3)).fill));
      expect(p.at(s(5)).fill, 1);
      expect(p.at(s(10)).fill, closeTo(0.5, 1e-9));
      expect(p.at(s(13)).fill, 0);
    });

    test('negative time is the start', () {
      const p = BreathPacer();
      expect(p.at(s(-3)).elapsed, Duration.zero);
      expect(p.at(s(-3)).phase, BreathPhase.inhale);
    });
  });

  group('length', () {
    test('a timed session ends on a whole breath, never mid-exhale', () {
      Duration? total(BreathPattern pattern, int minutes) => BreathPacer(
        pattern: pattern,
        length: Duration(minutes: minutes),
      ).total;
      expect(total(BreathPattern.calm, 1), s(60));
      expect(total(BreathPattern.box, 1), s(64)); // 4 breaths
      expect(total(BreathPattern.fourSevenEight, 1), s(76)); // 4 cycles
      expect(total(BreathPattern.box, 3), s(192));
      expect(total(BreathPattern.calm, 5), s(300));
      expect(
        const BreathPacer(length: Duration(seconds: 30)).total,
        s(30), // "A minute for you" after Storm: three slow breaths
      );
    });

    test('at the end: done, complete, the breath let all the way out', () {
      const p = BreathPacer(length: Duration(minutes: 1));
      final end = p.at(s(60));
      expect(end.done, isTrue);
      expect(end.progress, 1);
      expect(end.fill, 0);
      expect(end.phase, BreathPhase.exhale);
      expect(p.at(s(90)).elapsed, s(60)); // clamped
      expect(p.at(s(59.9)).done, isFalse);
      expect(p.at(s(30)).progress, closeTo(0.5, 1e-9));
    });

    test('open-ended: no end, no progress', () {
      const p = BreathPacer(pattern: BreathPattern.box);
      expect(p.openEnded, isTrue);
      expect(p.total, isNull);
      final late = p.at(const Duration(hours: 2));
      expect(late.done, isFalse);
      expect(late.progress, isNull);
      expect(p.nextBoundary(const Duration(hours: 2)), isNotNull);
    });
  });

  group('nextBoundary (one-shot timers instead of a ticker)', () {
    test('the next phase change strictly after the given time', () {
      const p = BreathPacer(length: Duration(minutes: 1));
      expect(p.nextBoundary(s(0)), s(4));
      expect(p.nextBoundary(s(1)), s(4));
      expect(p.nextBoundary(s(4)), s(10));
      expect(p.nextBoundary(s(58)), s(60));
      expect(p.nextBoundary(s(60)), isNull);
      const box = BreathPacer(pattern: BreathPattern.box);
      expect(box.nextBoundary(s(13)), s(16));
    });

    test('agrees with at(): the phase changes exactly there', () {
      const p = BreathPacer(pattern: BreathPattern.fourSevenEight);
      var t = Duration.zero;
      for (var i = 0; i < 12; i++) {
        final next = p.nextBoundary(t)!;
        final before = p.at(next - const Duration(microseconds: 1));
        final after = p.at(next);
        expect(after.step, before.step + 1);
        t = next;
      }
    });
  });

  test('the same input always gives the same moment (shared start times)', () {
    const a = BreathPacer(pattern: BreathPattern.box);
    const b = BreathPacer(pattern: BreathPattern.box);
    for (final t in [0, 1234, 16000, 99999]) {
      final x = a.at(Duration(milliseconds: t));
      final y = b.at(Duration(milliseconds: t));
      expect((x.phase, x.step, x.fill), (y.phase, y.step, y.fill));
    }
  });
}
