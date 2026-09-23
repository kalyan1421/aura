import 'dart:async';

import 'package:aura/src/app.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/router/deep_links.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/features/home/home_screen.dart';
import 'package:aura/src/features/rooms/room_join_screen.dart';
import 'package:aura/src/features/rooms/room_navigation.dart';
import 'package:aura/src/features/rooms/room_screen.dart';
import 'package:aura/src/features/rooms/rooms_home_screen.dart';
import 'package:aura/src/features/rooms/your_rooms_strip.dart';
import 'package:aura/src/features/shell/app_shell.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'rooms_fakes.dart';

/// The Rooms tab (your rooms, memories, what rooms are, Lantern Hour, the
/// check-in CTA), the Home "Your rooms" strip, and the routes: the tab,
/// `/rooms/join` and `/rooms/:id` above the shell.

const String _stormRoom = '22222222-2222-4222-8222-222222222222';
const String _memoryRoom = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> _summary(
  String id, {
  String quadrant = 'rain',
  String state = 'open',
  int hereNow = 3,
  int today = 18,
  String pseudonym = 'Soft Harbor',
}) => {
  'room': roomInfoJson(id: id, quadrant: quadrant, state: state),
  'me': {
    'memberId': meId,
    'pseudonym': pseudonym,
    'moodChip': 'lonely',
    'joinedAt': serverNow.toIso8601String(),
  },
  'counts': {'hereNow': hereNow, 'today': today},
};

FakeRoomsApi _withRooms() => FakeRoomsApi()
  ..rooms_ = [
    _summary(roomId),
    _summary(
      _stormRoom,
      quadrant: 'storm',
      hereNow: 5,
      pseudonym: 'Brave Tide',
    ),
    _summary(_memoryRoom, quadrant: 'moonlight', state: 'memory', hereNow: 0),
  ];

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('the Rooms tab', () {
    testWidgets('your rooms (back with the same name), memories, and help in '
        'the top bar', (tester) async {
      final api = _withRooms();
      await pumpRooms(
        tester,
        const RoomsHomeScreen(),
        api: api,
        channels: FakeChannels(),
      );
      expect(find.text('Your rooms'), findsOneWidget);
      expect(find.text('Memories'), findsOneWidget);
      expect(find.text('The Rain Sanctuary'), findsOneWidget);
      expect(find.text('The Lighthouse'), findsOneWidget);
      expect(find.text("You're Brave Tide here"), findsOneWidget);
      expect(find.text('5 here now'), findsOneWidget);
      expect(find.text('The Midnight Observatory'), findsOneWidget);
      expect(find.textContaining('A memory until '), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(HelpNowButton),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('room-card-$roomId')));
      await settleSheet(tester);
      await settleRooms(tester);
      expect(find.byType(RoomScreen), findsOneWidget);
      expect(find.text("You're Soft Harbor here"), findsOneWidget);
      await _end(tester);
    });

    testWidgets('no rooms: what rooms are (a fresh name, no messages, a day '
        'long), Lantern Hour, and "Check in to find a room"', (tester) async {
      await pumpRooms(
        tester,
        const RoomsHomeScreen(),
        api: FakeRoomsApi(),
        channels: FakeChannels(),
      );
      expect(find.byKey(const ValueKey('rooms-empty')), findsOneWidget);
      expect(
        find.text('A fresh name in every room. Nobody sees your account.'),
        findsOneWidget,
      );
      expect(
        find.text('No messages or DMs: only eight warm gestures.'),
        findsOneWidget,
      );
      expect(
        find.text('Rooms last a day, then rest as a memory for 7 days.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('rooms-lantern-note')), findsOneWidget);
      expect(find.text('Check in to find a room'), findsOneWidget);
      await _end(tester);
    });

    testWidgets('"I need help now" is within the first three focus stops', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpRooms(
        tester,
        const RoomsHomeScreen(),
        api: _withRooms(),
        channels: FakeChannels(),
      );
      final labels = [
        for (final n in tester.semantics.simulatedAccessibilityTraversal())
          n.getSemanticsData().label,
      ];
      final help = labels.indexWhere((l) => l.contains('I need help now'));
      expect(help, inInclusiveRange(0, 2), reason: labels.take(4).join(' | '));
      semantics.dispose();
      await _end(tester);
    });

    testWidgets('offline: says so and makes no call', (tester) async {
      final net = StreamController<bool>();
      addTearDown(net.close);
      net.add(false);
      final api = _withRooms();
      await pumpRooms(
        tester,
        const RoomsHomeScreen(),
        api: api,
        connectivity: net.stream,
      );
      expect(
        find.text(
          'Rooms need a connection. Your own check-ins still save on this '
          'phone.',
        ),
        findsOneWidget,
      );
      expect(api.calls, isEmpty);
      await _end(tester);
    });

    testWidgets('200% Telugu: no overflow', (tester) async {
      await pumpRooms(
        tester,
        const RoomsHomeScreen(),
        api: _withRooms(),
        tag: 'te',
        scale: 2,
        size: const Size(360, 740),
      );
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const ValueKey('rooms-home')),
        const Offset(0, -2000),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _end(tester);
    });
  });

  group('the Home "Your rooms" strip', () {
    Widget strip() => const Scaffold(body: Center(child: YourRoomsStrip()));

    testWidgets('active rooms only (not memories), each at least 48 dp, read '
        'as "The Rain Sanctuary, 3 people here now"', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpRooms(
        tester,
        strip(),
        api: _withRooms(),
        channels: FakeChannels(),
      );
      expect(find.text('Your rooms'), findsOneWidget);
      expect(find.text('The Rain Sanctuary · 3 here now'), findsOneWidget);
      expect(find.text('The Lighthouse · 5 here now'), findsOneWidget);
      expect(find.textContaining('Observatory'), findsNothing);
      expect(
        find.bySemanticsLabel('The Rain Sanctuary, 3 people here now'),
        findsOneWidget,
      );
      for (final id in [roomId, _stormRoom]) {
        expect(
          tester.getSize(find.byKey(ValueKey('strip-room-$id'))).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.tap(find.byKey(const ValueKey('strip-room-$roomId')));
      await settleSheet(tester);
      await settleRooms(tester);
      expect(find.byType(RoomScreen), findsOneWidget);
      semantics.dispose();
      await _end(tester);
    });

    testWidgets('nothing at all with no rooms, offline or signed out', (
      tester,
    ) async {
      await pumpRooms(tester, strip(), api: FakeRoomsApi());
      expect(find.byKey(const ValueKey('your-rooms-strip')), findsNothing);
      await _end(tester);

      final net = StreamController<bool>();
      addTearDown(net.close);
      net.add(false);
      await pumpRooms(
        tester,
        strip(),
        api: _withRooms(),
        connectivity: net.stream,
      );
      expect(find.byKey(const ValueKey('your-rooms-strip')), findsNothing);
      expect(find.byType(Text), findsNothing, reason: 'no error on Home');
      await _end(tester);
    });
  });

  test('aura://rooms opens the Rooms tab', () {
    expect(DeepLinks.targetOf(Uri.parse('aura://rooms')), Routes.rooms);
  });

  group('routes', () {
    Future<ProviderContainer> app(WidgetTester tester, FakeRoomsApi api) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      // A ProviderScope in the tree: disposed with it, timers and all.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...roomsTestOverrides(
              db: memoryDb(),
              api: api,
              channels: FakeChannels(),
            ),
            deviceRegionProvider.overrideWithValue('IN'),
          ],
          child: const AuraApp(),
        ),
      );
      await settleIo(tester, rounds: 4);
      await tester.pump(const Duration(milliseconds: 600));
      return ProviderScope.containerOf(tester.element(find.byType(AuraApp)));
    }

    Future<void> settle(WidgetTester tester) async {
      await settleIo(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('the Rooms tab root has Settings (not Back) and the strip is '
        'on Home; /rooms/:id opens above the shell', (tester) async {
      final api = _withRooms();
      final c = await app(tester, api);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('your-rooms-strip')), findsOneWidget);

      await tester.tap(find.byKey(AuraNavBar.tabKey(ShellTab.rooms)));
      await settle(tester);
      expect(find.byType(RoomsHomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('shell-settings')), findsOneWidget);

      unawaited(c.read(routerProvider).push(Routes.room(roomId)));
      await settle(tester);
      expect(find.byType(RoomScreen), findsOneWidget);
      expect(find.byKey(AuraNavBar.barKey).hitTestable(), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('/rooms/join takes the check-in as extra (never in the '
        'location) and becomes the room', (tester) async {
      final api = FakeRoomsApi();
      final c = await app(tester, api);
      await io(
        tester,
        () => c.read(kvStoreProvider).set('rooms.guidelines_accepted', '1'),
      );
      const request = RoomJoinRequest(
        quadrant: Quadrant.rain,
        moodId: 'lonely',
      );
      unawaited(c.read(routerProvider).push(Routes.roomJoin, extra: request));
      await settle(tester);
      await settle(tester);
      expect(api.matches.single.moodId, 'lonely');
      expect(find.byType(RoomScreen), findsOneWidget);
      expect(find.byType(RoomJoinScreen), findsNothing);
      final location = c.read(routerProvider).state.uri.toString();
      expect(location, Routes.room(roomId));
      expect(location, isNot(contains('lonely')));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
