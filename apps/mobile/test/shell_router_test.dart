import 'package:aura/src/app.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/router/deep_links.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura/src/features/home/home_screen.dart';
import 'package:aura/src/features/onboarding/blocked_screen.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/safety/safety_center_screen.dart';
import 'package:aura/src/features/sanctuary/sanctuary_screen.dart';
import 'package:aura/src/features/shell/app_shell.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The route map, the gate and `aura://` deep links on the real router:
/// the shell after onboarding, the Safety Center in every gate state,
/// Check-in / Safety above the shell, and links that respect the gate
/// (cold start and while running) without touching `aura://auth-callback`.

const _done = GateState(stage: OnboardingStage.done);
final _blocked = GateState(
  stage: OnboardingStage.welcome,
  blockedUntil: testNow,
);

/// The whole app at [gate] on a phone ([link]: the launch deep link).
Future<ProviderContainer> _app(
  WidgetTester tester, {
  GateState gate = _done,
  String? link,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  if (link != null) {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = link;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
  }
  final container = ProviderContainer(
    overrides: [
      ...testOverrides(db: memoryDb(), gate: gate),
      deviceRegionProvider.overrideWithValue('IN'),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AuraApp()),
  );
  await _settle(tester);
  return container;
}

/// Home's avatar never stops moving: pump instead of settling.
Future<void> _settle(WidgetTester tester) async {
  await settleIo(tester, rounds: 4);
  await tester.pump(const Duration(milliseconds: 600));
}

/// The platform opening [url] while the app runs (Flutter deep linking).
Future<void> _openLink(WidgetTester tester, String url) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    MethodCall('pushRouteInformation', {'location': url, 'state': null}),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    message,
    (_) {},
  );
  await _settle(tester);
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

String _location(ProviderContainer c) =>
    c.read(routerProvider).state.matchedLocation;

/// Whether [tab] is the selected destination (its semantics flag).
bool _selected(WidgetTester tester, ShellTab tab) =>
    tester
        .widget<Semantics>(
          find
              .ancestor(
                of: find.byKey(AuraNavBar.tabKey(tab), skipOffstage: false),
                matching: find.byType(Semantics, skipOffstage: false),
              )
              .first,
        )
        .properties
        .selected ==
    true;

void main() {
  group('gateRedirect', () {
    test('the Safety Center opens in every gate state', () {
      for (final gate in [
        _blocked,
        GateState(stage: OnboardingStage.done, blockedUntil: testNow),
        for (final stage in OnboardingStage.values) GateState(stage: stage),
      ]) {
        expect(gateRedirect(gate, Routes.safety), isNull, reason: '$gate');
      }
    });

    test('otherwise the lock still wins over everything', () {
      for (final location in [
        Routes.home,
        Routes.sanctuary,
        Routes.rooms,
        Routes.insights,
        Routes.checkIn,
        Routes.settings,
      ]) {
        expect(gateRedirect(_blocked, location), Routes.blocked);
      }
    });

    test('the tabs are for after onboarding', () {
      const dob = GateState(stage: OnboardingStage.dob);
      for (final tab in [
        Routes.home,
        Routes.sanctuary,
        Routes.rooms,
        Routes.insights,
      ]) {
        expect(gateRedirect(dob, tab), Routes.dob);
        expect(gateRedirect(_done, tab), isNull);
      }
      expect(gateRedirect(_done, Routes.root), Routes.home);
      expect(gateRedirect(_done, Routes.historyEntry('x')), isNull);
    });
  });

  group('aura:// links', () {
    test('host (or first path segment) names the screen', () {
      String? target(String s) => DeepLinks.targetOf(Uri.parse(s));
      expect(target('aura://checkin'), Routes.checkIn);
      expect(target('aura://safety/'), Routes.safety);
      expect(target('aura:///sanctuary'), Routes.sanctuary);
      expect(target('AURA://Safety'), Routes.safety);
      expect(target('aura://auth-callback?code=1'), isNull);
      expect(target('aura://somewhere-else'), isNull);
      expect(target('https://example.org/safety'), isNull);
      expect(target(Routes.safety), isNull);
      expect(
        DeepLinks.isAuthCallback(Uri.parse('aura://auth-callback?c=1')),
        isTrue,
      );
    });

    test('what a link does, by gate and what is on screen', () {
      const firstCheckIn = GateState(stage: OnboardingStage.firstCheckIn);
      const dob = GateState(stage: OnboardingStage.dob);
      for (final (gate, target, stack, action)
          in <(GateState, String, List<String>, DeepLinkAction)>[
            // The lock and onboarding win: the gate already shows the screen.
            (_blocked, Routes.checkIn, [Routes.blocked], DeepLinkAction.none),
            (_blocked, Routes.sanctuary, [Routes.blocked], DeepLinkAction.none),
            (dob, Routes.sanctuary, [Routes.dob], DeepLinkAction.none),
            (dob, Routes.checkIn, [Routes.dob], DeepLinkAction.none),
            // Safety opens everywhere, above what is showing, once.
            (_blocked, Routes.safety, [Routes.blocked], DeepLinkAction.push),
            (dob, Routes.safety, [Routes.dob], DeepLinkAction.push),
            (
              _done,
              Routes.safety,
              [Routes.home, Routes.safety],
              DeepLinkAction.none,
            ),
            // Check-in: above the current screen; never a second one.
            (
              firstCheckIn,
              Routes.checkIn,
              [Routes.checkIn],
              DeepLinkAction.none,
            ),
            (_done, Routes.checkIn, [Routes.rooms], DeepLinkAction.push),
            (
              _done,
              Routes.checkIn,
              [Routes.home, Routes.checkIn, Routes.safety],
              DeepLinkAction.none,
            ),
            // A tab: switch, but never over unsaved input.
            (_done, Routes.sanctuary, [Routes.home], DeepLinkAction.go),
            (
              _done,
              Routes.sanctuary,
              [Routes.home, Routes.settings],
              DeepLinkAction.go,
            ),
            (_done, Routes.sanctuary, [Routes.sanctuary], DeepLinkAction.none),
            (
              _done,
              Routes.sanctuary,
              [Routes.home, Routes.checkIn],
              DeepLinkAction.none,
            ),
            (
              _done,
              Routes.sanctuary,
              [Routes.insights, Routes.historyEntry('x')],
              DeepLinkAction.none,
            ),
          ]) {
        expect(
          deepLinkAction(gate, target, stack),
          action,
          reason:
              '${gate.stage} ${gate.isBlocked ? 'locked' : ''} $target over $stack',
        );
      }
    });
  });

  group('the real router', () {
    testWidgets('after onboarding: the shell with Home; /history is in the '
        'Insights tab', (tester) async {
      final c = await _app(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
      expect(_selected(tester, ShellTab.home), isTrue);

      c.read(routerProvider).go(Routes.history);
      await _settle(tester);
      expect(_location(c), Routes.insightsHistory);
      expect(_selected(tester, ShellTab.insights), isTrue);
      await _end(tester);
    });

    testWidgets('Check in (centre action) opens above the shell and returns '
        'to the tab it came from', (tester) async {
      final c = await _app(tester);
      await tester.tap(find.byKey(AuraNavBar.tabKey(ShellTab.rooms)));
      await _settle(tester);
      expect(_location(c), Routes.rooms);

      await tester.tap(find.byKey(AuraNavBar.checkInKey));
      await _settle(tester);
      expect(find.byType(CheckInScreen), findsOneWidget);
      expect(find.byKey(AuraNavBar.barKey).hitTestable(), findsNothing);

      await tester.tap(find.byKey(const ValueKey('checkin-close')));
      await _settle(tester);
      expect(find.byType(CheckInScreen), findsNothing);
      expect(_location(c), Routes.rooms);
      expect(_selected(tester, ShellTab.rooms), isTrue);
      await _end(tester);
    });

    for (final (name, gate, screen) in [
      (
        'onboarding (Welcome)',
        const GateState(stage: OnboardingStage.welcome),
        'welcome-begin',
      ),
      ('the under-13 screen', _blocked, 'blocked-title'),
    ]) {
      testWidgets('"I need help now" on $name opens the Safety Center; Close '
          'returns there', (tester) async {
        await _app(tester, gate: gate);
        expect(find.byKey(ValueKey(screen)), findsOneWidget);
        await tester.tap(find.byType(HelpNowButton));
        await _settle(tester);
        expect(find.byType(SafetyCenterScreen), findsOneWidget);
        if (gate.isBlocked) {
          // A child: Childline is listed (India).
          expect(
            find.byKey(const ValueKey('safety-call-1098')),
            findsOneWidget,
          );
        }
        await tester.tap(find.byKey(const ValueKey('safety-close')));
        await _settle(tester);
        expect(find.byType(SafetyCenterScreen), findsNothing);
        expect(find.byKey(ValueKey(screen)), findsOneWidget);
        await _end(tester);
      });
    }
  });

  group('deep links', () {
    testWidgets('cold start aura://checkin: Home, with the check-in above it', (
      tester,
    ) async {
      final c = await _app(tester, link: 'aura://checkin');
      expect(find.byType(CheckInScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('checkin-close')));
      await _settle(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(_location(c), Routes.home);
      await _end(tester);
    });

    testWidgets('cold start aura://safety during onboarding: over the step', (
      tester,
    ) async {
      await _app(
        tester,
        gate: const GateState(stage: OnboardingStage.dob),
        link: 'aura://safety',
      );
      expect(find.byType(SafetyCenterScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('safety-close')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('dob-continue')), findsOneWidget);
      await _end(tester);
    });

    testWidgets('cold start aura://sanctuary while locked: the lock wins', (
      tester,
    ) async {
      await _app(tester, gate: _blocked, link: 'aura://sanctuary');
      expect(find.byType(BlockedScreen), findsOneWidget);
      expect(find.byType(SanctuaryScreen), findsNothing);
      await _end(tester);
    });

    testWidgets('running: safety over the tab, check-in back to its tab, '
        'sanctuary switches tabs', (tester) async {
      final c = await _app(tester);
      await tester.tap(find.byKey(AuraNavBar.tabKey(ShellTab.insights)));
      await _settle(tester);

      await _openLink(tester, 'aura://safety');
      expect(find.byType(SafetyCenterScreen), findsOneWidget);
      await _openLink(tester, 'aura://safety'); // never twice
      await tester.tap(find.byKey(const ValueKey('safety-close')));
      await _settle(tester);
      expect(find.byType(SafetyCenterScreen), findsNothing);
      expect(_location(c), Routes.insights);

      await _openLink(tester, 'aura://checkin');
      expect(find.byType(CheckInScreen), findsOneWidget);
      // Over unsaved input a tab link does nothing.
      await _openLink(tester, 'aura://sanctuary');
      expect(find.byType(CheckInScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('checkin-close')));
      await _settle(tester);
      expect(_location(c), Routes.insights);

      await _openLink(tester, 'aura://sanctuary');
      expect(_location(c), Routes.sanctuary);
      expect(find.byType(SanctuaryScreen), findsOneWidget);
      expect(_selected(tester, ShellTab.sanctuary), isTrue);
      await _end(tester);
    });

    testWidgets('running while locked or onboarding: only Safety opens', (
      tester,
    ) async {
      await _app(tester, gate: const GateState(stage: OnboardingStage.trust));
      await _openLink(tester, 'aura://checkin');
      await _openLink(tester, 'aura://sanctuary');
      expect(find.byKey(const ValueKey('trust-continue')), findsOneWidget);
      await _openLink(tester, 'aura://safety');
      expect(find.byType(SafetyCenterScreen), findsOneWidget);
      await _end(tester);
    });

    testWidgets('aura://auth-callback is left to Supabase: the screen stays', (
      tester,
    ) async {
      final c = await _app(tester);
      await tester.tap(find.byTooltip('Settings'));
      await _settle(tester);
      expect(_location(c), Routes.settings);
      await _openLink(tester, 'aura://auth-callback?code=abc');
      expect(_location(c), Routes.settings);
      await _end(tester);
    });

    testWidgets('cold start aura://auth-callback: the gate picks the screen', (
      tester,
    ) async {
      final c = await _app(
        tester,
        gate: const GateState(stage: OnboardingStage.signIn),
        link: 'aura://auth-callback?code=abc',
      );
      expect(_location(c), Routes.onboardingSignIn);
      await _end(tester);
    });
  });
}
