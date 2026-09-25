import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/perf/device_profile.dart';
import 'package:aura/src/features/avatar/aura_avatar.dart';
import 'package:aura/src/features/avatar/aura_avatar_painter.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// REQ-AVA-07 / PRD F2 "Quality tiers": the Low tier is picked at launch on
/// an Android phone with ≤ 3 GB RAM or with battery saver on (and re-checked
/// on resume), not only after 2 s of slow frames.

const _gb = 1000000000;

AvatarTier _tierOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(AuraAvatarView),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is AuraAvatarPainter,
      ),
    ),
  );
  return (paint.painter! as AuraAvatarPainter).tier;
}

Future<void> _pumpAvatar(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Center(
      child: AuraAvatarView(
        state: AuraAvatarState(stage: AuraStage.glow, hue: 250),
        assets: null,
        size: const Size.square(120),
      ),
    ),
  ),
);

void main() {
  tearDown(() {
    DeviceProfile.instance.reset();
    FrameBudget.instance.reset();
  });

  group('the rule', () {
    test('a 3 GB Android prefers Low; a 4 GB one does not', () {
      expect(
        const DeviceProfileInfo(
          android: true,
          totalRamBytes: 2850000000,
        ).prefersLowTier,
        isTrue,
      );
      expect(
        const DeviceProfileInfo(
          android: true,
          totalRamBytes: 3 * _gb,
        ).prefersLowTier,
        isTrue,
      );
      expect(
        const DeviceProfileInfo(
          android: true,
          totalRamBytes: 3700000000,
        ).prefersLowTier,
        isFalse,
      );
    });

    test('battery saver prefers Low on either platform', () {
      expect(
        const DeviceProfileInfo(
          android: true,
          totalRamBytes: 8 * _gb,
          powerSave: true,
        ).prefersLowTier,
        isTrue,
      );
      expect(
        const DeviceProfileInfo(
          android: false,
          totalRamBytes: 6 * _gb,
          powerSave: true,
        ).prefersLowTier,
        isTrue,
      );
    });

    test('memory alone never lowers an iPhone; unknown memory never lowers '
        'anything', () {
      expect(
        const DeviceProfileInfo(
          android: false,
          totalRamBytes: 2 * _gb,
        ).prefersLowTier,
        isFalse,
      );
      expect(const DeviceProfileInfo(android: true).prefersLowTier, isFalse);
    });
  });

  test('refresh reads the platform channel and never throws', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('com.akvega.aura/platform');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });

    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'deviceProfile'
          ? {'totalRamBytes': 2900000000, 'powerSave': false}
          : null,
    );
    await DeviceProfile.instance.refresh();
    expect(DeviceProfile.instance.prefersLowTier.value, isTrue);

    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {'totalRamBytes': 6 * _gb, 'powerSave': false},
    );
    await DeviceProfile.instance.refresh();
    expect(DeviceProfile.instance.prefersLowTier.value, isFalse);

    // A platform without the call keeps the last answer.
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw MissingPluginException(),
    );
    await DeviceProfile.instance.refresh();
    expect(DeviceProfile.instance.prefersLowTier.value, isFalse);
  });

  testWidgets('the avatar starts on Low when the phone asks for it, and goes '
      'back to High when it no longer does', (tester) async {
    DeviceProfile.instance.apply(
      const DeviceProfileInfo(android: true, totalRamBytes: 2900000000),
    );
    await _pumpAvatar(tester);
    expect(_tierOf(tester), AvatarTier.low);

    // Battery saver switched off on a big phone (seen on resume).
    DeviceProfile.instance.apply(
      const DeviceProfileInfo(android: true, totalRamBytes: 6 * _gb),
    );
    await tester.pump();
    expect(_tierOf(tester), AvatarTier.high);
    await tester.pumpWidget(const SizedBox());
  });
}
