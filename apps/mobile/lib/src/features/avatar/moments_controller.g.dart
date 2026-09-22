// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moments_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One-shot avatar moments (`evolve`, `wakeUp`). They are events, not state:
/// each has an id and plays once per id on this device, even if a later sync
/// re-delivers the same stage (REQ-AVA-05).

@ProviderFor(MomentsController)
final momentsControllerProvider = MomentsControllerProvider._();

/// One-shot avatar moments (`evolve`, `wakeUp`). They are events, not state:
/// each has an id and plays once per id on this device, even if a later sync
/// re-delivers the same stage (REQ-AVA-05).
final class MomentsControllerProvider
    extends $NotifierProvider<MomentsController, AvatarMoment?> {
  /// One-shot avatar moments (`evolve`, `wakeUp`). They are events, not state:
  /// each has an id and plays once per id on this device, even if a later sync
  /// re-delivers the same stage (REQ-AVA-05).
  MomentsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'momentsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$momentsControllerHash();

  @$internal
  @override
  MomentsController create() => MomentsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AvatarMoment? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AvatarMoment?>(value),
    );
  }
}

String _$momentsControllerHash() => r'79233982d2d4321e2bd205195073329f75793c81';

/// One-shot avatar moments (`evolve`, `wakeUp`). They are events, not state:
/// each has an id and plays once per id on this device, even if a later sync
/// re-delivers the same stage (REQ-AVA-05).

abstract class _$MomentsController extends $Notifier<AvatarMoment?> {
  AvatarMoment? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AvatarMoment?, AvatarMoment?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AvatarMoment?, AvatarMoment?>,
              AvatarMoment?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
