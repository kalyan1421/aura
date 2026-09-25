// REQ-INS-03 (PRD F10 `[LEGAL]`): a template linter that fails the build on
// banned words in Insights copy. Patterns are descriptive only ("more
// often", never "because"); no numbers, percentages, scores, labels or
// diagnoses; and every quadrant uses the same template. Reads the generated
// ARB files, so it checks exactly what ships, in all five locales (Hindi and
// Hinglish from Milestone B).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A pattern sentence template (`insights_pattern…`, not the section's own
/// `insights_patterns…` strings, whose "4/7" counter is not a pattern).
bool _isPatternTemplate(String key) =>
    key.startsWith('insights_pattern') && !key.startsWith('insights_patterns');

/// Templates that describe a pattern or the weekly card (words only).
bool _isPatternCopy(String key) =>
    _isPatternTemplate(key) || key.startsWith('insights_weekly');

/// Every Insights string (care card and recap included).
bool _isInsightsCopy(String key) => key.startsWith('insights_');

/// Causal, clinical, scoring or labelling words (lower case, whole words or
/// stems). English and the Latin-script drafts share the list.
const List<String> _banned = [
  'because',
  'cause',
  'caused',
  'causes',
  'due to',
  'leads to',
  'makes you',
  'disorder',
  'depressed',
  'depression',
  'anxiety',
  'diagnos',
  'symptom',
  'bipolar',
  'ocd',
  'adhd',
  'ptsd',
  'mental illness',
  'score',
  'rating',
  'percent',
  'worse',
  'better',
  'bad mood',
  'good mood',
  'negative',
  'positive',
  'anduke', // Tenglish "because of that"
  'kaaranam', // Tenglish "reason / because"
  'kyunki', // Hinglish "because"
  'kyonki',
  'wajah', // Hinglish "reason / because of"
  'vajah',
  'kaaran', // Hinglish "reason"
  'isliye', // Hinglish "that's why"
  'behtar', // Hinglish "better"
  'badtar', // Hinglish "worse"
];

/// Telugu- and Devanagari-script words matched anywhere (no reliable word
/// boundaries around combining marks): "because", "reason", "that's why",
/// "better / worse", clinical labels.
const List<String> _bannedScript = [
  'ఎందుకంటే',
  'కారణం',
  'వల్ల',
  'क्योंकि',
  'वजह',
  'कारण',
  'इसलिए',
  'बेहतर',
  'बदतर',
  'स्कोर',
  'रेटिंग',
  'प्रतिशत',
  'डिप्रेशन',
  'बीमारी',
  'लक्षण',
];

/// Quadrant names as each script writes them (a template names the quadrant
/// only through `{quadrant}`).
const List<String> _quadrantNames = [
  'Storm',
  'Rain',
  'Moonlight',
  'Sunrise',
  'తుఫాను',
  'వాన',
  'వెన్నెల',
  'సూర్యోదయ',
  'तूफ़ान',
  'तूफान',
  'बारिश',
  'चाँदनी',
  'चांदनी',
  'सूर्योदय',
];

/// Look back strings (F10, REQ-INS-08). Besides the Insights rules above:
/// words only (no digits: "A month ago", never "1 month ago"), and none of
/// the nostalgia or pressure words a pushed "on this day" feature leans on.
bool _isLookBackCopy(String key) => key.startsWith('insights_lookBack');

const List<String> _lookBackBanned = [
  'memories',
  'memory',
  'on this day',
  'ago today',
  'remember when',
  'nostalgia',
  "don't miss",
  'miss',
  'missed',
  'streak',
  'yaadein', // Hinglish "memories"
  'yaad', // Hinglish "memory / remember"
  'gnaapakaalu', // Tenglish "memories"
  'jnaapakaalu',
];

const List<String> _lookBackBannedScript = [
  'జ్ఞాపకాలు', // Telugu "memories"
  'జ్ఞాపకం',
  'యాదులు',
  'यादें', // Hindi "memories"
  'याद',
];

/// Keys every locale must carry for Look back (it ships in all five).
const List<String> _lookBackKeys = [
  'insights_lookBackTitle',
  'insights_lookBackTileBody',
  'insights_lookBackIntro',
  'insights_lookBackMonth',
  'insights_lookBackSixMonths',
  'insights_lookBackYear',
  'insights_lookBackWeekOf',
  'insights_lookBackEmpty',
  'insights_lookBackClosed',
  'insights_lookBackShowNote',
  'insights_lookBackShowVoice',
  'insights_lookBackHideNote',
  'insights_lookBackSettingsHint',
  'insights_lookBackSetting',
  'insights_lookBackSettingNote',
];

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

/// The template with ICU placeholders removed (`{quadrant}` → ``).
String _text(String template) => template.replaceAll(RegExp(r'\{[^{}]*\}'), '');

void main() {
  for (final locale in ['en', 'te', 'te_Latn', 'hi', 'hi_Latn']) {
    group('Insights copy ($locale)', () {
      final arb = _arb(locale);
      final keys = arb.keys.where((k) => !k.startsWith('@')).toList();

      test('pattern templates exist', () {
        expect(keys.where(_isPatternCopy), isNotEmpty);
      });

      if (locale != 'en') {
        test('every pattern template is translated (the linter would pass '
            'English trivially)', () {
          final en = _arb('en');
          for (final key in en.keys.where(_isPatternCopy)) {
            expect(arb[key], isA<String>(), reason: key);
            expect(arb[key], isNot(en[key]), reason: key);
          }
        });
      }

      for (final key in keys.where(_isInsightsCopy)) {
        final value = arb[key] as String;
        test('$key has no banned word', () {
          final lower = _text(value).toLowerCase();
          for (final word in _banned) {
            expect(
              RegExp('\\b${RegExp.escape(word)}').hasMatch(lower),
              isFalse,
              reason: '"$word" in $key: $value',
            );
          }
          for (final word in _bannedScript) {
            expect(value.contains(word), isFalse, reason: '"$word" in $key');
          }
        });
      }

      for (final key in keys.where(_isPatternCopy)) {
        final value = arb[key] as String;
        test('$key: words only (no number, percentage or score)', () {
          expect(RegExp(r'[0-9%٪०-९౦-౯]').hasMatch(_text(value)), isFalse);
          expect(value, isNot(contains('{count')));
        });
      }

      test('Look back: every string is present', () {
        for (final key in _lookBackKeys) {
          expect(arb[key], isA<String>(), reason: key);
        }
        expect(keys.where(_isLookBackCopy).toSet(), _lookBackKeys.toSet());
      });

      if (locale == 'te' || locale == 'hi') {
        test('Look back: translated into the native script', () {
          final en = _arb('en');
          for (final key in _lookBackKeys) {
            expect(arb[key], isNot(en[key]), reason: key);
          }
        });
      }

      for (final key in keys.where(_isLookBackCopy)) {
        final value = arb[key] as String;
        test('$key: words only, no nostalgia or pressure words', () {
          expect(
            RegExp(r'[0-9%٪०-९౦-౯]').hasMatch(_text(value)),
            isFalse,
            reason: value,
          );
          final lower = _text(value).toLowerCase();
          for (final word in _lookBackBanned) {
            expect(
              RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(lower),
              isFalse,
              reason: '"$word" in $key: $value',
            );
          }
          for (final word in _lookBackBannedScript) {
            expect(value.contains(word), isFalse, reason: '"$word" in $key');
          }
        });
      }

      test('each pattern template names the quadrant by placeholder (one '
          'template for every quadrant)', () {
        for (final key in keys.where(_isPatternTemplate)) {
          expect(arb[key], contains('{quadrant}'), reason: key);
          for (final name in _quadrantNames) {
            expect(
              _text(arb[key] as String),
              isNot(contains(name)),
              reason: key,
            );
          }
        }
      });
    });
  }
}
