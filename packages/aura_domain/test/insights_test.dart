// F10 Insights rules beyond the shared vectors: travel (timezone change),
// the 04:00 rollover around week and month starts, DST, and the invariants
// the copy relies on (only "more often", equal treatment of quadrants).
import 'package:aura_domain/aura_domain.dart';
import 'package:test/test.dart';

LocalDay d(String iso) => LocalDay.parse(iso);

InsightCheckIn ci(
  String day,
  Quadrant q, {
  List<String> tags = const [],
  String? ts,
  int? off,
}) => InsightCheckIn(
  localDay: d(day),
  quadrant: q,
  tags: tags,
  deviceTs: ts == null ? null : DateTime.parse(ts),
  tzOffsetMinutes: off,
);

/// A check-in stamped the way the app stamps it: day and offset from the
/// zone the phone was in at that instant.
InsightCheckIn stamped(String utc, String tz, Quadrant q) {
  final at = DateTime.parse(utc);
  return InsightCheckIn(
    localDay: auraDay(at, tz),
    quadrant: q,
    deviceTs: at,
    tzOffsetMinutes: utcOffsetAt(at, tz).inMinutes,
  );
}

void main() {
  setUpAll(ensureTimeZonesLoaded);

  group('timezone change (travel)', () {
    test('entries keep their stamped day; today follows the new zone', () {
      // Checked in on Sunday 4 Oct 22:00 IST, then flew to New York.
      final sundayIst = stamped(
        '2026-10-04T16:30:00Z',
        'Asia/Kolkata',
        Quadrant.rain,
      );
      expect(sundayIst.localDay, d('2026-10-04'));
      expect(sundayIst.part, DayPart.night);

      // Monday 5 Oct 01:00 UTC: already Monday in IST, still Sunday in NY.
      final now = DateTime.parse('2026-10-05T01:00:00Z');
      expect(
        weeklyWindow(auraDay(now, 'Asia/Kolkata')).weekStart,
        d('2026-10-05'),
      );
      expect(
        weeklyWindow(auraDay(now, 'America/New_York')).weekStart,
        d('2026-09-28'),
      );
      // The entry stays on 4 Oct whichever zone the phone is in now.
      final week = weeklyWindow(d('2026-10-05')).range;
      expect(week.contains(sundayIst.localDay), isTrue);
    });

    test(
      'a check-in made abroad keeps the part of day of where it was made',
      () {
        // 08:00 in New York = 17:30 in IST; stamped in New York → morning.
        final ny = stamped(
          '2026-10-07T12:00:00Z',
          'America/New_York',
          Quadrant.sunrise,
        );
        expect(ny.part, DayPart.morning);
        final ist = stamped(
          '2026-10-07T12:00:00Z',
          'Asia/Kolkata',
          Quadrant.sunrise,
        );
        expect(ist.part, DayPart.evening);
      },
    );

    test('pulled rows without an offset have no part, but still count', () {
      final pulled = ci('2026-10-07', Quadrant.moonlight);
      expect(pulled.isLive, isFalse);
      expect(pulled.part, isNull);
      expect(
        patternGate([
          pulled,
        ], DayRange(d('2026-10-01'), d('2026-10-30'))).checkIns,
        1,
      );
    });
  });

  group('04:00 rollover', () {
    test('Monday 03:59 local is still last week; 04:00 is the new week', () {
      const tz = 'Asia/Kolkata';
      final before = auraDay(DateTime.parse('2026-10-04T22:29:59Z'), tz);
      final after = auraDay(DateTime.parse('2026-10-04T22:30:00Z'), tz);
      expect(weeklyWindow(before).weekStart, d('2026-09-28'));
      expect(weeklyWindow(after).weekStart, d('2026-10-05'));
    });

    test('1st of the month 03:59 is still the old month', () {
      const tz = 'America/New_York';
      // 1 Dec 2026 03:59 EST (UTC−5) = 08:59Z.
      final before = auraDay(DateTime.parse('2026-12-01T08:59:00Z'), tz);
      final after = auraDay(DateTime.parse('2026-12-01T09:00:00Z'), tz);
      expect(monthWindow(before).monthKey, '2026-10');
      expect(monthWindow(after).monthKey, '2026-11');
    });

    test('a 02:00 check-in is the night of the previous Aura day', () {
      final c = stamped('2026-10-05T20:30:00Z', 'Asia/Kolkata', Quadrant.storm);
      expect(c.localDay, d('2026-10-05')); // 02:00 on 6 Oct
      expect(c.isLive, isTrue);
      expect(c.part, DayPart.night);
    });

    test('DST: the rollover stays at 04:00 local on a 25-hour day', () {
      const tz = 'America/New_York';
      // 1 Nov 2026 (DST ends 02:00): 03:30 EST = 08:30Z, 04:00 EST = 09:00Z.
      final lastOct = stamped('2026-11-01T08:30:00Z', tz, Quadrant.rain);
      final firstNov = stamped('2026-11-01T09:00:00Z', tz, Quadrant.rain);
      expect(lastOct.localDay, d('2026-10-31'));
      expect(firstNov.localDay, d('2026-11-01'));
      expect(firstNov.part, DayPart.morning);
      expect(lastOct.part, DayPart.night);
      expect(monthRecap([lastOct, firstNov], firstNov.localDay).checkIns, 1);
    });

    test('care window moves with the rollover', () {
      final seven = [
        for (var i = 0; i < 7; i++)
          ci(d('2026-10-01').addDays(i).toIso(), Quadrant.rain),
      ];
      expect(showCareCard(seven, d('2026-10-14')), isTrue);
      expect(showCareCard(seven, d('2026-10-15')), isFalse);
    });
  });

  group('patterns', () {
    List<InsightCheckIn> tagged(Quadrant lean) {
      final others = [
        Quadrant.storm,
        Quadrant.rain,
        Quadrant.moonlight,
        Quadrant.sunrise,
      ].where((q) => q != lean).toList();
      return [
        for (var i = 0; i < 4; i++)
          ci(
            d('2026-10-01').addDays(i).toIso(),
            i < 3 ? lean : others[0],
            tags: const ['study'],
          ),
        for (var i = 4; i < 14; i++)
          ci(d('2026-10-01').addDays(i).toIso(), others[i % 3]),
      ];
    }

    test('every quadrant gets the same pattern from mirrored data', () {
      final range = DayRange(d('2026-10-01'), d('2026-10-30'));
      for (final q in Quadrant.values) {
        final ps = findPatterns(checkIns: tagged(q), range: range);
        expect(
          ps.first,
          InsightPattern(PatternKind.tagQuadrant, q, 'study'),
          reason: q.name,
        );
      }
    });

    test('custom tags are patterns too; keys sort in plain string order', () {
      final range = DayRange(d('2026-10-01'), d('2026-10-30'));
      final cs = [
        for (final c in tagged(Quadrant.moonlight))
          InsightCheckIn(
            localDay: c.localDay,
            quadrant: c.quadrant,
            tags: [
              for (final t in c.tags) ...[t, 'Exam week'],
            ],
          ),
      ];
      final keys = findPatterns(checkIns: cs, range: range).map((p) => p.key);
      expect(keys, ['Exam week', 'study']);
    });

    test('never a "less often" pattern: a context that avoids a quadrant '
        'yields nothing', () {
      final range = DayRange(d('2026-10-01'), d('2026-10-30'));
      // Study never appears with Storm or Moonlight; that is never said.
      final cs = [
        for (var i = 0; i < 14; i++)
          ci(
            d('2026-10-01').addDays(i).toIso(),
            Quadrant.values[i % 4],
            tags: i.isOdd ? const ['study'] : const [],
          ),
      ];
      final tagPatterns = findPatterns(
        checkIns: cs,
        range: range,
      ).where((p) => p.kind == PatternKind.tagQuadrant);
      expect(tagPatterns, isNotEmpty);
      for (final p in tagPatterns) {
        expect(p.quadrant, isIn([Quadrant.rain, Quadrant.sunrise]));
      }
    });

    test('a year of data keeps exact integer maths', () {
      final start = d('2025-10-01');
      final cs = [
        for (var i = 0; i < 365 * 3; i++)
          ci(
            start.addDays(i ~/ 3).toIso(),
            i % 3 == 0 ? Quadrant.storm : Quadrant.values[i % 4],
            tags: i % 3 == 0 ? const ['work'] : const [],
          ),
      ];
      final ps = findPatterns(
        checkIns: cs,
        range: DayRange(start, start.addDays(364)),
      );
      expect(
        ps.first,
        const InsightPattern(PatternKind.tagQuadrant, Quadrant.storm, 'work'),
      );
    });

    test('weekly card: Sunday-start weeks describe Sunday–Saturday', () {
      final w = weeklyWindow(d('2026-10-10'), weekStartsOn: DateTime.sunday);
      expect(w.weekStart, d('2026-10-04'));
      expect(w.range, DayRange(d('2026-09-27'), d('2026-10-03')));
    });
  });

  group('sky', () {
    test('rest days are only bridged gaps, never the days after a reset', () {
      expect(restDays([d('2026-10-01'), d('2026-10-10')]), isEmpty);
    });

    test('calendarMonth covers leap February', () {
      final feb = calendarMonth(2028, 2);
      expect(feb.from, d('2028-02-01'));
      expect(feb.to, d('2028-02-29'));
      expect(feb.length, 29);
    });

    test('a split star lists quadrants in catalogue order', () {
      expect(
        dayStar([Quadrant.sunrise, Quadrant.storm]),
        const DayStar(DayStarKind.split, [Quadrant.storm, Quadrant.sunrise]),
      );
    });
  });
}
