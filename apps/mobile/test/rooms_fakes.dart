import 'dart:async';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/avatar/avatar_assets.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/rooms/room_models.dart';
import 'package:aura/src/features/rooms/room_realtime.dart';
import 'package:aura/src/features/rooms/rooms_api.dart';
import 'package:aura/src/features/rooms/rooms_providers.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Test doubles for Mood Rooms (F5): an in-memory [RoomsApi], private
/// Realtime channels driven by hand, and a signed-in account.

const String roomId = '11111111-1111-4111-8111-111111111111';
const String meId = 'aaaaaaaa-0000-4000-8000-000000000001';
const String cometId = 'aaaaaaaa-0000-4000-8000-000000000002';
const String riverId = 'aaaaaaaa-0000-4000-8000-000000000003';

/// Server time in these tests: [testNow] (15:30 IST).
final DateTime serverNow = testNow;

Map<String, dynamic> lanternJson({bool active = false, DateTime? endsAt}) => {
  'timezone': 'Asia/Kolkata',
  'active': active,
  'startsAt': (active
          ? serverNow.subtract(const Duration(minutes: 30))
          : serverNow.add(const Duration(hours: 5)))
      .toIso8601String(),
  'endsAt': (endsAt ?? serverNow.add(const Duration(hours: 7)))
      .toIso8601String(),
};

Map<String, dynamic> roomInfoJson({
  String id = roomId,
  String quadrant = 'rain',
  String state = 'open',
  bool lantern = false,
  DateTime? lanternEnds,
  DateTime? createdAt,
}) {
  final created = createdAt ?? serverNow.subtract(const Duration(hours: 2));
  final theme = switch (quadrant) {
    'storm' => 'lighthouse',
    'rain' => 'rain_sanctuary',
    'moonlight' => 'midnight_observatory',
    _ => 'sunrise_deck',
  };
  return {
    'roomId': id,
    'quadrant': quadrant,
    'theme': theme,
    'state': state,
    'readOnly': state == 'memory',
    'createdAt': created.toIso8601String(),
    'joinsCloseAt': created.add(const Duration(hours: 20)).toIso8601String(),
    'memoryAt': created.add(const Duration(hours: 24)).toIso8601String(),
    'purgeAt': created.add(const Duration(days: 8)).toIso8601String(),
    'lanternHour': lanternJson(active: lantern, endsAt: lanternEnds),
  };
}

Map<String, dynamic> memberJson(
  String id,
  String pseudonym, {
  String mood = 'lonely',
  String stage = 'glow',
  int? hue = 210,
  bool live = true,
  bool muted = false,
  bool isMe = false,
}) => {
  'memberId': id,
  'pseudonym': pseudonym,
  'silhouette': {'stage': stage, 'hue': hue, 'cosmetic': null},
  'moodChip': mood,
  'live': live,
  'muted': muted,
  'isMe': isMe,
};

/// A room detail as the server sends it: you ("Soft Harbor") and, unless
/// [alone], "Quiet Comet" and "Silver River".
Map<String, dynamic> detailJson({
  String id = roomId,
  String quadrant = 'rain',
  String state = 'open',
  int hereNow = 3,
  int today = 18,
  bool alone = false,
  bool lantern = false,
  DateTime? lanternEnds,
  bool surveyEligible = false,
  DateTime? joinedAt,
  List<Map<String, dynamic>>? members,
  List<Map<String, dynamic>> received = const [],
  List<Map<String, dynamic>> sent = const [],
  List<Map<String, dynamic>> recent = const [],
}) => {
  'room': roomInfoJson(
    id: id,
    quadrant: quadrant,
    state: state,
    lantern: lantern,
    lanternEnds: lanternEnds,
  ),
  'me': {
    'memberId': meId,
    'pseudonym': 'Soft Harbor',
    'moodChip': 'lonely',
    'silhouette': {'stage': 'ember', 'hue': 180, 'cosmetic': null},
    'joinedAt': (joinedAt ?? serverNow.subtract(const Duration(minutes: 5)))
        .toIso8601String(),
    'surveyEligible': surveyEligible,
  },
  'counts': {'hereNow': hereNow, 'today': today},
  'members':
      members ??
      [
        memberJson(meId, 'Soft Harbor', mood: 'lonely', isMe: true),
        if (!alone) ...[
          memberJson(cometId, 'Quiet Comet', mood: 'drained'),
          memberJson(riverId, 'Silver River', mood: 'numb', live: false),
        ],
      ],
  'gestures': {'received': received, 'sent': sent, 'recent': recent},
  'realtime': {'roomTopic': 'room:$id', 'memberTopic': 'member:$meId'},
};

/// An in-memory rooms server. Every call is recorded; [fail] makes the
/// next call of a method throw.
class FakeRoomsApi implements RoomsApi {
  FakeRoomsApi({Map<String, dynamic>? detail})
    : detail = detail ?? detailJson();

  Map<String, dynamic> detail;
  List<Map<String, dynamic>> rooms_ = [];
  final List<String> calls = [];
  final List<MatchRequest> matches = [];
  final List<({GestureType type, String? to})> gestures = [];
  final List<({ReportTarget target, ReportReason reason, String? note})>
  reports = [];
  final List<({String member, bool muted})> mutes = [];
  final List<String> blocks = [];
  final List<SurveyAnswer> surveys = [];

  /// method name → the error its next call throws.
  final Map<String, ApiException> fail = {};

  /// Make a call hang until completed (e.g. a slow match).
  Completer<void>? hold;

  bool showHelplines = false;
  bool leaveSurveyEligible = true;
  int _gestureIds = 0;

  Future<void> _call(String name) async {
    calls.add(name);
    final h = hold;
    if (h != null) await h.future;
    final e = fail.remove(name);
    if (e != null) throw e;
  }

  int count(String name) => calls.where((c) => c == name).length;

  @override
  Future<MatchResult> match(MatchRequest request) async {
    matches.add(request);
    await _call('match');
    return MatchResult.fromJson({
      ...detail,
      'match': {'step': 2, 'reentry': false, 'created': false, 'merged': false},
    });
  }

  @override
  Future<List<RoomSummary>> rooms() async {
    await _call('rooms');
    return [for (final r in rooms_) RoomSummary.fromJson(r)];
  }

  @override
  Future<RoomDetail> room(String roomId) async {
    await _call('room');
    return RoomDetail.fromJson(detail);
  }

  @override
  Future<HeartbeatResult> heartbeat(String roomId) async {
    await _call('heartbeat');
    return HeartbeatResult.fromJson({
      'room': detail['room'],
      'counts': detail['counts'],
    });
  }

  @override
  Future<GestureAck> sendGesture(
    String roomId,
    GestureType type, {
    String? toMemberId,
  }) async {
    await _call('gesture');
    gestures.add((type: type, to: toMemberId));
    // Delivered or silently dropped: the same 202 either way.
    return GestureAck(
      gestureId: 'bbbbbbbb-0000-4000-8000-${(++_gestureIds).toString().padLeft(12, '0')}',
      at: serverNow,
    );
  }

  @override
  Future<bool> leave(String roomId) async {
    await _call('leave');
    return leaveSurveyEligible;
  }

  @override
  Future<void> survey(String roomId, SurveyAnswer answer) async {
    await _call('survey');
    surveys.add(answer);
  }

  @override
  Future<void> mute(String roomId, String memberId) async {
    await _call('mute');
    mutes.add((member: memberId, muted: true));
  }

  @override
  Future<void> unmute(String roomId, String memberId) async {
    await _call('unmute');
    mutes.add((member: memberId, muted: false));
  }

  @override
  Future<ReportAck> report(
    ReportTarget target,
    ReportReason reason, {
    String? note,
  }) async {
    await _call('report');
    reports.add((target: target, reason: reason, note: note));
    return ReportAck(
      reportId: 'cccccccc-0000-4000-8000-000000000001',
      showHelplines: reason == ReportReason.inDanger || showHelplines,
    );
  }

  @override
  Future<String> block(String roomId, String memberId) async {
    await _call('block');
    blocks.add(memberId);
    return 'dddddddd-0000-4000-8000-000000000001';
  }

  @override
  Future<SafetyStanding> standing() async {
    await _call('standing');
    return const SafetyStanding(rooms: 'suspended');
  }
}

/// A private Broadcast channel driven by the test.
class FakeChannel implements RoomChannel {
  FakeChannel(this.topic);

  final String topic;
  void Function(String event, Map<String, dynamic> payload)? _onEvent;
  void Function(RoomChannelStatus status)? _onStatus;
  bool subscribed = false;
  bool closed = false;

  @override
  void onEvent(void Function(String event, Map<String, dynamic> payload) cb) =>
      _onEvent = cb;

  @override
  void subscribe(void Function(RoomChannelStatus status) onStatus) {
    subscribed = true;
    _onStatus = onStatus;
  }

  @override
  Future<void> close() async => closed = true;

  void status(RoomChannelStatus s) => _onStatus?.call(s);

  void emit(String event, Map<String, dynamic> payload) =>
      _onEvent?.call(event, payload);
}

/// Opens [FakeChannel]s; joins them at once unless [autoJoin] is off.
class FakeChannels {
  final List<FakeChannel> opened = [];
  bool autoJoin = true;

  Future<RoomChannel> open(String topic) async {
    final c = FakeChannel(topic);
    opened.add(c);
    if (autoJoin) {
      scheduleMicrotask(() {
        if (!c.closed) c.status(RoomChannelStatus.subscribed);
      });
    }
    return c;
  }

  /// The newest open channel for [topic].
  FakeChannel latest(String topic) =>
      opened.lastWhere((c) => c.topic == topic && !c.closed);

  FakeChannel get room => latest('room:$roomId');
  FakeChannel get member => latest('member:$meId');

  int get live => opened.where((c) => !c.closed).length;
}

class SignedInAuth implements AuthRepository {
  const SignedInAuth();

  static const _user = AuthUser(id: 'account-u1');

  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => _user;
  @override
  Stream<AuthUser?> watchUser() => Stream.value(_user);
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<void> sendEmailCode(String email) async {}
  @override
  Future<void> verifyEmailCode(String email, String code) async {}
  @override
  Future<void> signOut() async {}
}

/// The app's test overrides (helpers.dart `testOverrides`) for a
/// signed-in, onboarded person, with [api], [channels] and a connectivity
/// [connectivity] stream the test can drive (default: online).
List<Override> roomsTestOverrides({
  required AppDatabase db,
  required FakeRoomsApi api,
  FakeChannels? channels,
  Stream<bool>? connectivity,
  AuthRepository auth = const SignedInAuth(),
  GateState gate = const GateState(stage: OnboardingStage.done),
  String locale = 'en',
  TimeContext? time,
}) {
  final t = time ?? testTime();
  return [
    appDatabaseProvider.overrideWithValue(db),
    secureStoreProvider.overrideWithValue(MemorySecureStore()),
    timeContextProvider.overrideWithValue(t),
    initialTimezoneProvider.overrideWithValue(t.timezone),
    timezoneResolverProvider.overrideWithValue(() async => t.timezone),
    authRepositoryProvider.overrideWithValue(auth),
    syncControllerProvider.overrideWithValue(FakeSync()),
    connectivityProvider.overrideWith(
      (ref) => connectivity ?? Stream.value(true),
    ),
    nowProvider.overrideWith((ref) => Stream.value(t.now())),
    avatarAssetsProvider.overrideWith((ref) async => emptyAssets()),
    initialGateProvider.overrideWithValue(gate),
    initialLocaleTagProvider.overrideWithValue(locale),
    roomsApiProvider.overrideWithValue(api),
    roomChannelOpenerProvider.overrideWithValue(channels?.open),
  ];
}

/// Everything a screen-reader announcement said during a test.
List<String> captureAnnouncements(WidgetTester tester) {
  final said = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        final data = message['data'];
        if (data is Map && data['message'] is String) {
          said.add(data['message'] as String);
        }
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return said;
}

/// A Quadrant for a quick match request.
const Quadrant rain = Quadrant.rain;
