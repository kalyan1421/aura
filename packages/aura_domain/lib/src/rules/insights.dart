// F10 Insights ("Aura Sky"): RULES.md section 10 (contracts/rules/vectors/
// insights.json). Pure and on-device only: the person's own check-ins and
// habit logs go in, the sky and the plain-language patterns come out. Nothing
// here is uploaded (PRD F10, REQ-INS-02).
import 'package:meta/meta.dart';

import '../catalog.g.dart';
import '../local_day.dart';
import 'aura_day.dart';
import 'streak.dart';

// ---- inputs -------------------------------------------------------------------

/// One live (not deleted) check-in, as Insights sees it. Never holds a note.
@immutable
final class InsightCheckIn {
  const InsightCheckIn({
    required this.localDay,
    required this.quadrant,
    this.tags = const [],
    this.deviceTs,
    this.tzOffsetMinutes,
  });

  /// The stamped Aura day (never recomputed).
  final LocalDay localDay;
  final Quadrant quadrant;
  final List<String> tags;

  /// When it was made and the UTC offset it was stamped with; both are
  /// needed for its part of the day.
  final DateTime? deviceTs;
  final int? tzOffsetMinutes;

  /// The local wall clock it was stamped at, or `null` without an instant.
  DateTime? get _wallClock {
    final ts = deviceTs;
    final off = tzOffsetMinutes;
    if (ts == null || off == null) return null;
    return ts.toUtc().add(Duration(minutes: off));
  }

  /// Made on its own Aura day (not a backfill), per its stamped wall clock.
  bool get isLive {
    final wall = _wallClock;
    if (wall == null) return false;
    final shifted = wall.subtract(const Duration(hours: auraDayRolloverHour));
    return LocalDay(shifted.year, shifted.month, shifted.day) == localDay;
  }

  /// Part of the day for a live check-in; `null` otherwise.
  DayPart? get part {
    if (!isLive) return null;
    return dayPartOfHour(_wallClock!.hour);
  }
}

/// One habit completion (not deleted).
@immutable
final class InsightHabitLog {
  const InsightHabitLog({required this.habitId, required this.localDay});

  final String habitId;
  final LocalDay localDay;
}

// ---- parts of the day ----------------------------------------------------------

/// Parts of the day (local wall clock). Night spans the 04:00 rollover.
enum DayPart { morning, afternoon, evening, night }

/// `morning` 04–12 · `afternoon` 12–17 · `evening` 17–21 · `night` otherwise.
DayPart dayPartOfHour(int hour) {
  if (hour >= 4 && hour < 12) return DayPart.morning;
  if (hour >= 12 && hour < 17) return DayPart.afternoon;
  if (hour >= 17 && hour < 21) return DayPart.evening;
  return DayPart.night;
}

// ---- the sky ----------------------------------------------------------------------

/// How one day looks in the sky.
enum DayStarKind {
  /// No check-ins: plain dark sky (never grey or crossed out).
  empty,

  /// A rest day: a faint ring.
  rest,

  /// One most-frequent quadrant.
  single,

  /// A tie at the top: a split star.
  split,
}

@immutable
final class DayStar {
  const DayStar(this.kind, [this.quadrants = const []]);

  static const DayStar empty = DayStar(DayStarKind.empty);
  static const DayStar rest = DayStar(DayStarKind.rest);

  final DayStarKind kind;

  /// The most frequent quadrant(s), catalogue order; empty for empty/rest.
  final List<Quadrant> quadrants;

  @override
  bool operator ==(Object other) =>
      other is DayStar &&
      other.kind == kind &&
      _listEquals(other.quadrants, quadrants);

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(quadrants));

  @override
  String toString() => 'DayStar(${kind.name}, $quadrants)';
}

/// A day's star from its check-ins' quadrants (RULES.md §10 `day_star`).
DayStar dayStar(Iterable<Quadrant> quadrants, {bool rest = false}) {
  final counts = _quadrantCounts(quadrants);
  final top = counts.values.fold(0, (a, b) => a > b ? a : b);
  if (top == 0) return rest ? DayStar.rest : DayStar.empty;
  final tied = [
    for (final q in Quadrant.values)
      if (counts[q] == top) q,
  ];
  return DayStar(
    tied.length == 1 ? DayStarKind.single : DayStarKind.split,
    List.unmodifiable(tied),
  );
}

/// Rest days: the gap days the §7 fold bridges with banked rest days,
/// ascending (RULES.md §10 `rest_days`).
List<LocalDay> restDays(Iterable<LocalDay> activeDays) {
  final sorted = activeDays.toSet().toList()..sort();
  final out = <LocalDay>[];
  var state = StreakState.initial;
  for (final day in sorted) {
    final last = state.lastActiveDay;
    if (last != null) {
      final gap = day.daysSince(last) - 1;
      if (gap >= 1 && gap <= state.restBank) {
        for (var i = 1; i <= gap; i++) {
          out.add(last.addDays(i));
        }
      }
    }
    state = foldStreak(state, [day]);
  }
  return out;
}

// ---- weeks and months -------------------------------------------------------------

/// ISO weekday of [day] (1 = Monday … 7 = Sunday).
int isoWeekday(LocalDay day) =>
    DateTime.utc(day.year, day.month, day.day).weekday;

/// First day of [day]'s week; weeks start on [weekStartsOn] (ISO weekday).
LocalDay weekStart(LocalDay day, {int weekStartsOn = DateTime.monday}) {
  assert(weekStartsOn >= 1 && weekStartsOn <= 7, 'ISO weekday 1–7');
  return day.addDays(-((isoWeekday(day) - weekStartsOn + 7) % 7));
}

/// An inclusive range of Aura days.
@immutable
final class DayRange {
  const DayRange(this.from, this.to);

  final LocalDay from;
  final LocalDay to;

  bool contains(LocalDay day) => !day.isBefore(from) && !day.isAfter(to);

  /// Number of days in the range.
  int get length => to.daysSince(from) + 1;

  @override
  bool operator ==(Object other) =>
      other is DayRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '[$from, $to]';
}

/// The weekly card's week (RULES.md §10 `week`).
@immutable
final class WeeklyWindow {
  const WeeklyWindow({
    required this.today,
    required this.weekStart,
    required this.range,
  });

  final LocalDay today;

  /// The first Aura day of the current week (the card's day).
  final LocalDay weekStart;

  /// The week just ended, which the card describes.
  final DayRange range;
}

WeeklyWindow weeklyWindow(
  LocalDay today, {
  int weekStartsOn = DateTime.monday,
}) {
  final start = weekStart(today, weekStartsOn: weekStartsOn);
  return WeeklyWindow(
    today: today,
    weekStart: start,
    range: DayRange(start.addDays(-7), start.addDays(-1)),
  );
}

/// "Your month in stars": the month being recapped (RULES.md §10 `month`).
@immutable
final class MonthWindow {
  const MonthWindow({
    required this.today,
    required this.monthStart,
    required this.range,
  });

  final LocalDay today;

  /// The 1st of today's month (the recap's day).
  final LocalDay monthStart;

  /// The whole previous calendar month.
  final DayRange range;

  /// `YYYY-MM` of the recapped month.
  String get monthKey => range.from.toIso().substring(0, 7);
}

MonthWindow monthWindow(LocalDay today) {
  final start = LocalDay(today.year, today.month, 1);
  final to = start.addDays(-1);
  return MonthWindow(
    today: today,
    monthStart: start,
    range: DayRange(LocalDay(to.year, to.month, 1), to),
  );
}

/// The days of [year]-[month], 1st to last.
DayRange calendarMonth(int year, int month) {
  final first = LocalDay.fromDateTime(DateTime.utc(year, month, 1));
  final next = LocalDay.fromDateTime(DateTime.utc(year, month + 1, 1));
  return DayRange(first, next.addDays(-1));
}

// ---- thresholds -----------------------------------------------------------------

/// PRD F10 thresholds (`[ASSUMPTION]` there; RULES.md §10).
abstract final class InsightThresholds {
  /// Any pattern: at least this many check-ins …
  static const int minCheckIns = 7;

  /// … over at least this many distinct days.
  static const int minDays = 5;

  /// Tag and habit patterns: at least this many check-ins in the window.
  static const int minCheckInsForItems = 14;

  /// A context must span this many days, and hold this many check-ins with
  /// its quadrant; the other side needs [minOut] check-ins.
  static const int minContextDays = 3;
  static const int minSupport = 3;
  static const int minOut = 3;

  /// Care card: the last 14 Aura days.
  static const int careWindowDays = 14;
}

enum PatternGateStatus { ok, needCheckIns, needDays }

@immutable
final class PatternGate {
  const PatternGate(this.status, {required this.checkIns, required this.days});

  final PatternGateStatus status;
  final int checkIns;
  final int days;

  bool get passes => status == PatternGateStatus.ok;

  @override
  bool operator ==(Object other) =>
      other is PatternGate &&
      other.status == status &&
      other.checkIns == checkIns &&
      other.days == days;

  @override
  int get hashCode => Object.hash(status, checkIns, days);

  @override
  String toString() => 'PatternGate(${status.name}, $checkIns, $days)';
}

List<InsightCheckIn> _inRange(Iterable<InsightCheckIn> all, DayRange range) => [
  for (final c in all)
    if (range.contains(c.localDay)) c,
];

/// Whether [range] holds enough data for any pattern (RULES.md §10 `gate`).
PatternGate patternGate(Iterable<InsightCheckIn> checkIns, DayRange range) =>
    _gate(_inRange(checkIns, range));

PatternGate _gate(List<InsightCheckIn> window) {
  final n = window.length;
  final d = {for (final c in window) c.localDay}.length;
  final status = n < InsightThresholds.minCheckIns
      ? PatternGateStatus.needCheckIns
      : d < InsightThresholds.minDays
      ? PatternGateStatus.needDays
      : PatternGateStatus.ok;
  return PatternGate(status, checkIns: n, days: d);
}

// ---- patterns -----------------------------------------------------------------------

/// Pattern types, in tie-break order (the mix always comes last).
enum PatternKind { tagQuadrant, habitQuadrant, timeOfDay, quadrantMix }

/// One plain-language pattern. [key] is the tag, the habit id or the part of
/// the day's name; `null` for the quadrant mix. The UI turns it into words
/// with a translated template (never a number).
@immutable
final class InsightPattern {
  const InsightPattern(this.kind, this.quadrant, [this.key]);

  final PatternKind kind;
  final Quadrant quadrant;
  final String? key;

  /// [key] as a part of the day (time patterns only).
  DayPart? get dayPart => kind == PatternKind.timeOfDay
      ? DayPart.values.firstWhere((p) => p.name == key)
      : null;

  @override
  bool operator ==(Object other) =>
      other is InsightPattern &&
      other.kind == kind &&
      other.quadrant == quadrant &&
      other.key == key;

  @override
  int get hashCode => Object.hash(kind, quadrant, key);

  @override
  String toString() => 'InsightPattern(${kind.name}, ${quadrant.name}, $key)';
}

/// A passing contrast: lift = num / den (exact).
final class _Candidate {
  _Candidate(this.kind, this.key, this.quadrant, this.num, this.den, this.k);

  final PatternKind kind;
  final String key;
  final Quadrant quadrant;
  final int num;
  final int den;
  final int k;

  /// Negative when this one ranks first.
  int compareTo(_Candidate o) {
    final lift = num * o.den - o.num * den;
    if (lift != 0) return lift > 0 ? -1 : 1;
    if (k != o.k) return k > o.k ? -1 : 1;
    if (kind != o.kind) return kind.index.compareTo(o.kind.index);
    return key.compareTo(o.key);
  }
}

/// The best quadrant for one context (RULES.md §10 "Contrast"), or `null`.
({Quadrant quadrant, int num, int den, int k})? _contrast(
  List<InsightCheckIn> population,
  bool Function(InsightCheckIn) isIn,
) {
  final ins = <InsightCheckIn>[];
  final outs = <InsightCheckIn>[];
  for (final c in population) {
    (isIn(c) ? ins : outs).add(c);
  }
  final nIn = ins.length;
  final nOut = outs.length;
  if ({for (final c in ins) c.localDay}.length <
          InsightThresholds.minContextDays ||
      nOut < InsightThresholds.minOut) {
    return null;
  }
  final inCounts = _quadrantCounts(ins.map((c) => c.quadrant));
  final outCounts = _quadrantCounts(outs.map((c) => c.quadrant));
  ({Quadrant quadrant, int num, int den, int k})? best;
  for (final q in Quadrant.values) {
    final kIn = inCounts[q]!;
    final kOut = outCounts[q]!;
    if (kIn < InsightThresholds.minSupport) continue;
    final num = kIn * nOut - kOut * nIn;
    final den = nIn * nOut;
    if (4 * num < den) continue; // lift < 1/4
    final b = best;
    if (b == null ||
        num * b.den > b.num * den ||
        (num * b.den == b.num * den && kIn > b.k)) {
      best = (quadrant: q, num: num, den: den, k: kIn);
    }
  }
  return best;
}

/// Every pattern in [range] that passes the thresholds, strongest first
/// (RULES.md §10 `patterns`). [includeHabits] is Plus (habit × mood).
List<InsightPattern> findPatterns({
  required Iterable<InsightCheckIn> checkIns,
  Iterable<InsightHabitLog> habitLogs = const [],
  required DayRange range,
  bool includeHabits = false,
}) {
  final window = _inRange(checkIns, range);
  if (!_gate(window).passes) return const [];

  final candidates = <_Candidate>[];
  void add(
    PatternKind kind,
    String key,
    List<InsightCheckIn> population,
    bool Function(InsightCheckIn) isIn,
  ) {
    final r = _contrast(population, isIn);
    if (r != null) {
      candidates.add(_Candidate(kind, key, r.quadrant, r.num, r.den, r.k));
    }
  }

  if (window.length >= InsightThresholds.minCheckInsForItems) {
    final tags = {for (final c in window) ...c.tags}.toList()..sort();
    for (final tag in tags) {
      add(PatternKind.tagQuadrant, tag, window, (c) => c.tags.contains(tag));
    }
    if (includeHabits) {
      final daysByHabit = <String, Set<LocalDay>>{};
      for (final l in habitLogs) {
        if (!range.contains(l.localDay)) continue;
        daysByHabit.putIfAbsent(l.habitId, () => {}).add(l.localDay);
      }
      final ids = daysByHabit.keys.toList()..sort();
      for (final id in ids) {
        final days = daysByHabit[id]!;
        add(
          PatternKind.habitQuadrant,
          id,
          window,
          (c) => days.contains(c.localDay),
        );
      }
    }
  }

  final live = [
    for (final c in window)
      if (c.isLive) c,
  ];
  for (final part in DayPart.values) {
    add(PatternKind.timeOfDay, part.name, live, (c) => c.part == part);
  }

  candidates.sort((a, b) => a.compareTo(b));
  final out = [
    for (final c in candidates) InsightPattern(c.kind, c.quadrant, c.key),
  ];
  final mix = _quadrantMix(window);
  if (mix != null) out.add(mix);
  return List.unmodifiable(out);
}

InsightPattern? _quadrantMix(List<InsightCheckIn> window) {
  final counts = _quadrantCounts(window.map((c) => c.quadrant));
  final ordered = counts.values.toList()..sort((a, b) => b.compareTo(a));
  final top = ordered[0];
  final second = ordered[1];
  if (second >= top) return null;
  if (5 * top < 2 * window.length) return null;
  if (top - second < 2) return null;
  final q = Quadrant.values.firstWhere((q) => counts[q] == top);
  return InsightPattern(PatternKind.quadrantMix, q);
}

/// The weekly insight card: one pattern from the week just ended, or `null`
/// (no card). Free: [includeHabits] false (RULES.md §10 `weekly`).
InsightPattern? weeklyInsight({
  required Iterable<InsightCheckIn> checkIns,
  Iterable<InsightHabitLog> habitLogs = const [],
  required LocalDay today,
  int weekStartsOn = DateTime.monday,
  bool includeHabits = false,
}) {
  final week = weeklyWindow(today, weekStartsOn: weekStartsOn);
  final patterns = findPatterns(
    checkIns: checkIns,
    habitLogs: habitLogs,
    range: week.range,
    includeHabits: includeHabits,
  );
  return patterns.isEmpty ? null : patterns.first;
}

// ---- month in stars -------------------------------------------------------------------

@immutable
final class MonthRecap {
  const MonthRecap({
    required this.window,
    required this.checkIns,
    required this.daysCheckedIn,
    required this.quadrantCounts,
  });

  final MonthWindow window;
  final int checkIns;
  final int daysCheckedIn;

  /// Every quadrant, zero included.
  final Map<Quadrant, int> quadrantCounts;

  String get month => window.monthKey;
  DayRange get range => window.range;
}

/// "Your month in stars" for the month before [today]'s (RULES.md §10
/// `month_recap`).
MonthRecap monthRecap(Iterable<InsightCheckIn> checkIns, LocalDay today) {
  final window = monthWindow(today);
  final inMonth = _inRange(checkIns, window.range);
  return MonthRecap(
    window: window,
    checkIns: inMonth.length,
    daysCheckedIn: {for (final c in inMonth) c.localDay}.length,
    quadrantCounts: Map.unmodifiable(
      _quadrantCounts(inMonth.map((c) => c.quadrant)),
    ),
  );
}

// ---- care card --------------------------------------------------------------------------

/// "It's been a heavy couple of weeks": ≥ 80 % of ≥ 7 check-ins in the last
/// 14 Aura days are Storm or Rain (RULES.md §10 `care`). Shown in Insights
/// only; never pushed.
bool showCareCard(Iterable<InsightCheckIn> checkIns, LocalDay today) {
  final window = _inRange(
    checkIns,
    DayRange(today.addDays(-(InsightThresholds.careWindowDays - 1)), today),
  );
  if (window.length < InsightThresholds.minCheckIns) return false;
  final heavy = window
      .where((c) => c.quadrant == Quadrant.storm || c.quadrant == Quadrant.rain)
      .length;
  return 5 * heavy >= 4 * window.length;
}

// ---- helpers -------------------------------------------------------------------------------

Map<Quadrant, int> _quadrantCounts(Iterable<Quadrant> quadrants) {
  final counts = {for (final q in Quadrant.values) q: 0};
  for (final q in quadrants) {
    counts[q] = counts[q]! + 1;
  }
  return counts;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
