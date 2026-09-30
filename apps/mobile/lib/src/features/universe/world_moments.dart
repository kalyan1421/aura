import 'dart:async';
import 'dart:convert';

import 'package:aura_domain/aura_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/kv_store.dart';
import '../../core/providers.dart';
import '../habits/decay_eligibility.dart';
import '../habits/habit_repository.dart';
import '../progress/progress_view.dart';
import 'universe_scene.dart';
import 'world_habits.dart';

part 'world_moments.g.dart';

/// Stable key of a world object (RULES.md section 13 `changes`): a preset's
/// catalogue key, which a person has at most once and which survives the
/// preset's first row being made, or a custom habit's id.
String worldKeyOf(HabitWorldInput input) {
  final preset = input.preset;
  return preset != null ? 'p:${preset.key}' : 'c:${input.habitId}';
}

/// One plant's moment: from how the person last saw it to how it is now.
class PlantMoment {
  const PlantMoment({
    required this.habit,
    required this.from,
    required this.kind,
  });

  /// The habit now. Its name is for the Flutter text twin only.
  final WorldHabit habit;

  /// How the plant looked when last seen; `null` for a new plant.
  final WorldPlant? from;
  final WorldChangeKind kind;

  /// The only part the renderer receives: a slot, stages and vitalities.
  WorldPlantChange get change => WorldPlantChange(from: from, to: habit.plant);
}

/// What changed in the personal world since the person last looked (T04).
/// Presentation only: playing it awards, stores and pushes nothing.
class WorldMoment {
  const WorldMoment(this.plants);
  final List<PlantMoment> plants;
}

/// The world moment waiting to be played, or `null`. Each change plays once:
/// [take] marks it seen. A plant that starts to rest, or shrinks because a
/// log was deleted, is shown as it is without a moment.
@riverpod
class WorldMoments extends _$WorldMoments {
  /// How each object looked when the person last saw it. `null` until read.
  Map<String, WorldLook>? _seen;
  Future<Map<String, WorldLook>?>? _reading;
  bool _hasBaseline = false;
  bool _disposed = false;
  List<WorldHabit>? _latest;

  @override
  WorldMoment? build() {
    ref.onDispose(() => _disposed = true);
    ref.listen(worldHabitsProvider, (_, next) {
      final habits = next.value;
      // A reload (the day or the age changed) repeats the old list: wait.
      if (next.isLoading || habits == null) return;
      // Until the age is known every plant looks thriving, which would read
      // as a wake. Rebuild the looks with the age now known instead of
      // trusting a list made before it arrived.
      final age = ref.read(deviceAgeYearsProvider).value;
      if (age == null) return;
      unawaited(
        _consider(
          buildWorldHabits(
            [for (final h in habits) h.input],
            today: ref.read(progressViewProvider).today,
            ageYears: age,
          ),
        ),
      );
    }, fireImmediately: true);
    return null;
  }

  Future<void> _consider(List<WorldHabit> habits) async {
    _latest = habits;
    final stored = await (_reading ??= _read());
    // A newer list arrived while the store was read: that one decides.
    if (_disposed || !identical(habits, _latest)) return;
    final current = _looks(habits);
    if (!_hasBaseline) {
      _hasBaseline = true;
      if (stored == null) {
        // The first look is the baseline, never a moment.
        unawaited(_remember({for (final c in current) c.key: c.look}));
        return;
      }
      _seen = stored;
    }
    final seen = _seen!;
    final changes = {
      for (final c in worldChanges(seen: seen, current: current)) c.key: c.kind,
    };
    // Objects without a moment are seen as they are now (so a plant that
    // started resting can later wake); objects with one keep their old look
    // until it plays. Objects that left the grove are forgotten.
    final next = <String, WorldLook>{};
    for (final c in current) {
      final before = seen[c.key];
      if (!changes.containsKey(c.key)) {
        next[c.key] = c.look;
      } else if (before != null) {
        next[c.key] = before;
      }
    }
    final moment = <PlantMoment>[];
    for (final h in habits) {
      final key = worldKeyOf(h.input);
      final kind = changes[key];
      if (kind == null) continue;
      final before = seen[key];
      moment.add(
        PlantMoment(
          habit: h,
          kind: kind,
          from: before == null
              ? null
              : WorldPlant(
                  slot: h.slot,
                  stage: before.stage,
                  vitality: before.vitality,
                ),
        ),
      );
    }
    state = moment.isEmpty ? null : WorldMoment(moment);
    if (!_sameLooks(next, seen)) unawaited(_remember(next));
  }

  /// The screen starts playing the waiting moment: from now on it is seen.
  WorldMoment? take() {
    final moment = state;
    if (moment == null) return null;
    final seen = {...?_seen};
    for (final p in moment.plants) {
      seen[worldKeyOf(p.habit.input)] = WorldLook(
        p.habit.stage,
        p.habit.vitality,
      );
    }
    unawaited(_remember(seen));
    state = null;
    return moment;
  }

  static List<({String key, WorldLook look})> _looks(List<WorldHabit> habits) =>
      [
        for (final h in habits)
          (key: worldKeyOf(h.input), look: WorldLook(h.stage, h.vitality)),
      ];

  static bool _sameLooks(Map<String, WorldLook> a, Map<String, WorldLook> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  Future<Map<String, WorldLook>?> _read() async {
    final raw = await ref.read(kvStoreProvider).get(KvKeys.worldSeen);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in json.entries)
          e.key: WorldLook(
            GrowthStage.fromName((e.value as List<dynamic>)[0] as String),
            Vitality.fromName((e.value as List<dynamic>)[1] as String),
          ),
      };
    } on Object {
      // Unreadable (an older shape): start a new baseline. Replay is cosmetic.
      return null;
    }
  }

  Future<void> _remember(Map<String, WorldLook> seen) async {
    _seen = seen;
    await ref
        .read(kvStoreProvider)
        .set(
          KvKeys.worldSeen,
          jsonEncode({
            for (final e in seen.entries)
              e.key: [e.value.stage.name, e.value.vitality.name],
          }),
        );
  }
}
