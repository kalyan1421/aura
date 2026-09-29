// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decay_eligibility.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [ageYearsFor] from the encrypted key-value store and today's Aura day.
/// Never leaves the phone.

@ProviderFor(deviceAgeYears)
final deviceAgeYearsProvider = DeviceAgeYearsProvider._();

/// [ageYearsFor] from the encrypted key-value store and today's Aura day.
/// Never leaves the phone.

final class DeviceAgeYearsProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// [ageYearsFor] from the encrypted key-value store and today's Aura day.
  /// Never leaves the phone.
  DeviceAgeYearsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceAgeYearsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceAgeYearsHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return deviceAgeYears(ref);
  }
}

String _$deviceAgeYearsHash() => r'55b3b9d14493e7667c458e4b97957e5cbea12e86';
