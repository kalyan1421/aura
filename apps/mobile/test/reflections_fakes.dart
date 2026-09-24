import 'dart:async';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/core/remote_config/remote_config_providers.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/reflections/reflection_models.dart';
import 'package:aura/src/features/reflections/reflections_api.dart';
import 'package:aura/src/features/reflections/reflections_providers.dart';
import 'package:aura/src/features/reflections/reflections_section.dart';
import 'package:aura/src/features/rooms/room_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'rooms_fakes.dart';

/// Test doubles for Reflections (F6): an in-memory [ReflectionsApi] and a
/// room host around the reflections section, on top of rooms_fakes.dart.

const String myReflectionId = '0192f0c4-8b5e-7c1a-9d3e-000000000001';
const String cometReflectionId = '0192f0c4-8b5e-7c1a-9d3e-000000000002';
const String riverReflectionId = '0192f0c4-8b5e-7c1a-9d3e-000000000003';

Map<String, dynamic> reflectionJson(
  String id, {
  String memberId = cometId,
  String pseudonym = 'Quiet Comet',
  bool isMine = false,
  String status = 'published',
  String text = 'first Diwali alone in this city',
  int? gestureCount,
  String? rejectReason,
  String? review,
  Duration ago = const Duration(minutes: 10),
}) => {
  'reflectionId': id,
  'status': status,
  'author': {'memberId': memberId, 'pseudonym': pseudonym},
  'isMine': isMine,
  'text': text,
  'createdAt': serverNow.subtract(ago).toIso8601String(),
  'publishedAt': status == 'published'
      ? serverNow.subtract(ago).toIso8601String()
      : null,
  'gestureCount': gestureCount,
  'rejectReason': rejectReason,
  'review': review,
};

Map<String, dynamic> composerJson({
  String state = 'open',
  int remainingInRoom = 3,
  int remainingToday = 10,
  bool slow = false,
}) => {
  'state': state,
  'maxChars': 200,
  'perRoom': 3,
  'remainingInRoom': remainingInRoom,
  'remainingToday': remainingToday,
  'slow': slow,
};

/// What the next `POST …/reflections` answers.
Map<String, dynamic> outcomeJson(
  String id, {
  String status = 'published',
  String? rejectReason,
  String? review,
  bool showSupport = false,
  Map<String, dynamic>? reflection,
  Map<String, dynamic>? composer,
}) => {
  'reflectionId': id,
  'status': status,
  'rejectReason': rejectReason,
  'review': review,
  'showSupport': showSupport,
  'reflection': reflection,
  'composer': composer ?? composerJson(remainingInRoom: 2, remainingToday: 9),
};

/// An in-memory reflections server. Every call is recorded; [fail] makes
/// the next call of a method throw; [outcome] builds the send answer.
class FakeReflectionsApi implements ReflectionsApi {
  FakeReflectionsApi({
    List<Map<String, dynamic>>? reflections,
    Map<String, dynamic>? composer,
  }) : reflections = reflections ?? [],
       composer = composer ?? composerJson();

  List<Map<String, dynamic>> reflections;
  Map<String, dynamic> composer;
  final List<String> calls = [];
  final List<({String reflectionId, String text})> sends = [];

  /// Every send's reflectionId, failed ones included (retries reuse it).
  final List<String> attempts = [];
  final List<String> deletes = [];
  final List<({GestureType type, String reflectionId})> gestures = [];

  /// method name → the error its next call throws.
  final Map<String, ApiException> fail = {};

  /// The answer for a send (default: published, stored).
  Map<String, dynamic> Function(String id, String text)? outcome;

  /// Make sends hang until completed.
  Completer<void>? holdSend;

  int count(String name) => calls.where((c) => c == name).length;

  Future<void> _call(String name) async {
    calls.add(name);
    final e = fail.remove(name);
    if (e != null) throw e;
  }

  @override
  Future<ReflectionList> list(String roomId) async {
    await _call('list');
    return ReflectionList.fromJson({
      'reflections': reflections,
      'composer': composer,
    });
  }

  @override
  Future<Reflection> get(String roomId, String reflectionId) async {
    await _call('get');
    return Reflection.fromJson(
      reflections.firstWhere((r) => r['reflectionId'] == reflectionId),
    );
  }

  @override
  Future<SendOutcome> send(
    String roomId, {
    required String reflectionId,
    required String text,
  }) async {
    calls.add('send');
    attempts.add(reflectionId);
    final h = holdSend;
    if (h != null) await h.future;
    final e = fail.remove('send');
    if (e != null) throw e;
    sends.add((reflectionId: reflectionId, text: text));
    final json =
        outcome?.call(reflectionId, text) ??
        outcomeJson(
          reflectionId,
          reflection: reflectionJson(
            reflectionId,
            memberId: meId,
            pseudonym: 'Soft Harbor',
            isMine: true,
            text: text,
            gestureCount: 0,
            ago: Duration.zero,
          ),
        );
    final stored = json['reflection'];
    if (stored is Map<String, dynamic>) {
      reflections = [stored, ...reflections];
    }
    if (json['composer'] is Map<String, dynamic>) {
      composer = json['composer'] as Map<String, dynamic>;
    }
    return SendOutcome.fromJson(json);
  }

  @override
  Future<void> delete(String roomId, String reflectionId) async {
    await _call('delete');
    deletes.add(reflectionId);
    reflections = [
      for (final r in reflections)
        if (r['reflectionId'] != reflectionId) r,
    ];
  }

  @override
  Future<GestureAck> sendGesture(
    String roomId,
    GestureType type, {
    required String reflectionId,
  }) async {
    await _call('gesture');
    gestures.add((type: type, reflectionId: reflectionId));
    return GestureAck(
      gestureId: 'eeeeeeee-0000-4000-8000-00000000000${gestures.length}',
      at: serverNow,
    );
  }
}

class FixedFlags extends RemoteFlagsNotifier {
  FixedFlags(this.flags);

  final RemoteFlags flags;

  @override
  RemoteFlags build() => flags;
}

List<Override> reflectionsOverrides({
  required AppDatabase db,
  required FakeRoomsApi rooms,
  required FakeReflectionsApi reflections,
  FakeChannels? channels,
  Stream<bool>? connectivity,
  RemoteFlags flags = const RemoteFlags(),
  String locale = 'en',
}) => [
  ...roomsTestOverrides(
    db: db,
    api: rooms,
    channels: channels,
    connectivity: connectivity,
    locale: locale,
  ),
  reflectionsApiProvider.overrideWithValue(reflections),
  remoteFlagsProvider.overrideWith(() => FixedFlags(flags)),
];

/// A phone-sized app showing the reflections section of [roomId] (the room
/// detail as [rooms] serves it).
Future<AppDatabase> pumpReflections(
  WidgetTester tester, {
  required FakeRoomsApi rooms,
  required FakeReflectionsApi reflections,
  FakeChannels? channels,
  Stream<bool>? connectivity,
  RemoteFlags flags = const RemoteFlags(),
  String tag = 'en',
  Widget? home,
  Future<void> Function(AppDatabase db)? seed,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = memoryDb();
  if (seed != null) await tester.runAsync(() => seed(db));
  final locale = localeFromTag(tag);
  await tester.pumpWidget(
    ProviderScope(
      overrides: reflectionsOverrides(
        db: db,
        rooms: rooms,
        reflections: reflections,
        channels: channels,
        connectivity: connectivity,
        flags: flags,
        locale: tag,
      ),
      child: MaterialApp(
        theme: buildAuraTheme(locale),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...systemLocalizationDelegates,
        ],
        home:
            home ??
            Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ReflectionsSection(
                    roomId: roomId,
                    detail: RoomDetail.fromJson(rooms.detail),
                  ),
                ],
              ),
            ),
      ),
    ),
  );
  await settleRooms(tester);
  return db;
}

/// Closes everything (sheets, timers) at the end of a test.
Future<void> closeAll(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}
