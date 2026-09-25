import 'dart:ui' as ui;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';

import '../avatar/aura_avatar_painter.dart';
import '../avatar/avatar_assets.dart';

/// Renders the avatar's Still tier (PRD F2 renderer tiers: "home widget and
/// share-card snapshots, a PNG drawn from the same state") to PNG bytes.
typedef AvatarSnapshotter = Future<Uint8List?> Function(AuraAvatarState state);

/// Pixel size of the widget avatar (fits the small widget at 3x).
const int widgetAvatarPixels = 384;

/// Paints [state] with the shared painter (no shaders, one frame) off
/// screen. `null` when it can't be drawn; the widget then shows a star.
Future<Uint8List?> renderAvatarPng(
  AuraAvatarState state,
  AvatarAssets? assets, {
  int pixels = widgetAvatarPixels,
}) async {
  try {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = ui.Size.square(pixels.toDouble());
    AuraAvatarPainter(
      state: state,
      time: ValueNotifier<double>(0),
      assets: assets,
      tier: AvatarTier.still,
      useShaders: false,
    ).paint(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(pixels, pixels);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  } catch (e) {
    debugPrint('widget: avatar snapshot failed (${e.runtimeType})');
    return null;
  }
}
