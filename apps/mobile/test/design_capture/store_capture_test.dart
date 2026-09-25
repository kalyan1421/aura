// Store screenshots: 8 screens that tell Aura's story, for the App Store
// 6.9" display (1320×2868) and Google Play phones (1080×1920), English, with
// Aura Plus OFF (as v1.0 ships). Written to apps/mobile/store/ios/screenshots/
// en-US/ and apps/mobile/store/android/screenshots/en-US/ (committed store
// assets). Not part of the normal suite (the `capture` tag); run it with
//   cd apps/mobile
//   flutter test --tags capture --run-skipped test/design_capture/store_capture_test.dart
@Tags(['capture'])
library;

import 'dart:io';

import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/features/avatar/avatar_assets.dart';
import 'package:aura/src/features/capsules/capsule_opening.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../rooms_fakes.dart' as rooms;
import 'capture_drive.dart';
import 'capture_harness.dart';
import 'capture_world.dart';
import 'captures_a.dart' show openCheckIn, pickMood, save, seedEveryday;
import 'store_capture.dart';

/// v1.0 as it ships: signed in, a year of history, Plus switched off.
World storeWorld({bool checkedIn = true}) =>
    world(checkedIn: checkedIn, plusEnabled: false);

void storeScreens(StoreDevice d) {
  group(d.name, () {
    storeTest(d, '01 Home after the check-in', (tester, pending) async {
      await boot(tester, storeWorld(), seed: seedEveryday);
      await frames(tester, frames: 12);
      await storeShot(tester, d, '01_home', pending);
    });

    storeTest(d, '02 check-in mood grid', (tester, pending) async {
      await openCheckIn(tester, storeWorld(checkedIn: false));
      await pickMood(tester, 'content');
      // Tapping scrolled the grid on shorter phones: back to the question.
      await scrollBy(tester, -100000);
      await frames(tester, frames: 8);
      await storeShot(tester, d, '02_checkin_mood_grid', pending);
    });

    storeTest(d, '03 saved + "A minute for you"', (tester, pending) async {
      await openCheckIn(tester, storeWorld(checkedIn: false));
      await pickMood(tester, 'lonely');
      await save(tester);
      await storeShot(tester, d, '03_checkin_saved_minute_for_you', pending);
    });

    storeTest(d, '04 Sanctuary: Breathe', (tester, pending) async {
      final c = await boot(tester, storeWorld(), seed: seedEveryday);
      await go(tester, c, Routes.sanctuary);
      await tapKey(tester, 'sanctuary-breathe');
      await frames(tester, frames: 8);
      await tapKey(tester, 'breathe-start');
      // Mid-inhale: about 2 s into the first breath in.
      await frames(tester, frames: 10, step: const Duration(milliseconds: 200));
      await storeShot(tester, d, '04_sanctuary_breathe', pending);
    });

    storeTest(d, '05 a room in Lantern Hour', (tester, pending) async {
      final c = await boot(tester, storeWorld(), seed: seedEveryday);
      await push(tester, c, Routes.room(rooms.roomId));
      await frames(tester, frames: 8);
      await storeShot(tester, d, '05_room_lantern_hour', pending);
    });

    storeTest(d, '06 Aura Sky (the year)', (tester, pending) async {
      final c = await boot(tester, storeWorld(), seed: seedEveryday);
      await go(tester, c, Routes.insights);
      final sky = find.byKey(const ValueKey('sky-view-switch'));
      await reveal(tester, sky);
      await tapFinder(
        tester,
        find.descendant(of: sky, matching: find.text('Year')),
      );
      await reveal(tester, sky);
      await scrollBy(tester, -24);
      await storeShot(tester, d, '06_insights_aura_sky', pending);
    });

    storeTest(d, '07 a Future-you capsule opens', (tester, pending) async {
      final c = await boot(
        tester,
        storeWorld(),
        seed: (w) async {
          await seedEveryday(w);
          await w.seedCapsules(dueToday: true);
        },
      );
      await pushScreen(tester, c, const CapsuleOpeningScreen(id: 'cap-due'));
      await frames(tester, frames: 30, step: const Duration(milliseconds: 250));
      await settle(tester);
      await storeShot(tester, d, '07_future_you_capsule', pending);
    });

    storeTest(d, '08 Safety Center', (tester, pending) async {
      final c = await boot(tester, storeWorld(), seed: seedEveryday);
      await push(tester, c, Routes.safety);
      await storeShot(tester, d, '08_safety_center', pending);
    });
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    captureFonts = await loadCaptureFonts();
    captureAssets = await AvatarAssets.load();
  });
  tearDownAll(() {
    // Rendering errors per shot (overflow stripes would show in the PNG).
    final b = StringBuffer();
    for (final e in storeIssues.entries) {
      if (e.value.isEmpty) continue;
      b.writeln('${e.key}:');
      for (final m in e.value.toSet()) {
        b.writeln('  - $m');
      }
    }
    Directory('build/design_capture').createSync(recursive: true);
    File(
      'build/design_capture/STORE_ISSUES.txt',
    ).writeAsStringSync(b.isEmpty ? 'None.\n' : b.toString());
    // ignore: avoid_print
    print('[store] issues:\n${b.isEmpty ? 'none' : b}');
  });

  storeScreens(ios69);
  storeScreens(play916);
}
