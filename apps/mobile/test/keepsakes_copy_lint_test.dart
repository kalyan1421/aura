// F13 copy lint: keepsakes are earned, private and calm; share cards never
// carry anything about how the person feels. Reads the generated ARB files,
// so it checks exactly what ships, in all five locales. Fails on pressure
// words (locked, next, progress, almost, streak…), exclamation marks,
// percentages, reward talk, and on any share / keepsake placeholder other
// than the milestone's own (stage, days, years, count, minutes), the line,
// the link and — inside the private box only — the date.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['en', 'te', 'te_Latn', 'hi', 'hi_Latn'];

bool _isF13(String key) =>
    key.startsWith('keepsakes_') ||
    key.startsWith('keepsake_') ||
    key.startsWith('share_');

/// Latin-script words (English and the romanized drafts).
final RegExp _banned = RegExp(
  r'\b(lock|locked|unlock|next|progress|almost|hurry|streak|reward|earn more|'
  r'level|score|rank|don.t lose|missed|behind|collect them all|only \d+ left|'
  r'jaldi|agla|agli|tarvaathi)\b',
  caseSensitive: false,
);

/// Telugu / Devanagari: streak, locked, next, hurry.
const List<String> _bannedScript = [
  'స్ట్రీక్',
  'లాక్',
  'తర్వాతి',
  'स्ट्रीक',
  'लॉक',
  'अगला',
  'अगली',
  'जल्दी',
];

void main() {
  final arbs = {
    for (final l in _locales)
      l: jsonDecode(
        File('lib/l10n/app_$l.arb').readAsStringSync(),
      ) as Map<String, dynamic>,
  };
  final keys = arbs['en']!.keys.where((k) => !k.startsWith('@') && _isF13(k));

  test('F13 copy exists', () => expect(keys.length, greaterThan(25)));

  for (final locale in _locales) {
    test('no pressure, reward or exclamation in $locale', () {
      for (final k in keys) {
        final v = arbs[locale]![k] as String;
        expect(v, isNot(matches(_banned)), reason: '$locale $k: $v');
        expect(v, isNot(contains('!')), reason: '$locale $k');
        expect(v, isNot(contains('%')), reason: '$locale $k');
        for (final w in _bannedScript) {
          expect(v, isNot(contains(w)), reason: '$locale $k: $w');
        }
      }
    });
  }

  test('placeholders: only the milestone, the line and the link; dates only '
      'inside the private box', () {
    const allowed = {
      'stage',
      'days',
      'years',
      'count',
      'minutes',
      'line',
      'link',
    };
    for (final k in keys) {
      final meta = arbs['en']!['@$k'] as Map<String, dynamic>?;
      final ph = ((meta?['placeholders'] as Map<String, dynamic>?) ?? {}).keys;
      for (final p in ph) {
        final ok =
            allowed.contains(p) || (p == 'date' && k.startsWith('keepsakes_'));
        expect(ok, isTrue, reason: '$k binds {$p}');
      }
      if (k.startsWith('share_')) {
        expect(ph, isNot(contains('date')), reason: k);
        expect(ph, isNot(contains('name')), reason: k);
      }
    }
  });
}
