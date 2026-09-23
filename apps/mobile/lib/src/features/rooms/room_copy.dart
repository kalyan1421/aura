import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import 'room_models.dart';
import 'rooms_repository.dart';

/// Room theme names by wire key ("The Rain Sanctuary"). An unknown key
/// (a newer server) reads as the plain word "Rooms".
String roomThemeName(AppLocalizations l, String theme) => switch (theme) {
  'lighthouse' => l.rooms_theme_lighthouse,
  'rain_sanctuary' => l.rooms_theme_rain_sanctuary,
  'midnight_observatory' => l.rooms_theme_midnight_observatory,
  'sunrise_deck' => l.rooms_theme_sunrise_deck,
  _ => l.rooms_title,
};

String gestureName(AppLocalizations l, GestureType g) => switch (g) {
  GestureType.warmTea => l.rooms_gesture_warm_tea,
  GestureType.lightACandle => l.rooms_gesture_light_a_candle,
  GestureType.hug => l.rooms_gesture_hug,
  GestureType.meToo => l.rooms_gesture_me_too,
  GestureType.softRain => l.rooms_gesture_soft_rain,
  GestureType.stargaze => l.rooms_gesture_stargaze,
  GestureType.deepBreath => l.rooms_gesture_deep_breath,
  GestureType.youreNotAlone => l.rooms_gesture_youre_not_alone,
};

/// One quiet line-art icon per gesture (the name is always shown too).
IconData gestureIcon(GestureType g) => switch (g) {
  GestureType.warmTea => Icons.emoji_food_beverage_outlined,
  GestureType.lightACandle => Icons.local_fire_department_outlined,
  GestureType.hug => Icons.volunteer_activism_outlined,
  GestureType.meToo => Icons.back_hand_outlined,
  GestureType.softRain => Icons.water_drop_outlined,
  GestureType.stargaze => Icons.auto_awesome_outlined,
  GestureType.deepBreath => Icons.air_rounded,
  GestureType.youreNotAlone => Icons.favorite_border_rounded,
};

String reportReasonLabel(AppLocalizations l, ReportReason r) => switch (r) {
  ReportReason.inDanger => l.rooms_reason1,
  ReportReason.harassment => l.rooms_reason2,
  ReportReason.sexual => l.rooms_reason3,
  ReportReason.hate => l.rooms_reason4,
  ReportReason.contactInfo => l.rooms_reason5,
  ReportReason.spam => l.rooms_reason6,
  ReportReason.under13 => l.rooms_reason7,
  ReportReason.targetingYoungPerson => l.rooms_reason9,
  ReportReason.other => l.rooms_reason8,
};

/// A member's mood chip in the reader's language (the server sends the
/// catalogue id). Empty for an id this build doesn't know.
String moodChipName(String moodId, String localeTag) =>
    moodById(moodId)?.nameFor(localeTag) ?? '';

/// The intl locale for dates: romanized locales use English month names
/// (like the DOB picker and account dates).
String _dateLocale(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return locale.scriptCode == 'Latn' ? 'en' : locale.languageCode;
}

/// "11:40 PM" in the reader's language and time zone.
String roomTime(BuildContext context, DateTime instant) {
  final local = instant.toLocal();
  try {
    return DateFormat.jm(_dateLocale(context)).format(local);
  } on Object {
    return DateFormat.jm('en').format(local);
  }
}

/// "15 Oct" in the reader's language.
String roomDate(BuildContext context, DateTime instant) {
  final local = instant.toLocal();
  try {
    return DateFormat.MMMd(_dateLocale(context)).format(local);
  } on Object {
    return DateFormat.MMMd('en').format(local);
  }
}

/// Calm, blame-free words for a rooms failure. [joining]: after a check-in
/// ("Your check-in is saved").
String roomsFailureText(
  AppLocalizations l,
  RoomsFailure f, {
  bool joining = false,
  bool opening = false,
}) => switch (f.kind) {
  RoomsFailureKind.offline =>
    joining
        ? l.rooms_offlineJoin
        : opening
        ? l.rooms_offlineRoom
        : l.rooms_offline,
  RoomsFailureKind.signedOut => l.rooms_signedOut,
  RoomsFailureKind.profileRequired => l.rooms_profilePending,
  RoomsFailureKind.suspended => l.rooms_suspended,
  RoomsFailureKind.closed => l.rooms_accountClosed,
  RoomsFailureKind.joinLimit => l.rooms_joinLimit,
  RoomsFailureKind.poolUnavailable => l.rooms_poolUnavailable,
  RoomsFailureKind.notFound => l.rooms_gone,
  RoomsFailureKind.reportLimit => l.rooms_reportLimit,
  _ => joining ? l.rooms_joinFailed : l.rooms_loadFailed,
};
