// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One open room (`/rooms/:id`): the detail, the two private Realtime topics,
/// the 45 s heartbeat while the app is in the foreground, and gestures with
/// a 30 s queue. Everything stops when the screen closes or you leave.

@ProviderFor(RoomController)
final roomControllerProvider = RoomControllerFamily._();

/// One open room (`/rooms/:id`): the detail, the two private Realtime topics,
/// the 45 s heartbeat while the app is in the foreground, and gestures with
/// a 30 s queue. Everything stops when the screen closes or you leave.
final class RoomControllerProvider
    extends $NotifierProvider<RoomController, RoomViewState> {
  /// One open room (`/rooms/:id`): the detail, the two private Realtime topics,
  /// the 45 s heartbeat while the app is in the foreground, and gestures with
  /// a 30 s queue. Everything stops when the screen closes or you leave.
  RoomControllerProvider._({
    required RoomControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'roomControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$roomControllerHash();

  @override
  String toString() {
    return r'roomControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RoomController create() => RoomController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomViewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomViewState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RoomControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$roomControllerHash() => r'acbe34110a2f8b09c8cc2edd29878bdc5587162b';

/// One open room (`/rooms/:id`): the detail, the two private Realtime topics,
/// the 45 s heartbeat while the app is in the foreground, and gestures with
/// a 30 s queue. Everything stops when the screen closes or you leave.

final class RoomControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          RoomController,
          RoomViewState,
          RoomViewState,
          RoomViewState,
          String
        > {
  RoomControllerFamily._()
    : super(
        retry: null,
        name: r'roomControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One open room (`/rooms/:id`): the detail, the two private Realtime topics,
  /// the 45 s heartbeat while the app is in the foreground, and gestures with
  /// a 30 s queue. Everything stops when the screen closes or you leave.

  RoomControllerProvider call(String roomId) =>
      RoomControllerProvider._(argument: roomId, from: this);

  @override
  String toString() => r'roomControllerProvider';
}

/// One open room (`/rooms/:id`): the detail, the two private Realtime topics,
/// the 45 s heartbeat while the app is in the foreground, and gestures with
/// a 30 s queue. Everything stops when the screen closes or you leave.

abstract class _$RoomController extends $Notifier<RoomViewState> {
  late final _$args = ref.$arg as String;
  String get roomId => _$args;

  RoomViewState build(String roomId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<RoomViewState, RoomViewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RoomViewState, RoomViewState>,
              RoomViewState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
