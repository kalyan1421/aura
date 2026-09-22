import 'dart:convert';
import 'dart:io';

import 'package:aura_domain/aura_domain.dart';
import 'package:test/test.dart';

void main() {
  final json = jsonDecode(
    File('../../contracts/moods.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('generated catalogue matches contracts/moods.json (run '
      'tool/gen_catalog.dart if this fails)', () {
    final moods = (json['moods'] as List<dynamic>).cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));
    expect(moodCatalog.length, moods.length);
    for (var i = 0; i < moods.length; i++) {
      final m = moods[i];
      final g = moodCatalog[i];
      expect(g.id, m['id']);
      expect(g.quadrant.name, m['quadrant']);
      expect(g.sort, m['sort']);
      expect(
        g.names,
        (m['names'] as Map<String, dynamic>).cast<String, String>(),
      );
    }

    final quadrants = json['quadrants'] as Map<String, dynamic>;
    for (final q in Quadrant.values) {
      final j = quadrants[q.name] as Map<String, dynamic>;
      expect(q.energy.name, j['energy']);
      expect(q.pleasant, j['pleasant']);
      expect(q.theme, j['theme']);
      expect(q.hueDeg, (j['hueDeg'] as num).toDouble());
    }

    expect(
      presetHabits.map((h) => h.key).toList(),
      (json['presetHabits'] as List<dynamic>)
          .map((h) => (h as Map<String, dynamic>)['key'])
          .toList(),
    );
    expect(contextTags, (json['contextTags'] as List<dynamic>).cast<String>());
  });

  test('grid is 4 quadrants x 4 moods', () {
    for (final q in Quadrant.values) {
      expect(moodsIn(q), hasLength(4));
    }
  });

  test('names fall back to English, never a raw key', () {
    final calm = moodById('calm')!;
    expect(calm.nameFor('te-Latn'), 'Prashaanthanga');
    expect(calm.nameFor('ta'), 'Calm');
    expect(moodById('nope'), isNull);
  });

  test('language pools', () {
    expect(AuraLocales.languagePool('te-Latn'), 'te');
    expect(AuraLocales.languagePool('hi-Latn'), 'hi');
    expect(AuraLocales.languagePool('en'), 'en');
  });
}
