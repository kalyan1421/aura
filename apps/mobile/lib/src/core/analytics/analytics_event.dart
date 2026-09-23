import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';

import 'analytics_schema.dart';

/// One product-analytics event: a schema name and its properties.
///
/// Build events with the typed constructors below: they take enums, bools
/// and counts only, so a call site can't pass a note, a title or a name.
/// Whatever reaches the service still goes through the privacy filter
/// (analytics_privacy.dart), which drops anything the schema doesn't allow.
@immutable
class AnalyticsEvent {
  const AnalyticsEvent._(this.name, this.properties);

  /// Any name and properties, for tests of the privacy filter. Never use it
  /// in app code: the typed constructors are the only API.
  @visibleForTesting
  const AnalyticsEvent.raw(this.name, this.properties);

  final String name;
  final Map<String, Object?> properties;

  // ---- F8 onboarding & account ----------------------------------------------

  factory AnalyticsEvent.onboardingStarted({
    OnboardingEntry entry = OnboardingEntry.organic,
  }) => AnalyticsEvent._(AnalyticsEvents.onboardingStarted, {
    'entry': entry.name,
  });

  factory AnalyticsEvent.languageSelected({
    required String language,
    required String fromLanguage,
    required AnalyticsSurface surface,
    required bool changedFromDefault,
  }) => AnalyticsEvent._(AnalyticsEvents.languageSelected, {
    'language': language,
    'from_language': fromLanguage,
    'surface': surface.name,
    'changed_from_default': changedFromDefault,
  });

  /// DOB submitted. Only ever reaches PostHog for 18+ (the gate drops it
  /// otherwise), as the PRD specifies.
  factory AnalyticsEvent.ageGateCompleted() =>
      const AnalyticsEvent._(AnalyticsEvents.ageGateCompleted, {});

  factory AnalyticsEvent.onboardingStepCompleted({
    required OnboardingStep step,
    required Duration duration,
  }) => AnalyticsEvent._(AnalyticsEvents.onboardingStepCompleted, {
    'step': step.wire,
    'step_index': step.index,
    'duration_ms': _ms(duration),
  });

  factory AnalyticsEvent.accountCreated(AuthMethod method) =>
      AnalyticsEvent._(AnalyticsEvents.accountCreated, {
        'auth_method': method.name,
      });

  factory AnalyticsEvent.onboardingCompleted({
    required bool firstCheckinDone,
    Duration? totalDuration,
  }) => AnalyticsEvent._(AnalyticsEvents.onboardingCompleted, {
    'first_checkin_done': firstCheckinDone,
    if (totalDuration != null) 'total_duration_ms': _ms(totalDuration),
  });

  factory AnalyticsEvent.accountDeletionRequested() =>
      const AnalyticsEvent._(AnalyticsEvents.accountDeletionRequested, {});

  // ---- F1 check-in, F2 ---------------------------------------------------------

  factory AnalyticsEvent.checkinStarted(CheckInSource source) =>
      AnalyticsEvent._(AnalyticsEvents.checkinStarted, {'source': source.name});

  /// Quadrant only, never the mood; tags as a count; note and voice as
  /// yes/no (PRD principles 2 and 3).
  factory AnalyticsEvent.checkinCompleted({
    required Quadrant quadrant,
    required int tagCount,
    required bool hasNote,
    required bool hasVoice,
    required Duration duration,
    required CheckInSource source,
    required bool isOffline,
    required bool isBackfill,
    required bool promptShown,
  }) => AnalyticsEvent._(AnalyticsEvents.checkinCompleted, {
    'quadrant': quadrant.name,
    'tag_count': tagCount,
    'has_note': hasNote,
    'has_voice': hasVoice,
    'duration_ms': _ms(duration),
    'source': source.name,
    'is_offline': isOffline,
    'is_backfill': isBackfill,
    'prompt_shown': promptShown,
  });

  factory AnalyticsEvent.checkinAbandoned({required bool moodPicked}) =>
      AnalyticsEvent._(AnalyticsEvents.checkinAbandoned, {
        'reached_step': moodPicked ? 'mood' : 'none',
      });

  factory AnalyticsEvent.companionResponseShown({
    required Quadrant quadrant,
    required bool reducedMotion,
    required CompanionMoment moment,
  }) => AnalyticsEvent._(AnalyticsEvents.companionResponseShown, {
    'quadrant': quadrant.name,
    'motion': reducedMotion ? 'still' : 'full',
    'moment': moment.name,
  });

  /// [presetKey]: a preset habit's key, or `null` for a custom habit (sent
  /// as `custom`: never its name).
  factory AnalyticsEvent.habitLogged({
    required String? presetKey,
    bool isBackfill = false,
  }) => AnalyticsEvent._(AnalyticsEvents.habitLogged, {
    'habit_key': presetKey ?? 'custom',
    'is_backfill': isBackfill,
  });

  factory AnalyticsEvent.avatarRestChanged({
    required bool resting,
    required int daysAway,
  }) => AnalyticsEvent._(AnalyticsEvents.avatarRestChanged, {
    'state': resting ? 'resting' : 'woke',
    'days_away': daysAway,
  });

  // ---- F4 capsules ---------------------------------------------------------------

  /// [horizonDays]: days from sealing to a date capsule's unlock day (none
  /// for a mood capsule). Never the date, the title, the words or the
  /// target mood.
  factory AnalyticsEvent.capsuleSealed({
    required bool dateUnlock,
    bool? quadrantScope,
    int? horizonDays,
    required bool hasVoice,
    required int photoCount,
    required bool promptShown,
  }) => AnalyticsEvent._(AnalyticsEvents.capsuleSealed, {
    'unlock_type': dateUnlock ? 'date' : 'mood',
    if (!dateUnlock && quadrantScope != null)
      'trigger_scope': quadrantScope ? 'quadrant' : 'mood',
    if (horizonDays != null) 'horizon_bucket': dayBucket(horizonDays),
    'has_voice': hasVoice,
    'photo_count': photoCount,
    'prompt_shown': promptShown,
  });

  factory AnalyticsEvent.capsuleUnlocked({
    required bool dateUnlock,
    required int daysSealed,
    required bool isOffline,
  }) => AnalyticsEvent._(AnalyticsEvents.capsuleUnlocked, {
    'unlock_type': dateUnlock ? 'date' : 'mood',
    'days_sealed_bucket': dayBucket(daysSealed),
    'is_offline': isOffline,
  });

  factory AnalyticsEvent.capsuleOpened({required bool ceremonyCompleted}) =>
      AnalyticsEvent._(AnalyticsEvents.capsuleOpened, {
        'ceremony_completed': ceremonyCompleted,
      });

  // ---- F5 rooms, F9 safety ------------------------------------------------------

  factory AnalyticsEvent.roomOfferShown({
    required Quadrant quadrant,
    required bool isLanternHour,
    required String uiLocale,
  }) => AnalyticsEvent._(AnalyticsEvents.roomOfferShown, {
    'quadrant': quadrant.name,
    'is_lantern_hour': isLanternHour,
    'language_pool': languagePoolFor(uiLocale),
  });

  /// [membersHere]: people in the room now (a bucket is sent). Never a room
  /// id, a pseudonym or a member id.
  factory AnalyticsEvent.roomJoined({
    required Quadrant quadrant,
    required RoomEntry entry,
    required int membersHere,
    required bool coldStartMerged,
    required String uiLocale,
    required Duration utcOffset,
  }) => AnalyticsEvent._(AnalyticsEvents.roomJoined, {
    'quadrant': quadrant.name,
    'entry': entry.wire,
    'members_bucket': membersBucket(membersHere),
    'cold_start_merged': coldStartMerged,
    'language_pool': languagePoolFor(uiLocale),
    'tz_region': tzRegionFor(utcOffset),
  });

  factory AnalyticsEvent.roomLeft({
    required Duration dwell,
    required int gesturesSent,
  }) => AnalyticsEvent._(AnalyticsEvents.roomLeft, {
    'dwell_s': dwell.inSeconds.clamp(0, 24 * 60 * 60),
    'gestures_sent': gesturesSent.clamp(0, 1000),
  });

  /// [gesture]: the gesture's wire key (`warm_tea`, …).
  factory AnalyticsEvent.gestureSent({
    required String gesture,
    required GestureTargetKind target,
    GestureSurface surface = GestureSurface.room,
  }) => AnalyticsEvent._(AnalyticsEvents.gestureSent, {
    'gesture': gesture,
    'target': target.name,
    'surface': surface.name,
  });

  /// [answer]: `yes`, `no` or `skip`.
  factory AnalyticsEvent.roomSurveyAnswered(String answer) =>
      AnalyticsEvent._(AnalyticsEvents.roomSurveyAnswered, {'answer': answer});

  /// [reason]: the report reason's key (`harassment`, …; `none` for block
  /// and mute).
  factory AnalyticsEvent.safetyActionTaken({
    required SafetyActionKind action,
    required SafetySurface surface,
    String reason = 'none',
  }) => AnalyticsEvent._(AnalyticsEvents.safetyActionTaken, {
    'action': action.name,
    'surface': surface.name,
    'reason': reason,
  });

  // ---- F15 Sanctuary -------------------------------------------------------------

  factory AnalyticsEvent.sanctuaryActivityStarted({
    required SanctuaryKind activity,
    required SanctuaryVariant variant,
    required SanctuaryEntry entry,
  }) => AnalyticsEvent._(AnalyticsEvents.sanctuaryActivityStarted, {
    'activity': activity.wire,
    'variant': variant.wire,
    'entry': entry.wire,
  });

  factory AnalyticsEvent.sanctuaryActivityEnded({
    required SanctuaryKind activity,
    required SanctuaryVariant variant,
    required Duration duration,
    required bool completed,
    required bool habitLogged,
  }) => AnalyticsEvent._(AnalyticsEvents.sanctuaryActivityEnded, {
    'activity': activity.wire,
    'variant': variant.wire,
    'duration_bucket': durationBucket(duration),
    'completed': completed,
    'habit_logged': habitLogged,
  });

  // ---- F14 notifications -------------------------------------------------------

  factory AnalyticsEvent.notificationPermissionResult(
    NotificationPermissionResult result,
  ) => AnalyticsEvent._(AnalyticsEvents.notificationPermissionResult, {
    'result': result.name,
  });

  factory AnalyticsEvent.notificationOpened(NotificationKind type) =>
      AnalyticsEvent._(AnalyticsEvents.notificationOpened, {
        'type': type.wire,
      });

  factory AnalyticsEvent.notificationSettingChanged(
    NotificationSetting setting, {
    bool? enabled,
  }) => AnalyticsEvent._(AnalyticsEvents.notificationSettingChanged, {
    'setting': setting.wire,
    'enabled': ?enabled,
  });

  @override
  String toString() => 'AnalyticsEvent($name)';
}

// ---- value types -----------------------------------------------------------------

enum OnboardingEntry { organic, deeplink }

enum AnalyticsSurface { onboarding, settings }

/// Onboarding steps in order; [index] is the PRD's `step_index`.
enum OnboardingStep {
  welcome('welcome'),
  trust('trust'),
  dob('dob'),
  language('language'),
  signIn('sign_in'),
  firstCheckin('first_checkin');

  const OnboardingStep(this.wire);

  final String wire;
}

enum AuthMethod { apple, google, email, phone }

enum CheckInSource { home, widget, notification, onboarding }

enum CompanionMoment { none, wake, evolve }

enum RoomEntry {
  checkinOffer('checkin_offer'),
  roomsTab('rooms_tab'),
  yourRooms('your_rooms'),
  notification('notification');

  const RoomEntry(this.wire);

  final String wire;
}

enum GestureTargetKind { member, reflection, room, session }

enum GestureSurface { room, game, quiet }

enum SafetyActionKind { report, block, mute }

/// Where a report, block or mute was made.
enum SafetySurface { member, gesture, room }

enum SanctuaryKind {
  breathe('breathe'),
  grounding('grounding'),
  stillness('stillness'),
  savour('savour'),
  sounds('sounds'),
  nightWindDown('night_wind_down');

  const SanctuaryKind(this.wire);

  final String wire;
}

enum SanctuaryVariant {
  calm('calm'),
  box('box'),
  fourSevenEight('4_7_8'),
  senses('5_4_3_2_1'),
  handOnHeart('hand_on_heart'),
  gratitude('gratitude'),
  mix('mix'),
  none('none');

  const SanctuaryVariant(this.wire);

  final String wire;
}

/// How a Sanctuary activity was opened. Never a support-sheet or Safety
/// Center value.
enum SanctuaryEntry {
  sanctuary('sanctuary'),
  todaysMinute('todays_minute'),
  minuteForYou('minute_for_you'),
  windDownReminder('wind_down_reminder');

  const SanctuaryEntry(this.wire);

  final String wire;
}

enum NotificationPermissionResult { granted, denied, provisional }

enum NotificationKind {
  reminder('reminder'),
  capsule('capsule'),
  room('room'),
  lanternHour('lantern_hour'),
  windDown('wind_down'),
  trialEnding('trial_ending');

  const NotificationKind(this.wire);

  final String wire;
}

enum NotificationSetting {
  master('master'),
  reminder('reminder'),
  reminderTime('reminder_time'),
  reminderInQuietHours('reminder_in_quiet_hours'),
  capsule('capsule'),
  quietHours('quiet_hours'),
  discreet('discreet');

  const NotificationSetting(this.wire);

  final String wire;
}

// ---- buckets (pure) -----------------------------------------------------------------

int _ms(Duration d) => d.inMilliseconds < 0 ? 0 : d.inMilliseconds;

/// A span of days as a bucket (capsule horizon, days sealed).
String dayBucket(int days) {
  if (days < 7) return 'lt_1w';
  if (days < 30) return '1w_1m';
  if (days < 90) return '1m_3m';
  if (days < 182) return '3m_6m';
  if (days < 365) return '6m_1y';
  if (days < 730) return '1y_2y';
  return '2y_plus';
}

/// PRD `duration_bucket`: < 30 s / 30–59 s / 1–3 / 3–10 / 10–30 / 30+ min.
String durationBucket(Duration d) {
  final s = d.inSeconds;
  if (s < 30) return 'lt_30s';
  if (s < 60) return '30_59s';
  if (s < 3 * 60) return '1_3m';
  if (s < 10 * 60) return '3_10m';
  if (s < 30 * 60) return '10_30m';
  return '30m_plus';
}

/// People in a room now, as a bucket (a room holds at most 24).
String membersBucket(int n) {
  if (n <= 1) return '1';
  if (n <= 3) return '2_3';
  if (n <= 7) return '4_7';
  if (n <= 15) return '8_15';
  return '16_24';
}

/// PRD `signup_age_bucket`: 0, 1, 2–7, 8–30, 31+ days since signup.
String signupAgeBucket(int days) {
  if (days <= 0) return '0';
  if (days == 1) return '1';
  if (days <= 7) return '2_7';
  if (days <= 30) return '8_30';
  return '31_plus';
}

/// The room language pool of a UI language (PRD `language_pool`).
String languagePoolFor(String uiLocale) =>
    switch (AuraLocales.languagePool(uiLocale)) {
      'te' => 'te_tenglish',
      'hi' => 'hi_hinglish',
      _ => 'en',
    };

/// The room timezone region of a UTC offset (PRD F5 "Timezone regions"):
/// americas ≤ -2:30 · europe_africa -2:00 to +3:00 · south_asia +3:30 to
/// +6:30 · east_asia_pacific ≥ +7:00.
String tzRegionFor(Duration offset) {
  final m = offset.inMinutes;
  if (m <= -150) return 'americas';
  if (m <= 180) return 'europe_africa';
  if (m < 420) return 'south_asia';
  return 'east_asia_pacific';
}

/// Lantern Hour is 21:00–23:00 on the local clock (F5).
bool isLanternHourAt(DateTime local) => local.hour >= 21 && local.hour < 23;
