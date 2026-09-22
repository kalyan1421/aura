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

  /// Still pending, but backing off after a refusal: sync carries on.
  deferred,
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
  });

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

  /// Stores the DOB and queues the first profile POST.
  Future<void> queue({required LocalDay birthDate}) async {
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
    final retryAt = _retryAt;
    if (retryAt != null && _clock.now().isBefore(retryAt)) {
      return ProfileFlush.deferred;
    }
    final locale = await _kv.get(KvKeys.locale) ?? AuraLocales.en;
    final zone = _timezone();
    try {
      final result = await api.postProfile(
        ProfileRequest(
          birthDate: birthDate,
          uiLocale: locale,
          timezone: zone,
          country: _country(),
        ),
      );
      await _kv.set(KvKeys.pendingProfile, null);
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
      if (e.code == 'birth_date_locked') {
        // The server keeps the onboarding DOB (support-only change): the
        // profile exists, so stop re-sending this one.
        await _kv.set(KvKeys.pendingProfile, null);
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
