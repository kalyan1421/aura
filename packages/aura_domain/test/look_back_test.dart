// F10 Look back (RULES.md §10.1): edge dates and the safety gate, beyond the
// shared vectors (contracts/rules/vectors/look_back.json).
import 'package:aura_domain/aura_domain.dart';
import 'package:test/test.dart';

LocalDay d(String iso) => LocalDay.parse(iso);

void main() {
  group('addMonthsClamped', () {
    test('clamps to every month length', () {
      expect(addMonthsClamped(d('2027-03-31'), -1), d('2027-02-28'));
      expect(addMonthsClamped(d('2028-03-31'), -1), d('2028-02-29'));
      expect(addMonthsClamped(d('2026-05-31'), -1), d('2026-04-30'));
      expect(addMonthsClamped(d('2026-07-31'), -1), d('2026-06-30'));
      expect(addMonthsClamped(d('2026-10-31'), -1), d('2026-09-30'));
      expect(addMonthsClamped(d('2026-12-31'), -1), d('2026-11-30'));
      expect(addMonthsClamped(d('2026-08-31'), -6), d('2026-02-28'));
      expect(addMonthsClamped(d('2028-08-31'), -6), d('2028-02-29'));
    });

    test('leap days', () {
      expect(addMonthsClamped(d('2028-02-29'), -12), d('2027-02-28'));
      expect(addMonthsClamped(d('2028-02-29'), -48), d('2024-02-29'));
      expect(addMonthsClamped(d('2028-02-29'), -1), d('2028-01-29'));
      expect(addMonthsClamped(d('2028-02-29'), 12), d('2029-02-28'));
      // 2100 is not a leap year; 2000 was.
      expect(addMonthsClamped(d('2100-03-29'), -1), d('2100-02-28'));
      expect(addMonthsClamped(d('2000-03-29'), -1), d('2000-02-29'));
    });

    test('crosses years both ways', () {
      expect(addMonthsClamped(d('2027-01-15'), -1), d('2026-12-15'));
      expect(addMonthsClamped(d('2027-01-15'), -13), d('2025-12-15'));
      expect(addMonthsClamped(d('2026-12-15'), 1), d('2027-01-15'));
      expect(addMonthsClamped(d('2026-06-30'), -6), d('2025-12-30'));
    });

    test('the 1st and days ≤ 28 never move within the month', () {
      for (var m = 1; m <= 12; m++) {
        for (final day in [1, 15, 28]) {
          final from = LocalDay(2027, m, day);
          for (final back in lookBackMonths) {
            expect(addMonthsClamped(from, -back).day, day);
          }
        }
      }
    });

    test('daysInMonth', () {
      expect(daysInMonth(2027, 2), 28);
      expect(daysInMonth(2028, 2), 29);
      expect(daysInMonth(1900, 2), 28);
      expect(daysInMonth(2000, 2), 29);
      expect(daysInMonth(2026, 4), 30);
      expect(daysInMonth(2026, 12), 31);
    });
  });

  group('lookBackWindows', () {
    test('every window is one whole week starting on the week start', () {
      var today = d('2026-01-01');
      for (var i = 0; i < 800; i++, today = today.addDays(1)) {
        final ws = lookBackWindows(today);
        expect(ws.map((w) => w.months), [1, 6, 12]);
        for (final w in ws) {
          expect(w.range.length, 7);
          expect(isoWeekday(w.range.from), DateTime.monday);
          expect(w.range.contains(w.anchor), isTrue);
          // Never the current week: the newest one ends at least 3 weeks ago.
          expect(w.range.to.isBefore(today.addDays(-20)), isTrue);
        }
        // Oldest last, never overlapping.
        expect(ws[1].range.to.isBefore(ws[0].range.from), isTrue);
        expect(ws[2].range.to.isBefore(ws[1].range.from), isTrue);
      }
    });

    test('weeks starting Sunday', () {
      final ws = lookBackWindows(
        d('2026-10-08'),
        weekStartsOn: DateTime.sunday,
      );
      for (final w in ws) {
        expect(isoWeekday(w.range.from), DateTime.sunday);
      }
      expect(ws.first.range, DayRange(d('2026-09-06'), d('2026-09-12')));
    });

    test('a timezone change moves only today (entries keep their day)', () {
      final instant = DateTime.utc(2026, 10, 8, 3);
      final ny = lookBackWindows(auraDay(instant, 'America/New_York'));
      final ist = lookBackWindows(auraDay(instant, 'Asia/Kolkata'));
      expect(ny.first.anchor, d('2026-09-07'));
      expect(ist.first.anchor, d('2026-09-08'));
      // Same week either way here: an entry stamped 8 Sep stays in it.
      expect(ny.first.range, ist.first.range);
    });
  });

  group('lookBackGate', () {
    final now = DateTime.utc(2026, 10, 8, 10);
    LookBackGateCheckIn ci(Quadrant q, DateTime at) =>
        (quadrant: q, deviceTs: at);

    test('open with nothing recent', () {
      expect(lookBackGate(now: now), LookBackGate.open);
    });

    test('3 h after Storm and Rain, to the minute', () {
      for (final q in [Quadrant.storm, Quadrant.rain]) {
        final at = now.subtract(const Duration(hours: 2, minutes: 59));
        expect(
          lookBackGate(now: now, checkIns: [ci(q, at)]),
          LookBackGate(
            LookBackGateStatus.afterHeavy,
            at.add(const Duration(hours: 3)),
          ),
        );
        expect(
          lookBackGate(
            now: now,
            checkIns: [ci(q, now.subtract(const Duration(hours: 3)))],
          ).isOpen,
          isTrue,
        );
      }
    });

    test('Moonlight and Sunrise never hide it', () {
      expect(
        lookBackGate(
          now: now,
          checkIns: [
            ci(Quadrant.moonlight, now),
            ci(Quadrant.sunrise, now.subtract(const Duration(minutes: 1))),
          ],
        ).isOpen,
        isTrue,
      );
    });

    test('24 h after a crisis sheet, to the minute', () {
      final help = now.subtract(const Duration(hours: 23, minutes: 59));
      expect(
        lookBackGate(now: now, helpAt: help),
        LookBackGate(
          LookBackGateStatus.afterHelp,
          help.add(const Duration(hours: 24)),
        ),
      );
      expect(
        lookBackGate(
          now: now,
          helpAt: now.subtract(const Duration(hours: 24)),
        ).isOpen,
        isTrue,
      );
    });

    test('a local-time instant compares as an instant', () {
      // 14:00 IST = 08:30 UTC, 1.5 h before now.
      final at = DateTime.parse('2026-10-08T14:00:00+05:30');
      final g = lookBackGate(now: now, checkIns: [ci(Quadrant.rain, at)]);
      expect(g.status, LookBackGateStatus.afterHeavy);
      expect(g.until, DateTime.utc(2026, 10, 8, 11, 30));
    });

    test('clock skew: a future help time or check-in keeps it hidden', () {
      expect(
        lookBackGate(now: now, helpAt: now.add(const Duration(days: 2))).status,
        LookBackGateStatus.afterHelp,
      );
      expect(
        lookBackGate(
          now: now,
          checkIns: [ci(Quadrant.storm, now.add(const Duration(hours: 1)))],
        ).status,
        LookBackGateStatus.afterHeavy,
      );
    });

    test('hidden in Settings wins over everything', () {
      expect(
        lookBackGate(
          now: now,
          hidden: true,
          helpAt: now,
          checkIns: [ci(Quadrant.storm, now)],
        ),
        LookBackGate.off,
      );
    });
  });

  group('lookBackSky', () {
    final week = DayRange(d('2026-09-07'), d('2026-09-13'));
    LookBackEntry e(
      String id,
      String day,
      Quadrant q, {
      int hour = 6,
      bool crisis = false,
      bool help = false,
      bool unreadable = false,
      bool deleted = false,
    }) => LookBackEntry(
      id: id,
      localDay: d(day),
      quadrant: q,
      deviceTs: DateTime.utc(d(day).year, d(day).month, d(day).day, hour),
      lexiconCrisis: crisis,
      helpOpened: help,
      noteUnreadable: unreadable,
      deleted: deleted,
    );

    test('seven days, first to last, even when empty', () {
      final sky = lookBackSky(week, const []);
      expect(sky.visible, isFalse);
      expect(sky.days.map((x) => x.day.toIso()), [
        '2026-09-07',
        '2026-09-08',
        '2026-09-09',
        '2026-09-10',
        '2026-09-11',
        '2026-09-12',
        '2026-09-13',
      ]);
      expect(sky.days.every((x) => x.star == DayStar.empty), isTrue);
    });

    test('no flagged entry ever shows, and no star hints at one', () {
      final sky = lookBackSky(week, [
        e('ok', '2026-09-08', Quadrant.sunrise),
        e('crisis', '2026-09-08', Quadrant.storm, hour: 7, crisis: true),
        e('crisis2', '2026-09-08', Quadrant.storm, hour: 8, crisis: true),
        e('help', '2026-09-09', Quadrant.rain, help: true),
        e('locked', '2026-09-10', Quadrant.rain, unreadable: true),
        e('gone', '2026-09-11', Quadrant.storm, deleted: true),
      ]);
      expect(sky.visible, isTrue);
      final all = [for (final x in sky.days) ...x.entryIds];
      expect(all, ['ok']);
      expect(
        sky.days[1].star,
        const DayStar(DayStarKind.single, [Quadrant.sunrise]),
      );
      for (final i in [2, 3, 4]) {
        expect(sky.days[i].star, DayStar.empty);
      }
    });

    test('entries outside the week are ignored', () {
      final sky = lookBackSky(week, [
        e('before', '2026-09-06', Quadrant.storm),
        e('after', '2026-09-14', Quadrant.storm),
      ]);
      expect(sky.visible, isFalse);
    });
  });
}
