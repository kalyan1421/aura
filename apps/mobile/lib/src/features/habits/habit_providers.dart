import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../progress/progress_view.dart';
import 'habit_repository.dart';

part 'habit_providers.g.dart';

/// Home's habits for the current Aura day (rolls over at 04:00).
@riverpod
Stream<List<HabitToday>> habitsToday(Ref ref) {
  final day = ref.watch(progressViewProvider.select((v) => v.today));
  return ref.watch(habitRepositoryProvider).watchToday(day);
}

/// The habits editor list: every preset and custom habit, shown or hidden.
@riverpod
Stream<List<HabitSetting>> habitSettings(Ref ref) =>
    ref.watch(habitRepositoryProvider).watchSettings();
