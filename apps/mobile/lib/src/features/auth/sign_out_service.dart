import 'package:flutter/foundation.dart';

import '../../core/db/database.dart';
import '../../core/db/kv_store.dart';
import '../../core/security/note_cipher.dart';
import '../../core/security/secure_store.dart';
import 'auth_repository.dart';

/// Signing out leaves nothing personal on the phone (shared and borrowed
/// phones, PRD Notifications/Privacy). The next person starts at Welcome and
/// goes through the DOB gate again; none of the previous account's check-ins,
/// notes, DOB or pending outbox can reach them or their account.
///
/// Kept (device-scoped): the under-13 device lock and the database key
/// (secure storage), the device id, the language choice and an owed FCM
/// `deleteToken()` retry ([KvKeys.deviceScoped]).
class SignOutService {
  SignOutService({
    required this._auth,
    required this._db,
    required this._secure,
    required this._dataKeys,
    required this._unregisterPush,
    required this._pauseSync,
    required this._resumeSync,
    required this._afterWipe,
  });

  final AuthRepository _auth;
  final AppDatabase _db;
  final SecureStore _secure;
  final DataKeyRepository _dataKeys;

  /// Best-effort `DELETE /v1/devices` + FCM `deleteToken()`; needs the
  /// session, so it runs first.
  final Future<void> Function() _unregisterPush;

  /// Stops sync so an in-flight drain can't write the old account's data
  /// back after the wipe.
  final Future<void> Function() _pauseSync;
  final void Function() _resumeSync;

  /// Resets in-memory state (onboarding stage → welcome, caches).
  final Future<void> Function() _afterWipe;

  static const Duration _pushTimeout = Duration(seconds: 12);

  Future<void> signOut() async {
    final userId = _auth.currentUser?.id;
    await _pauseSync();
    try {
      // 1. Push unregistration (best effort, bounded).
      try {
        await _unregisterPush().timeout(_pushTimeout);
      } catch (e) {
        debugPrint('sign-out: push ${e.runtimeType}');
      }
      // 2. End the session. Supabase drops the local session before its
      //    network call, so a failure here still signs out on this phone.
      try {
        await _auth.signOut();
      } catch (e) {
        debugPrint('sign-out: auth ${e.runtimeType}');
      }
      // 3 + 4. Every personal row and user-scoped key, in one transaction.
      await _db.wipeUserData(keepKeys: KvKeys.deviceScoped);
      // The per-user note key (Keychain/Keystore + memory).
      _dataKeys.forget();
      if (userId != null) await _secure.delete(SecureKeys.dataKey(userId));
      // 6. Back to Welcome (the under-13 lock is untouched).
      await _afterWipe();
    } finally {
      _resumeSync();
    }
  }
}
