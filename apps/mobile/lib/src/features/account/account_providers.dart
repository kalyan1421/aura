import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/net/aura_api.dart';
import '../../core/providers.dart';

part 'account_providers.g.dart';

/// In-app account deletion (F8 REQ-ACC-11; contracts/api/v1.md "Account
/// deletion"): a 7-day grace period, then the server purges everything.
/// Deleting needs a connection; nothing on the phone is wiped unless the
/// server accepted the request.
abstract interface class AccountRepository {
  /// `POST /v1/account/deletion` → the scheduled purge time. Idempotent.
  Future<DateTime> requestDeletion();

  /// `GET /v1/account` → the scheduled purge time, or `null`.
  Future<DateTime?> scheduledDeletion();

  /// `DELETE /v1/account/deletion` ("Keep my account"). Idempotent. Throws
  /// `409 account_deletion_in_progress` once the grace period is over.
  Future<void> cancelDeletion();
}

class ApiAccountRepository implements AccountRepository {
  const ApiAccountRepository(this._api);

  final AuraApi _api;

  @override
  Future<DateTime> requestDeletion() async {
    final date = (await _api.requestDeletion()).scheduledFor;
    // A 202 always carries the date; anything else is a server fault.
    if (date == null) {
      throw const ApiException(code: 'missing_deletion_date', status: 502);
    }
    return date;
  }

  @override
  Future<DateTime?> scheduledDeletion() async =>
      (await _api.account()).scheduledFor;

  @override
  Future<void> cancelDeletion() => _api.cancelDeletion();
}

/// `null` when this build has no API (debug builds without config).
@Riverpod(keepAlive: true)
AccountRepository? accountRepository(Ref ref) {
  final api = ref.watch(auraApiProvider);
  return api == null ? null : ApiAccountRepository(api);
}

/// How "Keep my account" ended.
enum KeepResult {
  /// The deletion is cancelled; sync pushes again.
  kept,

  /// `409 account_deletion_in_progress`: the grace period is over, the
  /// account can't be kept. The app explains and signs out ([DeletionHold.letGo]).
  tooLate,
}

/// The signed-in account is in its deletion grace period.
@immutable
class DeletionPending {
  const DeletionPending({required this.userId, this.scheduledFor});

  final String userId;

  /// `null` until `GET /v1/account` answers (e.g. offline after a sync 403).
  final DateTime? scheduledFor;

  @override
  bool operator ==(Object other) =>
      other is DeletionPending &&
      other.userId == userId &&
      other.scheduledFor == scheduledFor;

  @override
  int get hashCode => Object.hash(userId, scheduledFor);
}

/// Whether the signed-in account has a deletion scheduled. While it does,
/// the server refuses every write, sync holds the outbox, and the app asks
/// "Keep my account?" — after sign-in (the sign-in screen), and in Settings.
/// Clearing it (`null`) releases sync (wired in `syncControllerProvider`).
@Riverpod(keepAlive: true)
class DeletionHold extends _$DeletionHold {
  @override
  DeletionPending? build() {
    // Only the signed-in account can be pending: signing out or switching
    // accounts drops the hold.
    ref.listen(authUserProvider, (_, next) {
      final held = state;
      if (held != null && next.value?.id != held.userId) state = null;
    });
    return null;
  }

  String? get _userId => ref.read(authRepositoryProvider).currentUser?.id;

  /// Asked after every successful sign-in (code or magic link). Answers the
  /// pending state, or `null` when nothing is scheduled or the server can't
  /// be reached — sign-in never waits on this; a later
  /// `403 account_deletion_pending` from sync asks again.
  Future<DeletionPending?> check({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final userId = _userId;
    final repo = ref.read(accountRepositoryProvider);
    if (userId == null || repo == null) return null;
    try {
      final date = await repo.scheduledDeletion().timeout(timeout);
      if (_userId != userId) return null;
      state = date == null
          ? null
          : DeletionPending(userId: userId, scheduledFor: date);
      return state;
    } catch (e) {
      debugPrint('account: status ${e.runtimeType}');
      return null;
    }
  }

  /// Sync got `403 account_deletion_pending`: hold, then look up the date.
  /// Stays held even if the lookup says nothing is scheduled — the person
  /// resolves it with "Keep my account" (idempotent), so a confused server
  /// can never start a push/refuse loop.
  Future<void> reportFromSync() async {
    final userId = _userId;
    if (userId == null) return;
    final known = state?.userId == userId ? state?.scheduledFor : null;
    state = DeletionPending(userId: userId, scheduledFor: known);
    final repo = ref.read(accountRepositoryProvider);
    if (repo == null) return;
    try {
      final date = await repo.scheduledDeletion();
      if (date != null && state?.userId == userId) {
        state = DeletionPending(userId: userId, scheduledFor: date);
      }
    } catch (e) {
      debugPrint('account: status ${e.runtimeType}');
    }
  }

  /// "Keep my account": cancels the deletion; sync pushes again. Too late
  /// (the purge is under way) answers [KeepResult.tooLate] and keeps the
  /// hold. Throws (e.g. [ApiException]) when the server can't be reached —
  /// nothing changes then.
  Future<KeepResult> keep() async {
    final repo = ref.read(accountRepositoryProvider);
    if (repo == null) throw const ApiException(code: 'unavailable');
    try {
      await repo.cancelDeletion();
    } on ApiException catch (e) {
      if (e.isDeletionInProgress) return KeepResult.tooLate;
      rethrow;
    }
    state = null;
    return KeepResult.kept;
  }

  /// "Let it go": the deletion stays scheduled; this phone is cleared and
  /// signed out exactly like Sign out (lands on Welcome).
  Future<void> letGo() async {
    await ref.read(signOutServiceProvider).signOut();
    state = null;
  }
}

/// A deletion date in the UI language (Telugu month names for `te`;
/// romanized locales use English ones, like the DOB picker).
String formatAccountDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context);
  final tag = locale.scriptCode == 'Latn' ? 'en' : locale.languageCode;
  final local = date.toLocal();
  try {
    return DateFormat.yMMMMd(tag).format(local);
  } catch (_) {
    return DateFormat.yMMMMd('en').format(local);
  }
}
