import 'package:aura_domain/aura_domain.dart' show utcOffsetAt;
import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/db/kv_store.dart';
import 'health_source.dart';

/// The few platform calls the step adapter needs, so its logic runs in tests
/// without a device. The real one wraps the `health` plugin
/// ([HealthPluginPlatform]).
abstract interface class HealthPlatform {
  /// iOS (HealthKit) rather than Android (Health Connect).
  bool get isIos;

  Future<void> configure();

  /// Android only: Health Connect is installed and usable.
  Future<bool> healthConnectAvailable();

  /// Whether reading steps is allowed. `null` on iOS: HealthKit deliberately
  /// hides whether a read permission was granted.
  Future<bool?> hasStepsAccess();

  /// Shows the system prompt. On iOS `true` only means the sheet was shown.
  Future<bool> requestStepsAccess();

  /// Steps between [start] and [end], or `null`.
  Future<int?> totalSteps(DateTime start, DateTime end);
}

/// Midnight (start of the calendar day) at [now] in [timezone], as an instant.
/// The offset is read again at that midnight, so a day on which the clocks
/// change starts at the right moment (an hour off would count yesterday's
/// steps or miss this morning's).
DateTime localMidnight(DateTime now, String timezone) {
  final local = now.toUtc().add(utcOffsetAt(now, timezone));
  final wall = DateTime.utc(local.year, local.month, local.day);
  final guess = wall.subtract(utcOffsetAt(now, timezone));
  return wall.subtract(utcOffsetAt(guess, timezone));
}

/// [HealthSource] over the platform's health store: read-only, steps only, one
/// number for today. It never keeps, logs or sends the number; every failure
/// (no store, no plugin, no access) reads as "unavailable" or "unknown", never
/// as an error the person sees.
class PlatformHealthSource implements HealthSource {
  PlatformHealthSource({required this._platform, required this._kv});

  final HealthPlatform _platform;
  final KvStore _kv;
  bool _configured = false;

  Future<void> _ready() async {
    if (_configured) return;
    await _platform.configure();
    _configured = true;
  }

  @override
  Future<HealthAvailability> availability() async {
    try {
      await _ready();
      if (_platform.isIos) {
        // HealthKit will not say whether a read was allowed, so the app only
        // knows whether it has asked. Denied reads simply return no steps.
        return await _kv.get(KvKeys.healthAsked) == '1'
            ? HealthAvailability.ready
            : HealthAvailability.needsPermission;
      }
      if (!await _platform.healthConnectAvailable()) {
        return HealthAvailability.unavailable;
      }
      return await _platform.hasStepsAccess() == true
          ? HealthAvailability.ready
          : HealthAvailability.needsPermission;
    } on Object catch (e) {
      debugPrint('health: availability ${e.runtimeType}');
      return HealthAvailability.unavailable;
    }
  }

  @override
  Future<bool> requestStepsAccess() async {
    try {
      await _ready();
      final shown = await _platform.requestStepsAccess();
      if (_platform.isIos) {
        // The sheet is shown once by the system; afterwards a read either
        // works or returns nothing.
        await _kv.set(KvKeys.healthAsked, '1');
        return shown;
      }
      return shown && await _platform.hasStepsAccess() == true;
    } on Object catch (e) {
      debugPrint('health: request ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<int?> stepsToday(DateTime now, String timezone) async {
    try {
      await _ready();
      return await _platform.totalSteps(localMidnight(now, timezone), now);
    } on Object catch (e) {
      debugPrint('health: steps ${e.runtimeType}');
      return null;
    }
  }
}
