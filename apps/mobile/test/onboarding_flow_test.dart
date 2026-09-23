import 'package:aura/src/app.dart';
import 'package:aura/src/core/a11y/motion.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/core/theme/aura_tokens.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/avatar/aura_avatar.dart';
import 'package:aura/src/features/onboarding/age_gate.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Pumps the whole app at [stage] on a phone-sized view.
Future<KvStore> pumpAt(WidgetTester tester, OnboardingStage stage) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = memoryDb();
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        db: db,
        gate: GateState(stage: stage),
      ),
      child: const AuraApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return KvStore(db);
}

/// Lets the stage write land and the route transition finish.
Future<void> settleRoute(WidgetTester tester) async {
  await settleIo(tester, rounds: 4);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// The key of the primary action that identifies each onboarding screen.
const _screenKey = {
  OnboardingStage.welcome: ValueKey('welcome-begin'),
  OnboardingStage.trust: ValueKey('trust-continue'),
  OnboardingStage.dob: ValueKey('dob-continue'),
  OnboardingStage.language: ValueKey('language-continue'),
};

void main() {
  group('stage order (F8)', () {
    test('welcome → trust → dob → language → sign in; back mirrors it', () {
      expect(OnboardingStage.values.take(5), [
        OnboardingStage.welcome,
        OnboardingStage.trust,
        OnboardingStage.dob,
        OnboardingStage.language,
        OnboardingStage.signIn,
      ]);
      expect(OnboardingStage.welcome.previous, isNull);
      expect(OnboardingStage.trust.previous, OnboardingStage.welcome);
      expect(OnboardingStage.dob.previous, OnboardingStage.trust);
      expect(OnboardingStage.language.previous, OnboardingStage.dob);
      expect(OnboardingStage.signIn.previous, OnboardingStage.language);
      expect(OnboardingStage.firstCheckIn.previous, isNull);
      expect(OnboardingStage.done.previous, isNull);
    });

    test('redirect: trust sits between welcome and DOB', () {
      const trust = GateState(stage: OnboardingStage.trust);
      expect(gateRedirect(trust, Routes.trust), isNull);
      expect(gateRedirect(trust, Routes.dob), Routes.trust);
      expect(gateRedirect(trust, Routes.welcome), Routes.trust);
      expect(gateRedirect(trust, Routes.home), Routes.trust);
      const welcome = GateState(stage: OnboardingStage.welcome);
      expect(gateRedirect(welcome, Routes.trust), Routes.welcome);
      const done = GateState(stage: OnboardingStage.done);
      expect(gateRedirect(done, Routes.trust), Routes.home);
    });

    test('the under-13 lock wins over the trust step too', () {
      final g = GateState(stage: OnboardingStage.trust, blockedUntil: testNow);
      expect(gateRedirect(g, Routes.trust), Routes.blocked);
      expect(gateRedirect(g, Routes.dob), Routes.blocked);
    });
  });

  group('resume (loadGateState)', () {
    Future<GateState> resume(String? stored, {bool locked = false}) async {
      final kv = KvStore(memoryDb());
      if (stored != null) await kv.set(KvKeys.onboardingStage, stored);
      final secure = MemorySecureStore();
      final age = AgeGate(secure, FixedClock(testNow));
      if (locked) await age.block();
      return loadGateState(kv, age);
    }

    test('stages saved before the trust step resume exactly', () async {
      for (final name in [
        'welcome',
        'dob',
        'language',
        'signIn',
        'firstCheckIn',
        'done',
      ]) {
        expect((await resume(name)).stage.name, name, reason: name);
      }
      // A mid-onboarding install at DOB is not sent back through trust.
      expect(gateRedirect(await resume('dob'), Routes.root), Routes.dob);
    });

    test('missing or unknown names start at Welcome', () async {
      expect((await resume(null)).stage, OnboardingStage.welcome);
      expect((await resume('ageGate')).stage, OnboardingStage.welcome);
      expect((await resume('')).stage, OnboardingStage.welcome);
    });

    test('a stored lock still wins over a stored stage', () async {
      final g = await resume('language', locked: true);
      expect(g.isBlocked, isTrue);
      expect(gateRedirect(g, Routes.language), Routes.blocked);
    });
  });

  testWidgets('Welcome → Trust → DOB, each step persisted', (tester) async {
    final kv = await pumpAt(tester, OnboardingStage.welcome);

    await tester.tap(find.byKey(const ValueKey('welcome-begin')));
    await settleRoute(tester);
    expect(find.byKey(const ValueKey('trust-continue')), findsOneWidget);
    expect(find.text('Before we begin'), findsOneWidget);
    // The disclaimer sentence, verbatim (REQ-SAFE-12).
    expect(
      find.text('Aura is not a medical device or an emergency service.'),
      findsOneWidget,
    );
    // Nothing to tick (no pre-selected consent).
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(await io(tester, () => kv.get(KvKeys.onboardingStage)), 'trust');

    await tester.tap(find.byKey(const ValueKey('trust-continue')));
    await settleRoute(tester);
    expect(find.byKey(const ValueKey('dob-continue')), findsOneWidget);
    expect(await io(tester, () => kv.get(KvKeys.onboardingStage)), 'dob');

    await unmount(tester);
  });

  testWidgets('trust title is a header; legal links are shown', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAt(tester, OnboardingStage.trust);
    expect(
      tester.getSemantics(find.text('Before we begin')),
      isSemantics(isHeader: true),
    );
    // Debug builds carry placeholder policy URLs; the links close the list.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('legal-privacy')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('legal-privacy')), findsOneWidget);
    expect(find.byKey(const ValueKey('legal-terms')), findsOneWidget);
    await unmount(tester);
    handle.dispose();
  });

  group('back buttons return to the previous stage', () {
    for (final (from, to) in [
      (OnboardingStage.trust, OnboardingStage.welcome),
      (OnboardingStage.dob, OnboardingStage.trust),
      (OnboardingStage.language, OnboardingStage.dob),
    ]) {
      testWidgets('${from.name} → ${to.name}', (tester) async {
        final kv = await pumpAt(tester, from);
        final back = find.byTooltip('Back');
        expect(back, findsOneWidget);
        expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(back).width, greaterThanOrEqualTo(48));

        await tester.tap(back);
        await settleRoute(tester);
        expect(find.byKey(_screenKey[to]!), findsOneWidget);
        expect(await io(tester, () => kv.get(KvKeys.onboardingStage)), to.name);
        await unmount(tester);
      });
    }

    testWidgets('Welcome has no back button', (tester) async {
      await pumpAt(tester, OnboardingStage.welcome);
      expect(find.byTooltip('Back'), findsNothing);
      await unmount(tester);
    });
  });

  group('"I need help now" on every onboarding screen (F9, REQ-A11Y-11)', () {
    for (final stage in _screenKey.keys) {
      testWidgets('${stage.name}: within the first three focus stops', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpAt(tester, stage);
        expect(find.byKey(_screenKey[stage]!), findsOneWidget);
        expect(find.byType(HelpNowButton), findsOneWidget);

        final order = tester.semantics
            .simulatedAccessibilityTraversal()
            .toList();
        // Merged nodes (HelpNowButton is one MergeSemantics node) carry
        // their label in the merged data, not in `SemanticsNode.label`.
        final help = order.indexWhere(
          (n) => n.getSemanticsData().label.contains('I need help now'),
        );
        expect(help, inInclusiveRange(0, 2), reason: '$order');
        await unmount(tester);
        handle.dispose();
      });
    }
  });

  group('Welcome hero fade respects Reduce Motion (REQ-A11Y-08)', () {
    /// Opacity of the hero's own fade (the nearest one around the avatar).
    double heroOpacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.byType(AuraAvatar),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    testWidgets('reduced: a crossfade of at most 300 ms', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpAt(tester, OnboardingStage.welcome); // the fade starts now
      await tester.pump(reducedMotionFade);
      expect(heroOpacity(tester), 1);
      await unmount(tester);
    });

    testWidgets('default: the slow ease-in', (tester) async {
      await pumpAt(tester, OnboardingStage.welcome); // the fade starts now
      await tester.pump(reducedMotionFade);
      expect(heroOpacity(tester), lessThan(1));
      await tester.pump(AuraMotion.slow - reducedMotionFade);
      expect(heroOpacity(tester), 1);
      await unmount(tester);
    });
  });
}
