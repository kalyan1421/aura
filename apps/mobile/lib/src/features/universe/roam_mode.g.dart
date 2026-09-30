// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'roam_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the personal universe opens in free roam (W05): the mode the
/// person last chose with the Tap to travel / Free roam switch. Tap-to-travel
/// is the default for everyone and stays one tap away. Presentation only:
/// kept on this phone, never pushed, and nothing is awarded for either mode.

@ProviderFor(RoamModePreference)
final roamModePreferenceProvider = RoamModePreferenceProvider._();

/// Whether the personal universe opens in free roam (W05): the mode the
/// person last chose with the Tap to travel / Free roam switch. Tap-to-travel
/// is the default for everyone and stays one tap away. Presentation only:
/// kept on this phone, never pushed, and nothing is awarded for either mode.
final class RoamModePreferenceProvider
    extends $AsyncNotifierProvider<RoamModePreference, bool> {
  /// Whether the personal universe opens in free roam (W05): the mode the
  /// person last chose with the Tap to travel / Free roam switch. Tap-to-travel
  /// is the default for everyone and stays one tap away. Presentation only:
  /// kept on this phone, never pushed, and nothing is awarded for either mode.
  RoamModePreferenceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roamModePreferenceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roamModePreferenceHash();

  @$internal
  @override
  RoamModePreference create() => RoamModePreference();
}

String _$roamModePreferenceHash() =>
    r'39b2e2f45f97b1497de3935e10245f55f4b8591a';

/// Whether the personal universe opens in free roam (W05): the mode the
/// person last chose with the Tap to travel / Free roam switch. Tap-to-travel
/// is the default for everyone and stays one tap away. Presentation only:
/// kept on this phone, never pushed, and nothing is awarded for either mode.

abstract class _$RoamModePreference extends $AsyncNotifier<bool> {
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
