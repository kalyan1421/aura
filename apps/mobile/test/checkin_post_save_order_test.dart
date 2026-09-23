import 'dart:io';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura/src/features/checkin/post_save.dart';
import 'package:aura/src/features/companion/companion_lines.dart';
import 'package:aura/src/features/companion/companion_response.dart';
import 'package:aura/src/features/companion/minute_for_you.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura/src/features/history/checkin_detail_screen.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/rooms/room_offer.dart';
import 'package:aura/src/features/sanctuary/breath_haptics.dart';
import 'package:aura/src/features/sanctuary/breath_pacer.dart';
import 'package:aura/src/features/sanctuary/breathe_session_screen.dart';
import 'package:aura/src/features/sanctuary/steps_activity_screen.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _QuietHaptics implements BreathHaptics {
  @override
  void phaseStarted(BreathPhase phase) {}
}

/// Stands in for the F4 capsule step and notes what was on screen when it
/// ran, so the post-save order can be checked.
class _CapsuleStep {
  final List<({String mood, bool crisisShown, bool sheetOpen, bool saved})>
  calls = [];

  Future<void> call(
    BuildContext context,
    WidgetRef ref, {
    required String checkInId,
    required Mood mood,
    required bool crisisShown,
  }) async {
    calls.add((
      mood: mood.id,
      crisisShown: crisisShown,
      sheetOpen: find.byType(SupportSheet).evaluate().isNotEmpty,
      saved: find.byKey(const ValueKey('checkin-done')).evaluate().isNotEmpty,
    ));
  }
}

/// The check-in's post-save order (F1, PRD 06d REQ-CMP-04…06): crisis sheet
/// → mood-trigger capsule → saved moment (Starlight, the companion response,
/// "A minute for you", the room offer); and Journal auto-complete (F2).
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  Future<_CapsuleStep> pump(
    WidgetTester tester,
    AppDatabase db, {
    bool reduceMotion = false,
    GateState gate = const GateState(stage: OnboardingStage.done),
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final capsules = _CapsuleStep();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db, gate: gate),
          moodTriggerCapsuleStepProvider.overrideWithValue(capsules.call),
          breathHapticsProvider.overrideWithValue(_QuietHaptics()),
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
    return capsules;
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Picks [mood], writes [note] (if any) and saves. The saved moment
  /// animates, so this pumps instead of settling.
  Future<void> checkIn(WidgetTester tester, String mood, {String? note}) async {
    await tapVisible(tester, find.byKey(ValueKey('mood-$mood')));
    if (note != null) {
      await tapVisible(tester, find.text('Add a tag or a few words'));
      final field = find.byKey(const ValueKey('checkin-note'));
      await tester.ensureVisible(field);
      await tester.enterText(field, note);
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  /// The companion line on screen.
  String line(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('companion-line'))).data!;

  Future<List<String>> habitLogKeys(WidgetTester tester, AppDatabase db) =>
      io(tester, () async {
        final rows = await db
            .customSelect(
              'SELECT h.preset_key AS k FROM habit_logs l '
              'JOIN habits h ON h.id = l.habit_id WHERE l.deleted_at IS NULL',
            )
            .get();
        return [for (final r in rows) r.read<String>('k')];
      });

  /// Saves check-ins as if made [daysAgo] days back at the same time of day.
  Future<void> seedDays(
    WidgetTester tester,
    AppDatabase db,
    Iterable<int> daysAgo,
  ) => io(tester, () async {
    for (final d in daysAgo) {
      final repo = CheckInRepository(
        db,
        OutboxRepository(db, const Ids()),
        TimeContext(
          clock: FixedClock(testNow.subtract(Duration(days: d))),
          timezone: 'Asia/Kolkata',
        ),
      );
      await repo.save(id: const Ids().v7(), mood: moodById('calm')!);
    }
  });

  group('order', () {
    testWidgets('a clean note: the capsule step runs first (not held), then '
        'the saved moment: Starlight, the companion line, "A minute for '
        'you" and the room offer', (tester) async {
      final db = memoryDb();
      final capsules = await pump(tester, db);
      await checkIn(tester, 'overwhelmed', note: 'Exams tomorrow');

      expect(capsules.calls, hasLength(1));
      final c = capsules.calls.single;
      expect(c.mood, 'overwhelmed');
      expect(c.crisisShown, isFalse);
      expect(c.saved, isFalse, reason: 'the saved moment comes after it');

      expect(find.text('+10 Starlight'), findsOneWidget);
      expect(find.byType(CompanionReaction), findsOneWidget);
      final storm = [
        for (final k in CompanionLines.keys(Quadrant.storm))
          CompanionLines.text(en, k),
      ];
      expect(storm, contains(line(tester)));
      expect(find.byType(MinuteForYouCard), findsOneWidget);
      expect(find.text('Thirty seconds to land'), findsOneWidget);
      final room = tester.widget<RoomOfferButton>(find.byType(RoomOfferButton));
      expect(room.quadrant, Quadrant.storm);

      double y(Finder f) => tester.getTopLeft(f).dy;
      expect(
        y(find.byKey(const ValueKey('checkin-starlight'))),
        lessThan(y(find.byKey(const ValueKey('companion-line')))),
      );
      expect(
        y(find.byKey(const ValueKey('companion-line'))),
        lessThan(y(find.byType(MinuteForYouCard))),
      );
      await end(tester);
    });

    testWidgets('crisis words: the sheet comes first and the capsule step '
        'waits for it, then runs held; a neutral line, no minute card, the '
        'room offer still follows (REQ-CMP-04)', (tester) async {
      final db = memoryDb();
      final capsules = await pump(tester, db);
      await checkIn(tester, 'lonely', note: 'I want to die');

      // Saved first (F1), then the sheet; nothing else yet.
      expect(
        await io(tester, () => db.select(db.checkIns).get()),
        hasLength(1),
      );
      expect(find.byType(SupportSheet), findsOneWidget);
      expect(capsules.calls, isEmpty);
      expect(find.byType(MinuteForYouCard), findsNothing);

      await tester.tap(find.byKey(const ValueKey('support-close')));
      await settleIo(tester);
      expect(capsules.calls, hasLength(1));
      expect(capsules.calls.single.crisisShown, isTrue);

      final neutral = [
        for (final k in CompanionLines.keys(null)) CompanionLines.text(en, k),
      ];
      expect(neutral, contains(line(tester)));
      expect(find.byType(MinuteForYouCard), findsNothing);
      expect(find.byType(RoomOfferButton), findsOneWidget);
      await end(tester);
    });

    testWidgets('a check-in that wakes the resting avatar: the wake-up moment '
        'plays instead of the shimmer, and its line is the only one', (
      tester,
    ) async {
      final db = memoryDb();
      await seedDays(tester, db, [5]); // resting since 2 days
      final capsules = await pump(tester, db);
      await checkIn(tester, 'calm');

      expect(capsules.calls, hasLength(1));
      expect(
        find.text('Welcome back. One small thing today is plenty.'),
        findsOneWidget,
      );
      expect(find.byType(CompanionReaction), findsNothing);
      final pool = [
        for (final k in CompanionLines.keys(Quadrant.moonlight))
          CompanionLines.text(en, k),
      ];
      for (final l in pool) {
        expect(find.text(l), findsNothing);
      }
      // The minute card and the room offer still follow.
      expect(find.byType(MinuteForYouCard), findsOneWidget);
      expect(find.byType(RoomOfferButton), findsOneWidget);
      await end(tester);
    });

    testWidgets('crossing into Ember: the evolve moment and its line only', (
      tester,
    ) async {
      final db = memoryDb();
      await seedDays(tester, db, [for (var d = 1; d <= 9; d++) d]); // 90
      await pump(tester, db);
      await checkIn(tester, 'joyful'); // +10 = 100

      expect(find.text('+10 Starlight'), findsOneWidget);
      expect(find.text('Your Aura grew into Ember.'), findsOneWidget);
      expect(find.byType(CompanionReaction), findsNothing);
      await end(tester);
    });

    testWidgets('crisis words and a wake-up together: the sheet first, then '
        'the held capsule step, then only the wake-up line', (tester) async {
      final db = memoryDb();
      await seedDays(tester, db, [6]);
      final capsules = await pump(tester, db);
      await checkIn(tester, 'anxious', note: 'I want to die');
      expect(find.byType(SupportSheet), findsOneWidget);
      expect(capsules.calls, isEmpty);
      await tester.tap(find.byKey(const ValueKey('support-close')));
      await settleIo(tester);
      expect(capsules.calls.single.crisisShown, isTrue);
      expect(
        find.text('Welcome back. One small thing today is plenty.'),
        findsOneWidget,
      );
      expect(find.byType(MinuteForYouCard), findsNothing);
      await end(tester);
    });
  });

  group('companion response', () {
    testWidgets('Reduce Motion: no shimmer or lift; the line crossfades in '
        'within 300 ms and is announced (REQ-CMP-02)', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, memoryDb(), reduceMotion: true);
      await checkIn(tester, 'drained');
      expect(find.byKey(const ValueKey('companion-reaction')), findsNothing);
      expect(find.byKey(const ValueKey('companion-glow')), findsNothing);
      final fade = tester.widget<Animate>(
        find.ancestor(
          of: find.byKey(const ValueKey('companion-line')),
          matching: find.byType(Animate),
        ),
      );
      expect(
        fade.duration,
        lessThanOrEqualTo(const Duration(milliseconds: 300)),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('companion-line'))),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
      await end(tester);
    });
  });

  group('"A minute for you"', () {
    for (final (mood, quadrant, title) in [
      ('overwhelmed', Quadrant.storm, 'Thirty seconds to land'),
      ('lonely', Quadrant.rain, 'Hand on heart'),
      ('calm', Quadrant.moonlight, 'A minute of stillness'),
      ('joyful', Quadrant.sunrise, 'Savour this'),
    ]) {
      testWidgets('${quadrant.name}: one tap opens its activity; it never '
          'starts on its own', (tester) async {
        await pump(tester, memoryDb());
        await checkIn(tester, mood);
        final activity = find.byWidgetPredicate(
          (w) => w is BreatheSessionScreen || w is StepsActivityScreen,
        );
        expect(activity, findsNothing);
        await tester.tap(find.byKey(const ValueKey('minute-open')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(activity, findsOneWidget);
        expect(
          find.descendant(of: activity, matching: find.text(title)),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('activity-close')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(MinuteForYouCard), findsOneWidget);
        await end(tester);
      });
    }

    testWidgets('✕ dismisses it with one tap; Done stays', (tester) async {
      await pump(tester, memoryDb());
      await checkIn(tester, 'proud');
      await tester.tap(find.byKey(const ValueKey('minute-dismiss')));
      await tester.pump();
      expect(find.byType(MinuteForYouCard), findsNothing);
      expect(find.byKey(const ValueKey('checkin-done')), findsOneWidget);
      await end(tester);
    });

    testWidgets('Storm → the land activity is the paced 30 s grounding', (
      tester,
    ) async {
      await pump(tester, memoryDb());
      await checkIn(tester, 'anxious');
      await tester.tap(find.byKey(const ValueKey('minute-open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final screen = tester.widget<BreatheSessionScreen>(
        find.byType(BreatheSessionScreen),
      );
      expect(screen.guide, BreathGuide.land);
      expect(minuteActivityFor(Quadrant.storm).name, 'land');
      await end(tester);
    });

    group('real fonts', () {
      final roboto = _robotoFiles();
      setUpAll(() async {
        if (roboto == null) return;
        await _load('CupertinoSystemText', roboto);
        await _load('CupertinoSystemDisplay', roboto);
        await _load('NotoSansTelugu', const [
          'assets/fonts/NotoSansTelugu-Regular.ttf',
          'assets/fonts/NotoSansTelugu-Medium.ttf',
          'assets/fonts/NotoSansTelugu-SemiBold.ttf',
        ]);
      });

      for (final tag in ['te', 'te-Latn']) {
        testWidgets('$tag at 200%: the saved moment scrolls, Done stays '
            'pinned and nothing overflows', (tester) async {
          tester.view.physicalSize = const Size(390 * 3, 844 * 3);
          tester.view.devicePixelRatio = 3;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...testOverrides(db: memoryDb(), locale: tag),
                moodTriggerCapsuleStepProvider.overrideWithValue(
                  _CapsuleStep().call,
                ),
                breathHapticsProvider.overrideWithValue(_QuietHaptics()),
              ],
              child: localized(
                const CheckInScreen(),
                locale: localeFromTag(tag),
              ),
            ),
          );
          await settleIo(tester);
          await checkIn(tester, 'lonely');
          expect(tester.takeException(), isNull);
          expect(find.byType(MinuteForYouCard), findsOneWidget);
          final done = tester.getRect(
            find.byKey(const ValueKey('checkin-done')),
          );
          expect(done.bottom, lessThanOrEqualTo(844));
          expect(done.height, greaterThanOrEqualTo(48));
          await end(tester);
        }, skip: roboto == null);
      }

      for (final tag in ['en', 'te', 'te-Latn']) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('$tag at ${scale}x: the same size for every quadrant '
              '(REQ-CMP-05), nothing overflows', (tester) async {
            tester.view.physicalSize = const Size(390 * 3, 844 * 3);
            tester.view.devicePixelRatio = 3;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final sizes = <Size>{};
            for (final q in Quadrant.values) {
              await tester.pumpWidget(
                localized(
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: MinuteForYouCard(quadrant: q, onDismiss: () {}),
                    ),
                  ),
                  locale: localeFromTag(tag),
                ),
              );
              await tester.pump();
              expect(tester.takeException(), isNull);
              sizes.add(tester.getSize(find.byType(MinuteForYouCard)));
            }
            expect(sizes, hasLength(1), reason: '$sizes');
          }, skip: roboto == null);
        }
      }
    });
  });

  group('Journal auto-complete (F2)', () {
    final long = 'A long day, but the walk home by the lake was quiet.';
    final short = 'A long day, but the walk home was calm and quiet.'.substring(
      0,
      49,
    );

    testWidgets('a note of 50+ characters ticks off today\'s Journal once, '
        'with a quiet line', (tester) async {
      expect(long.length, greaterThanOrEqualTo(journalNoteMinChars));
      final db = memoryDb();
      await pump(tester, db);
      await checkIn(tester, 'content', note: long);
      await settleIo(tester);
      expect(await habitLogKeys(tester, db), ['journal']);
      expect(find.text('Journal is marked done for today.'), findsOneWidget);
      await end(tester);

      // A second long note the same day: still one.
      await pump(tester, db);
      await checkIn(tester, 'content', note: long);
      await settleIo(tester);
      expect(await habitLogKeys(tester, db), ['journal']);
      expect(find.text('Journal is marked done for today.'), findsNothing);
      await end(tester);
    });

    testWidgets('49 characters, a hidden Journal, or the onboarding check-in: '
        'nothing', (tester) async {
      final a = memoryDb();
      await pump(tester, a);
      await checkIn(tester, 'content', note: short);
      await settleIo(tester);
      expect(await habitLogKeys(tester, a), isEmpty);
      await end(tester);

      final hidden = memoryDb();
      await io(
        tester,
        () => HabitRepository(
          hidden,
          OutboxRepository(hidden, const Ids()),
          testTime(),
          const Ids(),
        ).setPresetShown(PresetHabitKeys.journal, false),
      );
      await pump(tester, hidden);
      await checkIn(tester, 'content', note: long);
      await settleIo(tester);
      expect(await habitLogKeys(tester, hidden), isEmpty);
      await end(tester);

      final first = memoryDb();
      await pump(
        tester,
        first,
        gate: const GateState(stage: OnboardingStage.firstCheckIn),
      );
      await checkIn(tester, 'content', note: long);
      await settleIo(tester);
      expect(
        await io(tester, () => first.select(first.habitLogs).get()),
        isEmpty,
      );
      await end(tester);
    });

    testWidgets('characters as people see them: 25 Telugu syllables are 25, '
        'not 50', (tester) async {
      final syllables25 = List.filled(25, 'నా').join(); // 50 code units
      final syllables50 = List.filled(50, 'నా').join();
      expect(noteCompletesJournal(syllables25), isFalse);
      expect(noteCompletesJournal(syllables50), isTrue);
      expect(noteCompletesJournal('   ${'a' * 49}   '), isFalse);
      expect(noteCompletesJournal(null), isFalse);
    });

    testWidgets('an edit within 24 h that writes a longer note ticks it off', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final db = memoryDb();
      final id = const Ids().v7();
      await io(
        tester,
        () => CheckInRepository(
          db,
          OutboxRepository(db, const Ids()),
          testTime(testNow.subtract(const Duration(hours: 3))),
        ).save(id: id, mood: moodById('calm')!, note: 'short'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db: db),
          child: localized(CheckInDetailScreen(id: id)),
        ),
      );
      await settleIo(tester);
      await tapVisible(tester, find.byKey(const ValueKey('history-edit')));
      final field = find.byKey(const ValueKey('checkin-note'));
      await tester.ensureVisible(field);
      await tester.enterText(field, long);
      await tester.pump();
      await tapVisible(tester, find.byKey(const ValueKey('history-edit-save')));
      await settleIo(tester);
      expect(await habitLogKeys(tester, db), ['journal']);
      expect(
        find.byKey(const ValueKey('history-journal-logged')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

List<String>? _robotoFiles() {
  final dirs = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      '$root/bin/cache/artifacts/material_fonts',
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    dirs.add('${dir.path}/material_fonts');
    dirs.add('${dir.path}/bin/cache/artifacts/material_fonts');
    dir = dir.parent;
  }
  for (final d in dirs) {
    final files = [
      '$d/Roboto-Regular.ttf',
      '$d/Roboto-Medium.ttf',
      '$d/Roboto-Bold.ttf',
    ];
    if (files.every((f) => File(f).existsSync())) return files;
  }
  return null;
}

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
    );
  }
  await loader.load();
}
