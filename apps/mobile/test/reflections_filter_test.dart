import 'dart:convert';
import 'dart:io';

import 'package:aura/src/features/reflections/reflection_filter.dart';
import 'package:aura/src/features/reflections/reflection_filter_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// The on-device reflection text rules (F6 "Not allowed", REQ-REF-02,
/// REQ-SAFE-07) are the contract's (contracts/safety): the embedded data
/// deep-equals reflection_filter.v1.json, and the Dart twin gives the verdict
/// of every shared vector the NestJS filter also passes.
void main() {
  const dir = '../../contracts/safety';
  final source = jsonDecode(
    File('$dir/reflection_filter.v1.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final vectors = jsonDecode(
    File('$dir/reflection_filter.vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  List<Map<String, dynamic>> entries(List<ReflectionPhraseEntry> list) => [
    for (final e in list)
      {
        'id': e.id,
        'language': e.language,
        'phrase': e.phrase,
        'variants': e.variants,
      },
  ];

  test('reflection_filter_data.dart deep-equals reflection_filter.v1.json', () {
    expect(reflectionFilterVersion, source['version']);
    expect(reflectionFilterMaxChars, source['maxChars']);
    expect({
      'standard': reflectionPhoneDigitsStandard,
      'strict': reflectionPhoneDigitsStrict,
    }, source['phoneDigits']);
    expect(reflectionTlds, source['tlds']);
    expect(reflectionContactApps, source['contactApps']);
    expect(reflectionMultipliers, source['multipliers']);
    expect(reflectionNumberWords, source['numberWords']);
    expect(entries(reflectionContactPhrases), source['contactPhrases']);
    expect(entries(reflectionGroomingPhrases), source['groomingPhrases']);
    // Nothing in the JSON that the Dart copy doesn't carry (besides the
    // review notes and the name).
    expect(source.keys.toSet(), {
      'name',
      'version',
      'review',
      'maxChars',
      'phoneDigits',
      'tlds',
      'contactApps',
      'multipliers',
      'numberWords',
      'contactPhrases',
      'groomingPhrases',
    });
  });

  test('the vectors are for this filter version', () {
    expect(vectors['filterVersion'], reflectionFilterVersion);
  });

  group('vectors', () {
    final cases = (vectors['cases'] as List).cast<Map<String, dynamic>>();
    for (final (i, c) in cases.indexed) {
      final text = c['text'] as String;
      final strict = c['strict'] == true;
      test('#$i ${strict ? '(strict) ' : ''}${c['note'] ?? ''}', () {
        final r = checkReflectionText(text, strict: strict);
        final why =
            'case $i: ${text.runes.map((r) => r.toRadixString(16)).join(' ')}'
            ' hits=${r.hits}';
        expect(r.contact.wire, c['contact'], reason: why);
        expect(r.grooming, c['grooming'], reason: why);
      });
    }
  });

  test('blocksSend: contact details and links only (grooming is the '
      "server's call)", () {
    expect(checkReflectionText('98765 43210').blocksSend, isTrue);
    expect(checkReflectionText('check www.example.com').blocksSend, isTrue);
    expect(checkReflectionText('How old are you?').blocksSend, isFalse);
    expect(checkReflectionText('first Diwali alone').blocksSend, isFalse);
  });

  test('hits are rule ids, never the words', () {
    final r = checkReflectionText('my insta id is quietcomet');
    expect(r.hits, ['en.insta_id']);
    expect(r.hits.join(), isNot(contains('quietcomet')));
  });
}
