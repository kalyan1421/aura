import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../security/secure_store.dart';

/// A stable, random identifier for this app install (PRD 19 REQ-ADM-14
/// "bans account and device"; contracts/api/v1.md "Device bans").
///
/// - 32 random bytes, made once and kept in secure storage: the iOS Keychain
///   keeps it when the app is deleted and reinstalled; on Android it goes with
///   the app (uninstall or "Clear storage" makes a new one) —
///   docs/setup/lexicon-and-flags.md. It is never derived from hardware and is
///   not the sync `deviceId` (that one lives in the database and is wiped with
///   it).
/// - Sent only as `X-Aura-Install` (+ `X-Aura-Platform`) on the calls that
///   decide whether this phone may use Aura: `POST /v1/profile` (sign-in /
///   onboarding), `PUT /v1/devices` (push registration) and
///   `POST /v1/rooms/match`. The server keeps only an HMAC of it.
/// - Never logged, never sent to analytics or crash reports, and kept across
///   sign-outs (it identifies the phone, not the person).
///
/// DeviceCheck / Play Integrity attestation is the later hardening (it needs
/// Apple and Google keys); until then a modified app can leave the header
/// out, so a device ban stops ordinary reinstalls and new accounts, not a
/// determined attacker.
class InstallId {
  InstallId(this._secure, {Random? random})
    : _random = random ?? Random.secure();

  /// Secure-storage key (device-scoped; sign-out keeps it).
  static const String secureKey = 'aura.install_id.v1';

  static const String header = 'X-Aura-Install';
  static const String platformHeader = 'X-Aura-Platform';

  final SecureStore _secure;
  final Random _random;
  Future<String?>? _value;

  /// The id, created on first use. `null` only when secure storage fails
  /// (the calls then go without it).
  Future<String?> value() => _value ??= _load();

  Future<String?> _load() async {
    try {
      final existing = await _secure.read(secureKey);
      if (existing != null && _valid.hasMatch(existing)) return existing;
      final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
      final id = base64Url.encode(bytes).replaceAll('=', '');
      await _secure.write(secureKey, id);
      return id;
    } on Object catch (e) {
      debugPrint('install id: ${e.runtimeType}');
      _value = null; // try again next time
      return null;
    }
  }

  /// The headers for the calls listed above (empty if there is no id).
  Future<Map<String, String>> headers() async {
    final id = await value();
    if (id == null) return const {};
    return {header: id, platformHeader: ?_platform()};
  }

  static String? _platform() {
    if (kIsWeb) return null;
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return null;
  }

  static final RegExp _valid = RegExp(r'^[A-Za-z0-9_-]{22,86}$');
}
