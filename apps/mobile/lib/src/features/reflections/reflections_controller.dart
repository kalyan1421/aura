import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../rooms/room_controller.dart';
import '../rooms/room_models.dart' show GestureType;
import '../rooms/room_realtime.dart';
import 'reflection_models.dart';
import 'reflections_providers.dart';
import 'reflections_repository.dart';

part 'reflections_controller.freezed.dart';
part 'reflections_controller.g.dart';

/// The gestures on reflections rest this long after a send (the server
/// allows 1 gesture per 2 s across rooms).
const Duration reflectionGestureCooldown = Duration(seconds: 2);

/// Without a live realtime link the list polls this often.
const Duration reflectionsPollEvery = Duration(seconds: 60);

enum ReflectionsLoad { loading, ready, failed }

@freezed
abstract class RoomReflectionsState with _$RoomReflectionsState {
  const factory RoomReflectionsState({
    @Default(ReflectionsLoad.loading) ReflectionsLoad load,

    /// Newest first, as the server sent them (minus what you just hid).
    @Default(<Reflection>[]) List<Reflection> reflections,
    ReflectionComposer? composer,

    /// Why the list couldn't load (kept with an older list on screen).
    ReflectionsFailure? failure,

    /// The gestures rest for [reflectionGestureCooldown] after a send.
    @Default(false) bool coolingDown,

    /// Bumped when one of your reflections was crisis-diverted after the
    /// composer closed (`reflection_status`): the room opens the support
    /// sheet at once.
    @Default(0) int supportSerial,
  }) = _RoomReflectionsState;

  const RoomReflectionsState._();

  bool get isEmpty => reflections.isEmpty;
}

/// A room's reflections (F6, contracts/api/v1-reflections.md): the list and
/// the composer state, kept fresh by the room's realtime hints
/// (`reflection_published`, `reflection_removed`, `reflection_status`,
/// `gesture_received` on your reflection → refetch), by every (re)subscribe
/// and reconnect, and by a slow poll while realtime is down. Sending,
/// deleting and gestures on reflections go through here; the text is never
/// logged.
@riverpod
class RoomReflections extends _$RoomReflections {
  late String _roomId;
  late ReflectionsRepository _repo;
  StreamSubscription<ReflectionEvent>? _events;
  Timer? _poll;
  Timer? _cooldown;
  bool _disposed = false;
  bool _refreshing = false;
  bool _refreshAgain = false;

  /// Reflections hidden on this phone before the server caught up
  /// (reported, deleted, their author blocked or muted).
  final Set<String> _hidden = {};

  /// Members whose reflections you hid here (blocked or muted).
  final Set<String> _hiddenAuthors = {};

  /// Crisis-diverted reflections whose support sheet already opened.
  final Set<String> _supportShown = {};

  @override
  RoomReflectionsState build(String roomId) {
    _roomId = roomId;
    _repo = ref.read(reflectionsRepositoryProvider);
    ref.onDispose(_dispose);
    final room = roomControllerProvider(roomId);
    // Keeps the room alive while its reflections show, and follows it.
    ref.listen(room.select((s) => s.link), (prev, next) {
      if (next == RoomLink.live && prev != RoomLink.live) {
        // Best-effort delivery: refetch after every (re)subscribe.
        unawaited(refresh());
      }
      _schedulePoll(next);
    });
    ref.listen(room.select((s) => s.isMemory), (prev, next) {
      if (next && prev == false) unawaited(refresh());
    });
    ref.listen(connectivityProvider, (prev, next) {
      if (next.value == true && prev?.value == false) unawaited(refresh());
    });
    _events = ref
        .read(room.notifier)
        .reflectionEvents
        .listen(_onEvent, onError: (Object _) {});
    _schedulePoll(ref.read(room).link);
    if (!_repo.isAvailable) {
      return const RoomReflectionsState(
        load: ReflectionsLoad.failed,
        failure: ReflectionsFailure(ReflectionsFailureKind.unavailable),
      );
    }
    scheduleMicrotask(() => unawaited(_start()));
    return const RoomReflectionsState();
  }

  /// The first load waits for the first known connection state (never
  /// calls on a guess); offline it says so without calling.
  Future<void> _start() async {
    bool online;
    try {
      online = await ref.read(connectivityProvider.future);
    } on Object {
      online = true;
    }
    if (_disposed) return;
    if (!online) {
      _set(
        (s) => s.copyWith(
          load: ReflectionsLoad.failed,
          failure: const ReflectionsFailure(ReflectionsFailureKind.offline),
        ),
      );
      return;
    }
    await refresh();
  }

  void _dispose() {
    _disposed = true;
    _poll?.cancel();
    _cooldown?.cancel();
    unawaited(_events?.cancel());
  }

  void _set(RoomReflectionsState Function(RoomReflectionsState s) change) {
    if (_disposed) return;
    state = change(state);
  }

  void _schedulePoll(RoomLink link) {
    _poll?.cancel();
    _poll = null;
    if (_disposed || link == RoomLink.live || !_repo.isAvailable) return;
    _poll = Timer.periodic(reflectionsPollEvery, (_) => unawaited(refresh()));
  }

  void _onEvent(ReflectionEvent e) {
    if (_disposed) return;
    if (e.event == 'reflection_status' &&
        e.status == 'crisis_diverted' &&
        _supportShown.add(e.reflectionId)) {
      // Never published; help first (REQ-REF-04: the sheet opens at once).
      _set((s) => s.copyWith(supportSerial: s.supportSerial + 1));
    }
    if (e.event == 'reflection_removed') _drop(e.reflectionId);
    unawaited(refresh());
  }

  List<Reflection> _visible(List<Reflection> list) => [
    for (final r in list)
      if (!_hidden.contains(r.reflectionId) &&
          !(!r.isMine && _hiddenAuthors.contains(r.author.memberId)) &&
          r.statusValue != ReflectionStatus.crisisDiverted)
        r,
  ];

  void _drop(String reflectionId) => _set(
    (s) => s.copyWith(
      reflections: [
        for (final r in s.reflections)
          if (r.reflectionId != reflectionId) r,
      ],
    ),
  );

  // ---- loading ---------------------------------------------------------------------

  /// Fetches the list and the composer state (the truth after every hint).
  Future<void> refresh() async {
    if (_disposed || !_repo.isAvailable) return;
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      final list = await _repo.list(_roomId);
      if (_disposed) return;
      // The server has caught up with what was hidden here.
      _hidden.removeWhere(
        (id) => !list.reflections.any((r) => r.reflectionId == id),
      );
      _set(
        (s) => s.copyWith(
          load: ReflectionsLoad.ready,
          reflections: _visible(list.reflections),
          composer: list.composer,
          failure: null,
        ),
      );
    } on ReflectionsFailure catch (f) {
      if (_disposed) return;
      // A hiccup with a list on screen: keep showing it (with a note).
      _set(
        (s) => s.copyWith(
          load: s.load == ReflectionsLoad.ready
              ? ReflectionsLoad.ready
              : ReflectionsLoad.failed,
          failure: f,
        ),
      );
    } finally {
      _refreshing = false;
      if (_refreshAgain && !_disposed) {
        _refreshAgain = false;
        unawaited(refresh());
      }
    }
  }

  // ---- sending ---------------------------------------------------------------------

  /// Sends [text] under [reflectionId] (the draft's; reused on a retry).
  /// Throws [ReflectionsFailure] when it didn't reach a decision (offline,
  /// network, limits, paused, read-only…); the composer state follows the
  /// answer either way.
  Future<SendOutcome> send({
    required String reflectionId,
    required String text,
  }) async {
    try {
      final outcome = await _repo.send(
        _roomId,
        reflectionId: reflectionId,
        text: text,
      );
      if (outcome.statusValue == ReflectionStatus.crisisDiverted) {
        // The composer opens help for this one; the event must not again.
        _supportShown.add(outcome.reflectionId);
      }
      final item = outcome.reflection;
      _set(
        (s) => s.copyWith(
          composer: outcome.composer,
          reflections: item == null
              ? s.reflections
              : _visible([
                  item,
                  for (final r in s.reflections)
                    if (r.reflectionId != item.reflectionId) r,
                ]),
        ),
      );
      unawaited(refresh());
      return outcome;
    } on ReflectionsFailure catch (f) {
      final composer = state.composer;
      if (composer != null) {
        final next = switch (f.kind) {
          ReflectionsFailureKind.roomLimit ||
          ReflectionsFailureKind.dailyLimit => composer.copyWith(
            state: 'limit_reached',
            remainingInRoom: f.kind == ReflectionsFailureKind.roomLimit
                ? 0
                : composer.remainingInRoom,
            remainingToday: f.kind == ReflectionsFailureKind.dailyLimit
                ? 0
                : composer.remainingToday,
          ),
          ReflectionsFailureKind.paused => composer.copyWith(state: 'paused'),
          ReflectionsFailureKind.readOnly => composer.copyWith(
            state: 'read_only',
          ),
          _ => composer,
        };
        _set((s) => s.copyWith(composer: next));
      }
      if (!f.isTransient) unawaited(refresh());
      rethrow;
    }
  }

  /// Deletes your published reflection, or withdraws a pending / held one.
  /// `false` when it didn't go through (nothing changed).
  Future<bool> delete(Reflection r) async {
    if (!r.isMine) return false;
    try {
      await _repo.delete(_roomId, r.reflectionId);
    } on ReflectionsFailure catch (f) {
      if (f.kind != ReflectionsFailureKind.reflectionNotFound) return false;
      // Already gone: the same as deleted.
    }
    _hidden.add(r.reflectionId);
    _drop(r.reflectionId);
    unawaited(refresh());
    return true;
  }

  // ---- gestures ------------------------------------------------------------------

  /// A gesture on someone's published reflection. It always "looks sent"
  /// (the server may drop it silently); the gestures then rest for
  /// [reflectionGestureCooldown]. `false` when it couldn't be sent at all
  /// (offline, the reflection is gone).
  Future<bool> sendGesture(Reflection r, GestureType type) async {
    if (r.isMine || !r.isPublished || state.coolingDown) return false;
    _set((s) => s.copyWith(coolingDown: true));
    _cooldown?.cancel();
    _cooldown = Timer(reflectionGestureCooldown, () {
      _cooldown = null;
      _set((s) => s.copyWith(coolingDown: false));
    });
    try {
      final ack = await _repo.sendGesture(
        _roomId,
        type,
        reflectionId: r.reflectionId,
      );
      if (_disposed) return true;
      ref
          .read(roomControllerProvider(_roomId).notifier)
          .noteOwnGesture(ack.gestureId);
      return true;
    } on ReflectionsFailure catch (f) {
      _cooldown?.cancel();
      _cooldown = null;
      _set((s) => s.copyWith(coolingDown: false));
      if (f.kind == ReflectionsFailureKind.reflectionNotFound) {
        _drop(r.reflectionId);
        unawaited(refresh());
      }
      return false;
    }
  }

  // ---- safety ----------------------------------------------------------------------

  /// After a report: it hides for you at once (the server does the same).
  void reported(String reflectionId) {
    _hidden.add(reflectionId);
    _drop(reflectionId);
    unawaited(refresh());
  }

  /// After a block or a mute: their reflections leave your list.
  void hideAuthor(String memberId) {
    _hiddenAuthors.add(memberId);
    _set((s) => s.copyWith(reflections: _visible(s.reflections)));
    unawaited(refresh());
  }

  /// After an unmute: their reflections come back with the next fetch.
  void showAuthor(String memberId) {
    _hiddenAuthors.remove(memberId);
    unawaited(refresh());
  }

  @visibleForTesting
  Set<String> get hiddenIds => {..._hidden};
}
