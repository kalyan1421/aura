import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../local_day.dart';

/// Hour of the local day at which the Aura day rolls over (RULES.md section 1).
const int auraDayRolloverHour = 4;

bool _tzReady = false;
final Map<String, tz.Location> _locations = {};

/// Loads the bundled IANA database (all zones, incl. legacy aliases such as
/// `Asia/Calcutta` that some Android builds still report). Idempotent.
void ensureTimeZonesLoaded() {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  _tzReady = true;
}

/// Whether [ianaTz] is a zone in the bundled database.
bool isKnownTimeZone(String ianaTz) {
  ensureTimeZonesLoaded();
  try {
    tz.getLocation(ianaTz);
    return true;
  } on tz.LocationNotFoundException {
    return false;
  }
}

final Set<String> _warnedUnknown = {};

tz.Location _location(String ianaTz) {
  ensureTimeZonesLoaded();
  return _locations.putIfAbsent(ianaTz, () {
    try {
      return tz.getLocation(ianaTz);
    } on tz.LocationNotFoundException {
      // Callers must resolve device zones first (resolveTimeZone), so the app
      // and the server judge days in the same zone. This is only a defensive
      // net: loud in debug, UTC in release.
      if (_warnedUnknown.add(ianaTz)) {
        // ignore: avoid_print
        print('aura_domain: unknown IANA zone "$ianaTz"; using UTC');
      }
      assert(
        false,
        'Unknown IANA zone "$ianaTz". Resolve it with resolveTimeZone() first.',
      );
      return tz.UTC;
    }
  });
}

/// Zones for UTC offsets that are not whole hours (no `Etc/GMT` zone exists
/// for them). Nearest well-known zone for that standard offset.
const Map<int, String> _fractionalOffsetZones = {
  -570: 'Pacific/Marquesas', // −9:30
  -210: 'America/St_Johns', // −3:30
  210: 'Asia/Tehran', // +3:30
  270: 'Asia/Kabul', // +4:30
  330: 'Asia/Kolkata', // +5:30
  345: 'Asia/Kathmandu', // +5:45
  390: 'Asia/Yangon', // +6:30
  525: 'Australia/Eucla', // +8:45
  570: 'Australia/Darwin', // +9:30
  630: 'Australia/Lord_Howe', // +10:30
  765: 'Pacific/Chatham', // +12:45
};

/// Resolves the device's zone to an id the bundled database knows, so the
/// app and the server always use the same zone.
///
/// - A known IANA id is returned as is.
/// - Otherwise a fixed-offset zone from [currentOffset]: whole hours map to
///   `Etc/GMT±N` (POSIX sign is inverted: UTC+5 → `Etc/GMT-5`); other
///   offsets map to the nearest well-known zone (+5:30 → `Asia/Kolkata`).
/// - Anything else → `UTC`.
String resolveTimeZone(String? deviceZone, Duration currentOffset) {
  if (deviceZone != null &&
      deviceZone.isNotEmpty &&
      isKnownTimeZone(deviceZone)) {
    return deviceZone;
  }
  final minutes = currentOffset.inMinutes;
  if (minutes == 0) return 'UTC';
  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    final id = hours > 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}';
    if (isKnownTimeZone(id)) return id;
  }
  final named = _fractionalOffsetZones[minutes];
  if (named != null && isKnownTimeZone(named)) return named;
  return 'UTC';
}

/// The Aura day of [instant] in [ianaTz]:
/// `date(toLocal(instant, tz) − 4h)` — the day rolls over at 04:00 local.
///
/// The subtraction is on the local wall clock, so the rollover is always at
/// 04:00 local even on DST-change days.
LocalDay auraDay(DateTime instant, String ianaTz) {
  final local = tz.TZDateTime.from(instant.toUtc(), _location(ianaTz));
  final date = LocalDay(local.year, local.month, local.day);
  return local.hour < auraDayRolloverHour ? date.addDays(-1) : date;
}

/// The local UTC offset of [ianaTz] at [instant] (for `tz_offset` stamps).
Duration utcOffsetAt(DateTime instant, String ianaTz) =>
    tz.TZDateTime.from(instant.toUtc(), _location(ianaTz)).timeZoneOffset;
