import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/features/rooms/room_guidelines.dart';
import 'package:aura/src/features/rooms/room_join_screen.dart';
import 'package:aura/src/features/rooms/room_models.dart';
import 'package:aura/src/features/rooms/room_offer.dart';
import 'package:aura/src/features/rooms/room_screen.dart';
import 'package:aura/src/features/rooms/rooms_api.dart';
import 'package:aura/src/features/rooms/rooms_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'rooms_fakes.dart';

/// Community guidelines before a room, recorded on the server (F9
/// REQ-SAFE-04, contracts/api/v1-rooms.md §1.1 / §2.4): the phone's flag is
/// only a cache; `409 guidelines_required` from the match brings the
/// guidelines back, agreeing records them (`POST
/// /v1/safety/guidelines/accept`) and the match is tried again; leaving them
/// never enters a room; guidelines newer than this build: "update Aura".

Widget _offer() => const Scaffold(
  body: Center(
    child: RoomOfferButton(quadrant: Quadrant.rain, moodId: 'lonely'),
  ),
);

const _update =
    'Rooms have new community guidelines. Update Aura to read them before '
    'your next room.';

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tapOffer(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('room-offer')));
  await settleIo(tester);
  await settleSheet(tester);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await settleIo(tester);
  await settleSheet(tester);
  await settleRooms(tester);
}

Future<void> _cache(WidgetTester tester, AppDatabase db) =>
    io(tester, () => db.setValue(roomGuidelinesKey, '$roomGuidelinesVersion'));

Future<String?> _cached(WidgetTester tester, AppDatabase db) =>
    io(tester, () => db.getValue(roomGuidelinesKey));

final _sheet = find.byKey(const ValueKey('rooms-guidelines'));

void main() {
  group('the join screen', () {
    testWidgets('first time on this phone: the guidelines, recorded on the '
        'server, then the match', (tester) async {
      final api = FakeRoomsApi();
      final db = await pumpRooms(tester, _offer(), api: api);
      await _tapOffer(tester);
      expect(_sheet, findsOneWidget);
      expect(api.calls, isEmpty, reason: 'nothing before the person agrees');
      await _tap(tester, 'rooms-guidelines-agree');
      expect(api.calls, ['acceptGuidelines', 'match']);
      expect(api.acceptedGuidelines, [roomGuidelinesVersion]);
      expect(await _cached(tester, db), '$roomGuidelinesVersion');
      expect(find.byType(RoomScreen), findsOneWidget);
      await _end(tester);
    });

    testWidgets('cached on this phone: straight to the match, no second '
        'record', (tester) async {
      final api = FakeRoomsApi();
      final db = await pumpRooms(tester, _offer(), api: api);
      await _cache(tester, db);
      await _tapOffer(tester);
      await settleRooms(tester);
      expect(_sheet, findsNothing);
      expect(api.calls, ['match']);
      expect(find.byType(RoomScreen), findsOneWidget);
      await _end(tester);
    });

    testWidgets('the phone says yes, the server says no (another phone, a '
        'material change): the guidelines, the record, the same match '
        'again', (tester) async {
      final api = FakeRoomsApi()
        ..fail['match'] = const GuidelinesRequiredException(1);
      final db = await pumpRooms(tester, _offer(), api: api);
      await _cache(tester, db);
      await _tapOffer(tester);
      await settleSheet(tester);
      expect(_sheet, findsOneWidget);
      expect(await _cached(tester, db), isNull, reason: 'the cache is dropped');
      await _tap(tester, 'rooms-guidelines-agree');
      expect(api.calls, ['match', 'acceptGuidelines', 'match']);
      expect(api.matches, hasLength(2));
      expect(
        api.matches.last.toJson(),
        api.matches.first.toJson(),
        reason: 'the same request is tried again',
      );
      expect(await _cached(tester, db), '$roomGuidelinesVersion');
      expect(find.byType(RoomScreen), findsOneWidget);
      await _end(tester);
    });

    testWidgets('409 then "Not now": no room, nothing recorded, the join '
        'screen closes (REQ-SAFE-04 negative)', (tester) async {
      final api = FakeRoomsApi()
        ..fail['match'] = const GuidelinesRequiredException(1);
      final db = await pumpRooms(tester, _offer(), api: api);
      await _cache(tester, db);
      await _tapOffer(tester);
      await settleSheet(tester);
      await _tap(tester, 'rooms-guidelines-later');
      expect(api.calls, ['match']);
      expect(api.acceptedGuidelines, isEmpty);
      expect(find.byType(RoomJoinScreen), findsNothing);
      expect(find.byType(RoomScreen), findsNothing);
      expect(find.byKey(const ValueKey('room-offer')), findsOneWidget);
      await _end(tester);
    });

    testWidgets('guidelines newer than this build carries: "update Aura", '
        'no sheet, nothing recorded', (tester) async {
      final api = FakeRoomsApi()
        ..fail['match'] = const GuidelinesRequiredException(
          roomGuidelinesVersion + 1,
        );
      final db = await pumpRooms(tester, _offer(), api: api);
      await _cache(tester, db);
      await _tapOffer(tester);
      await settleRooms(tester);
      expect(_sheet, findsNothing);
      expect(find.text(_update), findsOneWidget);
      expect(api.acceptedGuidelines, isEmpty);
      await tester.tap(find.text('Done'));
      await settleSheet(tester);
      expect(find.byType(RoomJoinScreen), findsNothing);
      await _end(tester);
    });

    testWidgets('the server refuses this build\'s version as too old: '
        '"update Aura", no room', (tester) async {
      final api = FakeRoomsApi()
        ..fail['acceptGuidelines'] = const GuidelinesRequiredException(
          roomGuidelinesVersion + 1,
        );
      await pumpRooms(tester, _offer(), api: api);
      await _tapOffer(tester);
      await _tap(tester, 'rooms-guidelines-agree');
      expect(find.text(_update), findsOneWidget);
      expect(api.matches, isEmpty);
      expect(find.byType(RoomScreen), findsNothing);
      await _end(tester);
    });

    testWidgets('the record doesn\'t go through: calm words and Try again; '
        'retrying records, then matches, without asking again', (tester) async {
      final api = FakeRoomsApi()
        ..fail['acceptGuidelines'] = const ApiException(
          code: 'internal_error',
          status: 500,
        );
      final db = await pumpRooms(tester, _offer(), api: api);
      await _tapOffer(tester);
      await _tap(tester, 'rooms-guidelines-agree');
      expect(
        find.text(
          "We couldn't reach the rooms just now. Your check-in is saved.",
        ),
        findsOneWidget,
      );
      expect(api.matches, isEmpty);
      expect(await _cached(tester, db), isNull);
      await _tap(tester, 'rooms-retry');
      expect(_sheet, findsNothing, reason: 'agreed once on this visit');
      expect(api.calls, ['acceptGuidelines', 'acceptGuidelines', 'match']);
      expect(find.byType(RoomScreen), findsOneWidget);
      await _end(tester);
    });
  });

  group('the rooms client', () {
    late _Adapter adapter;
    late RoomsRepository repo;

    setUp(() {
      adapter = _Adapter();
      repo = RoomsRepository(
        api: HttpRoomsApi(
          baseUrl: 'http://test',
          accessToken: () async => 'jwt',
          dio: Dio(
            BaseOptions(
              baseUrl: 'http://test',
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ),
          )..httpClientAdapter = adapter,
        ),
        isOnline: () => true,
        timezone: () => 'Asia/Kolkata',
      );
    });

    test('accept: POST /v1/safety/guidelines/accept {version} → the '
        'status', () async {
      adapter.reply = (
        200,
        {
          'version': 1,
          'accepted': true,
          'acceptedVersion': 1,
          'acceptedAt': '2026-10-08T10:00:00.000Z',
        },
      );
      final s = await repo.acceptGuidelines(1);
      final (method, path, body) = adapter.sent.single;
      expect((method, path), ('POST', '/v1/safety/guidelines/accept'));
      expect(body, {'version': 1});
      expect(s.version, 1);
      expect(s.accepted, isTrue);
      expect(s.acceptedVersion, 1);
    });

    test('409 guidelines_required carries the version to accept', () async {
      adapter.reply = (
        409,
        {
          'code': 'guidelines_required',
          'message':
              'Accept the community guidelines (version 2) before '
              'joining a room.',
          'version': 2,
        },
      );
      final f = await repo
          .match(quadrant: Quadrant.rain, moodId: 'lonely')
          .then<RoomsFailure?>(
            (_) => null,
            onError: (Object e) => e as RoomsFailure,
          );
      expect(f?.kind, RoomsFailureKind.guidelinesRequired);
      expect(f?.guidelinesVersion, 2);
      expect(f?.isTransient, isFalse);
      // Without a version (an older server): this build's version.
      adapter.reply = (409, {'code': 'guidelines_required', 'message': 'x'});
      final g = await repo
          .acceptGuidelines(1)
          .then<RoomsFailure?>(
            (_) => null,
            onError: (Object e) => e as RoomsFailure,
          );
      expect(g?.kind, RoomsFailureKind.guidelinesRequired);
      expect(g?.guidelinesVersion, 1);
    });

    test('offline: nothing is called', () async {
      final offline = RoomsRepository(
        api: FakeRoomsApi(),
        isOnline: () => false,
        timezone: () => 'Asia/Kolkata',
      );
      await expectLater(
        offline.acceptGuidelines(1),
        throwsA(
          isA<RoomsFailure>().having(
            (f) => f.kind,
            'kind',
            RoomsFailureKind.offline,
          ),
        ),
      );
    });

    test('report reason 9 goes out as 9', () async {
      adapter.reply = (
        201,
        {
          'reportId': 'cccccccc-0000-4000-8000-000000000001',
          'showHelplines': false,
        },
      );
      await repo.report(
        const MemberReportTarget(roomId, cometId),
        ReportReason.targetingYoungPerson,
      );
      final (method, path, body) = adapter.sent.single;
      expect((method, path), ('POST', '/v1/safety/reports'));
      expect((body! as Map)['reason'], 9);
    });
  });
}

/// Answers every request with [reply]; records method, path and JSON body.
class _Adapter implements HttpClientAdapter {
  (int, Object) reply = (200, const <String, Object>{});
  final List<(String, String, Object?)> sent = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add((options.method, options.path, options.data));
    final (status, body) = reply;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
