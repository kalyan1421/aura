import 'package:aura/src/core/entitlements/plus.dart';
import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/core/remote_config/remote_config_providers.dart';
import 'package:aura/src/features/quiet/quiet_providers.dart';
import 'package:aura/src/features/ripples/ripple_engine.dart' show ServerClock;
import 'package:aura/src/features/rooms/room_screen.dart';
import 'package:aura/src/features/rooms/wind_down_api.dart';
import 'package:aura/src/features/rooms/wind_down_screen.dart';
import 'package:aura/src/features/sanctuary/breath_orb.dart';
import 'package:aura/src/features/sanctuary/breath_pacer.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_backend.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_library.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_session_log.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quiet_test.dart' show FakeCues, SeedBackend;
import 'rooms_fakes.dart';
import 'sounds_fakes.dart';

/// F16 Lantern Hour wind-down in a room (PRD 06b "Lantern Hour wind-down
/// (Milestone C)"; REQ-QUIET-07; contracts/api/v1-quiet.md §2): the room
/// card shows only "N winding down" and follows the `wind_down` room event;
/// the wind-down runs the Calm pacer and preset cues from the server `t0`;
/// nothing plays until a tap; Reduce Motion holds the orb still; leaving
/// costs nothing.

class FakeWindDownApi implements WindDownApi {
  FakeWindDownApi(this.view);

  WindDownView? view;
  final List<String> calls = [];

  @override
  Future<WindDownReply> get(String roomId) async {
    calls.add('get');
    return WindDownReply(view, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<WindDownReply> join(String roomId) async {
    calls.add('join');
    view = view?.copyWith(joined: true, count: (view?.count ?? 0) + 1);
    return WindDownReply(view, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<void> leave(String roomId) async => calls.add('leave');
}

WindDownView openView({required int t0Ms, int count = 2}) => WindDownView(
  state: 'open',
  startsAtMs: t0Ms,
  endsAtMs: t0Ms + 20 * 60000,
  count: count,
  joined: false,
  stems: const ['rain', 'wind', 'chimes'],
  cues: const [
    WindDownCue(0, 'arrive'),
    WindDownCue(120, 'day_quieter'),
    WindDownCue(330, 'shoulders'),
  ],
);

class _Flags extends RemoteFlagsNotifier {
  _Flags(this.flags);
  final RemoteFlags flags;
  @override
  RemoteFlags build() => flags;
}

void main() {
  late FakeWindDownApi api;
  late FakeChannels channels;
  late SeedBackend backend;
  late FakeCues cues;
  late RecordingSessionLog log;

  Future<void> openRoom(
    WidgetTester tester, {
    WindDownView? view,
    bool reduceMotion = false,
    bool flagOn = true,
  }) async {
    api = FakeWindDownApi(
      view ?? openView(t0Ms: DateTime.now().millisecondsSinceEpoch - 60000),
    );
    channels = FakeChannels();
    backend = SeedBackend();
    cues = FakeCues();
    log = RecordingSessionLog();
    await pumpRooms(
      tester,
      const RoomScreen(roomId: roomId),
      api: FakeRoomsApi(),
      channels: channels,
      reduceMotion: reduceMotion,
      size: const Size(390, 1800),
      extra: [
        windDownApiProvider.overrideWithValue(api),
        quietCuesProvider.overrideWithValue(cues),
        soundsBackendProvider.overrideWithValue(backend),
        stemStoreProvider.overrideWithValue(FakeStemStore()),
        soundsSessionLogProvider.overrideWithValue(log),
        plusActiveProvider.overrideWithValue(false),
        if (!flagOn)
          remoteFlagsProvider.overrideWith(
            () => _Flags(
              const RemoteFlags({
                'lantern_wind_down_enabled': FlagValue(enabled: false),
              }),
            ),
          ),
      ],
    );
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('the room card shows only "N winding down" and follows the '
      'room event; it ends with the event', (tester) async {
    await openRoom(tester);
    expect(api.calls, contains('get'));
    final card = find.byKey(const ValueKey('wind-down-card'));
    await tester.ensureVisible(card);
    expect(find.text('2 winding down'), findsOneWidget);
    channels.room.emit('wind_down', {'state': 'open', 'count': 3, 'at': 'x'});
    await tester.pump();
    await tester.pump();
    expect(find.text('3 winding down'), findsOneWidget);
    channels.room.emit('wind_down', {'state': 'ended', 'count': 0});
    await tester.pump();
    await tester.pump();
    expect(card, findsNothing);
    await close(tester);
  });

  testWidgets('the kill switch hides the offer (and no call is made)', (
    tester,
  ) async {
    await openRoom(tester, flagOn: false);
    expect(find.byKey(const ValueKey('wind-down-card')), findsNothing);
    expect(api.calls, isEmpty);
    await close(tester);
  });

  testWidgets('"Wind down together" opts in and opens the wind-down; leaving '
      'opts out and costs nothing', (tester) async {
    await openRoom(tester);
    final join = find.byKey(const ValueKey('wind-down-join'));
    await tester.ensureVisible(join);
    await tester.tap(join);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(api.calls, contains('join'));
    expect(find.byKey(const ValueKey('wind-down-screen')), findsOneWidget);
    expect(find.text('3 winding down'), findsOneWidget);
    expect(backend.layers, isEmpty); // nothing plays without a tap
    expect(find.byType(HelpNowButton), findsWidgets);
    final leave = find.byKey(const ValueKey('wind-down-leave'));
    await tester.ensureVisible(leave);
    await tester.tap(leave);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(api.calls, contains('leave'));
    expect(find.byKey(const ValueKey('wind-down-screen')), findsNothing);
    expect(find.textContaining('early'), findsNothing);
    await close(tester);
  });

  group('the wind-down screen (pinned clock)', () {
    late int wall;

    Future<void> openScreen(
      WidgetTester tester, {
      bool reduceMotion = false,
    }) async {
      final t0 = DateTime.utc(2027, 3, 10, 17).millisecondsSinceEpoch;
      wall = t0;
      await openRoom(
        tester,
        view: openView(t0Ms: t0),
        reduceMotion: reduceMotion,
      );
      final clock = ServerClock()
        ..sample(sentMs: wall, receivedMs: wall, serverMs: wall);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => WindDownScreen(
            roomId: roomId,
            view: openView(t0Ms: t0),
            clock: clock,
            wallMs: () => wall,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> advance(WidgetTester tester, Duration d) async {
      var left = d;
      const step = Duration(milliseconds: 100);
      while (left > Duration.zero) {
        wall += step.inMilliseconds;
        await tester.pump(step);
        left -= step;
      }
    }

    testWidgets('the Calm pacer from t0 with phase words and haptics; preset '
        'text cues; no voice', (tester) async {
      await openScreen(tester);
      expect(find.text('Breathe in'), findsOneWidget);
      expect(find.text('Arrive. There\'s nothing to do now.'), findsOneWidget);
      await advance(tester, const Duration(seconds: 4));
      expect(find.text('Breathe out'), findsOneWidget);
      expect(
        cues.breaths,
        containsAllInOrder([BreathPhase.inhale, BreathPhase.exhale]),
      );
      wall += 120000; // two minutes in
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Let the day get quieter.'), findsOneWidget);
      expect(tester.widget<BreathOrb>(find.byType(BreathOrb)).still, isFalse);
      await close(tester);
    });

    testWidgets('Reduce Motion: the orb holds still; the words and haptics '
        'carry the rhythm', (tester) async {
      await openScreen(tester, reduceMotion: true);
      expect(tester.widget<BreathOrb>(find.byType(BreathOrb)).still, isTrue);
      await advance(tester, const Duration(seconds: 4));
      expect(find.text('Breathe out'), findsOneWidget);
      expect(cues.breaths, isNotEmpty);
      await close(tester);
    });

    testWidgets('the shared track starts at now − t0 after a tap, and it '
        'ends at 20 minutes with a calm line', (tester) async {
      await openScreen(tester);
      wall += 5 * 60000; // 5 min in
      final play = find.byKey(const ValueKey('shared-sound-play'));
      await tester.ensureVisible(play);
      await tester.tap(play);
      await tester.pump(const Duration(seconds: 1));
      expect(backend.seeds, hasLength(3));
      for (final s in backend.seeds) {
        expect((s - 5 * 60000).abs(), lessThan(1500));
      }
      wall += 16 * 60000; // past the end
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The wind-down has ended. Rest well.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(log.records, isEmpty);
      await close(tester);
    });
  });
}
