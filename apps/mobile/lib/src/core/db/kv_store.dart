import 'dart:convert';

import 'database.dart';

/// Keys for [KvStore]. Values live in the encrypted database.
abstract final class KvKeys {
  static const String locale = 'app.locale';
  static const String deviceId = 'app.device_id';
  static const String onboardingStage = 'onboarding.stage';

  /// Full DOB (ISO). Needed to (re)send `POST /v1/profile`; stays on device.
  static const String birthDate = 'profile.birth_date';

  /// Set when the profile must be (re)sent on the next sync.
  static const String pendingProfile = 'profile.pending';

  /// The IANA zone last accepted by `POST /v1/profile`.
  static const String profileTimezone = 'profile.timezone';

  /// 18th birthday (ISO). Used only to add Childline to the India help sheet.
  static const String minorUntil = 'profile.minor_until';
  static const String snapshot = 'sync.snapshot';
  static const String lastHue = 'avatar.last_hue';
  static const String playedMoments = 'avatar.played_moments';
  static const String pulledFor = 'sync.pulled_for';

  /// Delta-pull cursors (PRD 16 "Pull: per-entity delta since a server
  /// cursor"): `{userId, checkIns, habits, habitLogs, tombstones, at}`.
  static const String pullCursor = 'sync.pull_cursor';
  static const String carriesOnShownFor = 'streak.carries_on_shown_for';

  /// W04: the `lastActiveDay` the universe's "Your world is here" card was
  /// last shown for (ISO), so it appears once per absence. Device-only.
  static const String welcomeShownFor = 'universe.welcome_shown_for';

  /// T04: how each world object looked when the person last saw it
  /// (`{key: [stage, vitality]}`), so a plant's grow or wake moment plays
  /// once. Device-only presentation state; losing it only resets the baseline.
  static const String worldSeen = 'universe.world_seen';

  /// W06: the person turned on "use my steps" (`1`). Only this flag is kept;
  /// the step count itself is never stored, logged or uploaded.
  static const String healthStepsEnabled = 'health.steps_enabled';

  /// Push soft ask answered: `{answer: allow|notNow, at}`. Nothing is asked
  /// or registered before this exists (PRD 15-permissions).
  static const String pushSoftAsk = 'push.soft_ask';

  /// `{userId, token}` the server has for this install (`PUT /v1/devices`).
  /// Never logged.
  static const String pushRegistered = 'push.registered';

  /// A registration is owed (offline / no profile yet): retried after the
  /// next successful sync.
  static const String pushPending = 'push.pending';

  /// FCM `deleteToken()` failed at sign-out (offline): retried later.
  /// Device-scoped, so it survives the sign-out wipe.
  static const String pushDeleteOwed = 'push.delete_owed';

  /// Comfort preferences (`ComfortPrefs` JSON): reduce motion, haptics,
  /// hide streak number. A property of this phone, not of the account.
  static const String comfort = 'comfort.prefs';

  /// Settings › Comfort › Writing prompts: "true" = guided prompts off. A
  /// property of this phone, like [comfort].
  static const String guidedPromptsOff = 'companion.guided_prompts_off';

  /// F10 Look back (features/insights/look_back.dart), all on this phone
  /// only and never synced (DS-7): the last time a crisis sheet or the
  /// Safety Center opened here (Look back rests 24 h after it), the ids of
  /// check-ins help was opened from (never shown in Look back), and the
  /// Settings switch ("true" = hidden). Device-scoped: "on that device".
  static const String lookBackHelpAt = 'lookback.help_at';
  static const String lookBackHelpCheckIns = 'lookback.help_checkins';
  static const String lookBackHidden = 'lookback.hidden';

  /// Set once this install keeps the Supabase session in secure storage
  /// (core/security/secure_session_storage.dart). Device-scoped: it
  /// describes the phone, and a sign-out must not make the next launch drop
  /// a fresh session.
  static const String sessionStore = 'auth.session_store';

  /// The only keys kept when an account signs out. Everything else in the
  /// table belongs to the signed-in person and is wiped (shared phones).
  /// The under-13 lock and the DB key live in secure storage and stay too.
  static const Set<String> deviceScoped = {
    locale,
    deviceId,
    pushDeleteOwed,
    comfort,
    guidedPromptsOff,
    lookBackHelpAt,
    lookBackHelpCheckIns,
    lookBackHidden,
    sessionStore,
  };
}

/// Typed helpers over the key/value table.
class KvStore {
  KvStore(this._db);

  final AppDatabase _db;

  Future<String?> get(String key) => _db.getValue(key);

  Stream<String?> watch(String key) => _db.watchValue(key);

  Future<void> set(String key, String? value) => _db.setValue(key, value);

  Future<Map<String, dynamic>?> getJson(String key) async {
    final v = await get(key);
    return v == null ? null : jsonDecode(v) as Map<String, dynamic>;
  }

  Stream<Map<String, dynamic>?> watchJson(String key) =>
      watch(key)
          .map((v) => v == null ? null : jsonDecode(v) as Map<String, dynamic>);

  Future<void> setJson(String key, Map<String, dynamic>? value) =>
      set(key, value == null ? null : jsonEncode(value));
}
