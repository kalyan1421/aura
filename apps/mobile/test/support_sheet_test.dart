import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _done = GateState(stage: OnboardingStage.done);

/// Opens the sheet from a plain page, the way Home/Blocked/Check-in do.
Future<void> _open(
  WidgetTester tester,
  AppDatabase db, {
  GateState gate = _done,
  bool crisis = false,
  FakeSync? sync,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testOverrides(db: db, gate: gate, sync: sync),
        deviceRegionProvider.overrideWithValue('IN'),
      ],
      child: localized(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showSupportSheet(context, crisis: crisis),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await settleIo(tester);
}

/// Builds [target] (the list is lazy) and scrolls it fully on screen.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find
        .descendant(
          of: find.byType(SupportSheet),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _start(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('grounding-toggle'));
  await _scrollTo(tester, toggle);
  await tester.tap(toggle);
  await tester.pump();
}

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Size _circleSize(WidgetTester tester) => tester.getSize(
  find.descendant(
    of: find.byType(GroundingExercise),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    ),
  ),
);

Future<List<String>> _habitLogKeys(WidgetTester tester, AppDatabase db) =>
    io(tester, () async {
      final rows = await db
          .customSelect(
            'SELECT h.preset_key AS k FROM habit_logs l '
            'JOIN habits h ON h.id = l.habit_id WHERE l.deleted_at IS NULL',
          )
          .get();
      return [for (final r in rows) r.read<String>('k')];
    });

/// Every button node in the tree carries a tap action (no bare "button"
/// stops for TalkBack / VoiceOver).
void _expectNoActionlessButtons(WidgetTester tester, Finder within) {
  final root = tester.getSemantics(within).owner!.rootSemanticsNode!;
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isButton) {
      expect(
        data.hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'button "${data.label}" has no tap action',
      );
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
}

void main() {
  testWidgets('"I need help now" is one tappable button node', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      localized(const Scaffold(body: Center(child: HelpNowButton()))),
    );
    expect(
      tester.getSemantics(find.byType(HelpNowButton)),
      isSemantics(
        label: 'I need help now',
        isButton: true,
        hasTapAction: true,
      ),
    );
    // Still sorted early (REQ-A11Y-11: within the first focus stops).
    expect(
      tester.getSemantics(find.byType(HelpNowButton)).sortKey,
      const OrdinalSortKey(1),
    );
    _expectNoActionlessButtons(tester, find.byType(HelpNowButton));
    semantics.dispose();
  });

  testWidgets('helpline rows keep a tap action for screen readers',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final db = memoryDb();
    await _open(tester, db);
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Call Tele-MANAS · free, 24×7, 14416'),
      ),
      isSemantics(isButton: true, hasTapAction: true),
    );
    _expectNoActionlessButtons(tester, find.byType(SupportSheet));
    semantics.dispose();
    await _end(tester);
  });

  testWidgets('Reduce Motion: the cue follows the 1 s timer (4 s in, 6 s '
      'out) and the circle stays still', (tester) async {
    _reduceMotion(tester);
    final db = memoryDb();
    await _open(tester, db);
    await _start(tester);

    expect(find.text('Breathe in'), findsOneWidget);
    final still = _circleSize(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Breathe in'), findsOneWidget);
    expect(_circleSize(tester), still);

    await tester.pump(const Duration(seconds: 1)); // 4 s
    await tester.pump(const Duration(milliseconds: 350)); // crossfade done
    expect(find.text('Breathe out'), findsOneWidget);
    expect(find.text('Breathe in'), findsNothing);
    expect(_circleSize(tester), still);

    await tester.pump(const Duration(seconds: 6)); // 10 s: next breath
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Breathe in'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('with motion the circle breathes and the cue changes too',
      (tester) async {
    final db = memoryDb();
    await _open(tester, db);
    await _start(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Breathe in'), findsOneWidget);
    final inhale = _circleSize(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(_circleSize(tester).width, greaterThan(inhale.width));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Breathe out'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('an explicit Close at the top; the title is a header; focus '
      'starts on the first helpline', (tester) async {
    final semantics = tester.ensureSemantics();
    final db = memoryDb();
    await _open(tester, db);

    expect(
      tester.getSemantics(find.text('Help is here')),
      isSemantics(isHeader: true),
    );
    expect(
      Focus.of(tester.element(find.text('Tele-MANAS · free, 24×7'))).hasFocus,
      isTrue,
    );
    final close = find.byKey(const ValueKey('support-close'));
    expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
    await tester.tap(close);
    await settleIo(tester);
    expect(find.byType(SupportSheet), findsNothing);
    semantics.dispose();
    await _end(tester);
  });

  testWidgets('no countdown: a quiet ring whose semantics describe progress '
      'gently', (tester) async {
    final semantics = tester.ensureSemantics();
    final db = memoryDb();
    await _open(tester, db);
    await _start(tester);
    await tester.pump(const Duration(seconds: 30));

    expect(find.textContaining('seconds left'), findsNothing);
    expect(find.textContaining('30'), findsNothing);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byKey(const ValueKey('grounding-progress')),
    );
    expect(ring.value, 0.5);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Progress through the minute')),
      isSemantics(value: 'About halfway'),
    );
    semantics.dispose();
    await _end(tester);
  });

  testWidgets('the finished minute ticks off today\'s Breathe for an '
      'onboarded person (F2)', (tester) async {
    final db = memoryDb();
    final sync = FakeSync();
    await _open(tester, db, sync: sync);
    await _start(tester);
    await tester.pump(const Duration(seconds: 60));
    await settleIo(tester);

    expect(await _habitLogKeys(tester, db), ['breathe']);
    final outbox = await io(tester, () => db.select(db.outbox).get());
    expect(outbox.map((r) => r.entity), ['habit', 'habit_log']);
    expect(sync.writes, 1);
    expect(find.text('Breathe is marked done for today.'), findsOneWidget);

    // Again the same day: nothing more (never un-marks).
    await _start(tester);
    await tester.pump(const Duration(seconds: 60));
    await settleIo(tester);
    expect(await _habitLogKeys(tester, db), ['breathe']);
    await _end(tester);
  });

  for (final (name, gate) in [
    (
      'the Blocked (under-13) screen',
      GateState(
        stage: OnboardingStage.dob,
        blockedUntil: DateTime.utc(2026, 11, 1),
      ),
    ),
    ('onboarding', const GateState(stage: OnboardingStage.firstCheckIn)),
  ]) {
    testWidgets('from $name: finishing writes nothing and never crashes',
        (tester) async {
      final db = memoryDb();
      await _open(tester, db, gate: gate);
      await _start(tester);
      await tester.pump(const Duration(seconds: 60));
      await settleIo(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Well done. Stay as long as you need.'), findsOneWidget);
      expect(await io(tester, () => db.select(db.habits).get()), isEmpty);
      expect(await io(tester, () => db.select(db.outbox).get()), isEmpty);
      await _end(tester);
    });
  }

  testWidgets('a hidden Breathe is not ticked off', (tester) async {
    final db = memoryDb();
    await io(
      tester,
      () => HabitRepository(
        db,
        OutboxRepository(db, const Ids()),
        testTime(),
        const Ids(),
      ).setPresetShown(PresetHabitKeys.breathe, false),
    );
    await _open(tester, db);
    await _start(tester);
    await tester.pump(const Duration(seconds: 60));
    await settleIo(tester);

    expect(await _habitLogKeys(tester, db), isEmpty);
    expect(find.text('Breathe is marked done for today.'), findsNothing);
    await _end(tester);
  });

  testWidgets('crisis variant keeps "Back to my check-in"', (tester) async {
    final db = memoryDb();
    await _open(tester, db, crisis: true);
    expect(find.text('It sounds like a lot right now.'), findsOneWidget);
    final back = find.text('Back to my check-in');
    await _scrollTo(tester, back);
    await tester.tap(back);
    await settleIo(tester);
    expect(find.byType(SupportSheet), findsNothing);
    await _end(tester);
  });
}
