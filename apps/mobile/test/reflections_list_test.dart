import 'package:aura/src/features/reflections/reflections_section.dart';
import 'package:aura/src/features/rooms/room_models.dart';
import 'package:aura/src/features/rooms/room_screen.dart';
import 'package:aura/src/features/safety/safety_center_screen.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reflections_fakes.dart';
import 'rooms_fakes.dart';

/// Reflections inside a room (F6): newest first; others' published cards
/// carry the 8 gestures (sent with `target: reflection`) and a ⋯ menu with
/// Report · Block · Mute; no reply or edit anywhere (REQ-REF-05); your own
/// held / pending / rejected / removed ones show only calm words for you
/// (REQ-REF-05 "only the author sees held items"); only authors see counts;
/// memories are read-only; realtime hints refetch; a late crisis diversion
/// opens the support sheet (REQ-REF-04).

Finder _card(String id) => find.byKey(ValueKey('reflection-$id'));

Future<void> _menu(WidgetTester tester, String id) async {
  final button = find.byKey(ValueKey('reflection-menu-button-$id'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await settleSheet(tester);
}

FakeReflectionsApi _mixed() => FakeReflectionsApi(
  reflections: [
    reflectionJson(
      myReflectionId,
      memberId: meId,
      pseudonym: 'Soft Harbor',
      isMine: true,
      status: 'held',
      review: 'overnight',
      text: 'my held words',
      ago: const Duration(minutes: 1),
    ),
    reflectionJson(
      cometReflectionId,
      text: 'first Diwali alone in this city',
      ago: const Duration(minutes: 5),
    ),
    reflectionJson(
      riverReflectionId,
      memberId: riverId,
      pseudonym: 'Silver River',
      text: 'exams valla chala tired',
      ago: const Duration(minutes: 30),
    ),
  ],
);

void main() {
  testWidgets('newest first, text as written, the pseudonym on each card', (
    tester,
  ) async {
    await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: _mixed());
    final mine = tester.getTopLeft(_card(myReflectionId)).dy;
    final comet = tester.getTopLeft(_card(cometReflectionId)).dy;
    final river = tester.getTopLeft(_card(riverReflectionId)).dy;
    expect(mine, lessThan(comet));
    expect(comet, lessThan(river));
    expect(find.text('Quiet Comet'), findsOneWidget);
    expect(find.text('first Diwali alone in this city'), findsOneWidget);
    expect(find.text('exams valla chala tired'), findsOneWidget);
    await closeAll(tester);
  });

  testWidgets('your own held one: only calm words for you, no gestures, and '
      'Withdraw in its menu', (tester) async {
    final api = _mixed();
    await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: api);
    final card = _card(myReflectionId);
    expect(
      find.descendant(
        of: card,
        matching: find.text(
          'Waiting for a quick check. This may take until morning.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Only you can see this')),
      findsOneWidget,
    );
    expect(find.text('Your reflection'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reflection-gestures-$myReflectionId')),
      findsNothing,
    );
    await _menu(tester, myReflectionId);
    expect(find.byKey(const ValueKey('reflection-menu-report')), findsNothing);
    expect(find.text('Withdraw'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reflection-menu-delete')));
    await settleSheet(tester);
    await tester.tap(
      find.byKey(const ValueKey('reflection-delete-confirm-button')),
    );
    await settleSheet(tester);
    expect(api.deletes, [myReflectionId]);
    expect(_card(myReflectionId), findsNothing);
    expect(find.text('Your reflection is gone.'), findsOneWidget);
    await closeAll(tester);
  });

  testWidgets('your own pending, rejected and removed ones: calm words only', (
    tester,
  ) async {
    await pumpReflections(
      tester,
      rooms: FakeRoomsApi(),
      reflections: FakeReflectionsApi(
        reflections: [
          reflectionJson(
            'r-pending',
            memberId: meId,
            isMine: true,
            status: 'pending',
          ),
          reflectionJson(
            'r-rejected',
            memberId: meId,
            isMine: true,
            status: 'rejected',
            rejectReason: 'link',
          ),
          reflectionJson(
            'r-removed',
            memberId: meId,
            isMine: true,
            status: 'removed',
            rejectReason: 'hurtful',
          ),
        ],
      ),
    );
    expect(find.text('Still checking. You can keep reading.'), findsOneWidget);
    expect(find.text("This one didn't go up here."), findsOneWidget);
    expect(
      find.text("Reflections can't include links. Want to try without it?"),
      findsOneWidget,
    );
    expect(
      find.text('This one was taken down after a review.'),
      findsOneWidget,
    );
    expect(find.text('Only you can see this'), findsNWidgets(3));
    await closeAll(tester);
  });

  testWidgets("someone's published one: the 8 gestures and the ⋯ menu with "
      'Report, Block and Mute; no reply or edit anywhere', (tester) async {
    await pumpReflections(tester, rooms: FakeRoomsApi(), reflections: _mixed());
    for (final g in GestureType.values) {
      final chip = find.byKey(
        ValueKey('reflection-gesture-$cometReflectionId-${g.wire}'),
      );
      expect(chip, findsOneWidget, reason: g.wire);
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    }
    // Gesture-only: no text field, no reply or edit words.
    final section = find.byType(ReflectionsSection);
    expect(
      find.descendant(of: section, matching: find.byType(TextField)),
      findsNothing,
    );
    for (final word in ['Reply', 'reply', 'Edit', 'Comment']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
    await _menu(tester, cometReflectionId);
    expect(
      find.byKey(const ValueKey('reflection-menu-report')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('reflection-menu-block')), findsOneWidget);
    expect(find.byKey(const ValueKey('reflection-menu-mute')), findsOneWidget);
    expect(find.byKey(const ValueKey('reflection-menu-delete')), findsNothing);
    await closeAll(tester);
  });

  testWidgets('a gesture goes to the reflection (target reflection), never '
      'through the room tray; the words say who it went to', (tester) async {
    final rooms = FakeRoomsApi();
    final api = _mixed();
    await pumpReflections(tester, rooms: rooms, reflections: api);
    final hug = find.byKey(
      const ValueKey('reflection-gesture-$cometReflectionId-hug'),
    );
    await tester.ensureVisible(hug);
    await tester.tap(hug);
    await settleRooms(tester);
    expect(api.gestures.single.type, GestureType.hug);
    expect(api.gestures.single.reflectionId, cometReflectionId);
    expect(rooms.gestures, isEmpty);
    expect(find.text('Hug sent to Quiet Comet'), findsOneWidget);
    // Resting for 2 s: a second tap sends nothing.
    await tester.tap(hug);
    await settleRooms(tester);
    expect(api.gestures, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
    await closeAll(tester);
  });

  testWidgets('your own published one: its gesture count, which only you '
      'see; no gestures of your own on it', (tester) async {
    await pumpReflections(
      tester,
      rooms: FakeRoomsApi(),
      reflections: FakeReflectionsApi(
        reflections: [
          reflectionJson(
            myReflectionId,
            memberId: meId,
            pseudonym: 'Soft Harbor',
            isMine: true,
            gestureCount: 2,
          ),
        ],
      ),
    );
    expect(find.text('2 gestures'), findsOneWidget);
    expect(find.text('Only you see this count'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reflection-gestures-$myReflectionId')),
      findsNothing,
    );
    await _menu(tester, myReflectionId);
    expect(find.text('Delete'), findsOneWidget);
    await closeAll(tester);
  });

  group('safety', () {
    testWidgets('Report: the report sheet for a reflection target; it hides '
        'for you at once', (tester) async {
      final rooms = FakeRoomsApi();
      await pumpReflections(tester, rooms: rooms, reflections: _mixed());
      await _menu(tester, cometReflectionId);
      await tester.tap(find.byKey(const ValueKey('reflection-menu-report')));
      await settleSheet(tester);
      expect(find.text('Report this reflection'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report-reason-5')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('report-send')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await settleSheet(tester);
      final report = rooms.reports.single;
      expect(report.reason, ReportReason.contactInfo);
      expect(report.target.toJson(), {
        'kind': 'reflection',
        'roomId': roomId,
        'reflectionId': cometReflectionId,
      });
      expect(_card(cometReflectionId), findsNothing);
      expect(
        find.text(
          'Thank you for telling us. That reflection is hidden for you now.',
        ),
        findsOneWidget,
      );
      await closeAll(tester);
    });

    testWidgets('Report "in danger": the Safety Center opens at once', (
      tester,
    ) async {
      final rooms = FakeRoomsApi();
      await pumpReflections(tester, rooms: rooms, reflections: _mixed());
      await _menu(tester, cometReflectionId);
      await tester.tap(find.byKey(const ValueKey('reflection-menu-report')));
      await settleSheet(tester);
      await tester.tap(find.byKey(const ValueKey('report-reason-1')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('report-send')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await settleSheet(tester);
      expect(find.byType(SafetyCenterScreen), findsOneWidget);
      await closeAll(tester);
    });

    testWidgets('Block: confirmed, the account is blocked and their '
        'reflections leave your list', (tester) async {
      final rooms = FakeRoomsApi();
      await pumpReflections(tester, rooms: rooms, reflections: _mixed());
      await _menu(tester, cometReflectionId);
      await tester.tap(find.byKey(const ValueKey('reflection-menu-block')));
      await settleSheet(tester);
      expect(find.text('Block Quiet Comet?'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('reflection-block-confirm-button')),
      );
      await settleSheet(tester);
      expect(rooms.blocks, [cometId]);
      expect(_card(cometReflectionId), findsNothing);
      expect(_card(riverReflectionId), findsOneWidget);
      await closeAll(tester);
    });

    testWidgets('Mute: muted for you here; their reflections hide; Undo '
        'brings them back', (tester) async {
      final rooms = FakeRoomsApi();
      await pumpReflections(tester, rooms: rooms, reflections: _mixed());
      await _menu(tester, riverReflectionId);
      await tester.tap(find.byKey(const ValueKey('reflection-menu-mute')));
      await settleSheet(tester);
      expect(rooms.mutes.single, (member: riverId, muted: true));
      expect(_card(riverReflectionId), findsNothing);
      await tester.tap(find.byKey(const ValueKey('reflections-notice-undo')));
      await settleRooms(tester);
      expect(rooms.mutes.last, (member: riverId, muted: false));
      expect(_card(riverReflectionId), findsOneWidget);
      await closeAll(tester);
    });
  });

  testWidgets('a memory: read-only list, no composer, gestures resting', (
    tester,
  ) async {
    final api = FakeReflectionsApi(
      reflections: _mixed().reflections,
      composer: composerJson(state: 'read_only'),
    );
    await pumpReflections(
      tester,
      rooms: FakeRoomsApi(detail: detailJson(state: 'memory')),
      reflections: api,
    );
    expect(find.byKey(const ValueKey('reflections-share')), findsNothing);
    expect(
      find.text(
        'This room is a memory: its reflections can be read, not added to.',
      ),
      findsOneWidget,
    );
    expect(find.text('first Diwali alone in this city'), findsOneWidget);
    final hug = find.byKey(
      const ValueKey('reflection-gesture-$cometReflectionId-hug'),
    );
    await tester.ensureVisible(hug);
    await tester.tap(hug, warnIfMissed: false);
    await settleRooms(tester);
    expect(api.gestures, isEmpty);
    await closeAll(tester);
  });

  group('realtime', () {
    testWidgets('reflection_published / reflection_removed on the room topic '
        'and gesture_received on yours refetch the list', (tester) async {
      final channels = FakeChannels();
      final api = _mixed();
      await pumpReflections(
        tester,
        rooms: FakeRoomsApi(),
        reflections: api,
        channels: channels,
      );
      final before = api.count('list');
      api.reflections = [
        reflectionJson('r-new', text: 'a new one'),
        ...api.reflections,
      ];
      channels.room.emit('reflection_published', {
        'reflectionId': 'r-new',
        'at': serverNow.toIso8601String(),
      });
      await settleRooms(tester);
      expect(api.count('list'), greaterThan(before));
      expect(find.text('a new one'), findsOneWidget);

      api.reflections = [
        for (final r in api.reflections)
          if (r['reflectionId'] != cometReflectionId) r,
      ];
      channels.room.emit('reflection_removed', {
        'reflectionId': cometReflectionId,
        'at': serverNow.toIso8601String(),
      });
      await settleRooms(tester);
      expect(_card(cometReflectionId), findsNothing);

      final beforeGesture = api.count('list');
      channels.member.emit('gesture_received', {
        'gestureId': 'g-1',
        'type': 'hug',
        'fromMemberId': cometId,
        'fromPseudonym': 'Quiet Comet',
        'reflectionId': myReflectionId,
        'at': serverNow.toIso8601String(),
      });
      await settleRooms(tester);
      expect(api.count('list'), greaterThan(beforeGesture));
      await tester.pump(const Duration(seconds: 1));
      await closeAll(tester);
    });

    testWidgets('reflection_status crisis_diverted on your member topic '
        'opens the support sheet at once', (tester) async {
      final channels = FakeChannels();
      await pumpReflections(
        tester,
        rooms: FakeRoomsApi(),
        reflections: _mixed(),
        channels: channels,
      );
      channels.member.emit('reflection_status', {
        'reflectionId': myReflectionId,
        'status': 'crisis_diverted',
        'at': serverNow.toIso8601String(),
      });
      await settleSheet(tester);
      expect(find.byType(SupportSheet), findsOneWidget);
      expect(find.text("You don't have to carry it alone."), findsOneWidget);
      await closeAll(tester);
    });
  });

  testWidgets('the room screen has the reflections section and its "Share a '
      'reflection" entry', (tester) async {
    await pumpReflections(
      tester,
      rooms: FakeRoomsApi(),
      reflections: _mixed(),
      home: const RoomScreen(roomId: roomId),
    );
    final share = find.byKey(const ValueKey('reflections-share'));
    await tester.scrollUntilVisible(
      share,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('room-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(share, findsOneWidget);
    expect(find.text('Reflections'), findsOneWidget);
    await closeAll(tester);
  });

  testWidgets('offline: a calm note, nothing called', (tester) async {
    final api = FakeReflectionsApi();
    await pumpReflections(
      tester,
      rooms: FakeRoomsApi(),
      reflections: api,
      connectivity: Stream.value(false),
    );
    expect(api.count('list'), 0);
    expect(
      find.text(
        'Reflections need a connection. Anything you write stays on this '
        'phone.',
      ),
      findsOneWidget,
    );
    await closeAll(tester);
  });
}
