// Store listing lint (Milestone C "ASO + listings in 5 languages"). Checks
// every file under apps/mobile/store against store/listing_rules.json:
// character limits (App Store Connect, Play Console), keyword bytes, banned
// health / treatment / chat words in Latin, Telugu and Devanagari script
// (PRD 06d "calm, not treatment", F9 App Review positioning), the
// "not a medical device" line in every description, cross-store mentions,
// placeholders, mirrored English locales and the native-review status.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _root = 'store';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Store text as uploaded: fastlane strips the trailing newline.
String _text(File f) => f.readAsStringSync().replaceAll(RegExp(r'\n+$'), '');

/// Characters as the consoles count them (UTF-16 code units).
int _chars(String s) => s.length;

List<Directory> _localeDirs(String store) {
  final dir = Directory('$_root/$store');
  if (!dir.existsSync()) return [];
  return dir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _name(FileSystemEntity e) =>
    e.uri.pathSegments.where((s) => s.isNotEmpty).last.replaceAll('.txt', '');

/// `te`, `te-IN` → te; `hi`, `hi-IN` → hi; `te-Latn` stays; else en.
String _lang(String locale) {
  if (locale.endsWith('-Latn')) return locale;
  if (locale.startsWith('te')) return 'te';
  if (locale.startsWith('hi')) return 'hi';
  return 'en';
}

RegExp _word(String w) => RegExp(
  '(?<![\\p{L}\\p{N}])${RegExp.escape(w)}(?![\\p{L}\\p{N}])',
  caseSensitive: false,
  unicode: true,
);

void main() {
  final rules = _json('$_root/listing_rules.json');
  final status = _json('$_root/status.json');
  final limits = rules['limits'] as Map<String, dynamic>;
  final required = rules['required_files'] as Map<String, dynamic>;
  final disclaimers = rules['disclaimer'] as Map<String, dynamic>;
  final bannedLatin = [
    for (final w in (rules['banned_latin']['words'] as List)) _word('$w'),
  ];
  final bannedScript = [
    for (final list
        in (rules['banned_script'] as Map<String, dynamic>).entries
            .where((e) => !e.key.startsWith('_'))
            .map((e) => e.value as List))
      ...list.cast<String>(),
  ];
  final bannedTitle = [
    for (final w in (rules['banned_title_words']['words'] as List)) _word('$w'),
  ];
  final crossStore = rules['cross_store'] as Map<String, dynamic>;
  final placeholders = (rules['placeholders'] as List).cast<String>();

  const stores = ['ios', 'android', 'extras'];

  test('every store has locales, and every locale has a review status', () {
    expect(_localeDirs('ios'), hasLength(greaterThanOrEqualTo(3)));
    expect(_localeDirs('android'), hasLength(greaterThanOrEqualTo(3)));
    for (final store in stores) {
      for (final d in _localeDirs(store)) {
        final key = '$store/${_name(d)}';
        expect(
          status[key],
          isIn(['draft-native-review', 'ready-for-ak-review', 'approved']),
          reason: '$key needs an entry in store/status.json',
        );
      }
    }
  });

  test('5 languages are covered (Tenglish / Hinglish as extras)', () {
    final langs = {
      for (final store in stores)
        for (final d in _localeDirs(store)) _lang(_name(d)),
    };
    expect(langs, containsAll(['en', 'te', 'te-Latn', 'hi', 'hi-Latn']));
  });

  for (final store in stores) {
    for (final dir in _localeDirs(store)) {
      final locale = _name(dir);
      final lang = _lang(locale);
      final files = {
        for (final f in dir.listSync().whereType<File>())
          if (f.path.endsWith('.txt')) _name(f): _text(f),
      };

      group('$store/$locale', () {
        test('has every required file, none empty', () {
          for (final r in (required[store] as List).cast<String>()) {
            expect(files[r], isNotNull, reason: '$r.txt missing');
            expect(files[r]!.trim(), isNotEmpty, reason: '$r.txt empty');
          }
        });

        test('within store limits', () {
          final storeLimits = (limits[store] as Map<String, dynamic>);
          for (final MapEntry(:key, :value) in files.entries) {
            if (key == 'keywords') {
              final bytes = utf8.encode(value).length;
              final max = limits['${store}_keyword_bytes'] as int;
              expect(bytes, lessThanOrEqualTo(max), reason: 'keywords bytes');
              final terms = value.split(',');
              expect(
                terms.every((t) => t == t.trim() && t.isNotEmpty),
                isTrue,
                reason: 'keywords: no spaces around commas, no empty terms',
              );
              expect(
                terms.map((t) => t.toLowerCase()).toSet().length,
                terms.length,
                reason: 'keywords: duplicate term',
              );
              continue;
            }
            if (key == 'screenshot_captions') {
              final max = storeLimits['screenshot_captions_line'] as int;
              for (final line in value.split('\n')) {
                expect(_chars(line), lessThanOrEqualTo(max), reason: line);
              }
              continue;
            }
            final max = storeLimits[key];
            if (max is int) {
              expect(
                _chars(value),
                lessThanOrEqualTo(max),
                reason: '$key is ${_chars(value)} characters (max $max)',
              );
            }
          }
        });

        test('no health, treatment, chat or out-of-scope words', () {
          final disclaimer = disclaimers[lang] as String;
          for (final MapEntry(:key, :value) in files.entries) {
            // The disclaimer is the one place "medical" may appear.
            final text = value.replaceAll(disclaimer, '');
            for (final re in bannedLatin) {
              expect(
                re.hasMatch(text),
                isFalse,
                reason: '$key: "${re.firstMatch(text)?.group(0)}"',
              );
            }
            for (final w in bannedScript) {
              expect(text.contains(w), isFalse, reason: '$key: "$w"');
            }
            for (final p in placeholders) {
              expect(
                value.toLowerCase().contains(p.toLowerCase()),
                isFalse,
                reason: '$key: placeholder "$p"',
              );
            }
          }
        });

        test('name / title carry no ranking, price or promo words', () {
          for (final key in ['name', 'title']) {
            final v = files[key];
            if (v == null) continue;
            for (final re in bannedTitle) {
              expect(re.hasMatch(v), isFalse, reason: '$key: $re');
            }
            expect(v, startsWith('Aura'), reason: 'brand stays in Latin');
          }
        });

        test('descriptions carry the "not a medical device" line', () {
          final disclaimer = disclaimers[lang] as String;
          for (final key in ['description', 'full_description', 'disclaimer']) {
            final v = files[key];
            if (v == null) continue;
            expect(v, contains(disclaimer), reason: key);
          }
        });

        if (crossStore[store] != null) {
          test('never names the other store', () {
            for (final MapEntry(:key, :value) in files.entries) {
              for (final w in (crossStore[store] as List).cast<String>()) {
                expect(_word(w).hasMatch(value), isFalse, reason: '$key: $w');
              }
            }
          });
        }

        test('no emoji (Play title policy; calm tone everywhere)', () {
          final emoji = RegExp(
            r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}]',
            unicode: true,
          );
          for (final MapEntry(:key, :value) in files.entries) {
            expect(emoji.hasMatch(value), isFalse, reason: key);
          }
        });
      });
    }
  }

  test('mirrored English locales stay identical', () {
    final mirrors = (rules['mirrors'] as Map<String, dynamic>)
      ..remove('_about');
    for (final MapEntry(:key, :value) in mirrors.entries) {
      final a = Directory('$_root/$key');
      final b = Directory('$_root/$value');
      final names = {for (final f in b.listSync().whereType<File>()) _name(f)};
      expect(
        {for (final f in a.listSync().whereType<File>()) _name(f)},
        names,
        reason: '$key vs $value',
      );
      for (final n in names) {
        expect(
          File('${a.path}/$n.txt').readAsStringSync(),
          File('${b.path}/$n.txt').readAsStringSync(),
          reason: '$key/$n.txt must match $value/$n.txt',
        );
      }
    }
  });

  test('the lint catches what it should (self-check)', () {
    bool latin(String s) => bannedLatin.any((re) => re.hasMatch(s));
    expect(latin('Aura helps with anxiety'), isTrue);
    expect(latin('Better SLEEP tonight'), isTrue);
    expect(latin('Chat with strangers'), isTrue);
    expect(latin('a therapy-free zone'), isTrue);
    expect(latin('Aura is a daily mood check-in'), isFalse);
    expect(latin('Share a card'), isFalse); // "ai" never inside a word
    expect(bannedScript.any('ఇది చికిత్స కాదు'.contains), isTrue);
    expect(bannedScript.any('नींद के लिए'.contains), isTrue);
    expect(_word('ios').hasMatch('curiosity'), isFalse);
  });
}
