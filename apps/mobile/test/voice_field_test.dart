import 'dart:convert';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura/src/features/voice/voice_note_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'voice_fakes.dart';

/// Voice capture in the check-in (F1; PRD 15-permissions mic flow, 14-states
/// "Edge: mic denied", REQ-A11Y-02/04/08).
void main() {
  late AppDatabase db;
  late FakeRecorder recorder;
  late FakePlatform platform;
  late FakeVoiceStore store;
  late List<String> announced;

  setUp(() {
    db = memoryDb();
    recorder = FakeRecorder();
    platform = FakePlatform();
    store = FakeVoiceStore();
    announced = [];
  });

  Future<void> pump(WidgetTester tester, {bool reduceMotion = false}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final m = message as Map<dynamic, dynamic>;
        if (m['type'] == 'announce') {
          announced.add(
            (m['data'] as Map<dynamic, dynamic>)['message'] as String,
          );
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db),
          ...voiceOverrides(
            recorder: recorder,
            platform: platform,
            store: store,
          ),
        ],
        child: localized(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reduceMotion),
              child: const CheckInScreen(),
            ),
          ),
        ),
      ),
    );
    await settleIo(tester);
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(f);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openDetails(WidgetTester tester) async {
    await tapVisible(tester, find.byKey(const ValueKey('mood-calm')));
    await tapVisible(tester, find.text('Add a tag or a few words'));
    await tester.pump(const Duration(seconds: 1));
  }

  final record = find.byKey(const ValueKey('voice-record'));
  final stop = find.byKey(const ValueKey('voice-stop'));

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  }

  testWidgets('first mic tap: the explainer first; "Not now" never shows the '
      'OS prompt; "Allow" does, and recording starts', (tester) async {
    await pump(tester);
    await openDetails(tester);

    await tapVisible(tester, record);
    expect(
      find.text(
        'To record a voice note, Aura needs your microphone. Recordings '
        'stay private to you and are never shared in rooms.',
      ),
      findsOneWidget,
    );
    await tapVisible(tester, find.byKey(const ValueKey('voice-not-now')));
    await settleIo(tester);
    expect(recorder.prompts, 0);
    expect(stop, findsNothing);

    await tapVisible(tester, record);
    await tapVisible(tester, find.byKey(const ValueKey('voice-allow')));
    await settleIo(tester);
    expect(recorder.prompts, 1);
    expect(recorder.started, hasLength(1));
    expect(stop, findsOneWidget);
    expect(announced, contains('Recording started'));
    await tapVisible(tester, stop);
    await done(tester);
  });

  testWidgets('mic denied: "Voice is off…" with a working Settings link; '
      'typing still works; Save is not blocked', (tester) async {
    recorder.promptAnswer = false;
    await pump(tester);
    await openDetails(tester);

    await tapVisible(tester, record);
    await tapVisible(tester, find.byKey(const ValueKey('voice-allow')));
    await settleIo(tester);
    expect(
      find.text('Voice is off. Type instead, or turn it on in Settings.'),
      findsOneWidget,
    );
    await tapVisible(tester, find.byKey(const ValueKey('voice-settings')));
    expect(platform.settingsOpened, 1);

    // A later tap asks the OS again (no explainer twice); iOS just says no.
    await tapVisible(tester, record);
    await settleIo(tester);
    expect(find.byKey(const ValueKey('voice-allow')), findsNothing);
    expect(recorder.prompts, 1);

    final note = find.byKey(const ValueKey('checkin-note'));
    await tester.ensureVisible(note);
    await tester.enterText(note, 'typed instead');
    await tester.pump();
    expect(find.text('typed instead'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);
    expect(find.byKey(const ValueKey('checkin-starlight')), findsOneWidget);
    await done(tester);
  });

  testWidgets('recording counts up calmly and stops by itself at 60 s with a '
      'calm note; then play, record again, remove', (tester) async {
    recorder.granted = true;
    await pump(tester);
    await openDetails(tester);

    await tapVisible(tester, record);
    await settleIo(tester, rounds: 2);
    expect(stop, findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('0:05 · up to 1:00'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('voice-elapsed'))),
      isSemantics(label: 'Recording, 5 seconds'),
    );

    // Nothing counts down or changes tone near the end.
    await tester.pump(const Duration(seconds: 50));
    expect(find.text('0:55 · up to 1:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(recorder.stops, 1);
    expect(stop, findsNothing);
    expect(find.byKey(const ValueKey('voice-limit-note')), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    expect(announced, contains('Voice note recorded, 60 seconds'));

    // Record again replaces it; Remove clears it.
    await tapVisible(tester, find.byKey(const ValueKey('voice-rerecord')));
    await settleIo(tester, rounds: 2);
    expect(recorder.started, hasLength(2));
    await tester.pump(const Duration(seconds: 3));
    await tapVisible(tester, stop);
    await settleIo(tester, rounds: 2);
    expect(find.text('0:03'), findsOneWidget);
    expect(find.byKey(const ValueKey('voice-limit-note')), findsNothing);

    await tapVisible(tester, find.byKey(const ValueKey('voice-remove')));
    expect(find.byKey(const ValueKey('voice-play')), findsNothing);
    expect(record, findsOneWidget);
    await done(tester);
  });

  testWidgets('Reduce Motion: no pulsing level ring (the level stream is not '
      'even listened to)', (tester) async {
    recorder.granted = true;
    await pump(tester, reduceMotion: true);
    await openDetails(tester);
    await tapVisible(tester, record);
    await settleIo(tester, rounds: 2);
    expect(find.byKey(const ValueKey('voice-level-still')), findsOneWidget);
    expect(find.byKey(const ValueKey('voice-level')), findsNothing);
    expect(recorder.levelListeners, 0);
    await tapVisible(tester, stop);
    await done(tester);
  });

  testWidgets('with motion: the ring follows the input level', (tester) async {
    recorder.granted = true;
    await pump(tester);
    await openDetails(tester);
    await tapVisible(tester, record);
    await settleIo(tester, rounds: 2);
    expect(find.byKey(const ValueKey('voice-level')), findsOneWidget);
    expect(recorder.levelListeners, 1);
    recorder.levelsCtrl.add(0.8);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester
          .widget<AnimatedScale>(find.byKey(const ValueKey('voice-level')))
          .scale,
      closeTo(1.8, 0.001),
    );
    await tapVisible(tester, stop);
    await done(tester);
  });

  testWidgets('Save while recording finishes the recording and saves the '
      'check-in with it (the upsert waits for the upload)', (tester) async {
    recorder.granted = true;
    await pump(tester);
    await openDetails(tester);
    await tapVisible(tester, record);
    await settleIo(tester, rounds: 2);
    await tester.pump(const Duration(seconds: 7));

    await tapVisible(tester, find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);

    expect(recorder.stops, 1);
    expect(find.byKey(const ValueKey('checkin-starlight')), findsOneWidget);
    final row = await io(tester, () => db.select(db.checkIns).getSingle());
    expect(row.voiceFile, store.adopted.single);
    // 7 s plus the few frames before Save was tapped.
    expect(row.voiceMs, inInclusiveRange(7000, 9000));
    final m = await io(tester, () => db.select(db.outbox).getSingle());
    expect(m.needsMedia, isTrue);
    expect(jsonDecode(m.payload), isNot(contains('voicePath')));
    expect(find.byKey(const ValueKey('checkin-voice-dropped')), findsNothing);
    await done(tester);
  });

  testWidgets('storage full: the check-in saves, voice is dropped with a calm '
      'notice', (tester) async {
    recorder.granted = true;
    store.failAdopt = true;
    await pump(tester);
    await openDetails(tester);
    await tapVisible(tester, record);
    await settleIo(tester, rounds: 2);
    await tester.pump(const Duration(seconds: 2));
    await tapVisible(tester, stop);
    await settleIo(tester, rounds: 2);

    await tapVisible(tester, find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);

    expect(find.byKey(const ValueKey('checkin-voice-dropped')), findsOneWidget);
    final row = await io(tester, () => db.select(db.checkIns).getSingle());
    expect(row.voiceFile, isNull);
    await done(tester);
  });

  testWidgets('a recording counts as unsaved input (leaving asks first)', (
    tester,
  ) async {
    recorder.granted = true;
    await pump(tester);
    await openDetails(tester);
    await tapVisible(tester, record);
    await settleIo(tester, rounds: 2);
    await tester.pump(const Duration(seconds: 2));
    await tapVisible(tester, stop);
    await settleIo(tester, rounds: 2);
    await tapVisible(tester, find.byKey(const ValueKey('checkin-close')));
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('discard-keep')));
    await done(tester);
  });

  testWidgets('voice controls: 48 dp, labelled (tap-target guidelines)', (
    tester,
  ) async {
    recorder.granted = true;
    final handle = tester.ensureSemantics();
    await pump(tester);
    await openDetails(tester);
    await tester.ensureVisible(record);
    await tester.pump();
    expect(tester.getSize(record).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(record),
      isSemantics(
        label: 'Record a voice note',
        hint: 'Up to a minute. Only you can hear it.',
        isButton: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tapVisible(tester, record);
    await settleIo(tester, rounds: 2);
    expect(tester.getSize(stop).height, greaterThanOrEqualTo(48));
    await tester.pump(const Duration(seconds: 1));
    await tapVisible(tester, stop);
    await settleIo(tester, rounds: 2);
    final play = find.byKey(const ValueKey('voice-play'));
    expect(tester.getSize(play).height, greaterThanOrEqualTo(48));
    expect(find.byTooltip('Play voice note'), findsOneWidget);
    expect(find.bySemanticsLabel('Remove voice note'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
    await done(tester);
  });

  testWidgets('Telugu at 200% text: every voice state fits (no overflow)', (
    tester,
  ) async {
    recorder.granted = true;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db, locale: 'te'),
          ...voiceOverrides(
            recorder: recorder,
            platform: platform,
            store: store,
          ),
        ],
        child: localized(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: const CheckInScreen(),
            ),
          ),
          locale: const Locale('te'),
        ),
      ),
    );
    await settleIo(tester);
    // Everything is taller at 200%: bring each control in first (the list
    // builds lazily).
    Future<void> bringIn(Finder f) => tester.dragUntilVisible(
      f,
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await bringIn(find.byKey(const ValueKey('mood-calm')));
    await tapVisible(tester, find.byKey(const ValueKey('mood-calm')));
    final details = find.byIcon(Icons.add_rounded).first;
    await bringIn(details);
    await tapVisible(tester, details);
    await tester.pump(const Duration(seconds: 1));
    await bringIn(record);
    await tapVisible(tester, record);
    await settleIo(tester, rounds: 2);
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const ValueKey('voice-remove')));
    await tester.pump();
    expect(find.byKey(const ValueKey('voice-limit-note')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Denied notice with its Settings link.
    recorder
      ..granted = false
      ..promptAnswer = false;
    await tapVisible(tester, find.byKey(const ValueKey('voice-remove')));
    await tapVisible(tester, record);
    await settleIo(tester, rounds: 2);
    await tapVisible(tester, find.byKey(const ValueKey('voice-allow')));
    await settleIo(tester, rounds: 2);
    await tester.ensureVisible(find.byKey(const ValueKey('voice-settings')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await done(tester);
  });

  test('time formatting', () {
    expect(formatVoiceTime(const Duration(seconds: 7)), '0:07');
    expect(formatVoiceTime(const Duration(seconds: 60)), '1:00');
    expect(voiceSeconds(const Duration(milliseconds: 59600)), 60);
  });
}
