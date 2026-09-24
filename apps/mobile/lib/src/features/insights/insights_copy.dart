import 'package:aura_domain/aura_domain.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/l10n/locale_controller.dart';
import '../checkin/quadrant_glyph.dart' show habitLabel, quadrantName, tagLabel;

/// A pattern in words: one whole translated template per pattern type, the
/// quadrant and item filled in (never assembled from pieces, never a
/// number). REQ-INS-03: `test/insights_copy_lint_test.dart` checks the
/// templates.
String patternSentence(
  AppLocalizations l,
  InsightPattern p, {
  Map<String, HabitRow> habits = const {},
}) {
  final q = quadrantName(l, p.quadrant);
  return switch (p.kind) {
    PatternKind.tagQuadrant => l.insights_patternTag(tagLabel(l, p.key!), q),
    PatternKind.habitQuadrant => l.insights_patternHabit(
      habitName(l, habits[p.key]),
      q,
    ),
    PatternKind.timeOfDay => switch (p.dayPart!) {
      DayPart.morning => l.insights_patternMorning(q),
      DayPart.afternoon => l.insights_patternAfternoon(q),
      DayPart.evening => l.insights_patternEvening(q),
      DayPart.night => l.insights_patternNight(q),
    },
    PatternKind.quadrantMix => l.insights_patternMix(q),
  };
}

/// A habit's name: the preset's label or the person's own name for it.
String habitName(AppLocalizations l, HabitRow? habit) {
  if (habit == null) return '';
  final preset = habit.presetKey;
  return preset != null ? habitLabel(l, preset) : (habit.name ?? '');
}

/// Screen-reader label of one day in the sky (REQ-A11Y-10: never colour
/// alone).
String daySemantics(AppLocalizations l, String date, DayStar star, int count) =>
    switch (star.kind) {
      DayStarKind.empty => l.insights_dayEmpty(date),
      DayStarKind.rest => l.insights_dayRest(date),
      DayStarKind.single => l.insights_daySingle(
        date,
        quadrantName(l, star.quadrants.single),
        count,
      ),
      DayStarKind.split when star.quadrants.length == 2 => l.insights_dayPair(
        date,
        quadrantName(l, star.quadrants[0]),
        quadrantName(l, star.quadrants[1]),
        count,
      ),
      DayStarKind.split => l.insights_dayMixed(date, count),
    };

String _intlLocale(String localeTag) {
  final locale = localeFromTag(localeTag);
  // Romanized locales read dates in English (as history does).
  return locale.scriptCode == 'Latn' ? 'en' : locale.languageCode;
}

String _format(String localeTag, DateFormat Function(String) make, DateTime d) {
  try {
    return make(_intlLocale(localeTag)).format(d);
  } catch (_) {
    return make('en').format(d);
  }
}

/// "October 2026".
String monthYearLabel(String localeTag, int year, int month) =>
    _format(localeTag, DateFormat.yMMMM, DateTime(year, month));

/// "October" (year view tiles).
String monthLabel(String localeTag, int month) =>
    _format(localeTag, DateFormat.MMMM, DateTime(2000, month));

/// "Thursday, 8 October" (screen-reader day labels).
String dayLabel(String localeTag, LocalDay day) => _format(
  localeTag,
  DateFormat.MMMMEEEEd,
  DateTime(day.year, day.month, day.day),
);

/// Narrow weekday initials, starting Monday ("M", "T", …).
List<String> weekdayInitials(String localeTag) {
  // 5 Oct 2026 is a Monday.
  return [
    for (var i = 0; i < 7; i++)
      _format(localeTag, DateFormat.E, DateTime(2026, 10, 5 + i)),
  ];
}
