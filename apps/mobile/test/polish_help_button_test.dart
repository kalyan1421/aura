import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/home/home_screen.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// "I need help now" at 1.0 and 2.0 text scale, in English and Telugu:
/// never clipped, still clearly a button (a pill on one line, a rounded
/// rectangle once it wraps, never a near-circle), ≥ 48 dp, and within the
/// first three focus stops on Home.

void _setSize(WidgetTester tester, Size logical, double scale) {
  tester.view.physicalSize = logical * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Widget _home(Locale locale, String tag) => ProviderScope(
  overrides: testOverrides(db: memoryDb(), locale: tag),
  child: MaterialApp.router(
    theme: buildAuraTheme(locale),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...systemLocalizationDelegates,
    ],
    routerConfig: GoRouter(
      initialLocation: Routes.home,
      routes: [
        GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
      ],
    ),
  ),
);

/// A compact top bar like Check-in's: a 48 dp close, then help in a
/// Flexible that is [slot] dp wide.
Widget _slot(Locale locale, double slot) => localized(
  Scaffold(
    body: SafeArea(
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(
          width: 48 + 8 + slot,
          child: const Row(
            children: [
              SizedBox(width: 48, height: 48),
              SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: HelpNowButton(compact: true),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
  locale: locale,
);

/// Checks the button's geometry; returns whether its label wrapped.
/// [minRatio] is the least width / height of the visible shape.
bool _expectReadableButton(
  WidgetTester tester,
  String reason, {
  double minRatio = 1.0,
}) {
  expect(tester.takeException(), isNull, reason: reason);
  final button = find.byType(HelpNowButton);
  expect(button, findsOneWidget, reason: reason);

  // The tap target (padded) stays ≥ 48 dp.
  final target = tester.getSize(
    find.descendant(of: button, matching: find.byType(OutlinedButton)),
  );
  expect(target.height, greaterThanOrEqualTo(48), reason: reason);
  expect(target.width, greaterThanOrEqualTo(48), reason: reason);

  // The visible shape.
  final material = find
      .descendant(of: button, matching: find.byType(Material))
      .first;
  final rect = tester.getRect(material);
  final path = tester.widget<Material>(material).shape!.getOuterPath(rect);

  // The whole label is laid out (no line cap, no ellipsis) and every glyph
  // sits inside the visible shape.
  // The label's paragraph (the icon is a RichText too).
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: find.descendant(of: button, matching: find.byType(Text)),
      matching: find.byType(RichText),
    ),
  );
  expect(paragraph.didExceedMaxLines, isFalse, reason: reason);
  final text = paragraph.text.toPlainText();
  var glyphs = 0;
  final lineTops = <int>{};
  // Per grapheme cluster: a Telugu conjunct is one glyph run.
  var offset = 0;
  for (final cluster in text.characters) {
    final start = offset;
    offset += cluster.length;
    if (cluster.trim().isEmpty) continue; // spaces hang past a wrap
    for (final box in paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: offset),
    )) {
      final r = box.toRect().deflate(0.5);
      if (r.isEmpty) continue;
      glyphs++;
      lineTops.add(box.top.round());
      for (final corner in [
        r.topLeft,
        r.topRight,
        r.bottomLeft,
        r.bottomRight,
      ]) {
        final p = paragraph.localToGlobal(corner);
        expect(
          path.contains(p),
          isTrue,
          reason: '$reason: "$cluster" at $p is outside the button $rect',
        );
      }
    }
  }
  expect(glyphs, greaterThan(0), reason: reason);

  final wrapped = lineTops.length > 1;
  // About as wide as tall or wider: a button, never a tall sliver.
  expect(
    rect.width / rect.height,
    greaterThanOrEqualTo(minRatio),
    reason: reason,
  );
  // A point 6 dp in from the corner is inside a rounded rectangle
  // (radius 18) but outside a pill of this height.
  expect(
    path.contains(rect.topLeft + const Offset(6, 6)),
    wrapped,
    reason: '$reason: ${wrapped ? 'rounded rectangle' : 'pill'} expected',
  );
  return wrapped;
}

void main() {
  const locales = {'en': Locale('en'), 'te': Locale('te')};

  for (final MapEntry(key: tag, value: locale) in locales.entries) {
    for (final scale in [1.0, 2.0]) {
      for (final size in const [Size(375, 667), Size(390, 844)]) {
        final name = '${size.width.toInt()}×${size.height.toInt()}';
        testWidgets('Home $name, $tag, ${scale}x: readable, a button, within '
            'the first three focus stops', (tester) async {
          _setSize(tester, size, scale);
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(_home(locale, tag));
          await settleIo(tester);
          _expectReadableButton(tester, 'Home $name $tag $scale');

          final order = tester.semantics
              .simulatedAccessibilityTraversal()
              .toList();
          final l = AppLocalizations.of(
            tester.element(find.byType(HelpNowButton)),
          );
          final help = order.indexWhere(
            (n) => n.getSemanticsData().label.contains(l.help_button),
          );
          expect(help, inInclusiveRange(0, 2), reason: '$order');
          handle.dispose();
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        });
      }

      // A phone-wide bar, and Settings' 230 dp cap (the narrowest slot).
      for (final slot in [319.0, 230.0]) {
        testWidgets('compact top bar ${slot.toInt()} dp, $tag, ${scale}x: '
            'readable and a button', (tester) async {
          _setSize(tester, const Size(375, 667), scale);
          await tester.pumpWidget(_slot(locale, slot));
          await tester.pump();
          // The test font is about twice as wide as real ones, so Telugu at
          // 200% in the narrowest slot is a stress case: allow a slightly
          // tall (still rounded-rectangle) button there.
          _expectReadableButton(
            tester,
            'slot $slot $tag $scale',
            minRatio: slot < 300 && scale > 1 ? 0.8 : 1.0,
          );
        });
      }
    }
  }

  testWidgets('one line: a pill; wrapped: a rounded rectangle', (tester) async {
    _setSize(tester, const Size(700, 400), 1.0);
    await tester.pumpWidget(_slot(const Locale('en'), 600));
    await tester.pump();
    expect(_expectReadableButton(tester, 'wide'), isFalse);

    await tester.pumpWidget(_slot(const Locale('en'), 220));
    await tester.pump();
    expect(_expectReadableButton(tester, 'narrow'), isTrue);
  });
}
