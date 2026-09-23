// Runs every JSON vector in contracts/rules/vectors against the Dart rules.
// The same files run in server/aura-api (TypeScript), so the two engines
// cannot drift. A new vector file without a runner here fails the suite.
import 'dart:convert';
import 'dart:io';

import 'package:aura_domain/aura_domain.dart';
import 'package:test/test.dart';

final Directory vectorsDir = Directory('../../contracts/rules/vectors');

Map<String, dynamic> _load(File f) =>
    jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _cases(Map<String, dynamic> json) =>
    (json['cases'] as List<dynamic>).cast<Map<String, dynamic>>();

DateTime _ts(Object? s) => DateTime.parse(s! as String);

LocalDay? _day(Object? s) => s == null ? null : LocalDay.parse(s as String);

StreakState _streak(Map<String, dynamic> j) => StreakState(
  glowStreak: j['glowStreak'] as int,
  lifetimeGlowDays: j['lifetimeGlowDays'] as int,
  restBank: j['restBank'] as int,
  earnCounter: j['earnCounter'] as int,
  lastActiveDay: _day(j['lastActiveDay']),
);

final Map<String, void Function(Map<String, dynamic>)> runners = {
  'aura_day.json': (json) {
    for (final c in _cases(json)) {
      test(c['name'], () {
        expect(auraDay(_ts(c['utc']), c['tz'] as String).toIso(), c['expect']);
      });
    }
  },
  'eligibility.json': (json) {
    for (final c in _cases(json)) {
      test(c['name'], () {
        expect(
          isEligible(
            deviceTs: _ts(c['deviceTs']),
            serverNow: _ts(c['serverNow']),
            timezone: c['tz'] as String,
            localDay: LocalDay.parse(c['localDay'] as String),
          ),
          c['expect'],
        );
      });
    }
  },
  'starlight.json': (json) {
    for (final c in _cases(json)) {
      test(c['name'], () {
        final events = (c['events'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(
              (e) => e['type'] == 'checkin'
                  ? StarlightEvent.checkIn(
                      eligible: e['eligible'] as bool? ?? true,
                    )
                  : StarlightEvent.habit(
                      e['habitId'] as String,
                      eligible: e['eligible'] as bool? ?? true,
                    ),
            )
            .toList();
        final awards = starlightAwards(events);
        expect(awards, (c['expectAwards'] as List<dynamic>).cast<int>());
        expect(awards.fold<int>(0, (a, b) => a + b), c['expectTotal']);
      });
    }
  },
  'stage.json': (json) {
    for (final c in _cases(json)) {
      final total = c['total'] as int;
      test('total $total', () {
        expect(stageFor(total).name, c['expectStage']);
        expect(constellationStarsFor(total), c['expectStars']);
      });
    }
  },
  'traits.json': (json) {
    for (final c in _cases(json)) {
      final n = c['completions'] as int;
      test('$n completions', () {
        expect(traitLevel(n), c['expectLevel']);
      });
    }
  },
  'hue.json': (json) {
    final tolerance = (json['toleranceDeg'] as num).toDouble();
    for (final c in _cases(json)) {
      final counts = (c['counts'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(quadrantByName(k)!, v as int),
      );
      test('counts $counts', () {
        final hue = hueFor(counts);
        final expected = c['expect'] as num?;
        if (expected == null) {
          expect(hue, isNull);
        } else {
          expect(hue, isNotNull);
          // Circular distance, so 359.9 vs 0.1 counts as close.
          final d = ((hue! - expected) % 360 + 360) % 360;
          expect(
            d < tolerance || 360 - d < tolerance,
            isTrue,
            reason: 'hue $hue vs $expected',
          );
        }
      });
    }
  },
  'streak.json': (json) {
    for (final c in _cases(json)) {
      test(c['name'], () {
        final result = foldStreak(
          _streak(c['initial'] as Map<String, dynamic>),
          (c['days'] as List<dynamic>).map((d) => LocalDay.parse(d as String)),
        );
        expect(result, _streak(c['expect'] as Map<String, dynamic>));
      });
    }
  },
  'nebula.json': (json) {
    for (final c in _cases(json)) {
      test(c['name'], () {
        expect(
          isResting(
            _day(c['lastActiveDay']),
            LocalDay.parse(c['currentAuraDay'] as String),
          ),
          c['expect'],
        );
      });
    }
  },
  'capsules.json': (json) {
    for (final c in _cases(json)) {
      final kind = c['kind'] as String;
      test('$kind: ${c['name']}', () {
        switch (kind) {
          case 'window':
            expect(
              isValidUnlockDate(
                _ts(c['sealedAt']),
                c['tz'] as String,
                c['unlockLocalDate'] as String,
              ),
              c['expect'],
            );
          case 'unlock_at':
            final at = capsuleUnlockAt(
              LocalDay.parse(c['localDate'] as String),
              c['tz'] as String,
            );
            expect(at.isUtc, isTrue);
            expect(at, _ts(c['expect']));
          case 'trigger':
            final pick = pickTrigger(
              (c['capsules'] as List<dynamic>).cast<Map<String, dynamic>>().map(
                _triggerCapsule,
              ),
              _triggerCheckIn(c['checkIn'] as Map<String, dynamic>),
            );
            final want = c['expect'] as Map<String, dynamic>;
            expect(
              pick,
              TriggerPick(
                fire: want['fire'] as String?,
                hold: want['hold'] as String?,
              ),
            );
          default:
            fail('Unknown capsules.json case kind "$kind"');
        }
      });
    }
  },
};

DateTime? _tsOrNull(Object? s) => s == null ? null : _ts(s);

TriggerCapsule _triggerCapsule(Map<String, dynamic> j) => TriggerCapsule(
  id: j['id'] as String,
  unlockType: CapsuleUnlockType.byName(j['unlockType'] as String)!,
  triggerMoodId: j['triggerMoodId'] as String?,
  triggerQuadrant: j['triggerQuadrant'] == null
      ? null
      : quadrantByName(j['triggerQuadrant'] as String),
  sealedAt: _ts(j['sealedAt']),
  armedAt: _tsOrNull(j['armedAt']),
  firedAt: _tsOrNull(j['firedAt']),
  openedAt: _tsOrNull(j['openedAt']),
  deletedAt: _tsOrNull(j['deletedAt']),
  cooldownUntil: _tsOrNull(j['cooldownUntil']),
);

TriggerCheckIn _triggerCheckIn(Map<String, dynamic> j) => TriggerCheckIn(
  moodId: j['moodId'] as String,
  quadrant: quadrantByName(j['quadrant'] as String)!,
  deviceTs: _ts(j['deviceTs']),
  live: j['live'] as bool,
  crisis: j['crisis'] as bool,
);

void main() {
  final files =
      vectorsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('vector directory is present and non-empty', () {
    expect(files, isNotEmpty);
  });

  for (final f in files) {
    final name = f.uri.pathSegments.last;
    group(name, () {
      final runner = runners[name];
      if (runner == null) {
        test('has a Dart runner', () {
          fail('No runner for $name — add one to test/vectors_test.dart');
        });
        return;
      }
      runner(_load(f));
    });
  }
}
