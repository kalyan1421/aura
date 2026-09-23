import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/l10n/locale_controller.dart';

/// Day header for an Aura day: "Today", "Yesterday", else a localized date
/// ("Thursday, 8 October"; with the year when it isn't this year).
String historyDayLabel(
  AppLocalizations l,
  String localeTag,
  LocalDay day,
  LocalDay today,
) {
  if (day == today) return l.history_today;
  if (day == today.addDays(-1)) return l.history_yesterday;
  return dateLabel(localeTag, day, today);
}

/// A localized date for an Aura day, never "Today"/"Yesterday" ("Thursday,
/// 8 October"; with the year when it isn't [today]'s year).
String dateLabel(String localeTag, LocalDay day, LocalDay today) {
  final date = DateTime(day.year, day.month, day.day);
  final locale = localeFromTag(localeTag);
  // Romanized locales read dates in English (as the DOB picker does).
  final intlLocale = locale.scriptCode == 'Latn' ? 'en' : locale.languageCode;
  DateFormat format(String loc) => day.year == today.year
      ? DateFormat.MMMMEEEEd(loc)
      : DateFormat.yMMMMEEEEd(loc);
  try {
    return format(intlLocale).format(date);
  } catch (_) {
    return format('en').format(date);
  }
}

/// Whether [row] was added later for a past day (F1 backfill): its Aura day
/// isn't the one it was made on (RULES.md §2), judged in the zone it was
/// stamped in. Rows pulled from the server carry no zone: [fallbackTz]
/// (the device's) is used, so a traveller's pulled row made near 04:00 in
/// another zone can read as added later.
bool isBackfillRow(CheckInRow row, String fallbackTz) =>
    LocalDay.tryParse(row.localDay) !=
    auraDay(row.deviceTs, row.tz ?? fallbackTz);

/// Wall-clock time the check-in was made, in the zone it was stamped in
/// (rows pulled from the server carry no zone: [fallbackTz] is used).
String historyTimeLabel(
  BuildContext context,
  CheckInRow row,
  String fallbackTz,
) {
  final utc = row.deviceTs.toUtc();
  final offset = row.tz != null
      ? Duration(minutes: row.tzOffsetMinutes)
      : utcOffsetAt(utc, fallbackTz);
  final wall = utc.add(offset);
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: wall.hour, minute: wall.minute),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}
