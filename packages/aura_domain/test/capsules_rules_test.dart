import 'package:aura_domain/aura_domain.dart';
import 'package:test/test.dart';

/// RULES.md §9 helpers beyond the shared vectors (capsules.json runs in
/// vectors_test.dart): the picker's bounds, strict date parsing, the DST
/// rules of [zonedInstant] and the arming / cooldown transitions.
void main() {
  group('calendar dates', () {
    test('calendarDateOf has no 04:00 shift', () {
      // 01:30 IST on 9 Oct is still "9 Oct" (the Aura day would be 8 Oct).
      final t = DateTime.utc(2026, 10, 8, 20);
      expect(calendarDateOf(t, 'Asia/Kolkata').toIso(), '2026-10-09');
      expect(auraDay(t, 'Asia/Kolkata').toIso(), '2026-10-08');
    });

    test('addYearsClamped keeps month/day, 29 Feb → 28 Feb', () {
      expect(
        addYearsClamped(LocalDay.parse('2026-10-08'), 5).toIso(),
        '2031-10-08',
      );
      expect(
        addYearsClamped(LocalDay.parse('2028-02-29'), 5).toIso(),
        '2033-02-28',
      );
      expect(
        addYearsClamped(LocalDay.parse('2028-02-29'), 4).toIso(),
        '2032-02-29',
      );
    });

    test('parseCalendarDate refuses dates that do not exist', () {
      expect(parseCalendarDate('2026-02-30'), isNull);
      expect(parseCalendarDate('2026-13-01'), isNull);
      expect(parseCalendarDate('2026-00-10'), isNull);
      expect(parseCalendarDate('2026-1-01'), isNull);
      expect(parseCalendarDate('2026-10-08T10:00'), isNull);
      expect(parseCalendarDate(null), isNull);
      expect(parseCalendarDate('2028-02-29')?.toIso(), '2028-02-29');
    });

    test('unlockWindowFor gives the picker its first and last day', () {
      final w = unlockWindowFor(
        DateTime.parse('2026-10-08T18:00:00+05:30'),
        'Asia/Kolkata',
      );
      expect(w.first.toIso(), '2026-10-15');
      expect(w.last.toIso(), '2031-10-08');
      expect(w.contains(LocalDay.parse('2026-10-14')), isFalse);
      expect(w.contains(LocalDay.parse('2031-10-09')), isFalse);
      expect(w.contains(LocalDay.parse('2027-01-01')), isTrue);
    });
  });

  group('zonedInstant', () {
    test('a wall time inside the spring-forward gap moves forward', () {
      // New York skips 02:00–03:00 on 14 Mar 2027: 02:30 does not exist and
      // reads with the pre-transition offset (EST, −5) → 07:30Z = 03:30 EDT.
      expect(
        zonedInstant(LocalDay.parse('2027-03-14'), 2, 30, 'America/New_York'),
        DateTime.utc(2027, 3, 14, 7, 30),
      );
    });

    test('a repeated wall time takes the earlier instant', () {
      // 01:30 happens twice on 7 Nov 2027 in New York: EDT (05:30Z) first.
      expect(
        zonedInstant(LocalDay.parse('2027-11-07'), 1, 30, 'America/New_York'),
        DateTime.utc(2027, 11, 7, 5, 30),
      );
    });

    test('unlock at 10:00 in the current zone; due from that instant', () {
      final day = LocalDay.parse('2027-10-08');
      final at = capsuleUnlockAt(day, 'Asia/Kolkata');
      expect(at, DateTime.utc(2027, 10, 8, 4, 30));
      expect(
        isDateCapsuleDue(
          day,
          'Asia/Kolkata',
          at.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(isDateCapsuleDue(day, 'Asia/Kolkata', at), isTrue);
      // After a move to Los Angeles the same date unlocks later.
      expect(isDateCapsuleDue(day, 'America/Los_Angeles', at), isFalse);
    });
  });

  group('arming and cooldown', () {
    test('armedAt = seal + 24 h; cooldown = fire + 168 h', () {
      final seal = DateTime.parse('2026-10-05T18:00:00+05:30');
      expect(capsuleArmedAt(seal), DateTime.utc(2026, 10, 6, 12, 30));
      final fire = DateTime.parse('2026-10-12T09:00:00+05:30');
      expect(capsuleCooldownUntil(fire), DateTime.utc(2026, 10, 19, 3, 30));
    });

    test('globalCooldownUntil is the latest over all rows', () {
      TriggerCapsule c(String id, DateTime? until) => TriggerCapsule(
        id: id,
        unlockType: CapsuleUnlockType.mood,
        sealedAt: DateTime.utc(2026),
        cooldownUntil: until,
      );
      expect(globalCooldownUntil(const []), isNull);
      expect(
        globalCooldownUntil([
          c('a', DateTime.utc(2026, 10, 1)),
          c('b', null),
          c('c', DateTime.utc(2026, 10, 9)),
        ]),
        DateTime.utc(2026, 10, 9),
      );
    });

    test('a capsule without armedAt never fires', () {
      final pick = pickTrigger(
        [
          TriggerCapsule(
            id: 'x',
            unlockType: CapsuleUnlockType.mood,
            triggerQuadrant: Quadrant.storm,
            sealedAt: DateTime.utc(2026, 10, 1),
          ),
        ],
        TriggerCheckIn(
          moodId: 'anxious',
          quadrant: Quadrant.storm,
          deviceTs: DateTime.utc(2026, 10, 8),
          live: true,
          crisis: false,
        ),
      );
      expect(pick.isNone, isTrue);
    });
  });
}
