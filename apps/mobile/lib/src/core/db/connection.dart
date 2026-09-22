import 'dart:io';
import 'dart:math';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../security/secure_store.dart';
import 'database.dart';

const String _dbName = 'aura';

/// Opens the encrypted on-device database.
///
/// Engine: SQLite3MultipleCiphers, selected via the `sqlite3` build hook in
/// pubspec.yaml (`hooks.user_defines.sqlite3.source: sqlite3mc`). The key is
/// 32 random bytes generated on first launch and kept in Keychain/Keystore.
///
/// If the file cannot be opened with the stored key (e.g. the Keychain was
/// reset but the file survived), the file is replaced: the server is the
/// restore path (PRD Offline "Local store").
///
/// TODO(backup): exclude the database file from iCloud backup
/// (NSURLIsExcludedFromBackupKey); Android sets allowBackup=false.
Future<AppDatabase> openAppDatabase(SecureStore secure) async {
  final key = await _databaseKey(secure);
  var db = _open(key);
  try {
    await db.customSelect('SELECT count(*) FROM sqlite_master').get();
    return db;
  } catch (e) {
    debugPrint('db: could not open with stored key (${e.runtimeType}); resetting');
    await db.close();
    final dir = await getApplicationSupportDirectory();
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('${dir.path}/$_dbName.sqlite$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    db = _open(key);
    await db.customSelect('SELECT 1').get();
    return db;
  }
}

AppDatabase _open(String key) => AppDatabase(
  driftDatabase(
    name: _dbName,
    native: DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
      setup: (db) {
        // Must be the first statement on the connection.
        db.execute("PRAGMA key = '$key';");
      },
    ),
  ),
);

Future<String> _databaseKey(SecureStore secure) async {
  final existing = await secure.read(SecureKeys.dbKey);
  if (existing != null && existing.length == 64) return existing;
  final rnd = Random.secure();
  final hex = List<int>.generate(
    32,
    (_) => rnd.nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await secure.write(SecureKeys.dbKey, hex);
  return hex;
}
