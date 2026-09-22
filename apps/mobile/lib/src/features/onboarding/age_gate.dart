import 'package:aura_domain/aura_domain.dart';

import '../../core/security/secure_store.dart';
import '../../core/time/clock.dart';

/// The under-13 device lock (F8, REQ-ACC-03). Nothing identifying is stored:
/// just the date until which the block screen shows. It lives in Keychain,
/// which survives an iOS reinstall.
class AgeGate {
  AgeGate(this._secure, this._clock);

  static const Duration lockDuration = Duration(days: 30);
  static const int minimumAge = 13;

  final SecureStore _secure;
  final Clock _clock;

  /// Lock expiry, or `null` when not blocked (expired locks are cleared).
  Future<DateTime?> blockedUntil() async {
    final raw = await _secure.read(SecureKeys.ageBlockUntil);
    if (raw == null) return null;
    final until = DateTime.tryParse(raw);
    if (until == null || !until.isAfter(_clock.now())) {
      await _secure.delete(SecureKeys.ageBlockUntil);
      return null;
    }
    return until;
  }

  Future<DateTime> block() async {
    final until = _clock.now().add(lockDuration);
    await _secure.write(SecureKeys.ageBlockUntil, until.toIso8601String());
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
