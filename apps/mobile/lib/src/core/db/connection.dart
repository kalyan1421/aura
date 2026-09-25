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
    debugPrint(
      'db: could not open with stored key (${e.runtimeType}); resetting',
    );
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

/// Opens the database only if this phone already has it and its key: for
/// headless background work (F11 widget refresh), which must never create a
/// key, reset a file it can't open, or race the app's first launch. Returns
/// null (and leaves everything as it was) when any of that would be needed,
/// e.g. the Keychain isn't readable yet.
Future<AppDatabase?> openExistingAppDatabase(SecureStore secure) async {
  try {
    final key = await secure.read(SecureKeys.dbKey);
    if (key == null || key.length != 64) return null;
    final dir = await getApplicationSupportDirectory();
    if (!File('${dir.path}/$_dbName.sqlite').existsSync()) return null;
    final db = _open(key);
    try {
      await db.customSelect('SELECT count(*) FROM sqlite_master').get();
      return db;
    } catch (e) {
      await db.close();
      debugPrint('db: background open failed (${e.runtimeType})');
      return null;
    }
  } catch (e) {
    debugPrint('db: background open failed (${e.runtimeType})');
    return null;
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
