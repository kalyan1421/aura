import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../history/history_providers.dart';
import '../progress/progress_view.dart';

// F10 Insights reads only the person's own rows from Drift and works it out
// here, on the phone (PRD F10 "computed on device and never uploaded",
// REQ-INS-02). Nothing in this feature talks to the network. Written by
// hand: `CheckInRow`/`HabitRow` are Drift-generated types.

/// The Aura day now, in the phone's current zone (04:00 rollover; ticks with
/// [nowProvider]).
final insightsTodayProvider = Provider.autoDispose<LocalDay>((ref) {
  final time = ref.watch(timeContextProvider);
  return time.dayOf(ref.watch(nowProvider).value ?? time.now());
});

/// Habit completions (not deleted), for habit × mood (Plus).
final insightsHabitLogsProvider =
    StreamProvider.autoDispose<List<InsightHabitLog>>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final query = db.select(db.habitLogs)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.localDay)]);
      return query.watch().map(
        (rows) => [
          for (final r in rows)
            if (LocalDay.tryParse(r.localDay) case final day?)
              InsightHabitLog(habitId: r.habitId, localDay: day),
        ],
      );
    });

/// Habits by id, to name a habit pattern (preset label or custom name).
final insightsHabitsProvider =
    StreamProvider.autoDispose<Map<String, HabitRow>>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return db
          .select(db.habits)
          .watch()
          .map((rows) => {for (final r in rows) r.id: r});
    });

/// Rest days for the sky's faint rings: the gaps the glow-streak fold
/// bridges (RULES.md §10 `rest_days`). Active days are check-in and habit
/// days made on their own Aura day (deleted ones too: deleting keeps glow
/// days), judged in the zone each was stamped in.
final insightsRestDaysProvider = Provider.autoDispose<Set<LocalDay>>((ref) {
  final events = ref.watch(progressEventsProvider).value ?? const [];
  final tz = ref.watch(timeContextProvider).timezone;
  final active = [
    for (final e in events)
      if (auraDay(e.deviceTs, e.timezone ?? tz) == e.localDay) e.localDay,
  ];
  return restDays(active).toSet();
});

/// A check-in as the Insights rules see it: no note, no id. Rows pulled from
/// the server carry no zone (their offset is not the one they were made
/// in), so they have no part of the day and stay out of time patterns.
InsightCheckIn? insightCheckInOf(CheckInRow row) {
  final day = LocalDay.tryParse(row.localDay);
  final quadrant =
      moodById(row.moodId)?.quadrant ?? quadrantByName(row.quadrant);
  if (day == null || quadrant == null) return null;
  final stamped = row.tz != null;
  return InsightCheckIn(
    localDay: day,
    quadrant: quadrant,
    tags: row.tags,
    deviceTs: stamped ? row.deviceTs : null,
    tzOffsetMinutes: stamped ? row.tzOffsetMinutes : null,
  );
}

/// Everything the Aura Sky shows, from local data.
class InsightsModel {
  InsightsModel({
    required this.loaded,
    required this.today,
    required this.rows,
    required this.habitLogs,
    required this.restDays,
  }) {
    for (final r in rows) {
      final c = insightCheckInOf(r);
      if (c == null) continue;
      checkIns.add(c);
      byDay.putIfAbsent(c.localDay, () => []).add(r);
    }
  }

  /// False until the first local read (a blink at most).
  final bool loaded;
  final LocalDay today;

  /// Live check-ins, newest first (deleted entries leave the sky).
  final List<CheckInRow> rows;
  final List<InsightHabitLog> habitLogs;
  final Set<LocalDay> restDays;

  final List<InsightCheckIn> checkIns = [];
  final Map<LocalDay, List<CheckInRow>> byDay = {};

  bool get isEmpty => checkIns.isEmpty;

  /// The star of [day] (RULES.md §10 `day_star`).
  DayStar starOf(LocalDay day) {
    final rows = byDay[day];
    if (rows == null) {
      return restDays.contains(day) ? DayStar.rest : DayStar.empty;
    }
    return dayStar([
      for (final r in rows)
        if (insightCheckInOf(r) case final c?) c.quadrant,
    ]);
  }

  /// Distinct days with a check-in in [range].
  int daysIn(DayRange range) =>
      byDay.keys.where((d) => range.contains(d)).length;

  /// The first month with data (or this month), for navigation bounds.
  LocalDay get firstDay => byDay.keys.isEmpty
      ? today
      : byDay.keys.reduce((a, b) => a.isBefore(b) ? a : b);
}

final insightsModelProvider = Provider.autoDispose<InsightsModel>((ref) {
  final rows = ref.watch(historyEntriesProvider);
  return InsightsModel(
    loaded: rows.hasValue,
    today: ref.watch(insightsTodayProvider),
    rows: rows.value ?? const [],
    habitLogs: ref.watch(insightsHabitLogsProvider).value ?? const [],
    restDays: ref.watch(insightsRestDaysProvider),
  );
});

// ---- device-local "hide" state ----------------------------------------------
//
// Hiding a card is a property of this phone (PRD F10 says nothing about
// syncing it), kept in the encrypted key/value table. It belongs to the
// signed-in person, so sign-out wipes it with everything else.

abstract final class InsightsKeys {
  /// The week start (`YYYY-MM-DD`) whose weekly card was hidden.
  static const String weeklyHidden = 'insights.weekly_hidden';

  /// The month (`YYYY-MM`) whose recap card was hidden.
  static const String monthHidden = 'insights.month_hidden';

  /// The Aura day the care card was set aside ("Not now") on.
  static const String careHidden = 'insights.care_hidden';
}

final insightsHiddenProvider = StreamProvider.autoDispose
    .family<String?, String>(
      (ref, key) => ref.watch(kvStoreProvider).watch(key),
    );

// ---- pattern range (Plus: any range) -----------------------------------------

/// Pattern windows. Free always uses [days30] (PRD F10 "30-day patterns");
/// the others are Aura Plus ("any range").
enum InsightRange { days7, days30, days90, days365, all }

class InsightRangeNotifier extends Notifier<InsightRange> {
  @override
  InsightRange build() => InsightRange.days30;

  void set(InsightRange range) => state = range;
}

final insightRangeProvider =
    NotifierProvider.autoDispose<InsightRangeNotifier, InsightRange>(
      InsightRangeNotifier.new,
    );

/// The Aura days a range covers, ending [today].
DayRange rangeDays(InsightRange range, LocalDay today, LocalDay firstDay) =>
    switch (range) {
      InsightRange.days7 => DayRange(today.addDays(-6), today),
      InsightRange.days30 => DayRange(today.addDays(-29), today),
      InsightRange.days90 => DayRange(today.addDays(-89), today),
      InsightRange.days365 => DayRange(today.addDays(-364), today),
      InsightRange.all => DayRange(
        firstDay.isBefore(today) ? firstDay : today,
        today,
      ),
    };
