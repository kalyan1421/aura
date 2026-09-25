import 'package:meta/meta.dart';

/// App versions for the forced-update rule (RULES.md §12, `app_version.json`;
/// MASVS F-6). The server (`src/remote-config/app-version.ts`) runs the same
/// vectors.
///
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

/// Whether [installed] must update to reach [minimum]. Unknown on either side
/// → no (fail open: an unreadable version never blocks the app).
bool isUpdateRequired(AppVersion? installed, AppVersion? minimum) =>
    installed != null && minimum != null && installed < minimum;
