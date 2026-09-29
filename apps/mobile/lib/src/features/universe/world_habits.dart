import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../habits/decay_eligibility.dart';
import '../habits/habit_repository.dart';
import '../progress/progress_view.dart';
import 'universe_scene.dart';

part 'world_habits.g.dart';

/// One shown habit as the world presents it (RULES.md section 13): its
/// growth stage and how rested it looks. [input] carries the name for the
/// Flutter list; only [plant] ever reaches the renderer.
class WorldHabit {
  const WorldHabit({
    required this.slot,
    required this.input,
    required this.stage,
    required this.vitality,
  });

  final int slot;
  final HabitWorldInput input;
  final GrowthStage stage;
  final Vitality vitality;

  bool get resting => vitality != Vitality.thriving;

  WorldPlant get plant =>
      WorldPlant(slot: slot, stage: stage, vitality: vitality);
}

/// Pure: turns [inputs] into world habits. Presentation-only; it reads habit
/// logs and the person's own commitments and never touches the ledger.
/// Decay needs at least one commitment and an age of 18 or more
/// ([decayEligible]); anyone else sees every plant thriving.
List<WorldHabit> buildWorldHabits(
  List<HabitWorldInput> inputs, {
  required LocalDay today,
  required int ageYears,
}) {
  final decayActive = decayEligible(
    optedIn: inputs.any((i) => i.committedFrom != null),
    ageYears: ageYears,
  );
  return [
    for (var slot = 0; slot < inputs.length && slot < maxWorldPlants; slot++)
      WorldHabit(
        slot: slot,
        input: inputs[slot],
        stage: growthStage(inputs[slot].distinctLoggedDays),
        vitality: habitVitality(
          decayActive: decayActive,
          committedFrom: inputs[slot].committedFrom,
          lastLogDay: inputs[slot].lastLogDay,
          pausedThrough: inputs[slot].pausedThrough,
          today: today,
        ),
      ),
  ];
}

/// The habits of the personal world for the current Aura day. Logging a
/// habit restores it at once: the stream follows the logs.
@riverpod
Stream<List<WorldHabit>> worldHabits(Ref ref) {
  final today = ref.watch(progressViewProvider.select((v) => v.today));
  // Loading or unknown age means no decay: the safe default.
  final age = ref.watch(deviceAgeYearsProvider).value ?? 0;
  return ref
      .watch(habitRepositoryProvider)
      .watchWorldInputs()
      .map((inputs) => buildWorldHabits(inputs, today: today, ageYears: age));
}
