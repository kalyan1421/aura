import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Minimum supported app version (MASVS-CODE-2, docs/security/masvs-l1.md
/// F-6; contracts/api/v1.md "Remote config" `minAppVersion`).
///
/// `GET /v1/config` may carry `minAppVersion: {"ios": "1.2.0", "android":
/// "1.2.0"}`. When this install is older than its platform's value the app
/// shows the calm "Please update Aura" screen (features/update), keeps
/// "I need help now" reachable, and never deletes anything on the phone.
///
/// Format and comparison match the server (`src/remote-config/app-version.ts`):
/// `MAJOR[.MINOR[.PATCH]][+BUILD]`, compared numerically part by part
/// (missing parts are 0); BUILD only breaks a tie, and only when both sides
/// have one.
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, [this.minor = 0, this.patch = 0, this.build]);

  static final RegExp _pattern = RegExp(
    r'^(\d{1,5})(?:\.(\d{1,5}))?(?:\.(\d{1,5}))?(?:\+(\d{1,9}))?$',
  );

  /// Null for anything that isn't `x[.y[.z]][+build]`.
  static AppVersion? tryParse(Object? value) {
    if (value is! String) return null;
    final m = _pattern.firstMatch(value.trim());
    if (m == null) return null;
    return AppVersion(
      int.parse(m.group(1)!),
      int.parse(m.group(2) ?? '0'),
      int.parse(m.group(3) ?? '0'),
      m.group(4) == null ? null : int.parse(m.group(4)!),
    );
  }

  final int major;
  final int minor;
  final int patch;
  final int? build;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    final a = build;
    final b = other.build;
    if (a == null || b == null) return 0;
    return a.compareTo(b);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch &&
      other.build == build;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => '$major.$minor.$patch${build == null ? '' : '+$build'}';
}

/// The server's minimum per platform (`ios`, `android`); empty = none.
@immutable
class MinAppVersions {
  const MinAppVersions([this._values = const {}]);

  /// From the `minAppVersion` object; unknown platforms and malformed values
  /// are dropped (a typo on the server never locks anyone out).
  factory MinAppVersions.fromJson(Object? json) {
    if (json is! Map) return none;
    return MinAppVersions({
      for (final p in const ['ios', 'android'])
        p: ?AppVersion.tryParse(json[p]),
    });
  }

  static const MinAppVersions none = MinAppVersions();

  final Map<String, AppVersion> _values;

  AppVersion? forPlatform(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS => _values['ios'],
    TargetPlatform.android => _values['android'],
    _ => null,
  };

  bool get isEmpty => _values.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is MinAppVersions && mapEquals(other._values, _values);

  @override
  int get hashCode => Object.hashAllUnordered(
    _values.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// Whether [installed] must update to reach [minimum]. Unknown on either side
/// → no (fail open: an unreadable version never blocks the app).
bool isUpdateRequired(AppVersion? installed, AppVersion? minimum) =>
    installed != null && minimum != null && installed < minimum;

/// This install's version as the OS knows it (CFBundleShortVersionString +
/// CFBundleVersion; Android versionName + versionCode), i.e. pubspec
/// `version`. Not [Env.appVersion], which is hand-kept for display.
abstract interface class InstalledVersionReader {
  Future<AppVersion?> read();
}

/// Over `com.akvega.aura/platform` `appVersion` (AppDelegate.swift,
/// MainActivity.kt). Null when the platform can't say (tests, desktop).
class ChannelInstalledVersionReader implements InstalledVersionReader {
  const ChannelInstalledVersionReader();

  static const MethodChannel _channel = MethodChannel(
    'com.akvega.aura/platform',
  );

  @override
  Future<AppVersion?> read() async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('appVersion');
      final version = AppVersion.tryParse(r?['version']);
      if (version == null) return null;
      final build = int.tryParse('${r?['build'] ?? ''}');
      return AppVersion(version.major, version.minor, version.patch, build);
    } on Object catch (e) {
      debugPrint('platform: appVersion ${e.runtimeType}');
      return null;
    }
  }
}
