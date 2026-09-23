import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_blocked_test.dart' show pumpBlocked;

const _launcher = MethodChannel('plugins.flutter.io/url_launcher');

/// Answers url_launcher's `launch` with [result], recording each URL.
List<String> _dialer(WidgetTester tester, bool result) {
  final launched = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_launcher, (
    call,
  ) async {
    if (call.method == 'launch') {
      launched.add((call.arguments as Map)['url'] as String);
    }
    return result;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _launcher,
      null,
    ),
  );
  return launched;
}

/// The under-13 screen's helplines on a device that can't dial (iPad,
/// simulator): the number shows with a Copy action instead of nothing.
void main() {
  testWidgets('a failed call shows the number with Copy; closing hides it', (
    tester,
  ) async {
    final launched = _dialer(tester, false);
    await pumpBlocked(tester);

    await tester.tap(find.byKey(const ValueKey('blocked-call-1098')));
    await tester.pumpAndSettle();

    expect(launched, ['tel:1098']);
    final notice = find.byKey(const ValueKey('blocked-call-failed-1098'));
    expect(notice, findsOneWidget);
    expect(
      find.descendant(of: notice, matching: find.textContaining('1098')),
      findsWidgets,
    );

    await tester.tap(
      find.descendant(of: notice, matching: find.byTooltip('Close')),
    );
    await tester.pumpAndSettle();
    expect(notice, findsNothing);
  });

  testWidgets('a phone that can call shows no fallback', (tester) async {
    _dialer(tester, true);
    await pumpBlocked(tester);

    await tester.tap(find.byKey(const ValueKey('blocked-call-112')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('blocked-call-failed-112')), findsNothing);
  });
}
