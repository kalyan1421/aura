// Hindi (`hi`) and Hinglish (`hi-Latn`) UI, Milestone B (PRD 18). Every ARB
// key exists in both, with the English placeholders, and none of them is the
// English copy left in place: the generator (tool/l10n_source.py) refuses a
// missing translation, and this test checks what actually ships. The
// language picker offers both and switches the UI at once. The translations
// are drafts for native review (docs/l10n/hindi-review.md).
import 'dart:convert';
import 'dart:io';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/env/env.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/features/onboarding/language_screen.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

final _devanagari = RegExp('[ऀ-ॿ]');

/// Terms that stay in Latin script in every language (PRD 18 brand rule),
/// plus units: a Hindi string made only of these may equal the English.
const _latinTerms = [
  'Suicide & Crisis Lifeline',
  'Breath Ripples',
  'Lantern Hour',
  'Aura Plus',
  'Aura Sky',
  'Google Play',
  'App Store',
  'Starlight',
  'Stardust',
  'Tele-MANAS',
  'Childline',
  'Aura',
  'Plus',
  'MB',
];

/// [text] without ICU syntax, placeholders and the Latin-script terms.
String _words(String text) {
  var t = text
      .replaceAll(RegExp(r'\{\s*\w+\s*,\s*(plural|select)\s*,'), ' ')
      .replaceAll(RegExp(r'(=\d+|\bother|\bone|\bzero)\s*\{'), ' ')
      .replaceAll(RegExp(r'\{\w+\}'), ' ');
  for (final term in _latinTerms) {
    t = t.replaceAll(term, ' ');
  }
  return t;
}

/// The declared placeholders a message uses (`{name}` or `{name, plural…}`).
Set<String> _uses(String text, Iterable<String> declared) => {
  for (final n in declared)
    if (RegExp('\\{\\s*${RegExp.escape(n)}\\s*[,}]').hasMatch(text)) n,
};

void main() {
  final en = _arb('en');
  final keys = [
    for (final k in en.keys)
      if (!k.startsWith('@')) k,
  ];

  test('the English catalogue is big enough to mean something', () {
    expect(keys.length, greaterThan(1000));
  });

  for (final locale in ['hi', 'hi_Latn']) {
    group('app_$locale.arb', () {
      final arb = _arb(locale);

      test('declares its locale', () {
        expect(arb['@@locale'], locale);
      });

      test('has every key, and no key English lacks', () {
        final missing = [
          for (final k in keys)
            if (arb[k] is! String || (arb[k] as String).trim().isEmpty) k,
        ];
        expect(missing, isEmpty, reason: 'untranslated: $missing');
        final extra = [
          for (final k in arb.keys)
            if (!k.startsWith('@') && !en.containsKey(k)) k,
        ];
        expect(extra, isEmpty);
      });

      test('keeps the English placeholders in every message', () {
        for (final k in keys) {
          final meta = en['@$k'] as Map<String, dynamic>?;
          final declared =
              (meta?['placeholders'] as Map<String, dynamic>?)?.keys ??
              const <String>[];
          if (declared.isEmpty) continue;
          expect(
            _uses(arb[k] as String, declared),
            _uses(en[k] as String, declared),
            reason: k,
          );
        }
      });

      test('no English fallback: a message equal to the English is made only '
          'of brand terms, placeholders and numbers', () {
        final fallback = [
          for (final k in keys)
            if (locale == 'hi' &&
                arb[k] == en[k] &&
                RegExp('[A-Za-z]{2,}').hasMatch(_words(en[k] as String)))
              k,
        ];
        expect(fallback, isEmpty, reason: 'English left in Hindi: $fallback');
        // Hinglish keeps English words where people use them, but a long
        // sentence identical to the English means it was never translated.
        final sentences = [
          for (final k in keys)
            if (locale == 'hi_Latn' &&
                arb[k] == en[k] &&
                RegExp(r"[A-Za-z][A-Za-z'-]+")
                        .allMatches(_words(en[k] as String))
                        .length >=
                    5)
              k,
        ];
        expect(sentences, isEmpty, reason: 'English left: $sentences');
      });

      test(
        locale == 'hi'
            ? 'Hindi is written in Devanagari'
            : 'Hinglish is written in Latin letters only',
        () {
          for (final k in keys) {
            final text = arb[k] as String;
            if (locale == 'hi_Latn') {
              expect(_devanagari.hasMatch(text), isFalse, reason: k);
            } else if (RegExp('[A-Za-z]{2,}')
                .hasMatch(_words(en[k] as String))) {
              expect(_devanagari.hasMatch(text), isTrue, reason: '$k: $text');
            }
          }
        },
      );

      test('brand terms stay in Latin script (PRD 18)', () {
        for (final k in keys) {
          for (final term in const [
            'Aura',
            'Starlight',
            'Stardust',
            'Lantern Hour',
            'Breath Ripples',
          ]) {
            if ((en[k] as String).contains(term)) {
              expect(arb[k], contains(term), reason: '$k ($term)');
            }
          }
        }
      });
    });
  }

  group('generated localizations', () {
    test('hi and hi-Latn resolve to their own classes, not English', () {
      final english = lookupAppLocalizations(const Locale('en'));
      final hi = lookupAppLocalizations(const Locale('hi'));
      final hl = lookupAppLocalizations(localeFromTag('hi-Latn'));
      expect(hi.localeName, 'hi');
      expect(hl.localeName, 'hi_Latn');
      expect(hi.help_button, 'मुझे अभी मदद चाहिए');
      expect(hl.help_button, 'Mujhe abhi madad chahiye');
      expect(hi.quadrant_rain, 'बारिश');
      expect(hl.quadrant_rain, 'Rain'); // theme words stay English in Hinglish
      expect(hi.home_restDays(3), isNot(english.home_restDays(3)));
      expect(hl.home_restDays(3), contains('3'));
      expect(hi.notif_roomsPoolBanner, 'हिंदी और हिंग्लिश रूम अब खुल गए हैं।');
      expect(
        hl.notif_roomsPoolBanner,
        'Hindi aur Hinglish rooms ab khul gaye hain.',
      );
    });
  });

  group('language picker', () {
    // Hindi and Hinglish stay hidden until the crisis lexicon has reviewed
    // hi / hi-Latn terms (Env.betaLocales). The on-state tests run in review
    // builds: flutter test --dart-define=AURA_BETA_LOCALES=true
    test('off by default: the picker offers en / te / te-Latn only and a Hindi '
        'device starts in English', () {
      if (Env.betaLocales) return;
      expect(pickerLocales, [
        AuraLocales.en,
        AuraLocales.te,
        AuraLocales.teLatn,
      ]);
      expect(defaultLocaleTag(const [Locale('hi', 'IN')]), AuraLocales.en);
    });

    test('with the flag on: all five languages are offered', () {
      expect(localeEndonyms[AuraLocales.hi], 'हिन्दी');
      expect(localeEndonyms[AuraLocales.hiLatn], 'Hinglish');
      if (!Env.betaLocales) return;
      expect(pickerLocales, [
        AuraLocales.en,
        AuraLocales.te,
        AuraLocales.teLatn,
        AuraLocales.hi,
        AuraLocales.hiLatn,
      ]);
    });

    test('with the flag on: a Hindi device starts in Hindi; romanized is '
        'always a choice', () {
      if (!Env.betaLocales) return;
      expect(defaultLocaleTag(const [Locale('hi', 'IN')]), AuraLocales.hi);
      expect(
        defaultLocaleTag(const [Locale('fr'), Locale('hi')]),
        AuraLocales.hi,
      );
      expect(defaultLocaleTag(const [Locale('fr')]), AuraLocales.en);
    });

    testWidgets(
      'with the flag on: tapping Hindi, then Hinglish, switches the '
      'UI at once and keeps the choice',
      skip: !Env.betaLocales,
      (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final db = memoryDb();
        await tester.pumpWidget(
          ProviderScope(
            overrides: testOverrides(db: db),
            child: Consumer(
              builder: (context, ref, _) => localized(
                Builder(
                  builder: (context) => Scaffold(
                    body: ListView(
                      children: [
                        Text(AppLocalizations.of(context).language_title),
                        const LanguagePicker(),
                      ],
                    ),
                  ),
                ),
                locale: localeFromTag(ref.watch(localeControllerProvider)),
              ),
            ),
          ),
        );
        await settleIo(tester);
        for (final tag in pickerLocales) {
          expect(
            find.byKey(ValueKey('lang-$tag')),
            findsOneWidget,
            reason: tag,
          );
        }
        expect(find.text('हिन्दी'), findsOneWidget);
        expect(find.text('Hindi in English letters'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('lang-hi')));
        await settleIo(tester);
        final hi = lookupAppLocalizations(const Locale('hi'));
        expect(find.text(hi.language_title), findsOneWidget);
        expect(find.text(hi.language_hiLatnHint), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('lang-hi-Latn')));
        await settleIo(tester);
        final hl = lookupAppLocalizations(localeFromTag('hi-Latn'));
        expect(find.text(hl.language_title), findsOneWidget);
        expect(
          await io(tester, () => KvStore(db).get(KvKeys.locale)),
          AuraLocales.hiLatn,
        );
        await tester.pumpWidget(const SizedBox());
        await settleIo(tester);
      },
    );
  });
}
