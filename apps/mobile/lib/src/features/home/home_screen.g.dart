// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Check-ins saved on this phone for the current Aura day (deleted ones
/// excluded), for the history line.

@ProviderFor(checkInsToday)
final checkInsTodayProvider = CheckInsTodayProvider._();

/// Check-ins saved on this phone for the current Aura day (deleted ones
/// excluded), for the history line.

final class CheckInsTodayProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Check-ins saved on this phone for the current Aura day (deleted ones
  /// excluded), for the history line.
  CheckInsTodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkInsTodayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkInsTodayHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return checkInsToday(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$checkInsTodayHash() => r'd8a0c9f2e116bf2010b2f1b5f591212fc0790dbd';
