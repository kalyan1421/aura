// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The platform health adapter. Override in the app (or a test) once an
/// adapter exists; the default keeps every health surface hidden.

@ProviderFor(healthSource)
final healthSourceProvider = HealthSourceProvider._();

/// The platform health adapter. Override in the app (or a test) once an
/// adapter exists; the default keeps every health surface hidden.

final class HealthSourceProvider
    extends $FunctionalProvider<HealthSource, HealthSource, HealthSource>
    with $Provider<HealthSource> {
  /// The platform health adapter. Override in the app (or a test) once an
  /// adapter exists; the default keeps every health surface hidden.
  HealthSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthSourceHash();

  @$internal
  @override
  $ProviderElement<HealthSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HealthSource create(Ref ref) {
    return healthSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HealthSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HealthSource>(value),
    );
  }
}

String _$healthSourceHash() => r'c743e713789ee0c3c15e87d50885a26f4403e1f5';

@ProviderFor(healthAvailability)
final healthAvailabilityProvider = HealthAvailabilityProvider._();

final class HealthAvailabilityProvider
    extends
        $FunctionalProvider<
          AsyncValue<HealthAvailability>,
          HealthAvailability,
          FutureOr<HealthAvailability>
        >
    with
        $FutureModifier<HealthAvailability>,
        $FutureProvider<HealthAvailability> {
  HealthAvailabilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthAvailabilityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthAvailabilityHash();

  @$internal
  @override
  $FutureProviderElement<HealthAvailability> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<HealthAvailability> create(Ref ref) {
    return healthAvailability(ref);
  }
}

String _$healthAvailabilityHash() =>
    r'8b44b2bb0831c3b3d24d88f490ae4fec840cc69b';

/// The person's opt-in to step-lit path stones. Off by default. Only the flag
/// is kept; nothing is read from the health store while it is off.

@ProviderFor(HealthStepsEnabled)
final healthStepsEnabledProvider = HealthStepsEnabledProvider._();

/// The person's opt-in to step-lit path stones. Off by default. Only the flag
/// is kept; nothing is read from the health store while it is off.
final class HealthStepsEnabledProvider
    extends $AsyncNotifierProvider<HealthStepsEnabled, bool> {
  /// The person's opt-in to step-lit path stones. Off by default. Only the flag
  /// is kept; nothing is read from the health store while it is off.
  HealthStepsEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthStepsEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthStepsEnabledHash();

  @$internal
  @override
  HealthStepsEnabled create() => HealthStepsEnabled();
}

String _$healthStepsEnabledHash() =>
    r'bac334667623faed9ca8ac3423d74047a887a9ac';

/// The person's opt-in to step-lit path stones. Off by default. Only the flag
/// is kept; nothing is read from the health store while it is off.

abstract class _$HealthStepsEnabled extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Today's steps for the world, or `null`: off unless the person opted in and
/// access is granted. Read fresh each time the universe opens; the number goes
/// straight into [litStones] and is never stored, logged or shown.

@ProviderFor(worldSteps)
final worldStepsProvider = WorldStepsProvider._();

/// Today's steps for the world, or `null`: off unless the person opted in and
/// access is granted. Read fresh each time the universe opens; the number goes
/// straight into [litStones] and is never stored, logged or shown.

final class WorldStepsProvider
    extends $FunctionalProvider<AsyncValue<int?>, int?, FutureOr<int?>>
    with $FutureModifier<int?>, $FutureProvider<int?> {
  /// Today's steps for the world, or `null`: off unless the person opted in and
  /// access is granted. Read fresh each time the universe opens; the number goes
  /// straight into [litStones] and is never stored, logged or shown.
  WorldStepsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'worldStepsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$worldStepsHash();

  @$internal
  @override
  $FutureProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int?> create(Ref ref) {
    return worldSteps(ref);
  }
}

String _$worldStepsHash() => r'e087d649ffceebf4ebc840bc5ecc805f6bacc8b1';
