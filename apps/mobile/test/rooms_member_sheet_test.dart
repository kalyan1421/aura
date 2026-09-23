import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/features/rooms/room_models.dart';
import 'package:aura/src/features/rooms/room_screen.dart';
import 'package:aura/src/features/safety/safety_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rooms_fakes.dart';

/// F9 in a room: Report / Block / Mute are the second tap from a
/// silhouette (REQ-ROOM-08), the report flow (9 reasons, optional note,
/// on-device contact check), the crisis lane opening help, and reports from
/// the room menu and a received gesture.

const _room = RoomScreen(roomId: roomId);

Future<void> _openComet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('member-$cometId')));
  await settleSheet(tester);
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('two taps from a silhouette (REQ-ROOM-08)', () {
    testWidgets('tap Quiet Comet (1), then Report (2): the report sheet', (
      tester,
    ) async {
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(),
        channels: FakeChannels(),
      );
      await _openComet(tester);
      expect(find.byKey(const ValueKey('member-sheet')), findsOneWidget);
      expect(find.text('Quiet Comet'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('member-report')));
      await settleSheet(tester);
      expect(find.byKey(const ValueKey('report-sheet')), findsOneWidget);
      expect(find.text('Report Quiet Comet'), findsOneWidget);
      await _end(tester);
    });

    testWidgets('then Block (2): a calm confirm; Cancel changes nothing, '
        'Block blocks, and they disappear from the room', (tester) async {
      final api = FakeRoomsApi();
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      await _openComet(tester);
      await tester.tap(find.byKey(const ValueKey('member-block')));
      await settleSheet(tester);
      expect(find.text('Block Quiet Comet?'), findsOneWidget);
      expect(
        find.text(
          "You won't be placed in a room together again, and gestures "
          "between you stop. They won't be told.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('block-cancel')));
      await settleSheet(tester);
      expect(api.blocks, isEmpty);

      await _openComet(tester);
      await tester.tap(find.byKey(const ValueKey('member-block')));
      await settleSheet(tester);
      api.detail = detailJson(
        members: [
          memberJson(meId, 'Soft Harbor', isMe: true),
          memberJson(riverId, 'Silver River', mood: 'numb'),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('block-confirm-button')));
      await settleSheet(tester);
      await settleRooms(tester);
      expect(api.blocks, [cometId]);
      expect(
        find.text("Quiet Comet is blocked. You won't share a room again."),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('member-$cometId')), findsNothing);
      await _end(tester);
    });

    testWidgets('then Mute (2): muted at once, with Undo', (tester) async {
      final api = FakeRoomsApi();
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      await _openComet(tester);
      await tester.tap(find.byKey(const ValueKey('member-mute')));
      await settleSheet(tester);
      await settleRooms(tester);
      expect(api.mutes, [(member: cometId, muted: true)]);
      expect(
        find.text(
          "Quiet Comet is muted for you. Their gestures won't reach you here.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('room-notice-undo')));
      await settleRooms(tester);
      expect(api.mutes.last, (member: cometId, muted: false));
      await _end(tester);
    });

    testWidgets('the sheet\'s controls are all 48 dp and labelled', (
      tester,
    ) async {
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(),
        channels: FakeChannels(),
      );
      await _openComet(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await _end(tester);
    });
  });

  group('the report flow', () {
    Future<void> reportComet(
      WidgetTester tester,
      ReportReason reason, {
      String? note,
    }) async {
      await _openComet(tester);
      await tester.tap(find.byKey(const ValueKey('member-report')));
      await settleSheet(tester);
      expect(find.text("What's happening?"), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('report-reason-${reason.wire}')));
      await tester.pump();
      if (note != null) {
        await tester.enterText(find.byKey(const ValueKey('report-note')), note);
        await tester.pump();
      }
      await tester.ensureVisible(find.byKey(const ValueKey('report-send')));
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await settleSheet(tester);
      await settleRooms(tester);
    }

    testWidgets('9 reasons; nothing can be sent before one is picked', (
      tester,
    ) async {
      await pumpRooms(
        tester,
        _room,
        api: FakeRoomsApi(),
        channels: FakeChannels(),
      );
      await _openComet(tester);
      await tester.tap(find.byKey(const ValueKey('member-report')));
      await settleSheet(tester);
      expect(ReportReason.values, hasLength(9));
      for (final r in ReportReason.values) {
        expect(find.byKey(ValueKey('report-reason-${r.wire}')), findsOneWidget);
      }
      final send = tester.widget<FilledButton>(
        find.byKey(const ValueKey('report-send')),
      );
      expect(send.onPressed, isNull);
      await _end(tester);
    });

    testWidgets('reason 9 reads plainly, sits after "may be under 13" and '
        'before "Something else", and goes out as code 9', (tester) async {
      final api = FakeRoomsApi();
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      await _openComet(tester);
      await tester.tap(find.byKey(const ValueKey('member-report')));
      await settleSheet(tester);
      expect(ReportReason.values.map((r) => r.wire), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        9,
        8,
      ], reason: 'codes are stable; "Something else" stays last');
      double top(int wire) =>
          tester.getTopLeft(find.byKey(ValueKey('report-reason-$wire'))).dy;
      expect(top(7), lessThan(top(9)));
      expect(top(9), lessThan(top(8)));
      expect(find.text('Seems to be targeting a young person'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report-reason-9')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('report-send')));
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await settleSheet(tester);
      await settleRooms(tester);
      final report = api.reports.single;
      expect(report.reason, ReportReason.targetingYoungPerson);
      expect(report.reason.wire, 9);
      expect(report.target.toJson(), {
        'kind': 'member',
        'roomId': roomId,
        'memberId': cometId,
      });
      // The same calm thanks as any report: nobody's age, no lane.
      expect(
        find.text(
          "Thank you for telling us. You won't get their gestures in this "
          'room while a moderator takes a look.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SafetyCenterScreen), findsNothing);
      await _end(tester);
    });

    testWidgets('reason 9 in Tenglish and Telugu', (tester) async {
      for (final (tag, label) in [
        ('te-Latn', 'Chinna vayasu vaallani target chestunnattu anipistondi'),
        ('te', 'చిన్న వయసు వారిని లక్ష్యంగా చేసుకుంటున్నట్టు అనిపిస్తోంది'),
      ]) {
        await pumpRooms(
          tester,
          _room,
          api: FakeRoomsApi(),
          channels: FakeChannels(),
          tag: tag,
        );
        await _openComet(tester);
        await tester.tap(find.byKey(const ValueKey('member-report')));
        await settleSheet(tester);
        expect(find.text(label), findsOneWidget, reason: tag);
        await _end(tester);
      }
    });

    testWidgets('harassment with a note: sent, the member is muted for you '
        'and a calm thanks shows', (tester) async {
      final api = FakeRoomsApi();
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      await reportComet(
        tester,
        ReportReason.harassment,
        note: 'kept sending the same gesture',
      );
      final report = api.reports.single;
      expect(report.reason, ReportReason.harassment);
      expect(report.note, 'kept sending the same gesture');
      expect(report.target.toJson(), {
        'kind': 'member',
        'roomId': roomId,
        'memberId': cometId,
      });
      expect(
        find.text(
          "Thank you for telling us. You won't get their gestures in this "
          'room while a moderator takes a look.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SafetyCenterScreen), findsNothing);
      await _end(tester);
    });

    testWidgets('reason 1 (crisis lane): help opens at once, then a warm line '
        'in the room', (tester) async {
      final api = FakeRoomsApi();
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      await reportComet(tester, ReportReason.inDanger);
      expect(api.reports.single.reason, ReportReason.inDanger);
      expect(find.byType(SafetyCenterScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('safety-close')));
      await settleSheet(tester);
      expect(
        find.text(
          'Thank you for telling us. A moderator will look soon, and help is '
          'always one tap away.',
        ),
        findsOneWidget,
      );
      await _end(tester);
    });

    testWidgets('crisis words in the reporter\'s own note open help too', (
      tester,
    ) async {
      final api = FakeRoomsApi();
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      await reportComet(
        tester,
        ReportReason.harassment,
        note: 'this makes me want to die',
      );
      expect(api.reports, hasLength(1));
      expect(find.byType(SafetyCenterScreen), findsOneWidget);
      await _end(tester);
    });

    testWidgets('a note with contact details stays on the phone: nothing is '
        'sent, the words stay to edit', (tester) async {
      final api = FakeRoomsApi();
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      await reportComet(
        tester,
        ReportReason.contactInfo,
        note: 'he wrote 98765 43210',
      );
      expect(api.reports, isEmpty);
      expect(
        find.text(
          "Phone numbers, links and handles can't be shared here. It keeps "
          'everyone safer.',
        ),
        findsOneWidget,
      );
      expect(find.text('he wrote 98765 43210'), findsOneWidget);
      await _end(tester);
    });

    testWidgets('over the daily limit: calm words, help still pointed to', (
      tester,
    ) async {
      final api = FakeRoomsApi()
        ..fail['report'] = const ApiException(
          code: 'report_limit',
          status: 429,
        );
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      await reportComet(tester, ReportReason.spam);
      expect(
        find.text(
          "That's a lot of reports today. If someone is in danger, the help "
          'button is always here.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('report-sheet')), findsOneWidget);
      await _end(tester);
    });

    testWidgets('"Report a problem here" from the room menu reports the room', (
      tester,
    ) async {
      final api = FakeRoomsApi();
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      await tester.tap(find.byKey(const ValueKey('room-menu-button')));
      await settleSheet(tester);
      await tester.tap(find.byKey(const ValueKey('room-menu-report')));
      await settleSheet(tester);
      expect(find.text('Report a problem here'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report-reason-8')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('report-send')));
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await settleSheet(tester);
      expect(api.reports.single.target.toJson(), {
        'kind': 'room',
        'roomId': roomId,
      });
      await _end(tester);
    });

    testWidgets('a received gesture can be reported (and hides for you)', (
      tester,
    ) async {
      final api = FakeRoomsApi(
        detail: detailJson(
          received: [
            {
              'gestureId': 'g-hug',
              'type': 'hug',
              'fromMemberId': cometId,
              'fromPseudonym': 'Quiet Comet',
              'at': serverNow.toIso8601String(),
            },
          ],
        ),
      );
      await pumpRooms(tester, _room, api: api, channels: FakeChannels());
      expect(find.text('Quiet Comet sent you Hug'), findsOneWidget);
      final flag = find.byKey(const ValueKey('report-gesture-g-hug'));
      await tester.ensureVisible(flag);
      await tester.tap(flag);
      await settleSheet(tester);
      expect(find.text('Report this gesture'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report-reason-6')));
      await tester.pump();
      api.detail = detailJson();
      await tester.ensureVisible(find.byKey(const ValueKey('report-send')));
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await settleSheet(tester);
      await settleRooms(tester);
      expect(api.reports.single.target.toJson(), {
        'kind': 'gesture',
        'roomId': roomId,
        'gestureId': 'g-hug',
      });
      expect(find.text('Quiet Comet sent you Hug'), findsNothing);
      await _end(tester);
    });
  });
}
