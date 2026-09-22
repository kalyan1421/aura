import 'dart:ui' as ui;

import 'package:aura/src/features/avatar/aura_avatar.dart';
import 'package:aura/src/features/avatar/aura_avatar_painter.dart';
import 'package:aura/src/features/avatar/avatar_assets.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late AvatarAssets assets;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    assets = await AvatarAssets.load();
  });

  test('assets: base art decodes (WebP), manifest parses, rings resampled', () {
    expect(assets.base, isNotNull);
    expect(assets.base!.width, 1145);
    expect(assets.base!.height, 1374);
    final m = assets.manifest!;
    expect(m.bakedRings, 2);
    expect(m.rings, hasLength(3));
    expect(m.rings.first.samples, hasLength(240));
    expect(m.brow.dy, closeTo(0.354, 0.01));
    expect(m.heart.dy, closeTo(0.622, 0.01));
    // The gold ring crosses in front of the chest and behind the head.
    expect(m.rings.first.samples.any((p) => p.z > 0.5), isTrue);
    expect(m.rings.first.samples.any((p) => p.z < -0.5), isTrue);
    debugPrint('shaders available in flutter_tester: ${assets.hasShaders}');
  });

  const size = Size(360, 370);

  Future<ui.Image> render(
    AuraAvatarState state, {
    AvatarTier tier = AvatarTier.high,
    bool shaders = true,
    AvatarAssets? using,
    double t = 1.5,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    AuraAvatarPainter(
      state: state,
      time: ValueNotifier(t),
      assets: using ?? assets,
      tier: tier,
      useShaders: shaders,
    ).paint(canvas, size);
    expect(
      AuraAvatarPainter.lastFallback?.startsWith('painter'),
      isNot(true),
      reason: 'painter threw: ${AuraAvatarPainter.lastFallback}',
    );
    final picture = recorder.endRecording();
    return picture.toImage(size.width.toInt(), size.height.toInt());
  }

  Future<int> alphaAt(ui.Image img, Offset p) async {
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final i = ((p.dy.toInt() * img.width) + p.dx.toInt()) * 4;
    return data!.getUint8(i + 3);
  }

  for (final stage in AuraStage.values) {
    for (final resting in [false, true]) {
      test('smoke: ${stage.name}${resting ? ' · resting' : ''} paints every '
          'tier, with and without shaders, never blank', () async {
        final state = AuraAvatarState(
          stage: stage,
          hue: 210,
          isResting: resting,
          ringCount: 3,
          glowLevel: 2,
          constellationStars: stage == AuraStage.constellation ? 7 : 0,
        );
        for (final tier in AvatarTier.values) {
          for (final shaders in [true, false]) {
            final img = await render(state, tier: tier, shaders: shaders);
            // The heart of the character is always painted.
            expect(await alphaAt(img, const Offset(180, 215)), greaterThan(0));
            img.dispose();
          }
        }
      });
    }
  }

  test('out-of-range state is clamped and paints (REQ-AVA-06)', () async {
    final img = await render(
      AuraAvatarState(ringCount: 9, glowLevel: 7, constellationStars: 99, hue: -40),
    );
    img.dispose();
  });

  test('fallback chain: no base art → painted orb; no manifest → still drawn',
      () async {
    final img = await render(
      AuraAvatarState(stage: AuraStage.glow),
      using: emptyAssets(),
    );
    expect(await alphaAt(img, const Offset(180, 200)), greaterThan(0));
    img.dispose();
  });

  test('hue tint stays subtle (≤ 25%) and preserves alpha', () {
    final m = AuraAvatarPainter.tintMatrix(const Color(0xFFF3BE67), 0.9, 1);
    // Diagonal keeps at least 75% of each channel.
    expect(m[0], greaterThanOrEqualTo(0.75));
    expect(m[6], greaterThanOrEqualTo(0.75));
    expect(m[12], greaterThanOrEqualTo(0.75));
    expect(m.sublist(15), [0, 0, 0, 1, 0]);
  });

  group('goldens (fixed time, base art loaded)', () {
    for (final stage in AuraStage.values) {
      for (final resting in [false, true]) {
        final name = '${stage.name}${resting ? '_resting' : ''}';
        testWidgets(name, (tester) async {
          await tester.pumpWidget(
            localized(
              Center(
                child: RepaintBoundary(
                  key: const ValueKey('golden'),
                  child: ColoredBox(
                    color: const Color(0xFF0A0C1D),
                    child: AuraAvatarView(
                      state: AuraAvatarState(
                        stage: stage,
                        hue: 250,
                        isResting: resting,
                        ringCount: 2,
                        glowLevel: 1,
                        constellationStars: stage == AuraStage.constellation
                            ? 7
                            : 0,
                      ),
                      assets: assets,
                      size: size,
                      tier: AvatarTier.high,
                      fixedTime: 2,
                    ),
                  ),
                ),
              ),
            ),
          );
          await expectLater(
            find.byKey(const ValueKey('golden')),
            matchesGoldenFile('goldens/avatar_$name.png'),
          );
        });
      }
    }
  });
}
