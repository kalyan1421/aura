// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reflections_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `null` when this build has no API (debug builds without config): the
/// room then shows no reflections section at all.

@ProviderFor(reflectionsApi)
final reflectionsApiProvider = ReflectionsApiProvider._();

/// `null` when this build has no API (debug builds without config): the
/// room then shows no reflections section at all.

final class ReflectionsApiProvider
    extends
        $FunctionalProvider<ReflectionsApi?, ReflectionsApi?, ReflectionsApi?>
    with $Provider<ReflectionsApi?> {
  /// `null` when this build has no API (debug builds without config): the
  /// room then shows no reflections section at all.
  ReflectionsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reflectionsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reflectionsApiHash();

  @$internal
  @override
  $ProviderElement<ReflectionsApi?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReflectionsApi? create(Ref ref) {
    return reflectionsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReflectionsApi? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReflectionsApi?>(value),
    );
  }
}

String _$reflectionsApiHash() => r'50c8c98b7ed93d55d0e071e6da0cf73eb6411b5f';

@ProviderFor(reflectionsRepository)
final reflectionsRepositoryProvider = ReflectionsRepositoryProvider._();

final class ReflectionsRepositoryProvider
    extends
        $FunctionalProvider<
          ReflectionsRepository,
          ReflectionsRepository,
          ReflectionsRepository
        >
    with $Provider<ReflectionsRepository> {
  ReflectionsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reflectionsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reflectionsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReflectionsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReflectionsRepository create(Ref ref) {
    return reflectionsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReflectionsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReflectionsRepository>(value),
    );
  }
}

String _$reflectionsRepositoryHash() =>
    r'3ef06c48b9e849f87b821828d467766cb790e7a9';

@ProviderFor(reflectionDraftStore)
final reflectionDraftStoreProvider = ReflectionDraftStoreProvider._();

final class ReflectionDraftStoreProvider
    extends
        $FunctionalProvider<
          ReflectionDraftStore,
          ReflectionDraftStore,
          ReflectionDraftStore
        >
    with $Provider<ReflectionDraftStore> {
  ReflectionDraftStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reflectionDraftStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reflectionDraftStoreHash();

  @$internal
  @override
  $ProviderElement<ReflectionDraftStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReflectionDraftStore create(Ref ref) {
    return reflectionDraftStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReflectionDraftStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReflectionDraftStore>(value),
    );
  }
}

String _$reflectionDraftStoreHash() =>
    r'abefa6d114583e4ae62a47d27abb217e1af208ba';

/// Whether the remote flags let the composer show at all. The server's
/// `composer.state` still decides (a paused language pool is only known
/// there: the room detail carries no pool).

@ProviderFor(reflectionsComposerAllowed)
final reflectionsComposerAllowedProvider =
    ReflectionsComposerAllowedProvider._();

/// Whether the remote flags let the composer show at all. The server's
/// `composer.state` still decides (a paused language pool is only known
/// there: the room detail carries no pool).

final class ReflectionsComposerAllowedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the remote flags let the composer show at all. The server's
  /// `composer.state` still decides (a paused language pool is only known
  /// there: the room detail carries no pool).
  ReflectionsComposerAllowedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reflectionsComposerAllowedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reflectionsComposerAllowedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return reflectionsComposerAllowed(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$reflectionsComposerAllowedHash() =>
    r'5ff8106b3ddaab873314e84b364a06667e9df4e4';
