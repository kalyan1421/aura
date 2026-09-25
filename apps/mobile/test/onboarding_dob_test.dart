import 'package:aura/src/core/theme/aura_tokens.dart';
import 'package:aura/src/core/widgets/inline_notice.dart';
import 'package:aura/src/features/onboarding/dob_screen.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> pumpDob(WidgetTester tester, {double textScale = 1}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        db: memoryDb(),
        gate: const GateState(stage: OnboardingStage.dob),
      ),
      child: localized(const DobScreen()),
    ),
  );
  await tester.pump();
}

/// Scrolls the page to [field] (at large text sizes it sits below the fold)
/// and opens its picker sheet.
Future<void> openSheet(WidgetTester tester, String field) async {
  final target = find.byKey(ValueKey('dob-$field'));
  await tester.scrollUntilVisible(
    target,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Taps [value] in the open sheet, scrolling the list as needed.
Future<void> tapOption(WidgetTester tester, int value) async {
  final option = find.byKey(ValueKey('dob-option-$value')).hitTestable();
  final list = find.byType(ListView).last;
  // The year sheet opens scrolled near 2008: look down, then up.
  for (var i = 0; i < 80 && option.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -80));
    await tester.pumpAndSettle();
  }
  for (var i = 0; i < 2 * 80 && option.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, 80));
    await tester.pumpAndSettle();
  }
  await tester.tap(option);
  await tester.pumpAndSettle();
}

/// Types [year] into the year sheet's field and presses Done.
Future<void> typeYear(WidgetTester tester, String year) async {
  await openSheet(tester, 'year');
  await tester.enterText(find.byKey(const ValueKey('dob-year-input')), year);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

String fieldLabel(WidgetTester tester, String field) =>
    tester.getSemantics(find.byKey(ValueKey('dob-$field'))).label;

void main() {
  testWidgets('an impossible date is a calm live-region notice, not lantern '
      'text; Continue stays off', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpDob(tester);
    await openSheet(tester, 'day');
    await tapOption(tester, 31);
    await openSheet(tester, 'month');
    await tapOption(tester, 2); // February
    await typeYear(tester, '2000');

    const message = "That date doesn't exist. Could you check it?";
    final notice = find.byKey(const ValueKey('dob-error'));
    expect(notice, findsOneWidget);
    expect(tester.widget(notice), isA<InlineNotice>());
    expect(
      tester.getSemantics(notice),
      isSemantics(isLiveRegion: true, label: message),
    );
    // Lantern belongs to immediate support; the only lantern on this screen
    // is the help button.
    final inNotice = find.descendant(of: notice, matching: find.byType(Text));
    for (final text in tester.widgetList<Text>(inNotice)) {
      expect(text.style?.color, isNot(AuraColors.lantern));
    }
    for (final icon in tester.widgetList<Icon>(
      find.descendant(of: notice, matching: find.byType(Icon)),
    )) {
      expect(icon.color, isNot(AuraColors.lantern));
    }
    final cont = find.byKey(const ValueKey('dob-continue'));
    expect(tester.widget<FilledButton>(cont).onPressed, isNull);

    // Fixing the day clears the notice.
    await openSheet(tester, 'day');
    await tapOption(tester, 28);
    expect(notice, findsNothing);
    expect(tester.widget<FilledButton>(cont).onPressed, isNotNull);
    handle.dispose();
  });

  testWidgets('no default year: the field, the typed input and the list all '
      'start empty (REQ-ACC-02)', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpDob(tester);
    expect(fieldLabel(tester, 'year'), 'Year');
    expect(find.text('—'), findsNWidgets(3));
    // A screen-reader double-tap opens the picker.
    expect(
      tester.getSemantics(find.byKey(const ValueKey('dob-year'))),
      isSemantics(isButton: true, hasTapAction: true),
    );

    await openSheet(tester, 'year');
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('dob-year-input')),
    );
    expect(input.controller!.text, isEmpty);
    expect(input.decoration?.hintText, isNull);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    handle.dispose();
  });

  testWidgets('the year list opens scrolled near a typical first-run age '
      '(2008), not at the youngest years, with nothing picked', (tester) async {
    await pumpDob(tester);
    await openSheet(tester, 'year');
    final year = testNow.toLocal().year - dobTypicalAge;
    expect(
      find.byKey(ValueKey('dob-option-$year')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find
          .byKey(ValueKey('dob-option-${testNow.toLocal().year}'))
          .hitTestable(),
      findsNothing,
    );
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('typing the year filters the list; Done picks the single match', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpDob(tester);
    await openSheet(tester, 'year');
    final input = find.byKey(const ValueKey('dob-year-input'));
    final sheetHeight = tester.getSize(find.byType(DobPickerSheet)).height;

    // Digits only, at most four.
    await tester.enterText(input, '19x9');
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, '199');
    // Filtering does not resize the sheet under the finger.
    expect(tester.getSize(find.byType(DobPickerSheet)).height, sheetHeight);
    expect(find.byKey(const ValueKey('dob-option-1995')), findsOneWidget);
    expect(find.byKey(const ValueKey('dob-option-2006')), findsNothing);

    // A year outside the list: a calm live-region note, nothing picked.
    await tester.enterText(input, '1850');
    await tester.pump();
    final none = find.byKey(const ValueKey('dob-year-nomatch'));
    expect(none, findsOneWidget);
    expect(tester.getSemantics(none), isSemantics(isLiveRegion: true));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(input, findsOneWidget); // still open

    await tester.enterText(input, '2006');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(fieldLabel(tester, 'year'), 'Year, 2006');
    handle.dispose();
  });

  testWidgets('reopening marks the current value and scrolls it into view', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpDob(tester);
    await typeYear(tester, '1931'); // near the end of the list

    await openSheet(tester, 'year');
    final option = find.byKey(const ValueKey('dob-option-1931'));
    expect(option.hitTestable(), findsOneWidget);
    expect(
      find.descendant(of: option, matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(
      tester.getSemantics(option),
      isSemantics(isSelected: true, label: '1931'),
    );
    handle.dispose();
  });

  testWidgets('sheets have a header title and close without dragging', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpDob(tester);
    await openSheet(tester, 'month');
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byType(DobPickerSheet),
          matching: find.text('Month'),
        ),
      ),
      isSemantics(isHeader: true),
    );
    final close = find.byTooltip('Close');
    expect(close, findsOneWidget);
    expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(DobPickerSheet), findsNothing);
    expect(fieldLabel(tester, 'month'), 'Month');
    handle.dispose();
  });

  testWidgets('at 200% text the screen and the year sheet lay out and scroll', (
    tester,
  ) async {
    await pumpDob(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    await openSheet(tester, 'year');
    expect(tester.takeException(), isNull);
    await tapOption(tester, 1950);
    expect(tester.takeException(), isNull);
    expect(find.text('1950'), findsOneWidget);
  });

  testWidgets('help is on the screen; no copy mentions 13 or 18', (
    tester,
  ) async {
    await pumpDob(tester);
    expect(find.byType(HelpNowButton), findsOneWidget);
    final ageCopy = RegExp(r'\b1[38]\b');
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data ?? text.textSpan?.toPlainText() ?? '';
      expect(ageCopy.hasMatch(data), isFalse, reason: data);
    }
  });
}
