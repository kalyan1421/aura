// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reflections_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A room's reflections (F6, contracts/api/v1-reflections.md): the list and
/// the composer state, kept fresh by the room's realtime hints
/// (`reflection_published`, `reflection_removed`, `reflection_status`,
/// `gesture_received` on your reflection → refetch), by every (re)subscribe
/// and reconnect, and by a slow poll while realtime is down. Sending,
/// deleting and gestures on reflections go through here; the text is never
/// logged.

@ProviderFor(RoomReflections)
final roomReflectionsProvider = RoomReflectionsFamily._();

/// A room's reflections (F6, contracts/api/v1-reflections.md): the list and
/// the composer state, kept fresh by the room's realtime hints
/// (`reflection_published`, `reflection_removed`, `reflection_status`,
/// `gesture_received` on your reflection → refetch), by every (re)subscribe
/// and reconnect, and by a slow poll while realtime is down. Sending,
/// deleting and gestures on reflections go through here; the text is never
/// logged.
final class RoomReflectionsProvider
    extends $NotifierProvider<RoomReflections, RoomReflectionsState> {
  /// A room's reflections (F6, contracts/api/v1-reflections.md): the list and
  /// the composer state, kept fresh by the room's realtime hints
  /// (`reflection_published`, `reflection_removed`, `reflection_status`,
  /// `gesture_received` on your reflection → refetch), by every (re)subscribe
  /// and reconnect, and by a slow poll while realtime is down. Sending,
  /// deleting and gestures on reflections go through here; the text is never
  /// logged.
  RoomReflectionsProvider._({
    required RoomReflectionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'roomReflectionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$roomReflectionsHash();

  @override
  String toString() {
    return r'roomReflectionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RoomReflections create() => RoomReflections();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomReflectionsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomReflectionsState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RoomReflectionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$roomReflectionsHash() => r'5604a26769d121b779759823cc93bf5e046ff90b';

/// A room's reflections (F6, contracts/api/v1-reflections.md): the list and
/// the composer state, kept fresh by the room's realtime hints
/// (`reflection_published`, `reflection_removed`, `reflection_status`,
/// `gesture_received` on your reflection → refetch), by every (re)subscribe
/// and reconnect, and by a slow poll while realtime is down. Sending,
/// deleting and gestures on reflections go through here; the text is never
/// logged.

final class RoomReflectionsFamily extends $Family
    with
        $ClassFamilyOverride<
          RoomReflections,
          RoomReflectionsState,
          RoomReflectionsState,
          RoomReflectionsState,
          String
        > {
  RoomReflectionsFamily._()
    : super(
        retry: null,
        name: r'roomReflectionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A room's reflections (F6, contracts/api/v1-reflections.md): the list and
  /// the composer state, kept fresh by the room's realtime hints
  /// (`reflection_published`, `reflection_removed`, `reflection_status`,
  /// `gesture_received` on your reflection → refetch), by every (re)subscribe
  /// and reconnect, and by a slow poll while realtime is down. Sending,
  /// deleting and gestures on reflections go through here; the text is never
  /// logged.

  RoomReflectionsProvider call(String roomId) =>
      RoomReflectionsProvider._(argument: roomId, from: this);

  @override
  String toString() => r'roomReflectionsProvider';
}

/// A room's reflections (F6, contracts/api/v1-reflections.md): the list and
/// the composer state, kept fresh by the room's realtime hints
/// (`reflection_published`, `reflection_removed`, `reflection_status`,
/// `gesture_received` on your reflection → refetch), by every (re)subscribe
/// and reconnect, and by a slow poll while realtime is down. Sending,
/// deleting and gestures on reflections go through here; the text is never
/// logged.

abstract class _$RoomReflections extends $Notifier<RoomReflectionsState> {
  late final _$args = ref.$arg as String;
  String get roomId => _$args;

  RoomReflectionsState build(String roomId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<RoomReflectionsState, RoomReflectionsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RoomReflectionsState, RoomReflectionsState>,
              RoomReflectionsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
