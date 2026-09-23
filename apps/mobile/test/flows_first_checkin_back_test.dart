import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// The first check-in ends onboarding and is the only route (like the real
/// router, which `go`es there). The Android back gesture must never leave the
/// app or skip onboarding: nothing picked → nothing happens; input → "Keep
/// editing" (default) or "Start over", which clears and stays.
void main() {
  late int systemPops;
  late ProviderContainer container;

  Future<void> pumpFirstCheckIn(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Leaving the app = SystemNavigator.pop on the platform channel.
    systemPops = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') systemPops++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final router = GoRouter(
      initialLocation: '/checkin',
      routes: [
        GoRoute(
          path: '/checkin',
          builder: (_, _) => const CheckInScreen(first: true),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
      ],
    );
    container = ProviderContainer(
      overrides: testOverrides(
        db: memoryDb(),
        gate: const GateState(stage: OnboardingStage.firstCheckIn),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildAuraTheme(const Locale('en')),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...systemLocalizationDelegates,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tapMood(WidgetTester tester, String id) async {
    final tile = find.byKey(ValueKey('mood-$id'));
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();
  }

  final startOverTitle = find.text('Start over?');
  final leaveTitle = find.text('Leave without saving?');
  final picker = find.byKey(const ValueKey('checkin-save'));
  final home = find.text('home');

  FilledButton save(WidgetTester tester) => tester.widget<FilledButton>(picker);

  testWidgets('nothing picked: back does nothing — no dialog, the app stays, '
      'onboarding is not skipped', (tester) async {
    await pumpFirstCheckIn(tester);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(systemPops, 0);
    expect(startOverTitle, findsNothing);
    expect(leaveTitle, findsNothing);
    expect(picker, findsOneWidget);
    expect(home, findsNothing);
    expect(
      container.read(gateControllerProvider).stage,
      OnboardingStage.firstCheckIn,
    );

    // Again: still nothing.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(systemPops, 0);
    expect(picker, findsOneWidget);
    await done(tester);
  });

  testWidgets('with input: back offers "Keep editing" (focused, keeps it) '
      'and "Start over" (clears, stays) — never leaves', (tester) async {
    await pumpFirstCheckIn(tester);
    await tapMood(tester, 'calm');
    // The details row grows in (AnimatedSize) before it can be tapped.
    await tester.pumpAndSettle();
    final list = find.byType(ListView).first;
    Future<void> reveal(Finder f) async {
      for (var i = 0; i < 30 && f.hitTestable().evaluate().isEmpty; i++) {
        await tester.drag(list, const Offset(0, -120));
        await tester.pumpAndSettle();
      }
    }

    await reveal(find.text('Add a tag or a few words'));
    await tester.tap(find.text('Add a tag or a few words').hitTestable());
    await tester.pumpAndSettle();
    final note = find.widgetWithText(TextField, 'A few words, if you like');
    await reveal(note);
    await tester.enterText(note, 'a quiet morning');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(startOverTitle, findsOneWidget);
    expect(leaveTitle, findsNothing);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextButton>()
          ?.key,
      const ValueKey('startover-keep'),
    );

    await tester.tap(find.byKey(const ValueKey('startover-keep')));
    await tester.pumpAndSettle();
    expect(startOverTitle, findsNothing);
    expect(save(tester).onPressed, isNotNull); // the mood is kept
    expect(find.text('a quiet morning'), findsOneWidget);

    // Back while the dialog is open closes only the dialog.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(startOverTitle, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(startOverTitle, findsNothing);
    expect(save(tester).onPressed, isNotNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('startover-confirm')));
    await tester.pumpAndSettle();
    expect(startOverTitle, findsNothing);
    expect(picker, findsOneWidget); // still here
    expect(save(tester).onPressed, isNull); // no mood any more
    expect(find.text('a quiet morning'), findsNothing);
    expect(home, findsNothing);
    expect(systemPops, 0);
    expect(
      container.read(gateControllerProvider).stage,
      OnboardingStage.firstCheckIn,
    );

    // Empty again: back is back to doing nothing.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(startOverTitle, findsNothing);
    expect(systemPops, 0);
    await done(tester);
  });

  testWidgets('after saving: back still stays (Done finishes onboarding)', (
    tester,
  ) async {
    await pumpFirstCheckIn(tester);
    await tapMood(tester, 'joyful');
    await tester.tap(picker);
    await settleIo(tester);
    expect(find.byKey(const ValueKey('checkin-done')), findsOneWidget);

    // The saved moment animates (Starlight): pump, don't settle.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));
    expect(systemPops, 0);
    expect(startOverTitle, findsNothing);
    expect(find.byKey(const ValueKey('checkin-done')), findsOneWidget);
    expect(
      container.read(gateControllerProvider).stage,
      OnboardingStage.firstCheckIn,
    );
    await done(tester);
  });
}
