import 'package:aura_domain/aura_domain.dart';

/// Injectable time source (tests pin it).
class Clock {
  const Clock();

  DateTime now() => DateTime.now().toUtc();
}

class FixedClock extends Clock {
  FixedClock(this.instant);

  DateTime instant;

  @override
  DateTime now() => instant.toUtc();
}

/// The user's time context: IANA zone + clock. All day stamps go through here
/// so the app and the server agree on the Aura day (RULES.md section 1).
class TimeContext {
  const TimeContext({required this.clock, required this.timezone});

  final Clock clock;

  /// Device IANA zone, e.g. `Asia/Kolkata`.
  final String timezone;

  DateTime now() => clock.now();

  LocalDay today() => auraDay(clock.now(), timezone);

  LocalDay dayOf(DateTime instant) => auraDay(instant, timezone);

  int offsetMinutes(DateTime instant) =>
      utcOffsetAt(instant, timezone).inMinutes;
}
