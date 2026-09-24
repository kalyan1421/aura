import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/features/rooms/room_controller.dart';
import 'package:aura/src/features/rooms/room_models.dart';
import 'package:aura/src/features/rooms/room_realtime.dart';
import 'package:aura/src/features/rooms/room_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rooms_fakes.dart';

/// Room lanterns and Tonight's intention (F5, Milestone B; contracts
/// §1.9): the lantern card at each moment (invitation, glowing, full,
/// "Tonight's lantern" afterwards and in the memory, never failure copy),
/// the one-tap hold and its room total, live `room_state` totals that never
/// dim, the fully-lit moment (animated, and still under Reduce Motion), and
/// no per-member data anywhere.

const _room = RoomScreen(roomId: roomId);

Map<String, dynamic> _lantern({int level = 2, bool active = true}) => {
  'level': level,
  'maxLevel': 5,
  'active': active,
};

Map<String, dynamic> _intention({int holds = 12, bool open = true}) => {
  'key': 'gentle_with_myself',
  'holds': holds,
  'open': open,
};

/// A room in Lantern Hour with a lantern at [level] and tonight's intention.
Map<String, dynamic> _lit({
  int level = 2,
  int holds = 12,
  bool holding = false,
  String state = 'lantern_hour',
  bool active = true,
  bool withIntention = true,
}) {
  final d = detailJson(state: state, lantern: state == 'lantern_hour');
  final room = d['room'] as Map<String, dynamic>;
  room['lantern'] = _lantern(level: level, active: active);
  room['intention'] = withIntention
      ? _intention(holds: holds, open: active)
      : null;
  (d['me'] as Map<String, dynamic>)['holdingIntention'] = holding;
  return d;
}

Map<String, dynamic> _roomState({
  required int level,
  int holds = 12,
  String state = 'lantern_hour',
}) => {
  'state': state,
  'readOnly': state == 'memory',
  'joinsCloseAt': serverNow.add(const Duration(hours: 18)).toIso8601String(),
  'memoryAt': serverNow.add(const Duration(hours: 22)).toIso8601String(),
  'purgeAt': serverNow.add(const Duration(days: 7)).toIso8601String(),
  'lantern': _lantern(level: level),
  'intention': _intention(holds: holds),
  'at': serverNow.toIso8601String(),
};

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('models and merging (never dims)', () {
    test('room_state carries the room totals; an older payload does not', () {
      final e = parseRoomEvent('room_state', _roomState(level: 3, holds: 4));
      expect(e, isA<RoomStateEvent>());
      final st = e! as RoomStateEvent;
      expect(st.carriesTotals, isTrue);
      expect(st.lantern, const RoomLantern(level: 3, active: true));
      expect(
        st.intention,
        const RoomIntention(key: 'gentle_with_myself', holds: 4, open: true),
      );
      final old =
          parseRoomEvent('room_state', {'state': 'open', 'readOnly': false})!
              as RoomStateEvent;
      expect(old.carriesTotals, isFalse);
      expect(old.lantern, isNull);
    });

    test('a later, lower view never dims the lantern or lowers the holds', () {
      const shown = RoomLantern(level: 4, active: true);
      expect(
        brighterLantern(shown, const RoomLantern(level: 2, active: false)),
        const RoomLantern(level: 4, active: false),
      );
      expect(
        brighterLantern(shown, const RoomLantern(level: 5, active: true)),
        const RoomLantern(level: 5, active: true),
      );
      expect(brighterLantern(shown, null), isNull, reason: 'kill switch');
      const held = RoomIntention(key: 'a', holds: 9, open: true);
      expect(
        higherIntention(held, const RoomIntention(key: 'a', holds: 3))!.holds,
        9,
      );
      final before = RoomDetail.fromJson(_lit(level: 4, holding: true));
      final after = keepRoomTotals(
        RoomDetail.fromJson(_lit(level: 1, holds: 2)),
        before,
      );
      expect(after.room.lantern!.level, 4);
      expect(after.room.intention!.holds, 12);
      expect(after.me.holdingIntention, isTrue);
    });

    test(
      'the fully-lit moment is for a rise seen live, not a room already lit',
      () {
        final four = RoomDetail.fromJson(_lit(level: 4));
        final five = RoomDetail.fromJson(_lit(level: 5));
        expect(lanternJustFilled(four, five), isTrue);
        expect(lanternJustFilled(null, five), isFalse);
        expect(lanternJustFilled(five, five), isFalse);
      },
    );

    test('no member id or per-member value in the parsed totals', () {
      final payload = {
        ..._roomState(level: 2),
        'memberId': cometId,
        'holders': [meId],
      };
      final st = parseRoomEvent('room_state', payload)! as RoomStateEvent;
      final shown = '${st.lantern} ${st.intention}';
      expect(shown, isNot(contains(cometId)));
      expect(shown, isNot(contains(meId)));
    });
  });

  group('room screen', () {
    testWidgets('before the first Lantern Hour: no lantern and no intention', (
      tester,
    ) async {
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(),
        channels: FakeChannels(),
      );
      expect(find.byKey(const ValueKey('room-lantern-card')), findsNothing);
      expect(find.byKey(const ValueKey('room-intention-card')), findsNothing);
      await _close(tester);
    });

    testWidgets('in Lantern Hour: the lantern (read as a room total) and '
        "tonight's intention with the room's count", (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(detail: _lit()),
        channels: FakeChannels(),
      );
      expect(find.text("Tonight's lantern"), findsOneWidget);
      expect(
        find.text('It glows brighter with every gesture here.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r"^Tonight's lantern, 2 of 5 lights lit")),
        findsOneWidget,
      );
      expect(find.text("Tonight's intention"), findsOneWidget);
      expect(find.text('Be gentle with myself tonight'), findsOneWidget);
      expect(find.text('12 holding this tonight'), findsOneWidget);
      expect(
        find.text(
          'Nobody sees who holds it, and nobody will ask about it tomorrow.',
        ),
        findsOneWidget,
      );
      final hold = tester.getSize(
        find.byKey(const ValueKey('room-intention-hold')),
      );
      expect(hold.height, greaterThanOrEqualTo(48));
      semantics.dispose();
      await _close(tester);
    });

    testWidgets('level 0 invites; a full lantern says "together"', (
      tester,
    ) async {
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(detail: _lit(level: 0)),
        channels: FakeChannels(),
      );
      expect(
        find.text('Every gesture here adds a little light.'),
        findsOneWidget,
      );
      await _close(tester);
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(detail: _lit(level: 5)),
        channels: FakeChannels(),
      );
      expect(find.text('Fully lit, together.'), findsOneWidget);
      // Opening a room that is already lit doesn't replay the moment.
      expect(find.byKey(const ValueKey('room-lantern-rise')), findsNothing);
      await _close(tester);
    });

    testWidgets('one tap holds it: "You\'re holding this tonight" and the '
        'new room total; it cannot be tapped again', (tester) async {
      final api = FakeRoomsApi(detail: _lit())..intentionHolds = 12;
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      await tester.tap(find.byKey(const ValueKey('room-intention-hold')));
      await settleRooms(tester);
      expect(api.count('holdIntention'), 1);
      expect(find.text("You're holding this tonight"), findsOneWidget);
      expect(find.text('13 holding this tonight'), findsOneWidget);
      expect(find.byKey(const ValueKey('room-intention-hold')), findsNothing);
      await _close(tester);
    });

    testWidgets('a hold that fails (the hour ended) changes nothing and says '
        'so calmly', (tester) async {
      final api = FakeRoomsApi(detail: _lit());
      api.fail['holdIntention'] = const ApiException(
        code: 'intention_closed',
        status: 409,
      );
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      await tester.tap(find.byKey(const ValueKey('room-intention-hold')));
      await settleRooms(tester);
      expect(
        find.byKey(const ValueKey('room-intention-holding')),
        findsNothing,
      );
      expect(
        find.text("That didn't go through. Please try again."),
        findsOneWidget,
      );
      await _close(tester);
    });

    testWidgets('live totals: a rising level and hold count apply without a '
        'refetch, a stale lower one never dims it, and the fully lit moment '
        'plays once with words', (tester) async {
      final said = captureAnnouncements(tester);
      final channels = FakeChannels();
      final api = FakeRoomsApi(detail: _lit(level: 3));
      await pumpRooms(tester, _room, api: api, channels: channels);
      final fetches = api.count('room');

      channels.room.emit('room_state', _roomState(level: 4, holds: 14));
      await settleRooms(tester);
      expect(
        find.bySemanticsLabel(RegExp(r"^Tonight's lantern, 4 of 5")),
        findsOneWidget,
      );
      expect(find.text('14 holding this tonight'), findsOneWidget);
      expect(api.count('room'), fetches, reason: 'totals only: no refetch');

      channels.room.emit('room_state', _roomState(level: 2, holds: 3));
      await settleRooms(tester);
      expect(
        find.bySemanticsLabel(RegExp(r"^Tonight's lantern, 4 of 5")),
        findsOneWidget,
        reason: 'never dims',
      );
      expect(find.text('14 holding this tonight'), findsOneWidget);

      channels.room.emit('room_state', _roomState(level: 5, holds: 14));
      await settleRooms(tester);
      expect(find.byKey(const ValueKey('room-lantern-rise')), findsOneWidget);
      expect(
        said,
        contains('The lantern is fully lit. Lanterns rise, together.'),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const ValueKey('room-lantern-rise')), findsNothing);
      await _close(tester);
    });

    testWidgets('Reduce Motion: the fully lit moment is a still image with a '
        'line of text', (tester) async {
      final channels = FakeChannels();
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(detail: _lit(level: 4)),
        channels: channels,
        reduceMotion: true,
      );
      channels.room.emit('room_state', _roomState(level: 5));
      await settleRooms(tester);
      expect(
        find.byKey(const ValueKey('room-lantern-rise-still')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('room-lantern-rise')), findsNothing);
      expect(
        find.byKey(const ValueKey('room-lantern-rise-line')),
        findsOneWidget,
      );
      await _close(tester);
    });

    testWidgets('after 23:00: "Tonight\'s lantern glowed this bright." and a '
        'read-only total — no failure copy', (tester) async {
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(detail: _lit(level: 2, state: 'open', active: false)),
        channels: FakeChannels(),
      );
      expect(
        find.text("Tonight's lantern glowed this bright."),
        findsOneWidget,
      );
      expect(find.text('12 held this tonight'), findsOneWidget);
      expect(find.byKey(const ValueKey('room-intention-hold')), findsNothing);
      expect(
        find.textContaining(RegExp('fail|miss|almost', caseSensitive: false)),
        findsNothing,
      );
      await _close(tester);
    });

    testWidgets('the memory keeps "Tonight\'s lantern" at the level reached', (
      tester,
    ) async {
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(
          detail: _lit(level: 3, state: 'memory', active: false),
        ),
        channels: FakeChannels(),
      );
      expect(find.byKey(const ValueKey('room-memory')), findsOneWidget);
      expect(
        find.text("Tonight's lantern glowed this bright."),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r"^Tonight's lantern, 3 of 5")),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('room-intention-card')), findsNothing);
      await _close(tester);
    });

    testWidgets('Telugu and Tenglish', (tester) async {
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(detail: _lit()),
        channels: FakeChannels(),
        tag: 'te',
      );
      expect(find.text('ఈ రాత్రి లాంతరు'), findsOneWidget);
      expect(find.text('ఈ రాత్రి నా పట్ల మృదువుగా ఉంటాను'), findsOneWidget);
      await _close(tester);
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(detail: _lit()),
        channels: FakeChannels(),
        tag: 'te-Latn',
      );
      expect(find.text('Ee raatri lantern'), findsOneWidget);
      expect(find.text('Ee raatri 12 mandi idi pattukunnaru'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('an intention key this build does not know hides the card', (
      tester,
    ) async {
      final d = _lit();
      ((d['room'] as Map<String, dynamic>)['intention']
              as Map<String, dynamic>)['key'] =
          'brand_new_preset';
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(detail: d),
        channels: FakeChannels(),
      );
      expect(find.byKey(const ValueKey('room-intention-card')), findsNothing);
      expect(find.byKey(const ValueKey('room-lantern-card')), findsOneWidget);
      await _close(tester);
    });
  });
}
