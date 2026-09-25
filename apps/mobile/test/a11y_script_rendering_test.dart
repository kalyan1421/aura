import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// REQ-A11Y-14 "Script-aware line height for Telugu and Devanagari": `te`
/// text uses Noto Sans Telugu and `hi` Noto Sans Devanagari with line height
/// ≥ 1.5 and no fixed-height text boxes; golden images at 100%, 150% and
/// 200% in `te` and `hi` of the words that matter most (the mood labels, the
/// support sheet's lines, a button and a chip) with the real bundled fonts,
/// for a person to check that no vowel sign or conjunct (vattulu) is clipped.
/// Regenerate with `flutter test --update-goldens test/a11y_script_rendering_test.dart`
/// and review the images before committing them.

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await family(AuraFonts.telugu, [
    'NotoSansTelugu-Regular.ttf',
    'NotoSansTelugu-Medium.ttf',
    'NotoSansTelugu-SemiBold.ttf',
  ]);
  await family(AuraFonts.devanagari, [
    'NotoSansDevanagari-Regular.ttf',
    'NotoSansDevanagari-Medium.ttf',
    'NotoSansDevanagari-SemiBold.ttf',
  ]);
}

Widget _sample(Locale locale, double scale) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildAuraTheme(locale),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...systemLocalizationDelegates,
  ],
  home: Builder(
    builder: (context) {
      final l = AppLocalizations.of(context);
      final t = Theme.of(context).textTheme;
      final tag = tagFromLocale(locale);
      return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('sample'),
            // The night sky behind, as in the app, so the light text reads.
            child: Container(
              color: const Color(0xFF0A0C1D),
              width: 390,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.help_crisisTitle, style: t.headlineSmall),
                    Text(l.help_subtitle, style: t.bodyLarge),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in moodCatalog.take(8))
                          Chip(label: Text(m.nameFor(tag))),
                      ],
                    ),
                    FilledButton(onPressed: () {}, child: Text(l.help_button)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  ),
);

void main() {
  setUpAll(_loadFonts);

  test('Telugu and Devanagari reading styles are at least 1.5 line height, '
      'in the bundled Noto families', () {
    for (final locale in const [Locale('te'), Locale('hi')]) {
      final theme = buildAuraTheme(locale);
      final t = theme.textTheme;
      for (final (name, style) in [
        ('displaySmall', t.displaySmall),
        ('headlineMedium', t.headlineMedium),
        ('headlineSmall', t.headlineSmall),
        ('titleLarge', t.titleLarge),
        ('titleMedium', t.titleMedium),
        ('titleSmall', t.titleSmall),
        ('bodyLarge', t.bodyLarge),
        ('bodyMedium', t.bodyMedium),
        ('bodySmall', t.bodySmall),
        ('labelLarge', t.labelLarge),
        ('labelMedium', t.labelMedium),
        ('labelSmall', t.labelSmall),
      ]) {
        expect(
          style?.height,
          greaterThanOrEqualTo(1.5),
          reason: '$locale $name',
        );
      }
      expect(
        theme.textTheme.bodyLarge?.fontFamily,
        locale.languageCode == 'te' ? AuraFonts.telugu : AuraFonts.devanagari,
      );
    }
    // Romanized text keeps the system font and Latin line height.
    final latn = buildAuraTheme(
      const Locale.fromSubtags(languageCode: 'te', scriptCode: 'Latn'),
    );
    expect(latn.textTheme.bodyLarge?.fontFamily, isNot(AuraFonts.telugu));
  });

  for (final locale in const [Locale('te'), Locale('hi')]) {
    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets('${locale.languageCode} at ${(scale * 100).round()}%: '
          'nothing overflows; golden for review', (tester) async {
        tester.view.physicalSize = const Size(1170, 4000);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_sample(locale, scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('sample')),
          matchesGoldenFile(
            'goldens/script_${locale.languageCode}_${(scale * 100).round()}.png',
          ),
        );
      });
    }
  }
}
