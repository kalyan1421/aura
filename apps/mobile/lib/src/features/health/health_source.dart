/// What the platform's health store offers this phone (W06).
enum HealthAvailability {
  /// No health store, or this build has no adapter for it: the app shows
  /// nothing about health.
  unavailable,

  /// A store exists and the person has not granted (or refused) access yet.
  needsPermission,

  /// Access is granted.
  ready,
}

/// The one door to the platform's health store (HealthKit on iOS, Health
/// Connect on Android). Read-only, steps only, one number for today, computed
/// on the phone. The app never keeps it, logs it, uploads it or shows it: it
/// only decides how many path stones glow (RULES.md section 13 `stones`).
///
/// A platform adapter implements this. Until one is installed, the default
/// [UnavailableHealthSource] keeps every health surface hidden.
abstract interface class HealthSource {
  Future<HealthAvailability> availability();

  /// Shows the system permission prompt for reading steps. `true` when access
  /// is granted; `false` when refused or unsupported. Never throws.
  Future<bool> requestStepsAccess();

  /// Today's step count in [timezone], or `null` when it is unknown. Never
  /// throws.
  Future<int?> stepsToday(DateTime now, String timezone);
}

/// The default: this build has no health adapter.
class UnavailableHealthSource implements HealthSource {
  const UnavailableHealthSource();

  @override
  Future<HealthAvailability> availability() async =>
      HealthAvailability.unavailable;

  @override
  Future<bool> requestStepsAccess() async => false;

  @override
  Future<int?> stepsToday(DateTime now, String timezone) async => null;
}
