/// The reflection text rules (contracts/safety/reflection_filter.v1.json +
/// README "Reflection filter"; PRD F6 "Not allowed", F9 reflection pipeline
/// steps 1–2). A line-by-line twin of the server's TypeScript
/// (server/aura-api/src/reflections/filter/reflection-filter.ts): both must
/// give the verdict of every case in
/// contracts/safety/reflection_filter.vectors.json.
///
/// - `contact`: links, emails / UPI ids, @handles, "app: handle", phone
///   numbers (spaced, dashed, +91, Telugu / Devanagari / fullwidth digits,
///   spelled out in English, Telugu, Tenglish, Hindi or Hinglish words) and
///   contact-swap phrases. The app blocks these before anything leaves the
///   phone; the server repeats the check.
/// - `grooming`: asking someone's age, school, city or photos, secrecy,
///   meeting up, moving to another app. Server-only routing to the Minors &
///   grooming lane: the app never blocks on it.
///
/// `strict` (an under-18 involved, or the Telugu / Hindi pools): the
/// phone-digit threshold drops from 7 to 6. The app always checks with
/// `strict: false` (it can't know who is in the room). Text is never
/// logged; `hits` holds rule ids only.
library;

import 'package:flutter/foundation.dart';

import '../support/crisis_lexicon.dart' show normalizeForLexicon;
import 'reflection_filter_data.dart';

enum ReflectionContact {
  none,
  contactDetails,
  link;

  /// The contract's value (`none` · `contact_details` · `link`).
  String get wire => switch (this) {
    none => 'none',
    contactDetails => 'contact_details',
    link => 'link',
  };
}

@immutable
class ReflectionFilterResult {
  const ReflectionFilterResult({
    required this.contact,
    required this.grooming,
    required this.hits,
  });

  final ReflectionContact contact;
  final bool grooming;

  /// Rule ids that matched (`link`, `email_or_upi`, `handle`, `app_handle`,
  /// `phone_digits`, `spelled_number`, phrase ids). Never the words.
  final List<String> hits;

  /// Nothing may leave the phone (contact details or a link).
  bool get blocksSend => contact != ReflectionContact.none;
}

/// Latin forms as word lists (also indexed joined into one word), and
/// other-script forms matched as substrings.
typedef _CompiledPhrases = ({
  List<({String id, List<String> words})> latin,
  List<({String id, String text})> script,
});

final RegExp _ascii = RegExp(r'^[\x00-\x7f]*$');
final RegExp _latinWord = RegExp('[a-z0-9]+');
final RegExp _token = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);
final RegExp _allDigits = RegExp(r'^[0-9]+$');
final RegExp _nonDigit = RegExp('[^0-9]');

final String _tlds = reflectionTlds.join('|');
final String _apps = reflectionContactApps.join('|');

final List<RegExp> _linkRules = [
  RegExp(r'(https?://|www\.)'),
  RegExp('(^|[^a-z0-9@._%+-])[a-z0-9-]+\\.($_tlds)\\b'),
  RegExp(r'\b[a-z0-9-]+\s*dot\s*(com|net|org)\b'),
];
final RegExp _emailOrUpi = RegExp(r'[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*');
final RegExp _handle = RegExp(r'(^|[^a-z0-9._%+-])@[a-z0-9_.]+');
final RegExp _appHandle = RegExp(
  '(^|[^a-z0-9])($_apps)\\s*[:=\\-]\\s*@?[a-z0-9_.]+',
);
final RegExp _date = RegExp(
  r'(?<![0-9])[0-9]{1,2}[/.-][0-9]{1,2}[/.-]([0-9]{4}|[0-9]{2})(?![0-9])',
);
final RegExp _digitRun = RegExp(r'[0-9][0-9\s().\-/]*[0-9]|[0-9]');

/// Telugu (౦–౯), Devanagari (०–९) and fullwidth (０–９) digits read as 0–9;
/// fullwidth ＠ as @.
String _asciiDigits(String s) {
  final out = StringBuffer();
  for (final cp in s.runes) {
    if (cp >= 0x0c66 && cp <= 0x0c6f) {
      out.writeCharCode(0x30 + cp - 0x0c66);
    } else if (cp >= 0x0966 && cp <= 0x096f) {
      out.writeCharCode(0x30 + cp - 0x0966);
    } else if (cp >= 0xff10 && cp <= 0xff19) {
      out.writeCharCode(0x30 + cp - 0xff10);
    } else if (cp == 0xff20) {
      out.write('@');
    } else {
      out.writeCharCode(cp);
    }
  }
  return out.toString();
}

/// The text as the rules see it: the crisis lexicon's normalization, then
/// ASCII digits.
String normalizeForFilter(String text) =>
    _asciiDigits(normalizeForLexicon(text));

_CompiledPhrases _compile(List<ReflectionPhraseEntry> entries) {
  final latin = <({String id, List<String> words})>[];
  final script = <({String id, String text})>[];
  for (final e in entries) {
    for (final form in [e.phrase, ...e.variants]) {
      final n = normalizeForFilter(form).replaceAll('\n', ' ');
      if (n.isEmpty) continue;
      if (!_ascii.hasMatch(n)) {
        script.add((id: e.id, text: n));
        continue;
      }
      final words = [for (final m in _latinWord.allMatches(n)) m[0]!];
      if (words.isEmpty) continue;
      latin.add((id: e.id, words: words));
      if (words.length > 1) latin.add((id: e.id, words: [words.join()]));
    }
  }
  return (latin: latin, script: script);
}

final _CompiledPhrases _contactPhrases = _compile(reflectionContactPhrases);
final _CompiledPhrases _groomingPhrases = _compile(reflectionGroomingPhrases);
final Set<String> _numberWords = {
  for (final words in reflectionNumberWords.values)
    for (final w in words) normalizeForFilter(w),
};
final Map<String, int> _multipliers = {
  for (final e in reflectionMultipliers.entries)
    normalizeForFilter(e.key): e.value,
};

List<String> _phraseHits(String normalized, _CompiledPhrases phrases) {
  final hits = <String>{};
  final words = [for (final m in _latinWord.allMatches(normalized)) m[0]!];
  for (final p in phrases.latin) {
    final n = p.words.length;
    for (var i = 0; i + n <= words.length; i++) {
      var ok = true;
      for (var k = 0; k < n && ok; k++) {
        ok = words[i + k] == p.words[k];
      }
      if (ok) {
        hits.add(p.id);
        break;
      }
    }
  }
  final flat = normalized.replaceAll('\n', ' ');
  for (final p in phrases.script) {
    if (flat.contains(p.text)) hits.add(p.id);
  }
  return [...hits];
}

/// A run of digits with the separators people use (dates removed first)
/// holding at least [threshold] digits.
bool _hasPhoneDigits(String normalized, int threshold) {
  final t = normalized.replaceAll(_date, ' ');
  for (final m in _digitRun.allMatches(t)) {
    if (m[0]!.replaceAll(_nonDigit, '').length >= threshold) return true;
  }
  return false;
}

/// A run of consecutive tokens that are number words (any of the five
/// languages), digit groups or multipliers ("double nine" = 2 digits) that
/// spells at least [threshold] digits and contains at least one word.
bool _hasSpelledNumber(String normalized, int threshold) {
  var run = 0;
  var hasWord = false;
  var mult = 1;
  for (final m in _token.allMatches(normalized)) {
    final tok = m[0]!;
    if (_allDigits.hasMatch(tok)) {
      run += mult > 1 && tok.length == 1 ? mult : tok.length;
      mult = 1;
    } else if (_numberWords.contains(tok)) {
      run += mult;
      mult = 1;
      hasWord = true;
    } else if (_multipliers.containsKey(tok)) {
      mult = _multipliers[tok]!;
      hasWord = true;
      continue;
    } else {
      run = 0;
      hasWord = false;
      mult = 1;
      continue;
    }
    if (hasWord && run >= threshold) return true;
  }
  return false;
}

/// The contract's `check(text, strict)`.
ReflectionFilterResult checkReflectionText(String text, {bool strict = false}) {
  final n = normalizeForFilter(text);
  final threshold = strict
      ? reflectionPhoneDigitsStrict
      : reflectionPhoneDigitsStandard;
  final hits = <String>[];
  var link = false;
  var contact = false;
  if (_linkRules.any((r) => r.hasMatch(n))) {
    link = true;
    hits.add('link');
  }
  if (_emailOrUpi.hasMatch(n)) {
    contact = true;
    hits.add('email_or_upi');
  }
  if (_handle.hasMatch(n)) {
    contact = true;
    hits.add('handle');
  }
  if (_appHandle.hasMatch(n)) {
    contact = true;
    hits.add('app_handle');
  }
  if (_hasPhoneDigits(n, threshold)) {
    contact = true;
    hits.add('phone_digits');
  }
  if (_hasSpelledNumber(n, threshold)) {
    contact = true;
    hits.add('spelled_number');
  }
  final contactPhrases = _phraseHits(n, _contactPhrases);
  if (contactPhrases.isNotEmpty) {
    contact = true;
    hits.addAll(contactPhrases);
  }
  final groomingPhrases = _phraseHits(n, _groomingPhrases);
  hits.addAll(groomingPhrases);
  return ReflectionFilterResult(
    contact: link
        ? ReflectionContact.link
        : contact
        ? ReflectionContact.contactDetails
        : ReflectionContact.none,
    grooming: groomingPhrases.isNotEmpty,
    hits: hits,
  );
}

/// Characters (grapheme clusters) a reflection may hold.
const int reflectionMaxChars = reflectionFilterMaxChars;
