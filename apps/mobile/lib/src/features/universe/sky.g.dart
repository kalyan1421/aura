// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sky.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The sky over the personal universe (W06, RULES.md section 13 `sky`): the
/// phone's own time of day. No location, no permission, no personal data.
/// Rebuilds only when the phase changes, not on every clock tick.

@ProviderFor(sky)
final skyProvider = SkyProvider._();

/// The sky over the personal universe (W06, RULES.md section 13 `sky`): the
/// phone's own time of day. No location, no permission, no personal data.
/// Rebuilds only when the phase changes, not on every clock tick.

final class SkyProvider
    extends $FunctionalProvider<SkyPhase, SkyPhase, SkyPhase>
    with $Provider<SkyPhase> {
  /// The sky over the personal universe (W06, RULES.md section 13 `sky`): the
  /// phone's own time of day. No location, no permission, no personal data.
  /// Rebuilds only when the phase changes, not on every clock tick.
  SkyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skyHash();

  @$internal
  @override
  $ProviderElement<SkyPhase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SkyPhase create(Ref ref) {
    return sky(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SkyPhase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SkyPhase>(value),
    );
  }
}

String _$skyHash() => r'fcc1558e613d324a03bace510b2efa9d07316763';
