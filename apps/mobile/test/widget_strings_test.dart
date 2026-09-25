import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The native home-screen widgets (F11) carry fallback copy for the moments
/// before the app has published anything. It is generated from the Flutter
/// ARB files (tool/gen_widget_strings.py via tool/gen.sh), and this test
/// fails when either side drifts: every native key in all five languages,
/// exactly the ARB text.
void main() {
  const keys = [
    'widget_prompt',
    'widget_checkIn',
    'widget_doneToday',
    'widget_saved',
    'widget_needHelp',
    'widget_openApp',
    'widget_openAppDiscreet',
    'widget_back',
    'widget_galleryName',
    'widget_galleryDescription',
    'widget_lockGalleryName',
    'widget_lockGalleryDescription',
  ];
  // ARB locale → (iOS language, Android values qualifier).
  const locales = {
    'en': ('en', 'values'),
    'te': ('te', 'values-te'),
    'te_Latn': ('te-Latn', 'values-b+te+Latn'),
    'hi': ('hi', 'values-hi'),
    'hi_Latn': ('hi-Latn', 'values-b+hi+Latn'),
  };

  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  test('the generator knows the same keys as this test', () {
    final source = File('tool/gen_widget_strings.py').readAsStringSync();
    for (final k in keys) {
      expect(source, contains('"$k"'));
    }
  });

  test('iOS String Catalog matches the ARB files', () {
    final catalog = jsonDecode(
      File('ios/AuraWidget/Localizable.xcstrings').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(catalog['sourceLanguage'], 'en');
    final strings = catalog['strings'] as Map<String, dynamic>;
    expect(strings.keys.toSet(), keys.toSet());
    for (final MapEntry(key: locale, value: (lang, _)) in locales.entries) {
      final values = arb(locale);
      for (final k in keys) {
        final unit =
            (strings[k]['localizations'] as Map<String, dynamic>)[lang]
                as Map<String, dynamic>?;
        expect(unit, isNotNull, reason: '$k has no $lang');
        expect(unit!['stringUnit']['value'], values[k], reason: '$k/$lang');
      }
    }
  });

  test('Android strings match the ARB files', () {
    final entry = RegExp(r'<string name="([^"]+)">(.*?)</string>');
    String unescape(String s) => s
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
    for (final MapEntry(key: locale, value: (_, qualifier))
        in locales.entries) {
      final xml = File('android/app/src/main/res/$qualifier/widget_strings.xml')
          .readAsStringSync();
      final found = {
        for (final m in entry.allMatches(xml)) m[1]!: unescape(m[2]!),
      };
      final values = arb(locale);
      expect(found.keys.toSet(), keys.toSet(), reason: qualifier);
      for (final k in keys) {
        expect(found[k], values[k], reason: '$k/$qualifier');
      }
    }
  });
}
