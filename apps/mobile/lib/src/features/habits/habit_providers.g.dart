// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Home's habits for the current Aura day (rolls over at 04:00).

@ProviderFor(habitsToday)
final habitsTodayProvider = HabitsTodayProvider._();

/// Home's habits for the current Aura day (rolls over at 04:00).

final class HabitsTodayProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HabitToday>>,
          List<HabitToday>,
          Stream<List<HabitToday>>
        >
    with $FutureModifier<List<HabitToday>>, $StreamProvider<List<HabitToday>> {
  /// Home's habits for the current Aura day (rolls over at 04:00).
  HabitsTodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'habitsTodayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$habitsTodayHash();

  @$internal
  @override
  $StreamProviderElement<List<HabitToday>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<HabitToday>> create(Ref ref) {
    return habitsToday(ref);
  }
}

String _$habitsTodayHash() => r'7ae453b0ca31c1acf65697c1fc23756f0c07f6c4';

/// The habits editor list: every preset and custom habit, shown or hidden.

@ProviderFor(habitSettings)
final habitSettingsProvider = HabitSettingsProvider._();

/// The habits editor list: every preset and custom habit, shown or hidden.

final class HabitSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HabitSetting>>,
          List<HabitSetting>,
          Stream<List<HabitSetting>>
        >
    with
        $FutureModifier<List<HabitSetting>>,
        $StreamProvider<List<HabitSetting>> {
  /// The habits editor list: every preset and custom habit, shown or hidden.
  HabitSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'habitSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$habitSettingsHash();

  @$internal
  @override
  $StreamProviderElement<List<HabitSetting>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<HabitSetting>> create(Ref ref) {
    return habitSettings(ref);
  }
}

String _$habitSettingsHash() => r'b1c79a396b1442938606e0141bc3b7480f90d92b';
