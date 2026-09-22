import 'package:meta/meta.dart';

/// A calendar date with no time or zone (`YYYY-MM-DD`), e.g. an Aura day.
///
/// Day arithmetic runs on UTC midnights, so it is exact (no DST drift).
@immutable
final class LocalDay implements Comparable<LocalDay> {
  const LocalDay(this.year, this.month, this.day);

  /// Normalises overflowing parts (e.g. day 32) like [DateTime] does.
  factory LocalDay.fromDateTime(DateTime dt) {
    final u = DateTime.utc(dt.year, dt.month, dt.day);
    return LocalDay(u.year, u.month, u.day);
  }

  /// Parses `YYYY-MM-DD` (throws [FormatException] otherwise).
  factory LocalDay.parse(String iso) {
    final m = _iso.firstMatch(iso.trim());
    if (m == null) throw FormatException('Not a YYYY-MM-DD day', iso);
    return LocalDay.fromDateTime(
      DateTime.utc(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      ),
    );
  }

  static LocalDay? tryParse(String? iso) {
    if (iso == null) return null;
    try {
      return LocalDay.parse(iso);
    } on FormatException {
      return null;
    }
  }

  static final RegExp _iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

  final int year;
  final int month;
  final int day;

  DateTime get _midnight => DateTime.utc(year, month, day);

  /// Whole days from [other] to this (`this − other`).
  int daysSince(LocalDay other) => _midnight.difference(other._midnight).inDays;

  LocalDay addDays(int days) =>
      LocalDay.fromDateTime(DateTime.utc(year, month, day + days));

  bool isBefore(LocalDay other) => compareTo(other) < 0;
  bool isAfter(LocalDay other) => compareTo(other) > 0;

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDay other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
