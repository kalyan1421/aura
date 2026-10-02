// The seeded "world" the design captures run in: an onboarded, signed-in
// person with ~a year of check-ins across all four quadrants, habits, a
// capsule or two, rooms with members, reflections, keepsakes, Plus state,
// and every network surface faked (the existing test fakes).
import 'dart:io';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/entitlements/entitlement.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/net/aura_api.dart' show ApiException;
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/sync/sync_service.dart' show SyncPhase;
import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/core/remote_config/remote_config_providers.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/account/account_providers.dart';
import 'package:aura/src/features/auth/auth_providers.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/auth/social_sign_in.dart';
import 'package:aura/src/features/avatar/avatar_assets.dart';
import 'package:aura/src/features/capsules/capsule_media_store.dart';
import 'package:aura/src/features/capsules/capsule_repository.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura/src/features/keepsakes/keepsakes_api.dart';
import 'package:aura/src/features/keepsakes/keepsakes_providers.dart';
import 'package:aura/src/features/keepsakes/keepsakes_repository.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/plus/store_gateway.dart';
import 'package:aura/src/features/progress/progress_view.dart';
import 'package:aura/src/features/quiet/quiet_api.dart';
import 'package:aura/src/features/quiet/quiet_models.dart';
import 'package:aura/src/features/quiet/quiet_providers.dart';
import 'package:aura/src/features/reflections/reflections_providers.dart';
import 'package:aura/src/features/ripples/ripple_feedback.dart';
import 'package:aura/src/features/ripples/ripple_models.dart';
import 'package:aura/src/features/ripples/ripples_providers.dart';
import 'package:aura/src/features/rooms/intention_copy.dart';
import 'package:aura/src/features/rooms/room_guidelines.dart';
import 'package:aura/src/features/rooms/room_models.dart'
    show GestureType, ReportReason;
import 'package:aura/src/features/rooms/rooms_providers.dart';
import 'package:aura/src/features/rooms/wind_down_api.dart';
import 'package:aura/src/features/sanctuary/breath_haptics.dart';
import 'package:aura/src/features/sanctuary/breath_pacer.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_backend.dart';
import 'package:aura/src/features/sanctuary/sounds/saved_mixes.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_library.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_screen.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_session_log.dart';
import 'package:aura/src/features/share/share_gateway.dart';
import 'package:aura/src/features/share/share_prompt.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/misc.dart' show Override;

import '../auth_social_fakes.dart' as social;
import '../capsules_fakes.dart' as caps;
import '../helpers.dart';
import '../keepsakes_fakes.dart';
import '../plus_fakes.dart';
import '../reflections_fakes.dart' as refl;
import '../ripples_fakes.dart' as rip;
import '../rooms_fakes.dart' as rooms;
import '../sounds_fakes.dart';
import '../voice_fakes.dart';
import '../widget_fakes.dart';

// ---- small fakes not shared by the suite ---------------------------------------

class QuietHaptics implements BreathHaptics {
  @override
  void phaseStarted(BreathPhase phase) {}
}

class CaptureCues implements QuietCues {
  @override
  void rhythm({required bool toBreak, required bool chime}) {}
  @override
  void breath(BreathPhase phase) {}
  @override
  Future<void> dispose() async {}
}

/// A pinned wall clock for Quiet Together (moved by the capture).
int quietWall = DateTime.utc(2027, 3, 10, 13, 50).millisecondsSinceEpoch;

/// Quiet Together server (as test/quiet_test.dart's).
class CaptureQuietApi implements QuietApi {
  CaptureQuietApi({this.count = 7});

  int count;
  final int t0Ms = DateTime.utc(2027, 3, 10, 13, 30).millisecondsSinceEpoch;
  final String id = 'aaaaaaaa-0000-4000-8000-000000000001';

  QuietSession session() => QuietSession.fromJson({
    'sessionId': id,
    'mode': 'study',
    't0Ms': t0Ms,
    'endsAtMs': t0Ms + 3600000,
    'count': count,
    'soundscape': {
      'seed': 4,
      'stems': [
        {'id': 'brown_noise', 'gain': 0.55},
        {'id': 'chimes', 'gain': 0.2},
      ],
    },
    'rhythm': {'focusMin': 25, 'breakMin': 5},
    'gestures': {'minIntervalMs': 10000, 'perHour': 20},
    'heartbeatMs': 30000,
    'realtime': {'topic': 'quiet:$id'},
    'serverTimeMs': quietWall,
  });

  @override
  Future<QuietSession> join(QuietMode mode, {String? timezone}) async =>
      session();

  /// The next heartbeats fail (a dropped connection).
  ApiException? beatError;

  @override
  Future<QuietSession> heartbeat(String sessionId) async {
    final e = beatError;
    if (e != null) throw e;
    return session();
  }

  @override
  Future<void> leave(String sessionId) async {}

  @override
  Future<String> gesture(String sessionId, GestureType type) async => 'g-1';

  @override
  Future<bool> report(
    String sessionId,
    ReportReason reason, {
    String? note,
  }) async => false;
}

/// Lantern Hour wind-down server (as test/rooms_wind_down_test.dart's).
class CaptureWindDownApi implements WindDownApi {
  CaptureWindDownApi(this.view);

  WindDownView? view;

  @override
  Future<WindDownReply> get(String roomId) async =>
      WindDownReply(view, DateTime.now().millisecondsSinceEpoch);

  @override
  Future<WindDownReply> join(String roomId) async {
    view = view?.copyWith(joined: true, count: (view?.count ?? 0) + 1);
    return WindDownReply(view, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<void> leave(String roomId) async {}
}

WindDownView openWindDown({int count = 4}) {
  final t0 = DateTime.now().millisecondsSinceEpoch - 60000;
  return WindDownView(
    state: 'open',
    startsAtMs: t0,
    endsAtMs: t0 + 20 * 60000,
    count: count,
    joined: false,
    stems: const ['rain', 'wind', 'chimes'],
    cues: const [
      WindDownCue(0, 'arrive'),
      WindDownCue(120, 'day_quieter'),
      WindDownCue(330, 'shoulders'),
    ],
  );
}

/// Home's milestone share prompt, off unless a capture asks for it.
class NoSharePrompt extends SharePromptController {
  @override
  Future<void> show(SharePromptResult r) async {}
}

class CaptureFlags extends RemoteFlagsNotifier {
  CaptureFlags(this.flags);
  final RemoteFlags flags;
  @override
  RemoteFlags build() => flags;
}

// ---- room data -----------------------------------------------------------------

const String stormRoomId = '22222222-2222-4222-8222-222222222222';
const String memoryRoomId = '33333333-3333-4333-8333-333333333333';
const String dawnId = 'aaaaaaaa-0000-4000-8000-000000000004';
const String fernId = 'aaaaaaaa-0000-4000-8000-000000000005';

Map<String, dynamic> roomSummary(
  String id, {
  String quadrant = 'rain',
  String state = 'open',
  int hereNow = 5,
  int today = 18,
  String pseudonym = 'Soft Harbor',
}) => {
  'room': rooms.roomInfoJson(id: id, quadrant: quadrant, state: state),
  'me': {
    'memberId': rooms.meId,
    'pseudonym': pseudonym,
    'moodChip': 'lonely',
    'joinedAt': rooms.serverNow.toIso8601String(),
  },
  'counts': {'hereNow': hereNow, 'today': today},
};

/// A rain room in Lantern Hour: five people, lantern 3 of 5, tonight's
/// intention, a gesture received and a few recent ones.
Map<String, dynamic> litRoomDetail({
  int level = 3,
  String state = 'lantern_hour',
  bool holding = false,
}) {
  final now = rooms.serverNow;
  final d = rooms.detailJson(
    state: state,
    lantern: state == 'lantern_hour',
    hereNow: 5,
    today: 23,
    members: [
      rooms.memberJson(rooms.meId, 'Soft Harbor', isMe: true, stage: 'glow'),
      rooms.memberJson(rooms.cometId, 'Quiet Comet', mood: 'drained', hue: 260),
      rooms.memberJson(
        rooms.riverId,
        'Silver River',
        mood: 'numb',
        live: false,
        hue: 190,
      ),
      rooms.memberJson(
        dawnId,
        'Gentle Dawn',
        mood: 'lonely',
        stage: 'radiance',
        hue: 30,
      ),
      rooms.memberJson(
        fernId,
        'Still Fern',
        mood: 'melancholy',
        stage: 'ember',
        hue: 140,
      ),
    ],
    received: [
      {
        'gestureId': 'g1',
        'type': 'warm_tea',
        'fromMemberId': rooms.cometId,
        'fromPseudonym': 'Quiet Comet',
        'at': now.subtract(const Duration(minutes: 4)).toIso8601String(),
      },
    ],
    recent: [
      {
        'gestureId': 'g2',
        'type': 'hug',
        'at': now.subtract(const Duration(minutes: 2)).toIso8601String(),
      },
      {
        'gestureId': 'g3',
        'type': 'light_a_candle',
        'at': now.subtract(const Duration(minutes: 6)).toIso8601String(),
      },
      {
        'gestureId': 'g4',
        'type': 'youre_not_alone',
        'at': now.subtract(const Duration(minutes: 9)).toIso8601String(),
      },
    ],
  );
  final room = d['room'] as Map<String, dynamic>;
  room['lantern'] = {
    'level': level,
    'maxLevel': 5,
    'active': state == 'lantern_hour',
  };
  room['intention'] = {
    'key': 'gentle_with_myself',
    'holds': 12,
    'open': state == 'lantern_hour',
  };
  (d['me'] as Map<String, dynamic>)['holdingIntention'] = holding;
  return d;
}

List<Map<String, dynamic>> roomReflections() => [
  refl.reflectionJson(
    refl.myReflectionId,
    memberId: rooms.meId,
    pseudonym: 'Soft Harbor',
    isMine: true,
    status: 'pending',
    text: 'The rain on the tin roof tonight sounds like home used to.',
    ago: const Duration(minutes: 1),
  ),
  refl.reflectionJson(
    refl.cometReflectionId,
    text: 'first Diwali alone in this city. the lights still look kind.',
    gestureCount: 4,
    ago: const Duration(minutes: 12),
  ),
  refl.reflectionJson(
    refl.riverReflectionId,
    memberId: rooms.riverId,
    pseudonym: 'Silver River',
    text: 'Made tea for two out of habit. Drank both.',
    gestureCount: 2,
    ago: const Duration(minutes: 40),
  ),
  refl.reflectionJson(
    '0192f0c4-8b5e-7c1a-9d3e-000000000004',
    memberId: rooms.meId,
    pseudonym: 'Soft Harbor',
    isMine: true,
    status: 'held',
    text: 'Some days I just want someone to ask how I am.',
    review: 'held',
    ago: const Duration(hours: 1),
  ),
];

// ---- the world -------------------------------------------------------------------

class World {
  World({
    this.locale = 'en',
    this.gate = const GateState(stage: OnboardingStage.done),
    Entitlement? entitlement,
    this.progress,
    this.flags = const RemoteFlags(),
    this.assets,
    this.signedIn = true,
    this.keepsakeList,
    this.sharePrompt = false,
    this.authRepo,
    this.plusEnabled = true,
  }) : entitlement = entitlement ?? freeAccount();

  /// The `plus_enabled` remote flag (the design captures show Plus on; the
  /// store screenshots show v1.0 as it ships: off).
  final bool plusEnabled;

  final String locale;
  final GateState gate;
  final Entitlement entitlement;

  /// A fixed Home progress view (null: the app computes its own).
  final ProgressView? progress;
  final RemoteFlags flags;
  final AvatarAssets? assets;
  final bool signedIn;
  final List<OwnKeepsake>? keepsakeList;

  /// Replaces the signed-in account (e.g. a signed-out social sign-in).
  final AuthRepository? authRepo;

  /// Let Home offer its milestone share card.
  final bool sharePrompt;

  /// Sync is done (Home's cloud icon reads "all saved").
  late final FakeSync sync = () {
    final s = FakeSync();
    (s.phase as ValueNotifier<SyncPhase>).value = SyncPhase.idle;
    return s;
  }();

  final AppDatabase db = memoryDb();
  final time = testTime();

  late final roomsApi = rooms.FakeRoomsApi(detail: litRoomDetail())
    ..rooms_ = [
      roomSummary(rooms.roomId, hereNow: 5),
      roomSummary(
        stormRoomId,
        quadrant: 'storm',
        hereNow: 3,
        pseudonym: 'Brave Tide',
      ),
      roomSummary(
        memoryRoomId,
        quadrant: 'moonlight',
        state: 'memory',
        hereNow: 0,
        pseudonym: 'Night Lark',
      ),
    ];
  final roomChannels = rooms.FakeChannels();
  late final reflections = refl.FakeReflectionsApi(
    reflections: roomReflections(),
  );
  final quiet = CaptureQuietApi();
  final quietChannels = rip.FakeChannels();
  late final ripples = rip.FakeRipplesApi(current: rip.fakeSession(cycles: 4));
  final rippleChannels = rip.FakeChannels();
  WindDownView? windDownView;
  late final windDown = CaptureWindDownApi(windDownView);
  final sounds = FakeSoundsBackend();
  final stems = FakeStemStore();
  final share = FakeShareGateway();
  late final keepsakes = FakeKeepsakesApi(
    keepsakeList ??
        [
          keep('capsule_sealed_first', '2026-08-14'),
          keep('glow_days_7', '2026-08-20'),
          keep('glow_days_30', '2026-09-18'),
          keep('ripples_first', '2026-09-02'),
          keep('lantern_hours_1', '2026-09-05'),
          keep('sanctuary_minutes_60', '2026-09-26'),
        ],
  );
  late final auth = caps.SignedInAuth()..user = signedIn ? _user : null;
  static const _user = AuthUser(
    id: caps.capsuleTestUser,
    email: 'ak@aura.test',
  );
  late final Directory capsuleRoot = Directory.systemTemp.createTempSync(
    'aura-capture-capsules',
  );
  late final CapsuleMediaStore capsuleStore = caps.tempCapsuleStore(
    capsuleRoot,
  );
  final widgetHost = MemoryWidgetHost();
  final List<Override> extra = [];

  List<Override> overrides() => [
    ...testOverrides(
      db: db,
      secure: caps.secureWithKey(),
      gate: gate,
      locale: locale,
      assets: assets,
      time: time,
      auth: authRepo ?? auth,
      widgetHost: widgetHost,
      sync: sync,
    ),
    if (!sharePrompt) sharePromptProvider.overrideWith(NoSharePrompt.new),
    if (progress != null) progressViewProvider.overrideWithValue(progress!),
    deviceRegionProvider.overrideWithValue('IN'),
    remoteFlagsProvider.overrideWith(() => CaptureFlags(flags)),
    // Rooms (F5) and reflections (F6).
    roomsApiProvider.overrideWithValue(roomsApi),
    roomChannelOpenerProvider.overrideWithValue(roomChannels.open),
    intentionCopyLoaderProvider.overrideWithValue(() async => const {}),
    reflectionsApiProvider.overrideWithValue(reflections),
    // Quiet Together (F16), wind-down, Breath Ripples (F7).
    quietApiProvider.overrideWithValue(quiet),
    quietChannelOpenerProvider.overrideWithValue(quietChannels.open),
    quietCuesProvider.overrideWithValue(CaptureCues()),
    windDownApiProvider.overrideWithValue(windDown),
    ripplesApiProvider.overrideWithValue(ripples),
    rippleChannelOpenerProvider.overrideWithValue(rippleChannels.open),
    rippleFeedbackProvider.overrideWithValue(rip.FakeRippleFeedback()),
    // Sanctuary.
    breathHapticsProvider.overrideWithValue(QuietHaptics()),
    soundsBackendProvider.overrideWithValue(sounds),
    stemStoreProvider.overrideWithValue(stems),
    soundsSessionLogProvider.overrideWithValue(RecordingSessionLog()),
    savedMixesProvider.overrideWith(MemorySavedMixes.new),
    soundsOnlineProvider.overrideWithValue(true),
    // Keepsakes and share cards (F13).
    keepsakesApiProvider.overrideWithValue(keepsakes),
    shareGatewayProvider.overrideWithValue(share),
    // Plus (F12).
    ...plusOverrides(
      entitlement: entitlement,
      api: FakeBillingApi(current: entitlement),
      store: FakeStore(platform: StorePlatform.apple),
      plusEnabled: plusEnabled,
    ),
    // Capsules (F4) and voice notes (F1).
    ...caps.capsuleOverrides(store: capsuleStore),
    ...voiceOverrides(recorder: FakeRecorder(granted: true)),
    // Account and sign-in.
    accountRepositoryProvider.overrideWithValue(social.FakeAccount()),
    ...extra,
  ];

  // ---- seeding ------------------------------------------------------------------

  int _seq = 0;

  /// Today's check-in (after [seedHistory] with a mood for today).
  String? todayId;

  Future<String> addCheckIn(
    String day,
    String moodId, {
    int hour = 13,
    int minute = 0,
    List<String> tags = const [],
    String? note,
  }) async {
    final d = LocalDay.parse(day);
    // [hour]:[minute] IST.
    final at = DateTime.utc(
      d.year,
      d.month,
      d.day,
      hour,
      minute,
    ).subtract(const Duration(hours: 5, minutes: 30));
    final id =
        '0190a000-0000-7000-8000-${(_seq++).toString().padLeft(12, '0')}';
    await db
        .into(db.checkIns)
        .insert(
          CheckInsCompanion.insert(
            id: id,
            moodId: moodId,
            quadrant: moodById(moodId)!.quadrant.name,
            tags: Value(tags),
            note: Value(note),
            localDay: day,
            deviceTs: at,
            tzOffsetMinutes: 330,
            tz: const Value('Asia/Kolkata'),
            synced: const Value(true),
          ),
        );
    return id;
  }

  /// ~A year of check-ins (sparser further back), every quadrant, some
  /// tags and notes; nothing today unless [today] is given.
  Future<void> seedHistory({String? todayMood, bool heavyWeek = false}) async {
    const pattern = [
      'calm',
      'content',
      'drained',
      'anxious',
      'grateful',
      'quietly_hopeful',
      'lonely',
      'joyful',
      'melancholy',
      'proud',
      'overwhelmed',
      'energised',
      'numb',
      'excited',
      'restless',
      'calm',
      'frustrated',
    ];
    const notes = [
      'Long day at the lab. The chai after helped.',
      'Talked to Amma for an hour. Felt lighter.',
      'Could not sleep, kept thinking about the exam.',
      null,
      'Walked by the lake with Ravi. Quiet and good.',
      null,
      null,
    ];
    final today = time.today();
    var n = 0;
    for (var back = 365; back >= 1; back--) {
      final day = today.addDays(-back);
      // Sparse a year ago, daily in the last two months.
      final every = back > 60 ? (back > 180 ? 4 : 2) : 1;
      if (back % every != 0) continue;
      final per = back <= 21 && back % 3 == 0 ? 2 : 1;
      for (var k = 0; k < per; k++) {
        var mood = pattern[(n * 7 + k * 3) % pattern.length];
        if (heavyWeek && back <= 13) {
          mood = k.isEven ? 'drained' : 'anxious';
        }
        await addCheckIn(
          day.toIso(),
          mood,
          hour: k == 0 ? 9 : 21,
          minute: (n * 13) % 60,
          tags: [
            contextTags[n % contextTags.length],
            if (n % 3 == 0) contextTags[(n + 4) % contextTags.length],
          ],
          note: back <= 30 ? notes[n % notes.length] : null,
        );
        n++;
      }
    }
    if (todayMood != null) {
      todayId = await addCheckIn(
        today.toIso(),
        todayMood,
        hour: 10,
        minute: 12,
        tags: const ['study', 'friends'],
        note:
            'Presentation went better than I feared. Treated myself to '
            'jalebi on the way back.',
      );
    }
  }

  /// Habits: the presets plus two custom ones; some done today.
  Future<void> seedHabits({bool doneToday = true}) async {
    final habits = HabitRepository(
      db,
      OutboxRepository(db, const Ids()),
      time,
      const Ids(),
    );
    await habits.addCustom('Stretch');
    await habits.addCustom('Read 10 pages');
    if (doneToday) {
      await habits.toggleToday('water');
      await habits.toggleToday('move');
    }
  }

  CapsuleRepository capsules([DateTime? at]) => CapsuleRepository(
    db,
    OutboxRepository(db, const Ids()),
    TimeContext(clock: FixedClock(at ?? testNow), timezone: 'Asia/Kolkata'),
    store: capsuleStore,
    cipher: () async => caps.testCipher(),
  );

  Future<void> seedCapsules({bool dueToday = false}) async {
    await capsules(DateTime.utc(2026, 8, 14)).seal(
      id: 'cap-date',
      content: const CapsuleContent(
        title: 'For exam-day me',
        text: 'You studied more than you think. Breathe, then begin.',
      ),
      unlock: DateUnlock(LocalDay.parse('2027-03-12')),
    );
    await capsules(DateTime.utc(2026, 9, 2)).seal(
      id: 'cap-storm',
      content: const CapsuleContent(
        title: 'When it gets loud',
        text: 'This has passed before. Call Priya. Drink water.',
      ),
      unlock: const MoodUnlock.quadrant(Quadrant.storm),
    );
    if (dueToday) {
      await capsules(DateTime.utc(2025, 10, 8)).seal(
        id: 'cap-due',
        content: const CapsuleContent(
          title: 'One year ago',
          text:
              'Hi. A year ago you were scared of moving cities. Look at you '
              'now: you made a whole life here. Be proud, and be gentle.',
        ),
        unlock: DateUnlock(LocalDay.parse('2026-10-08')),
      );
    }
  }

  /// Keepsakes already in the cache and marked seen (so Home shows no card),
  /// unless [unseen] is given.
  Future<void> seedKeepsakes({String? unseen}) async {
    final kv = KvStore(db);
    await kv.setJson(KeepsakeKv.seen, {
      'keys': [
        for (final k in keepsakes.list)
          if (k.key != unseen) k.key,
      ],
    });
  }

  /// Room guidelines accepted (so joins go straight to matching).
  Future<void> acceptGuidelines() =>
      db.setValue(roomGuidelinesKey, '$roomGuidelinesVersion');
}

/// A loaded Home progress view.
ProgressView homeProgress({
  bool checkedIn = true,
  AuraStage stage = AuraStage.glow,
  int total = 640,
  int streak = 11,
  double hue = 210,
}) => ProgressView(
  loaded: true,
  today: const LocalDay(2026, 10, 8),
  avatar: AuraAvatarState(
    stage: stage,
    hue: hue,
    ringCount: 2,
    glowLevel: checkedIn ? 2 : 1,
    equippedCosmetics: const {'first_light'},
  ),
  todayStarlight: checkedIn ? 25 : 0,
  totalStarlight: total,
  streak: StreakState(
    glowStreak: streak,
    lifetimeGlowDays: 48,
    restBank: 2,
    lastActiveDay: checkedIn
        ? const LocalDay(2026, 10, 8)
        : const LocalDay(2026, 10, 7),
  ),
  glow: checkedIn ? GlowStatus.activeToday : GlowStatus.continuing,
  provisional: false,
  hasActivity: true,
  awards: const {},
  localHue: null,
);

/// A brand-new person (nothing yet).
ProgressView newUserProgress() => ProgressView(
  loaded: true,
  today: const LocalDay(2026, 10, 8),
  avatar: AuraAvatarState(),
  todayStarlight: 0,
  totalStarlight: 0,
  streak: StreakState.initial,
  glow: GlowStatus.fresh,
  provisional: false,
  hasActivity: false,
  awards: const {},
  localHue: null,
);

/// Plus in its last two days of trial, with the trial-ending notice.
Entitlement trialEnding() => plusAccount(
  store: PlusStore.apple,
  until: testNow.add(const Duration(hours: 40)),
  notices: [
    PlusNotice(
      kind: PlusNoticeKind.trialEnding,
      key: 's:trial_ending',
      date: testNow.add(const Duration(hours: 40)),
      price: '₹49.00',
    ),
  ],
);

/// Social sign-in configured (Google), signed out.
List<Override> socialOverrides(social.FakeSocialAuth auth) => [
  socialSignInProvider.overrideWithValue(
    SocialSignInService(
      config: social.iosSocial,
      exchange: auth,
      google: social.FakeGoogle(),
    ),
  ),
  ageSignalSourceProvider.overrideWithValue(social.FakeAgeSource()),
];

/// The Ripples session starts now (the lobby's poll matches at once).
RippleSession rippleSession() => rip.fakeSession(cycles: 4);
