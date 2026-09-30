// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'world_moments.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The world moment waiting to be played, or `null`. Each change plays once:
/// [take] marks it seen. A plant that starts to rest, or shrinks because a
/// log was deleted, is shown as it is without a moment.

@ProviderFor(WorldMoments)
final worldMomentsProvider = WorldMomentsProvider._();

/// The world moment waiting to be played, or `null`. Each change plays once:
/// [take] marks it seen. A plant that starts to rest, or shrinks because a
/// log was deleted, is shown as it is without a moment.
final class WorldMomentsProvider
    extends $NotifierProvider<WorldMoments, WorldMoment?> {
  /// The world moment waiting to be played, or `null`. Each change plays once:
  /// [take] marks it seen. A plant that starts to rest, or shrinks because a
  /// log was deleted, is shown as it is without a moment.
  WorldMomentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'worldMomentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$worldMomentsHash();

  @$internal
  @override
  WorldMoments create() => WorldMoments();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorldMoment? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorldMoment?>(value),
    );
  }
}

String _$worldMomentsHash() => r'e824dbfbf01370d488211c8a6841c2bff6ab0dfe';

/// The world moment waiting to be played, or `null`. Each change plays once:
/// [take] marks it seen. A plant that starts to rest, or shrinks because a
/// log was deleted, is shown as it is without a moment.

abstract class _$WorldMoments extends $Notifier<WorldMoment?> {
  WorldMoment? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WorldMoment?, WorldMoment?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WorldMoment?, WorldMoment?>,
              WorldMoment?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
