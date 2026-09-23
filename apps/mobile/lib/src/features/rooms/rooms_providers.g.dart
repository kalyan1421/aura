// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rooms_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `null` when this build has no API (debug builds without config).

@ProviderFor(roomsApi)
final roomsApiProvider = RoomsApiProvider._();

/// `null` when this build has no API (debug builds without config).

final class RoomsApiProvider
    extends $FunctionalProvider<RoomsApi?, RoomsApi?, RoomsApi?>
    with $Provider<RoomsApi?> {
  /// `null` when this build has no API (debug builds without config).
  RoomsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roomsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roomsApiHash();

  @$internal
  @override
  $ProviderElement<RoomsApi?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RoomsApi? create(Ref ref) {
    return roomsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomsApi? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomsApi?>(value),
    );
  }
}

String _$roomsApiHash() => r'8d9d9c48dd647963c4134ac8503897905fbbc8df';

@ProviderFor(roomsRepository)
final roomsRepositoryProvider = RoomsRepositoryProvider._();

final class RoomsRepositoryProvider
    extends
        $FunctionalProvider<RoomsRepository, RoomsRepository, RoomsRepository>
    with $Provider<RoomsRepository> {
  RoomsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roomsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roomsRepositoryHash();

  @$internal
  @override
  $ProviderElement<RoomsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RoomsRepository create(Ref ref) {
    return roomsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomsRepository>(value),
    );
  }
}

String _$roomsRepositoryHash() => r'fb18caa6c87806e937c8e26ec360c82de309d1bb';

/// Opens the private Realtime channels, or `null` when this build has no
/// Supabase (the room then polls with its heartbeat).

@ProviderFor(roomChannelOpener)
final roomChannelOpenerProvider = RoomChannelOpenerProvider._();

/// Opens the private Realtime channels, or `null` when this build has no
/// Supabase (the room then polls with its heartbeat).

final class RoomChannelOpenerProvider
    extends
        $FunctionalProvider<
          RoomChannelOpener?,
          RoomChannelOpener?,
          RoomChannelOpener?
        >
    with $Provider<RoomChannelOpener?> {
  /// Opens the private Realtime channels, or `null` when this build has no
  /// Supabase (the room then polls with its heartbeat).
  RoomChannelOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roomChannelOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roomChannelOpenerHash();

  @$internal
  @override
  $ProviderElement<RoomChannelOpener?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RoomChannelOpener? create(Ref ref) {
    return roomChannelOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomChannelOpener? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomChannelOpener?>(value),
    );
  }
}

String _$roomChannelOpenerHash() => r'2bdb25efaaaf961fdc3fb0841af833a7904dbc43';

/// Whether rooms can be used here at all: an API and Supabase sign-in in
/// this build, a signed-in account and a finished onboarding.

@ProviderFor(roomsReady)
final roomsReadyProvider = RoomsReadyProvider._();

/// Whether rooms can be used here at all: an API and Supabase sign-in in
/// this build, a signed-in account and a finished onboarding.

final class RoomsReadyProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether rooms can be used here at all: an API and Supabase sign-in in
  /// this build, a signed-in account and a finished onboarding.
  RoomsReadyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roomsReadyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roomsReadyHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return roomsReady(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$roomsReadyHash() => r'c663c7733a4ef7163707aadbee236a750940e9ff';

/// The rooms you are in (`GET /v1/rooms`), newest first: active ones and
/// memories. Empty until rooms are usable ([roomsReady]); offline it fails
/// with [RoomsFailureKind.offline] and never calls. Refreshed on reconnect,
/// on resume and every 90 s while something shows it.

@ProviderFor(MyRooms)
final myRoomsProvider = MyRoomsProvider._();

/// The rooms you are in (`GET /v1/rooms`), newest first: active ones and
/// memories. Empty until rooms are usable ([roomsReady]); offline it fails
/// with [RoomsFailureKind.offline] and never calls. Refreshed on reconnect,
/// on resume and every 90 s while something shows it.
final class MyRoomsProvider
    extends $AsyncNotifierProvider<MyRooms, List<RoomSummary>> {
  /// The rooms you are in (`GET /v1/rooms`), newest first: active ones and
  /// memories. Empty until rooms are usable ([roomsReady]); offline it fails
  /// with [RoomsFailureKind.offline] and never calls. Refreshed on reconnect,
  /// on resume and every 90 s while something shows it.
  MyRoomsProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRoomsRetry,
        name: r'myRoomsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myRoomsHash();

  @$internal
  @override
  MyRooms create() => MyRooms();
}

String _$myRoomsHash() => r'54c44768fb1dc29485070eba7643ea9067b75d50';

/// The rooms you are in (`GET /v1/rooms`), newest first: active ones and
/// memories. Empty until rooms are usable ([roomsReady]); offline it fails
/// with [RoomsFailureKind.offline] and never calls. Refreshed on reconnect,
/// on resume and every 90 s while something shows it.

abstract class _$MyRooms extends $AsyncNotifier<List<RoomSummary>> {
  FutureOr<List<RoomSummary>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<RoomSummary>>, List<RoomSummary>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<RoomSummary>>, List<RoomSummary>>,
              AsyncValue<List<RoomSummary>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
