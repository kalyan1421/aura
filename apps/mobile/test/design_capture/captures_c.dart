// Insights (Aura Sky), keepsakes and share cards, Plus, Settings, safety,
// and the Telugu / Hindi / 200% text passes.
import 'dart:async';

import 'package:aura/src/core/entitlements/entitlement.dart';
import 'package:aura/src/core/remote_config/device_ban.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/features/insights/look_back_screen.dart';
import 'package:aura/src/features/keepsakes/keepsakes_screen.dart'
    show keepsakesRoute;
import 'package:aura/src/features/plus/plus_entry.dart';
import 'package:aura/src/features/share/share_card_data.dart';
import 'package:aura/src/features/share/share_sheet.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:aura/src/features/update/update_required.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../plus_fakes.dart';
import '../rooms_fakes.dart' as rooms;
import 'capture_drive.dart';
import 'capture_harness.dart';
import 'captures_a.dart' show seedEveryday;
import 'captures_b.dart' show rainJoin;

final _avatar = AuraAvatarState(
  stage: AuraStage.glow,
  hue: 210,
  ringCount: 2,
  glowLevel: 2,
  equippedCosmetics: const {'first_light'},
);

void insightsKeepsakesPlus() {
  group('insights', () {
    captureTest('aura sky', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await go(tester, c, Routes.insights);
      await cap.shoot(
        '110_insights_top_weekly-month-cards',
        screen: 'Insights (Aura Sky)',
        state: 'top: month-in-stars card',
        source: 'InsightsScreen (${Routes.insights})',
      );
      final sky = find.byKey(const ValueKey('sky-view-switch'));
      await reveal(tester, sky);
      await cap.shoot(
        '111_insights_sky_month',
        screen: 'Insights (Aura Sky)',
        state: 'sky calendar, month view (October)',
        source: 'SkyCalendar in InsightsScreen',
      );
      await tapFinder(
        tester,
        find.descendant(of: sky, matching: find.text('Year')),
      );
      await cap.shoot(
        '112_insights_sky_year',
        screen: 'Insights (Aura Sky)',
        state: 'sky calendar, year view (2026)',
        source: 'SkyCalendar in InsightsScreen',
      );
      await tapFinder(
        tester,
        find.descendant(of: sky, matching: find.text('Month')),
      );
      await scrollBy(tester, 550);
      await cap.shoot(
        '113_insights_patterns_free',
        screen: 'Insights (Aura Sky)',
        state: 'patterns (free: Plus depth locked)',
        source: 'InsightsScreen _PatternsSection',
      );
      await scrollToEnd(tester);
      await cap.shoot(
        '114_insights_end_look-back-keepsakes',
        screen: 'Insights (Aura Sky)',
        state: 'end: lifetime, Look back entry, keepsakes, all check-ins',
        source: 'InsightsScreen',
      );
      final day = find.byKey(
        ValueKey('sky-day-${testTime().today().addDays(-1).toIso()}'),
      );
      await reveal(tester, find.byKey(const ValueKey('sky-view-switch')));
      if (day.evaluate().isNotEmpty) {
        await tapFinder(tester, day);
        await frames(tester, frames: 6);
        await cap.shoot(
          '115_insights_day-sheet_yesterday',
          screen: 'Insights · Day',
          state: 'a day tapped in the sky (yesterday)',
          source: 'showDaySheet',
        );
      }
    });

    captureTest('care card', (tester, cap) async {
      final c = await boot(
        tester,
        world(),
        seed: (w) async {
          await w.seedHistory(heavyWeek: true);
          await w.seedKeepsakes();
        },
      );
      await go(tester, c, Routes.insights);
      await cap.shoot(
        '116_insights_care-card_heavy-week',
        screen: 'Insights (Aura Sky)',
        state: 'a heavy week: care card',
        source: 'CareCard in InsightsScreen',
      );
    });

    captureTest('plus patterns', (tester, cap) async {
      final c = await boot(
        tester,
        world(entitlement: plusAccount(status: PlusStatus.active)),
        seed: seedEveryday,
      );
      await go(tester, c, Routes.insights);
      await reveal(tester, find.byKey(const ValueKey('sky-view-switch')));
      await scrollBy(tester, 550);
      await cap.shoot(
        '117_insights_patterns_plus',
        screen: 'Insights (Aura Sky)',
        state: 'patterns with Plus',
        source: 'InsightsScreen _PatternsSection',
      );
      await push(tester, c, Routes.insightsMonth);
      await cap.shoot(
        '118_month-in-stars_plus_top',
        screen: 'Your month in stars',
        state: 'September, with Plus',
        source: 'MonthInStarsScreen (${Routes.insightsMonth})',
      );
      await scrollToEnd(tester);
      await cap.shoot(
        '119_month-in-stars_plus_end',
        screen: 'Your month in stars',
        state: 'September, with Plus, scrolled',
        source: 'MonthInStarsScreen (${Routes.insightsMonth})',
      );
    });

    captureTest('month in stars free', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await go(tester, c, Routes.insights);
      await push(tester, c, Routes.insightsMonth);
      await cap.shoot(
        '120_month-in-stars_free_top',
        screen: 'Your month in stars',
        state: 'September, free',
        source: 'MonthInStarsScreen (${Routes.insightsMonth})',
      );
      await scrollToEnd(tester);
      await cap.shoot(
        '121_month-in-stars_free_plus-locked',
        screen: 'Your month in stars',
        state: 'free: the Plus-locked "deeper" part',
        source: 'MonthInStarsScreen (${Routes.insightsMonth})',
      );
    });

    captureTest('look back', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await go(tester, c, Routes.insights);
      await pushScreen(tester, c, const LookBackScreen());
      await cap.shoot(
        '122_look-back_weeks_top',
        screen: 'Look back',
        state: '1 month / 6 months / 1 year ago',
        source: 'LookBackScreen (from Insights)',
      );
    });
  });

  group('keepsakes and share', () {
    captureTest('keepsakes box', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await push(tester, c, keepsakesRoute);
      await cap.shoot(
        '125_keepsakes_box_six',
        screen: 'Keepsakes',
        state: 'six keepsakes earned',
        source: 'KeepsakesScreen ($keepsakesRoute)',
      );
    });

    final cards = <(String, String, ShareCardData)>[
      (
        '126_share_evolution_preview',
        'Evolution',
        ShareCardData.evolution(_avatar),
      ),
      (
        '127_share_glow_preview',
        'Glow days (30)',
        ShareCardData.glow(_avatar, 30),
      ),
      (
        '128_share_capsule-anniversary_preview',
        'Capsule anniversary (1 year)',
        ShareCardData.capsuleAnniversary(_avatar, 1),
      ),
      (
        '129_share_keepsake_preview',
        'Keepsake (Lantern Hour)',
        ShareCardData.keepsake(_avatar, 'lantern_hours_1'),
      ),
    ];
    for (final (file, what, data) in cards) {
      captureTest('share $what', (tester, cap) async {
        final c = await boot(tester, world(), seed: seedEveryday);
        unawaited(showShareCardSheet(rootContext(c), data));
        await settle(tester);
        await frames(tester, frames: 6);
        await cap.shoot(
          file,
          screen: 'Share card preview',
          state: what,
          source: 'ShareCardSheet (showShareCardSheet)',
        );
      });
    }
  });

  group('plus', () {
    captureTest('paywall', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await push(tester, c, '$plusRoute?from=settings');
      await cap.shoot(
        '130_plus_paywall_top',
        screen: 'Aura Plus paywall',
        state: 'free account, trial offered (App Store prices)',
        source: 'PaywallScreen ($plusRoute)',
      );
      await scrollToEnd(tester);
      await cap.shoot(
        '131_plus_paywall_end',
        screen: 'Aura Plus paywall',
        state: 'scrolled: cancel steps, restore, terms',
        source: 'PaywallScreen ($plusRoute)',
      );
    });

    captureTest('sky themes', (tester, cap) async {
      final c = await boot(
        tester,
        world(entitlement: plusAccount(status: PlusStatus.active)),
        seed: seedEveryday,
      );
      await push(tester, c, plusSkiesRoute);
      await cap.shoot(
        '132_plus_sky-themes_top',
        screen: 'Sky themes',
        state: 'with Plus',
        source: 'SkyThemesScreen ($plusSkiesRoute)',
      );
      await scrollToEnd(tester);
      await cap.shoot(
        '133_plus_sky-themes_end',
        screen: 'Sky themes',
        state: 'with Plus, scrolled',
        source: 'SkyThemesScreen ($plusSkiesRoute)',
      );
    });

    captureTest('sky themes free', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await push(tester, c, plusSkiesRoute);
      await cap.shoot(
        '134_plus_sky-themes_free',
        screen: 'Sky themes',
        state: 'free account',
        source: 'SkyThemesScreen ($plusSkiesRoute)',
      );
    });
  });
}

void settingsAndSafety() {
  group('settings', () {
    captureTest('sections', (tester, cap) async {
      final c = await boot(
        tester,
        world(entitlement: plusAccount()),
        seed: seedEveryday,
      );
      await push(tester, c, Routes.settings);
      await cap.shoot(
        '140_settings_top_default',
        screen: 'Settings',
        state: 'top (language)',
        source: 'SettingsScreen (${Routes.settings})',
      );
      for (final (n, key, what) in [
        (141, 'comfort', 'Comfort'),
        (142, 'notifications', 'Notifications'),
        (143, 'widget', 'Home-screen widget'),
        (144, 'account', 'Account'),
        (145, 'plus', 'Help & safety, Aura Plus (trial), About (end)'),
      ]) {
        final f = find.byKey(ValueKey('set-section-$key'));
        if (!await reveal(tester, f)) {
          // ignore: avoid_print
          print('[capture] settings: no $key section');
          continue;
        }
        final top = tester.getTopLeft(f).dy;
        await scrollBy(tester, top - 120);
        await cap.shoot(
          '${n}_settings_${key}_section',
          screen: 'Settings',
          state: '$what section',
          source: 'SettingsScreen (${Routes.settings})',
        );
      }
    });

    captureTest('delete account', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await push(tester, c, Routes.deleteAccount);
      await cap.shoot(
        '147_settings_delete-account_default',
        screen: 'Delete account',
        state: 'before confirming',
        source: 'DeleteAccountScreen (${Routes.deleteAccount})',
      );
      final delete = find.byKey(const ValueKey('acct-delete'));
      if (delete.evaluate().isNotEmpty) {
        await tapFinder(tester, delete);
        await frames(tester, frames: 6);
        await cap.shoot(
          '148_settings_delete-account_confirm',
          screen: 'Delete account',
          state: 'confirm dialog',
          source: 'DeleteAccountScreen',
        );
      }
    });
  });

  group('safety', () {
    captureTest('safety center', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await push(tester, c, Routes.safety);
      await cap.shoot(
        '150_safety-center_top',
        screen: 'Safety Center',
        state: 'top (India)',
        source: 'SafetyCenterScreen (${Routes.safety})',
      );
      await scrollToEnd(tester);
      await cap.shoot(
        '151_safety-center_end',
        screen: 'Safety Center',
        state: 'scrolled to the end',
        source: 'SafetyCenterScreen (${Routes.safety})',
      );
    });

    captureTest('support sheet', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      unawaited(showSupportSheet(rootContext(c)));
      await settle(tester);
      await cap.shoot(
        '152_support-sheet_help-now',
        screen: 'Support sheet',
        state: '"I need help now"',
        source: 'SupportSheet (showSupportSheet)',
      );
    });

    captureTest('crisis sheet', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      unawaited(showSupportSheet(rootContext(c), crisis: true));
      await settle(tester);
      await cap.shoot(
        '153_support-sheet_crisis',
        screen: 'Support sheet',
        state: 'crisis (after a note that needs support)',
        source: 'SupportSheet(crisis: true)',
      );
    });

    captureTest('update required', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await pushScreen(
        tester,
        c,
        const UpdateRequiredScreen(platform: TargetPlatform.iOS),
      );
      await cap.shoot(
        '154_update-required_default',
        screen: 'Update required',
        state: 'forced update (iOS)',
        source: 'UpdateRequiredScreen (${Routes.updateRequired})',
      );
    });

    captureTest('device banned', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await pushScreen(tester, c, const DeviceBannedScreen());
      await cap.shoot(
        '155_device-banned_default',
        screen: 'Device banned',
        state: '"This device can\'t use Aura"',
        source: 'DeviceBannedScreen',
      );
    });
  });
}

/// The dense screens in Telugu or Hindi (run from capture_te_test.dart /
/// capture_hi_test.dart, each with its own fonts).
void localeCaptures(String locale) {
  {
    group('locale $locale', () {
      captureTest('home', (tester, cap) async {
        await boot(tester, world(locale: locale), seed: seedEveryday);
        await frames(tester, frames: 10);
        await cap.shoot(
          '2${locale == 'te' ? 0 : 1}0_home_today_checked-in_$locale',
          screen: 'Home',
          state: 'after today\'s check-in',
          source: 'HomeScreen (${Routes.home})',
        );
      }, locale: locale);

      captureTest('check-in', (tester, cap) async {
        final c = await boot(
          tester,
          world(locale: locale, checkedIn: false),
          seed: (w) => seedEveryday(w, checkedIn: false),
        );
        await push(tester, c, Routes.checkIn);
        await cap.shoot(
          '2${locale == 'te' ? 0 : 1}1_checkin_mood-grid_empty_$locale',
          screen: 'Check-in · Mood grid',
          state: 'nothing picked',
          source: 'CheckInScreen (${Routes.checkIn})',
        );
        await tapKey(tester, 'mood-lonely');
        await tapKey(tester, 'checkin-save', settleIo: true);
        await settle(tester);
        await frames(
          tester,
          frames: 15,
          step: const Duration(milliseconds: 200),
        );
        await cap.shoot(
          '2${locale == 'te' ? 0 : 1}2_checkin_saved_minute-for-you_$locale',
          screen: 'Check-in · Saved moment',
          state: 'Rain mood: companion + "A minute for you"',
          source: 'CheckInScreen saved view',
        );
      }, locale: locale);

      captureTest('sanctuary', (tester, cap) async {
        final c = await boot(tester, world(locale: locale), seed: seedEveryday);
        await go(tester, c, Routes.sanctuary);
        await cap.shoot(
          '2${locale == 'te' ? 0 : 1}3_sanctuary_hub_top_$locale',
          screen: 'Sanctuary',
          state: 'top',
          source: 'SanctuaryScreen (${Routes.sanctuary})',
        );
        await scrollBy(tester, 700);
        await cap.shoot(
          '2${locale == 'te' ? 0 : 1}4_sanctuary_hub_grounding_$locale',
          screen: 'Sanctuary',
          state: 'scrolled: grounding library',
          source: 'SanctuaryScreen (${Routes.sanctuary})',
        );
      }, locale: locale);

      captureTest('aura sky', (tester, cap) async {
        final c = await boot(tester, world(locale: locale), seed: seedEveryday);
        await go(tester, c, Routes.insights);
        await cap.shoot(
          '2${locale == 'te' ? 0 : 1}5_insights_top_$locale',
          screen: 'Insights (Aura Sky)',
          state: 'top: month-in-stars card',
          source: 'InsightsScreen (${Routes.insights})',
        );
        await reveal(tester, find.byKey(const ValueKey('sky-view-switch')));
        await cap.shoot(
          '2${locale == 'te' ? 0 : 1}6_insights_sky_month_$locale',
          screen: 'Insights (Aura Sky)',
          state: 'sky calendar, month view',
          source: 'SkyCalendar in InsightsScreen',
        );
      }, locale: locale);
      if (locale == 'hi') {
        captureTest('hindi pool choice', (tester, cap) async {
          final c = await boot(
            tester,
            world(locale: 'hi'),
            seed: (w) async {
              await seedEveryday(w);
              await w.acceptGuidelines();
            },
          );
          await push(tester, c, Routes.roomJoin, extra: rainJoin);
          await frames(tester, frames: 6);
          await cap.shoot(
            '095_rooms_join_hindi-pool-choice',
            screen: 'Rooms · Join',
            state: 'Hindi pool not open yet: English-room choice',
            source: 'RoomJoinScreen (rooms_pool_hi off)',
          );
        }, locale: 'hi');
      }
    });
  }
}

/// English at 200% text.
void largeTextCaptures() {
  group('200% text', () {
    captureTest('home', (tester, cap) async {
      await boot(tester, world(), seed: seedEveryday);
      await frames(tester, frames: 10);
      await cap.shoot(
        '230_home_today_checked-in_200pct',
        screen: 'Home',
        state: 'after today\'s check-in',
        source: 'HomeScreen (${Routes.home})',
      );
      await scrollBy(tester, 700);
      await cap.shoot(
        '231_home_today_scrolled_200pct',
        screen: 'Home',
        state: 'scrolled',
        source: 'HomeScreen (${Routes.home})',
      );
    }, scale: 2);

    captureTest('check-in', (tester, cap) async {
      final c = await boot(
        tester,
        world(checkedIn: false),
        seed: (w) => seedEveryday(w, checkedIn: false),
      );
      await push(tester, c, Routes.checkIn);
      await cap.shoot(
        '232_checkin_mood-grid_empty_200pct',
        screen: 'Check-in · Mood grid',
        state: 'nothing picked',
        source: 'CheckInScreen (${Routes.checkIn})',
      );
      await tapKey(tester, 'mood-lonely');
      await tapKey(tester, 'checkin-save', settleIo: true);
      await settle(tester);
      await frames(tester, frames: 15, step: const Duration(milliseconds: 200));
      await cap.shoot(
        '233_checkin_saved_minute-for-you_200pct',
        screen: 'Check-in · Saved moment',
        state: 'Rain mood',
        source: 'CheckInScreen saved view',
      );
    }, scale: 2);

    captureTest('room', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await push(tester, c, Routes.room(rooms.roomId));
      await frames(tester, frames: 8);
      await cap.shoot(
        '234_room_lantern-hour_top_200pct',
        screen: 'Room',
        state: 'Lantern Hour',
        source: 'RoomScreen (${Routes.rooms}/:id)',
      );
      await scrollBy(tester, 900);
      await cap.shoot(
        '235_room_lantern-hour_members_200pct',
        screen: 'Room',
        state: 'scrolled: members',
        source: 'RoomScreen (${Routes.rooms}/:id)',
      );
    }, scale: 2);

    captureTest('paywall', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await push(tester, c, '$plusRoute?from=settings');
      await cap.shoot(
        '236_plus_paywall_top_200pct',
        screen: 'Aura Plus paywall',
        state: 'free account',
        source: 'PaywallScreen ($plusRoute)',
      );
      await scrollBy(tester, 900);
      await cap.shoot(
        '237_plus_paywall_scrolled_200pct',
        screen: 'Aura Plus paywall',
        state: 'scrolled',
        source: 'PaywallScreen ($plusRoute)',
      );
    }, scale: 2);

    captureTest('settings', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await push(tester, c, Routes.settings);
      await cap.shoot(
        '238_settings_top_200pct',
        screen: 'Settings',
        state: 'top',
        source: 'SettingsScreen (${Routes.settings})',
      );
      await scrollBy(tester, 900);
      await cap.shoot(
        '239_settings_scrolled_200pct',
        screen: 'Settings',
        state: 'scrolled (Comfort)',
        source: 'SettingsScreen (${Routes.settings})',
      );
    }, scale: 2);
  });
}
