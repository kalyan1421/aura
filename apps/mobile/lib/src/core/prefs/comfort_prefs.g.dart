// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comfort_prefs.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ComfortController)
final comfortControllerProvider = ComfortControllerProvider._();

final class ComfortControllerProvider
    extends $NotifierProvider<ComfortController, ComfortPrefs> {
  ComfortControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'comfortControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$comfortControllerHash();

  @$internal
  @override
  ComfortController create() => ComfortController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ComfortPrefs value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ComfortPrefs>(value),
    );
  }
}

String _$comfortControllerHash() => r'd7ec67ce4fc07ff0888770ff60ab28a4284db29d';

abstract class _$ComfortController extends $Notifier<ComfortPrefs> {
  ComfortPrefs build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ComfortPrefs, ComfortPrefs>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ComfortPrefs, ComfortPrefs>,
              ComfortPrefs,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
