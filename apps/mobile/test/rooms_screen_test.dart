import 'dart:async';

import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/features/rooms/room_models.dart';
import 'package:aura/src/features/rooms/room_realtime.dart';
import 'package:aura/src/features/rooms/room_screen.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rooms_fakes.dart';
import 'shell_helpers.dart' show loadRealFonts;

/// The room screen (F5, PRD 14-states "Room"): loading, cold start, live,
/// reconnecting, closing, memory, gone, suspended and offline, with help in
/// every state; gestures announced (REQ-A11Y-06); 200% Telugu; DS-10.

const _room = RoomScreen(roomId: roomId);

Finder _help() => find.byType(HelpNowButton);

Future<void> _closeSheets(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('states', () {
    testWidgets('loading: a calm "Opening the room…", help already there', (
      tester,
    ) async {
      final api = FakeRoomsApi()..hold = Completer<void>();
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      expect(find.byKey(const ValueKey('room-opening')), findsOneWidget);
      expect(find.text('Opening the room…'), findsOneWidget);
      expect(_help(), findsOneWidget);
      api.hold!.complete();
      api.hold = null;
      await settleRooms(tester);
      expect(find.text("You're Soft Harbor here"), findsOneWidget);
      await _closeSheets(tester);
    });

    testWidgets('live: real counts (read as "3 people here now, 18 today"), '
        'your name here, the members and all 8 gestures', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(),
        channels: FakeChannels(),
      );
      expect(find.text('The Rain Sanctuary'), findsOneWidget);
      expect(find.text('3 here now'), findsOneWidget);
      expect(find.text('18 people have been here today'), findsOneWidget);
      expect(
        find.bySemanticsLabel('3 people here now, 18 today'),
        findsOneWidget,
      );
      expect(find.text("You're Soft Harbor here"), findsOneWidget);
      expect(find.text('Quiet Comet'), findsOneWidget);
      expect(find.text('Drained'), findsOneWidget, reason: 'mood chip');
      expect(find.text('Silver River'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Silver River, Numb, away for now'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('gesture-tray')), findsOneWidget);
      for (final g in GestureType.values) {
        final size = tester.getSize(find.byKey(ValueKey('gesture-${g.wire}')));
        expect(size.width, greaterThanOrEqualTo(48), reason: g.wire);
        expect(size.height, greaterThanOrEqualTo(48), reason: g.wire);
      }
      expect(find.byKey(const ValueKey('room-cold-start')), findsNothing);
      expect(find.byKey(const ValueKey('room-reconnecting')), findsNothing);
      expect(_help(), findsOneWidget);
      semantics.dispose();
      await _closeSheets(tester);
    });

    testWidgets('empty (cold start): honest counts and "Leave a light for '
        'the next one"', (tester) async {
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(
          detail: detailJson(alone: true, hereNow: 1, today: 12),
        ),
        channels: FakeChannels(),
      );
      expect(
        find.text(
          '12 people have been here today. Leave a light for the next one.',
        ),
        findsOneWidget,
      );
      expect(find.text('1 here now'), findsOneWidget);
      // Gestures still work: they wait for whoever comes next.
      expect(find.byKey(const ValueKey('gesture-tray')), findsOneWidget);
      await _closeSheets(tester);
    });

    testWidgets('realtime dropped: "Reconnecting…" while it rejoins', (
      tester,
    ) async {
      final channels = FakeChannels();
      await pumpRooms(tester, _room, api: FakeRoomsApi(), channels: channels);
      channels.room.status(RoomChannelStatus.error);
      await settleRooms(tester);
      expect(find.text('Reconnecting…'), findsOneWidget);
      expect(_help(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1300));
      await settleRooms(tester);
      expect(find.text('Reconnecting…'), findsNothing);
      await _closeSheets(tester);
    });

    testWidgets('closing: "This room becomes a memory at …"; gestures still '
        'work', (tester) async {
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(detail: detailJson(state: 'closing')),
        channels: FakeChannels(),
      );
      expect(
        find.textContaining('This room becomes a memory at '),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('gesture-tray')), findsOneWidget);
      await _closeSheets(tester);
    });

    testWidgets('memory: read-only (no tray), "Find a new room", and report '
        'and block still there; help too', (tester) async {
      final channels = FakeChannels();
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(detail: detailJson(state: 'memory')),
        channels: channels,
      );
      expect(
        find.text(
          'This room has become a memory. You can look back for 7 days.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('gesture-tray')), findsNothing);
      expect(find.text('Find a new room'), findsOneWidget);
      expect(_help(), findsOneWidget);
      expect(channels.opened, isEmpty, reason: 'no realtime for a memory');

      await tester.tap(find.byKey(const ValueKey('member-$cometId')));
      await settleSheet(tester);
      expect(find.byKey(const ValueKey('member-report')), findsOneWidget);
      expect(find.byKey(const ValueKey('member-block')), findsOneWidget);
      expect(find.byKey(const ValueKey('gesture-hug')), findsNothing);
      await _closeSheets(tester);
    });

    testWidgets('the room closes while you look: it dims into a memory in '
        'place', (tester) async {
      final channels = FakeChannels();
      final api = FakeRoomsApi();
      await pumpRooms(tester, _room, api: api, channels: channels);
      expect(find.byKey(const ValueKey('gesture-tray')), findsOneWidget);
      api.detail = detailJson(state: 'memory');
      channels.room.emit('room_state', {
        'state': 'memory',
        'readOnly': true,
        'at': serverNow.toIso8601String(),
      });
      await settleRooms(tester);
      expect(find.byKey(const ValueKey('gesture-tray')), findsNothing);
      expect(find.byKey(const ValueKey('room-memory')), findsOneWidget);
      await _closeSheets(tester);
    });

    testWidgets('gone (purged, or not yours): a calm line and back to your '
        'rooms; help stays', (tester) async {
      final api = FakeRoomsApi()
        ..fail['room'] = const ApiException(code: 'not_found', status: 404);
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      expect(
        find.text(
          "This room has closed. Rooms rest for 7 days as memories, then "
          "they're gone.",
        ),
        findsOneWidget,
      );
      expect(find.text('Back to your rooms'), findsOneWidget);
      expect(_help(), findsOneWidget);
      await _closeSheets(tester);
    });

    testWidgets('suspended: calm, no blame, help always here', (tester) async {
      final api = FakeRoomsApi()
        ..fail['room'] = const ApiException(
          code: 'rooms_suspended',
          status: 403,
        );
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      expect(
        find.text(
          'Rooms are paused for your account right now. Help is always here.',
        ),
        findsOneWidget,
      );
      expect(_help(), findsOneWidget);
      await _closeSheets(tester);
    });
  });

  testWidgets('offline from the start: no call, the offline words, then the '
      'room on reconnect', (tester) async {
    final net = StreamController<bool>();
    addTearDown(net.close);
    net.add(false);
    final api = FakeRoomsApi();
    await pumpRooms(
      tester,
      _room,
      api: api,
      channels: FakeChannels(),
      connectivity: net.stream,
    );
    expect(api.calls, isEmpty);
    expect(
      find.text(
        "Rooms need a connection. This room opens again when you're back "
        'online.',
      ),
      findsOneWidget,
    );
    expect(_help(), findsOneWidget);
    net.add(true);
    await settleRooms(tester);
    expect(find.text("You're Soft Harbor here"), findsOneWidget);
    await _closeSheets(tester);
  });

  group('announcements (REQ-A11Y-06)', () {
    testWidgets('sending to everyone, to one member, and receiving', (
      tester,
    ) async {
      final said = captureAnnouncements(tester);
      final channels = FakeChannels();
      final api = FakeRoomsApi();
      await pumpRooms(tester, _room, api: api, channels: channels);

      await tester.tap(find.byKey(const ValueKey('gesture-warm_tea')));
      await settleRooms(tester);
      expect(said, contains('Warm Tea sent to everyone here'));
      expect(api.gestures.single.to, isNull);
      // The tray rests 2 s and says what was sent.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('gesture-tray')),
          matching: find.text('Warm Tea sent to everyone here'),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.byKey(const ValueKey('member-$cometId')));
      await settleSheet(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('member-sheet')),
          matching: find.byKey(const ValueKey('gesture-hug')),
        ),
      );
      await settleSheet(tester);
      expect(said, contains('Hug sent to Quiet Comet'));
      expect(api.gestures.last, (type: GestureType.hug, to: cometId));

      channels.member.emit('gesture_received', {
        'gestureId': 'g-in',
        'type': 'warm_tea',
        'fromMemberId': cometId,
        'fromPseudonym': 'Quiet Comet',
        'at': serverNow.toIso8601String(),
      });
      await settleRooms(tester);
      expect(said, contains('Quiet Comet sent you Warm Tea'));
      expect(
        find.byKey(const ValueKey('room-received-banner')),
        findsOneWidget,
      );
      expect(find.text('Quiet Comet sent you Warm Tea'), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
      expect(find.byKey(const ValueKey('room-received-banner')), findsNothing);
      await _closeSheets(tester);
    });

    testWidgets('others\' gestures are unnamed; under Reduce Motion it only '
        'fades in place', (tester) async {
      final said = captureAnnouncements(tester);
      final channels = FakeChannels();
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(),
        channels: channels,
        reduceMotion: true,
      );
      channels.room.emit('gesture_sent', {
        'gestureId': 'g-other',
        'type': 'soft_rain',
        'target': 'room',
        'at': serverNow.toIso8601String(),
      });
      await tester.pump(const Duration(milliseconds: 800));
      await settleRooms(tester);
      expect(said, contains('Someone sent Soft Rain to everyone here'));
      expect(said.where((s) => s.contains('Quiet Comet')), isEmpty);
      expect(
        find.text('Someone sent Soft Rain to everyone here'),
        findsOneWidget,
        reason: 'listed under "Warmth in this room"',
      );
      await tester.pump(const Duration(seconds: 3));
      await _closeSheets(tester);
    });
  });

  testWidgets('Lantern Hour: the calm lantern line and glow', (tester) async {
    await pumpRooms(
      tester,
      _room,
      api: FakeRoomsApi(
        detail: detailJson(state: 'lantern_hour', lantern: true),
      ),
      channels: FakeChannels(),
      reduceMotion: true,
    );
    expect(find.byKey(const ValueKey('room-lantern')), findsOneWidget);
    expect(find.textContaining('Lantern Hour · until '), findsOneWidget);
    expect(find.byKey(const ValueKey('room-lantern-glow')), findsOneWidget);
    await _closeSheets(tester);
  });

  testWidgets('leave: a calm confirm, the survey (eligible), then gone', (
    tester,
  ) async {
    final api = FakeRoomsApi()..leaveSurveyEligible = true;
    final channels = FakeChannels();
    await pumpRooms(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => _room)),
          child: const Text('open'),
        ),
      ),
      api: api,
      channels: channels,
    );
    await tester.tap(find.text('open'));
    await settleSheet(tester);
    await settleRooms(tester);

    await tester.tap(find.byKey(const ValueKey('room-menu-button')));
    await settleSheet(tester);
    await tester.tap(find.byKey(const ValueKey('room-menu-leave')));
    await settleSheet(tester);
    expect(find.text('Leave this room?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('leave-confirm-button')));
    await settleSheet(tester);
    expect(api.count('leave'), 1);
    expect(channels.live, 0, reason: 'unsubscribed after leaving');
    expect(find.text('Did you feel less alone?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('survey-yes')));
    await settleSheet(tester);
    await settleRooms(tester);
    expect(api.surveys, [SurveyAnswer.yes]);
    expect(find.byType(RoomScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
    await _closeSheets(tester);
  });

  testWidgets('back asks "Did you feel less alone?" once when eligible; '
      'closing it counts as Skip', (tester) async {
    final api = FakeRoomsApi(detail: detailJson(surveyEligible: true));
    await pumpRooms(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => _room)),
          child: const Text('open'),
        ),
      ),
      api: api,
      channels: FakeChannels(),
    );
    await tester.tap(find.text('open'));
    await settleSheet(tester);
    await settleRooms(tester);
    await tester.tap(find.byType(BackButton));
    await settleSheet(tester);
    expect(find.text('Did you feel less alone?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('survey-skip')));
    await settleSheet(tester);
    await settleRooms(tester);
    expect(api.surveys, [SurveyAnswer.skip]);
    expect(find.byType(RoomScreen), findsNothing);
    await _closeSheets(tester);
  });

  testWidgets('200% text in Telugu: the room, a member sheet and the report '
      'sheet fit without overflow', (tester) async {
    await loadRealFonts();
    await pumpRooms(
      tester,
      _room,
      api: FakeRoomsApi(
        detail: detailJson(
          state: 'closing',
          received: [
            {
              'gestureId': 'g1',
              'type': 'youre_not_alone',
              'fromMemberId': cometId,
              'fromPseudonym': 'Quiet Comet',
              'at': serverNow.toIso8601String(),
            },
          ],
        ),
      ),
      channels: FakeChannels(),
      tag: 'te',
      scale: 2,
      size: const Size(360, 740),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('వాన నిలయం'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('room-list')),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    const comet = ValueKey('member-$cometId');
    await tester.ensureVisible(find.byKey(comet));
    await tester.pump();
    await tester.tap(find.byKey(comet));
    await settleSheet(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('member-report')));
    await settleSheet(tester);
    expect(find.byKey(const ValueKey('report-sheet')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _closeSheets(tester);
  });

  testWidgets('DS-10: an account id sent by mistake is never shown or read '
      'out', (tester) async {
    const leaked = {'userId': 'acct-5f3a', 'email': 'someone@example.com'};
    await pumpRooms(
      tester,
      _room,
      api: FakeRoomsApi(
        detail: detailJson(
          members: [
            {...memberJson(meId, 'Soft Harbor', isMe: true), ...leaked},
            {...memberJson(cometId, 'Quiet Comet'), ...leaked},
          ],
        ),
      ),
      channels: FakeChannels(),
    );
    final semantics = tester.ensureSemantics();
    expect(find.textContaining('acct-5f3a'), findsNothing);
    expect(find.textContaining('someone@example.com'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('acct-5f3a|someone@')), findsNothing);
    // No member id is shown either: pseudonyms only.
    expect(find.textContaining(cometId), findsNothing);
    semantics.dispose();
    await _closeSheets(tester);
  });

  testWidgets('"I need help now" is within the first three focus stops '
      '(after Back and the room name)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRooms(
      tester,
      _room,
      api: FakeRoomsApi(),
      channels: FakeChannels(),
    );
    final order = tester.semantics.simulatedAccessibilityTraversal().toList();
    final labels = [for (final n in order) n.getSemanticsData().label];
    final help = labels.indexWhere((l) => l.contains('I need help now'));
    expect(help, inInclusiveRange(0, 2), reason: labels.take(4).join(' | '));
    semantics.dispose();
    await _closeSheets(tester);
  });
}
