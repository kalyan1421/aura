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
  static const String carriesOnShownFor = 'streak.carries_on_shown_for';

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

  /// The only keys kept when an account signs out. Everything else in the
  /// table belongs to the signed-in person and is wiped (shared phones).
  /// The under-13 lock and the DB key live in secure storage and stay too.
  static const Set<String> deviceScoped = {locale, deviceId, pushDeleteOwed};
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

  Stream<Map<String, dynamic>?> watchJson(String key) => watch(
    key,
  ).map((v) => v == null ? null : jsonDecode(v) as Map<String, dynamic>);

  Future<void> setJson(String key, Map<String, dynamic>? value) =>
      set(key, value == null ? null : jsonEncode(value));
}
