import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/features/ripples/ripple_controller.dart';
import 'package:aura/src/features/ripples/ripple_engine.dart';
import 'package:aura/src/features/ripples/ripple_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ripples_fakes.dart';

/// The session controller without widgets: the clock is advanced by hand and
/// timers by the test binding.
void main() {
  RippleController make(
    FakeRipplesApi api,
    FakeChannels ch, {
    Future<void> Function()? habit,
  }) => RippleController(
    api: api,
    openChannel: ch.open,
    entry: RippleEntry.quick,
    newTicketId: () => 'ticket-1',
    isOnline: () => true,
    wallMs: () => fakeWallMs,
    feedback: FakeRippleFeedback(),
    onBreatheHabit: habit,
  );

  Future<void> advance(
    WidgetTester tester,
    RippleController c,
    int fromMs,
    int toMs,
  ) async {
    for (var t = fromMs; t <= toMs; t += 250) {
      c.advance(Duration(milliseconds: t));
      await tester.pump();
    }
  }

  testWidgets('≥ 6 cycles log the Breathe habit once (as F15 Breathe)', (
    tester,
  ) async {
    var habits = 0;
    final c = make(
      FakeRipplesApi(current: fakeSession(cycles: 8)),
      FakeChannels(),
      habit: () async => habits++,
    );
    addTearDown(c.dispose);
    await c.start();
    await advance(tester, c, 0, 2000 + 5 * 10000);
    expect(habits, 0);
    await advance(tester, c, 2000 + 5 * 10000, 2000 + 6 * 10000 + 500);
    expect(habits, 1);
    expect(c.habitLogged, isTrue);
    await advance(tester, c, 2000 + 6 * 10000 + 500, 2000 + 7 * 10000);
    expect(habits, 1);
  });

  testWidgets(
    'what goes on the channel: seat numbers, phases, preset gestures and '
    'times — never an id, a sync value or a score (DS-10, REQ-GAME-06)',
    (tester) async {
      final ch = FakeChannels();
      final c = make(FakeRipplesApi(current: fakeSession()), ch);
      addTearDown(c.dispose);
      await c.start();
      await advance(tester, c, 0, 2100);
      c.press();
      await advance(tester, c, 2100, 6000);
      c.release();
      c.sendPulse();
      c.sendGesture(RippleGesture.hug);
      expect(c.sendPulse(), isFalse); // ≤ 1 per 3 s
      expect(c.sendGesture(RippleGesture.deepBreath), isFalse); // ≤ 1 per 5 s
      await tester.pump();
      final sent = ch.last.sent;
      expect(
        sent.map((e) => e.$1).toSet(),
        containsAll(['breath_state', 'pulse', 'gesture', 'heartbeat']),
      );
      for (final (_, p) in sent) {
        expect(
          p.keys.toSet().difference({'seat', 'phase', 't', 'type'}),
          isEmpty,
        );
        expect(p['seat'], 1);
      }
    },
  );

  testWidgets('seat_update from the channel is only a hint: labels come from '
      'the server (a forged label never shows)', (tester) async {
    final api = FakeRipplesApi(current: fakeSession());
    final ch = FakeChannels();
    final c = make(api, ch);
    addTearDown(c.dispose);
    await c.start();
    await advance(tester, c, 0, 500);
    final fetches = api.sessionFetches;
    ch.last.deliver('seat_update', {
      'seat': 2,
      'kind': 'human',
      'label': 'Call me 98765',
    });
    await tester.pump();
    expect(api.sessionFetches, fetches + 1);
    expect(c.lights().map((v) => v.label), isNot(contains('Call me 98765')));
    // An early session_end can't end anyone's session: the phone keeps its own clock.
    ch.last.deliver('session_end', {'t': fakeWallMs});
    await tester.pump();
    expect(c.phase, RipplePhase.playing);
  });

  testWidgets('a full 3-minute session ends at t0 + 180 s on this phone', (
    tester,
  ) async {
    final api = FakeRipplesApi(
      current: fakeSession(cycles: 16).copyWithSettle(10000, 10000),
    );
    final c = make(api, FakeChannels());
    addTearDown(c.dispose);
    await c.start();
    await advance(tester, c, 0, 179750);
    expect(c.phase, RipplePhase.playing);
    expect(c.stage, RippleStage.fade);
    await advance(tester, c, 179750, 180250);
    expect(c.phase, RipplePhase.ended);
    expect(api.completes.single.$1, 16);
  });

  test('Breath Ripples kill switch reads from remote flags (default on)', () {
    expect(RemoteFlags.defaults.ripplesEnabled, isTrue);
  });
}

extension on RippleSession {
  RippleSession copyWithSettle(int settleMs, int fadeMs) => RippleSession(
    sessionId: sessionId,
    entry: entry,
    t0Ms: t0Ms,
    mySeat: mySeat,
    seats: seats,
    settleMs: settleMs,
    fadeMs: fadeMs,
    cycles: cycles,
    humans: humans,
    echoes: echoes,
    guides: guides,
  );
}
