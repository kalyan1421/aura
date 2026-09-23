import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';

import '../db/kv_store.dart';
import '../env/env.dart';
import '../net/aura_api.dart';
import '../time/clock.dart';
import 'analytics_gate.dart';

/// The analytics notice the "Help improve Aura" choice refers to. Bump it
/// when that notice changes: the server records every choice with it
/// (`user_consents.policy_version`) and starts a fresh analytics id for a
/// new version.
const String analyticsPolicyVersion = 'analytics-2026-09';

/// Analytics keys in the encrypted key/value table. All of them belong to
/// the signed-in person (not in `KvKeys.deviceScoped`), so a sign-out wipes
/// them: the next person on a shared phone starts from the default.
abstract final class AnalyticsKeys {
  /// "Help improve Aura": `{granted, at, version}`.
  static const String consent = 'analytics.consent';

  /// The server's answer for the account: `{userId, tracking, distinctId,
  /// signupDay, granted, version, at}`.
  static const String identity = 'analytics.identity';

  /// When this onboarding began (ISO), for `total_duration_ms`.
  static const String onboardingStartedAt = 'analytics.onboarding_started_at';

  /// The avatar's last known rest state (`resting` / `awake`), so entering
  /// or leaving the Resting Nebula is reported once, even across launches.
  static const String restState = 'analytics.rest_state';

  /// Date capsules whose unlock was already reported (ids stay on the
  /// phone).
  static const String capsulesUnlocked = 'analytics.capsules_unlocked';
}

/// "Help improve Aura" (PRD 13-analytics principle 5), on this phone for the
/// person using it. Before any choice: [defaultOn] (off unless the build
/// says otherwise; `[LEGAL]`).
class AnalyticsConsentStore {
  AnalyticsConsentStore(
    this._kv, {
    this.defaultOn = Env.analyticsDefaultOn,
    Clock clock = const Clock(),
  }) : _clock = clock;

  final KvStore _kv;
  final Clock _clock;
  final bool defaultOn;

  bool _fromJson(Map<String, dynamic>? j) =>
      j == null ? defaultOn : j['granted'] == true;

  Future<bool> granted() async => _fromJson(await _kv.getJson(_key));

  Stream<bool> watch() => _kv.watchJson(_key).map(_fromJson);

  /// The person's choice. Takes effect at once (the gate stops or starts);
  /// the server hears about it on the next [AnalyticsIdentitySync.refresh].
  Future<void> set(bool granted) => _kv.setJson(_key, {
    'granted': granted,
    'at': _clock.now().toUtc().toIso8601String(),
    'version': analyticsPolicyVersion,
  });

  static const String _key = AnalyticsKeys.consent;
}

/// The server's last answer for an account (`PUT /v1/analytics/consent`).
@immutable
class AnalyticsIdentity {
  const AnalyticsIdentity({
    required this.userId,
    required this.tracking,
    required this.granted,
    required this.version,
    this.distinctId,
    this.signupDay,
  });

  factory AnalyticsIdentity.fromJson(Map<String, dynamic> j) =>
      AnalyticsIdentity(
        userId: '${j['userId'] ?? ''}',
        tracking: j['tracking'] == true,
        granted: j['granted'] == true,
        version: '${j['version'] ?? ''}',
        distinctId: j['distinctId'] is String ? j['distinctId'] as String : null,
        signupDay: LocalDay.tryParse(j['signupDay'] as String?),
      );

  final String userId;
  final bool tracking;

  /// The choice the answer was for.
  final bool granted;
  final String version;
  final String? distinctId;

  /// The account's signup day (for `signup_age_bucket`).
  final LocalDay? signupDay;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'tracking': tracking,
    'granted': granted,
    'version': version,
    'distinctId': distinctId,
    'signupDay': signupDay?.toIso(),
  };

  /// The verdict for the signed-in [currentUserId] with the current choice
  /// [granted]: unknown until the server answered for exactly this account,
  /// choice and notice version.
  static ServerVerdict verdictFor(
    AnalyticsIdentity? identity, {
    required String? currentUserId,
    required bool granted,
  }) {
    if (identity == null ||
        currentUserId == null ||
        identity.userId != currentUserId ||
        identity.granted != granted ||
        identity.version != analyticsPolicyVersion) {
      return ServerVerdict.unknown;
    }
    final id = identity.distinctId;
    return identity.tracking && id != null
        ? ServerVerdict.on(id)
        : ServerVerdict.off;
  }
}

/// Tells the server the person's choice and stores its answer (the gate's
/// [ServerVerdict]). Runs when an account signs in, when the choice changes,
/// after a sync (the profile must be on the server first) and at most every
/// few hours on resume. Serialised; never throws; logs error kinds only.
class AnalyticsIdentitySync {
  AnalyticsIdentitySync({
    required KvStore kv,
    required AuraApi? Function() api,
    required String? Function() userId,
    required Future<bool> Function() profileOnServer,
    required Future<bool> Function() consent,
    Clock clock = const Clock(),
  }) : _kv = kv,
       _api = api,
       _userId = userId,
       _profileOnServer = profileOnServer,
       _consent = consent,
       _clock = clock;

  final KvStore _kv;
  final AuraApi? Function() _api;
  final String? Function() _userId;
  final Future<bool> Function() _profileOnServer;
  final Future<bool> Function() _consent;
  final Clock _clock;

  /// How long an answer stays fresh for [refresh] without `force`.
  static const Duration maxAge = Duration(hours: 6);

  Future<void>? _running;
  bool _again = false;
  DateTime? _lastOk;
  String? _lastKey;

  /// Asks the server unless the stored answer is for this account and
  /// choice and younger than [maxAge] ([force]: ask anyway).
  Future<void> refresh({bool force = false}) {
    final running = _running;
    if (running != null) {
      _again = _again || force;
      return running;
    }
    final f = _run(force).whenComplete(() => _running = null);
    _running = f;
    return f;
  }

  Future<void> _run(bool force) async {
    var again = force;
    do {
      _again = false;
      await _once(again);
      again = _again;
    } while (again);
  }

  Future<void> _once(bool force) async {
    try {
      final api = _api();
      final userId = _userId();
      if (api == null || userId == null) return;
      final granted = await _consent();
      final key = '$userId|$granted|$analyticsPolicyVersion';
      final last = _lastOk;
      if (!force &&
          key == _lastKey &&
          last != null &&
          _clock.now().difference(last) < maxAge) {
        return;
      }
      // The server needs the profile (DOB) to decide; sync sends it first.
      if (!await _profileOnServer()) return;
      final answer = await api.putAnalyticsConsent(
        granted: granted,
        policyVersion: analyticsPolicyVersion,
      );
      if (_userId() != userId) return; // signed out meanwhile
      await _store(
        AnalyticsIdentity(
          userId: userId,
          tracking: answer.tracking,
          granted: granted,
          version: analyticsPolicyVersion,
          distinctId: answer.tracking ? answer.distinctId : null,
          signupDay: LocalDay.tryParse(answer.signupDay),
        ),
      );
      _lastOk = _clock.now();
      _lastKey = key;
    } on ApiException catch (e) {
      if (e.isDeletionPending || e.isAccountClosed) {
        // Nothing is tracked for an account on hold; asked again later.
        final userId = _userId();
        if (userId != null) {
          await _store(
            AnalyticsIdentity(
              userId: userId,
              tracking: false,
              granted: await _consent(),
              version: analyticsPolicyVersion,
            ),
          );
        }
        return;
      }
      // Offline, 5xx, profile not there yet: tried again on the next
      // trigger (sync, resume, a change of choice).
      debugPrint('analytics: consent ${e.code}');
    } on Object catch (e) {
      debugPrint('analytics: consent ${e.runtimeType}');
    }
  }

  Future<void> _store(AnalyticsIdentity identity) =>
      _kv.setJson(AnalyticsKeys.identity, identity.toJson());

  /// Forget the in-memory freshness (sign-out: the stored answer is wiped
  /// with the rest of the person's data).
  void forget() {
    _lastOk = null;
    _lastKey = null;
  }
}
