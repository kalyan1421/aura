import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import '../../core/db/database.dart';
import '../../core/ids/ids.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/time/clock.dart';

// ---- auto-complete rules (F2) -----------------------------------------------

/// A check-in note of at least this many characters auto-completes today's
/// Journal habit (F2). Characters as people see them (grapheme clusters), so
/// a Telugu conjunct or an emoji counts once, as everywhere else in the app.
const int journalNoteMinChars = 50;

/// Whether [note] is long enough to count as journaling (F2): at least
/// [journalNoteMinChars] characters once trimmed.
bool noteCompletesJournal(String? note) =>
    (note?.trim().characters.length ?? 0) >= journalNoteMinChars;

/// Active breathing time that auto-completes today's Breathe habit (F2: "the
/// 60 s exercise"). Any Sanctuary breathing session counts once it reaches
/// this, whatever length was picked.
const Duration breatheAutoCompleteAfter = Duration(seconds: 60);

/// One habit on Home today: a preset (its label comes from l10n) or a
/// custom habit (its own [name]), and whether it is done this Aura day.
class HabitToday {
  const HabitToday({
    required PresetHabit this.preset,
    required this.done,
    this.habitId,
  }) : name = null;

  const HabitToday.custom({
    required String this.habitId,
    required String this.name,
    required this.done,
  }) : preset = null;

  final PresetHabit? preset;

  /// `null` for a preset that was never used (its row is created lazily).
  final String? habitId;

  /// The custom habit's own name (never sent to analytics or logs).
  final String? name;
  final bool done;

  bool get isCustom => preset == null;

  /// Stable per habit, for widget keys.
  String get key => preset?.key ?? habitId!;
}

/// One row in the habits editor: shown on Home or not.
class HabitSetting {
  const HabitSetting.preset(PresetHabit this.preset, {required this.shown})
    : habitId = null,
      name = null;

  const HabitSetting.custom({
    required String this.habitId,
    required String this.name,
    required this.shown,
  }) : preset = null;

  final PresetHabit? preset;
  final String? habitId;
  final String? name;

  /// `habits.active`: shown on Home.
  final bool shown;

  bool get isCustom => preset == null;
  String get key => preset?.key ?? habitId!;
}

/// Why adding or showing a custom habit did not happen.
enum CustomHabitResult { saved, tooMany, invalid }

/// Outcome of changing a habit's commitment (W02, RULES.md section 13).
/// [notAvailable]: opt-in decay is never available under 18. [invalid]: a
/// pause needs a commitment, and lasts 1 to [HabitRepository.maxPauseDays].
enum CommitmentResult { saved, notAvailable, notFound, invalid }

/// Binary, self-reported habits per Aura day (F2): the six presets plus up
/// to 3 active custom habits. No "missed" state. Every change is written
/// locally together with its outbox mutation (the app never writes personal
/// tables on the server directly).
class HabitRepository {
  HabitRepository(this._db, this._outbox, this._time, this._ids);

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final TimeContext _time;
  final Ids _ids;

  /// At most 3 active custom habits (server: `too_many_custom_habits`).
  /// Everything that adds or re-shows one checks [canAddCustomHabit] first.
  /// Presets are never duplicated: there is one row per preset key
  /// (server: `duplicate_preset_habit`).
  static const int maxActiveCustomHabits = 3;

  /// Custom names: ≤ 30 characters (PRD F2), counted as grapheme clusters
  /// (what a person sees as one letter, so a Telugu conjunct is one). The
  /// server counts the same way; the editor's field enforces it as you type.
  static const int maxCustomNameChars = 30;

  /// The name as it will be saved, or `null` when it is empty or too long.
  static String? cleanCustomName(String raw) {
    final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return null;
    if (name.characters.length > maxCustomNameChars) return null;
    return name;
  }

  Future<bool> canAddCustomHabit() async =>
      await _activeCustomCount() < maxActiveCustomHabits;

  Future<int> _activeCustomCount() async {
    final active = await (_db.select(
      _db.habits,
    )..where((t) => t.kind.equals('custom') & t.active.equals(true))).get();
    return active.length;
  }

  /// Home's habits for [day]: shown presets in catalogue order (a preset
  /// without a row is shown by default), then active custom habits, oldest
  /// first.
  Stream<List<HabitToday>> watchToday(LocalDay day) {
    return _db
        .customSelect(
          'SELECT h.id AS id, h.kind AS kind, h.preset_key AS preset_key, '
          '  h.name AS name, h.active AS active, COUNT(l.id) AS done '
          'FROM habits h LEFT JOIN habit_logs l '
          '  ON l.habit_id = h.id AND l.local_day = ? AND l.deleted_at IS NULL '
          'GROUP BY h.id '
          'ORDER BY h.created_at, h.rowid',
          variables: [Variable.withString(day.toIso())],
          readsFrom: {_db.habits, _db.habitLogs},
        )
        .watch()
        .map((rows) {
          final presets = <String, ({String id, bool active, bool done})>{};
          final custom = <HabitToday>[];
          for (final r in rows) {
            final active = r.read<bool>('active');
            final done = r.read<int>('done') > 0;
            final key = r.readNullable<String>('preset_key');
            if (r.read<String>('kind') == 'preset' && key != null) {
              presets[key] = (
                id: r.read<String>('id'),
                active: active,
                done: done,
              );
            } else if (active) {
              custom.add(
                HabitToday.custom(
                  habitId: r.read<String>('id'),
                  name: r.readNullable<String>('name') ?? '',
                  done: done,
                ),
              );
            }
          }
          return [
            for (final p in presetHabits)
              if (presets[p.key]?.active ?? true)
                HabitToday(
                  preset: p,
                  done: presets[p.key]?.done ?? false,
                  habitId: presets[p.key]?.id,
                ),
            ...custom,
          ];
        });
  }

  /// The editor list: all six presets, then every custom habit (shown or
  /// hidden), oldest first.
  Stream<List<HabitSetting>> watchSettings() {
    return (_db.select(_db.habits)..orderBy([
          (t) => OrderingTerm.asc(t.createdAt),
          // Insertion order when two share a timestamp.
          (t) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
        ]))
        .watch()
        .map((rows) {
          final presetShown = <String, bool>{
            for (final r in rows)
              if (r.kind == 'preset' && r.presetKey != null)
                r.presetKey!: r.active,
          };
          return [
            for (final p in presetHabits)
              HabitSetting.preset(p, shown: presetShown[p.key] ?? true),
            for (final r in rows)
              if (r.kind == 'custom')
                HabitSetting.custom(
                  habitId: r.id,
                  name: r.name ?? '',
                  shown: r.active,
                ),
          ];
        });
  }

  /// Marks the preset [presetKey] done today, or un-marks it. The habit row
  /// itself is created lazily the first time it is used.
  Future<bool> toggleToday(String presetKey) => _db.transaction(() async {
    final habit = await _presetRow(presetKey, create: true);
    return _toggleLog(habit!);
  });

  /// Marks the custom habit [habitId] done today, or un-marks it.
  Future<bool> toggleCustomToday(String habitId) => _db.transaction(() async {
    final habit = await (_db.select(
      _db.habits,
    )..where((t) => t.id.equals(habitId))).getSingleOrNull();
    if (habit == null) return false;
    return _toggleLog(habit);
  });

  /// Auto-complete (F2: Breathe after the 60 s exercise, Journal after a
  /// note of [journalNoteMinChars]+ characters): marks [presetKey] done
  /// today unless it is hidden or already done. Never un-marks, so calling
  /// it again the same day is a no-op. Returns whether a new completion was
  /// written.
  Future<bool> completeToday(String presetKey) => _db.transaction(() async {
    final existing = await _presetRow(presetKey, create: false);
    if (existing != null && !existing.active) return false;
    final habit = existing ?? await _presetRow(presetKey, create: true);
    final day = _time.dayOf(_time.now()).toIso();
    final live =
        await (_db.select(_db.habitLogs)..where(
              (t) =>
                  t.habitId.equals(habit!.id) &
                  t.localDay.equals(day) &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (live != null) return false;
    return _toggleLog(habit!);
  });

  /// The id of preset [presetKey]'s row, created (shown, with its `habit`
  /// upsert in the outbox) when the preset was never used — a habit nudge
  /// (F14) refers to a habit by id.
  Future<String> ensurePresetId(String presetKey) => _db.transaction(
    () async => (await _presetRow(presetKey, create: true))!.id,
  );

  /// Shows or hides a preset on Home (`habit` upsert with `active`).
  Future<void> setPresetShown(String presetKey, bool shown) => _db.transaction(
    () async {
      final habit = await _presetRow(presetKey, create: false);
      if (habit == null) {
        if (shown) return; // no row = shown by default
        await _insertHabit(kind: 'preset', presetKey: presetKey, active: false);
        return;
      }
      if (habit.active == shown) return;
      await _setActive(habit, shown);
    },
  );

  /// Adds a custom habit named [raw] (see [cleanCustomName]). Crisis
  /// scanning is the caller's job (the name saves either way).
  Future<CustomHabitResult> addCustom(String raw) async {
    final name = cleanCustomName(raw);
    if (name == null) return CustomHabitResult.invalid;
    return _db.transaction(() async {
      if (await _activeCustomCount() >= maxActiveCustomHabits) {
        return CustomHabitResult.tooMany;
      }
      await _insertHabit(kind: 'custom', name: name, active: true);
      return CustomHabitResult.saved;
    });
  }

  /// Shows or hides a custom habit. Showing one needs a free slot.
  Future<CustomHabitResult> setCustomShown(String habitId, bool shown) =>
      _db.transaction(() async {
        final habit = await (_db.select(
          _db.habits,
        )..where((t) => t.id.equals(habitId))).getSingleOrNull();
        if (habit == null || habit.kind != 'custom') {
          return CustomHabitResult.invalid;
        }
        if (habit.active == shown) return CustomHabitResult.saved;
        if (shown && await _activeCustomCount() >= maxActiveCustomHabits) {
          return CustomHabitResult.tooMany;
        }
        await _setActive(habit, shown);
        return CustomHabitResult.saved;
      });

  /// Removes a custom habit (`habit` delete; the server hard-deletes it and
  /// its logs). Its local logs become tombstones so Starlight and glow days
  /// already earned stay, as on the server. Pending log mutations still go
  /// out first (the outbox drains in order).
  Future<void> removeCustom(String habitId) => _db.transaction(() async {
    final habit = await (_db.select(
      _db.habits,
    )..where((t) => t.id.equals(habitId))).getSingleOrNull();
    if (habit == null || habit.kind != 'custom') return;
    final now = _time.now();
    await (_db.update(_db.habitLogs)
          ..where((t) => t.habitId.equals(habitId) & t.deletedAt.isNull()))
        .write(HabitLogsCompanion(deletedAt: Value(now)));
    await (_db.delete(_db.habits)..where((t) => t.id.equals(habitId))).go();
    await _outbox.enqueue(
      entity: Entities.habit,
      op: Ops.delete,
      entityId: habitId,
      deviceTs: now,
      localDay: _time.dayOf(now),
      tz: _time.timezone,
      payload: {'id': habitId},
    );
  });

  // ---- commitments (W02) -----------------------------------------------------

  /// The longest pause, in Aura days ahead of today (server: `MAX_PAUSE_DAYS`).
  static const int maxPauseDays = 60;

  /// Turns the person's own commitment on or off for a habit (RULES.md
  /// section 13). Presentation-only: it never touches Starlight, streaks or
  /// keepsakes. Starting one needs [ageYears] of at least 18
  /// ([decayEligible]); ending one is always allowed and also ends a pause.
  /// Written locally with its outbox mutation, like every personal change.
  Future<CommitmentResult> setCommitment(
    String habitId, {
    required bool committed,
    required int ageYears,
  }) => _db.transaction(() async {
    final habit = await _byId(habitId);
    if (habit == null) return CommitmentResult.notFound;
    if (committed && !decayEligible(optedIn: true, ageYears: ageYears)) {
      return CommitmentResult.notAvailable;
    }
    if (committed && habit.committedFrom != null) return CommitmentResult.saved;
    final now = _time.now();
    final from = committed ? _time.dayOf(now).toIso() : null;
    await _writeCommitment(habit, now, committedFrom: from, pausedThrough: null);
    return CommitmentResult.saved;
  });

  /// Pauses a commitment for [days] Aura days from today (holiday, illness),
  /// or ends the pause with `days: 0`. Needs an existing commitment.
  Future<CommitmentResult> pauseCommitment(
    String habitId, {
    required int days,
  }) => _db.transaction(() async {
    final habit = await _byId(habitId);
    if (habit == null) return CommitmentResult.notFound;
    if (habit.committedFrom == null || days < 0 || days > maxPauseDays) {
      return CommitmentResult.invalid;
    }
    final now = _time.now();
    final through = days == 0
        ? null
        : _time.dayOf(now).addDays(days).toIso();
    await _writeCommitment(
      habit,
      now,
      committedFrom: habit.committedFrom,
      pausedThrough: through,
    );
    return CommitmentResult.saved;
  });

  Future<HabitRow?> _byId(String habitId) => (_db.select(
    _db.habits,
  )..where((t) => t.id.equals(habitId))).getSingleOrNull();

  Future<void> _writeCommitment(
    HabitRow habit,
    DateTime now, {
    required String? committedFrom,
    required String? pausedThrough,
  }) async {
    await (_db.update(_db.habits)..where((t) => t.id.equals(habit.id))).write(
      HabitsCompanion(
        committedFrom: Value(committedFrom),
        pausedThrough: Value(pausedThrough),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
    // Explicit nulls clear on the server; ordinary edits omit the fields.
    await _enqueueUpsert(
      id: habit.id,
      kind: habit.kind,
      presetKey: habit.presetKey,
      name: habit.name,
      active: habit.active,
      now: now,
      commitment: {'committedFrom': committedFrom, 'pausedThrough': pausedThrough},
    );
  }

  // ---- internals -------------------------------------------------------------

  Future<HabitRow?> _presetRow(String presetKey, {required bool create}) async {
    final habit =
        await (_db.select(_db.habits)..where(
              (t) => t.kind.equals('preset') & t.presetKey.equals(presetKey),
            ))
            .getSingleOrNull();
    if (habit != null || !create) return habit;
    return _insertHabit(kind: 'preset', presetKey: presetKey, active: true);
  }

  Future<HabitRow> _insertHabit({
    required String kind,
    String? presetKey,
    String? name,
    required bool active,
  }) async {
    final now = _time.now();
    final id = _ids.v7();
    await _db
        .into(_db.habits)
        .insert(
          HabitsCompanion.insert(
            id: id,
            kind: kind,
            presetKey: Value(presetKey),
            name: Value(name),
            active: Value(active),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _enqueueUpsert(
      id: id,
      kind: kind,
      presetKey: presetKey,
      name: name,
      active: active,
      now: now,
    );
    return (_db.select(_db.habits)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> _setActive(HabitRow habit, bool active) async {
    final now = _time.now();
    await (_db.update(_db.habits)..where((t) => t.id.equals(habit.id))).write(
      HabitsCompanion(
        active: Value(active),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
    await _enqueueUpsert(
      id: habit.id,
      kind: habit.kind,
      presetKey: habit.presetKey,
      name: habit.name,
      active: active,
      now: now,
    );
  }

  Future<void> _enqueueUpsert({
    required String id,
    required String kind,
    required String? presetKey,
    required String? name,
    required bool active,
    required DateTime now,
    Map<String, Object?> commitment = const {},
  }) => _outbox.enqueue(
    entity: Entities.habit,
    op: Ops.upsert,
    entityId: id,
    deviceTs: now,
    localDay: _time.dayOf(now),
    tz: _time.timezone,
    payload: {
      'id': id,
      'kind': kind,
      'presetKey': presetKey,
      'name': name,
      'active': active,
      ...commitment,
    },
  );

  /// Logs [habit] for today, or un-logs today's log. Returns `true` when it
  /// is now done.
  Future<bool> _toggleLog(HabitRow habit) async {
    final now = _time.now();
    final day = _time.dayOf(now);
    final logs =
        await (_db.select(_db.habitLogs)..where(
              (t) =>
                  t.habitId.equals(habit.id) & t.localDay.equals(day.toIso()),
            ))
            .get();
    final live = logs.where((l) => l.deletedAt == null).firstOrNull;

    if (live == null) {
      // One log per habit per Aura day: re-marking after an un-mark reuses
      // the same id (the server rejects a second id as `already_logged`).
      final previous = logs.firstOrNull;
      final logId = previous?.id ?? _ids.v7();
      if (previous != null) {
        await (_db.update(
          _db.habitLogs,
        )..where((t) => t.id.equals(logId))).write(
          HabitLogsCompanion(
            deletedAt: const Value(null),
            synced: const Value(false),
            tz: Value(_time.timezone),
          ),
        );
      } else {
        await _db
            .into(_db.habitLogs)
            .insert(
              HabitLogsCompanion.insert(
                id: logId,
                habitId: habit.id,
                localDay: day.toIso(),
                deviceTs: now,
                tz: Value(_time.timezone),
              ),
            );
      }
      await _outbox.enqueue(
        entity: Entities.habitLog,
        op: Ops.upsert,
        entityId: logId,
        deviceTs: now,
        localDay: day,
        tz: _time.timezone,
        payload: {'id': logId, 'habitId': habit.id},
      );
      return true;
    }

    // Un-mark: a tombstone locally (Starlight already earned stays, as on
    // the server) and a delete mutation.
    await (_db.update(_db.habitLogs)..where((t) => t.id.equals(live.id))).write(
      HabitLogsCompanion(deletedAt: Value(now)),
    );
    await _outbox.enqueue(
      entity: Entities.habitLog,
      op: Ops.delete,
      entityId: live.id,
      deviceTs: now,
      localDay: day,
      tz: _time.timezone,
      payload: {'id': live.id},
    );
    return false;
  }
}
