// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_view.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(progressEvents)
final progressEventsProvider = ProgressEventsProvider._();

final class ProgressEventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProgressEvent>>,
          List<ProgressEvent>,
          Stream<List<ProgressEvent>>
        >
    with
        $FutureModifier<List<ProgressEvent>>,
        $StreamProvider<List<ProgressEvent>> {
  ProgressEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'progressEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$progressEventsHash();

  @$internal
  @override
  $StreamProviderElement<List<ProgressEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ProgressEvent>> create(Ref ref) {
    return progressEvents(ref);
  }
}

String _$progressEventsHash() => r'ac0f10d5a0283ad3af91b0c9eee4b9109a8dc5a9';

@ProviderFor(snapshot)
final snapshotProvider = SnapshotProvider._();

final class SnapshotProvider
    extends
        $FunctionalProvider<AsyncValue<Snapshot?>, Snapshot?, Stream<Snapshot?>>
    with $FutureModifier<Snapshot?>, $StreamProvider<Snapshot?> {
  SnapshotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'snapshotProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$snapshotHash();

  @$internal
  @override
  $StreamProviderElement<Snapshot?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Snapshot?> create(Ref ref) {
    return snapshot(ref);
  }
}

String _$snapshotHash() => r'56ed2c7153fe26fba32f64b05d3921264af6f57f';

@ProviderFor(lastHue)
final lastHueProvider = LastHueProvider._();

final class LastHueProvider
    extends $FunctionalProvider<AsyncValue<double?>, double?, Stream<double?>>
    with $FutureModifier<double?>, $StreamProvider<double?> {
  LastHueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastHueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastHueHash();

  @$internal
  @override
  $StreamProviderElement<double?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<double?> create(Ref ref) {
    return lastHue(ref);
  }
}

String _$lastHueHash() => r'01a8426968ce639fffa5036cd99fce36e752be5c';

@ProviderFor(progressView)
final progressViewProvider = ProgressViewProvider._();

final class ProgressViewProvider
    extends $FunctionalProvider<ProgressView, ProgressView, ProgressView>
    with $Provider<ProgressView> {
  ProgressViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'progressViewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$progressViewHash();

  @$internal
  @override
  $ProviderElement<ProgressView> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProgressView create(Ref ref) {
    return progressView(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProgressView value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProgressView>(value),
    );
  }
}

String _$progressViewHash() => r'247ba7c89c6936b3baa4b8fe6ea13c24bb970197';
