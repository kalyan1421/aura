import 'package:aura/src/features/ripples/ripple_engine.dart';
import 'package:aura/src/features/ripples/ripple_models.dart';
import 'package:aura/src/features/sanctuary/breath_pacer.dart';
import 'package:flutter_test/flutter_test.dart';

/// F7 Breath Ripples: the pure engine (timeline on the F15 pacer, on-device
/// sync, echo trace, event budgets, server clock).
void main() {
  const s = RippleSession(
    sessionId: 's',
    entry: RippleEntry.quick,
    t0Ms: 0,
    mySeat: 1,
    seats: [],
  );
  final tl = RippleTimeline(s);

  test('the default session is 3 minutes: settle, 16 × (4 + 6), fade', () {
    expect(s.endsAtMs, 180000);
    expect(tl.stageAt(9999), RippleStage.settle);
    expect(tl.stageAt(10000), RippleStage.breathing);
    expect(tl.stageAt(169999), RippleStage.breathing);
    expect(tl.stageAt(170000), RippleStage.fade);
    expect(tl.stageAt(180000), RippleStage.done);
  });

  test('runs on the same F15 pacer engine as Sanctuary Breathe', () {
    expect(tl.pacer.pattern.inhale, BreathPattern.calm.inhale);
    expect(tl.pacer.pattern.exhale, BreathPattern.calm.exhale);
    expect(tl.momentAt(10000 + 1000).phase, BreathPhase.inhale);
    expect(tl.momentAt(10000 + 5000).phase, BreathPhase.exhale);
    expect(tl.momentAt(10000 + 10000).phase, BreathPhase.inhale);
  });

  test('transitions and the nearest one of the same kind', () {
    expect(tl.transitions, 32);
    expect(tl.transitionAt(0), 10000);
    expect(tl.transitionAt(1), 14000);
    expect(tl.transitionAt(2), 20000);
    expect(tl.nearestTransition(19400, inhale: true), 2);
    expect(tl.nearestTransition(13100, inhale: false), 1);
    expect(tl.cyclesAt(9000), 0);
    expect(tl.cyclesAt(70000), 6);
    expect(tl.cyclesAt(999999), 16);
  });

  group('GroupSync (never shown as a number, never sent)', () {
    test('everyone on the pacer → S rises toward 1', () {
      final g = GroupSync(tl);
      for (var k = 0; k < 12; k++) {
        for (final seat in [1, 2, 3]) {
          g.record(seat, k, tl.transitionAt(k) + 100 * seat);
        }
      }
      g.close(tl.transitionAt(11) + 2000, [1, 2, 3]);
      expect(g.value, greaterThan(0.9));
    });

    test(
      'nobody breathing → S stays 0; the minimum ripple and 3 fish remain',
      () {
        final g = GroupSync(tl)..close(tl.transitionAt(10) + 2000, [1, 2]);
        expect(g.value, 0);
        expect(fishCount(g.value), 3);
        expect(rippleRadius(g.value), greaterThan(0));
        expect(fishCount(1), 15);
      },
    );

    test('players drifting together still count (the reference is the group median)', () {
      final g = GroupSync(tl);
      for (var k = 0; k < 10; k++) {
        g
          ..record(1, k, tl.transitionAt(k) + 1800)
          ..record(2, k, tl.transitionAt(k) + 1900);
      }
      g.close(tl.transitionAt(9) + 2000, [1, 2]);
      expect(g.value, greaterThan(0.9));
    });

    test('someone 1.5 s off the others counts 0 for that transition', () {
      expect(
        GroupSync.alignmentOf({1: 0, 2: 0, 3: 1500}, [1, 2, 3], 1500),
        closeTo(2 / 3, 0.001),
      );
      expect(GroupSync.alignmentOf({1: 0}, [1, 2], 1500), 0.5); // seat 2 missed
    });
  });

  test(
    'echo trace: pacer-relative offsets in 50 ms steps, null = missed, ±2 s',
    () {
      final e = EchoTrace(tl)
        ..record(10120, inhale: true)
        ..record(13900, inhale: false)
        ..record(24000, inhale: false) // exhale k=3 is at 24000: 0
        ..record(30000 + 2500, inhale: true); // too far from 30000
      expect(e.offsets.take(5).toList(), [2, -2, null, 0, null]);
      expect(e.upTo(24000), [2, -2, null, 0]);
      expect(e.hits, 3);
    },
  );

  test('event budget: at most 10 per second; pulses 3 s; gestures 5 s', () {
    final b = EventBudget(10);
    expect(
      [for (var i = 0; i < 12; i++) b.allow(i)].where((x) => x).length,
      10,
    );
    expect(b.allow(1001), isTrue);
    final p = MinInterval(3000);
    expect([p.allow(0), p.allow(2999), p.allow(3000)], [true, false, true]);
  });

  test('server clock: the shortest round trip wins', () {
    final c = ServerClock()
      ..sample(sentMs: 0, receivedMs: 400, serverMs: 10200)
      ..sample(sentMs: 1000, receivedMs: 1100, serverMs: 11000)
      ..sample(sentMs: 2000, receivedMs: 2900, serverMs: 99999);
    expect(c.offsetMs, 11000 - 1050);
    expect(c.toServer(0), 9950);
  });
}
