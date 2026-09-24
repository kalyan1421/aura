import 'dart:async';

import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/features/ripples/ripple_channel.dart';
import 'package:aura/src/features/ripples/ripple_feedback.dart';
import 'package:aura/src/features/ripples/ripple_models.dart';
import 'package:aura/src/features/ripples/ripples_api.dart';

/// A fixed wall clock: time in these tests is the ticker's (pump), so the
/// server-clock estimate stays exact.
const int fakeWallMs = 1791466200000;

/// A short session: 2 s settle, [cycles] × (4 s in / 6 s out), 1 s fade.
RippleSession fakeSession({
  int cycles = 3,
  RippleEntry entry = RippleEntry.quick,
  List<RippleSeat>? seats,
  int humans = 2,
  int echoes = 1,
  int guides = 1,
  int t0Ms = fakeWallMs,
}) => RippleSession(
  sessionId: 'session-1',
  entry: entry,
  roomId: entry == RippleEntry.room ? 'room-1' : null,
  t0Ms: t0Ms,
  settleMs: 2000,
  cycles: cycles,
  fadeMs: 1000,
  mySeat: 1,
  humans: humans,
  echoes: echoes,
  guides: guides,
  seats:
      seats ??
      const [
        RippleSeat(seat: 1, kind: SeatKind.human, label: 'Quiet Comet'),
        RippleSeat(seat: 2, kind: SeatKind.human, label: 'Gentle Moon'),
        RippleSeat(seat: 3, kind: SeatKind.echo, trace: [0, 1, -1, null]),
        RippleSeat(seat: 4, kind: SeatKind.guide),
      ],
);

class FakeRipplesApi implements RipplesApi {
  FakeRipplesApi({this.current, this.waitPolls = 0, this.error});

  RippleSession? current;

  /// Answer "waiting" this many times before "matched".
  int waitPolls;
  Object? error;
  RippleInvite? invite;
  bool consent = true;

  final List<String> tickets = [];
  final List<String> cancelled = [];
  final List<(int cycles, List<int?>? offsets)> completes = [];
  final List<String> left = [];
  final List<int> floods = [];
  final List<(int seat, int reason)> reports = [];
  final List<int> blocks = [];
  int sessionFetches = 0;

  @override
  Future<MatchPoll> match(
    String ticketId,
    RippleEntry entry, {
    String? roomId,
  }) async {
    tickets.add(ticketId);
    final e = error;
    if (e != null) throw e;
    if (waitPolls > 0 || current == null) {
      waitPolls--;
      return MatchWaiting(
        ticketId: ticketId,
        serverTimeMs: fakeWallMs,
        pollAfterMs: 2000,
        invite: invite,
      );
    }
    return MatchMatched(
      ticketId: ticketId,
      serverTimeMs: fakeWallMs,
      session: current!,
    );
  }

  @override
  Future<void> cancel(String ticketId) async => cancelled.add(ticketId);

  @override
  Future<RippleSession> session(String sessionId) async {
    sessionFetches++;
    return current!;
  }

  @override
  Future<void> leave(String sessionId) async => left.add(sessionId);

  @override
  Future<void> complete(
    String sessionId,
    int cycles,
    List<int?>? offsets,
  ) async => completes.add((cycles, offsets));

  @override
  Future<bool> report(
    String sessionId,
    int seat,
    int reason, {
    String? note,
  }) async {
    reports.add((seat, reason));
    return reason == 1;
  }

  @override
  Future<void> block(String sessionId, int seat) async => blocks.add(seat);

  @override
  Future<void> flood(String sessionId, int seat) async => floods.add(seat);

  @override
  Future<RippleInvite?> roomInvite(String roomId) async => invite;

  @override
  Future<bool> echoConsent() async => consent;

  @override
  Future<bool> setEchoConsent(bool enabled) async => consent = enabled;
}

const ApiException paused = ApiException(code: 'ripples_paused', status: 503);

/// A private channel the test drives: it records what the phone sends and
/// can deliver broadcasts or drop the link.
class FakeRippleChannel implements RippleChannel {
  FakeRippleChannel(this.topic);

  final String topic;
  void Function(String, Map<String, dynamic>)? _cb;
  void Function(RippleLinkStatus)? _status;
  final List<(String, Map<String, dynamic>)> sent = [];
  final List<Map<String, dynamic>> tracked = [];
  bool closed = false;

  void deliver(String event, Map<String, dynamic> payload) =>
      _cb?.call(event, payload);
  void status(RippleLinkStatus s) => _status?.call(s);

  @override
  void onEvent(void Function(String event, Map<String, dynamic> payload) cb) =>
      _cb = cb;

  @override
  void subscribe(void Function(RippleLinkStatus status) onStatus) {
    _status = onStatus;
    scheduleMicrotask(() => onStatus(RippleLinkStatus.subscribed));
  }

  @override
  Future<void> send(String event, Map<String, dynamic> payload) async =>
      sent.add((event, payload));

  @override
  Future<void> track(Map<String, dynamic> payload) async =>
      tracked.add(payload);

  @override
  Future<void> close() async => closed = true;
}

class FakeChannels {
  final List<FakeRippleChannel> opened = [];
  bool refuse = false;

  FakeRippleChannel get last => opened.last;

  Future<RippleChannel> open(String topic) async {
    if (refuse) throw StateError('refused');
    final c = FakeRippleChannel(topic);
    opened.add(c);
    return c;
  }
}

class FakeRippleFeedback implements RippleFeedback {
  final List<(bool inhale, double? strength, bool tone)> phases = [];
  int pulses = 0;

  @override
  void phase({required bool inhale, double? strength, bool tone = false}) =>
      phases.add((inhale, strength, tone));

  @override
  void pulse() => pulses++;

  @override
  Future<void> dispose() async {}
}
