import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// REQ-A11Y-13 "Correct language for speech": Telugu strings carry `te` and
/// Hindi strings `hi` in semantics, so TTS picks a matching voice; Tenglish
/// and Hinglish are read by the English voice (accepted, PRD 17).

Future<Locale?> _spokenAs(WidgetTester tester, Locale app) async {
  await tester.pumpWidget(
    MaterialApp(
      // The same wrapper as AuraApp's builder (lib/src/app.dart).
      builder: (context, child) =>
          Semantics(localeForSubtree: speechLocaleFor(app), child: child!),
      home: const Scaffold(body: Text('ఈ రోజు ఎలా ఉంది?')),
    ),
  );
  return tester
      .getSemantics(find.text('ఈ రోజు ఎలా ఉంది?'))
      .getSemanticsData()
      .locale;
}

void main() {
  test('the speech locale per app language', () {
    expect(speechLocaleFor(const Locale('en')), const Locale('en'));
    expect(speechLocaleFor(const Locale('te')), const Locale('te'));
    expect(speechLocaleFor(const Locale('hi')), const Locale('hi'));
    expect(
      speechLocaleFor(
        const Locale.fromSubtags(languageCode: 'te', scriptCode: 'Latn'),
      ),
      const Locale('en'),
    );
    expect(
      speechLocaleFor(
        const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
      ),
      const Locale('en'),
    );
  });

  testWidgets('Telugu text is tagged te in the semantics tree', (tester) async {
    final handle = tester.ensureSemantics();
    expect(await _spokenAs(tester, const Locale('te')), const Locale('te'));
    handle.dispose();
  });

  testWidgets('Hindi text is tagged hi; English en', (tester) async {
    final handle = tester.ensureSemantics();
    expect(await _spokenAs(tester, const Locale('hi')), const Locale('hi'));
    expect(await _spokenAs(tester, const Locale('en')), const Locale('en'));
    handle.dispose();
  });
}
