import 'package:aura_domain/aura_domain.dart';
import 'package:test/test.dart';

void main() {
  group('resolveTimeZone', () {
    test('known IANA ids pass through', () {
      expect(
        resolveTimeZone('Asia/Kolkata', const Duration(hours: 5, minutes: 30)),
        'Asia/Kolkata',
      );
      expect(
        resolveTimeZone('Asia/Calcutta', const Duration(hours: 5, minutes: 30)),
        'Asia/Calcutta',
      );
    });

    test('unknown zone, whole-hour offset → Etc/GMT with inverted sign', () {
      expect(
        resolveTimeZone('Mars/Olympus', const Duration(hours: 5)),
        'Etc/GMT-5',
      );
      expect(resolveTimeZone(null, const Duration(hours: -4)), 'Etc/GMT+4');
      expect(resolveTimeZone('', Duration.zero), 'UTC');
    });

    test('unknown zone, fractional offset → nearest well-known zone', () {
      expect(
        resolveTimeZone('x', const Duration(hours: 5, minutes: 30)),
        'Asia/Kolkata',
      );
      expect(
        resolveTimeZone('x', const Duration(hours: 5, minutes: 45)),
        'Asia/Kathmandu',
      );
      expect(
        resolveTimeZone('x', const Duration(hours: 9, minutes: 30)),
        'Australia/Darwin',
      );
      expect(
        resolveTimeZone('x', const Duration(hours: -3, minutes: -30)),
        'America/St_Johns',
      );
      expect(
        resolveTimeZone('x', const Duration(hours: 3, minutes: 17)),
        'UTC',
      );
    });

    test('auraDay agrees with the resolved fixed-offset zone (UTC+5)', () {
      final zone = resolveTimeZone('Mars/Olympus', const Duration(hours: 5));
      // 22:59 UTC = 03:59 local next day → still the previous Aura day.
      expect(
        auraDay(DateTime.utc(2026, 10, 7, 22, 59), zone).toIso(),
        '2026-10-07',
      );
      // 23:00 UTC = 04:00 local → rolls over.
      expect(
        auraDay(DateTime.utc(2026, 10, 7, 23), zone).toIso(),
        '2026-10-08',
      );
      expect(
        utcOffsetAt(DateTime.utc(2026, 10, 7), zone),
        const Duration(hours: 5),
      );
    });

    test('an unknown zone reaching auraDay is loud in debug (assert)', () {
      expect(
        () => auraDay(DateTime.utc(2026), 'Nowhere/Land'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  test('projection judges each event in its own stamped zone', () {
    // Logged at 23:30 in New York on 7 Oct (= 03:30 UTC on 8 Oct), synced
    // later from India. In IST that instant is already 8 Oct 09:00, but the
    // event's Aura day is 7 Oct in its own zone, so it is not a backfill.
    final ts = DateTime.utc(2026, 10, 8, 3, 30);
    final now = DateTime.utc(2026, 10, 8, 4);
    final event = ProgressEvent.checkIn(
      id: 'ny',
      deviceTs: ts,
      localDay: LocalDay.parse('2026-10-07'),
      quadrant: Quadrant.rain,
      timezone: 'America/New_York',
    );
    final p = projectProgress(
      events: [event],
      now: now,
      timezone: 'Asia/Kolkata',
    );
    expect(p.awards['ny'], 10);
    expect(p.streak.lastActiveDay, LocalDay.parse('2026-10-07'));

    final judgedHere = projectProgress(
      events: [
        ProgressEvent.checkIn(
          id: 'ny',
          deviceTs: ts,
          localDay: LocalDay.parse('2026-10-07'),
          quadrant: Quadrant.rain,
        ),
      ],
      now: now,
      timezone: 'Asia/Kolkata',
    );
    expect(judgedHere.awards['ny'], 0);
  });
}
