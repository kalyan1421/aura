import 'package:aura/src/core/env/env.dart';
import 'package:aura/src/core/widgets/legal_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Legal links when the browser can't open: a calm note with the address
/// and a Copy action that stays until closed.

Future<void> _pump(
  WidgetTester tester,
  Widget links, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(375 * 3, 667 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    localized(
      Scaffold(
        body: ListView(padding: const EdgeInsets.all(20), children: [links]),
      ),
    ),
  );
}

/// Records what goes on the clipboard.
List<String> _clipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

void main() {
  final privacy = Env.privacyPolicyUrl;
  final message = "Your browser didn't open. The page is at $privacy.";

  testWidgets('const LegalLinks() still works and shows no note', (
    tester,
  ) async {
    await _pump(tester, const LegalLinks());
    expect(find.byKey(const ValueKey('legal-privacy')), findsOneWidget);
    expect(find.byKey(const ValueKey('legal-terms')), findsOneWidget);
    expect(find.textContaining("didn't open"), findsNothing);
  });

  for (final (name, opener) in <(String, UrlOpener)>[
    ('returns false', (_) async => false),
    (
      'throws',
      (_) async => throw PlatformException(code: 'ACTIVITY_NOT_FOUND'),
    ),
  ]) {
    testWidgets('the browser $name: a calm note with the address and Copy, '
        'which stays until closed', (tester) async {
      final handle = tester.ensureSemantics();
      final copied = _clipboard(tester);
      final opened = <Uri>[];
      await _pump(
        tester,
        LegalLinks(
          opener: (uri) {
            opened.add(uri);
            return opener(uri);
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey('legal-privacy')));
      await tester.pump();
      expect(opened.single.toString(), privacy);
      expect(tester.takeException(), isNull);
      expect(find.text(message), findsOneWidget);
      expect(
        tester.getSemantics(find.text(message)),
        isSemantics(isLiveRegion: true, label: message),
      );

      // Still there well past 5 s: nothing times it out.
      await tester.pump(const Duration(seconds: 12));
      expect(find.text(message), findsOneWidget);

      await tester.tap(find.text('Copy link'));
      await tester.pump();
      expect(copied, [privacy]);
      expect(find.text('Link copied'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      expect(find.text(message), findsNothing);
      handle.dispose();
    });
  }

  testWidgets('a page that opens shows no note, and clears an earlier one', (
    tester,
  ) async {
    var works = false;
    await _pump(tester, LegalLinks(opener: (_) async => works));

    await tester.tap(find.byKey(const ValueKey('legal-terms')));
    await tester.pump();
    expect(find.textContaining(Env.termsUrl), findsOneWidget);

    works = true;
    await tester.tap(find.byKey(const ValueKey('legal-privacy')));
    await tester.pump();
    expect(find.textContaining("didn't open"), findsNothing);
  });

  testWidgets('the note fits at 200% text', (tester) async {
    await _pump(tester, LegalLinks(opener: (_) async => false), scale: 2);
    await tester.tap(find.byKey(const ValueKey('legal-privacy')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(message), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(
      tester
          .getSize(find.widgetWithIcon(IconButton, Icons.close_rounded))
          .height,
      greaterThanOrEqualTo(48),
    );
  });
}
