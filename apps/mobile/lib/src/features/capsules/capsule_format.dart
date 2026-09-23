import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/l10n/locale_controller.dart';
import '../checkin/quadrant_glyph.dart' show quadrantName;
import 'capsule_payload.dart';
import 'capsule_repository.dart';

/// intl locale for a UI locale tag: romanized locales read dates in English
/// (as elsewhere in the app).
String _intlLocale(String localeTag) {
  final l = localeFromTag(localeTag);
  return l.scriptCode == 'Latn' ? 'en' : l.languageCode;
}

/// A capsule date like "12 Oct 2027" (PRD 14-states).
String capsuleDateLabel(String localeTag, LocalDay day) {
  final date = DateTime(day.year, day.month, day.day);
  try {
    return DateFormat('d MMM y', _intlLocale(localeTag)).format(date);
  } on Object {
    return DateFormat('d MMM y', 'en').format(date);
  }
}

/// The wall-clock date of [instant] in [tz] ("8 Oct 2026").
String capsuleDayOf(String localeTag, DateTime instant, String tz) =>
    capsuleDateLabel(localeTag, calendarDateOf(instant, tz));

/// "12 Oct 2027, 6:00 PM" for [instant] in [tz].
String capsuleMomentLabel(
  BuildContext context,
  String localeTag,
  DateTime instant,
  String tz,
) {
  final local = instant.toUtc().add(utcOffsetAt(instant, tz));
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: local.hour, minute: local.minute),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '${capsuleDayOf(localeTag, instant, tz)}, $time';
}

/// 10:00 in the current locale's clock ("10:00 AM").
String capsuleUnlockTimeLabel(BuildContext context) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      const TimeOfDay(hour: capsuleUnlockHour, minute: 0),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// A trigger target as words: a mood's name, or "Any Storm feeling".
String feelingLabel(AppLocalizations l, String localeTag, MoodUnlock target) {
  final mood = target.moodId == null ? null : moodById(target.moodId!);
  if (mood != null) return mood.nameFor(localeTag);
  final q = target.quadrant;
  return q == null ? '' : l.capsules_anyQuadrant(quadrantName(l, q));
}

/// The name a capsule shows: its title, else "A capsule from 8 Oct 2026",
/// or "A sealed capsule" while this phone can't read it.
String capsuleTitleOf(
  AppLocalizations l,
  String localeTag,
  CapsuleRow row,
  CapsulePayload? payload,
  String tz,
) {
  if (payload == null) {
    return row.payloadCt == null && row.payloadClear == null
        ? l.capsules_untitled(capsuleDayOf(localeTag, row.sealedAt, tz))
        : l.capsules_lockedTitle;
  }
  final title = payload.title.trim();
  return title.isNotEmpty
      ? title
      : l.capsules_untitled(capsuleDayOf(localeTag, row.sealedAt, tz));
}
