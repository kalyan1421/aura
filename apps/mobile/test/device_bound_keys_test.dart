// MASVS F-3 (docs/security/masvs-l1.md, CRYPTO-2): the database key and the
// per-user data keys are Keychain `…ThisDeviceOnly`, so they never travel in
// an iCloud backup or a Quick Start transfer; items written before are moved
// once, on first read, without ever losing the database key.
import 'package:aura/src/core/security/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// One Keychain, like flutter_secure_storage_darwin: an item is found at any
/// accessibility level; a write replaces it at the writer's level.
class _Keychain {
  final items = <String, ({String value, String level})>{};
  String? failWritesOf;
  int writes = 0;
}

class _Level implements SecureStore {
  _Level(this.keychain, this.level);
  final _Keychain keychain;
  final String level;

  @override
  Future<String?> read(String key) async => keychain.items[key]?.value;

  @override
  Future<void> write(String key, String value) async {
    keychain.writes++;
    if (keychain.failWritesOf == level) {
      // The plugin deletes the old item before a failing add.
      keychain.items.remove(key);
      throw StateError('keychain add failed');
    }
    keychain.items[key] = (value: value, level: level);
  }

  @override
  Future<void> delete(String key) async => keychain.items.remove(key);
}

void main() {
  const legacy = 'first_unlock';
  const device = 'first_unlock_this_device';
  final dataKey = SecureKeys.dataKey('u1');

  late _Keychain keychain;
  DeviceBoundKeyStore store({bool migrate = true, bool ios = true}) =>
      DeviceBoundKeyStore(
        portable: _Level(keychain, legacy),
        thisDevice: _Level(keychain, device),
        migrate: migrate,
        movesOnThisPlatform: ios,
      );

  setUp(() => keychain = _Keychain());

  test(
    'key material is written ThisDeviceOnly; other items stay portable',
    () async {
      final s = store();
      await s.write(SecureKeys.dbKey, 'a' * 64);
      await s.write(dataKey, '{"dataKey":"k"}');
      await s.write(SecureKeys.ageBlockUntil, '2026-10-01');
      expect(keychain.items[SecureKeys.dbKey]!.level, device);
      expect(keychain.items[dataKey]!.level, device);
      expect(keychain.items[SecureKeys.ageBlockUntil]!.level, legacy);
    },
  );

  test(
    'an older item moves on first read, once, with the same value',
    () async {
      keychain.items[SecureKeys.dbKey] = (value: 'b' * 64, level: legacy);
      final s = store();
      expect(await s.read(SecureKeys.dbKey), 'b' * 64);
      expect(keychain.items[SecureKeys.dbKey], (
        value: 'b' * 64,
        level: device,
      ));
      final writes = keychain.writes;
      expect(await s.read(SecureKeys.dbKey), 'b' * 64);
      // A new launch (new store) sees the marker and doesn't rewrite.
      expect(await store().read(SecureKeys.dbKey), 'b' * 64);
      expect(keychain.writes, writes);
    },
  );

  test(
    'a failed move puts the key back: the database key is never lost',
    () async {
      keychain.items[SecureKeys.dbKey] = (value: 'c' * 64, level: legacy);
      keychain.failWritesOf = device;
      final s = store();
      expect(await s.read(SecureKeys.dbKey), 'c' * 64);
      expect(keychain.items[SecureKeys.dbKey], (
        value: 'c' * 64,
        level: legacy,
      ));
      // Tried again on the next launch.
      keychain.failWritesOf = null;
      expect(await store().read(SecureKeys.dbKey), 'c' * 64);
      expect(keychain.items[SecureKeys.dbKey]!.level, device);
    },
  );

  test('background readers and Android never rewrite', () async {
    keychain.items[SecureKeys.dbKey] = (value: 'd' * 64, level: legacy);
    expect(await store(migrate: false).read(SecureKeys.dbKey), 'd' * 64);
    expect(await store(ios: false).read(SecureKeys.dbKey), 'd' * 64);
    expect(keychain.items[SecureKeys.dbKey]!.level, legacy);
    expect(keychain.writes, 0);
  });

  test(
    'delete removes the key and its marker (sign-out, a new data key later)',
    () async {
      keychain.items[dataKey] = (value: '{"dataKey":"k"}', level: legacy);
      final s = store();
      await s.read(dataKey);
      await s.delete(dataKey);
      expect(keychain.items.keys, isEmpty);
      expect(await s.read(dataKey), isNull);
    },
  );

  test('only the DB key and data keys count as key material', () {
    expect(DeviceBoundKeyStore.isKeyMaterial(SecureKeys.dbKey), isTrue);
    expect(DeviceBoundKeyStore.isKeyMaterial(dataKey), isTrue);
    expect(
      DeviceBoundKeyStore.isKeyMaterial(SecureKeys.ageBlockUntil),
      isFalse,
    );
    expect(DeviceBoundKeyStore.isKeyMaterial('aura.install_id'), isFalse);
  });
}
