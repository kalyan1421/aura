import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/secure_store.dart';
import '../../core/time/clock.dart';

/// A second home for the lock's date that survives an app reinstall where
/// secure storage doesn't (Android: Keystore-backed prefs are wiped on
/// uninstall). Never throws.
abstract interface class DeviceLockMirror {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

/// No mirror (iOS: the Keychain already survives a reinstall; tests).
class NoDeviceLockMirror implements DeviceLockMirror {
  const NoDeviceLockMirror();

  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

/// Android Block Store over `com.akvega.aura/device_lock` (MainActivity.kt):
/// device-only bytes outside the app's data (PRD F8 `[ASSUMPTION: confirm
/// persistence across reinstall]`, spike A8). Stores the ISO date only.
class BlockStoreDeviceLockMirror implements DeviceLockMirror {
  const BlockStoreDeviceLockMirror();

  static const MethodChannel _channel = MethodChannel(
    'com.akvega.aura/device_lock',
  );

  @override
  Future<String?> read() async {
    try {
      return await _channel.invokeMethod<String>('read');
    } on Object catch (e) {
      debugPrint('device lock: read ${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> write(String value) async {
    try {
      await _channel.invokeMethod<bool>('write', value);
    } on Object catch (e) {
      debugPrint('device lock: write ${e.runtimeType}');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<bool>('clear');
    } on Object catch (e) {
      debugPrint('device lock: clear ${e.runtimeType}');
    }
  }
}

/// The mirror for this platform.
DeviceLockMirror platformDeviceLockMirror() =>
    defaultTargetPlatform == TargetPlatform.android && !kIsWeb
    ? const BlockStoreDeviceLockMirror()
    : const NoDeviceLockMirror();

/// Tests replace it.
final deviceLockMirrorProvider = Provider<DeviceLockMirror>(
  (ref) => platformDeviceLockMirror(),
);

/// The under-13 device lock (F8, REQ-ACC-03). Nothing identifying is stored:
/// just the date until which the block screen shows. It lives in Keychain,
/// which survives an iOS reinstall; on Android it is mirrored into Block
/// Store ([DeviceLockMirror]) because the Keystore-backed copy is wiped on
/// uninstall. Either copy keeps the lock; an expired one clears both.
class AgeGate {
  AgeGate(
    this._secure,
    this._clock, [
    this._mirror = const NoDeviceLockMirror(),
  ]);

  final DeviceLockMirror _mirror;

  static const Duration lockDuration = Duration(days: 30);
  static const int minimumAge = 13;

  final SecureStore _secure;
  final Clock _clock;

  /// Lock expiry, or `null` when not blocked (expired locks are cleared).
  Future<DateTime?> blockedUntil() async {
    var raw = await _secure.read(SecureKeys.ageBlockUntil);
    final fromMirror = raw == null;
    raw ??= await _mirror.read();
    if (raw == null) return null;
    final until = DateTime.tryParse(raw);
    if (until == null || !until.isAfter(_clock.now())) {
      await _secure.delete(SecureKeys.ageBlockUntil);
      await _mirror.clear();
      return null;
    }
    // Back after a reinstall: restore the local copy too.
    if (fromMirror) await _secure.write(SecureKeys.ageBlockUntil, raw);
    return until;
  }

  Future<DateTime> block() async {
    final until = _clock.now().add(lockDuration);
    final value = until.toIso8601String();
    await _secure.write(SecureKeys.ageBlockUntil, value);
    await _mirror.write(value);
    return until;
  }

  /// Whole years between [birthDate] and [today] (calendar dates).
  static int ageOn(LocalDay birthDate, LocalDay today) {
    var age = today.year - birthDate.year;
    final hadBirthday =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthday) age -= 1;
    return age;
  }

  static bool isUnder13(LocalDay birthDate, LocalDay today) =>
      ageOn(birthDate, today) < minimumAge;
}
