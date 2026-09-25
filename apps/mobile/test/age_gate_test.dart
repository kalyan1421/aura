import 'package:aura/src/app.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/onboarding/age_gate.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Opens a DOB picker sheet and taps [value], scrolling the sheet as needed.
Future<void> pick(WidgetTester tester, String field, int value) async {
  await tester.tap(find.byKey(ValueKey('dob-$field')));
  await tester.pumpAndSettle();
  final option = find.byKey(ValueKey('dob-option-$value')).hitTestable();
  final list = find.byType(ListView).last;
  // The year sheet opens scrolled near 2008: look down, then up.
  for (var i = 0; i < 60 && option.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -80));
    await tester.pumpAndSettle();
  }
  for (var i = 0; i < 2 * 60 && option.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, 80));
    await tester.pumpAndSettle();
  }
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  group('AgeGate.isUnder13', () {
    final today = LocalDay.parse('2026-10-08');
    test('13th birthday today → allowed', () {
      expect(AgeGate.isUnder13(LocalDay.parse('2013-10-08'), today), isFalse);
    });
    test('13th birthday tomorrow → under 13', () {
      expect(AgeGate.isUnder13(LocalDay.parse('2013-10-09'), today), isTrue);
    });
    test('29 Feb birthday rolls to 1 Mar in common years', () {
      expect(
        AgeGate.isUnder13(
          LocalDay.parse('2013-02-28').addDays(1), // 1 Mar 2013
          LocalDay.parse('2026-02-28'),
        ),
        isTrue,
      );
    });
  });

  group('lock', () {
    test('lasts 30 days, then clears itself', () async {
      final store = MemorySecureStore();
      final clock = FixedClock(testNow);
      final gate = AgeGate(store, clock);
      final until = await gate.block();
      expect(until, testNow.add(const Duration(days: 30)));
      clock.instant = testNow.add(const Duration(days: 29));
      expect(await gate.blockedUntil(), until);
      clock.instant = testNow.add(const Duration(days: 30, seconds: 1));
      expect(await gate.blockedUntil(), isNull);
      expect(store.values, isEmpty);
    });
  });

  group('gateRedirect', () {
    test('the lock wins over every route', () {
      final g = GateState(stage: OnboardingStage.done, blockedUntil: testNow);
      expect(gateRedirect(g, Routes.home), Routes.blocked);
      expect(gateRedirect(g, Routes.blocked), isNull);
    });
    test('onboarding runs in order; DOB before sign-in', () {
      const g = GateState(stage: OnboardingStage.dob);
      expect(gateRedirect(g, Routes.onboardingSignIn), Routes.dob);
      expect(gateRedirect(g, Routes.home), Routes.dob);
      expect(gateRedirect(g, Routes.dob), isNull);
    });
    test('after onboarding, onboarding routes bounce home', () {
      const g = GateState(stage: OnboardingStage.done);
      expect(gateRedirect(g, Routes.dob), Routes.home);
      expect(gateRedirect(g, Routes.checkIn), isNull);
    });
  });

  testWidgets('DOB under 13 → kind block screen + device lock; relaunch still '
      'blocked; nothing about the child is kept (REQ-ACC-03)', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final secure = MemorySecureStore();
    final db = memoryDb();
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          db: db,
          secure: secure,
          gate: const GateState(stage: OnboardingStage.dob),
        ),
        child: const AuraApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));


    // A 10-year-old (the fixed clock is 8 Oct 2026).
    await pick(tester, 'day', 5);
    await pick(tester, 'month', 3);
    await pick(tester, 'year', 2016);
    await tester.tap(find.byKey(const ValueKey('dob-continue')));
    await settleIo(tester);

    expect(find.byKey(const ValueKey('blocked-title')), findsOneWidget);
    expect(secure.values.containsKey(SecureKeys.ageBlockUntil), isTrue);
    final kv = KvStore(db);
    expect(await io(tester, () => kv.get(KvKeys.birthDate)), isNull);
    expect(await io(tester, () => kv.get(KvKeys.pendingProfile)), isNull);

    // Relaunch (reinstall on iOS keeps the Keychain): straight to the block.
    await tester.pumpWidget(const SizedBox());
    final gate = await io(
      tester,
      () => loadGateState(kv, AgeGate(secure, FixedClock(testNow))),
    );
    expect(gate.isBlocked, isTrue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: db, secure: secure, gate: gate),
        child: const AuraApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('blocked-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('dob-continue')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('DOB 13+ queues the profile and moves on to language',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final secure = MemorySecureStore();
    final db = memoryDb();
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          db: db,
          secure: secure,
          gate: const GateState(stage: OnboardingStage.dob),
        ),
        child: const AuraApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Continue stays disabled until day, month and year are all set.
    final cont = find.byKey(const ValueKey('dob-continue'));
    expect(tester.widget<FilledButton>(cont).onPressed, isNull);


    await pick(tester, 'day', 17);
    await pick(tester, 'month', 4);
    await pick(tester, 'year', 2006);
    await tester.tap(cont);
    await settleIo(tester);

    expect(find.byKey(const ValueKey('language-continue')), findsOneWidget);
    expect(secure.values.containsKey(SecureKeys.ageBlockUntil), isFalse);
    final kv = KvStore(db);
    expect(await io(tester, () => kv.get(KvKeys.birthDate)), '2006-04-17');
    expect(await io(tester, () => kv.get(KvKeys.pendingProfile)), '1');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
