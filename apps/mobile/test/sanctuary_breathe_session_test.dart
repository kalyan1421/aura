import 'package:aura/src/core/a11y/haptics.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/sanctuary/breath_haptics.dart';
import 'package:aura/src/features/sanctuary/breath_orb.dart';
import 'package:aura/src/features/sanctuary/breath_pacer.dart';
import 'package:aura/src/features/sanctuary/breathe_session_screen.dart';
import 'package:aura/src/features/safety/safety_center_screen.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Records the phases the session cued (instead of the device's haptics).
class FakeBreathHaptics implements BreathHaptics {
  final List<BreathPhase> cues = [];

  @override
  void phaseStarted(BreathPhase phase) => cues.add(phase);
}

/// F15 Breathe: the avatar-orb pacer session. Time is the test clock
/// (tickers advance with `pump`), haptics a recorder.
void main() {
  Future<FakeBreathHaptics> open(
    WidgetTester tester,
    AppDatabase db,
    Widget screen, {
    GateState gate = const GateState(stage: OnboardingStage.done),
    bool reduceMotion = false,
    FakeSync? sync,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    final haptics = FakeBreathHaptics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db, gate: gate, sync: sync),
          breathHapticsProvider.overrideWithValue(haptics),
        ],
        child: localized(screen),
      ),
    );
    await tester.pump();
    return haptics;
  }

  /// Breathes for [d] of test time, a frame every [step].
  Future<void> breathe(
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

  Future<List<String>> habitLogKeys(WidgetTester tester, AppDatabase db) =>
      io(tester, () async {
        final rows = await db
            .customSelect(
              'SELECT h.preset_key AS k FROM habit_logs l '
              'JOIN habits h ON h.id = l.habit_id WHERE l.deleted_at IS NULL',
            )
            .get();
        return [for (final r in rows) r.read<String>('k')];
      });

  ChoiceChip chip(WidgetTester tester, String key) =>
      tester.widget<ChoiceChip>(find.byKey(ValueKey(key)));

  testWidgets('setup: Calm and 1 minute are the defaults; 4-7-8 adds the '
      'light-headed note; Start begins with "Breathe in"', (tester) async {
    await open(tester, memoryDb(), const BreatheSessionScreen());

    expect(chip(tester, 'breathe-pattern-calm').selected, isTrue);
    expect(chip(tester, 'breathe-pattern-box').selected, isFalse);
    expect(chip(tester, 'breathe-length-1').selected, isTrue);
    expect(find.byKey(const ValueKey('breathe-length-open')), findsOneWidget);
    expect(find.byKey(const ValueKey('breathe-light-headed')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('breathe-pattern-478')));
    await tester.pump();
    expect(chip(tester, 'breathe-pattern-478').selected, isTrue);
    expect(
      find.text('If you feel light-headed, stop and breathe normally.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('breathe-pattern-calm')));
    await tester.pump();
    expect(find.byKey(const ValueKey('breathe-light-headed')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('breathe-start')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Breathe in'), findsOneWidget);
    await end(tester);
  });

  testWidgets('phases follow the pattern: one cue per phase at its '
      'boundary (box: in, hold, out, hold)', (tester) async {
    final haptics = await open(
      tester,
      memoryDb(),
      const BreatheSessionScreen(pattern: BreathPattern.box, autoStart: true),
    );
    expect(haptics.cues, [BreathPhase.inhale]);
    expect(find.text('Breathe in'), findsOneWidget);

    await breathe(tester, const Duration(seconds: 4));
    await breathe(tester, const Duration(milliseconds: 250));
    expect(find.text('Hold'), findsOneWidget);
    await breathe(tester, const Duration(seconds: 4));
    expect(find.text('Breathe out'), findsOneWidget);
    await breathe(tester, const Duration(seconds: 4));
    expect(find.text('Hold'), findsOneWidget);
    await breathe(tester, const Duration(seconds: 4));
    expect(find.text('Breathe in'), findsOneWidget);
    expect(haptics.cues, [
      BreathPhase.inhale,
      BreathPhase.holdIn,
      BreathPhase.exhale,
      BreathPhase.holdOut,
      BreathPhase.inhale,
    ]);
    await end(tester);
  });

  testWidgets('time away never counts: one frame adds at most a second', (
    tester,
  ) async {
    await open(tester, memoryDb(), const BreatheSessionScreen(autoStart: true));
    // A 10 s gap between frames (the screen was away): still breathing in.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Breathe in'), findsOneWidget);
    await end(tester);
  });

  testWidgets('no numbers and no countdown: a quiet ring read as words', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester, memoryDb(), const BreatheSessionScreen(autoStart: true));
    await breathe(tester, const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining(RegExp(r'\d')), findsNothing);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byKey(const ValueKey('breathe-progress')),
    );
    expect(ring.value, closeTo(0.5, 0.02));
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Progress through this session'),
      ),
      isSemantics(value: 'About halfway'),
    );
    semantics.dispose();
    await end(tester);
  });

  testWidgets('the phase is a live region: screen readers hear each change', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester, memoryDb(), const BreatheSessionScreen(autoStart: true));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Breathe in')),
      isSemantics(isLiveRegion: true),
    );
    await breathe(tester, const Duration(seconds: 4, milliseconds: 250));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Breathe out')),
      isSemantics(isLiveRegion: true),
    );
    semantics.dispose();
    await end(tester);
  });

  testWidgets('pause holds everything still; resume carries on where it '
      'was', (tester) async {
    final haptics = await open(
      tester,
      memoryDb(),
      const BreatheSessionScreen(autoStart: true),
    );
    await breathe(tester, const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('breathe-toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Paused. Take your time.'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Paused. Take your time.'), findsOneWidget);
    expect(haptics.cues, [BreathPhase.inhale]);

    await tester.tap(find.byKey(const ValueKey('breathe-toggle')));
    await tester.pump();
    await breathe(tester, const Duration(milliseconds: 1500));
    expect(find.text('Breathe in'), findsOneWidget); // 3.5 s in
    await breathe(tester, const Duration(milliseconds: 1000));
    expect(find.text('Breathe out'), findsOneWidget); // 4.5 s in
    expect(haptics.cues, [BreathPhase.inhale, BreathPhase.exhale]);
    await end(tester);
  });

  testWidgets('≥ 60 s of breathing ticks off today\'s Breathe once, and '
      'the end screen says so (REQ-SAN-04)', (tester) async {
    final db = memoryDb();
    final sync = FakeSync();
    await open(
      tester,
      db,
      const BreatheSessionScreen(autoStart: true),
      sync: sync,
    );
    await breathe(tester, const Duration(seconds: 60));
    await settleIo(tester);

    expect(find.text('That was time just for you.'), findsOneWidget);
    expect(find.text('Breathe is marked done for today.'), findsOneWidget);
    expect(await habitLogKeys(tester, db), ['breathe']);
    expect(sync.writes, 1);

    // Again, the same day: still one completion.
    await tester.tap(find.byKey(const ValueKey('breathe-again')));
    await tester.pump();
    await breathe(tester, const Duration(seconds: 60));
    await settleIo(tester);
    expect(await habitLogKeys(tester, db), ['breathe']);
    await end(tester);
  });

  testWidgets('59 s (pauses excluded) logs nothing', (tester) async {
    final db = memoryDb();
    await open(
      tester,
      db,
      const BreatheSessionScreen(length: null, autoStart: true),
    );
    await breathe(tester, const Duration(seconds: 30));
    await tester.tap(find.byKey(const ValueKey('breathe-toggle')));
    await tester.pump(const Duration(seconds: 45)); // paused: doesn't count
    await tester.tap(find.byKey(const ValueKey('breathe-toggle')));
    await tester.pump();
    await breathe(tester, const Duration(seconds: 29));
    await tester.tap(find.byKey(const ValueKey('breathe-finish')));
    await settleIo(tester);

    expect(find.text('That was time just for you.'), findsOneWidget);
    expect(find.text('Breathe is marked done for today.'), findsNothing);
    expect(await habitLogKeys(tester, db), isEmpty);
    await end(tester);
  });

  testWidgets('a hidden Breathe is never ticked off; nor before onboarding', (
    tester,
  ) async {
    final hidden = memoryDb();
    await io(
      tester,
      () => HabitRepository(
        hidden,
        OutboxRepository(hidden, const Ids()),
        testTime(),
        const Ids(),
      ).setPresetShown(PresetHabitKeys.breathe, false),
    );
    await open(tester, hidden, const BreatheSessionScreen(autoStart: true));
    await breathe(tester, const Duration(seconds: 60));
    await settleIo(tester);
    expect(await habitLogKeys(tester, hidden), isEmpty);
    expect(find.text('Breathe is marked done for today.'), findsNothing);
    await end(tester);

    final early = memoryDb();
    await open(
      tester,
      early,
      const BreatheSessionScreen(autoStart: true),
      gate: const GateState(stage: OnboardingStage.firstCheckIn),
    );
    await breathe(tester, const Duration(seconds: 60));
    await settleIo(tester);
    expect(
      await io(tester, () => early.select(early.habitLogs).get()),
      isEmpty,
    );
    await end(tester);
  });

  testWidgets('Reduce Motion: the orb holds still; the words and the cues '
      'still carry the rhythm (REQ-SAN-03)', (tester) async {
    final haptics = await open(
      tester,
      memoryDb(),
      const BreatheSessionScreen(autoStart: true),
      reduceMotion: true,
    );
    final orb = tester.widget<BreathOrb>(find.byType(BreathOrb));
    expect(orb.still, isTrue);
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(BreathOrb),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as BreathOrbPainter;
    expect(painter.fill, isNull); // nothing to animate

    await breathe(tester, const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300)); // the crossfade
    expect(find.text('Breathe out'), findsOneWidget);
    expect(haptics.cues, [BreathPhase.inhale, BreathPhase.exhale]);
    await end(tester);
  });

  testWidgets('with motion the orb grows on the inhale', (tester) async {
    await open(tester, memoryDb(), const BreatheSessionScreen(autoStart: true));
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(BreathOrb),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as BreathOrbPainter;
    await breathe(tester, const Duration(seconds: 1));
    final early = painter.fill!.value;
    await breathe(tester, const Duration(seconds: 2));
    expect(painter.fill!.value, greaterThan(early));
    await end(tester);
  });

  testWidgets('"I need help now" is the second focus stop, and opening it '
      'pauses the pacer (REQ-SAN-08)', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, memoryDb(), const BreatheSessionScreen(autoStart: true));
    final order = tester.semantics.simulatedAccessibilityTraversal().toList();
    final helpAt = order.indexWhere(
      (n) => n.getSemanticsData().label.contains('I need help now'),
    );
    expect(helpAt, inInclusiveRange(0, 2));

    await breathe(tester, const Duration(seconds: 1));
    await tester.tap(find.byType(HelpNowButton));
    await settleIo(tester);
    expect(find.byType(SafetyCenterScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('safety-close')));
    await settleIo(tester);
    expect(find.byType(SafetyCenterScreen), findsNothing);
    expect(find.text('Paused. Take your time.'), findsOneWidget);
    semantics.dispose();
    await end(tester);
  });

  testWidgets('the app going to the background pauses it', (tester) async {
    await open(tester, memoryDb(), const BreatheSessionScreen(autoStart: true));
    await breathe(tester, const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Paused. Take your time.'), findsOneWidget);
    await end(tester);
  });

  testWidgets('Storm\'s minute: three breaths with grounding cues, then '
      '"Keep going" opens Breathe', (tester) async {
    final db = memoryDb();
    await open(tester, db, const BreatheSessionScreen(guide: BreathGuide.land));
    expect(find.text('Thirty seconds to land'), findsOneWidget);
    expect(find.text('Feel your feet on the ground.'), findsOneWidget);
    await breathe(tester, const Duration(seconds: 10, milliseconds: 250));
    expect(find.text('Notice three sounds around you.'), findsOneWidget);
    await breathe(tester, const Duration(seconds: 20));
    await settleIo(tester);
    expect(find.text('That was time just for you.'), findsOneWidget);
    // 30 s is not the Breathe habit's minute.
    expect(await habitLogKeys(tester, db), isEmpty);

    await tester.tap(find.byKey(const ValueKey('breathe-keep-going')));
    await settleIo(tester);
    expect(find.byKey(const ValueKey('breathe-start')), findsOneWidget);
    expect(find.text('Rhythm'), findsOneWidget);
    await end(tester);
  });

  testWidgets('the device haptics: rising as the inhale begins, falling as '
      'the exhale begins, nothing on a hold; Comfort › Haptics off is '
      'silent', (tester) async {
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
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    const haptics = AuraBreathHaptics();

    haptics.phaseStarted(BreathPhase.inhale);
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
    ]);
    calls.clear();

    haptics.phaseStarted(BreathPhase.holdIn);
    haptics.phaseStarted(BreathPhase.holdOut);
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, isEmpty);

    haptics.phaseStarted(BreathPhase.exhale);
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.selectionClick',
    ]);
    calls.clear();

    AuraHaptics.enabled = false;
    addTearDown(() => AuraHaptics.enabled = true);
    haptics.phaseStarted(BreathPhase.inhale);
    haptics.phaseStarted(BreathPhase.exhale);
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, isEmpty);
  });
}
