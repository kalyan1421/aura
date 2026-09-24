import 'package:aura/src/core/a11y/haptics.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/features/ripples/ripple_channel.dart';
import 'package:aura/src/features/ripples/ripple_feedback.dart';
import 'package:aura/src/features/ripples/ripple_models.dart';
import 'package:aura/src/features/ripples/ripple_screen.dart';
import 'package:aura/src/features/ripples/ripples_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'ripples_fakes.dart';

/// F7 Breath Ripples on the phone: lobby → session → end, with the silent
/// disconnect, Reduce Motion, haptics off, accessible mode, the event budget
/// and safety on a light. Time is the test clock (the ticker follows pump).
void main() {
  late AppDatabase db;
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  Future<
    ({FakeRipplesApi api, FakeChannels channels, FakeRippleFeedback feedback})
  >
  open(
    WidgetTester tester, {
    FakeRipplesApi? api,
    RippleEntry entry = RippleEntry.quick,
    bool reduceMotion = false,
    bool screenReader = false,
    VoidCallback? onFeelNow,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    if (reduceMotion || screenReader) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(
            disableAnimations: reduceMotion,
            accessibleNavigation: screenReader,
          );
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    final a = api ?? FakeRipplesApi(current: fakeSession());
    final channels = FakeChannels();
    final feedback = FakeRippleFeedback();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db),
          ripplesApiProvider.overrideWithValue(a),
          rippleChannelOpenerProvider.overrideWithValue(channels.open),
          rippleFeedbackProvider.overrideWithValue(feedback),
        ],
        child: localized(
          RippleScreen(
            entry: entry,
            roomId: entry == RippleEntry.room ? 'room-1' : null,
            wallMs: () => fakeWallMs,
            onFeelNow: onFeelNow,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return (api: a, channels: channels, feedback: feedback);
  }

  Future<void> run(
    WidgetTester tester,
    Duration d, {
    Duration step = const Duration(milliseconds: 250),
  }) async {
    var left = d;
    while (left > Duration.zero) {
      final s = left < step ? left : step;
      await tester.pump(s);
      left -= s;
    }
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  const failureWords = [
    'failed',
    'left',
    'disconnected',
    'no one found',
    'error',
  ];
  void expectNoFailureCopy(WidgetTester tester) {
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final s = (t.data ?? '').toLowerCase();
      for (final w in failureWords) {
        expect(s.contains(w), isFalse, reason: '"${t.data}" says $w');
      }
    }
  }

  testWidgets(
    'lobby: the pacer starts at once, "Looking for others…", then the '
    'session: intro counts echoes as echoes, never as people',
    (tester) async {
      final r = await open(
        tester,
        api: FakeRipplesApi(current: fakeSession(), waitPolls: 1),
      );
      expect(find.text('Looking for others to breathe with…'), findsOneWidget);
      expect(find.text('Breathe in'), findsOneWidget); // the lobby pacer
      expect(find.byKey(const ValueKey('ripple-echo-toggle')), findsOneWidget);

      await run(tester, const Duration(seconds: 2)); // the next poll matches
      expect(r.api.tickets.toSet(), hasLength(1)); // one ticket, polled
      expect(find.text('Settle in'), findsOneWidget);
      expect(find.text('2 people breathing together'), findsOneWidget);
      expect(find.textContaining('1 echo joined'), findsOneWidget);
      expect(find.text('A guide light breathes with you.'), findsOneWidget);
      expect(r.channels.last.topic, 'game:session-1');
      expect(r.channels.last.tracked, [
        {'seat': 1},
      ]);

      await run(tester, const Duration(seconds: 2));
      expect(find.text('Breathe in'), findsOneWidget);
      // No score, number or countdown anywhere on the session screen.
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect(
          RegExp(r'\d+\s*(s|sec|%|/)').hasMatch(t.data ?? ''),
          isFalse,
          reason: t.data,
        );
      }
      await end(tester);
    },
  );

  testWidgets(
    'hold to breathe in, release to breathe out: state changes only go '
    'client to client; ✕ leaves silently and sends the trace',
    (tester) async {
      final r = await open(tester);
      await run(
        tester,
        const Duration(milliseconds: 2100),
      ); // into the first inhale
      final area = find.byKey(const ValueKey('ripple-breath-area'));
      final g = await tester.startGesture(tester.getCenter(area));
      await run(tester, const Duration(seconds: 4));
      await g.up();
      await tester.pump();
      final breaths = r.channels.last.sent
          .where((e) => e.$1 == 'breath_state')
          .map((e) => e.$2['phase'])
          .toList();
      expect(breaths, ['in', 'out']);
      expect(r.channels.last.sent.every((e) => e.$2['seat'] == 1), isTrue);
      expect(
        r.channels.last.sent.any(
          (e) => e.$2.containsKey('sync') || e.$2.containsKey('score'),
        ),
        isFalse,
      );

      await tester.tap(find.byKey(const ValueKey('ripple-close')));
      await tester.pump();
      await tester.pump();
      expect(r.api.left, ['session-1']);
      expect(r.api.completes.single.$2, isNotNull);
      expect(r.api.completes.single.$2!.first, isNotNull); // the inhale was hit
      await end(tester);
    },
  );

  testWidgets(
    'REQ-GAME-04 disconnect: the pacer carries on locally with a calm '
    'line, a silent rejoin within the window, never a failure screen',
    (tester) async {
      final r = await open(tester);
      await run(tester, const Duration(seconds: 3));
      r.channels.last.status(RippleLinkStatus.error);
      await tester.pump();
      expect(
        find.text("You're breathing on your own for a moment."),
        findsOneWidget,
      );
      expectNoFailureCopy(tester);
      final before = r.channels.opened.length;
      await run(tester, const Duration(seconds: 2)); // backoff → rejoin
      expect(r.channels.opened.length, greaterThan(before));
      await tester.pump();
      expect(
        find.text("You're breathing on your own for a moment."),
        findsNothing,
      );

      // Gone for good this time: after the window the session finishes here, gently.
      r.channels.refuse = true;
      r.channels.last.status(RippleLinkStatus.closed);
      await run(tester, const Duration(seconds: 12));
      expect(
        find.text('Keep breathing. The ocean is still here.'),
        findsOneWidget,
      );
      expectNoFailureCopy(tester);
      // Another player who went quiet dims into an echo; nobody is shown as gone.
      expect(find.text('echo'), findsWidgets);
      await run(tester, const Duration(seconds: 20));
      expect(find.byKey(const ValueKey('ripple-end')), findsOneWidget);
      expect(find.text('That was a few minutes together.'), findsOneWidget);
      expect(r.api.completes, hasLength(1));
      expectNoFailureCopy(tester);
      await end(tester);
    },
  );

  testWidgets('another player going quiet: follows the pacer, then an echo — '
      'one event brings the light back', (tester) async {
    final r = await open(tester);
    await run(tester, const Duration(seconds: 3));
    final ch = r.channels.last;
    ch.deliver('heartbeat', {'seat': 2, 't': fakeWallMs + 3000});
    await tester.pump();
    expect(find.bySemanticsLabel("Gentle Moon's light"), findsOneWidget);
    await run(tester, const Duration(seconds: 11));
    expect(find.bySemanticsLabel("Gentle Moon's light"), findsNothing);
    expect(
      find.bySemanticsLabel('An echo of someone who breathed here before'),
      findsNWidgets(2),
    );
    ch.deliver('breath_state', {
      'seat': 2,
      'phase': 'in',
      't': fakeWallMs + 14000,
    });
    await tester.pump();
    expect(find.bySemanticsLabel("Gentle Moon's light"), findsOneWidget);
    await end(tester);
  });

  testWidgets('Reduce Motion: the Still tier (one painted frame, no drift), '
      'phase words and haptics still carry the rhythm', (tester) async {
    final r = await open(tester, reduceMotion: true);
    expect(find.byKey(const ValueKey('ripple-ocean-still')), findsOneWidget);
    await run(tester, const Duration(seconds: 2, milliseconds: 250));
    expect(find.text('Breathe in'), findsOneWidget);
    await run(tester, const Duration(seconds: 4));
    expect(find.text('Breathe out'), findsOneWidget);
    expect(r.feedback.phases.map((p) => p.$1), [true, false]);
    await end(tester);
  });

  testWidgets('haptics off (Comfort): no device haptics at all; a received '
      'pulse shows as a visual pulse by that light', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String);
        }
        return null;
      },
    );
    AuraHaptics.enabled = false;
    addTearDown(() {
      AuraHaptics.enabled = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final a = FakeRipplesApi(current: fakeSession());
    // The real feedback (through AuraHaptics), not the recorder.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final channels = FakeChannels();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db),
          ripplesApiProvider.overrideWithValue(a),
          rippleChannelOpenerProvider.overrideWithValue(channels.open),
          rippleFeedbackProvider.overrideWithValue(AuraRippleFeedback()),
        ],
        child: localized(RippleScreen(wallMs: () => fakeWallMs)),
      ),
    );
    await tester.pump();
    await tester.pump();
    await run(tester, const Duration(seconds: 3));
    channels.last.deliver('pulse', {'seat': 2, 't': fakeWallMs + 3000});
    await tester.pump();
    expect(find.byKey(const ValueKey('ripple-visual-pulse-2')), findsOneWidget);
    expect(find.text('Gentle Moon sent a pulse'), findsOneWidget);
    await run(tester, const Duration(seconds: 5)); // phase cues pass too
    expect(calls, isEmpty);
    await end(tester);
  });

  testWidgets(
    'accessible mode: on with a screen reader; tap to switch; tones and '
    'strength carry sync (not colour)',
    (tester) async {
      final r = await open(tester, screenReader: true);
      await run(tester, const Duration(milliseconds: 2100));
      expect(
        find.text('Tap to switch between breathing in and out'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('ripple-breath-area')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ripple-breath-area')));
      await tester.pump();
      expect(
        r.channels.last.sent
            .where((e) => e.$1 == 'breath_state')
            .map((e) => e.$2['phase']),
        ['in', 'out'],
      );
      expect(r.feedback.phases.first.$3, isTrue); // tone
      expect(r.feedback.phases.first.$2, isNotNull); // strength
      await end(tester);
    },
  );

  testWidgets(
    'REQ-GAME-05: a seat over 10 events/s is ignored past the cap and '
    'flagged once; echoes never pulse',
    (tester) async {
      final r = await open(tester);
      await run(tester, const Duration(seconds: 3));
      for (var i = 0; i < 50; i++) {
        r.channels.last.deliver('heartbeat', {
          'seat': 2,
          't': fakeWallMs + 3000,
        });
      }
      r.channels.last.deliver('pulse', {
        'seat': 3,
        't': fakeWallMs + 3000,
      }); // an echo seat
      await tester.pump();
      expect(r.api.floods, [2]);
      expect(r.feedback.pulses, 0);
      await end(tester);
    },
  );

  testWidgets('tap a light: mute / block / report in ≤ 2 taps; echoes and '
      'guides have no sheet', (tester) async {
    final r = await open(tester);
    await run(tester, const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('ripple-light-3')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('ripple-seat-sheet')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ripple-light-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('ripple-seat-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ripple-block')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(r.api.blocks, [2]);
    expect(
      find.text("Blocked. You won't be matched together again."),
      findsOneWidget,
    );

    // A blocked seat's pulses stop reaching you.
    r.channels.last.deliver('pulse', {'seat': 2, 't': fakeWallMs + 1500});
    await tester.pump();
    expect(r.feedback.pulses, 0);

    await tester.tap(find.byKey(const ValueKey('ripple-light-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('ripple-report')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ripple-reason-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ripple-report-send')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(r.api.reports, [(2, 2)]);
    await end(tester);
  });

  testWidgets('offline: "Breathe solo instead?" and no call is made', (
    tester,
  ) async {
    final a = FakeRipplesApi(current: fakeSession());
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db),
          ripplesApiProvider.overrideWithValue(a),
          rippleChannelOpenerProvider.overrideWithValue(null),
          rippleFeedbackProvider.overrideWithValue(FakeRippleFeedback()),
        ],
        child: localized(
          RippleScreen(wallMs: () => fakeWallMs, isOnline: () => false),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Breathing together needs a connection. Breathe solo instead?'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('ripple-solo')), findsOneWidget);
    expect(a.tickets, isEmpty);
    await end(tester);
  });

  testWidgets(
    'kill switch: 503 ripples_paused reads calmly with the solo pacer',
    (tester) async {
      await open(tester, api: FakeRipplesApi(error: paused));
      expect(
        find.text('Breath Ripples is resting for a bit. Breathe solo instead?'),
        findsOneWidget,
      );
      await end(tester);
    },
  );

  testWidgets(
    'end: Breathe again / Back to room / Done / How do you feel now?; '
    'the trace goes only with the echo switch on',
    (tester) async {
      var feel = 0;
      final api = FakeRipplesApi(
        current: fakeSession(entry: RippleEntry.room, cycles: 1),
      )..consent = false;
      await open(
        tester,
        api: api,
        entry: RippleEntry.room,
        onFeelNow: () => feel++,
      );
      await run(tester, const Duration(seconds: 14));
      expect(find.byKey(const ValueKey('ripple-end')), findsOneWidget);
      expect(find.byKey(const ValueKey('ripple-again')), findsOneWidget);
      expect(find.byKey(const ValueKey('ripple-back-to-room')), findsOneWidget);
      expect(find.byKey(const ValueKey('ripple-done')), findsOneWidget);
      expect(api.completes.single, (
        1,
        null,
      )); // opted out: no trace leaves the phone
      await tester.tap(find.byKey(const ValueKey('ripple-feel-now')));
      await tester.pump();
      expect(feel, 1);
      await end(tester);
    },
  );
}
