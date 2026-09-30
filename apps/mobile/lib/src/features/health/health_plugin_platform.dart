import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:health/health.dart';

import 'platform_health_source.dart';

/// [HealthPlatform] over the `health` plugin: steps, read access only.
class HealthPluginPlatform implements HealthPlatform {
  HealthPluginPlatform([Health? health]) : _health = health ?? Health();

  final Health _health;

  static const _types = [HealthDataType.STEPS];
  static const _read = [HealthDataAccess.READ];

  @override
  bool get isIos => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> configure() => _health.configure();

  @override
  Future<bool> healthConnectAvailable() async =>
      await _health.getHealthConnectSdkStatus() ==
      HealthConnectSdkStatus.sdkAvailable;

  @override
  Future<bool?> hasStepsAccess() =>
      _health.hasPermissions(_types, permissions: _read);

  @override
  Future<bool> requestStepsAccess() =>
      _health.requestAuthorization(_types, permissions: _read);

  @override
  Future<int?> totalSteps(DateTime start, DateTime end) =>
      _health.getTotalStepsInInterval(start, end);
}
