// Store screenshots (App Store 6.9" and Google Play phone): the same capture
// world as the design captures, rendered at the store's exact pixel sizes,
// English, with Aura Plus switched OFF (`plus_enabled`, as v1.0 ships), and
// written as opaque RGB PNGs (no alpha channel: App Store Connect refuses
// transparent screenshots) to apps/mobile/store/<platform>/screenshots/en-US/.
//
//   cd apps/mobile
//   flutter test --tags capture --run-skipped test/design_capture/store_capture_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aura/src/core/theme/aura_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_harness.dart';

/// A store screenshot size: logical points × ratio = the required pixels.
class StoreDevice {
  const StoreDevice({
    required this.name,
    required this.size,
    required this.ratio,
    required this.topInset,
    required this.bottomInset,
    required this.platform,
    required this.outDir,
  });

  final String name;
  final Size size;
  final double ratio;
  final double topInset;
  final double bottomInset;
  final TargetPlatform platform;
  final String outDir;

  int get pixelWidth => (size.width * ratio).round();
  int get pixelHeight => (size.height * ratio).round();
}

/// App Store 6.9" display (iPhone 16 Pro Max class): 440×956 pt @3x =
/// 1320×2868 px, its safe areas (62 pt Dynamic Island band, 34 pt home
/// indicator). No status bar is drawn: the band shows the app's own sky.
const StoreDevice ios69 = StoreDevice(
  name: 'App Store 6.9"',
  size: Size(440, 956),
  ratio: 3,
  topInset: 62,
  bottomInset: 34,
  platform: TargetPlatform.iOS,
  outDir: 'store/ios/screenshots/en-US',
);

/// Google Play phone, 9:16: 1080×1920 px (Play: 320–3840 px, long side ≤ 2×
/// the short one; 9:16 at 1080×1920 meets the promotion minimum). Rendered as
/// a 411×731 dp phone at 2.625 (a common Android density), so the layout has
/// a modern phone's width instead of a cramped 360×640. 24 dp status bar
/// band, gesture navigation (no bottom bar).
const StoreDevice play916 = StoreDevice(
  name: 'Google Play phone 9:16',
  size: Size(1080 / 2.625, 1920 / 2.625),
  ratio: 2.625,
  topInset: 24,
  bottomInset: 0,
  platform: TargetPlatform.android,
  outDir: 'store/android/screenshots/en-US',
);

/// The phone view for [d] (size, DPR, safe areas, 100 % text).
void setStoreDevice(WidgetTester tester, StoreDevice d) {
  tester.view.physicalSize = d.size * d.ratio;
  tester.view.devicePixelRatio = d.ratio;
  final insets = FakeViewPadding(
    top: d.topInset * d.ratio,
    bottom: d.bottomInset * d.ratio,
  );
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  tester.platformDispatcher.textScaleFactorTestValue = 1;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Errors reported while each shot was built (overflows included).
final Map<String, List<String>> storeIssues = {};

/// Grabs the whole app as `<d.outDir>/<file>.png`, flattened onto the app's
/// deepest sky colour and written as 8-bit RGB (no alpha).
Future<void> storeShot(
  WidgetTester tester,
  StoreDevice d,
  String file,
  List<String> pending,
) async {
  storeIssues['${d.outDir}/$file.png'] = [...pending];
  pending.clear();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureRootKey),
    );
    final image = await boundary.toImage(pixelRatio: d.ratio);
    final w = image.width;
    final h = image.height;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    image.dispose();
    if (w != d.pixelWidth || h != d.pixelHeight) {
      throw StateError('$file: ${w}x$h, expected ${d.pixelWidth}x${d.pixelHeight}');
    }
    final png = encodeRgbPng(
      data!.buffer.asUint8List(),
      w,
      h,
      background: AuraColors.skyDeep,
    );
    Directory(d.outDir).createSync(recursive: true);
    File('${d.outDir}/$file.png').writeAsBytesSync(png);
  });
}

/// A truecolour PNG (colour type 2, 8 bits, no alpha) from straight RGBA
/// pixels composited over [background].
Uint8List encodeRgbPng(
  Uint8List rgba,
  int width,
  int height, {
  required Color background,
}) {
  final br = (background.r * 255).round();
  final bg = (background.g * 255).round();
  final bb = (background.b * 255).round();
  final raw = Uint8List(height * (1 + width * 3));
  var o = 0;
  var i = 0;
  for (var y = 0; y < height; y++) {
    raw[o++] = 0; // filter: none
    for (var x = 0; x < width; x++) {
      final a = rgba[i + 3];
      if (a == 255) {
        raw[o++] = rgba[i];
        raw[o++] = rgba[i + 1];
        raw[o++] = rgba[i + 2];
      } else {
        // Straight (unpremultiplied) RGBA: composite "over" the background.
        raw[o++] = (rgba[i] * a + br * (255 - a)) ~/ 255;
        raw[o++] = (rgba[i + 1] * a + bg * (255 - a)) ~/ 255;
        raw[o++] = (rgba[i + 2] * a + bb * (255 - a)) ~/ 255;
      }
      i += 4;
    }
  }
  final out = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> body) {
    final t = type.codeUnits;
    out
      ..add(_u32(body.length))
      ..add(t)
      ..add(body)
      ..add(_u32(_crc32([...t, ...body])));
  }

  chunk('IHDR', [
    ..._u32(width),
    ..._u32(height),
    8, // bit depth
    2, // colour type: truecolour (RGB)
    0, 0, 0, // compression, filter, interlace
  ]);
  chunk('IDAT', ZLibEncoder(level: 9).convert(raw));
  chunk('IEND', const []);
  return out.toBytes();
}

List<int> _u32(int v) => [
  (v >> 24) & 0xff,
  (v >> 16) & 0xff,
  (v >> 8) & 0xff,
  v & 0xff,
];

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xff] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// A store screenshot test on [d]: the platform is [StoreDevice.platform]
/// (switches, back icons and scroll physics as on that phone), errors are
/// recorded against the next shot, and the tree is unmounted at the end.
void storeTest(
  StoreDevice d,
  String description,
  Future<void> Function(WidgetTester tester, List<String> pending) body,
) {
  testWidgets('${d.name}: $description', (tester) async {
    final original = FlutterError.onError;
    final pending = <String>[];
    FlutterError.onError = (details) => pending.add(summarizeError(details));
    debugDefaultTargetPlatformOverride = d.platform;
    try {
      setStoreDevice(tester, d);
      await body(tester, pending);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 30));
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = original;
    }
  });
}
