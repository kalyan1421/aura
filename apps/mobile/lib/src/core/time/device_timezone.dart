import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// The device's IANA zone, resolved to an id the bundled tz database knows
/// (unknown ids become a fixed-offset zone such as `Etc/GMT-5`, never a
/// silent UTC). The same id goes into the profile and every mutation, so the
/// app and the server judge Aura days in the same zone.
Future<String> resolveDeviceTimezone() async {
  String? id;
  try {
    id = (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (e) {
    debugPrint('timezone: ${e.runtimeType}');
  }
  final resolved = resolveTimeZone(id, DateTime.now().timeZoneOffset);
  if (id != null && resolved != id) {
    debugPrint('timezone: "$id" unknown, using $resolved');
  }
  return resolved;
}
