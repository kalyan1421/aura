import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/features/reflections/reflection_draft.dart';
import 'package:aura/src/features/reflections/reflection_models.dart';
import 'package:aura/src/features/reflections/reflections_api.dart';
import 'package:aura/src/features/reflections/reflections_controller.dart';
import 'package:aura/src/features/reflections/reflections_providers.dart';
import 'package:aura/src/features/reflections/reflections_repository.dart';
import 'package:aura/src/features/rooms/room_controller.dart';
import 'package:aura/src/features/rooms/room_models.dart';
import 'package:aura/src/features/rooms/room_realtime.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'reflections_fakes.dart';
import 'rooms_fakes.dart';

/// Reflections below the UI (F6, contracts/api/v1-reflections.md): the
/// HTTP shapes (no `parentId`, gestures with `target: reflection`, report
/// targets), error codes → calm kinds, online-only guard, DS-10 parsing,
/// the draft store, the remote flags and the controller with fakes.

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, [this.body = const <String, dynamic>{}]);

  final int status;
  final Object body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

HttpReflectionsApi _api(_Adapter adapter) => HttpReflectionsApi(
  baseUrl: 'http://test',
  accessToken: () async => 'token',
  dio: Dio(
    BaseOptions(
      baseUrl: 'http://test',
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter,
);

class _Host {
  _Host(this.c, this.api, this.rooms, this.channels);

  final ProviderContainer c;
  final FakeReflectionsApi api;
  final FakeRoomsApi rooms;
  final FakeChannels channels;

  RoomReflectionsState get state => c.read(roomReflectionsProvider(roomId));
  RoomReflections get ctl => c.read(roomReflectionsProvider(roomId).notifier);
}

Future<_Host> _host(WidgetTester tester, FakeReflectionsApi api) async {
  final rooms = FakeRoomsApi();
  final channels = FakeChannels();
  await tester.pumpWidget(
    ProviderScope(
      overrides: reflectionsOverrides(
        db: memoryDb(),
        rooms: rooms,
        reflections: api,
        channels: channels,
      ),
      child: Consumer(
        builder: (context, ref, _) {
          ref.watch(roomReflectionsProvider(roomId));
          return const SizedBox(key: ValueKey('host'));
        },
      ),
    ),
  );
  final c = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('host'))),
  );
  await settleRooms(tester);
  return _Host(c, api, rooms, channels);
}

void main() {
  group('HTTP', () {
    test('send: exactly reflectionId and text (never a parentId)', () async {
      final adapter = _Adapter(
        201,
        outcomeJson(myReflectionId, status: 'held', review: 'overnight'),
      );
      final outcome = await _api(
        adapter,
      ).send(roomId, reflectionId: myReflectionId, text: 'first Diwali alone');
      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/v1/rooms/$roomId/reflections');
      expect(req.data, {
        'reflectionId': myReflectionId,
        'text': 'first Diwali alone',
      });
      expect(req.headers['Authorization'], 'Bearer token');
      expect(outcome.statusValue, ReflectionStatus.held);
      expect(outcome.reviewValue, ReviewHint.overnight);
    });

    test(
      'a gesture on a reflection: target reflection + toReflectionId',
      () async {
        final adapter = _Adapter(202, {
          'gestureId': 'g-1',
          'at': serverNow.toIso8601String(),
        });
        await _api(adapter).sendGesture(
          roomId,
          GestureType.warmTea,
          reflectionId: cometReflectionId,
        );
        final req = adapter.requests.single;
        expect(req.path, '/v1/rooms/$roomId/gestures');
        expect(req.data, {
          'type': 'warm_tea',
          'target': 'reflection',
          'toReflectionId': cometReflectionId,
        });
      },
    );

    test('list and delete paths; DS-10: nothing but memberId and pseudonym '
        'of an author survives parsing', () async {
      final adapter = _Adapter(200, {
        'reflections': [
          {
            ...reflectionJson(cometReflectionId),
            'author': {
              'memberId': cometId,
              'pseudonym': 'Quiet Comet',
              'accountId': 'account-u2',
              'age': 15,
            },
            'moderationScore': 0.2,
          },
        ],
        'composer': composerJson(remainingInRoom: 2),
      });
      final list = await _api(adapter).list(roomId);
      expect(adapter.requests.single.path, '/v1/rooms/$roomId/reflections');
      final r = list.reflections.single;
      expect(r.author.toJson(), {
        'memberId': cometId,
        'pseudonym': 'Quiet Comet',
      });
      expect(r.toJson().keys, isNot(contains('moderationScore')));
      expect(list.composer.remainingInRoom, 2);

      final del = _Adapter(204);
      await _api(del).delete(roomId, myReflectionId);
      expect(del.requests.single.method, 'DELETE');
      expect(
        del.requests.single.path,
        '/v1/rooms/$roomId/reflections/$myReflectionId',
      );
    });

    test('a report on a reflection names it', () {
      expect(const ReflectionReportTarget(roomId, cometReflectionId).toJson(), {
        'kind': 'reflection',
        'roomId': roomId,
        'reflectionId': cometReflectionId,
      });
    });

    test('an error carries its code (never a body)', () async {
      final adapter = _Adapter(429, {
        'code': 'reflection_room_limit',
        'message': "That's 3 reflections for today.",
      });
      await expectLater(
        _api(adapter).send(roomId, reflectionId: myReflectionId, text: 'x'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'reflection_room_limit')
              .having((e) => e.status, 'status', 429),
        ),
      );
    });
  });

  group('errors → calm kinds', () {
    final cases = <(int?, String, ReflectionsFailureKind)>[
      (429, 'reflection_room_limit', ReflectionsFailureKind.roomLimit),
      (429, 'reflection_daily_limit', ReflectionsFailureKind.dailyLimit),
      (503, 'reflections_paused', ReflectionsFailureKind.paused),
      (409, 'room_read_only', ReflectionsFailureKind.readOnly),
      (409, 'reflection_id_conflict', ReflectionsFailureKind.idConflict),
      (404, 'reflection_not_found', ReflectionsFailureKind.reflectionNotFound),
      (404, 'not_found', ReflectionsFailureKind.notFound),
      (400, 'replies_not_supported', ReflectionsFailureKind.other),
      (400, 'invalid_request', ReflectionsFailureKind.other),
      (400, 'invalid_target', ReflectionsFailureKind.invalidTarget),
      (403, 'rooms_suspended', ReflectionsFailureKind.suspended),
      (401, 'signed_out', ReflectionsFailureKind.signedOut),
      (502, 'http_502', ReflectionsFailureKind.network),
    ];
    for (final (status, code, kind) in cases) {
      test('$status $code → ${kind.name}', () {
        final f = ReflectionsFailure.from(
          ApiException(code: code, status: status),
        );
        expect(f.kind, kind);
      });
    }
    test('no response → network (retried with the same id)', () {
      final f = ReflectionsFailure.from(
        const ApiException(code: 'connectionTimeout', isNetwork: true),
      );
      expect(f.kind, ReflectionsFailureKind.network);
      expect(f.isTransient, isTrue);
    });
  });

  group('repository', () {
    test('offline: nothing is called', () async {
      final api = FakeReflectionsApi();
      final repo = ReflectionsRepository(api: api, isOnline: () => false);
      await expectLater(
        repo.send(roomId, reflectionId: myReflectionId, text: 'hi'),
        throwsA(
          isA<ReflectionsFailure>().having(
            (f) => f.kind,
            'kind',
            ReflectionsFailureKind.offline,
          ),
        ),
      );
      expect(api.calls, isEmpty);
    });

    test('no API in this build: unavailable', () async {
      final repo = ReflectionsRepository(api: null, isOnline: () => true);
      expect(repo.isAvailable, isFalse);
      await expectLater(
        repo.list(roomId),
        throwsA(
          isA<ReflectionsFailure>().having(
            (f) => f.kind,
            'kind',
            ReflectionsFailureKind.unavailable,
          ),
        ),
      );
    });

    test(
      'the text is trimmed; an account_deletion_pending runs the hook',
      () async {
        final api = FakeReflectionsApi();
        var held = 0;
        final repo = ReflectionsRepository(
          api: api,
          isOnline: () => true,
          onDeletionPending: () => held++,
        );
        await repo.send(roomId, reflectionId: myReflectionId, text: '  hi  ');
        expect(api.sends.single.text, 'hi');
        api.fail['list'] = const ApiException(
          code: ApiException.deletionPendingCode,
          status: 403,
        );
        await expectLater(
          repo.list(roomId),
          throwsA(isA<ReflectionsFailure>()),
        );
        expect(held, 1);
      },
    );
  });

  testWidgets('draft store: saved, loaded and cleared per room', (
    tester,
  ) async {
    final db = memoryDb();
    final store = ReflectionDraftStore(KvStore(db));
    await tester.runAsync(() async {
      expect(await store.load(roomId), isNull);
      await store.save(
        roomId,
        const ReflectionDraft(reflectionId: myReflectionId, text: 'hello'),
      );
      final back = await store.load(roomId);
      expect(back?.reflectionId, myReflectionId);
      expect(back?.text, 'hello');
      expect(await store.load('other-room'), isNull);
      await store.clear(roomId);
      expect(await store.load(roomId), isNull);
      await db.close();
    });
  });

  group('remote flags', () {
    test(
      'reflections_composer defaults on; off, or reduced_mode on, pauses',
      () {
        expect(reflectionsComposerAllowedBy(const RemoteFlags()), isTrue);
        expect(
          reflectionsComposerAllowedBy(
            const RemoteFlags({
              'reflections_composer': FlagValue(enabled: true),
            }),
          ),
          isTrue,
        );
        expect(
          reflectionsComposerAllowedBy(
            const RemoteFlags({
              'reflections_composer': FlagValue(enabled: false),
            }),
          ),
          isFalse,
        );
        expect(
          reflectionsComposerAllowedBy(
            const RemoteFlags({'reduced_mode': FlagValue(enabled: true)}),
          ),
          isFalse,
        );
      },
    );
  });

  group('realtime parsing', () {
    test('reflection events: ids (and your status) only', () {
      final published = parseRoomEvent('reflection_published', {
        'reflectionId': cometReflectionId,
        'at': serverNow.toIso8601String(),
      });
      expect(published, isA<ReflectionEvent>());
      expect((published! as ReflectionEvent).reflectionId, cometReflectionId);
      final status = parseRoomEvent('reflection_status', {
        'reflectionId': myReflectionId,
        'status': 'crisis_diverted',
        'at': serverNow.toIso8601String(),
      }) as ReflectionEvent?;
      expect(status?.status, 'crisis_diverted');
      expect(parseRoomEvent('reflection_removed', {}), isNull);
      final gesture = parseRoomEvent('gesture_received', {
        'gestureId': 'g-1',
        'type': 'hug',
        'fromMemberId': cometId,
        'fromPseudonym': 'Quiet Comet',
        'reflectionId': myReflectionId,
        'at': serverNow.toIso8601String(),
      }) as GestureReceivedEvent?;
      expect(gesture?.reflectionId, myReflectionId);
    });
  });

  group('controller', () {
    testWidgets('loads the list and the composer; a send adds your item and '
        'the new allowance', (tester) async {
      final h = await _host(
        tester,
        FakeReflectionsApi(reflections: [reflectionJson(cometReflectionId)]),
      );
      expect(h.state.load, ReflectionsLoad.ready);
      expect(h.state.reflections, hasLength(1));
      expect(h.state.composer?.remainingInRoom, 3);
      final outcome = await h.ctl.send(
        reflectionId: myReflectionId,
        text: 'hello',
      );
      await settleRooms(tester);
      expect(outcome.statusValue, ReflectionStatus.published);
      expect(h.state.reflections.first.reflectionId, myReflectionId);
      expect(h.state.composer?.remainingInRoom, 2);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a limit answer turns the composer to limit_reached', (
      tester,
    ) async {
      final api = FakeReflectionsApi();
      final h = await _host(tester, api);
      api.fail['send'] = const ApiException(
        code: 'reflection_daily_limit',
        status: 429,
      );
      api.composer = composerJson(state: 'limit_reached', remainingToday: 0);
      await expectLater(
        h.ctl.send(reflectionId: myReflectionId, text: 'x'),
        throwsA(isA<ReflectionsFailure>()),
      );
      expect(h.state.composer?.stateValue, ComposerState.limitReached);
      await settleRooms(tester);
      expect(h.state.composer?.remainingToday, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reported, blocked and muted authors hide at once; unmute '
        'brings them back', (tester) async {
      final api = FakeReflectionsApi(
        reflections: [
          reflectionJson(cometReflectionId),
          reflectionJson(
            riverReflectionId,
            memberId: riverId,
            pseudonym: 'Silver River',
          ),
        ],
      );
      final h = await _host(tester, api);
      h.ctl.reported(cometReflectionId);
      await settleRooms(tester);
      // The server still lists it for a moment: it stays hidden here.
      expect(h.state.reflections.map((r) => r.reflectionId), [
        riverReflectionId,
      ]);
      h.ctl.hideAuthor(riverId);
      await settleRooms(tester);
      expect(h.state.reflections, isEmpty);
      h.ctl.showAuthor(riverId);
      await settleRooms(tester);
      expect(h.state.reflections.map((r) => r.reflectionId), [
        riverReflectionId,
      ]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a gesture goes out once per 2 s and is marked as yours for '
        'the room feed', (tester) async {
      final api = FakeReflectionsApi(
        reflections: [reflectionJson(cometReflectionId)],
      );
      final h = await _host(tester, api);
      final r = h.state.reflections.single;
      expect(await h.ctl.sendGesture(r, GestureType.hug), isTrue);
      expect(await h.ctl.sendGesture(r, GestureType.hug), isFalse);
      expect(api.gestures, hasLength(1));
      // Its anonymous copy on the room topic doesn't play as someone else's.
      h.channels.room.emit('gesture_sent', {
        'gestureId': 'eeeeeeee-0000-4000-8000-000000000001',
        'type': 'hug',
        'target': 'reflection',
        'reflectionId': cometReflectionId,
        'at': serverNow.toIso8601String(),
      });
      await tester.pump(const Duration(seconds: 1));
      expect(
        h.c.read(roomControllerProvider(roomId)).detail?.gestures.recent,
        isEmpty,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(h.state.coolingDown, isFalse);
      // Never on your own.
      final mine = Reflection.fromJson(
        reflectionJson(myReflectionId, memberId: meId, isMine: true),
      );
      expect(await h.ctl.sendGesture(mine, GestureType.hug), isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reflection_status crisis_diverted bumps the support serial '
        'once per reflection', (tester) async {
      final h = await _host(tester, FakeReflectionsApi());
      for (var i = 0; i < 2; i++) {
        h.channels.member.emit('reflection_status', {
          'reflectionId': myReflectionId,
          'status': 'crisis_diverted',
          'at': serverNow.toIso8601String(),
        });
        await settleRooms(tester);
      }
      expect(h.state.supportSerial, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
