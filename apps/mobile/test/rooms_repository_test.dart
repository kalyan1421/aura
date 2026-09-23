import 'dart:convert';

import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/features/rooms/contact_check.dart';
import 'package:aura/src/features/rooms/room_models.dart';
import 'package:aura/src/features/rooms/room_realtime.dart';
import 'package:aura/src/features/rooms/rooms_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rooms_fakes.dart';

/// RoomsRepository (F5 / F9) over an in-memory server: match and re-entry,
/// limits that "look sent", online-only, error codes, and the DS-10
/// boundary in parsing.
void main() {
  late FakeRoomsApi api;
  late bool online;
  late int deletionHolds;
  late RoomsRepository repo;

  setUp(() {
    api = FakeRoomsApi();
    online = true;
    deletionHolds = 0;
    repo = RoomsRepository(
      api: api,
      isOnline: () => online,
      timezone: () => 'Asia/Kolkata',
      onDeletionPending: () => deletionHolds++,
    );
  });

  group('match', () {
    test('sends the check-in quadrant, mood and device zone; the detail is '
        'handed to the room screen once', () async {
      final result = await repo.match(quadrant: rain, moodId: 'lonely');
      final sent = api.matches.single.toJson();
      expect(sent, {
        'quadrant': 'rain',
        'moodId': 'lonely',
        'timezone': 'Asia/Kolkata',
      });
      expect(result.detail.room.roomId, roomId);
      expect(result.detail.me.pseudonym, 'Soft Harbor');
      expect(repo.takePrefetched(roomId), isNotNull);
      expect(repo.takePrefetched(roomId), isNull, reason: 'handed over once');
    });

    test('re-entry: the same quadrant returns the same room, pseudonym and '
        'memberId (step 0)', () async {
      final first = await repo.match(quadrant: rain, moodId: 'lonely');
      api.detail = {
        ...detailJson(),
        'match': {'step': 0, 'reentry': true},
      };
      final again = await repo.match(quadrant: rain, moodId: 'numb');
      expect(again.detail.room.roomId, first.detail.room.roomId);
      expect(again.detail.me.memberId, first.detail.me.memberId);
      expect(again.detail.me.pseudonym, first.detail.me.pseudonym);
    });

    test('"Join English room" retries with allowPoolFallback', () async {
      api.fail['match'] = const ApiException(
        code: 'language_pool_unavailable',
        status: 409,
      );
      await expectLater(
        repo.match(quadrant: rain, moodId: 'lonely'),
        throwsA(
          isA<RoomsFailure>().having(
            (f) => f.kind,
            'kind',
            RoomsFailureKind.poolUnavailable,
          ),
        ),
      );
      await repo.match(
        quadrant: rain,
        moodId: 'lonely',
        allowPoolFallback: true,
      );
      expect(api.matches.last.toJson()['allowPoolFallback'], isTrue);
    });
  });

  test('offline: every call fails as offline and nothing reaches the '
      'server (rooms are online only)', () async {
    online = false;
    Future<void> offline(Future<Object?> Function() call) => expectLater(
      call(),
      throwsA(
        isA<RoomsFailure>().having((f) => f.kind, 'kind', RoomsFailureKind.offline),
      ),
    );
    await offline(() => repo.match(quadrant: rain, moodId: 'lonely'));
    await offline(repo.myRooms);
    await offline(() => repo.room(roomId));
    await offline(() => repo.sendGesture(roomId, GestureType.hug));
    await offline(
      () => repo.report(RoomReportTarget(roomId), ReportReason.other),
    );
    await offline(() => repo.block(roomId, cometId));
    expect(api.calls, isEmpty);
  });

  test('over a limit, a gesture still "looks sent": the same 202 answer, '
      'no error, nothing for the app to show', () async {
    // The server drops the 2nd and 3rd silently (1 per 2 s); the app can't
    // tell and never says so.
    for (var i = 0; i < 3; i++) {
      final ack = await repo.sendGesture(
        roomId,
        GestureType.warmTea,
        toMemberId: cometId,
      );
      expect(ack.gestureId, isNotEmpty);
    }
    expect(api.gestures, hasLength(3));
  });

  group('error codes', () {
    Future<RoomsFailureKind> kindOf(ApiException e) async {
      api.fail['room'] = e;
      try {
        await repo.room(roomId);
      } on RoomsFailure catch (f) {
        return f.kind;
      }
      throw StateError('no failure');
    }

    test('map to calm, typed kinds', () async {
      expect(
        await kindOf(const ApiException(code: 'not_found', status: 404)),
        RoomsFailureKind.notFound,
      );
      expect(
        await kindOf(const ApiException(code: 'rooms_suspended', status: 403)),
        RoomsFailureKind.suspended,
      );
      expect(
        await kindOf(const ApiException(code: 'account_closed', status: 403)),
        RoomsFailureKind.closed,
      );
      expect(
        await kindOf(const ApiException(code: 'room_join_limit', status: 429)),
        RoomsFailureKind.joinLimit,
      );
      expect(
        await kindOf(const ApiException(code: 'report_limit', status: 429)),
        RoomsFailureKind.reportLimit,
      );
      expect(
        await kindOf(const ApiException(code: 'room_read_only', status: 409)),
        RoomsFailureKind.readOnly,
      );
      expect(
        await kindOf(const ApiException(code: 'profile_required', status: 409)),
        RoomsFailureKind.profileRequired,
      );
      expect(
        await kindOf(const ApiException(code: 'member_not_found', status: 404)),
        RoomsFailureKind.memberNotFound,
      );
      expect(
        await kindOf(const ApiException(code: 'http_503', status: 503)),
        RoomsFailureKind.network,
      );
      expect(
        await kindOf(
          const ApiException(code: 'connectionTimeout', isNetwork: true),
        ),
        RoomsFailureKind.network,
      );
    });

    test('403 account_deletion_pending also asks "Keep my account?" (the '
        'same hold as sync)', () async {
      expect(
        await kindOf(
          const ApiException(code: 'account_deletion_pending', status: 403),
        ),
        RoomsFailureKind.deletionPending,
      );
      expect(deletionHolds, 1);
    });
  });

  test('reports: reason 1 comes back with helplines (crisis lane); the note '
      'is trimmed and sent only when there is one', () async {
    final crisis = await repo.report(
      MemberReportTarget(roomId, cometId),
      ReportReason.inDanger,
      note: '  ',
    );
    expect(crisis.showHelplines, isTrue);
    final spam = await repo.report(
      GestureReportTarget(roomId, 'g1'),
      ReportReason.spam,
    );
    expect(spam.showHelplines, isFalse);
    expect(api.reports.first.target.toJson(), {
      'kind': 'member',
      'roomId': roomId,
      'memberId': cometId,
    });
  });

  group('DS-10: no account id, email, age or DOB can be shown or kept', () {
    const leaked = {
      'userId': 'acct-5f3a',
      'user_id': 'acct-5f3a',
      'sub': 'acct-5f3a',
      'email': 'someone@example.com',
      'age': 16,
      'birthDate': '2010-01-01',
      'isMinor': true,
    };

    test('a response carrying them anyway is parsed without them', () {
      final json = detailJson(
        members: [
          {...memberJson(meId, 'Soft Harbor', isMe: true), ...leaked},
          {...memberJson(cometId, 'Quiet Comet'), ...leaked},
        ],
        received: [
          {
            'gestureId': 'g1',
            'type': 'hug',
            'fromMemberId': cometId,
            'fromPseudonym': 'Quiet Comet',
            'at': serverNow.toIso8601String(),
            ...leaked,
          },
        ],
      );
      (json['me'] as Map<String, dynamic>).addAll(leaked);
      final detail = RoomDetail.fromJson(json);
      final kept = jsonEncode(detail.toJson());
      for (final key in leaked.keys) {
        expect(kept, isNot(contains('"$key"')), reason: key);
      }
      expect(kept, isNot(contains('acct-5f3a')));
      expect(kept, isNot(contains('someone@example.com')));
    });

    test('so do realtime payloads', () {
      final event = parseRoomEvent('member_joined', {
        'member': {...memberJson(cometId, 'Quiet Comet'), ...leaked},
        'counts': {'hereNow': 4, 'today': 19},
        'at': serverNow.toIso8601String(),
        'id': 'realtime-message-id',
      });
      expect(event, isA<MemberJoinedEvent>());
      final member = (event! as MemberJoinedEvent).member;
      final kept = jsonEncode(member.toJson());
      expect(kept, isNot(contains('acct-5f3a')));
      expect(member.live, isTrue);
      expect(member.isMe, isFalse);
    });
  });

  group('realtime payloads', () {
    test('unknown events and malformed payloads are ignored', () {
      expect(parseRoomEvent('reflection_published', {'id': 'x'}), isNull);
      expect(parseRoomEvent('gesture_sent', {'type': 'hug'}), isNull);
      expect(parseRoomEvent('presence', {'at': 'x'}), isNull);
    });

    test('an unknown gesture key from a newer server is not shown', () {
      final g = RoomGesture.fromJson({
        'gestureId': 'g9',
        'type': 'paper_boat',
        'target': 'room',
        'at': serverNow.toIso8601String(),
      });
      expect(g.gesture, isNull);
    });
  });

  group('contact details in a report note (on-device check)', () {
    test('numbers, emails, UPI ids, links and handles', () {
      for (final text in [
        'call 98765 43210',
        '+91 98765-43210',
        '౯౮౭౬౫౪౩౨౧౦',
        'mail me at name@example.com',
        'pay name@okaxis',
        'see www.example.in',
        'https://t.me/someone',
        'insta: @quietcomet',
      ]) {
        expect(containsContactDetails(text), isTrue, reason: text);
      }
    });

    test('ordinary words (and naming an app) are fine', () {
      for (final text in [
        'They kept asking which school I go to',
        'he asked for my insta',
        'sent me the same gesture 20 times',
        'room at 11 pm, 3 people',
      ]) {
        expect(containsContactDetails(text), isFalse, reason: text);
      }
    });
  });
}
