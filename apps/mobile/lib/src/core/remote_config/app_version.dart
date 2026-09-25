import 'package:flutter/foundation.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/services.dart';

export 'package:aura_domain/aura_domain.dart' show AppVersion, isUpdateRequired;

/// Minimum supported app version (MASVS-CODE-2, docs/security/masvs-l1.md
/// F-6; contracts/api/v1.md "Remote config" `minAppVersion`).
///
/// `GET /v1/config` may carry `minAppVersion: {"ios": "1.2.0", "android":
/// "1.2.0"}`. When this install is older than its platform's value the router
/// shows the calm "Please update Aura" screen (features/update), keeps
/// "I need help now" reachable, and never deletes anything on the phone.
/// [AppVersion] and [isUpdateRequired] are the shared rule (RULES.md §12,
/// packages/aura_domain), the same vectors as the server.

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
