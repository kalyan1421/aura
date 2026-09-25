import 'package:aura/src/core/entitlements/plus.dart';
import 'package:aura/src/core/net/aura_api.dart' show ApiException;
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/features/quiet/quiet_api.dart';
import 'package:aura/src/features/quiet/quiet_models.dart';
import 'package:aura/src/features/quiet/quiet_providers.dart';
import 'package:aura/src/features/quiet/quiet_screen.dart';
import 'package:aura/src/features/ripples/ripple_channel.dart';
import 'package:aura/src/features/rooms/room_models.dart'
    show GestureType, ReportReason;
import 'package:aura/src/features/sanctuary/breath_pacer.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_backend.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_controller.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_library.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_session_log.dart';
import 'package:aura/src/features/sanctuary/sounds/wind_down.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'ripples_fakes.dart' as rf;
import 'rooms_fakes.dart';
import 'sounds_fakes.dart';

/// F16 Quiet Together on the phone (PRD 06b F16; 14-states "Quiet Together
/// (F16)"; contracts/api/v1-quiet.md): join and the count, leaving (costs
/// nothing), the optional 25/5 rhythm, unnamed gestures, Reduce Motion, the
/// shared sound played locally from `t0` (REQ-QUIET-03), and a disconnect
/// that never shows a failure. Time is the test clock plus a pinned wall.

/// The shared sound records where each layer starts (the backend seeks to
/// `seed mod length`).
class SeedBackend extends FakeSoundsBackend {
  final List<int> seeds = [];

  @override
  Future<SoundsLayer> openLayer(String path, {required int seed}) {
    seeds.add(seed);
    return super.openLayer(path, seed: seed);
  }
}

class FakeCues implements QuietCues {
  final List<bool> toBreaks = [];
  final List<bool> chimes = [];
  final List<BreathPhase> breaths = [];

  @override
  void rhythm({required bool toBreak, required bool chime}) {
    toBreaks.add(toBreak);
    chimes.add(chime);
  }

  @override
  void breath(BreathPhase phase) => breaths.add(phase);

  @override
  Future<void> dispose() async {}
}

/// A pinned wall clock the tests move with the test clock.
int wall = DateTime.utc(2027, 3, 10, 13, 50).millisecondsSinceEpoch;

class FakeQuietApi implements QuietApi {
  FakeQuietApi({this.count = 3, int? t0Ms, this.rhythm = true})
    : t0Ms = t0Ms ?? DateTime.utc(2027, 3, 10, 13, 30).millisecondsSinceEpoch;

  int count;
  int t0Ms;
  bool rhythm;
  String id = 'aaaaaaaa-0000-4000-8000-000000000001';
  final List<String> calls = [];
  final List<GestureType> gestures = [];
  final List<ReportReason> reports = [];
  ApiException? joinError;
  ApiException? beatError;

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
    'rhythm': rhythm ? {'focusMin': 25, 'breakMin': 5} : null,
    'gestures': {'minIntervalMs': 10000, 'perHour': 20},
    'heartbeatMs': 30000,
    'realtime': {'topic': 'quiet:$id'},
    'serverTimeMs': wall,
  });

  @override
  Future<QuietSession> join(QuietMode mode, {String? timezone}) async {
    calls.add('join:${mode.wire}');
    final e = joinError;
    if (e != null) throw e;
    return session();
  }

  @override
  Future<QuietSession> heartbeat(String sessionId) async {
    calls.add('heartbeat');
    final e = beatError;
    if (e != null) throw e;
    return session();
  }

  @override
  Future<void> leave(String sessionId) async => calls.add('leave');

  @override
  Future<String> gesture(String sessionId, GestureType type) async {
    gestures.add(type);
    return 'g-${gestures.length}';
  }

  @override
  Future<bool> report(
    String sessionId,
    ReportReason reason, {
    String? note,
  }) async {
    reports.add(reason);
    return reason == ReportReason.inDanger;
  }
}

void main() {
  late FakeQuietApi api;
  late rf.FakeChannels channels;
  late SeedBackend backend;
  late RecordingSessionLog log;
  late FakeCues cues;

  Future<void> open(
    WidgetTester tester, {
    FakeQuietApi? quietApi,
    bool online = true,
    bool reduceMotion = false,
  }) async {
    wall = DateTime.utc(2027, 3, 10, 13, 50).millisecondsSinceEpoch;
    api = quietApi ?? FakeQuietApi();
    channels = rf.FakeChannels();
    backend = SeedBackend();
    log = RecordingSessionLog();
    cues = FakeCues();
    await pumpRooms(
      tester,
      QuietScreen(
        mode: QuietMode.study,
        wallMs: () => wall,
        isOnline: () => online,
      ),
      api: FakeRoomsApi(),
      reduceMotion: reduceMotion,
      size: const Size(390, 1600),
      extra: [
        quietApiProvider.overrideWithValue(api),
        quietChannelOpenerProvider.overrideWithValue(channels.open),
        quietCuesProvider.overrideWithValue(cues),
        soundsBackendProvider.overrideWithValue(backend),
        stemStoreProvider.overrideWithValue(FakeStemStore()),
        soundsSessionLogProvider.overrideWithValue(log),
        plusActiveProvider.overrideWithValue(false),
      ],
    );
  }

  Future<void> advance(WidgetTester tester, Duration d) async {
    var left = d;
    const step = Duration(milliseconds: 500);
    while (left > Duration.zero) {
      final s = left < step ? left : step;
      wall += s.inMilliseconds;
      await tester.pump(s);
      left -= s;
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('REQ-QUIET-01: drops in and shows the count only (no names, '
      'no list); "Just you" when alone', (tester) async {
    await open(tester);
    expect(api.calls, ['join:study']);
    expect(find.text('3 here'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiet-just-you')), findsNothing);
    expect(channels.last.topic, 'quiet:${api.id}');
    // A count arrives on the channel.
    channels.last.deliver('count', {'count': 1, 'at': 'x'});
    await tester.pump();
    expect(find.text('1 here'), findsOneWidget);
    expect(
      find.text('Just you right now. Others drop in through the hour.'),
      findsOneWidget,
    );
    // No text input anywhere.
    expect(find.byType(TextField), findsNothing);
    // "I need help now" is in the top bar the whole session (the pill, or
    // the heart when the wide test font leaves no room for its words).
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(HelpNowButton),
      ),
      findsOneWidget,
    );
    await close(tester);
  });

  testWidgets('offline: "needs a connection", Sanctuary offered, no call', (
    tester,
  ) async {
    await open(tester, online: false);
    expect(api.calls, isEmpty);
    expect(
      find.text('Quiet Together needs a connection. Sanctuary works offline.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('quiet-open-sanctuary')), findsOneWidget);
    await close(tester);
  });

  testWidgets('kill switch: quiet_paused shows the calm paused line', (
    tester,
  ) async {
    await open(
      tester,
      quietApi: FakeQuietApi()
        ..joinError = const ApiException(code: 'quiet_paused', status: 503),
    );
    expect(
      find.text(
        'Quiet Together is resting for a bit. The Sanctuary is always open.',
      ),
      findsOneWidget,
    );
    await close(tester);
  });

  testWidgets('REQ-QUIET-04: leaving costs nothing — no confirm, no loss '
      'copy; the server is told', (tester) async {
    await open(tester);
    expect(find.text('Leave whenever you like. Nothing is lost.'), findsOne);
    await tester.ensureVisible(find.byKey(const ValueKey('quiet-leave')));
    await tester.tap(find.byKey(const ValueKey('quiet-leave')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(api.calls, contains('leave'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('early'), findsNothing);
    expect(find.textContaining('streak'), findsNothing);
    await close(tester);
  });

  testWidgets('REQ-QUIET-05: the rhythm is off by default; on, it follows '
      'the block and shows the next change as a clock time', (tester) async {
    await open(tester);
    // 13:50 is 20 min into the 13:30 block: focus until :25.
    expect(find.byKey(const ValueKey('quiet-rhythm-line')), findsNothing);
    final sw = find.byKey(const ValueKey('quiet-rhythm-switch'));
    await tester.ensureVisible(sw);
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pump();
    expect(find.textContaining('Focus · break at '), findsOneWidget);
    expect(find.textContaining('left'), findsNothing); // never a countdown
    // To 13:55 + a moment: the shared break begins.
    await advance(tester, const Duration(minutes: 5, seconds: 1));
    expect(cues.toBreaks, [true]);
    expect(cues.chimes, [false]); // no shared sound playing: haptic only
    expect(find.text('Break time.'), findsOneWidget);
    expect(find.textContaining('Break · focus again at '), findsOneWidget);
    await close(tester);
  });

  testWidgets('REQ-QUIET-02: gestures are unnamed; yours say "You sent"; '
      '"Hide gestures" hides them for you only', (tester) async {
    await open(tester);
    channels.last.deliver('gesture', {
      'gestureId': 'x1',
      'type': 'light_a_candle',
      'at': 'now',
    });
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Someone lit a candle'), findsOneWidget);

    final chip = find.byKey(const ValueKey('quiet-gesture-hug'));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pump(const Duration(seconds: 1));
    expect(api.gestures, [GestureType.hug]);
    expect(find.textContaining('You sent'), findsOneWidget);
    // Its echo from the server is not shown twice.
    channels.last.deliver('gesture', {'gestureId': 'g-1', 'type': 'hug'});
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('You sent'), findsOneWidget);
    // The tray rests (1 per 10 s).
    await tester.tap(find.byKey(const ValueKey('quiet-gesture-stargaze')));
    await tester.pump();
    expect(api.gestures, [GestureType.hug]);

    await tester.ensureVisible(find.byKey(const ValueKey('quiet-menu')));
    await tester.tap(find.byKey(const ValueKey('quiet-menu')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('quiet-menu-gestures')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Gestures are hidden for you.'), findsOneWidget);
    channels.last.deliver('gesture', {'gestureId': 'x2', 'type': 'hug'});
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Someone sent a hug'), findsNothing);
    await close(tester);
  });

  testWidgets('Reduce Motion: the presence holds still; a gesture is a still '
      'text line', (tester) async {
    await open(tester, reduceMotion: true);
    final presence = find.byKey(const ValueKey('quiet-presence'));
    final before = tester.getSize(presence);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getSize(presence), before);
    channels.last.deliver('gesture', {'gestureId': 'x', 'type': 'hug'});
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Someone sent a hug'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('quiet-session')),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    await close(tester);
  });

  testWidgets('without Reduce Motion the presence breathes slowly', (
    tester,
  ) async {
    await open(tester);
    final presence = find.byKey(const ValueKey('quiet-presence'));
    final before = tester.getSize(presence);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getSize(presence), isNot(before));
    await close(tester);
  });

  testWidgets('a disconnect never shows a failure: "Reconnecting…" while the '
      'session and the sound go on, then it clears', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('shared-sound-play')));
    await tester.pump(const Duration(seconds: 1));
    channels.last.status(RippleLinkStatus.error);
    api.beatError = const ApiException(
      code: 'connectionError',
      isNetwork: true,
    );
    await advance(tester, const Duration(seconds: 31));
    expect(find.text('Reconnecting…'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiet-session')), findsOneWidget);
    expect(find.textContaining("couldn't"), findsNothing);
    expect(find.textContaining('needs a connection'), findsNothing);
    expect(backend.live, isNotEmpty); // the shared sound keeps playing
    api.beatError = null;
    await advance(tester, const Duration(seconds: 31)); // a beat succeeds
    channels.last.status(RippleLinkStatus.subscribed); // reopened channel
    await tester.pump();
    expect(find.text('Reconnecting…'), findsNothing);
    await close(tester);
  });

  testWidgets('a 404 heartbeat (went quiet) rejoins silently', (tester) async {
    await open(tester);
    api.beatError = const ApiException(code: 'not_found', status: 404);
    await advance(tester, const Duration(seconds: 31));
    expect(api.calls.where((c) => c == 'join:study'), hasLength(2));
    expect(find.byKey(const ValueKey('quiet-session')), findsOneWidget);
    await close(tester);
  });

  testWidgets('the next block: a new session re-opens the channel and '
      're-aligns the playing shared sound to its t0', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('shared-sound-play')));
    await tester.pump(const Duration(seconds: 1));
    final firstSeeds = List.of(backend.seeds);
    api
      ..id = 'aaaaaaaa-0000-4000-8000-000000000002'
      ..t0Ms = api.t0Ms + 3600000;
    wall = api.t0Ms + 2000; // just after the new block started
    await tester.pump(const Duration(seconds: 31)); // heartbeat
    await tester.pump(const Duration(seconds: 1));
    expect(channels.last.topic, 'quiet:${api.id}');
    expect(channels.opened.first.closed, isTrue);
    final fresh = backend.seeds.sublist(firstSeeds.length);
    expect(fresh, isNotEmpty);
    for (final s in fresh) {
      expect(
        (s - (2000 + sharedSoundLead.inMilliseconds)).abs(),
        lessThan(1000),
      );
    }
    await close(tester);
  });

  testWidgets('REQ-QUIET-03: silent until the tap; the shared sound starts '
      'at now − t0 (base stems only) and leaves no session record', (
    tester,
  ) async {
    await open(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(backend.layers, isEmpty); // nothing plays until the tap
    await tester.tap(find.byKey(const ValueKey('shared-sound-play')));
    await tester.pump(const Duration(seconds: 1));
    expect(backend.seeds, hasLength(2));
    // Joined 20 min into the block: every layer starts 20 min in (± 1 s).
    for (final s in backend.seeds) {
      expect((s - 20 * 60000).abs(), lessThan(1000));
    }
    expect(find.byKey(const ValueKey('shared-sound-volume')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shared-sound-stop')));
    await tester.pump(const Duration(seconds: 2));
    expect(log.records, isEmpty); // nothing depends on time spent together
    await close(tester);
  });

  testWidgets('"Report a problem here": reasons, send, thanks; crisis opens '
      'help', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('quiet-menu')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('quiet-menu-report')));
    await settleSheet(tester);
    expect(find.byKey(const ValueKey('quiet-report-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiet-reason-6')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiet-report-send')));
    await settleSheet(tester);
    expect(api.reports, [ReportReason.spam]);
    expect(find.text('Thank you. A moderator will take a look.'), findsOne);
    await close(tester);
  });

  testWidgets('every locale renders the session', (tester) async {
    for (final tag in ['te', 'te-Latn', 'hi', 'hi-Latn']) {
      wall = DateTime.utc(2027, 3, 10, 13, 50).millisecondsSinceEpoch;
      final a = FakeQuietApi();
      await pumpRooms(
        tester,
        QuietScreen(
          mode: QuietMode.rest,
          wallMs: () => wall,
          isOnline: () => true,
        ),
        api: FakeRoomsApi(),
        tag: tag,
        size: const Size(390, 1600),
        extra: [
          quietApiProvider.overrideWithValue(a),
          quietChannelOpenerProvider.overrideWithValue(rf.FakeChannels().open),
          quietCuesProvider.overrideWithValue(FakeCues()),
          soundsBackendProvider.overrideWithValue(SeedBackend()),
          stemStoreProvider.overrideWithValue(FakeStemStore()),
          soundsSessionLogProvider.overrideWithValue(RecordingSessionLog()),
          plusActiveProvider.overrideWithValue(false),
        ],
      );
      expect(find.byKey(const ValueKey('quiet-count')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    }
  });

  group('Sounds: the shared soundscape (additive to the F15 engine)', () {
    ProviderContainer make(SeedBackend b, RecordingSessionLog l) {
      final c = ProviderContainer(
        overrides: [
          soundsBackendProvider.overrideWithValue(b),
          stemStoreProvider.overrideWithValue(FakeStemStore()),
          plusActiveProvider.overrideWithValue(false),
          timeContextProvider.overrideWithValue(testTime()),
          soundsSessionLogProvider.overrideWithValue(l),
        ],
      );
      c.read(soundsLibraryProvider);
      return c;
    }

    testWidgets('two phones that joined 10 min apart start at the same point '
        '(±1 s); Plus stems are left out; a resume re-aligns', (tester) async {
      final a = SeedBackend();
      final b = SeedBackend();
      final ca = make(a, RecordingSessionLog());
      final cb = make(b, RecordingSessionLog());
      var now = 30 * 60000; // both tap 30 min after t0
      SharedSound sound(String key) => SharedSound(
        key: key,
        layers: const [
          SoundsLayerState('brown_noise', 0.5),
          SoundsLayerState('pink_noise', 0.5), // Plus: never played here
        ],
        elapsed: () => Duration(milliseconds: now),
      );
      expect(
        ca.read(soundsControllerProvider.notifier).startShared(sound('q:a')),
        isTrue,
      );
      expect(
        cb.read(soundsControllerProvider.notifier).startShared(sound('q:a')),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(a.seeds, b.seeds);
      expect(a.seeds, hasLength(1));
      expect(ca.read(soundsControllerProvider).isShared, isTrue);
      // Toggling stems is busy under a shared sound.
      expect(
        ca.read(soundsControllerProvider.notifier).toggle('rain'),
        SoundsToggle.busy,
      );
      // Pause, then resume a minute later: it rejoins the shared moment.
      ca.read(soundsControllerProvider.notifier).pause();
      await tester.pump(const Duration(seconds: 1));
      now += 60000;
      ca.read(soundsControllerProvider.notifier).play();
      await tester.pump(const Duration(seconds: 1));
      expect(
        (a.seeds.last - (now + sharedSoundLead.inMilliseconds)).abs(),
        lessThan(1000),
      );
      ca.read(soundsControllerProvider.notifier).stopShared('q:a');
      cb.read(soundsControllerProvider.notifier).stopShared('other');
      expect(cb.read(soundsControllerProvider).isShared, isTrue); // not its key
      cb.read(soundsControllerProvider.notifier).stopShared('q:a');
      await tester.pump(const Duration(seconds: 2));
      ca.dispose();
      cb.dispose();
    });

    testWidgets('the wind-down envelope thins out and ends by itself', (
      tester,
    ) async {
      final b = SeedBackend();
      final l = RecordingSessionLog();
      final c = make(b, l);
      var now = 19 * 60000 + 50000; // 10 s before the 20-minute end
      final plan = windDownPlanWith(const LocalDay(2027, 3, 10), [
        'rain',
        'wind',
        'chimes',
      ]);
      expect(plan.order, ['rain', 'wind', 'chimes']);
      c
          .read(soundsControllerProvider.notifier)
          .startShared(
            SharedSound(
              key: 'wind_down:r',
              layers: [for (final id in plan.order) SoundsLayerState(id, 1)],
              elapsed: () => Duration(milliseconds: now),
              plan: plan,
            ),
          );
      await tester.pump(const Duration(seconds: 1));
      expect(c.read(soundsControllerProvider).isShared, isTrue);
      now += 11000;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      expect(c.read(soundsControllerProvider).isIdle, isTrue);
      expect(l.records, isEmpty);
      c.dispose();
    });
  });
}
