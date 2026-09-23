import 'dart:async';

import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/features/rooms/room_controller.dart';
import 'package:aura/src/features/rooms/room_models.dart';
import 'package:aura/src/features/rooms/room_realtime.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'rooms_fakes.dart';

/// The open room (RoomController): both private topics, events, "show it
/// once", reconnect with backoff and a refetch after every subscribe, the
/// 30 s gesture queue, the heartbeat, Lantern Hour's local end, memory and
/// leaving.

class _Room {
  _Room(this.c, this.api, this.channels, this.net);

  final ProviderContainer c;
  final FakeRoomsApi api;
  final FakeChannels channels;
  final StreamController<bool> net;
  final List<GestureMoment> moments = [];

  RoomViewState get state => c.read(roomControllerProvider(roomId));
  RoomController get room => c.read(roomControllerProvider(roomId).notifier);
}

/// Opens the room in a ProviderScope that lives in the widget tree, so it
/// (and every timer the room holds) is disposed with the tree at the end of
/// the test.
Future<_Room> _open(
  WidgetTester tester, {
  FakeRoomsApi? api,
  bool autoJoin = true,
}) async {
  final server = api ?? FakeRoomsApi();
  final channels = FakeChannels()..autoJoin = autoJoin;
  final net = StreamController<bool>.broadcast();
  addTearDown(net.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: roomsTestOverrides(
        db: memoryDb(),
        api: server,
        channels: channels,
        connectivity: net.stream,
      ),
      child: Consumer(
        builder: (context, ref, _) {
          ref.watch(roomControllerProvider(roomId));
          return const SizedBox(key: ValueKey('host'));
        },
      ),
    ),
  );
  final c = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('host'))),
  );
  final r = _Room(c, server, channels, net);
  c.listen(roomControllerProvider(roomId), (prev, next) {
    final m = next.moment;
    if (m != null && m.serial != prev?.moment?.serial) r.moments.add(m);
  });
  await _settle(tester);
  return r;
}

/// Lets the fake server, channels and stream events land.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

/// Steps the app through [states] (AppLifecycleListener checks that each
/// transition is a real one).
void _lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
  for (final s in states) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

Map<String, dynamic> _gesture(
  String id, {
  String type = 'warm_tea',
  String target = 'member',
}) => {
  'gestureId': id,
  'type': type,
  'target': target,
  'at': serverNow.toIso8601String(),
};

Map<String, dynamic> _received(String id, {String from = cometId}) => {
  'gestureId': id,
  'type': 'warm_tea',
  'fromMemberId': from,
  'fromPseudonym': from == cometId ? 'Quiet Comet' : 'Silver River',
  'at': serverNow.toIso8601String(),
};

void main() {
  testWidgets('joins both private topics, then refetches the room after '
      'subscribing (events are hints)', (tester) async {
    final r = await _open(tester);
    expect(r.channels.opened.map((c) => c.topic), [
      'room:$roomId',
      'member:$meId',
    ]);
    expect(r.channels.opened.every((c) => c.subscribed), isTrue);
    expect(r.state.link, RoomLink.live);
    expect(r.api.count('room'), 2, reason: 'the first load + after subscribe');
    expect(r.state.detail!.me.pseudonym, 'Soft Harbor');
  });

  testWidgets('member_joined, member_left and presence update members and '
      'real counts; presence refetches who is live', (tester) async {
    final r = await _open(tester);
    r.channels.room.emit('member_joined', {
      'member': memberJson('m4', 'Kind Lantern', mood: 'melancholy'),
      'counts': {'hereNow': 4, 'today': 19},
      'at': serverNow.toIso8601String(),
    });
    await _settle(tester);
    expect(
      r.state.detail!.members.map((m) => m.pseudonym),
      contains('Kind Lantern'),
    );
    expect(r.state.detail!.counts.hereNow, 4);

    r.channels.room.emit('member_left', {
      'memberId': 'm4',
      'counts': {'hereNow': 3, 'today': 19},
      'at': serverNow.toIso8601String(),
    });
    await _settle(tester);
    expect(
      r.state.detail!.members.map((m) => m.pseudonym),
      isNot(contains('Kind Lantern')),
    );

    final before = r.api.count('room');
    r.channels.room.emit('presence', {
      'counts': {'hereNow': 2, 'today': 19},
      'at': serverNow.toIso8601String(),
    });
    await _settle(tester);
    expect(r.state.detail!.counts.hereNow, 2);
    await tester.pump(const Duration(seconds: 31));
    expect(r.api.count('room'), before + 1);
  });

  group('gestures show once', () {
    testWidgets('sent to you: the anonymous room copy and the named member '
        'copy become one named moment', (tester) async {
      final r = await _open(tester);
      r.channels.room.emit('gesture_sent', _gesture('g1'));
      r.channels.member.emit('gesture_received', _received('g1'));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(r.moments, hasLength(1));
      expect(r.moments.single.kind, GestureMomentKind.received);
      expect(r.moments.single.pseudonym, 'Quiet Comet');
      final g = r.state.detail!.gestures;
      expect(g.received.map((x) => x.gestureId), ['g1']);
      expect(g.recent.map((x) => x.gestureId), isNot(contains('g1')));
    });

    testWidgets('the named copy first, then the room copy: still once', (
      tester,
    ) async {
      final r = await _open(tester);
      r.channels.member.emit('gesture_received', _received('g2'));
      await _settle(tester);
      r.channels.room.emit('gesture_sent', _gesture('g2'));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(r.moments.map((m) => m.kind), [GestureMomentKind.received]);
    });

    testWidgets('someone else\'s gesture plays unnamed after a short wait', (
      tester,
    ) async {
      final r = await _open(tester);
      r.channels.room.emit('gesture_sent', _gesture('g3', target: 'room'));
      await _settle(tester);
      expect(r.moments, isEmpty, reason: 'waits for a possible named copy');
      await tester.pump(const Duration(milliseconds: 800));
      expect(r.moments.single.kind, GestureMomentKind.room);
      expect(r.moments.single.pseudonym, isNull);
      expect(r.state.detail!.gestures.recent.first.gestureId, 'g3');
    });

    testWidgets('your own gesture plays at once and never again from the '
        'room feed', (tester) async {
      final r = await _open(tester);
      final comet = r.state.detail!.members.firstWhere(
        (m) => m.pseudonym == 'Quiet Comet',
      );
      r.room.sendGesture(GestureType.warmTea, to: comet);
      expect(r.moments.single.kind, GestureMomentKind.sent);
      expect(r.moments.single.pseudonym, 'Quiet Comet');
      await _settle(tester);
      expect(r.api.gestures.single, (type: GestureType.warmTea, to: cometId));
      final id = r.state.detail!.gestures.sent.first.gestureId;
      r.channels.room.emit('gesture_sent', _gesture(id));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(r.moments, hasLength(1));
      await tester.pump(const Duration(seconds: 2)); // spacing
    });

    testWidgets('your own gesture\'s room copy arriving before a slow reply '
        'is still never replayed', (tester) async {
      final r = await _open(tester);
      r.api.hold = Completer<void>();
      r.room.sendGesture(GestureType.meToo);
      await _settle(tester);
      // The fake server's first id; its broadcast beats the HTTP reply.
      r.channels.room.emit(
        'gesture_sent',
        _gesture('bbbbbbbb-0000-4000-8000-000000000001', target: 'room'),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(r.moments.map((m) => m.kind), [GestureMomentKind.sent]);
      r.api.hold!.complete();
      r.api.hold = null;
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(r.moments.map((m) => m.kind), [GestureMomentKind.sent]);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a muted member\'s gestures never show', (tester) async {
      final r = await _open(tester);
      final comet = r.state.detail!.members.firstWhere(
        (m) => m.memberId == cometId,
      );
      expect(await r.room.setMuted(comet, muted: true), isTrue);
      expect(r.api.mutes.single, (member: cometId, muted: true));
      r.channels.member.emit('gesture_received', _received('g4'));
      await _settle(tester);
      expect(r.moments, isEmpty);
    });
  });

  testWidgets('the tray rests 2 s after a send', (tester) async {
    final r = await _open(tester);
    expect(r.state.canSend, isTrue);
    r.room.sendGesture(GestureType.meToo);
    expect(r.state.canSend, isFalse);
    r.room.sendGesture(GestureType.hug); // ignored while resting
    await _settle(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(r.state.canSend, isTrue);
    expect(r.api.gestures.map((g) => g.type), [GestureType.meToo]);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('connection dropped: "Reconnecting…", both topics joined again '
      'with backoff, and the room refetched', (tester) async {
    final r = await _open(tester);
    final first = [...r.channels.opened];
    final loads = r.api.count('room');
    r.channels.room.status(RoomChannelStatus.error);
    await _settle(tester);
    expect(r.state.link, RoomLink.reconnecting);
    // First retry within 1–1.2 s (jitter).
    await tester.pump(const Duration(milliseconds: 1300));
    await _settle(tester);
    expect(first.every((c) => c.closed), isTrue);
    expect(r.channels.live, 2);
    expect(r.state.link, RoomLink.live);
    expect(r.api.count('room'), loads + 1);
  });

  testWidgets('refused joins keep backing off (1, 2, 4 s …) and show '
      '"Reconnecting…" meanwhile', (tester) async {
    final r = await _open(tester, autoJoin: false);
    r.channels.latest('room:$roomId').status(RoomChannelStatus.error);
    await _settle(tester);
    expect(r.state.link, RoomLink.reconnecting);
    await tester.pump(const Duration(milliseconds: 1300));
    await _settle(tester);
    expect(r.channels.opened, hasLength(4));
    r.channels.latest('room:$roomId').status(RoomChannelStatus.timedOut);
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(r.channels.opened, hasLength(4), reason: 'the 2nd wait is ≥ 2 s');
    await tester.pump(const Duration(milliseconds: 1000));
    await _settle(tester);
    expect(r.channels.opened, hasLength(6));
    expect(r.state.link, RoomLink.reconnecting);
  });

  testWidgets('offline, a gesture waits (≤ 30 s) and goes when the '
      'connection is back; a stale one is dropped quietly', (tester) async {
    final r = await _open(tester);
    r.net.add(false);
    await _settle(tester);
    expect(r.state.link, RoomLink.reconnecting);

    r.room.sendGesture(GestureType.hug);
    await _settle(tester);
    expect(r.state.pending, hasLength(1));
    expect(r.api.gestures, isEmpty, reason: 'no call while offline');

    await tester.pump(const Duration(seconds: 10));
    r.net.add(true);
    await _settle(tester);
    expect(r.api.gestures.map((g) => g.type), [GestureType.hug]);
    expect(r.state.pending, isEmpty);

    await tester.pump(const Duration(seconds: 3));
    r.net.add(false);
    await _settle(tester);
    r.room.sendGesture(GestureType.deepBreath);
    await _settle(tester);
    expect(r.state.pending, hasLength(1));
    await tester.pump(const Duration(seconds: 31));
    expect(r.state.pending, isEmpty, reason: 'stale: dropped quietly');
    r.net.add(true);
    await _settle(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(r.api.gestures.map((g) => g.type), [GestureType.hug]);
  });

  testWidgets('a server hiccup keeps the gesture queued and retries it once, '
      'after 3 s (never two sends within 2 s)', (tester) async {
    final r = await _open(tester);
    r.api.fail['gesture'] = const ApiException(code: 'http_503', status: 503);
    r.room.sendGesture(GestureType.stargaze);
    await _settle(tester);
    expect(r.api.count('gesture'), 1);
    expect(r.state.pending, hasLength(1));
    await tester.pump(const Duration(milliseconds: 2500));
    expect(r.api.count('gesture'), 1);
    await tester.pump(const Duration(milliseconds: 600));
    await _settle(tester);
    expect(r.api.count('gesture'), 2);
    expect(r.state.pending, isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('heartbeat every 45 s in the foreground, none in the '
      'background, one at once on resume', (tester) async {
    final r = await _open(tester);
    await tester.pump(const Duration(seconds: 45));
    await _settle(tester);
    expect(r.api.count('heartbeat'), 1);
    await tester.pump(const Duration(seconds: 45));
    await _settle(tester);
    expect(r.api.count('heartbeat'), 2);

    _lifecycle(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await tester.pump(const Duration(seconds: 120));
    expect(r.api.count('heartbeat'), 2);

    _lifecycle(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await _settle(tester);
    expect(r.api.count('heartbeat'), 3);
    await tester.pump(const Duration(seconds: 45));
    await _settle(tester);
    expect(r.api.count('heartbeat'), 4);
  });

  testWidgets('Lantern Hour ends here at endsAt even when the end event is '
      'late', (tester) async {
    final r = await _open(
      tester,
      api: FakeRoomsApi(
        detail: detailJson(
          state: 'lantern_hour',
          lantern: true,
          lanternEnds: serverNow.add(const Duration(seconds: 30)),
        ),
      ),
    );
    expect(r.state.lanternActive, isTrue);
    await tester.pump(const Duration(seconds: 31));
    expect(r.state.lanternActive, isFalse);
    expect(r.state.detail!.room.phase, RoomPhase.open);
  });

  testWidgets('lantern_hour events start it; room_state → memory makes the '
      'room read-only and stops everything live', (tester) async {
    final r = await _open(tester);
    r.channels.room.emit('lantern_hour', {
      'lanternHour': lanternJson(active: true),
      'at': serverNow.toIso8601String(),
    });
    await _settle(tester);
    expect(r.state.lanternActive, isTrue);

    r.api.detail = detailJson(state: 'memory');
    r.channels.room.emit('room_state', {
      'state': 'memory',
      'readOnly': true,
      'at': serverNow.toIso8601String(),
    });
    await _settle(tester);
    expect(r.state.isMemory, isTrue);
    expect(r.state.canSend, isFalse);
    expect(r.state.lanternActive, isFalse);
    expect(r.channels.live, 0);
    expect(r.state.link, RoomLink.off);
    final beats = r.api.count('heartbeat');
    await tester.pump(const Duration(minutes: 3));
    expect(r.api.count('heartbeat'), beats);
  });

  testWidgets('leaving unsubscribes both topics and stops the heartbeat', (
    tester,
  ) async {
    final r = await _open(tester);
    expect(await r.room.leave(), isTrue);
    expect(r.state.left, isTrue);
    expect(r.channels.live, 0);
    expect(r.state.link, RoomLink.off);
    await tester.pump(const Duration(minutes: 2));
    expect(r.api.count('heartbeat'), 0);
    expect(r.api.count('leave'), 1);
  });

  testWidgets('block: the person disappears from your room', (tester) async {
    final r = await _open(tester);
    final river = r.state.detail!.members.firstWhere(
      (m) => m.memberId == riverId,
    );
    r.api.detail = detailJson(
      members: [
        memberJson(meId, 'Soft Harbor', isMe: true),
        memberJson(cometId, 'Quiet Comet', mood: 'drained'),
      ],
    );
    expect(await r.room.block(river), isTrue);
    expect(r.api.blocks, [riverId]);
    expect(
      r.state.detail!.members.map((m) => m.memberId),
      isNot(contains(riverId)),
    );
  });

  testWidgets('a room that is gone (404) ends quietly: no realtime, no '
      'heartbeat', (tester) async {
    final r = await _open(tester);
    r.api.fail['room'] = const ApiException(code: 'not_found', status: 404);
    r.channels.room.emit('room_state', {
      'state': 'memory',
      'readOnly': true,
      'at': serverNow.toIso8601String(),
    });
    await _settle(tester);
    expect(r.state.failure?.isTerminal, isTrue);
    expect(r.channels.live, 0);
  });
}
