import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import 'room_models.dart';
import 'room_realtime.dart';
import 'rooms_providers.dart';
import 'rooms_repository.dart';

part 'room_controller.freezed.dart';
part 'room_controller.g.dart';

/// Heartbeat period while the room screen is in the foreground (§1.4;
/// "live" = seen within 2 min).
const Duration roomHeartbeatEvery = Duration(seconds: 45);

/// The tray rests this long after a send (the server allows 1 gesture per
/// 2 s across rooms).
const Duration gestureCooldown = Duration(seconds: 2);

/// A gesture that can't be sent (connection dropped) waits this long, then
/// is dropped quietly (PRD States: "gestures queue 30 s").
const Duration gestureQueueFor = Duration(seconds: 30);

/// Spacing between queued sends, so a flush never trips the 2 s limit
/// (3 limit hits in 24 h would shadow-mute the account).
const Duration _sendSpacing = Duration(milliseconds: 2100);

/// How long an anonymous `gesture_sent` waits for its named twin on the
/// member topic (or the sender's own reply) before it animates: a gesture
/// shows once.
const Duration _twinWindow = Duration(milliseconds: 700);

enum RoomLoad { loading, ready, failed }

/// A tapped gesture the server hasn't accepted yet (≤ [gestureQueueFor]).
@immutable
class PendingGesture {
  const PendingGesture({
    required this.localId,
    required this.type,
    this.toMemberId,
    this.toPseudonym,
  });

  final int localId;
  final GestureType type;
  final String? toMemberId;
  final String? toPseudonym;
}

enum GestureMomentKind {
  /// You sent it ("Warm Tea sent to Quiet Comet").
  sent,

  /// Sent to you ("Quiet Comet sent you Warm Tea").
  received,

  /// Someone else's, unnamed.
  room,
}

/// One gesture to animate and announce (REQ-A11Y-06). [serial] makes every
/// cue distinct.
@immutable
class GestureMoment {
  const GestureMoment({
    required this.serial,
    required this.kind,
    required this.type,
    this.pseudonym,
    this.toRoom = true,
    this.animate = true,
  });

  final int serial;
  final GestureMomentKind kind;
  final GestureType type;

  /// The recipient ([GestureMomentKind.sent] to a member) or the sender
  /// ([GestureMomentKind.received]).
  final String? pseudonym;
  final bool toRoom;

  /// `false` when the same gesture already played unnamed (its named copy
  /// arrived late): only the words show, so it plays once.
  final bool animate;
}

@freezed
abstract class RoomViewState with _$RoomViewState {
  const factory RoomViewState({
    @Default(RoomLoad.loading) RoomLoad load,
    RoomDetail? detail,

    /// Why the room can't show (with no [detail]), or why it ended (gone,
    /// suspended, …).
    RoomsFailure? failure,
    @Default(RoomLink.off) RoomLink link,
    @Default(<PendingGesture>[]) List<PendingGesture> pending,

    /// The tray rests for [gestureCooldown] after a send.
    @Default(false) bool coolingDown,
    GestureMoment? moment,

    /// You left: nothing more is sent or heard.
    @Default(false) bool left,
  }) = _RoomViewState;

  const RoomViewState._();

  bool get isMemory => detail?.room.isMemory ?? false;

  /// Lantern Hour right now (ended locally at `endsAt`, even if the end
  /// event is late).
  bool get lanternActive {
    final d = detail;
    return d != null && !d.room.isMemory && d.room.lanternHour.active;
  }

  bool get canSend =>
      detail != null && !isMemory && !left && !coolingDown && failure == null;
}

/// One open room (`/rooms/:id`): the detail, the two private Realtime topics,
/// the 45 s heartbeat while the app is in the foreground, and gestures with
/// a 30 s queue. Everything stops when the screen closes or you leave.
@riverpod
class RoomController extends _$RoomController {
  late String _roomId;
  late RoomsRepository _repo;
  RoomRealtime? _realtime;
  AppLifecycleListener? _lifecycle;

  Timer? _heartbeat;
  Timer? _cooldown;
  Timer? _lanternEnd;
  Timer? _presenceRefetch;
  Timer? _scheduledRefetch;
  Timer? _surveyRefetch;
  Timer? _spacing;
  Timer? _retryFlush;
  final Map<int, Timer> _expiry = {};

  /// Anonymous room gestures waiting for their named twin.
  final Map<String, Timer> _twins = {};

  /// Your own gestures (never animated again from the room feed).
  final Set<String> _ownIds = {};

  /// Gestures you received (the anonymous copy is never shown).
  final Set<String> _receivedIds = {};

  bool _disposed = false;
  bool _foreground = true;
  bool _flushing = false;
  bool _started = false;
  bool _refreshing = false;
  bool _refreshAgain = false;
  int _serial = 0;
  int _localIds = 0;

  @override
  RoomViewState build(String roomId) {
    _roomId = roomId;
    _repo = ref.read(roomsRepositoryProvider);
    ref.onDispose(_dispose);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    ref.listen(connectivityProvider, (prev, next) {
      final was = prev?.value;
      final now = next.value;
      if (now == true && was == false) _onBackOnline();
      if (now == false && was != false) _onOffline();
    });
    final prefetched = _repo.takePrefetched(roomId);
    scheduleMicrotask(() => _start(prefetched));
    return prefetched == null
        ? const RoomViewState()
        : RoomViewState(load: RoomLoad.ready, detail: prefetched);
  }

  // ---- lifecycle ---------------------------------------------------------------

  Future<void> _start(RoomDetail? prefetched) async {
    if (_disposed) return;
    if (prefetched == null) {
      await refresh();
    } else {
      _adopt(prefetched);
    }
    _begin();
  }

  /// Starts realtime and the heartbeat once there is a (non-memory) room.
  void _begin() {
    final d = state.detail;
    if (_disposed || _started || d == null || state.left) return;
    if (state.failure?.isTerminal ?? false) return;
    if (d.room.isMemory) return;
    _started = true;
    final open = ref.read(roomChannelOpenerProvider);
    if (open != null) {
      _realtime = RoomRealtime(
        open: open,
        onEvent: _onEvent,
        onLink: (link) => _set((s) => s.copyWith(link: link)),
        onSubscribed: _onSubscribed,
      )..start(d.realtime);
    }
    _startHeartbeat();
  }

  void _onLifecycle(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      if (_foreground) return;
      _foreground = true;
      if (!_started) return;
      // Once when back in the foreground (§1.4), then every 45 s.
      unawaited(_beat());
      _startHeartbeat();
      if (_realtime?.link == RoomLink.live) {
        unawaited(refresh());
      } else {
        _realtime?.retryNow();
      }
    } else if (s == AppLifecycleState.paused ||
        s == AppLifecycleState.hidden ||
        s == AppLifecycleState.detached) {
      _foreground = false;
      _heartbeat?.cancel();
      _heartbeat = null;
    }
  }

  void _onBackOnline() {
    if (_disposed) return;
    if (state.detail == null || state.failure != null) {
      // The room never loaded (or failed transiently): try again now.
      if (!(state.failure?.isTerminal ?? false)) unawaited(_retryLoad());
      return;
    }
    _realtime?.retryNow();
    _flush();
  }

  void _onOffline() {
    if (_realtime != null && !state.left) {
      _set((s) => s.copyWith(link: RoomLink.reconnecting));
    }
  }

  Future<void> _retryLoad() async {
    await refresh();
    _begin();
  }

  /// Load again after a failure ("Try again").
  Future<void> retry() => _retryLoad();

  void _dispose() {
    _disposed = true;
    _stopTimers();
    for (final t in _expiry.values) {
      t.cancel();
    }
    _expiry.clear();
    _lifecycle?.dispose();
    unawaited(_realtime?.stop());
  }

  void _stopTimers() {
    for (final t in [
      _heartbeat,
      _cooldown,
      _lanternEnd,
      _presenceRefetch,
      _scheduledRefetch,
      _surveyRefetch,
      _spacing,
      _retryFlush,
    ]) {
      t?.cancel();
    }
    for (final t in _twins.values) {
      t.cancel();
    }
    _twins.clear();
  }

  /// Ends everything live (left, gone, suspended): no heartbeat, no
  /// realtime, nothing queued.
  Future<void> _end() async {
    _stopTimers();
    for (final t in _expiry.values) {
      t.cancel();
    }
    _expiry.clear();
    _set((s) => s.copyWith(pending: const [], coolingDown: false));
    final realtime = _realtime;
    _realtime = null;
    await realtime?.stop();
    _set((s) => s.copyWith(link: RoomLink.off));
  }

  void _set(RoomViewState Function(RoomViewState s) change) {
    if (_disposed) return;
    state = change(state);
  }

  // ---- loading -------------------------------------------------------------------

  /// Fetches the room detail (members, counts, gestures). The truth after
  /// every (re)subscribe and `room_state`.
  Future<void> refresh() async {
    if (_disposed || state.left) return;
    if (_refreshing) {
      // One more once this one lands: it may predate what asked for it.
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      final detail = await _repo.room(_roomId);
      if (_disposed || state.left) return;
      _adopt(detail);
    } on RoomsFailure catch (f) {
      if (_disposed) return;
      if (f.isTerminal) {
        _refreshAgain = false;
        await _end();
        _set((s) => s.copyWith(load: RoomLoad.failed, failure: f));
      } else if (state.detail == null) {
        _set((s) => s.copyWith(load: RoomLoad.failed, failure: f));
      }
      // A hiccup with a room on screen: keep showing it.
    } finally {
      _refreshing = false;
      if (_refreshAgain && !_disposed) {
        _refreshAgain = false;
        unawaited(refresh());
      }
    }
  }

  void _adopt(RoomDetail detail) {
    _ownIds.addAll(detail.gestures.sent.map((g) => g.gestureId));
    _receivedIds.addAll(detail.gestures.received.map((g) => g.gestureId));
    final wasMemory = state.detail?.room.isMemory ?? false;
    _set(
      (s) => s.copyWith(load: RoomLoad.ready, detail: detail, failure: null),
    );
    _schedule(detail);
    if (detail.room.isMemory && !wasMemory) unawaited(_enterMemory());
  }

  /// Timers that follow the room's clock: Lantern Hour ends locally at
  /// `endsAt`; closing and memory transitions refetch; the survey becomes
  /// possible 30 s after joining.
  void _schedule(RoomDetail d) {
    final now = ref.read(timeContextProvider).now();
    _lanternEnd?.cancel();
    _lanternEnd = null;
    final lantern = d.room.lanternHour;
    if (lantern.active && !d.room.isMemory) {
      final left = lantern.endsAt.difference(now);
      if (left <= Duration.zero) {
        _endLantern();
      } else {
        _lanternEnd = Timer(left, _endLantern);
      }
    }
    _scheduledRefetch?.cancel();
    _scheduledRefetch = null;
    if (!d.room.isMemory) {
      final next = [d.room.joinsCloseAt, d.room.memoryAt]
          .where((t) => t.isAfter(now))
          .fold<DateTime?>(
            null,
            (a, b) => a == null || b.isBefore(a) ? b : a,
          );
      if (next != null) {
        _scheduledRefetch = Timer(
          next.difference(now) + const Duration(seconds: 2),
          () => unawaited(refresh()),
        );
      }
    }
    _surveyRefetch?.cancel();
    _surveyRefetch = null;
    final eligibleAt = d.me.joinedAt.add(const Duration(seconds: 31));
    if (!d.me.surveyEligible && eligibleAt.isAfter(now)) {
      _surveyRefetch = Timer(eligibleAt.difference(now), () {
        unawaited(refresh());
      });
    }
  }

  void _endLantern() {
    _lanternEnd = null;
    final d = state.detail;
    if (d == null || !d.room.lanternHour.active) return;
    _set(
      (s) => s.copyWith(
        detail: d.copyWith(
          room: d.room.copyWith(
            lanternHour: d.room.lanternHour.copyWith(active: false),
            state: d.room.phase == RoomPhase.lanternHour ? 'open' : d.room.state,
          ),
        ),
      ),
    );
  }

  /// The room became a memory: read-only, so nothing live is needed.
  Future<void> _enterMemory() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    final realtime = _realtime;
    _realtime = null;
    for (final t in _expiry.values) {
      t.cancel();
    }
    _expiry.clear();
    _set((s) => s.copyWith(pending: const []));
    await realtime?.stop();
    _set((s) => s.copyWith(link: RoomLink.off));
  }

  // ---- heartbeat -----------------------------------------------------------------

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
    if (!_foreground || state.isMemory || state.left) return;
    _heartbeat = Timer.periodic(roomHeartbeatEvery, (_) => unawaited(_beat()));
  }

  Future<void> _beat() async {
    final d = state.detail;
    if (_disposed || d == null || d.room.isMemory || state.left) return;
    try {
      final beat = await _repo.heartbeat(_roomId);
      final now = state.detail;
      if (_disposed || now == null || state.left) return;
      final changed =
          beat.room.state != now.room.state ||
          beat.room.readOnly != now.room.readOnly;
      final next = now.copyWith(room: beat.room, counts: beat.counts);
      _set((s) => s.copyWith(detail: next));
      _schedule(next);
      // Without realtime the heartbeat is the only poll: refetch gestures.
      if (changed || _realtime == null) unawaited(refresh());
    } on RoomsFailure catch (f) {
      if (f.isTerminal) await refresh();
    }
  }

  // ---- realtime -----------------------------------------------------------------

  void _onSubscribed() {
    // Best-effort delivery: refetch after every (re)subscribe (§3).
    unawaited(refresh());
    _flush();
  }

  void _onEvent(RoomEvent event) {
    final d = state.detail;
    if (_disposed || d == null || state.left) return;
    switch (event) {
      case MemberJoinedEvent(:final member, :final counts):
        final known = d.members.any((m) => m.memberId == member.memberId);
        _set(
          (s) => s.copyWith(
            detail: d.copyWith(
              members: known ? d.members : [...d.members, member],
              counts: counts ?? d.counts,
            ),
          ),
        );
      case MemberLeftEvent(:final memberId, :final counts):
        _set(
          (s) => s.copyWith(
            detail: d.copyWith(
              members: [
                for (final m in d.members)
                  if (m.memberId != memberId || m.isMe) m,
              ],
              counts: counts ?? d.counts,
            ),
          ),
        );
      case PresenceEvent(:final counts):
        _set((s) => s.copyWith(detail: d.copyWith(counts: counts)));
        // Who is live changed: refetch the member list, at most every 30 s.
        _presenceRefetch ??= Timer(const Duration(seconds: 30), () {
          _presenceRefetch = null;
          unawaited(refresh());
        });
      case GestureSentEvent(:final gesture):
        _onRoomGesture(gesture);
      case GestureReceivedEvent(:final gesture):
        _onReceived(gesture);
      case RoomStateEvent():
        _set(
          (s) => s.copyWith(
            detail: d.copyWith(
              room: d.room.copyWith(
                state: event.state,
                readOnly: event.readOnly,
                joinsCloseAt: event.joinsCloseAt ?? d.room.joinsCloseAt,
                memoryAt: event.memoryAt ?? d.room.memoryAt,
                purgeAt: event.purgeAt ?? d.room.purgeAt,
              ),
            ),
          ),
        );
        final next = state.detail;
        if (next != null && next.room.isMemory) unawaited(_enterMemory());
        unawaited(refresh());
      case LanternHourEvent(:final lanternHour):
        final next = d.copyWith(
          room: d.room.copyWith(
            lanternHour: lanternHour,
            state: switch (d.room.phase) {
              RoomPhase.open when lanternHour.active => 'lantern_hour',
              RoomPhase.lanternHour when !lanternHour.active => 'open',
              _ => d.room.state,
            },
          ),
        );
        _set((s) => s.copyWith(detail: next));
        _schedule(next);
    }
  }

  void _onRoomGesture(RoomGesture g) {
    final id = g.gestureId;
    if (_ownIds.contains(id) ||
        _receivedIds.contains(id) ||
        _twins.containsKey(id) ||
        g.gesture == null) {
      return;
    }
    // Wait briefly: the recipient also gets a named copy, and a sender's
    // own reply may still be on its way.
    _twins[id] = Timer(_twinWindow, () {
      _twins.remove(id);
      final d = state.detail;
      if (_disposed || d == null || _ownIds.contains(id)) return;
      if (_receivedIds.contains(id)) return;
      if (d.gestures.recent.any((r) => r.gestureId == id)) return;
      _set(
        (s) => s.copyWith(
          detail: d.copyWith(
            gestures: d.gestures.copyWith(recent: [g, ...d.gestures.recent]),
          ),
          moment: GestureMoment(
            serial: ++_serial,
            kind: GestureMomentKind.room,
            type: g.gesture!,
            toRoom: g.target == 'room',
          ),
        ),
      );
    });
  }

  void _onReceived(ReceivedGesture g) {
    final id = g.gestureId;
    final type = g.gesture;
    _twins.remove(id)?.cancel();
    final d = state.detail;
    if (d == null || type == null || _receivedIds.contains(id)) return;
    // Muted for you: never shown (the server drops them too).
    final from = d.members.where((m) => m.memberId == g.fromMemberId);
    if (from.isNotEmpty && from.first.muted) return;
    _receivedIds.add(id);
    final wasShown = d.gestures.recent.any((r) => r.gestureId == id);
    _set(
      (s) => s.copyWith(
        detail: d.copyWith(
          gestures: d.gestures.copyWith(
            received: [g, ...d.gestures.received],
            recent: [
              for (final r in d.gestures.recent)
                if (r.gestureId != id) r,
            ],
          ),
        ),
        // Shown once: the named cue, unless the unnamed copy already
        // played (then only its words show and are announced).
        moment: GestureMoment(
          serial: ++_serial,
          kind: GestureMomentKind.received,
          type: type,
          pseudonym: g.fromPseudonym,
          toRoom: false,
          animate: !wasShown,
        ),
      ),
    );
  }

  // ---- gestures ------------------------------------------------------------------

  /// Sends [type] to [to], or to everyone here. Plays and announces at once
  /// (it always "looks sent": the server may drop it silently); the tray
  /// then rests for [gestureCooldown]. With no connection it waits up to
  /// [gestureQueueFor] and is then dropped quietly.
  void sendGesture(GestureType type, {RoomMember? to}) {
    if (!state.canSend || (to?.isMe ?? false)) return;
    final item = PendingGesture(
      localId: ++_localIds,
      type: type,
      toMemberId: to?.memberId,
      toPseudonym: to?.pseudonym,
    );
    _set(
      (s) => s.copyWith(
        pending: [...s.pending, item],
        coolingDown: true,
        moment: GestureMoment(
          serial: ++_serial,
          kind: GestureMomentKind.sent,
          type: type,
          pseudonym: to?.pseudonym,
          toRoom: to == null,
        ),
      ),
    );
    _cooldown?.cancel();
    _cooldown = Timer(gestureCooldown, () {
      _cooldown = null;
      _set((s) => s.copyWith(coolingDown: false));
    });
    _expiry[item.localId] = Timer(gestureQueueFor, () {
      _expiry.remove(item.localId);
      _drop(item.localId); // stale: dropped quietly
    });
    _flush();
  }

  void _drop(int localId) => _set(
    (s) => s.copyWith(
      pending: [
        for (final p in s.pending)
          if (p.localId != localId) p,
      ],
    ),
  );

  bool get _online => ref.read(connectivityProvider).value ?? true;

  /// Sends queued gestures one at a time, [_sendSpacing] apart.
  void _flush() {
    if (_disposed || _flushing || _spacing != null || _retryFlush != null) {
      return;
    }
    if (state.pending.isEmpty || state.left || !_online) return;
    unawaited(_sendNext());
  }

  Future<void> _sendNext() async {
    final item = state.pending.first;
    _flushing = true;
    _spacing = Timer(_sendSpacing, () {
      _spacing = null;
      _flush();
    });
    try {
      final ack = await _repo.sendGesture(
        _roomId,
        item.type,
        toMemberId: item.toMemberId,
      );
      if (_disposed) return;
      _ownIds.add(ack.gestureId);
      _twins.remove(ack.gestureId)?.cancel();
      _expiry.remove(item.localId)?.cancel();
      final d = state.detail;
      _set(
        (s) => s.copyWith(
          pending: [
            for (final p in s.pending)
              if (p.localId != item.localId) p,
          ],
          detail: d?.copyWith(
            gestures: d.gestures.copyWith(
              sent: [
                SentGesture(
                  gestureId: ack.gestureId,
                  type: item.type.wire,
                  target: item.toMemberId == null ? 'room' : 'member',
                  toMemberId: item.toMemberId,
                  at: ack.at,
                ),
                ...d.gestures.sent,
              ],
            ),
          ),
        ),
      );
    } on RoomsFailure catch (f) {
      if (_disposed) return;
      if (f.isTransient) {
        // Kept until it goes stale; tried again on reconnect or 3 s after
        // the failure (never sooner: a request that timed out may still
        // have reached the server, and two within 2 s would be a limit hit).
        _spacing?.cancel();
        _spacing = null;
        _retryFlush?.cancel();
        _retryFlush = Timer(const Duration(seconds: 3), () {
          _retryFlush = null;
          _flush();
        });
        return;
      }
      _expiry.remove(item.localId)?.cancel();
      _drop(item.localId);
      if (f.isTerminal || f.kind == RoomsFailureKind.readOnly) {
        unawaited(refresh());
      } else if (f.kind == RoomsFailureKind.memberNotFound) {
        unawaited(refresh()); // they left: the list catches up quietly
      }
    } finally {
      _flushing = false;
    }
  }

  // ---- safety ---------------------------------------------------------------------

  /// Mutes (or unmutes) [member] for you in this room: their gestures stop
  /// reaching you. `false` when it didn't go through (nothing changed).
  Future<bool> setMuted(RoomMember member, {required bool muted}) async {
    final before = state.detail;
    if (before == null || member.isMe) return false;
    _updateMember(member.memberId, (m) => m.copyWith(muted: muted));
    try {
      if (muted) {
        await _repo.mute(_roomId, member.memberId);
        _hideReceivedFrom(member.memberId);
      } else {
        await _repo.unmute(_roomId, member.memberId);
        unawaited(refresh());
      }
      return true;
    } on RoomsFailure catch (f) {
      _updateMember(member.memberId, (m) => m.copyWith(muted: !muted));
      if (f.isTerminal) unawaited(refresh());
      return false;
    }
  }

  /// Blocks [member]'s account: never matched together again, gestures
  /// dropped both ways, and they disappear from your rooms. They are never
  /// told. `false` when it didn't go through.
  Future<bool> block(RoomMember member) async {
    if (member.isMe || state.detail == null) return false;
    try {
      await _repo.block(_roomId, member.memberId);
    } on RoomsFailure catch (f) {
      if (f.isTerminal) unawaited(refresh());
      return false;
    }
    final d = state.detail;
    if (d != null) {
      _set(
        (s) => s.copyWith(
          detail: d.copyWith(
            members: [
              for (final m in d.members)
                if (m.memberId != member.memberId) m,
            ],
          ),
        ),
      );
    }
    _hideReceivedFrom(member.memberId);
    unawaited(refresh());
    return true;
  }

  /// After a report: the item hides for you at once (a reported member is
  /// muted for you here, except for reason 1; a reported gesture drops
  /// out of your lists). The server does the same; a refetch follows.
  void reported(ReportTarget target, ReportReason reason) {
    switch (target) {
      case MemberReportTarget(:final memberId):
        if (reason != ReportReason.inDanger) {
          _updateMember(memberId, (m) => m.copyWith(muted: true));
          _hideReceivedFrom(memberId);
        }
      case GestureReportTarget(:final gestureId):
        final d = state.detail;
        if (d != null) {
          _set(
            (s) => s.copyWith(
              detail: d.copyWith(
                gestures: d.gestures.copyWith(
                  received: [
                    for (final g in d.gestures.received)
                      if (g.gestureId != gestureId) g,
                  ],
                  recent: [
                    for (final g in d.gestures.recent)
                      if (g.gestureId != gestureId) g,
                  ],
                ),
              ),
            ),
          );
        }
      case RoomReportTarget():
        break;
    }
    unawaited(refresh());
  }

  void _updateMember(String memberId, RoomMember Function(RoomMember) f) {
    final d = state.detail;
    if (d == null) return;
    _set(
      (s) => s.copyWith(
        detail: d.copyWith(
          members: [
            for (final m in d.members) m.memberId == memberId ? f(m) : m,
          ],
        ),
      ),
    );
  }

  void _hideReceivedFrom(String memberId) {
    final d = state.detail;
    if (d == null) return;
    _set(
      (s) => s.copyWith(
        detail: d.copyWith(
          gestures: d.gestures.copyWith(
            received: [
              for (final g in d.gestures.received)
                if (g.fromMemberId != memberId) g,
            ],
          ),
        ),
      ),
    );
  }

  // ---- leaving --------------------------------------------------------------------

  /// Leaves for good (frees the quadrant slot; no rejoining) and stops
  /// everything live. → whether to ask "Did you feel less alone?", or
  /// `null` when it didn't go through (still in the room).
  Future<bool?> leave() async {
    try {
      final eligible = await _repo.leave(_roomId);
      await _end();
      _set((s) => s.copyWith(left: true));
      ref.invalidate(myRoomsProvider);
      return eligible;
    } on RoomsFailure catch (f) {
      if (f.kind == RoomsFailureKind.notFound) {
        await _end();
        _set((s) => s.copyWith(left: true));
        ref.invalidate(myRoomsProvider);
        return false;
      }
      return null;
    }
  }

  /// Aggregate only; asked at most once a day (the server decides).
  Future<void> answerSurvey(SurveyAnswer answer) async {
    final d = state.detail;
    if (d != null) {
      _set(
        (s) => s.copyWith(
          detail: d.copyWith(me: d.me.copyWith(surveyEligible: false)),
        ),
      );
    }
    try {
      await _repo.survey(_roomId, answer);
    } on RoomsFailure catch (f) {
      debugPrint('rooms: survey not sent (${f.kind.name})');
    }
  }
}
