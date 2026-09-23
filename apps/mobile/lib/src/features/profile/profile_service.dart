import 'dart:math';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';

import '../../core/db/kv_store.dart';
import '../../core/net/api_models.dart';
import '../../core/net/aura_api.dart';
import '../../core/time/clock.dart';
import '../progress/progress_repository.dart';

enum ProfileFlush {
  nothingPending,
  saved,
  under13,

  /// Network/5xx: try again later; sync waits for the profile.
  retryLater,

  /// Refused (`409 birth_date_locked`, or a 4xx that stays pending and is
  /// retried with backoff): sync carries on.
  failed,

  /// Still pending, but backing off after a refusal — or held while the
  /// account's deletion is pending (`403 account_deletion_pending`, see
  /// [ProfileService.releaseDeletionHold]): sync carries on.
  deferred,
}

/// A platform age band for `POST /v1/profile` (`ageSignal`, F8 REQ-ACC-04 /
/// REQ-ACC-10; contracts/api/v1.md "Onboarding / profile"). The app sends
/// only "under 18": under 13 is blocked on the phone before any auth call,
/// and an adult band changes nothing on the server.
enum AgeBand {
  under18('under18');

  const AgeBand(this.wire);

  final String wire;

  static AgeBand? fromWire(String? v) {
    for (final b in values) {
      if (b.wire == v) return b;
    }
    return null;
  }
}

/// Queues and sends `POST /v1/profile`.
///
/// The DOB is kept in the encrypted local database because a later profile
/// POST (locale/timezone change) must repeat the same `birthDate` — it is
/// locked server-side after onboarding. It never goes to logs or analytics.
class ProfileService {
  ProfileService({
    required this._kv,
    required this._timezone,
    required this._progress,
    required this._country,
    this._clock = const Clock(),
    this._onDeletionPending,
  });

  /// The server refused the profile with `403 account_deletion_pending`: the
  /// account is in its 7-day deletion grace. Reported like sync's refused
  /// push (the UI asks "Keep my account?"); called once per hold.
  final void Function()? _onDeletionPending;

  final KvStore _kv;

  /// The current resolved device zone (read at send time).
  final String Function() _timezone;
  final ProgressRepository _progress;
  final String? Function() _country;
  final Clock _clock;

  /// Backoff after the server refused the profile (e.g. `400`): it stays
  /// pending and is retried (30 s … 1 h), never dropped. In memory: a restart
  /// retries at once.
  int _refusals = 0;
  DateTime? _retryAt;
  static const Duration _maxBackoff = Duration(hours: 1);

  /// Set by `403 account_deletion_pending`: the profile stays pending but is
  /// not sent (every retry would be refused) until [releaseDeletionHold].
  bool _heldForDeletion = false;

  /// True while a pending profile waits for the "Keep my account?" choice.
  bool get isHeldForDeletion => _heldForDeletion;

  /// The platform age band waiting to go with the next profile POST.
  /// User-scoped (wiped at sign-out); cleared once the server took it, so a
  /// later re-send (locale, timezone) never restarts the server's window.
  static const String ageSignalKey = 'profile.age_signal';

  /// A platform signal said "under 18" (AgeSignalPolicy): send the band with
  /// the next profile POST, so the server's invisible protections apply
  /// even with an adult DOB. Never logged or shown.
  Future<void> noteAgeSignal(AgeBand band) async {
    await _kv.set(ageSignalKey, band.wire);
    await markDirty();
  }

  /// "Keep my account" succeeded, or the account signed out / changed: a
  /// pending profile goes on the next flush, without backoff.
  void releaseDeletionHold() {
    if (!_heldForDeletion) return;
    _heldForDeletion = false;
    _refusals = 0;
    _retryAt = null;
  }

  /// Stores the DOB and queues the first profile POST.
  Future<void> queue({required LocalDay birthDate}) async {
    // A new onboarding is never held for an earlier account's deletion.
    releaseDeletionHold();
    await _kv.set(KvKeys.birthDate, birthDate.toIso());
    // Only used to add Childline (1098) on the India help sheet.
    await _kv.set(
      KvKeys.minorUntil,
      LocalDay(birthDate.year + 18, birthDate.month, birthDate.day).toIso(),
    );
    await markDirty();
  }

  /// Locale, timezone or country changed (or the server says it has no
  /// profile): re-send the profile on next sync. A content change retries at
  /// once; [resetBackoff] `false` keeps an ongoing refusal backoff.
  Future<void> markDirty({bool resetBackoff = true}) async {
    if (await _kv.get(KvKeys.birthDate) == null) return;
    if (resetBackoff) {
      _refusals = 0;
      _retryAt = null;
    }
    await _kv.set(KvKeys.pendingProfile, '1');
  }

  Future<bool> hasPending() async =>
      await _kv.get(KvKeys.pendingProfile) != null;

  /// The server has this person's profile (onboarded, nothing pending).
  Future<bool> isOnServer() async =>
      await _kv.get(KvKeys.birthDate) != null && !await hasPending();

  Future<ProfileFlush> flush(AuraApi api) async {
    if (await _kv.get(KvKeys.pendingProfile) == null) {
      return ProfileFlush.nothingPending;
    }
    final birthDate = await _kv.get(KvKeys.birthDate);
    if (birthDate == null) {
      await _kv.set(KvKeys.pendingProfile, null);
      return ProfileFlush.nothingPending;
    }
    if (_heldForDeletion) return ProfileFlush.deferred;
    final retryAt = _retryAt;
    if (retryAt != null && _clock.now().isBefore(retryAt)) {
      return ProfileFlush.deferred;
    }
    final locale = await _kv.get(KvKeys.locale) ?? AuraLocales.en;
    final zone = _timezone();
    final band = AgeBand.fromWire(await _kv.get(ageSignalKey));
    try {
      final result = await api.postProfile(
        ProfileRequest(
          birthDate: birthDate,
          uiLocale: locale,
          timezone: zone,
          country: _country(),
          ageSignal: band?.wire,
        ),
      );
      await _kv.set(KvKeys.pendingProfile, null);
      if (band != null) {
        await _kv.set(ageSignalKey, null);
      } else if (await _kv.get(ageSignalKey) != null) {
        // A band noted while this POST was in flight goes with the next one.
        await _kv.set(KvKeys.pendingProfile, '1');
      }
      _refusals = 0;
      _retryAt = null;
      switch (result) {
        case ProfileSaved(:final snapshot):
          await _kv.set(KvKeys.profileTimezone, zone);
          if (snapshot != null) await _progress.saveSnapshot(snapshot);
          return ProfileFlush.saved;
        case ProfileUnder13():
          await _kv.set(KvKeys.birthDate, null);
          return ProfileFlush.under13;
      }
    } on ApiException catch (e) {
      if (e.isRetryable) return ProfileFlush.retryLater;
      if (e.isDeletionPending) {
        // The account is in its deletion grace period: every POST would be
        // refused. Keep the profile pending, no backoff, send nothing more
        // until the person decides ("Keep my account" releases the hold).
        _heldForDeletion = true;
        _onDeletionPending?.call();
        return ProfileFlush.deferred;
      }
      if (e.code == 'birth_date_locked') {
        // The server keeps the onboarding DOB (support-only change): the
        // profile exists, so stop re-sending this one. It still recorded the
        // age band (contracts/api/v1.md), so that is done too.
        await _kv.set(KvKeys.pendingProfile, null);
        if (band != null) await _kv.set(ageSignalKey, null);
        return ProfileFlush.failed;
      }
      // Any other refusal: keep it pending and retry with backoff, never
      // give up (a lost profile blocks every push with profile_required).
      _refusals++;
      final wait = Duration(seconds: 30 << min(_refusals - 1, 7));
      _retryAt = _clock.now().add(wait > _maxBackoff ? _maxBackoff : wait);
      debugPrint('profile: refused (${e.code}); retrying later');
      return ProfileFlush.failed;
    }
  }
}
