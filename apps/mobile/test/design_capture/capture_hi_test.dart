// Design capture in Hindi (hi): the dense screens, to check script
// overflow. Its own test file because the fonts differ (see
// loadCaptureFonts). Run with the rest:
//   flutter test --tags capture --run-skipped test/design_capture
@Tags(['capture'])
library;

import 'package:aura/src/features/avatar/avatar_assets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_drive.dart';
import 'capture_harness.dart';
import 'captures_c.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    captureFonts = await loadCaptureFonts(script: 'hi');
    captureAssets = await AvatarAssets.load();
  });
  tearDownAll(() => writeIndex(fonts: captureFonts));

  localeCaptures('hi');
}
