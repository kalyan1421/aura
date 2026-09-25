// Design capture: every screen of the app as a PNG in docs/design/screens/
// (with INDEX.md), for a design critique. English and 200% text here; the
// Telugu and Hindi passes are capture_te_test.dart / capture_hi_test.dart. Not part of the normal suite
// (dart_test.yaml skips the `capture` tag); run it with
//   cd apps/mobile
//   flutter test --tags capture --run-skipped test/design_capture
@Tags(['capture'])
library;

import 'package:aura/src/features/avatar/avatar_assets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_drive.dart';
import 'capture_harness.dart';
import 'captures_a.dart';
import 'captures_b.dart';
import 'captures_c.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    captureFonts = await loadCaptureFonts();
    captureAssets = await AvatarAssets.load();
  });
  tearDownAll(() => writeIndex(fonts: captureFonts));

  onboardingAndHome();
  checkInAndHistory();
  sanctuaryAndCapsules();
  roomsQuietRipples();
  insightsKeepsakesPlus();
  settingsAndSafety();
  largeTextCaptures();
}
