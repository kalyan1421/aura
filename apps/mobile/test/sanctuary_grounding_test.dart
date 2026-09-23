import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/features/sanctuary/breath_haptics.dart';
import 'package:aura/src/features/sanctuary/breath_pacer.dart';
import 'package:aura/src/features/sanctuary/breathe_session_screen.dart';
import 'package:aura/src/features/sanctuary/sanctuary_activities.dart';
import 'package:aura/src/features/sanctuary/steps_activity_screen.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _QuietHaptics implements BreathHaptics {
  @override
  void phaseStarted(BreathPhase phase) {}
}

/// The grounding library (F15 v1): 5-4-3-2-1, three small things and savour
/// are prompts only, step by step; hand on heart and stillness breathe with
/// the orb. Each can be left at any time, nothing is scored and nothing
/// typed or picked is stored (REQ-SAN-05).
void main() {
  Future<void> openHost(WidgetTester tester, AppDatabase db) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db),
          breathHapticsProvider.overrideWithValue(_QuietHaptics()),
        ],
        child: localized(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final a in SanctuaryActivity.values)
                      TextButton(
                        key: ValueKey('open-${a.name}'),
                        onPressed: () => openSanctuaryActivity(context, a),
                        child: Text(a.name),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> open(WidgetTester tester, SanctuaryActivity a) async {
    await tester.tap(find.byKey(ValueKey('open-${a.name}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('steps-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> expectNothingStored(WidgetTester tester, AppDatabase db) async {
    expect(await io(tester, () => db.select(db.outbox).get()), isEmpty);
    expect(await io(tester, () => db.select(db.habitLogs).get()), isEmpty);
    expect(await io(tester, () => db.select(db.checkIns).get()), isEmpty);
  }

  testWidgets('five senses: one prompt at a time with Next, Back revisits, '
      'then a calm ending; no text field, nothing stored', (tester) async {
    final db = memoryDb();
    await openHost(tester, db);
    await open(tester, SanctuaryActivity.senses);

    expect(find.byType(StepsActivityScreen), findsOneWidget);
    expect(
      find.text(
        "Let's notice what's around you, one sense at a time. Go at your "
        'own pace.',
      ),
      findsOneWidget,
    );
    expect(find.text('Five things you can see'), findsOneWidget);
    expect(find.byKey(const ValueKey('steps-back')), findsNothing);

    await next(tester);
    expect(find.text('Four things you can touch'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('steps-back')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Five things you can see'), findsOneWidget);

    for (final step in [
      'Four things you can touch',
      'Three things you can hear',
      'Two things you can smell',
      'One thing you can taste',
    ]) {
      await next(tester);
      expect(find.text(step), findsOneWidget);
    }
    await next(tester);
    expect(
      find.text("You're here, in this moment. Nicely done."),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    await expectNothingStored(tester, db);

    await tester.tap(find.byKey(const ValueKey('steps-finish')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(StepsActivityScreen), findsNothing);
    await end(tester);
  });

  testWidgets('each step is announced once; the dots read "Step 2 of 5", '
      'never a score', (tester) async {
    final semantics = tester.ensureSemantics();
    await openHost(tester, memoryDb());
    await open(tester, SanctuaryActivity.senses);
    await next(tester);
    expect(
      tester.getSemantics(find.text('Four things you can touch')),
      isSemantics(isLiveRegion: true),
    );
    expect(find.bySemanticsLabel('Step 2 of 5'), findsOneWidget);
    semantics.dispose();
    await end(tester);
  });

  testWidgets('three small things and savour: prompts only, one at a time', (
    tester,
  ) async {
    final db = memoryDb();
    await openHost(tester, db);
    await open(tester, SanctuaryActivity.gratitude);
    expect(find.text('One small thing that went okay'), findsOneWidget);
    await next(tester);
    expect(find.text('Another small thing'), findsOneWidget);
    await next(tester);
    expect(find.text('One more small thing'), findsOneWidget);
    await next(tester);
    expect(
      find.text("Hold onto those for a moment. They're yours."),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const ValueKey('steps-finish')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(StepsActivityScreen), findsNothing);

    await open(tester, SanctuaryActivity.savour);
    expect(find.text('Savour this'), findsOneWidget);
    expect(
      find.text('Bring one good moment from today to mind, however small.'),
      findsOneWidget,
    );
    await next(tester);
    await next(tester);
    await next(tester);
    expect(find.text('Let it stay with you a little longer.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await expectNothingStored(tester, db);
    await end(tester);
  });

  testWidgets('hand on heart: starts at once with where to put the hand, '
      'gentle lines follow; a full minute ticks off Breathe', (tester) async {
    final db = memoryDb();
    await openHost(tester, db);
    await open(tester, SanctuaryActivity.heart);

    expect(find.text('Hand on heart'), findsOneWidget);
    expect(
      find.text(
        'Place a hand on your heart, or anywhere that feels comforting.',
      ),
      findsOneWidget,
    );
    for (var i = 0; i < 44; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Feel the warmth of your hand.'), findsOneWidget);
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await settleIo(tester);
    expect(
      find.text('Thank you for being gentle with yourself.'),
      findsOneWidget,
    );
    expect(find.text('Breathe is marked done for today.'), findsOneWidget);
    await end(tester);
  });

  testWidgets('stillness: one quiet minute with the orb, no instructions', (
    tester,
  ) async {
    await openHost(tester, memoryDb());
    await open(tester, SanctuaryActivity.stillness);
    expect(find.text('A minute of stillness'), findsOneWidget);
    expect(find.text('Breathe in'), findsOneWidget);
    expect(find.byKey(const ValueKey('breathe-cue')), findsNothing);
    final screen = tester.widget<BreatheSessionScreen>(
      find.byType(BreatheSessionScreen),
    );
    expect(screen.guide, BreathGuide.stillness);
    await end(tester);
  });

  testWidgets('every activity: "I need help now" within the first three '
      'focus stops, and ✕ leaves at once', (tester) async {
    final semantics = tester.ensureSemantics();
    await openHost(tester, memoryDb());
    for (final a in SanctuaryActivity.values) {
      await open(tester, a);
      final order = tester.semantics.simulatedAccessibilityTraversal().toList();
      final helpAt = order.indexWhere(
        (n) => n.getSemanticsData().label.contains('I need help now'),
      );
      expect(helpAt, inInclusiveRange(0, 2), reason: a.name);
      expect(find.byType(HelpNowButton), findsOneWidget, reason: a.name);

      await tester.tap(find.byKey(const ValueKey('activity-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(ValueKey('open-${a.name}')), findsOneWidget);
    }
    semantics.dispose();
    await end(tester);
  });

  test('activity ids are stable for a later /sanctuary/activity/:id route', () {
    for (final a in SanctuaryActivity.values) {
      expect(sanctuaryActivityById(a.name), a);
    }
    expect(sanctuaryActivityById('nope'), isNull);
  });
}
