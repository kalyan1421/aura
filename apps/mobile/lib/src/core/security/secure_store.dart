import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small async key-value store backed by iOS Keychain / Android Keystore.
///
/// Abstracted so tests (and the under-13 gate test) can use [MemorySecureStore].
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Keys used in secure storage. Nothing here identifies a person.
abstract final class SecureKeys {
  /// 256-bit key for the local SQLite3MultipleCiphers database (hex).
  static const String dbKey = 'aura.db_key.v1';

  /// ISO date until which the under-13 block screen shows (device lock).
  static const String ageBlockUntil = 'aura.age_block_until';

  /// Per-user data key for note encryption: `aura.data_key.<userId>`.
  static String dataKey(String userId) => 'aura.data_key.$userId';
}

class FlutterSecureStore implements SecureStore {
  FlutterSecureStore()
    : _storage = const FlutterSecureStorage(
        // iOS: Keychain items survive app reinstall, which the 30-day
        // under-13 device lock relies on (REQ-ACC-03).
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        // Android: Keystore-backed prefs are wiped on uninstall, so the
        // under-13 lock is also mirrored into Block Store (AgeGate,
        // BlockStoreDeviceLockMirror). Whether Block Store survives a
        // reinstall on every device is spike A8 (PRD F8 [ASSUMPTION]).
        aOptions: AndroidOptions(),
      );

  /// Keychain items that must never move to another phone through a backup
  /// (`first_unlock_this_device`), e.g. the Supabase session
  /// (SecureSessionStorage). Readable after the first unlock, so background
  /// work (widget refresh) still can.
  FlutterSecureStore.thisDeviceOnly()
    : _storage = const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
        aOptions: AndroidOptions(),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// MASVS F-3 (docs/security/masvs-l1.md, CRYPTO-2): key material never
/// travels to another phone.
///
/// The database key ([SecureKeys.dbKey]) and the per-user data keys
/// ([SecureKeys.dataKey]) live in [thisDevice] (iOS
/// `…AfterFirstUnlockThisDeviceOnly`), so they are left out of encrypted
/// iCloud / Finder backups and Quick Start transfers. Nothing is lost on a new
/// phone: the database file is excluded from backup anyway (G-1; the server
/// is the restore path, PRD 16), and the data key is fetched again from
/// `GET /v1/keys/data-key` after sign-in (it is wrapped server-side, DS-1).
/// "After first unlock" still lets the widget's background refresh read the
/// database key while the phone is locked.
///
/// Everything else (the under-13 device lock, the install id) stays in
/// [portable], as before.
///
/// Items written before this change (`first_unlock`) are moved on first read
/// ([migrate], iOS only): flutter_secure_storage finds an item at any
/// accessibility level and a write with the new level replaces it (delete +
/// add). If that write fails the value is written back to [portable], so the
/// database key is never lost (a lost key would reset the local database). A
/// marker item records the move, so it happens once. Headless background work
/// passes `migrate: false` and only reads.
class DeviceBoundKeyStore implements SecureStore {
  DeviceBoundKeyStore({
    required this._portable,
    required this._thisDevice,
    this.migrate = true,
    bool? movesOnThisPlatform,
  }) : _moves =
           movesOnThisPlatform ?? defaultTargetPlatform == TargetPlatform.iOS;

  /// The app's store on this phone.
  factory DeviceBoundKeyStore.platform({bool migrate = true}) =>
      DeviceBoundKeyStore(
        portable: FlutterSecureStore(),
        thisDevice: FlutterSecureStore.thisDeviceOnly(),
        migrate: migrate,
      );

  final SecureStore _portable;
  final SecureStore _thisDevice;
  final bool migrate;
  final bool _moves;
  final Set<String> _moved = {};

  /// Keys that must stay on this device.
  static bool isKeyMaterial(String key) =>
      key == SecureKeys.dbKey || key.startsWith('aura.data_key.');

  static String markerFor(String key) => 'aura.this_device.v1:$key';

  @override
  Future<String?> read(String key) async {
    if (!isKeyMaterial(key)) return _portable.read(key);
    final value = await _thisDevice.read(key);
    if (value == null || !migrate || !_moves || _moved.contains(key)) {
      return value;
    }
    if (await _thisDevice.read(markerFor(key)) != null) {
      _moved.add(key);
      return value;
    }
    try {
      await _thisDevice.write(key, value);
      await _thisDevice.write(markerFor(key), '1');
      _moved.add(key);
    } on Object catch (e) {
      debugPrint('secure: key move failed (${e.runtimeType})');
      try {
        if (await _thisDevice.read(key) == null) {
          await _portable.write(key, value);
        }
      } on Object catch (e2) {
        debugPrint('secure: key restore failed (${e2.runtimeType})');
      }
    }
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    if (!isKeyMaterial(key)) return _portable.write(key, value);
    await _thisDevice.write(key, value);
    if (_moves) {
      await _thisDevice.write(markerFor(key), '1');
      _moved.add(key);
    }
  }

  @override
  Future<void> delete(String key) async {
    if (!isKeyMaterial(key)) return _portable.delete(key);
    await _thisDevice.delete(key);
    await _thisDevice.delete(markerFor(key));
    _moved.remove(key);
  }
}

/// In-memory implementation for tests.
class MemorySecureStore implements SecureStore {
  MemorySecureStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
