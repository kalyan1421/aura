import 'package:meta/meta.dart';

import 'avatar/aura_avatar_state.dart';
import 'avatar/aura_stage.dart';
import 'catalog.g.dart';
import 'local_day.dart';
import 'rules/aura_day.dart';
import 'rules/progression.dart';
import 'rules/streak.dart';

/// Kind of a progression event.
enum ProgressKind { checkIn, habit }

/// A stored check-in or habit completion, as the projection sees it.
@immutable
final class ProgressEvent {
  const ProgressEvent.checkIn({
    required this.id,
    required this.deviceTs,
    required this.localDay,
    required Quadrant this.quadrant,
    this.timezone,
    this.deleted = false,
  }) : kind = ProgressKind.checkIn,
       habitId = null,
       habitKey = null;

  const ProgressEvent.habit({
    required this.id,
    required this.deviceTs,
    required this.localDay,
    required String this.habitId,
    this.habitKey,
    this.timezone,
    this.deleted = false,
  }) : kind = ProgressKind.habit,
       quadrant = null;

  final String id;
  final ProgressKind kind;
  final DateTime deviceTs;
  final LocalDay localDay;
  final Quadrant? quadrant;
  final String? habitId;

  /// Preset key (`breathe`, `sleep_on_time`, …) for trait counts.
  final String? habitKey;

  /// IANA zone the event was stamped in (its `localDay` is the Aura day in
  /// this zone). Eligibility is judged here, so an event made in New York is
  /// still judged in New York after the phone returns to IST. `null` → the
  /// projection's current zone.
  final String? timezone;

  /// Deleted check-ins keep their Starlight and glow day, but leave the hue.
  final bool deleted;
}

/// The provisional (on-device) progression, computed with the same rules the
/// server runs. The server snapshot replaces it after sync (DS-5).
@immutable
final class ProgressProjection {
  const ProgressProjection({
    required this.today,
    required this.totalStarlight,
    required this.todayStarlight,
    required this.streak,
    required this.avatar,
    required this.awards,
    required this.breatheCompletions,
    required this.sleepCompletions,
    required this.hue,
  });

  final LocalDay today;
  final int totalStarlight;
  final int todayStarlight;
  final StreakState streak;
  final AuraAvatarState avatar;

  /// Starlight awarded per event id.
  final Map<String, int> awards;

  /// Distinct credited days of Breathe / Sleep on time (trait inputs).
  final int breatheCompletions;
  final int sleepCompletions;

  /// Mood-mix hue, or `null` when there is no recent data.
  final double? hue;

  AuraStage get stage => avatar.stage;
}

/// Projects Starlight, streak and avatar from local [events].
///
/// [now] stands in for server time (provisional credit); "today" is the Aura
/// day of [now] in [timezone], while each event is judged in its own stamped
/// zone. [previousHue] is held when the 14-day mix is empty.
ProgressProjection projectProgress({
  required Iterable<ProgressEvent> events,
  required DateTime now,
  required String timezone,
  double? previousHue,
  Set<CosmeticId> equippedCosmetics = const {},
  StreakState initialStreak = StreakState.initial,
}) {
  final today = auraDay(now, timezone);
  final byDay = <LocalDay, List<(ProgressEvent, bool)>>{};
  final activeDays = <LocalDay>{};
  // Traits count distinct credited days (contracts/api/v1.md "Rings/glow").
  final breatheDays = <LocalDay>{};
  final sleepDays = <LocalDay>{};

  for (final e in events) {
    final eligible = isEligible(
      deviceTs: e.deviceTs,
      serverNow: now,
      timezone: e.timezone ?? timezone,
      localDay: e.localDay,
    );
    byDay.putIfAbsent(e.localDay, () => []).add((e, eligible));
    if (!eligible) continue;
    activeDays.add(e.localDay);
    if (e.kind == ProgressKind.habit) {
      if (e.habitKey == PresetHabitKeys.breathe) breatheDays.add(e.localDay);
      if (e.habitKey == PresetHabitKeys.sleepOnTime) sleepDays.add(e.localDay);
    }
  }

  final awards = <String, int>{};
  var total = 0;
  var todayTotal = 0;
  for (final entry in byDay.entries) {
    final dayEvents = entry.value
      ..sort((a, b) {
        final c = a.$1.deviceTs.compareTo(b.$1.deviceTs);
        return c != 0 ? c : a.$1.id.compareTo(b.$1.id);
      });
    final dayAwards = starlightAwards(
      dayEvents.map(
        (p) => p.$1.kind == ProgressKind.checkIn
            ? StarlightEvent.checkIn(eligible: p.$2)
            : StarlightEvent.habit(p.$1.habitId!, eligible: p.$2),
      ),
    );
    for (var i = 0; i < dayEvents.length; i++) {
      awards[dayEvents[i].$1.id] = dayAwards[i];
      total += dayAwards[i];
      if (entry.key == today) todayTotal += dayAwards[i];
    }
  }

  final streak = foldStreak(initialStreak, activeDays);
  final hue = hueFromCheckIns(
    events
        .where((e) => e.kind == ProgressKind.checkIn && !e.deleted)
        .map((e) => (day: e.localDay, quadrant: e.quadrant!)),
    today,
  );

  return ProgressProjection(
    today: today,
    totalStarlight: total,
    todayStarlight: todayTotal,
    streak: streak,
    breatheCompletions: breatheDays.length,
    sleepCompletions: sleepDays.length,
    awards: Map.unmodifiable(awards),
    hue: hue,
    avatar: AuraAvatarState(
      stage: stageFor(total),
      hue: hue ?? previousHue ?? AuraAvatarState.defaultHue,
      isResting: isResting(streak.lastActiveDay, today),
      ringCount: traitLevel(breatheDays.length),
      glowLevel: traitLevel(sleepDays.length),
      constellationStars: constellationStarsFor(total),
      equippedCosmetics: equippedCosmetics,
    ),
  );
}

/// One-shot avatar moments. They are events, not state: each has an id and
/// plays once per id.
enum AvatarMomentKind { evolve, wakeUp, celebrate }

@immutable
final class AvatarMoment {
  const AvatarMoment(this.id, this.kind);

  final String id;
  final AvatarMomentKind kind;

  @override
  bool operator ==(Object other) =>
      other is AvatarMoment && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);

  @override
  String toString() => 'AvatarMoment(${kind.name}, $id)';
}

/// Moments caused by moving from [before] to [after]; [causeId] is the id of
/// the event (e.g. the check-in) that caused the change, so a replay on
/// another device never plays it twice.
List<AvatarMoment> momentsBetween(
  AuraAvatarState before,
  AuraAvatarState after, {
  required String causeId,
}) => [
  if (before.isResting && !after.isResting)
    AvatarMoment('wake:$causeId', AvatarMomentKind.wakeUp),
  if (after.stage.index > before.stage.index)
    AvatarMoment('evolve:${after.stage.name}', AvatarMomentKind.evolve),
];
