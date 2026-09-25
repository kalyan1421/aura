// F10 Look back (Milestone C): RULES.md section 10.1 (contracts/rules/vectors/
// look_back.json). Pure and on-device only, like the rest of Insights: the
// person's own check-ins go in, three past weeks of their sky come out.
// Nothing here is uploaded, pushed or shown outside Insights (PRD F10,
// REQ-INS-08).
import 'package:meta/meta.dart';

import '../catalog.g.dart';
import '../local_day.dart';
import 'insights.dart';

// ---- windows ------------------------------------------------------------------

/// How far back each Look back week sits, in calendar months: the same week
/// 1 month, 6 months and 1 year ago (PRD F10).
const List<int> lookBackMonths = [1, 6, 12];

/// Days in [year]-[month] (proleptic Gregorian).
int daysInMonth(int year, int month) =>
    DateTime.utc(year, month + 1, 1).subtract(const Duration(days: 1)).day;

/// [day] moved by [months] calendar months (negative = back), keeping the
/// day of the month and clamping it to the target month's length: 31 Mar
/// − 1 month = 28 Feb (29 Feb in a leap year); 29 Feb − 12 months = 28 Feb
/// (RULES.md §10.1 `add_months`).
LocalDay addMonthsClamped(LocalDay day, int months) {
  final index = day.year * 12 + (day.month - 1) + months;
  final year = index ~/ 12;
  final month = index % 12 + 1;
  final last = daysInMonth(year, month);
  return LocalDay(year, month, day.day > last ? last : day.day);
}

/// One Look back week.
@immutable
final class LookBackWindow {
  const LookBackWindow({
    required this.months,
    required this.anchor,
    required this.range,
  });

  /// 1, 6 or 12.
  final int months;

  /// Today moved back [months] months (clamped).
  final LocalDay anchor;

  /// The whole week holding [anchor] (7 Aura days).
  final DayRange range;

  @override
  bool operator ==(Object other) =>
      other is LookBackWindow &&
      other.months == months &&
      other.anchor == anchor &&
      other.range == range;

  @override
  int get hashCode => Object.hash(months, anchor, range);

  @override
  String toString() => 'LookBackWindow($months, $anchor, $range)';
}

/// The three Look back weeks for [today] (the Aura day now, in the phone's
/// current zone): for each of [lookBackMonths], the week (starting on
/// [weekStartsOn]) that holds `addMonthsClamped(today, −m)` (RULES.md §10.1
/// `windows`). Entries are matched on their stamped Aura day, so a timezone
/// change moves only "today", never an entry.
List<LookBackWindow> lookBackWindows(
  LocalDay today, {
  int weekStartsOn = DateTime.monday,
}) => List.unmodifiable([
  for (final m in lookBackMonths)
    () {
      final anchor = addMonthsClamped(today, -m);
      final start = weekStart(anchor, weekStartsOn: weekStartsOn);
      return LookBackWindow(
        months: m,
        anchor: anchor,
        range: DayRange(start, start.addDays(6)),
      );
    }(),
]);

// ---- safety gate ----------------------------------------------------------------

/// Hidden for this long after a Storm or Rain check-in (PRD F10
/// `[ASSUMPTION]`, the same 3 h as BD-6).
const Duration lookBackAfterHeavy = Duration(hours: 3);

/// Hidden for this long after a crisis sheet on this phone (PRD F10).
const Duration lookBackAfterHelp = Duration(hours: 24);

/// Why Look back is (not) shown right now.
enum LookBackGateStatus {
  /// Shown (still pull-only: only inside Insights, on the person's tap).
  open,

  /// Hidden in Settings by the person.
  off,

  /// Within 24 h of a crisis sheet (or the Safety Center) on this phone.
  afterHelp,

  /// Within 3 h of a Storm or Rain check-in.
  afterHeavy,
}

@immutable
final class LookBackGate {
  const LookBackGate(this.status, [this.until]);

  static const LookBackGate open = LookBackGate(LookBackGateStatus.open);
  static const LookBackGate off = LookBackGate(LookBackGateStatus.off);

  final LookBackGateStatus status;

  /// When every gate in force has ended (UTC); `null` for open and off.
  final DateTime? until;

  bool get isOpen => status == LookBackGateStatus.open;

  @override
  bool operator ==(Object other) =>
      other is LookBackGate && other.status == status && other.until == until;

  @override
  int get hashCode => Object.hash(status, until);

  @override
  String toString() => 'LookBackGate(${status.name}, $until)';
}

/// A check-in as the gate sees it: when it was made and its quadrant. Every
/// check-in made counts, deleted ones and backfills included (it is the
/// moment that matters, not the day it was for).
typedef LookBackGateCheckIn = ({Quadrant quadrant, DateTime deviceTs});

/// The Look back safety gate (RULES.md §10.1 `gate`):
/// 1. [hidden] in Settings → [LookBackGateStatus.off].
/// 2. `now < helpAt + 24 h` → [LookBackGateStatus.afterHelp].
/// 3. `now < t + 3 h` for a Storm or Rain check-in made at `t` →
///    [LookBackGateStatus.afterHeavy].
/// `until` is the latest end among the gates in force. Instants compare as
/// instants; a time in the future (clock skew) keeps it hidden.
LookBackGate lookBackGate({
  required DateTime now,
  Iterable<LookBackGateCheckIn> checkIns = const [],
  DateTime? helpAt,
  bool hidden = false,
}) {
  if (hidden) return LookBackGate.off;
  final n = now.toUtc();
  DateTime? helpEnd;
  if (helpAt != null) {
    final end = helpAt.toUtc().add(lookBackAfterHelp);
    if (n.isBefore(end)) helpEnd = end;
  }
  DateTime? heavyEnd;
  for (final c in checkIns) {
    if (c.quadrant != Quadrant.storm && c.quadrant != Quadrant.rain) continue;
    final end = c.deviceTs.toUtc().add(lookBackAfterHeavy);
    if (n.isBefore(end) && (heavyEnd == null || end.isAfter(heavyEnd))) {
      heavyEnd = end;
    }
  }
  if (helpEnd == null && heavyEnd == null) return LookBackGate.open;
  final until = helpEnd == null
      ? heavyEnd!
      : heavyEnd == null || !heavyEnd.isAfter(helpEnd)
      ? helpEnd
      : heavyEnd;
  return LookBackGate(
    helpEnd != null
        ? LookBackGateStatus.afterHelp
        : LookBackGateStatus.afterHeavy,
    until,
  );
}

// ---- the week's sky ---------------------------------------------------------------

/// One check-in as Look back sees it. The note itself never comes here: the
/// device runs the crisis lexicon on it and passes the verdict.
@immutable
final class LookBackEntry {
  const LookBackEntry({
    required this.id,
    required this.localDay,
    required this.quadrant,
    required this.deviceTs,
    this.deleted = false,
    this.lexiconCrisis = false,
    this.helpOpened = false,
    this.noteUnreadable = false,
  });

  final String id;

  /// The stamped Aura day (never recomputed).
  final LocalDay localDay;
  final Quadrant quadrant;
  final DateTime deviceTs;
  final bool deleted;

  /// The crisis lexicon matches its note, re-run when it is displayed.
  final bool lexiconCrisis;

  /// Help was opened from this check-in on this phone (a device-only flag).
  final bool helpOpened;

  /// It has a note this phone can't read yet, so the lexicon couldn't check
  /// it: left out rather than risked.
  final bool noteUnreadable;

  /// Crisis-flagged, deleted or unchecked entries never appear.
  bool get shows =>
      !deleted && !lexiconCrisis && !helpOpened && !noteUnreadable;
}

/// One day of a Look back week: its star from the entries that show, and
/// those entries' ids in the order they were made.
@immutable
final class LookBackDay {
  const LookBackDay({
    required this.day,
    required this.star,
    required this.entryIds,
  });

  final LocalDay day;
  final DayStar star;
  final List<String> entryIds;

  @override
  bool operator ==(Object other) =>
      other is LookBackDay &&
      other.day == day &&
      other.star == star &&
      _sameIds(other.entryIds, entryIds);

  @override
  int get hashCode => Object.hash(day, star, Object.hashAll(entryIds));

  @override
  String toString() => 'LookBackDay($day, $star, $entryIds)';
}

@immutable
final class LookBackSky {
  const LookBackSky({required this.visible, required this.days});

  /// At least one entry shows in the week; a week with none is left out.
  final bool visible;

  /// Every day of the week, first to last.
  final List<LookBackDay> days;
}

/// A Look back week's sky (RULES.md §10.1 `sky`): only entries that
/// [LookBackEntry.shows], matched on their stamped Aura day; each day's star
/// is [dayStar] over those (a day whose only entries were left out is plain
/// sky, never a hint of them); rest days (from `rest_days`, §10) are rings.
LookBackSky lookBackSky(
  DayRange range,
  Iterable<LookBackEntry> entries, {
  Set<LocalDay> restDays = const {},
}) {
  final byDay = <LocalDay, List<LookBackEntry>>{};
  for (final e in entries) {
    if (!e.shows || !range.contains(e.localDay)) continue;
    byDay.putIfAbsent(e.localDay, () => []).add(e);
  }
  final days = <LookBackDay>[];
  for (var i = 0; i < range.length; i++) {
    final day = range.from.addDays(i);
    final list = [...?byDay[day]]
      ..sort((a, b) {
        final t = a.deviceTs.compareTo(b.deviceTs);
        return t != 0 ? t : a.id.compareTo(b.id);
      });
    days.add(
      LookBackDay(
        day: day,
        star: dayStar(
          list.map((e) => e.quadrant),
          rest: restDays.contains(day),
        ),
        entryIds: List.unmodifiable([for (final e in list) e.id]),
      ),
    );
  }
  return LookBackSky(visible: byDay.isNotEmpty, days: List.unmodifiable(days));
}

bool _sameIds(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
