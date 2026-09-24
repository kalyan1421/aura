import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/kv_store.dart';
import '../../core/ids/ids.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/time/clock.dart';
import '../onboarding/gate_controller.dart';
import 'breath_pacer.dart';
import 'breathe_session_screen.dart' show BreathGuide;
import 'habit_auto_complete.dart' show habitAutoCompleteAllowed;
import 'steps_activity_screen.dart' show StepsActivity;

/// F15 session records (PRD 06d: "A finished activity writes one
/// content-free session record (activity, pattern, duration, Aura day)
/// through POST /v1/sync/push"; 10-data-model `sanctuary_sessions`;
/// contracts/api/v1.md "Sanctuary sessions").
///
/// Content-free by construction: an activity and a variant from closed
/// lists, whole seconds and the Aura day it started. Nothing typed, said or
/// picked inside an activity exists here. Offline it waits in the outbox
/// like every other write.
@immutable
class SanctuarySession {
  const SanctuarySession({
    required this.activity,
    required this.variant,
    required this.durationS,
    required this.localDay,
  });

  /// One of [SessionActivities].
  final String activity;

  /// One of the activity's variants (see [SessionActivities]).
  final String variant;

  /// Seconds actually spent (paused / background time excluded).
  final int durationS;

  /// The Aura day the activity started.
  final LocalDay localDay;

  Map<String, Object?> payload(String id) => {
    'id': id,
    'activity': activity,
    'variant': variant,
    'durationS': durationS,
  };

  @override
  bool operator ==(Object other) =>
      other is SanctuarySession &&
      other.activity == activity &&
      other.variant == variant &&
      other.durationS == durationS &&
      other.localDay == localDay;

  @override
  int get hashCode => Object.hash(activity, variant, durationS, localDay);

  @override
  String toString() =>
      'SanctuarySession($activity/$variant, ${durationS}s, $localDay)';
}

/// The server's activity names (`sanctuary_sessions.activity`) and how the
/// app's features map onto them:
///
/// | app | activity | variant |
/// |---|---|---|
/// | Breathe, Calm / Box / 4-7-8 minutes | `breathe` | `calm` · `box` · `478` |
/// | Storm's three slow breaths | `grounding` | `land` |
/// | Hand on heart | `grounding` | `heart` |
/// | 5-4-3-2-1 | `grounding` | `senses` |
/// | Gratitude | `grounding` | `gratitude` |
/// | Stillness | `stillness` | `orb` |
/// | Savour | `savour` | `moment` |
/// | Sounds | `sounds` | `open` · `timer_15` · `timer_30` · `timer_60` |
/// | Night wind-down | `night_wind_down` | `v1` |
abstract final class SessionActivities {
  static const String breathe = 'breathe';
  static const String grounding = 'grounding';
  static const String stillness = 'stillness';
  static const String savour = 'savour';
  static const String sounds = 'sounds';
  static const String nightWindDown = 'night_wind_down';
}

/// (activity, variant) of a paced breathing session.
({String activity, String variant}) breathSessionKind(
  BreathGuide guide,
  BreathPattern pattern,
) => switch (guide) {
  BreathGuide.breathe => (
    activity: SessionActivities.breathe,
    variant: pattern.id,
  ),
  BreathGuide.land => (activity: SessionActivities.grounding, variant: 'land'),
  BreathGuide.heart => (
    activity: SessionActivities.grounding,
    variant: 'heart',
  ),
  BreathGuide.stillness => (
    activity: SessionActivities.stillness,
    variant: 'orb',
  ),
};

/// (activity, variant) of a step-through activity.
({String activity, String variant}) stepsSessionKind(StepsActivity a) =>
    switch (a) {
      StepsActivity.senses => (
        activity: SessionActivities.grounding,
        variant: 'senses',
      ),
      StepsActivity.gratitude => (
        activity: SessionActivities.grounding,
        variant: 'gratitude',
      ),
      StepsActivity.savour => (
        activity: SessionActivities.savour,
        variant: 'moment',
      ),
    };

/// The server's bounds (1 s … 12 h).
const int maxSessionSeconds = 12 * 3600;

/// Where finished activities go.
abstract interface class SanctuarySessionLog {
  /// Records [session]; false when nothing was written (not allowed here,
  /// or shorter than a second). Never throws.
  Future<bool> record(SanctuarySession session);
}

/// The real log: one `sanctuary_session` mutation in the outbox (the one
/// write path), then a sync nudge. Only for an onboarded person who isn't
/// behind the under-13 lock (the same rule as the habit auto-complete).
class OutboxSanctuarySessionLog implements SanctuarySessionLog {
  OutboxSanctuarySessionLog({
    required this._db,
    required this._outbox,
    required this._ids,
    required this._time,
    required this._gate,
    this._notifySync,
  });

  static const String entity = 'sanctuary_session';

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final Ids _ids;
  final TimeContext Function() _time;
  final GateState Function() _gate;
  final void Function()? _notifySync;

  @override
  Future<bool> record(SanctuarySession s) async {
    try {
      if (!habitAutoCompleteAllowed(_gate())) return false;
      if (s.durationS < 1) return false;
      final t = _time();
      final id = _ids.v7();
      final clamped = s.durationS > maxSessionSeconds
          ? maxSessionSeconds
          : s.durationS;
      await _db.transaction(() async {
        await _outbox.enqueue(
          entity: entity,
          op: Ops.upsert,
          entityId: id,
          deviceTs: t.now().toUtc(),
          localDay: s.localDay,
          payload: SanctuarySession(
            activity: s.activity,
            variant: s.variant,
            durationS: clamped,
            localDay: s.localDay,
          ).payload(id),
          tz: t.timezone,
        );
      });
      _notifySync?.call();
      return true;
    } on Object catch (e) {
      debugPrint('sanctuary: session record skipped (${e.runtimeType})');
      return false;
    }
  }
}

final sanctuarySessionLogProvider = Provider<SanctuarySessionLog>(
  (ref) => OutboxSanctuarySessionLog(
    db: ref.watch(appDatabaseProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    ids: ref.watch(idsProvider),
    time: () => ref.read(timeContextProvider),
    gate: () => ref.read(gateControllerProvider),
    notifySync: () => ref.read(syncControllerProvider).notifyLocalWrite(),
  ),
);

/// Records a finished activity from a screen. Reads the log before any
/// await (the screen may be gone when the write finishes); never throws.
Future<bool> recordSanctuarySession(WidgetRef ref, SanctuarySession s) {
  final log = ref.read(sanctuarySessionLogProvider);
  return log.record(s);
}

// ---- "Sanctuary was opened this evening" (on this phone only) -------------

/// Kept in the local store (never synced): when Sanctuary was last opened,
/// so a wind-down reminder that arrives while Aura is open stays quiet after
/// Sanctuary was already used that evening (PRD 12 "skipped if Sanctuary
/// was already opened that evening"; the server knows only finished
/// activities).
const String sanctuaryOpenedAtKey = 'sanctuary.openedAt';

/// "That evening" starts at 18:00 of the Aura day (as the server's rule).
const int windDownEveningHour = 18;

Future<void> markSanctuaryOpened(KvStore kv, DateTime now) async {
  try {
    await kv.set(sanctuaryOpenedAtKey, now.toUtc().toIso8601String());
  } on Object catch (e) {
    debugPrint('sanctuary: opened mark (${e.runtimeType})');
  }
}

/// Whether Sanctuary was opened on this phone since 18:00 of the Aura day
/// containing [now] (local wall clock).
Future<bool> sanctuaryOpenedThisEvening(KvStore kv, DateTime now) async {
  final at = DateTime.tryParse(await kv.get(sanctuaryOpenedAtKey) ?? '');
  if (at == null) return false;
  final local = now.toLocal();
  // The Aura day rolls over at 04:00: before that it is still last evening.
  final dayStart = local.hour < 4
      ? DateTime(local.year, local.month, local.day - 1)
      : DateTime(local.year, local.month, local.day);
  final evening = dayStart.add(const Duration(hours: windDownEveningHour));
  return !at.toLocal().isBefore(evening);
}
