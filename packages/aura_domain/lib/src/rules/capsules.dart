import 'package:meta/meta.dart';

import '../catalog.g.dart';
import '../local_day.dart';
import 'aura_day.dart';

// ---------------------------------------------------------------------------
// 9. Time capsules (RULES.md section 9, vectors: capsules.json, PRD F4)
// ---------------------------------------------------------------------------
//
// Pure functions the app runs offline (date unlock, trigger firing) and the
// server runs too (seal validation, the "capsule unlocked" push). The same
// JSON vectors run in both implementations.

/// A date capsule opens at least this many days after the seal's date…
const int capsuleUnlockMinDays = 7;

/// …and at most this many years after it (REQ-CAP-01).
const int capsuleUnlockMaxYears = 5;

/// A date capsule unlocks at this wall-clock hour, in the current zone.
const int capsuleUnlockHour = 10;

/// A mood-trigger capsule arms this long after sealing (REQ-CAP-02).
const Duration capsuleArmingDelay = Duration(hours: 24);

/// After any trigger capsule fires, none fires for this long (7 × 24 h,
/// absolute: REQ-CAP-03 "fired Mon 09:00 → nothing before next Mon 09:00").
const Duration capsuleCooldown = Duration(hours: 168);

/// Free accounts keep at most this many active trigger capsules (REQ-CAP-04).
/// Plus ("unlimited") is not built, so everyone is Free.
const int maxActiveTriggerCapsules = 3;

/// Fair-use cap on pending (sealed, unopened) date capsules `[ASSUMPTION]`.
const int maxPendingDateCapsules = 200;

/// How a capsule unlocks.
enum CapsuleUnlockType {
  /// At 10:00 local on a chosen date.
  date,

  /// On the next matching check-in (one mood or a quadrant).
  mood;

  static CapsuleUnlockType? byName(String? name) => switch (name) {
    'date' => date,
    'mood' => mood,
    _ => null,
  };
}

/// The calendar date of [instant] in [ianaTz] — the wall-clock date, with
/// **no** 04:00 Aura-day shift (a seal at 01:30 belongs to that day).
LocalDay calendarDateOf(DateTime instant, String ianaTz) {
  final local = instant.toUtc().add(utcOffsetAt(instant, ianaTz));
  return LocalDay(local.year, local.month, local.day);
}

/// [day] plus [years], keeping month and day; 29 Feb becomes 28 Feb when the
/// target year has no 29 Feb.
LocalDay addYearsClamped(LocalDay day, int years) {
  final year = day.year + years;
  final daysInMonth = DateTime.utc(year, day.month + 1, 0).day;
  return LocalDay(
    year,
    day.month,
    day.day > daysInMonth ? daysInMonth : day.day,
  );
}

/// Parses `YYYY-MM-DD` strictly: `null` for anything that isn't a real date
/// (e.g. `2026-02-30`, which [LocalDay.parse] would roll over to March).
LocalDay? parseCalendarDate(String? iso) {
  if (iso == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1) return null;
  if (d > DateTime.utc(y, mo + 1, 0).day) return null;
  return LocalDay(y, mo, d);
}

/// The inclusive range of unlock dates for a capsule sealed at [sealedAt] in
/// [ianaTz]: 7 days to 5 years after the seal's calendar date.
@immutable
class UnlockWindow {
  const UnlockWindow({required this.first, required this.last});

  final LocalDay first;
  final LocalDay last;

  bool contains(LocalDay day) => !day.isBefore(first) && !day.isAfter(last);

  @override
  bool operator ==(Object other) =>
      other is UnlockWindow && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => 'UnlockWindow($first … $last)';
}

/// RULES.md §9 `window` bounds (the date picker's first and last day).
UnlockWindow unlockWindowFor(DateTime sealedAt, String ianaTz) {
  final sealDate = calendarDateOf(sealedAt, ianaTz);
  return UnlockWindow(
    first: sealDate.addDays(capsuleUnlockMinDays),
    last: addYearsClamped(sealDate, capsuleUnlockMaxYears),
  );
}

/// RULES.md §9 `window`: whether [unlockLocalDate] (`YYYY-MM-DD`) is a real
/// date from 7 days to 5 years after the seal's calendar date in [ianaTz].
bool isValidUnlockDate(
  DateTime sealedAt,
  String ianaTz,
  String unlockLocalDate,
) {
  final day = parseCalendarDate(unlockLocalDate);
  return day != null && unlockWindowFor(sealedAt, ianaTz).contains(day);
}

/// The instant the wall clock in [ianaTz] reads [hour]:[minute] on [day].
///
/// A wall time that occurs twice (DST fall-back) → the earlier instant; one
/// that does not exist (DST gap) → shifted forward by the gap, i.e. read
/// with the offset in force before the transition (java.time / Temporal
/// "compatible"). Same algorithm as the server's `zonedInstant`.
DateTime zonedInstant(LocalDay day, int hour, int minute, String ianaTz) {
  final wall = DateTime.utc(day.year, day.month, day.day, hour, minute);
  Duration offsetAt(DateTime t) => utcOffsetAt(t, ianaTz);
  final before = offsetAt(wall.subtract(const Duration(days: 1)));
  final offsets = <Duration>{
    before,
    offsetAt(wall),
    offsetAt(wall.add(const Duration(days: 1))),
  };
  DateTime? earliest;
  for (final o in offsets) {
    final t = wall.subtract(o);
    if (offsetAt(t) != o) continue; // this offset isn't in force then
    if (earliest == null || t.isBefore(earliest)) earliest = t;
  }
  return earliest ?? wall.subtract(before);
}

/// RULES.md §9 `unlock_at`: 10:00 on [localDate] in [ianaTz]. Always
/// evaluated in the user's **current** zone (a move re-times the unlock).
DateTime capsuleUnlockAt(LocalDay localDate, String ianaTz) =>
    zonedInstant(localDate, capsuleUnlockHour, 0, ianaTz);

/// A date capsule is due once `now ≥ unlockAt(date, currentTz)`.
bool isDateCapsuleDue(LocalDay unlockDate, String currentTz, DateTime now) =>
    !now.toUtc().isBefore(capsuleUnlockAt(unlockDate, currentTz));

/// A trigger capsule sealed at [sealedAt] may fire from this instant.
DateTime capsuleArmedAt(DateTime sealedAt) =>
    sealedAt.toUtc().add(capsuleArmingDelay);

/// A fire at [firedAt] holds every trigger capsule until this instant.
DateTime capsuleCooldownUntil(DateTime firedAt) =>
    firedAt.toUtc().add(capsuleCooldown);

/// What the trigger rule needs to know about one capsule (all of the
/// user's capsules, tombstones included: a deleted capsule's fire still
/// holds the global cooldown).
@immutable
class TriggerCapsule {
  const TriggerCapsule({
    required this.id,
    required this.unlockType,
    required this.sealedAt,
    this.triggerMoodId,
    this.triggerQuadrant,
    this.armedAt,
    this.firedAt,
    this.openedAt,
    this.deletedAt,
    this.cooldownUntil,
  });

  final String id;
  final CapsuleUnlockType unlockType;
  final String? triggerMoodId;
  final Quadrant? triggerQuadrant;
  final DateTime sealedAt;
  final DateTime? armedAt;
  final DateTime? firedAt;
  final DateTime? openedAt;
  final DateTime? deletedAt;
  final DateTime? cooldownUntil;
}

/// The check-in a trigger is evaluated for.
@immutable
class TriggerCheckIn {
  const TriggerCheckIn({
    required this.moodId,
    required this.quadrant,
    required this.deviceTs,
    required this.live,
    required this.crisis,
  });

  final String moodId;
  final Quadrant quadrant;
  final DateTime deviceTs;

  /// False for a backfill: backfills never fire capsules.
  final bool live;

  /// A crisis-lexicon hit or "I need help now": the pick is held.
  final bool crisis;
}

/// The outcome of [pickTrigger]: at most one of [fire] / [hold] is set.
@immutable
class TriggerPick {
  const TriggerPick({this.fire, this.hold});

  static const TriggerPick none = TriggerPick();

  /// Fire this capsule now (cooldown starts).
  final String? fire;

  /// Crisis collision: offer "Open now, or later?" after the support sheet.
  final String? hold;

  bool get isNone => fire == null && hold == null;

  @override
  bool operator ==(Object other) =>
      other is TriggerPick && other.fire == fire && other.hold == hold;

  @override
  int get hashCode => Object.hash(fire, hold);

  @override
  String toString() => 'TriggerPick(fire: $fire, hold: $hold)';
}

/// The latest `cooldownUntil` over [capsules] (tombstones included), or
/// `null` when nothing has fired.
DateTime? globalCooldownUntil(Iterable<TriggerCapsule> capsules) {
  DateTime? latest;
  for (final c in capsules) {
    final t = c.cooldownUntil;
    if (t == null) continue;
    if (latest == null || t.isAfter(latest)) latest = t;
  }
  return latest;
}

/// RULES.md §9 `trigger`: which capsule a saved check-in fires (or holds).
TriggerPick pickTrigger(
  Iterable<TriggerCapsule> capsules,
  TriggerCheckIn checkIn,
) {
  if (!checkIn.live) return TriggerPick.none;
  final at = checkIn.deviceTs.toUtc();
  final cooldown = globalCooldownUntil(capsules);
  if (cooldown != null && at.isBefore(cooldown)) return TriggerPick.none;
  final candidates = [
    for (final c in capsules)
      if (c.unlockType == CapsuleUnlockType.mood &&
          c.deletedAt == null &&
          c.firedAt == null &&
          c.openedAt == null &&
          c.armedAt != null &&
          !c.armedAt!.isAfter(at) &&
          ((c.triggerMoodId != null && c.triggerMoodId == checkIn.moodId) ||
              (c.triggerQuadrant != null &&
                  c.triggerQuadrant == checkIn.quadrant)))
        c,
  ];
  if (candidates.isEmpty) return TriggerPick.none;
  candidates.sort((a, b) {
    final byArmed = a.armedAt!.compareTo(b.armedAt!);
    if (byArmed != 0) return byArmed;
    final bySeal = a.sealedAt.compareTo(b.sealedAt);
    if (bySeal != 0) return bySeal;
    return a.id.compareTo(b.id);
  });
  final pick = candidates.first.id;
  return checkIn.crisis ? TriggerPick(hold: pick) : TriggerPick(fire: pick);
}
