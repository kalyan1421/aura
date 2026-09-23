// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gate_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loaded before the first frame (main.dart) so a blocked device never sees
/// the DOB screen flash.

@ProviderFor(initialGate)
final initialGateProvider = InitialGateProvider._();

/// Loaded before the first frame (main.dart) so a blocked device never sees
/// the DOB screen flash.

final class InitialGateProvider
    extends $FunctionalProvider<GateState, GateState, GateState>
    with $Provider<GateState> {
  /// Loaded before the first frame (main.dart) so a blocked device never sees
  /// the DOB screen flash.
  InitialGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialGateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialGateHash();

  @$internal
  @override
  $ProviderElement<GateState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GateState create(Ref ref) {
    return initialGate(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GateState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GateState>(value),
    );
  }
}

String _$initialGateHash() => r'37e284191b443e65b5a99f00e2e19c9aa45eaff9';

@ProviderFor(GateController)
final gateControllerProvider = GateControllerProvider._();

final class GateControllerProvider
    extends $NotifierProvider<GateController, GateState> {
  GateControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gateControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gateControllerHash();

  @$internal
  @override
  GateController create() => GateController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GateState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GateState>(value),
    );
  }
}

String _$gateControllerHash() => r'3d924ad3c424ef25754b815b3153eb28f53059c2';

abstract class _$GateController extends $Notifier<GateState> {
  GateState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GateState, GateState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GateState, GateState>,
              GateState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
