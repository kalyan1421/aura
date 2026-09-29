// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'world_habits.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The habits of the personal world for the current Aura day. Logging a
/// habit restores it at once: the stream follows the logs.

@ProviderFor(worldHabits)
final worldHabitsProvider = WorldHabitsProvider._();

/// The habits of the personal world for the current Aura day. Logging a
/// habit restores it at once: the stream follows the logs.

final class WorldHabitsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorldHabit>>,
          List<WorldHabit>,
          Stream<List<WorldHabit>>
        >
    with $FutureModifier<List<WorldHabit>>, $StreamProvider<List<WorldHabit>> {
  /// The habits of the personal world for the current Aura day. Logging a
  /// habit restores it at once: the stream follows the logs.
  WorldHabitsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'worldHabitsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$worldHabitsHash();

  @$internal
  @override
  $StreamProviderElement<List<WorldHabit>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<WorldHabit>> create(Ref ref) {
    return worldHabits(ref);
  }
}

String _$worldHabitsHash() => r'50e6c12cb77e2bb287d83bbd43ca6cb6ba0a73f3';
