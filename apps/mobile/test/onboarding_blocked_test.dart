import 'package:aura/src/core/providers.dart';
import 'package:aura/src/features/onboarding/blocked_screen.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> pumpBlocked(
  WidgetTester tester, {
  String? region = 'IN',
  String supportEmail = 'help@example.org',
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testOverrides(
          db: memoryDb(),
          gate: GateState(
            stage: OnboardingStage.welcome,
            blockedUntil: testNow,
          ),
        ),
        deviceRegionProvider.overrideWithValue(region),
      ],
      child: localized(BlockedScreen(supportEmail: supportEmail)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('India: Childline and 112 read with their names, not bare '
      'digits; help stays on screen', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBlocked(tester);

    expect(find.byType(HelpNowButton), findsOneWidget);
    expect(
      find.bySemanticsLabel('Call Childline · for under-18s, 1098'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Call Emergency, 112'), findsOneWidget);
    // A screen reader's double-tap reaches the call action.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Call Emergency, 112')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    // Only the two F8 lines, not the full support-sheet list.
    expect(find.byKey(const ValueKey('blocked-call-14416')), findsNothing);
    expect(find.bySemanticsLabel('1098'), findsNothing);
    handle.dispose();
  });

  testWidgets('elsewhere: no numbers, just "an adult you trust"', (
    tester,
  ) async {
    await pumpBlocked(tester, region: 'US');
    expect(find.byKey(const ValueKey('blocked-call-1098')), findsNothing);
    expect(find.byKey(const ValueKey('blocked-call-112')), findsNothing);
    expect(find.textContaining('an adult you trust'), findsOneWidget);
    expect(find.byType(HelpNowButton), findsOneWidget);
  });

  testWidgets('"Entered the wrong date?" is hidden without a support address', (
    tester,
  ) async {
    await pumpBlocked(tester, supportEmail: '');
    expect(find.byKey(const ValueKey('blocked-wrong-date')), findsNothing);
    expect(find.text('Entered the wrong date?'), findsNothing);
  });

  testWidgets('"Entered the wrong date?" emails support with a subject only; '
      'if no mail app opens, the address is shown', (tester) async {
    final launched = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return false; // no mail app
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        null,
      ),
    );
    final handle = tester.ensureSemantics();
    await pumpBlocked(tester);

    final link = find.byKey(const ValueKey('blocked-wrong-date'));
    expect(link, findsOneWidget);
    expect(
      tester.getSemantics(link),
      isSemantics(
        label: 'Entered the wrong date?',
        hint: 'Opens your email app',
      ),
    );
    await tester.tap(link);
    await tester.pump();

    expect(launched, hasLength(1));
    final uri = Uri.parse(launched.single);
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'help@example.org');
    expect(uri.queryParameters.keys, ['subject']);
    expect(uri.queryParameters['subject'], 'Aura: I entered the wrong date');

    final failed = find.byKey(const ValueKey('blocked-mail-failed'));
    expect(failed, findsOneWidget);
    expect(tester.getSemantics(failed), isSemantics(isLiveRegion: true));
    expect(find.textContaining('help@example.org'), findsOneWidget);
    handle.dispose();
  });

  test('the mailto carries no personal data, only the subject', () {
    final uri = wrongDateMailto('help@example.org', 'Aura: wrong date');
    expect(
      uri.toString(),
      'mailto:help@example.org?subject=Aura%3A%20wrong%20date',
    );
    expect(uri.queryParameters.keys, ['subject']);
  });
}
