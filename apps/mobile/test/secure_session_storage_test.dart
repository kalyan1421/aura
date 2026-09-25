// MASVS-STORAGE-1 (docs/security/masvs-l1.md): the Supabase session lives in
// secure storage, not SharedPreferences. Upgrades stay signed in; a new
// install never inherits a Keychain session from an earlier one; sign-out
// keeps the marker so the next launch doesn't drop a fresh session.
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/security/secure_session_storage.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

/// Stand-in for supabase_flutter's SharedPreferencesLocalStorage.
class _Legacy extends LocalStorage {
  _Legacy([this.value]);
  String? value;
  bool initialized = false;

  @override
  Future<void> initialize() async => initialized = true;
  @override
  Future<bool> hasAccessToken() async => value != null;
  @override
  Future<String?> accessToken() async => value;
  @override
  Future<void> removePersistedSession() async => value = null;
  @override
  Future<void> persistSession(String s) async => value = s;
}

void main() {
  const key = 'sb-abcd-auth-token';
  late KvStore kv;
  late MemorySecureStore secure;

  setUp(() {
    kv = KvStore(memoryDb());
    secure = MemorySecureStore();
  });

  SecureSessionStorage storage(_Legacy legacy) => SecureSessionStorage(
    secure: secure,
    kv: kv,
    persistSessionKey: key,
    legacy: legacy,
  );

  test(
    'upgrade: the SharedPreferences session moves and the old copy goes',
    () async {
      final legacy = _Legacy('{"access_token":"a","refresh_token":"r"}');
      final s = storage(legacy);
      await s.initialize();
      expect(legacy.initialized, isTrue);
      expect(await s.hasAccessToken(), isTrue);
      expect(await s.accessToken(), contains('refresh_token'));
      expect(legacy.value, isNull);
      expect(await kv.get(KvKeys.sessionStore), isNotNull);
    },
  );

  test(
    'new install: a Keychain session left from an earlier one is dropped',
    () async {
      await secure.write(key, '{"old":"session"}');
      final s = storage(_Legacy());
      await s.initialize();
      expect(await s.hasAccessToken(), isFalse);
    },
  );

  test('later launches keep the secure session', () async {
    final s = storage(_Legacy());
    await s.initialize();
    await s.persistSession('{"fresh":"session"}');
    // Next launch, same install.
    final again = storage(_Legacy());
    await again.initialize();
    expect(await again.accessToken(), '{"fresh":"session"}');
  });

  test('persist and remove use secure storage only', () async {
    final legacy = _Legacy();
    final s = storage(legacy);
    await s.initialize();
    await s.persistSession('{"s":1}');
    expect(secure.values[key], '{"s":1}');
    expect(legacy.value, isNull);
    await s.removePersistedSession();
    expect(await s.hasAccessToken(), isFalse);
  });

  test('the marker survives a sign-out wipe (device-scoped)', () {
    expect(KvKeys.deviceScoped, contains(KvKeys.sessionStore));
  });

  test('an unreadable legacy store never blocks start-up', () async {
    final s = SecureSessionStorage(
      secure: secure,
      kv: kv,
      persistSessionKey: key,
      legacy: _Throwing(),
    );
    await expectLater(s.initialize(), completes);
    expect(await s.hasAccessToken(), isFalse);
  });

  test('session key matches supabase_flutter', () {
    expect(
      supabaseSessionKey('https://abcd.supabase.co'),
      'sb-abcd-auth-token',
    );
  });
}

class _Throwing extends _Legacy {
  @override
  Future<void> initialize() async => throw StateError('prefs');
}
