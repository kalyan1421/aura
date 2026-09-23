/// The one Dart schema of Aura's product-analytics events (PRD
/// 13-analytics "Explicit events only": events are declared in one Dart
/// schema; properties are enums, booleans, counts or buckets).
///
/// Every event the app may send is listed in [analyticsSchema] with the only
/// properties it may carry. The privacy filter (analytics_privacy.dart)
/// drops any event that isn't listed and any property that isn't listed for
/// its event or whose value doesn't match its spec, so a future caller can't
/// leak a note, a capsule's words, a date of birth, an email or a pseudonym
/// by adding a property. There is deliberately no free-text string spec:
/// test/analytics_privacy_test.dart fails the build if one appears.
///
/// Names and properties follow the PRD taxonomy exactly. Where the PRD names
/// an event without listing its values, the values here are the ones this
/// build can produce (see docs/setup/analytics.md "Derived names").
library;

import 'package:flutter/foundation.dart';

/// What one property may hold.
@immutable
sealed class PropSpec {
  const PropSpec();

  /// Whether [value] may be sent.
  bool accepts(Object? value);
}

/// One value from a closed set of strings.
final class EnumProp extends PropSpec {
  const EnumProp(this.values);

  final Set<String> values;

  @override
  bool accepts(Object? value) => value is String && values.contains(value);
}

/// `true` / `false`.
final class BoolProp extends PropSpec {
  const BoolProp();

  @override
  bool accepts(Object? value) => value is bool;
}

/// A bounded whole number: a count, a duration in ms or s.
final class IntProp extends PropSpec {
  const IntProp({this.min = 0, required this.max});

  final int min;
  final int max;

  @override
  bool accepts(Object? value) => value is int && value >= min && value <= max;
}

/// A short machine code with a fixed shape (an ISO country code, the app
/// version). Anchored pattern, at most [maxLength] characters, so it can't
/// carry words.
final class CodeProp extends PropSpec {
  const CodeProp(this.pattern, {required this.maxLength});

  /// Anchored (`^…$`); checked by test/analytics_privacy_test.dart.
  final String pattern;
  final int maxLength;

  @override
  bool accepts(Object? value) =>
      value is String &&
      value.length <= maxLength &&
      RegExp(pattern).hasMatch(value);
}

/// Event names (PRD 13-analytics taxonomy; source C = client).
abstract final class AnalyticsEvents {
  // F8 onboarding & account
  static const String onboardingStarted = 'onboarding_started';
  static const String languageSelected = 'language_selected';
  static const String ageGateCompleted = 'age_gate_completed';
  static const String onboardingStepCompleted = 'onboarding_step_completed';
  static const String accountCreated = 'account_created';
  static const String onboardingCompleted = 'onboarding_completed';

  /// Derived (not in the PRD taxonomy): Settings → Delete my account was
  /// confirmed and the server scheduled the deletion.
  static const String accountDeletionRequested = 'account_deletion_requested';

  // F1 check-in, F2 companion / habits / avatar
  static const String checkinStarted = 'checkin_started';
  static const String checkinCompleted = 'checkin_completed';
  static const String checkinAbandoned = 'checkin_abandoned';
  static const String companionResponseShown = 'companion_response_shown';
  static const String habitLogged = 'habit_logged';
  static const String avatarRestChanged = 'avatar_rest_changed';

  // F4 capsules
  static const String capsuleSealed = 'capsule_sealed';
  static const String capsuleUnlocked = 'capsule_unlocked';
  static const String capsuleOpened = 'capsule_opened';

  // F5 rooms, F9 safety
  static const String roomOfferShown = 'room_offer_shown';
  static const String roomJoined = 'room_joined';
  static const String roomLeft = 'room_left';
  static const String gestureSent = 'gesture_sent';
  static const String roomSurveyAnswered = 'room_survey_answered';
  static const String safetyActionTaken = 'safety_action_taken';

  // F15 Sanctuary
  static const String sanctuaryActivityStarted = 'sanctuary_activity_started';
  static const String sanctuaryActivityEnded = 'sanctuary_activity_ended';

  // F14 notifications
  static const String notificationPermissionResult =
      'notification_permission_result';
  static const String notificationOpened = 'notification_opened';

  /// Named in PRD 12 rule 9; its properties are derived.
  static const String notificationSettingChanged =
      'notification_setting_changed';
}

// ---- shared value sets ------------------------------------------------------

const Set<String> _quadrants = {'storm', 'rain', 'moonlight', 'sunrise'};
const Set<String> _languages = {'en', 'te', 'te-Latn', 'hi', 'hi-Latn'};
const Set<String> _languagePools = {'en', 'te_tenglish', 'hi_hinglish'};
const Set<String> _tzRegions = {
  'americas',
  'europe_africa',
  'south_asia',
  'east_asia_pacific',
};
const Set<String> _utmSources = {
  'reddit',
  'instagram',
  'youtube',
  'discord',
  'store_search',
  'share_card',
  'other',
};
const Set<String> _checkinSources = {
  'home',
  'widget',
  'notification',
  'onboarding',
};

/// Onboarding steps, in order (step_index = position, from 0).
const List<String> onboardingSteps = [
  'welcome',
  'trust',
  'dob',
  'language',
  'sign_in',
  'first_checkin',
];

/// Time spans in days, for how far ahead a capsule opens and how long it
/// stayed sealed (derived: the PRD names the property, not the buckets).
const Set<String> _dayBuckets = {
  'lt_1w',
  '1w_1m',
  '1m_3m',
  '3m_6m',
  '6m_1y',
  '1y_2y',
  '2y_plus',
};
const Set<String> _sanctuaryActivities = {
  'breathe',
  'grounding',
  'stillness',
  'savour',
  'sounds',
  'night_wind_down',
};
const Set<String> _sanctuaryVariants = {
  'calm',
  'box',
  '4_7_8',
  '5_4_3_2_1',
  'hand_on_heart',
  'gratitude',
  'mix',
  'none',
};
const Set<String> _notificationTypes = {
  'reminder',
  'capsule',
  'room',
  'lantern_hour',
  'wind_down',
  'trial_ending',
};
const Set<String> _gestures = {
  'warm_tea',
  'light_a_candle',
  'hug',
  'me_too',
  'soft_rain',
  'stargaze',
  'deep_breath',
  'youre_not_alone',
};

/// Longest duration any event reports: a day, in ms.
const int _dayMs = 24 * 60 * 60 * 1000;

/// Every event and the only properties it may carry.
const Map<String, Map<String, PropSpec>> analyticsSchema = {
  // ---- F8 onboarding & account ----------------------------------------------
  AnalyticsEvents.onboardingStarted: {
    'entry': EnumProp({'organic', 'deeplink'}),
    'utm_source': EnumProp(_utmSources),
    // No campaign allow-list yet: anything maps to `other` (PRD: "mapped to
    // an allow-list; unknown → other").
    'utm_campaign': EnumProp({'other'}),
  },
  AnalyticsEvents.languageSelected: {
    'language': EnumProp(_languages),
    'from_language': EnumProp(_languages),
    'surface': EnumProp({'onboarding', 'settings'}),
    'changed_from_default': BoolProp(),
  },
  AnalyticsEvents.ageGateCompleted: {},
  AnalyticsEvents.onboardingStepCompleted: {
    'step': EnumProp({
      'welcome',
      'trust',
      'dob',
      'language',
      'sign_in',
      'first_checkin',
    }),
    'step_index': IntProp(max: 5),
    'duration_ms': IntProp(max: _dayMs),
  },
  AnalyticsEvents.accountCreated: {
    'auth_method': EnumProp({'apple', 'google', 'email', 'phone'}),
  },
  AnalyticsEvents.onboardingCompleted: {
    'first_checkin_done': BoolProp(),
    'total_duration_ms': IntProp(max: 30 * _dayMs),
  },
  AnalyticsEvents.accountDeletionRequested: {},

  // ---- F1 check-in, F2 -----------------------------------------------------------
  AnalyticsEvents.checkinStarted: {'source': EnumProp(_checkinSources)},
  AnalyticsEvents.checkinCompleted: {
    // Quadrant only, never the mood (PRD principle 3).
    'quadrant': EnumProp(_quadrants),
    'tag_count': IntProp(max: 20),
    'has_note': BoolProp(),
    'has_voice': BoolProp(),
    'duration_ms': IntProp(max: _dayMs),
    'source': EnumProp(_checkinSources),
    'is_offline': BoolProp(),
    'is_backfill': BoolProp(),
    'prompt_shown': BoolProp(),
  },
  AnalyticsEvents.checkinAbandoned: {
    'reached_step': EnumProp({'none', 'mood'}),
  },
  AnalyticsEvents.companionResponseShown: {
    // No line or pool id: the neutral after-support pool would reveal a
    // crisis sheet (DS-7).
    'quadrant': EnumProp(_quadrants),
    'motion': EnumProp({'full', 'still'}),
    'moment': EnumProp({'none', 'wake', 'evolve'}),
  },
  AnalyticsEvents.habitLogged: {
    // A preset key or `custom`: never a custom habit's name.
    'habit_key': EnumProp({
      'hydrate',
      'sleep_on_time',
      'move',
      'breathe',
      'journal',
      'go_outside',
      'custom',
    }),
    'is_backfill': BoolProp(),
  },
  AnalyticsEvents.avatarRestChanged: {
    'state': EnumProp({'resting', 'woke'}),
    'days_away': IntProp(max: 3650),
  },

  // ---- F4 capsules (never content, titles, dates or targets) ---------------
  AnalyticsEvents.capsuleSealed: {
    'unlock_type': EnumProp({'date', 'mood'}),
    'trigger_scope': EnumProp({'mood', 'quadrant'}),
    'horizon_bucket': EnumProp(_dayBuckets),
    'has_voice': BoolProp(),
    'photo_count': IntProp(max: 3),
    'prompt_shown': BoolProp(),
  },
  AnalyticsEvents.capsuleUnlocked: {
    'unlock_type': EnumProp({'date', 'mood'}),
    'days_sealed_bucket': EnumProp(_dayBuckets),
    'is_offline': BoolProp(),
  },
  AnalyticsEvents.capsuleOpened: {'ceremony_completed': BoolProp()},

  // ---- F5 rooms, F9 safety (no room, member or report ids) -----------------
  AnalyticsEvents.roomOfferShown: {
    'quadrant': EnumProp(_quadrants),
    'is_lantern_hour': BoolProp(),
    'language_pool': EnumProp(_languagePools),
  },
  AnalyticsEvents.roomJoined: {
    'quadrant': EnumProp(_quadrants),
    'entry': EnumProp({
      'checkin_offer',
      'rooms_tab',
      'your_rooms',
      'notification',
    }),
    'members_bucket': EnumProp({'1', '2_3', '4_7', '8_15', '16_24'}),
    'cold_start_merged': BoolProp(),
    'language_pool': EnumProp(_languagePools),
    'tz_region': EnumProp(_tzRegions),
  },
  AnalyticsEvents.roomLeft: {
    'dwell_s': IntProp(max: 24 * 60 * 60),
    'gestures_sent': IntProp(max: 1000),
  },
  AnalyticsEvents.gestureSent: {
    'gesture': EnumProp(_gestures),
    'target': EnumProp({'member', 'reflection', 'room', 'session'}),
    'surface': EnumProp({'room', 'game', 'quiet'}),
  },
  AnalyticsEvents.roomSurveyAnswered: {
    'answer': EnumProp({'yes', 'no', 'skip'}),
  },
  AnalyticsEvents.safetyActionTaken: {
    'action': EnumProp({'report', 'block', 'mute'}),
    'surface': EnumProp({'member', 'gesture', 'room'}),
    'reason': EnumProp({
      'in_danger',
      'harassment',
      'sexual',
      'hate',
      'contact_info',
      'spam',
      'under_13',
      'targeting_young_person',
      'other',
      'none',
    }),
  },

  // ---- F15 Sanctuary (activity and length only) ------------------------------
  AnalyticsEvents.sanctuaryActivityStarted: {
    'activity': EnumProp(_sanctuaryActivities),
    'variant': EnumProp(_sanctuaryVariants),
    // Never a support-sheet or Safety Center value (PRD calm-events rule).
    'entry': EnumProp({
      'sanctuary',
      'todays_minute',
      'minute_for_you',
      'wind_down_reminder',
    }),
  },
  AnalyticsEvents.sanctuaryActivityEnded: {
    'activity': EnumProp(_sanctuaryActivities),
    'variant': EnumProp(_sanctuaryVariants),
    'duration_bucket': EnumProp({
      'lt_30s',
      '30_59s',
      '1_3m',
      '3_10m',
      '10_30m',
      '30m_plus',
    }),
    'completed': BoolProp(),
    'habit_logged': BoolProp(),
  },

  // ---- F14 notifications ---------------------------------------------------------
  AnalyticsEvents.notificationPermissionResult: {
    'result': EnumProp({'granted', 'denied', 'provisional'}),
  },
  AnalyticsEvents.notificationOpened: {'type': EnumProp(_notificationTypes)},
  AnalyticsEvents.notificationSettingChanged: {
    'setting': EnumProp({
      'master',
      'reminder',
      'reminder_time',
      'reminder_in_quiet_hours',
      'capsule',
      'quiet_hours',
      'discreet',
    }),
    'enabled': BoolProp(),
  },
};

/// Global properties on every event (PRD 13-analytics). Age is always 18+
/// by construction, so it is never a property.
const Map<String, PropSpec> analyticsGlobalProps = {
  'app_version': CodeProp(
    r'^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(\+[0-9]{1,6})?$',
    maxLength: 20,
  ),
  'platform': EnumProp({'ios', 'android'}),
  'os_major': IntProp(min: 1, max: 99),
  'app_language': EnumProp(_languages),
  // Device region from the OS locale, never from the IP.
  'country': CodeProp(r'^[A-Z]{2}$', maxLength: 2),
  'plan': EnumProp({'free', 'trial', 'plus'}),
  'signup_age_bucket': EnumProp({'0', '1', '2_7', '8_30', '31_plus'}),
  'acq_channel': EnumProp({
    'reddit',
    'instagram',
    'youtube',
    'discord',
    'store_search',
    'share_card',
    'other',
    'unknown',
  }),
};

/// Set on every event by the app itself (never by a caller): PostHog must
/// not look the request IP up for a location (PRD principle 2; the project
/// setting "Discard client IP data" must be on as well).
const Map<String, Object> analyticsFixedProps = {r'$geoip_disable': true};
