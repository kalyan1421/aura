// REQ-INS-03 (PRD F10 `[LEGAL]`): a template linter that fails the build on
// banned words in Insights copy. Patterns are descriptive only ("more
// often", never "because"); no numbers, percentages, scores, labels or
// diagnoses; and every quadrant uses the same template. Reads the generated
// ARB files, so it checks exactly what ships, in every alpha locale.
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
];

/// Telugu-script causal words ("because", "reason").
const List<String> _bannedTelugu = ['ఎందుకంటే', 'కారణం', 'వల్ల'];

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

/// The template with ICU placeholders removed (`{quadrant}` → ``).
String _text(String template) => template.replaceAll(RegExp(r'\{[^{}]*\}'), '');

void main() {
  for (final locale in ['en', 'te', 'te_Latn']) {
    group('Insights copy ($locale)', () {
      final arb = _arb(locale);
      final keys = arb.keys.where((k) => !k.startsWith('@')).toList();

      test('pattern templates exist', () {
        expect(keys.where(_isPatternCopy), isNotEmpty);
      });

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
          for (final word in _bannedTelugu) {
            expect(value.contains(word), isFalse, reason: '"$word" in $key');
          }
        });
      }

      for (final key in keys.where(_isPatternCopy)) {
        final value = arb[key] as String;
        test('$key: words only (no number, percentage or score)', () {
          expect(RegExp(r'[0-9%٪]').hasMatch(_text(value)), isFalse);
          expect(value, isNot(contains('{count')));
        });
      }

      test('each pattern template names the quadrant by placeholder (one '
          'template for every quadrant)', () {
        for (final key in keys.where(_isPatternTemplate)) {
          expect(arb[key], contains('{quadrant}'), reason: key);
          for (final name in ['Storm', 'Rain', 'Moonlight', 'Sunrise']) {
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
