import 'dart:async';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/rooms/room_guidelines.dart';
import 'package:aura/src/features/rooms/room_join_screen.dart';
import 'package:aura/src/features/rooms/room_navigation.dart';
import 'package:aura/src/features/rooms/room_offer.dart';
import 'package:aura/src/features/rooms/room_screen.dart';
import 'package:aura/src/features/rooms/rooms_providers.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'rooms_fakes.dart';

/// "Join a room of people feeling this" (REQ-ROOM-01) and matching: the
/// offline line with no call, signed out / onboarding explained (never a
/// dead button), the guidelines before the first room (REQ-SAFE-04), the
/// check-in's mood, and the join states (loading, pool not open, limit,
/// offline).

Widget _offer({String? moodId = 'lonely'}) => Scaffold(
  body: Center(
    child: RoomOfferButton(quadrant: Quadrant.rain, moodId: moodId),
  ),
);

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// Taps the offer and lets the guidelines read land.
Future<void> _tapOffer(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('room-offer')));
  await settleIo(tester);
  await settleSheet(tester);
}

void main() {
  testWidgets('offline: "Rooms open when you\'re back online", and no call '
      '(REQ-ROOM-01)', (tester) async {
    final net = StreamController<bool>();
    addTearDown(net.close);
    net.add(false);
    final api = FakeRoomsApi();
    await pumpRooms(tester, _offer(), api: api, connectivity: net.stream);
    expect(find.text("Rooms open when you're back online"), findsOneWidget);
    expect(find.byKey(const ValueKey('room-offer')), findsNothing);
    expect(api.calls, isEmpty);
    // Back online: the offer appears by itself.
    net.add(true);
    await settleRooms(tester);
    expect(find.byKey(const ValueKey('room-offer')), findsOneWidget);
    expect(api.calls, isEmpty);
    await _end(tester);
  });

  testWidgets('online: guidelines first, then "Finding people…", then the '
      'room, matched on this check-in', (tester) async {
    final api = FakeRoomsApi()..hold = Completer<void>();
    await pumpRooms(tester, _offer(), api: api);
    expect(find.text('Join a room of people feeling this'), findsOneWidget);
    await _tapOffer(tester);
    expect(find.byKey(const ValueKey('rooms-guidelines')), findsOneWidget);
    expect(find.text('Before your first room'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rooms-guidelines-agree')));
    await settleIo(tester);
    await settleSheet(tester);
    // The join screen (its own guidelines check reads the store).
    await settleIo(tester);
    expect(
      find.text('Finding people who feel this way right now…'),
      findsOneWidget,
    );
    api.hold!.complete();
    api.hold = null;
    await settleSheet(tester);
    await settleRooms(tester);
    expect(api.matches.single.toJson(), {
      'quadrant': 'rain',
      'moodId': 'lonely',
      'timezone': 'Asia/Kolkata',
    });
    expect(find.byType(RoomScreen), findsOneWidget);
    expect(find.byType(RoomJoinScreen), findsNothing);
    expect(find.text("You're Soft Harbor here"), findsOneWidget);
    await _end(tester);
  });

  testWidgets('leaving the guidelines never enters a room; accepted once, '
      'they are not asked again', (tester) async {
    final api = FakeRoomsApi();
    final db = await pumpRooms(tester, _offer(), api: api);
    await _tapOffer(tester);
    await tester.tap(find.byKey(const ValueKey('rooms-guidelines-later')));
    await settleSheet(tester);
    await settleIo(tester);
    expect(api.matches, isEmpty);
    expect(find.byType(RoomJoinScreen), findsNothing);

    await io(
      tester,
      () => db.setValue(roomGuidelinesKey, '$roomGuidelinesVersion'),
    );
    await _tapOffer(tester);
    expect(find.byKey(const ValueKey('rooms-guidelines')), findsNothing);
    await settleIo(tester);
    await settleRooms(tester);
    expect(api.matches, hasLength(1));
    await _end(tester);
  });

  testWidgets('without a mood given, it joins with the newest check-in in '
      'the quadrant on this phone', (tester) async {
    final api = FakeRoomsApi();
    final db = await pumpRooms(tester, _offer(moodId: null), api: api);
    await io(tester, () async {
      await db.setValue(roomGuidelinesKey, '$roomGuidelinesVersion');
      Future<void> add(String id, String mood, Duration ago) => db
          .into(db.checkIns)
          .insert(
            CheckInsCompanion.insert(
              id: id,
              moodId: mood,
              quadrant: moodById(mood)!.quadrant.name,
              localDay: '2026-10-08',
              deviceTs: testNow.subtract(ago),
              tzOffsetMinutes: 330,
              tz: const Value('Asia/Kolkata'),
            ),
          );
      await add('c1', 'melancholy', const Duration(hours: 3));
      await add('c2', 'numb', const Duration(minutes: 1));
      await add('c3', 'anxious', Duration.zero); // another quadrant
    });
    await _tapOffer(tester);
    await settleIo(tester);
    await settleRooms(tester);
    expect(api.matches.single.moodId, 'numb');
    await _end(tester);
  });

  testWidgets('the offer reads as one button with a hint about the fresh '
      'name', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRooms(tester, _offer(), api: FakeRoomsApi());
    expect(
      tester.getSemantics(find.byKey(const ValueKey('room-offer'))),
      isSemantics(
        label: 'Join a room of people feeling this',
        hint: 'Opens a room, with a fresh name just for it',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
    await _end(tester);
  });

  testWidgets('signed out: a calm line, no button to nowhere', (tester) async {
    final api = FakeRoomsApi();
    await pumpRooms(tester, _offer(), api: api, auth: const _SignedOut());
    expect(find.text("Rooms open once you're signed in."), findsOneWidget);
    expect(find.byKey(const ValueKey('room-offer')), findsNothing);
    expect(api.calls, isEmpty);
    await _end(tester);
  });

  testWidgets('the first check-in (still onboarding): where rooms are, no '
      'button', (tester) async {
    await pumpRooms(
      tester,
      _offer(),
      api: FakeRoomsApi(),
      gate: const GateState(stage: OnboardingStage.firstCheckIn),
    );
    expect(
      find.text("Rooms are in the Rooms tab whenever you'd like company."),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('room-offer')), findsNothing);
    await _end(tester);
  });

  testWidgets('a build without rooms shows nothing at all', (tester) async {
    await pumpRooms(
      tester,
      _offer(),
      api: FakeRoomsApi(),
      auth: const UnavailableAuthRepository(),
    );
    expect(find.byType(RoomOfferButton), findsOneWidget);
    expect(find.byType(Text), findsNothing);
    await _end(tester);
  });

  group('joining', () {
    const request = RoomJoinRequest(quadrant: Quadrant.rain, moodId: 'lonely');

    Future<AppDatabase> join(
      WidgetTester tester,
      FakeRoomsApi api, {
      Stream<bool>? connectivity,
    }) async {
      return pumpRooms(
        tester,
        const RoomJoinScreen(request: request),
        api: api,
        connectivity: connectivity,
        seed: (db) => db.setValue(roomGuidelinesKey, '$roomGuidelinesVersion'),
      );
    }

    testWidgets('Hindi + Hinglish not open yet: "Join English room" retries '
        'with the fallback', (tester) async {
      final api = FakeRoomsApi()
        ..fail['match'] = const ApiException(
          code: 'language_pool_unavailable',
          status: 409,
        );
      await join(tester, api);
      await settleIo(tester);
      await settleRooms(tester);
      expect(
        find.text(
          'Hindi and Hinglish rooms are opening soon. Join an English room '
          'for now?',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('rooms-pool-english')));
      await settleSheet(tester);
      await settleRooms(tester);
      expect(api.matches.last.allowPoolFallback, isTrue);
      expect(find.byType(RoomScreen), findsOneWidget);
      await _end(tester);
    });

    testWidgets('"Tell me when they open" is kept on this phone', (
      tester,
    ) async {
      final api = FakeRoomsApi()
        ..fail['match'] = const ApiException(
          code: 'language_pool_unavailable',
          status: 409,
        );
      final db = await join(tester, api);
      await settleIo(tester);
      await settleRooms(tester);
      await tester.tap(find.byKey(const ValueKey('rooms-pool-notify')));
      await settleIo(tester);
      expect(find.byKey(const ValueKey('rooms-pool-notified')), findsOneWidget);
      expect(await io(tester, () => db.getValue(roomsNotifyHiPoolKey)), '1');
      await _end(tester);
    });

    testWidgets('3 new rooms for this feeling today: calm words and "See your '
        'rooms"', (tester) async {
      final api = FakeRoomsApi()
        ..fail['match'] = const ApiException(
          code: 'room_join_limit',
          status: 429,
        );
      await join(tester, api);
      await settleIo(tester);
      await settleRooms(tester);
      expect(
        find.text(
          "That's 3 new rooms for this feeling today. The rooms you're in are "
          'still open to you.',
        ),
        findsOneWidget,
      );
      expect(find.text('See your rooms'), findsOneWidget);
      await _end(tester);
    });

    testWidgets('offline: "Rooms need a connection. Your check-in is saved.", '
        'no call; it joins by itself once back online', (tester) async {
      final net = StreamController<bool>();
      addTearDown(net.close);
      net.add(false);
      final api = FakeRoomsApi();
      await join(tester, api, connectivity: net.stream);
      await settleIo(tester);
      await settleRooms(tester);
      expect(
        find.text('Rooms need a connection. Your check-in is saved.'),
        findsOneWidget,
      );
      expect(api.calls, isEmpty);
      net.add(true);
      await settleRooms(tester);
      await settleSheet(tester);
      expect(api.matches, hasLength(1));
      expect(find.byType(RoomScreen), findsOneWidget);
      await _end(tester);
    });
  });
}

class _SignedOut implements AuthRepository {
  const _SignedOut();

  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => null;
  @override
  Stream<AuthUser?> watchUser() => Stream.value(null);
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<void> sendEmailCode(String email) async {}
  @override
  Future<void> verifyEmailCode(String email, String code) async {}
  @override
  Future<void> signOut() async {}
}
