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
        // TODO(android): Keystore-backed prefs are wiped on uninstall. Move the
        // under-13 lock to Android Block Store (persists across reinstall) —
        // PRD F8 marks this [ASSUMPTION: confirm persistence].
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
