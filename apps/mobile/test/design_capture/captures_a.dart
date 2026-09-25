// Onboarding, Home, check-in and history captures.
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth_social_fakes.dart' as social;
import '../helpers.dart';
import 'capture_drive.dart';
import 'capture_harness.dart';
import 'capture_world.dart';

World _onboarding(OnboardingStage stage, {DateTime? blockedUntil}) => World(
  gate: GateState(stage: stage, blockedUntil: blockedUntil),
  assets: captureAssets,
  progress: newUserProgress(),
  signedIn: false,
);

/// A year of history, habits and keepsakes (all seen); today's check-in
/// when [checkedIn].
Future<void> seedEveryday(World w, {bool checkedIn = true}) async {
  await w.seedHistory(todayMood: checkedIn ? 'content' : null);
  await w.seedHabits(doneToday: checkedIn);
  await w.seedKeepsakes();
}

void onboardingAndHome() {
  group('onboarding', () {
    captureTest('welcome', (tester, cap) async {
      await boot(tester, _onboarding(OnboardingStage.welcome));
      await frames(tester, frames: 10);
      await cap.shoot(
        '010_onboarding_welcome_default',
        screen: 'Onboarding · Welcome',
        state: 'first launch',
        source: 'WelcomeScreen (${Routes.welcome})',
      );
    });

    captureTest('trust', (tester, cap) async {
      await boot(tester, _onboarding(OnboardingStage.trust));
      await cap.shoot(
        '011_onboarding_trust_default',
        screen: 'Onboarding · Privacy & boundaries',
        state: 'default',
        source: 'TrustScreen (${Routes.trust})',
      );
    });

    captureTest('dob', (tester, cap) async {
      await boot(tester, _onboarding(OnboardingStage.dob));
      await cap.shoot(
        '013_onboarding_dob_empty',
        screen: 'Onboarding · Date of birth',
        state: 'nothing picked',
        source: 'DobScreen (${Routes.dob})',
      );
      await tapKey(tester, 'dob-year');
      await frames(tester, frames: 6);
      await cap.shoot(
        '014_onboarding_dob_year-picker',
        screen: 'Onboarding · Date of birth',
        state: 'year picker sheet open',
        source: 'DobPickerSheet',
      );
    });

    captureTest('language', (tester, cap) async {
      await boot(tester, _onboarding(OnboardingStage.language));
      await cap.shoot(
        '015_onboarding_language_default',
        screen: 'Onboarding · Language',
        state: 'English selected',
        source: 'LanguageScreen (${Routes.language})',
      );
    });

    captureTest('sign in', (tester, cap) async {
      final auth = social.FakeSocialAuth();
      final w = World(
        gate: const GateState(stage: OnboardingStage.signIn),
        assets: captureAssets,
        progress: newUserProgress(),
        authRepo: auth,
      )..extra.addAll(socialOverrides(auth));
      await boot(tester, w);
      await cap.shoot(
        '016_onboarding_signin_default',
        screen: 'Onboarding · Sign in',
        state: 'Apple + Google + email (iOS config)',
        source: 'SignInScreen (${Routes.onboardingSignIn})',
      );
    });

    captureTest('blocked', (tester, cap) async {
      await boot(
        tester,
        _onboarding(
          OnboardingStage.dob,
          blockedUntil: testNow.add(const Duration(days: 30)),
        ),
      );
      await cap.shoot(
        '017_onboarding_blocked_under-13',
        screen: 'Onboarding · Under 13',
        state: '30-day device lock (India helplines)',
        source: 'BlockedScreen (${Routes.blocked})',
      );
    });

    captureTest('first check-in', (tester, cap) async {
      await boot(
        tester,
        World(
          gate: const GateState(stage: OnboardingStage.firstCheckIn),
          assets: captureAssets,
          progress: newUserProgress(),
        ),
      );
      await cap.shoot(
        '018_onboarding_first-checkin_mood-grid',
        screen: 'Onboarding · First check-in',
        state: 'mood grid, no close button',
        source: 'CheckInScreen(first: true) (${Routes.checkIn})',
      );
    });
  });

  group('home', () {
    captureTest('fresh day', (tester, cap) async {
      await boot(
        tester,
        world(checkedIn: false),
        seed: (w) => seedEveryday(w, checkedIn: false),
      );
      await frames(tester, frames: 10);
      await cap.shoot(
        '020_home_today_fresh-day',
        screen: 'Home',
        state: 'fresh day, not checked in yet (11-day glow streak)',
        source: 'HomeScreen (${Routes.home})',
      );
    });

    captureTest('after check-in', (tester, cap) async {
      await boot(tester, world(), seed: seedEveryday);
      await frames(tester, frames: 10);
      await cap.shoot(
        '021_home_today_checked-in',
        screen: 'Home',
        state: 'after today\'s check-in (glow active, 2 habits done)',
        source: 'HomeScreen (${Routes.home})',
      );
      await scrollToEnd(tester);
      await cap.shoot(
        '022_home_today_scrolled-end',
        screen: 'Home',
        state: 'scrolled to the end (habits, Breath Ripples card)',
        source: 'HomeScreen (${Routes.home})',
      );
    });

    captureTest('new user', (tester, cap) async {
      final w = World(
        assets: captureAssets,
        progress: newUserProgress(),
        keepsakeList: const [],
      );
      w.roomsApi.rooms_ = [];
      await boot(tester, w);
      await frames(tester, frames: 10);
      await cap.shoot(
        '023_home_new-user_empty',
        screen: 'Home',
        state: 'brand-new person (Check in pulses)',
        source: 'HomeScreen (${Routes.home})',
      );
    });

    captureTest('new keepsake', (tester, cap) async {
      await boot(
        tester,
        world(),
        seed: (w) async {
          await w.seedHistory(todayMood: 'content');
          await w.seedHabits();
          await w.seedKeepsakes(unseen: 'sanctuary_minutes_60');
        },
      );
      await frames(tester, frames: 10);
      await cap.shoot(
        '024_home_keepsake-card_new',
        screen: 'Home',
        state: 'new-keepsake card',
        source: 'KeepsakeHomeCards on HomeScreen',
      );
    });

    captureTest('trial ending', (tester, cap) async {
      await boot(tester, world(entitlement: trialEnding()), seed: seedEveryday);
      // The card loads after the first frames; the list grows with it.
      for (var i = 0; i < 3; i++) {
        await settle(tester);
        await scrollToEnd(tester);
      }
      await cap.shoot(
        '025_home_plus-card_trial-ending',
        screen: 'Home',
        state: 'Plus trial-ending card (scrolled to the end)',
        source: 'PlusHomeCards on HomeScreen',
      );
    });

    captureTest('share prompt', (tester, cap) async {
      await boot(tester, world(sharePrompt: true), seed: seedEveryday);
      await frames(tester, frames: 10);
      await cap.shoot(
        '026_home_share-prompt_milestone',
        screen: 'Home',
        state: 'milestone share prompt ("Your Aura reached Glow")',
        source: 'SharePromptCard on HomeScreen',
      );
    });

    captureTest('capsule ready', (tester, cap) async {
      await boot(
        tester,
        world(),
        seed: (w) async {
          await seedEveryday(w);
          await w.seedCapsules(dueToday: true);
        },
      );
      await frames(tester, frames: 10);
      await cap.shoot(
        '027_home_capsule-card_ready',
        screen: 'Home',
        state: 'a date capsule is ready to open',
        source: 'CapsuleReadyCard on HomeScreen',
      );
    });

    captureTest('habits editor', (tester, cap) async {
      await boot(tester, world(), seed: seedEveryday);
      await tapKey(tester, 'habits-edit');
      await frames(tester, frames: 6);
      await cap.shoot(
        '028_home_habits-editor_sheet',
        screen: 'Home · Habits editor',
        state: 'presets + 2 custom habits',
        source: 'HabitsEditorSheet (showHabitsEditor)',
      );
    });

    captureTest('rest days', (tester, cap) async {
      await boot(tester, world(), seed: seedEveryday);
      await tapKey(tester, 'home-rest-days');
      await frames(tester, frames: 6);
      await cap.shoot(
        '029_home_rest-days_sheet',
        screen: 'Home · Rest days',
        state: 'sheet open',
        source: 'RestDaysSheet (showRestDaysSheet)',
      );
    });
  });
}

/// Opens the check-in from Home.
Future<void> openCheckIn(WidgetTester tester, World w) async {
  final c = await boot(
    tester,
    w,
    seed: (w) => seedEveryday(w, checkedIn: false),
  );
  await push(tester, c, Routes.checkIn);
}

Future<void> pickMood(WidgetTester tester, String mood) =>
    tapKey(tester, 'mood-$mood');

Future<void> save(WidgetTester tester) async {
  await tapKey(tester, 'checkin-save', settleIo: true);
  await settle(tester);
  await frames(tester, frames: 15, step: const Duration(milliseconds: 200));
}

void checkInAndHistory() {
  group('check-in', () {
    captureTest('mood grid and details', (tester, cap) async {
      await openCheckIn(tester, world(checkedIn: false));
      await cap.shoot(
        '030_checkin_mood-grid_empty',
        screen: 'Check-in · Mood grid',
        state: 'nothing picked',
        source: 'CheckInScreen (${Routes.checkIn})',
      );
      await pickMood(tester, 'drained');
      await cap.shoot(
        '031_checkin_mood-grid_selected',
        screen: 'Check-in · Mood grid',
        state: '"Drained" picked',
        source: 'CheckInScreen (${Routes.checkIn})',
      );
      await tapFinder(tester, find.text('Add a tag or a few words'));
      await frames(tester, frames: 10);
      final note = find.byKey(const ValueKey('checkin-note'));
      await reveal(tester, note);
      await scrollBy(tester, 120);
      await cap.shoot(
        '032_checkin_details_prompt',
        screen: 'Check-in · Details',
        state: 'tags + note field with the guided prompt',
        source: 'CheckInDetails in CheckInScreen',
      );
      await tapKey(tester, 'tag-study');
      await tapKey(tester, 'tag-sleep');
      await tester.ensureVisible(note);
      await tester.enterText(
        note,
        'Slept four hours again. Everything feels heavier than it is.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await frames(tester, frames: 6);
      await cap.shoot(
        '033_checkin_details_typed',
        screen: 'Check-in · Details',
        state: '2 tags picked, note typed',
        source: 'CheckInDetails in CheckInScreen',
      );
      final record = find.byKey(const ValueKey('voice-record'));
      await reveal(tester, record);
      await tapFinder(tester, record, settleIo: true);
      // The mic is already allowed here; an explainer would ask first.
      if (find.byKey(const ValueKey('voice-allow')).evaluate().isNotEmpty) {
        await tapKey(tester, 'voice-allow', settleIo: true);
      }
      await frames(tester, frames: 20, step: const Duration(milliseconds: 250));
      await cap.shoot(
        '034_checkin_voice_recording',
        screen: 'Check-in · Voice note',
        state: 'recording (~5 s)',
        source: 'VoiceNoteField in CheckInScreen',
      );
      await tapKey(tester, 'voice-stop', settleIo: true);
      await frames(tester, frames: 6);
      await cap.shoot(
        '035_checkin_voice_recorded',
        screen: 'Check-in · Voice note',
        state: 'recorded, ready to save',
        source: 'VoiceNoteField in CheckInScreen',
      );
    });

    captureTest('saved: companion', (tester, cap) async {
      await openCheckIn(tester, world(checkedIn: false));
      await pickMood(tester, 'joyful');
      await save(tester);
      await cap.shoot(
        '036_checkin_saved_companion',
        screen: 'Check-in · Saved moment',
        state: 'Sunrise mood: Starlight + companion line',
        source: 'CheckInScreen saved view',
      );
    });

    captureTest('saved: minute for you', (tester, cap) async {
      await openCheckIn(tester, world(checkedIn: false));
      await pickMood(tester, 'lonely');
      await save(tester);
      await cap.shoot(
        '037_checkin_saved_minute-for-you',
        screen: 'Check-in · Saved moment',
        state: 'Rain mood: companion + "A minute for you" + room offer',
        source: 'CheckInScreen saved view (MinuteForYouCard, RoomOfferButton)',
      );
    });

    captureTest('backfill', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await pushScreen(
        tester,
        c,
        CheckInScreen(backfillDay: testTime().today().addDays(-2)),
      );
      await cap.shoot(
        '039_checkin_backfill_mood-grid',
        screen: 'Check-in · Add a past day',
        state: 'backfill for Tue 6 Oct',
        source: 'CheckInScreen(backfillDay:) from History',
      );
      await pickMood(tester, 'calm');
      await save(tester);
      await cap.shoot(
        '040_checkin_backfill_saved',
        screen: 'Check-in · Add a past day',
        state: 'saved ("Added to your sky")',
        source: 'CheckInScreen(backfillDay:) saved view',
      );
    });
  });

  group('history', () {
    captureTest('list, entry, edit', (tester, cap) async {
      late World w;
      final c = await boot(tester, w = world(), seed: seedEveryday);
      await go(tester, c, Routes.insightsHistory);
      await cap.shoot(
        '041_history_list_default',
        screen: 'History',
        state: 'a year of check-ins, newest first',
        source: 'HistoryScreen (${Routes.insightsHistory})',
      );
      await push(tester, c, Routes.historyEntry(w.todayId!));
      await cap.shoot(
        '042_history_entry_today',
        screen: 'History · Check-in detail',
        state: 'today\'s check-in (editable for 24 h)',
        source: 'CheckInDetailScreen (${Routes.history}/:id)',
      );
      await tapKey(tester, 'history-edit');
      await frames(tester, frames: 6);
      await cap.shoot(
        '043_history_entry_editing',
        screen: 'History · Check-in detail',
        state: 'editing',
        source: 'CheckInDetailScreen edit mode',
      );
    });
  });
}
