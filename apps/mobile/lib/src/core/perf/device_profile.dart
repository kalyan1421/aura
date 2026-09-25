import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the OS says about this phone that decides the avatar's quality tier
/// (PRD F2 "Quality tiers": Low "on Android with ≤ 3 GB RAM, battery saver
/// on, or frames over budget for 2 s"; REQ-AVA-07 "On a 3 GB Android the Low
/// tier is chosen at launch"). Read once at launch and again on every resume
/// ("picked at launch and re-checked while running"). Nothing here leaves the
/// phone.
@immutable
class DeviceProfileInfo {
  const DeviceProfileInfo({
    required this.android,
    this.totalRamBytes,
    this.powerSave = false,
  });

  final bool android;

  /// Physical memory the OS reports (`ActivityManager.MemoryInfo.totalMem`;
  /// `ProcessInfo.physicalMemory`). `null` when unknown.
  final int? totalRamBytes;

  /// Battery saver (Android) / Low Power Mode (iOS).
  final bool powerSave;

  /// A phone sold as "3 GB" reports about 2.7–2.9 × 10⁹ bytes and a "4 GB"
  /// one about 3.6–3.8 × 10⁹ (the kernel keeps some), so the line sits
  /// between them.
  static const int lowRamBytes = 3300000000;

  /// The PRD rule. Unknown memory never lowers the tier.
  bool get prefersLowTier =>
      powerSave ||
      (android && totalRamBytes != null && totalRamBytes! <= lowRamBytes);
}

/// Reads [DeviceProfileInfo] over `com.akvega.aura/platform` `deviceProfile`
/// (MainActivity.kt, AppDelegate.swift) and publishes whether the Low tier
/// is preferred. Tests (and platforms without the call) keep `false`.
class DeviceProfile {
  DeviceProfile._();

  static final DeviceProfile instance = DeviceProfile._();

  static const MethodChannel _channel = MethodChannel(
    'com.akvega.aura/platform',
  );

  /// True while the phone asks for the Low tier.
  final ValueNotifier<bool> prefersLowTier = ValueNotifier(false);

  /// Asks the OS again; never throws.
  Future<void> refresh() async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>(
        'deviceProfile',
      );
      if (r == null) return;
      apply(
        DeviceProfileInfo(
          android: defaultTargetPlatform == TargetPlatform.android,
          totalRamBytes: (r['totalRamBytes'] as num?)?.toInt(),
          powerSave: r['powerSave'] == true,
        ),
      );
    } on Object catch (e) {
      debugPrint('platform: deviceProfile ${e.runtimeType}');
    }
  }

  @visibleForTesting
  void apply(DeviceProfileInfo info) =>
      prefersLowTier.value = info.prefersLowTier;

  @visibleForTesting
  void reset() => prefersLowTier.value = false;
}
