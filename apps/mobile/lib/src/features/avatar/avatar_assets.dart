import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'avatar_manifest.dart';

part 'avatar_assets.g.dart';

/// Everything the renderer needs, loaded once. Any part may be missing: the
/// painter degrades (shader → painter-only → plain base → painted orb) and is
/// never blank (REQ-AVA-07).
class AvatarAssets {
  AvatarAssets({
    required this.manifest,
    required this.base,
    required this.glowProgram,
    required this.nebulaProgram,
  });

  static const String glowShader = 'shaders/aura_glow.frag';
  static const String nebulaShader = 'shaders/aura_nebula.frag';

  final AvatarManifest? manifest;
  final ui.Image? base;
  final ui.FragmentProgram? glowProgram;
  final ui.FragmentProgram? nebulaProgram;

  bool get hasShaders => glowProgram != null;

  /// Loads assets; each failure is logged (no user content) and tolerated.
  static Future<AvatarAssets> load({
    AssetBundle? bundle,
    bool shaders = true,
  }) async {
    final b = bundle ?? rootBundle;
    AvatarManifest? manifest;
    try {
      manifest = await AvatarManifest.load(b);
    } catch (e) {
      debugPrint('avatar: manifest failed (${e.runtimeType})');
    }

    ui.Image? base;
    for (final name in [
      manifest?.base ?? 'aura_base.webp',
      manifest?.fallbackBase ?? 'aura_base.png',
    ]) {
      try {
        base = await _decode(b, '${AvatarManifest.assetDir}$name');
        break;
      } catch (e) {
        debugPrint('avatar: base $name failed (${e.runtimeType})');
      }
    }

    ui.FragmentProgram? glow;
    ui.FragmentProgram? nebula;
    if (shaders) {
      try {
        glow = await ui.FragmentProgram.fromAsset(glowShader);
        nebula = await ui.FragmentProgram.fromAsset(nebulaShader);
      } catch (e) {
        // Painter-only fallback; retried next launch.
        debugPrint('avatar: shader failed (${e.runtimeType})');
        glow = null;
        nebula = null;
      }
    }
    return AvatarAssets(
      manifest: manifest,
      base: base,
      glowProgram: glow,
      nebulaProgram: nebula,
    );
  }

  static Future<ui.Image> _decode(AssetBundle bundle, String key) async {
    final data = await bundle.load(key);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }
}

@Riverpod(keepAlive: true)
Future<AvatarAssets> avatarAssets(Ref ref) => AvatarAssets.load();
