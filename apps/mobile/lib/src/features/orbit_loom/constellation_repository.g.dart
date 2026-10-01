// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'constellation_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(constellationRepository)
final constellationRepositoryProvider = ConstellationRepositoryProvider._();

final class ConstellationRepositoryProvider
    extends
        $FunctionalProvider<
          ConstellationRepository,
          ConstellationRepository,
          ConstellationRepository
        >
    with $Provider<ConstellationRepository> {
  ConstellationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'constellationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$constellationRepositoryHash();

  @$internal
  @override
  $ProviderElement<ConstellationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConstellationRepository create(Ref ref) {
    return constellationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConstellationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConstellationRepository>(value),
    );
  }
}

String _$constellationRepositoryHash() =>
    r'7d98b7955e264645c182fe9e639bc1d2b9a61b58';

/// The constellations kept in the Reflection sky, newest first.

@ProviderFor(keptConstellations)
final keptConstellationsProvider = KeptConstellationsProvider._();

/// The constellations kept in the Reflection sky, newest first.

final class KeptConstellationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<KeptConstellation>>,
          List<KeptConstellation>,
          Stream<List<KeptConstellation>>
        >
    with
        $FutureModifier<List<KeptConstellation>>,
        $StreamProvider<List<KeptConstellation>> {
  /// The constellations kept in the Reflection sky, newest first.
  KeptConstellationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'keptConstellationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$keptConstellationsHash();

  @$internal
  @override
  $StreamProviderElement<List<KeptConstellation>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<KeptConstellation>> create(Ref ref) {
    return keptConstellations(ref);
  }
}

String _$keptConstellationsHash() =>
    r'6a6981bd425d83262b77ef259e391b8a72efbbef';

/// How many were kept today (Orbit Loom's per-day limit).

@ProviderFor(keptToday)
final keptTodayProvider = KeptTodayProvider._();

/// How many were kept today (Orbit Loom's per-day limit).

final class KeptTodayProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// How many were kept today (Orbit Loom's per-day limit).
  KeptTodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'keptTodayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$keptTodayHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return keptToday(ref);
  }
}

String _$keptTodayHash() => r'69d0898b0c400d5596356dd087aae80ed861a9c1';
