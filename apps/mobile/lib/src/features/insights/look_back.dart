import 'dart:convert';

import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/db/kv_store.dart';
import '../../core/providers.dart';
import '../history/history_providers.dart';
import '../support/crisis_lexicon.dart';
import 'insights_providers.dart';

// F10 Look back (Milestone C, REQ-INS-08): the sky from the same week 1 month,
// 6 months and 1 year ago (RULES.md §10.1). Pull-only: it exists only inside
// Insights, behind the person's own tap. There is deliberately no route for
// it (nothing outside Insights can deep-link, push or share it), and nothing
// here talks to the network: the rules run on this phone from Drift, like
// the rest of Aura Sky (REQ-INS-02).
//
// Safety gates (PRD F10), all worked out on this phone:
// - hidden for 3 h after a Storm or Rain check-in and for 24 h after a crisis
//   sheet or the Safety Center opened here (the time is kept on this phone
//   only, never sent: DS-7);
// - crisis-flagged entries never appear: the lexicon is re-run on each note
//   whenever Look back is worked out and again when a note is opened, and a
//   device-only flag marks check-ins help was opened from;
// - never pushed, never on Home, the widget or a notification; it can be
//   hidden in Settings (`LookBackSettingsSwitch`).

// ---- device-only marks ------------------------------------------------------------

/// Most check-in ids kept in the help flag list (oldest dropped first).
const int lookBackMaxHelpFlags = 1000;

/// A crisis sheet or the Safety Center just opened on this phone: Look back
/// rests for 24 h. Called by the support sheet and the Safety Center. Never
/// throws, never logs what it stores.
Future<void> recordLookBackHelp(KvStore kv, DateTime now) async {
  try {
    await kv.set(KvKeys.lookBackHelpAt, now.toUtc().toIso8601String());
  } on Object catch (e) {
    debugPrint('lookback: help mark (${e.runtimeType})');
  }
}

/// Help was opened from check-in [checkInId] (the crisis sheet after saving
/// or editing it, or "I need help now" on its screen): it never shows in Look
/// back. Device-only. Never throws.
Future<void> markLookBackCheckInHelp(KvStore kv, String checkInId) async {
  try {
    final ids = _decodeIds(await kv.get(KvKeys.lookBackHelpCheckIns));
    if (ids.contains(checkInId)) return;
    ids.add(checkInId);
    final kept = ids.length > lookBackMaxHelpFlags
        ? ids.sublist(ids.length - lookBackMaxHelpFlags)
        : ids;
    await kv.set(KvKeys.lookBackHelpCheckIns, jsonEncode(kept));
  } on Object catch (e) {
    debugPrint('lookback: check-in mark (${e.runtimeType})');
  }
}

List<String> _decodeIds(String? raw) {
  if (raw == null) return [];
  try {
    return (jsonDecode(raw) as List<dynamic>).whereType<String>().toList();
  } on Object {
    return [];
  }
}

/// Settings › Look back: hide it (or show it again). Device-scoped.
Future<void> setLookBackHidden(KvStore kv, {required bool hidden}) =>
    kv.set(KvKeys.lookBackHidden, hidden ? 'true' : null);

// ---- providers --------------------------------------------------------------------

/// Hidden in Settings.
final lookBackHiddenProvider = StreamProvider.autoDispose<bool>(
  (ref) => ref
      .watch(kvStoreProvider)
      .watch(KvKeys.lookBackHidden)
      .map((v) => v == 'true'),
);

/// When a crisis sheet or the Safety Center last opened on this phone.
final lookBackHelpAtProvider = StreamProvider.autoDispose<DateTime?>(
  (ref) => ref
      .watch(kvStoreProvider)
      .watch(KvKeys.lookBackHelpAt)
      .map((v) => v == null ? null : DateTime.tryParse(v)),
);

/// Check-ins help was opened from (device-only flags).
final lookBackHelpCheckInsProvider = StreamProvider.autoDispose<Set<String>>(
  (ref) => ref
      .watch(kvStoreProvider)
      .watch(KvKeys.lookBackHelpCheckIns)
      .map((v) => _decodeIds(v).toSet()),
);

/// The latest Storm or Rain check-in made on this phone or synced to it,
/// deleted ones and backfills included (RULES.md §10.1 `gate`: the moment
/// counts, not the day it was for).
final lookBackLatestHeavyProvider =
    StreamProvider.autoDispose<LookBackGateCheckIn?>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final query = db.select(db.checkIns)
        ..where(
          (t) => t.quadrant.isIn([Quadrant.storm.name, Quadrant.rain.name]),
        )
        ..orderBy([(t) => OrderingTerm.desc(t.deviceTs)])
        ..limit(1);
      return query.watchSingleOrNull().map(
        (r) => r == null
            ? null
            : (
                quadrant: quadrantByName(r.quadrant) ?? Quadrant.storm,
                deviceTs: r.deviceTs,
              ),
      );
    });

/// The gate right now, or `null` until every input has loaded (Look back
/// stays out of sight until then). Re-evaluated as [nowProvider] ticks.
final lookBackGateProvider = Provider.autoDispose<LookBackGate?>((ref) {
  final time = ref.watch(timeContextProvider);
  final now = ref.watch(nowProvider).value ?? time.now();
  final hidden = ref.watch(lookBackHiddenProvider);
  final helpAt = ref.watch(lookBackHelpAtProvider);
  final heavy = ref.watch(lookBackLatestHeavyProvider);
  if (!hidden.hasValue || !helpAt.hasValue || !heavy.hasValue) return null;
  final latest = heavy.value;
  return lookBackGate(
    now: now,
    checkIns: [?latest],
    helpAt: helpAt.value,
    hidden: hidden.value!,
  );
});

/// One Look back week that has something to show.
@immutable
class LookBackWeek {
  const LookBackWeek({required this.window, required this.sky});

  final LookBackWindow window;
  final LookBackSky sky;
}

/// Everything Look back shows, from local data only.
@immutable
class LookBackModel {
  const LookBackModel({
    required this.loaded,
    required this.today,
    required this.weeks,
    required this.rows,
  });

  /// False until the first local read.
  final bool loaded;
  final LocalDay today;

  /// Visible weeks only, newest first (a week with nothing to show is left
  /// out).
  final List<LookBackWeek> weeks;

  /// The rows that show, by id (never a flagged one).
  final Map<String, CheckInRow> rows;

  bool get isEmpty => weeks.isEmpty;
}

/// Whether [row] may show in Look back, as a [LookBackEntry] (the lexicon
/// re-run on its note right now).
LookBackEntry lookBackEntryOf(
  CheckInRow row,
  Quadrant quadrant,
  LocalDay day, {
  required Set<String> helpFlags,
}) {
  final note = row.note;
  return LookBackEntry(
    id: row.id,
    localDay: day,
    quadrant: quadrant,
    deviceTs: row.deviceTs,
    deleted: row.deletedAt != null,
    lexiconCrisis: note != null && noteNeedsSupport(note),
    helpOpened: helpFlags.contains(row.id),
    noteUnreadable: row.noteLocked,
  );
}

final lookBackModelProvider = Provider.autoDispose<LookBackModel>((ref) {
  final today = ref.watch(insightsTodayProvider);
  final rows = ref.watch(historyEntriesProvider);
  final flags = ref.watch(lookBackHelpCheckInsProvider);
  final restDays = ref.watch(insightsRestDaysProvider);
  if (!rows.hasValue || !flags.hasValue) {
    return LookBackModel(
      loaded: false,
      today: today,
      weeks: const [],
      rows: const {},
    );
  }
  final windows = lookBackWindows(today);
  final entries = <LookBackEntry>[];
  final byId = <String, CheckInRow>{};
  for (final r in rows.value!) {
    final day = LocalDay.tryParse(r.localDay);
    final quadrant = moodById(r.moodId)?.quadrant ?? quadrantByName(r.quadrant);
    if (day == null || quadrant == null) continue;
    if (!windows.any((w) => w.range.contains(day))) continue;
    final e = lookBackEntryOf(r, quadrant, day, helpFlags: flags.value!);
    entries.add(e);
    if (e.shows) byId[r.id] = r;
  }
  final weeks = [
    for (final w in windows)
      if (lookBackSky(w.range, entries, restDays: restDays) case final sky
          when sky.visible)
        LookBackWeek(window: w, sky: sky),
  ];
  return LookBackModel(
    loaded: true,
    today: today,
    weeks: List.unmodifiable(weeks),
    rows: Map.unmodifiable(byId),
  );
});

/// Whether the way into Look back shows in Insights right now: the gate is
/// open and at least one week has something to show.
final lookBackAvailableProvider = Provider.autoDispose<bool>((ref) {
  final gate = ref.watch(lookBackGateProvider);
  if (gate == null || !gate.isOpen) return false;
  return !ref.watch(lookBackModelProvider).isEmpty;
});

// ---- Settings ---------------------------------------------------------------------

/// Settings › Comfort: "Look back in Aura Sky" (on by default). PRD F10: it
/// can be hidden in Settings.
class LookBackSettingsSwitch extends ConsumerWidget {
  const LookBackSettingsSwitch({super.key});

  static const Key switchKey = ValueKey('set-look-back');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final hidden = ref.watch(lookBackHiddenProvider).value ?? false;
    return SwitchListTile(
      key: switchKey,
      contentPadding: EdgeInsets.zero,
      value: !hidden,
      onChanged: (show) =>
          setLookBackHidden(ref.read(kvStoreProvider), hidden: !show),
      title: Text(l.insights_lookBackSetting),
      subtitle: Text(l.insights_lookBackSettingNote),
    );
  }
}
