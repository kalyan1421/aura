// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(habitsToday)
final habitsTodayProvider = HabitsTodayProvider._();

final class HabitsTodayProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HabitToday>>,
          List<HabitToday>,
          Stream<List<HabitToday>>
        >
    with $FutureModifier<List<HabitToday>>, $StreamProvider<List<HabitToday>> {
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
