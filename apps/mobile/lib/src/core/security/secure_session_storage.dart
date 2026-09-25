import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/kv_store.dart';
import 'secure_store.dart';

/// Keeps the Supabase session (access + refresh token) in the Keychain /
/// Keystore instead of supabase_flutter's default SharedPreferences, which is
/// a plain plist / XML file (on iOS it is also part of iCloud and iTunes
/// backups). MASVS-STORAGE-1, docs/security/masvs-l1.md.
///
/// On iOS the item is `first_unlock_this_device`: readable by the widget's
/// background refresh after the first unlock, never restored to another
/// phone from a backup. Keychain items outlive an uninstall, so a session
/// left behind by an earlier install is dropped on the first launch of a new
/// one (it would otherwise refresh before the date of birth is asked, which
/// REQ-ACC-02 forbids). The "this install has moved its session" marker
/// lives in the encrypted database ([KvKeys.sessionStore], device-scoped),
/// which an uninstall removes.
///
/// Upgrades keep people signed in: the first launch moves an existing
/// SharedPreferences session into secure storage and deletes the old copy.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({
    required this._secure,
    required this._kv,
    required this.persistSessionKey,
    this._legacy,
  });

  final SecureStore _secure;
  final KvStore _kv;
  final LocalStorage? _legacy;

  /// supabase_flutter's own key (`sb-<project ref>-auth-token`).
  final String persistSessionKey;

  @override
  Future<void> initialize() async {
    final legacy = _legacy;
    String? old;
    if (legacy != null) {
      try {
        await legacy.initialize();
        old = await legacy.accessToken();
      } catch (e) {
        debugPrint('auth: legacy session unreadable (${e.runtimeType})');
      }
    }
    final moved = await _kv.get(KvKeys.sessionStore) == _marker;
    if (!moved) {
      if (old != null) {
        // Upgrade from the SharedPreferences store: keep the person signed in.
        await _secure.write(persistSessionKey, old);
      } else {
        // First launch of this install: nothing may be left from before.
        await _secure.delete(persistSessionKey);
      }
      await _kv.set(KvKeys.sessionStore, _marker);
    }
    if (old != null) {
      try {
        await legacy!.removePersistedSession();
      } catch (e) {
        debugPrint('auth: legacy session not removed (${e.runtimeType})');
      }
    }
  }

  static const String _marker = 'secure.v1';

  @override
  Future<bool> hasAccessToken() async =>
      await _secure.read(persistSessionKey) != null;

  @override
  Future<String?> accessToken() => _secure.read(persistSessionKey);

  @override
  Future<void> removePersistedSession() => _secure.delete(persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _secure.write(persistSessionKey, persistSessionString);
}

/// supabase_flutter's session key for [supabaseUrl]
/// (`sb-<first host label>-auth-token`), so the legacy copy is found.
String supabaseSessionKey(String supabaseUrl) =>
    'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token';

/// Auth options for every `Supabase.initialize` (app and widget background):
/// the session lives in secure storage ([SecureSessionStorage]).
FlutterAuthClientOptions secureAuthOptions({
  required String supabaseUrl,
  required KvStore kv,
  SecureStore? secure,
}) {
  final key = supabaseSessionKey(supabaseUrl);
  return FlutterAuthClientOptions(
    localStorage: SecureSessionStorage(
      secure: secure ?? FlutterSecureStore.thisDeviceOnly(),
      kv: kv,
      persistSessionKey: key,
      legacy: SharedPreferencesLocalStorage(persistSessionKey: key),
    ),
  );
}
