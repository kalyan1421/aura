// Sanctuary, Sounds, capsules, rooms, Quiet Together and Breath Ripples.
import 'dart:async';

import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/net/aura_api.dart' show ApiException;
import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/features/capsules/capsule_composer_screen.dart';
import 'package:aura/src/features/capsules/capsule_detail_screen.dart';
import 'package:aura/src/features/capsules/capsule_draft.dart';
import 'package:aura/src/features/capsules/capsule_opening.dart';
import 'package:aura/src/features/capsules/capsules_list_screen.dart';
import 'package:aura/src/features/plus/gift_sheet.dart';
import 'package:aura/src/features/quiet/quiet_models.dart';
import 'package:aura/src/features/quiet/quiet_screen.dart';
import 'package:aura/src/features/reflections/reflection_compose_sheet.dart';
import 'package:aura/src/features/ripples/ripple_channel.dart';
import 'package:aura/src/features/ripples/ripple_screen.dart';
import 'package:aura/src/features/rooms/room_navigation.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_screen.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ripples_fakes.dart' as rip;
import '../rooms_fakes.dart' as rooms;
import 'capture_drive.dart';
import 'capture_harness.dart';
import 'capture_world.dart';
import 'captures_a.dart' show seedEveryday;

const rainJoin = RoomJoinRequest(quadrant: Quadrant.rain, moodId: 'lonely');

void sanctuaryAndCapsules() {
  group('sanctuary', () {
    captureTest('hub and activities', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await go(tester, c, Routes.sanctuary);
      await cap.shoot(
        '050_sanctuary_hub_top',
        screen: 'Sanctuary',
        state: 'top (orb, Today\'s minute, Breathe)',
        source: 'SanctuaryScreen (${Routes.sanctuary})',
      );
      await scrollBy(tester, 430);
      await cap.shoot(
        '051_sanctuary_hub_grounding',
        screen: 'Sanctuary',
        state: 'scrolled: grounding library',
        source: 'SanctuaryScreen (${Routes.sanctuary})',
      );
      await scrollToEnd(tester);
      await cap.shoot(
        '052_sanctuary_hub_end',
        screen: 'Sanctuary',
        state: 'scrolled to the end: Sounds + Future you',
        source: 'SanctuaryScreen (${Routes.sanctuary})',
      );
      await scrollBy(tester, -100000);
      await tapKey(tester, 'sanctuary-today');
      await frames(tester, frames: 8);
      await cap.shoot(
        '053_sanctuary_todays-minute_intro',
        screen: 'Sanctuary · Today\'s minute',
        state: 'activity opened from the Today card',
        source: 'StepsActivityScreen / BreatheSessionScreen (calmRoute)',
      );
    });

    captureTest('breathe', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await go(tester, c, Routes.sanctuary);
      await tapKey(tester, 'sanctuary-breathe');
      await frames(tester, frames: 8);
      await cap.shoot(
        '054_breathe_setup_default',
        screen: 'Sanctuary · Breathe',
        state: 'pattern choice before starting',
        source: 'BreatheSessionScreen',
      );
      await tapKey(tester, 'breathe-start');
      // Mid-inhale: about 2 s into the first 4 s breath in.
      await frames(tester, frames: 10, step: const Duration(milliseconds: 200));
      await cap.shoot(
        '055_breathe_running_mid-inhale',
        screen: 'Sanctuary · Breathe',
        state: 'running, mid-inhale',
        source: 'BreatheSessionScreen (BreathOrb)',
      );
    });

    captureTest('grounding', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await go(tester, c, Routes.sanctuary);
      final senses = find.byKey(const ValueKey('sanctuary-senses'));
      await reveal(tester, senses);
      await tapFinder(tester, senses);
      await frames(tester, frames: 8);
      await cap.shoot(
        '056_grounding_senses_intro',
        screen: 'Sanctuary · Grounding (5-4-3-2-1)',
        state: 'intro',
        source: 'StepsActivityScreen',
      );
      await tapKey(tester, 'steps-next');
      await tapKey(tester, 'steps-next');
      await frames(tester, frames: 6);
      await cap.shoot(
        '057_grounding_senses_step-3',
        screen: 'Sanctuary · Grounding (5-4-3-2-1)',
        state: 'step 3 (hear)',
        source: 'StepsActivityScreen',
      );
    });

    captureTest('sounds', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await pushScreen(tester, c, const SoundsScreen());
      await cap.shoot(
        '058_sounds_idle_wind-down-card',
        screen: 'Sanctuary · Sounds',
        state: 'nothing playing (night wind-down card on top)',
        source: 'SoundsScreen',
      );
      await tapKey(tester, 'sounds-toggle-rain');
      await tapKey(tester, 'sounds-toggle-brown_noise');
      await frames(tester, frames: 10, step: const Duration(milliseconds: 300));
      final timer = find.byKey(const ValueKey('sounds-timer'));
      await reveal(tester, timer);
      await tapFinder(tester, timer);
      await frames(tester, frames: 6);
      await cap.shoot(
        '059_sounds_timer_sheet',
        screen: 'Sanctuary · Sounds',
        state: 'timer sheet (2 layers playing)',
        source: '_TimerSheet in SoundsScreen',
      );
      await tapKey(tester, 'sounds-timer-15');
      await frames(tester, frames: 10, step: const Duration(milliseconds: 200));
      await scrollBy(tester, -100000);
      await cap.shoot(
        '060_sounds_playing_two-layers-timer',
        screen: 'Sanctuary · Sounds',
        state: 'rain + brown noise playing, 15-minute timer',
        source: 'SoundsScreen',
      );
      await scrollBy(tester, 500);
      await cap.shoot(
        '061_sounds_playing_mixer',
        screen: 'Sanctuary · Sounds',
        state: 'mixer scrolled (volumes, locked Plus stems)',
        source: 'SoundsScreen',
      );
      final pink = find.byKey(const ValueKey('sounds-toggle-pink_noise'));
      await reveal(tester, pink);
      await tapFinder(tester, pink);
      await frames(tester, frames: 8);
      await cap.shoot(
        '062_sounds_plus-stem_locked-note',
        screen: 'Sanctuary · Sounds',
        state: 'a locked Plus stem tapped: "Part of Aura Plus" note',
        source: 'showPlusNoteSheet',
      );
    });

    captureTest('sounds wind-down', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await pushScreen(tester, c, const SoundsScreen());
      await tapKey(tester, 'sounds-wind-down');
      await frames(tester, frames: 10, step: const Duration(milliseconds: 300));
      await scrollBy(tester, -100000);
      await cap.shoot(
        '063_sounds_wind-down_active',
        screen: 'Sanctuary · Sounds',
        state: 'night wind-down running',
        source: 'SoundsScreen (_WindDownCard)',
      );
    });
  });

  group('capsules', () {
    captureTest('list and sealed', (tester, cap) async {
      final c = await boot(
        tester,
        world(),
        seed: (w) async {
          await seedEveryday(w);
          await w.seedCapsules();
        },
      );
      await pushScreen(tester, c, const CapsulesListScreen());
      await cap.shoot(
        '070_capsules_list_sealed',
        screen: 'Capsules',
        state: 'a date capsule and a feeling capsule, sealed',
        source: 'CapsulesListScreen',
      );
      await pushScreen(tester, c, const CapsuleDetailScreen(id: 'cap-date'));
      await cap.shoot(
        '071_capsule_detail_sealed',
        screen: 'Capsule',
        state: 'sealed until 12 Mar 2027',
        source: 'CapsuleDetailScreen',
      );
    });

    captureTest('composer: date', (tester, cap) async {
      final c = await boot(
        tester,
        world(),
        seed: (w) async {
          await seedEveryday(w);
          await CapsuleDraftStore(KvStore(w.db)).save(
            CapsuleDraft(
              id: 'draft-1',
              title: 'For graduation-day me',
              text:
                  'I hope you still laugh at Ravi\'s terrible jokes. I hope '
                  'the fear you feel today turned into something useful.',
              kind: CapsuleUnlockKind.date,
              date: LocalDay.parse('2027-06-15'),
            ),
          );
        },
      );
      await pushScreen(tester, c, const CapsuleComposerScreen());
      await cap.shoot(
        '072_capsule_composer_top',
        screen: 'Capsule composer',
        state: 'title + note written',
        source: 'CapsuleComposerScreen',
      );
      await reveal(tester, find.byKey(const ValueKey('capsule-seal')));
      await cap.shoot(
        '073_capsule_composer_date',
        screen: 'Capsule composer',
        state: 'opens on a date (15 Jun 2027)',
        source: 'CapsuleComposerScreen',
      );
    });

    captureTest('composer: feeling', (tester, cap) async {
      final c = await boot(
        tester,
        world(),
        seed: (w) async {
          await seedEveryday(w);
          await CapsuleDraftStore(KvStore(w.db)).save(
            CapsuleDraft(
              id: 'draft-2',
              title: 'When it gets loud',
              text: 'This has passed before. Call Priya. Drink water.',
              kind: CapsuleUnlockKind.feeling,
              moodId: 'overwhelmed',
            ),
          );
        },
      );
      await pushScreen(tester, c, const CapsuleComposerScreen());
      await reveal(tester, find.byKey(const ValueKey('capsule-seal')));
      await cap.shoot(
        '074_capsule_composer_mood-trigger',
        screen: 'Capsule composer',
        state: 'opens on a feeling (Overwhelmed)',
        source: 'CapsuleComposerScreen',
      );
    });

    captureTest('opening', (tester, cap) async {
      final c = await boot(
        tester,
        world(),
        seed: (w) async {
          await seedEveryday(w);
          await w.seedCapsules(dueToday: true);
        },
      );
      await pushScreen(tester, c, const CapsuleOpeningScreen(id: 'cap-due'));
      await frames(tester, frames: 5, step: const Duration(milliseconds: 250));
      await cap.shoot(
        '075_capsule_opening_ceremony',
        screen: 'Capsule opening',
        state: 'ceremony (~1.5 s in)',
        source: 'CapsuleOpeningScreen',
      );
      await frames(tester, frames: 25, step: const Duration(milliseconds: 250));
      await settle(tester);
      await cap.shoot(
        '076_capsule_opening_opened',
        screen: 'Capsule opening',
        state: 'opened: the note',
        source: 'CapsuleOpeningScreen',
      );
    });
  });
}

void roomsQuietRipples() {
  group('rooms', () {
    captureTest('rooms home', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await go(tester, c, Routes.rooms);
      await cap.shoot(
        '080_rooms_home_top',
        screen: 'Rooms',
        state: 'your rooms + a memory',
        source: 'RoomsHomeScreen (${Routes.rooms})',
      );
      final quiet = find.byKey(const ValueKey('quiet-card'));
      await reveal(tester, quiet);
      await cap.shoot(
        '081_rooms_home_quiet-together-card',
        screen: 'Rooms',
        state: 'scrolled: Quiet Together entry card',
        source: 'QuietTogetherCard on RoomsHomeScreen',
      );
    });

    captureTest('join: guidelines', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await push(tester, c, Routes.roomJoin, extra: rainJoin);
      await frames(tester, frames: 6);
      await cap.shoot(
        '083_rooms_join_guidelines',
        screen: 'Rooms · Join',
        state: 'first join: room guidelines sheet',
        source: 'RoomGuidelinesSheet (RoomJoinScreen, ${Routes.roomJoin})',
      );
    });

    captureTest('join: matching', (tester, cap) async {
      final w = world();
      w.roomsApi.hold = Completer<void>();
      final c = await boot(
        tester,
        w,
        seed: (w) async {
          await seedEveryday(w);
          await w.acceptGuidelines();
        },
      );
      await push(tester, c, Routes.roomJoin, extra: rainJoin);
      await frames(tester, frames: 8);
      await cap.shoot(
        '084_rooms_join_matching',
        screen: 'Rooms · Join',
        state: '"Finding people…"',
        source: 'RoomJoinScreen (${Routes.roomJoin})',
      );
    });

    captureTest('room', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await push(tester, c, Routes.room(rooms.roomId));
      await frames(tester, frames: 8);
      await cap.shoot(
        '085_room_lantern-hour_top',
        screen: 'Room',
        state: 'Lantern Hour: lantern 3/5, intention card, gesture received',
        source: 'RoomScreen (${Routes.rooms}/:id)',
      );
      await scrollBy(tester, 650);
      await cap.shoot(
        '086_room_lantern-hour_members',
        screen: 'Room',
        state: 'scrolled: members + gesture tray',
        source: 'RoomScreen (${Routes.rooms}/:id)',
      );
      final share = find.byKey(const ValueKey('reflections-section'));
      await reveal(tester, share);
      await scrollBy(tester, 250);
      await cap.shoot(
        '087_room_reflections_list',
        screen: 'Room · Reflections',
        state: 'yours pending + held, others published',
        source: 'ReflectionsSection in RoomScreen',
      );
      await scrollToEnd(tester);
      await cap.shoot(
        '088_room_reflections_end',
        screen: 'Room · Reflections',
        state: 'scrolled to the end',
        source: 'ReflectionsSection in RoomScreen',
      );
      await scrollBy(tester, -100000);
      final comet = find.byKey(const ValueKey('member-${rooms.cometId}'));
      await reveal(tester, comet);
      await tapFinder(tester, comet);
      await frames(tester, frames: 6);
      await cap.shoot(
        '089_room_member-sheet_default',
        screen: 'Room · Member sheet',
        state: 'Quiet Comet: gestures, gift, mute, report, block',
        source: 'MemberSheet (showMemberSheet)',
      );
      await tapKey(tester, 'member-report');
      await frames(tester, frames: 6);
      await cap.shoot(
        '090_room_report-sheet_default',
        screen: 'Room · Report',
        state: 'report a member',
        source: 'ReportSheet (showReportSheet)',
      );
    });

    captureTest('reflection composer', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await push(tester, c, Routes.room(rooms.roomId));
      unawaited(showReflectionComposer(rootContext(c), roomId: rooms.roomId));
      await frames(tester, frames: 8);
      await tester.enterText(
        find.byType(TextField).last,
        'Tonight the rain made me miss my grandmother\'s kitchen.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await frames(tester, frames: 6);
      await cap.shoot(
        '091_room_reflection-composer_typed',
        screen: 'Room · Share a reflection',
        state: 'text typed',
        source: 'ReflectionComposeSheet (showReflectionComposer)',
      );
    });

    captureTest('gift sheet', (tester, cap) async {
      final c = await boot(tester, world(), seed: seedEveryday);
      await push(tester, c, Routes.room(rooms.roomId));
      unawaited(
        showGiftSheet(
          rootContext(c),
          roomId: rooms.roomId,
          memberId: rooms.cometId,
        ),
      );
      await settle(tester);
      await cap.shoot(
        '092_room_gift-sheet_default',
        screen: 'Room · Send a gift',
        state: 'three gifts with store prices',
        source: 'GiftSheet (showGiftSheet)',
      );
    });

    captureTest('room memory', (tester, cap) async {
      final w = world();
      w.roomsApi.detail = rooms.detailJson(state: 'memory', hereNow: 0);
      final c = await boot(tester, w, seed: seedEveryday);
      await push(tester, c, Routes.room(rooms.roomId));
      await cap.shoot(
        '093_room_memory_default',
        screen: 'Room',
        state: 'a memory (read-only, after 24 h)',
        source: 'RoomScreen (state: memory)',
      );
      await scrollToEnd(tester);
      await cap.shoot(
        '094_room_memory_end',
        screen: 'Room',
        state: 'memory, scrolled to the end',
        source: 'RoomScreen (state: memory)',
      );
    });

    captureTest('paused', (tester, cap) async {
      final c = await boot(
        tester,
        world(
          flags: const RemoteFlags({
            RemoteFlags.roomsEnabledKey: FlagValue(enabled: false),
          }),
        ),
        seed: seedEveryday,
      );
      await go(tester, c, Routes.rooms);
      await cap.shoot(
        '096_rooms_home_paused',
        screen: 'Rooms',
        state: 'rooms kill switch off',
        source: 'RoomsHomeScreen (rooms_enabled off)',
      );
    });

    captureTest('lantern wind-down', (tester, cap) async {
      final w = world()..windDownView = openWindDown();
      final c = await boot(tester, w, seed: seedEveryday);
      await push(tester, c, Routes.room(rooms.roomId));
      final card = find.byKey(const ValueKey('wind-down-card'));
      await reveal(tester, card);
      await cap.shoot(
        '097_room_wind-down_card',
        screen: 'Room · Lantern Hour wind-down',
        state: 'entry card ("4 winding down")',
        source: 'WindDownEntry in RoomScreen',
      );
      await tapKey(tester, 'wind-down-join', settleIo: true);
      await frames(tester, frames: 10, step: const Duration(milliseconds: 200));
      await cap.shoot(
        '098_wind-down_session_running',
        screen: 'Lantern Hour wind-down',
        state: 'joined: pacer + cue',
        source: 'WindDownScreen',
      );
    });
  });

  group('quiet together', () {
    captureTest('session', (tester, cap) async {
      final w = world();
      final c = await boot(tester, w, seed: seedEveryday);
      quietWall = DateTime.utc(2027, 3, 10, 13, 50).millisecondsSinceEpoch;
      await pushScreen(
        tester,
        c,
        QuietScreen(
          mode: QuietMode.study,
          wallMs: () => quietWall,
          isOnline: () => true,
        ),
      );
      await settle(tester);
      final sw = find.byKey(const ValueKey('quiet-rhythm-switch'));
      await reveal(tester, sw);
      await tapFinder(tester, sw);
      await scrollBy(tester, -100000);
      await cap.shoot(
        '100_quiet_session_study-rhythm',
        screen: 'Quiet Together',
        state: 'study mode, 7 here, 25/5 rhythm on',
        source: 'QuietScreen(mode: study)',
      );
      await scrollToEnd(tester);
      await cap.shoot(
        '101_quiet_session_scrolled',
        screen: 'Quiet Together',
        state: 'scrolled: shared sound, gestures, leave',
        source: 'QuietScreen(mode: study)',
      );
      w.quietChannels.last.status(RippleLinkStatus.error);
      w.quiet.beatError = const ApiException(
        code: 'connectionError',
        isNetwork: true,
      );
      for (var i = 0; i < 64; i++) {
        quietWall += 500;
        await tester.pump(const Duration(milliseconds: 500));
      }
      await scrollBy(tester, -100000);
      await cap.shoot(
        '102_quiet_session_reconnecting',
        screen: 'Quiet Together',
        state: 'connection dropped: "Reconnecting…"',
        source: 'QuietScreen(mode: study)',
      );
    });
  });

  group('breath ripples', () {
    captureTest('lobby', (tester, cap) async {
      final w = world();
      w.ripples.waitPolls = 1000;
      final c = await boot(tester, w, seed: seedEveryday);
      await pushScreen(tester, c, RippleScreen(wallMs: () => rip.fakeWallMs));
      await frames(tester, frames: 8, step: const Duration(milliseconds: 250));
      await cap.shoot(
        '105_ripples_lobby_looking',
        screen: 'Breath Ripples',
        state: 'lobby: "Looking for others…" with the pacer',
        source: 'RippleScreen(entry: quick)',
      );
    });

    captureTest('session and end', (tester, cap) async {
      final w = world();
      w.ripples.waitPolls = 0;
      final c = await boot(tester, w, seed: seedEveryday);
      await pushScreen(tester, c, RippleScreen(wallMs: () => rip.fakeWallMs));
      Future<void> run(Duration d) async {
        var left = d;
        const step = Duration(milliseconds: 250);
        while (left > Duration.zero) {
          await tester.pump(step);
          left -= step;
        }
      }

      await run(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 50));
      await cap.shoot(
        '106_ripples_session_settle',
        screen: 'Breath Ripples',
        state: 'matched: "Settle in" (2 people, 1 echo, 1 guide)',
        source: 'RippleScreen',
      );
      await run(const Duration(milliseconds: 13750));
      await cap.shoot(
        '107_ripples_session_three-lights',
        screen: 'Breath Ripples',
        state: 'in session with 3 other lights',
        source: 'RippleScreen (OceanPainter)',
      );
      await run(const Duration(seconds: 40));
      await settle(tester);
      await cap.shoot(
        '108_ripples_end_default',
        screen: 'Breath Ripples',
        state: 'end screen',
        source: 'RippleScreen (end)',
      );
    });
  });
}
