import 'dart:convert';
import 'dart:io';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/a11y/haptics.dart';
import 'package:aura/src/core/entitlements/plus.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/features/sanctuary/sanctuary_screen.dart';
import 'package:aura/src/features/sanctuary/sounds/saved_mixes.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_backend.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_screen.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_library.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_session_log.dart';
import 'package:aura/src/features/sanctuary/sounds/stem_manifest.dart';
import 'package:aura/src/features/sanctuary/sounds/stem_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'sounds_fakes.dart';

/// Sanctuary › Sounds (F15, PRD 06d): silent until chosen, the mixer, the
/// timer, locked Plus stems, offline and download states, accessibility.
void main() {
  late FakeSoundsBackend backend;
  late FakeStemStore store;
  late RecordingSessionLog log;

  Future<void> pump(
    WidgetTester tester, {
    bool plus = false,
    StemManifest? manifest,
    FakeStemStore? stems,
    bool online = true,
    bool reduceMotion = false,
    double textScale = 1,
    String locale = 'en',
    Size size = const Size(390, 2200),
    Widget screen = const SoundsScreen(),
  }) async {
    backend = FakeSoundsBackend();
    store = stems ?? FakeStemStore();
    log = RecordingSessionLog();
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: memoryDb(), locale: locale),
          soundsBackendProvider.overrideWithValue(backend),
          stemStoreProvider.overrideWithValue(store),
          plusActiveProvider.overrideWithValue(plus),
          soundsOnlineProvider.overrideWithValue(online),
          soundsSessionLogProvider.overrideWithValue(log),
          savedMixesProvider.overrideWith(MemorySavedMixes.new),
          if (manifest != null) stemManifestProvider.overrideWithValue(manifest),
        ],
        child: localized(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: screen,
            ),
          ),
          locale: localeFromTag(locale),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  Finder toggle(String id) => find.byKey(ValueKey('sounds-toggle-$id'));
  String status(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('sounds-status'))).data!;

  testWidgets('opening Sounds plays nothing (REQ-SAN-09)', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(backend.prepares, 0);
    expect(backend.layers, isEmpty);
    expect(backend.media, isEmpty);
    expect(status(tester), 'Nothing playing');
    expect(find.byKey(const ValueKey('sounds-pause')), findsNothing);
    await end(tester);
  });

  testWidgets('the free base set is listed; pending recordings are hidden; '
      'Plus extras show locked', (tester) async {
    await pump(tester);
    for (final id in [
      'rain',
      'ocean',
      'wind',
      'night_insects',
      'singing_bowl',
      'chimes',
      'brown_noise',
      'pink_noise',
      'deep_bell',
    ]) {
      expect(toggle(id), findsOneWidget, reason: id);
    }
    for (final id in ['monsoon_roof', 'stream', 'fireplace', 'distant_thunder']) {
      expect(toggle(id), findsNothing, reason: id);
    }
    expect(find.text('Aura Plus'), findsNWidgets(2));
    await end(tester);
  });

  testWidgets('a tap plays the stem with a spoken state; pause, play and '
      'stop', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    expect(find.bySemanticsLabel('Brown noise, off'), findsOneWidget);

    await tester.tap(toggle('brown_noise'));
    await tester.pump(const Duration(seconds: 3));
    expect(backend.layerFor('brown_noise')!.playing, isTrue);
    expect(status(tester), 'Playing');
    expect(
      find.bySemanticsLabel('Brown noise, playing, volume 60%'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Brown noise volume'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sounds-pause')));
    await tester.pump(const Duration(seconds: 1));
    expect(status(tester), 'Paused');
    expect(
      find.bySemanticsLabel('Brown noise, paused, volume 60%'),
      findsOneWidget,
    );
    expect(backend.layerFor('brown_noise')!.playing, isFalse);

    await tester.tap(find.byKey(const ValueKey('sounds-play')));
    await tester.pump(const Duration(seconds: 3));
    expect(status(tester), 'Playing');

    await tester.tap(find.byKey(const ValueKey('sounds-stop')));
    await tester.pump(const Duration(seconds: 1));
    expect(status(tester), 'Nothing playing');
    expect(backend.live, isEmpty);
    expect(find.byKey(const ValueKey('sounds-stop')), findsNothing);
    expect(log.records.single.activity, 'sounds');
    semantics.dispose();
    await end(tester);
  });

  testWidgets('each stem has its own volume slider', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    await tester.tap(toggle('rain'));
    await tester.tap(toggle('chimes'));
    await tester.pump(const Duration(seconds: 3));
    tester
        .widget<Slider>(find.byKey(const ValueKey('sounds-volume-rain')))
        .onChanged!(0.3);
    await tester.pump(const Duration(milliseconds: 400));
    expect(backend.layerFor('rain')!.volume, closeTo(0.3, 0.001));
    expect(backend.layerFor('chimes')!.volume, closeTo(0.6, 0.001));
    expect(find.bySemanticsLabel('Rain, playing, volume 30%'), findsOneWidget);
    semantics.dispose();
    await end(tester);
  });

  testWidgets('a fifth stem gets a calm note, not a fifth layer', (
    tester,
  ) async {
    await pump(tester);
    for (final id in ['rain', 'ocean', 'wind', 'chimes']) {
      await tester.tap(toggle(id));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(toggle('brown_noise'));
    await tester.pump();
    expect(find.text(l10n(tester).sounds_full), findsOneWidget);
    expect(backend.live, hasLength(4));
    await end(tester);
  });

  testWidgets('a locked Plus stem shows one calm line and plays nothing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    expect(
      find.bySemanticsLabel('Pink noise, part of Aura Plus'),
      findsOneWidget,
    );
    await tester.tap(toggle('pink_noise'));
    await tester.pump();
    expect(find.text('Coming with Aura Plus.'), findsOneWidget);
    expect(backend.layers, isEmpty);
    expect(backend.prepares, 0);
    // No paywall, no new route.
    expect(find.byType(SoundsScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    semantics.dispose();
    await end(tester);
  });

  testWidgets('with Plus the extra stems play', (tester) async {
    await pump(tester, plus: true);
    expect(find.text('Aura Plus'), findsNothing);
    await tester.tap(toggle('deep_bell'));
    await tester.pump(const Duration(seconds: 3));
    expect(backend.layerFor('deep_bell')!.playing, isTrue);
    await end(tester);
  });

  testWidgets('timer: 15 min, then the sound fades out over 30 s and stops', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(toggle('ocean'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Timer · Off'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sounds-timer')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Fade out after'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sounds-timer-15')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Timer · 15 minutes'), findsOneWidget);
    expect(status(tester), 'Playing · Fades out in about 15 minutes');

    await tester.pump(const Duration(minutes: 14, seconds: 30));
    expect(status(tester), 'Playing · Fading out');
    final layer = backend.layerFor('ocean')!;
    expect(layer.volume, lessThan(0.6));

    await tester.pump(const Duration(seconds: 32));
    expect(status(tester), 'Nothing playing');
    await tester.pump(const Duration(seconds: 1));
    expect(layer.disposed, isTrue);
    expect(log.records.single.variant, 'timer_15');
    await end(tester);
  });

  testWidgets('night wind-down: one tap, a countdown in words, stems wait', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('sounds-wind-down')));
    await tester.pump(const Duration(seconds: 1));
    expect(backend.live, hasLength(4));
    expect(status(tester), 'Playing · About 20 minutes left');
    expect(find.byKey(const ValueKey('sounds-timer')), findsNothing);
    expect(find.byKey(const ValueKey('sounds-wind-down')), findsNothing);

    await tester.tap(toggle('brown_noise'));
    await tester.pump();
    expect(find.text(l10n(tester).sounds_windDownBusy), findsOneWidget);

    await tester.pump(const Duration(minutes: 5));
    expect(status(tester), 'Playing · About 15 minutes left');
    await tester.tap(find.byKey(const ValueKey('sounds-stop')));
    await tester.pump(const Duration(seconds: 1));
    expect(log.records.single.activity, 'night_wind_down');
    await end(tester);
  });

  group('offline and downloads', () {
    testWidgets('brown noise plays offline on a fresh install', (
      tester,
    ) async {
      await pump(tester, online: false);
      await tester.tap(toggle('brown_noise'));
      await tester.pump(const Duration(seconds: 3));
      expect(backend.layerFor('brown_noise')!.playing, isTrue);
      await end(tester);
    });

    testWidgets('no recordings to download: no download card', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Recorded sounds'), findsNothing);
      expect(find.byKey(const ValueKey('sounds-remove-downloads')), findsNothing);
      await end(tester);
    });

    testWidgets('offline: the size is shown, and the download waits', (
      tester,
    ) async {
      await pump(tester, manifest: downloadableManifest(), online: false);
      expect(find.text('Recorded sounds'), findsOneWidget);
      expect(find.textContaining('2.5 MB to download once'), findsOneWidget);
      expect(find.byKey(const ValueKey('sounds-offline')), findsOneWidget);
      expect(find.byKey(const ValueKey('sounds-download')), findsNothing);
      // The generated stand-in still plays.
      await tester.tap(toggle('rain'));
      await tester.pump(const Duration(seconds: 1));
      expect(backend.layerFor('rain')!.path, 'gen/rain');
      await end(tester);
    });

    testWidgets('download once, then "Remove downloaded sounds"', (
      tester,
    ) async {
      await pump(tester, manifest: downloadableManifest());
      await tester.tap(find.byKey(const ValueKey('sounds-download')));
      await tester.pump();
      await tester.pump();
      expect(store.downloads, 1);
      expect(find.text('Recorded sounds'), findsNothing);
      await tester.tap(toggle('rain'));
      await tester.pump(const Duration(seconds: 1));
      expect(backend.layerFor('rain')!.path, 'rec/rain');

      await tester.tap(find.byKey(const ValueKey('sounds-remove-downloads')));
      await tester.pump();
      await tester.pump();
      expect(store.removals, 1);
      expect(find.text('Recorded sounds'), findsOneWidget);
      expect(
        find.text(l10n(tester).sounds_downloadsRemoved),
        findsOneWidget,
      );
      await end(tester);
    });

    testWidgets('storage full: the PRD line, with the size', (tester) async {
      final stems = FakeStemStore()..downloadError = StemDownloadError.noSpace;
      await pump(tester, manifest: downloadableManifest(), stems: stems);
      await tester.tap(find.byKey(const ValueKey('sounds-download')));
      await tester.pump();
      await tester.pump();
      expect(
        find.text(
          'Sounds need about 2.5 MB. Free some space, or play brown noise, '
          'which needs none.',
        ),
        findsOneWidget,
      );
      await end(tester);
    });

    testWidgets('a connection lost mid-download says so calmly', (
      tester,
    ) async {
      final stems = FakeStemStore()..downloadError = StemDownloadError.offline;
      await pump(tester, manifest: downloadableManifest(), stems: stems);
      await tester.tap(find.byKey(const ValueKey('sounds-download')));
      await tester.pump();
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sounds-download-error')),
          matching: find.text(l10n(tester).sounds_downloadOffline),
        ),
        findsOneWidget,
      );
      await end(tester);
    });

    testWidgets('a Plus recording shows its size and downloads when first '
        'picked, then plays', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, plus: true, manifest: downloadableManifest());
      expect(
        find.bySemanticsLabel('Stream, 1.2 MB to download once'),
        findsOneWidget,
      );
      await tester.tap(toggle('stream'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(store.downloads, 1);
      expect(backend.layerFor('stream')!.path, 'rec/stream');
      semantics.dispose();
      await end(tester);
    });
  });

  testWidgets('save a mix (no typing), then play it again', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    await tester.tap(toggle('rain'));
    await tester.tap(toggle('chimes'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('sounds-save-mix')));
    await tester.pump();
    expect(find.text('Saved on this phone.'), findsOneWidget);
    expect(find.text('Rain · Chimes'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sounds-stop')));
    await tester.pump(const Duration(seconds: 1));
    expect(backend.live, isEmpty);

    await tester.tap(find.text('Rain · Chimes'));
    await tester.pump(const Duration(seconds: 1));
    expect(backend.live, hasLength(2));
    expect(find.byTooltip('Remove Rain · Chimes'), findsOneWidget);
    expect(find.bySemanticsLabel('Play Rain · Chimes'), findsOneWidget);
    semantics.dispose();
    await end(tester);
  });

  testWidgets('Reduce Motion: nothing on the screen animates', (
    tester,
  ) async {
    await pump(tester, reduceMotion: true);
    await tester.tap(toggle('rain'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(Animate), findsNothing);
    await end(tester);

    await pump(tester);
    await tester.tap(toggle('rain'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(Animate), findsOneWidget); // the slow playing glow
    await end(tester);
  });

  testWidgets('large text (200%, Telugu): no overflow while playing', (
    tester,
  ) async {
    await pump(
      tester,
      textScale: 2,
      locale: 'te',
      size: const Size(360, 780),
    );
    final list = find.descendant(
      of: find.byKey(const ValueKey('sounds-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(toggle('rain'), 200, scrollable: list);
    await tester.tap(toggle('rain'));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      toggle('brown_noise'),
      200,
      scrollable: list,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await end(tester);
  });

  testWidgets('haptics obey Settings › Comfort', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final before = AuraHaptics.enabled;
    addTearDown(() => AuraHaptics.enabled = before);

    AuraHaptics.enabled = false;
    await pump(tester);
    await tester.tap(toggle('rain'));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, isEmpty);

    AuraHaptics.enabled = true;
    await tester.tap(toggle('chimes'));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, hasLength(1));
    await end(tester);
  });

  test('copy lint: no health, sleep or "binaural" claims (REQ-SAN-12), '
      'and every string is in Telugu and Tenglish', () {
    Map<String, dynamic> arb(String name) =>
        jsonDecode(File('lib/l10n/$name').readAsStringSync())
            as Map<String, dynamic>;
    final en = arb('app_en.arb');
    final te = arb('app_te.arb');
    final tl = arb('app_te_Latn.arb');
    final keys = [
      for (final k in en.keys)
        if (k.startsWith('sounds_')) k,
    ];
    expect(keys.length, greaterThan(50));
    final banned = RegExp(
      r'binaural|heal|cure|treat|therap|clinical|sleep|insomnia|anxiety|'
      r'stress|relax|hz\b|frequenc|brainwave|unlock|hurry|last chance',
      caseSensitive: false,
    );
    for (final k in keys) {
      final text = en[k] as String;
      expect(banned.hasMatch(text), isFalse, reason: '$k: $text');
      expect(te[k], isA<String>(), reason: 'te $k');
      expect(tl[k], isA<String>(), reason: 'te_Latn $k');
      expect(text.contains('!'), isFalse, reason: '$k: $text');
    }
  });

  testWidgets('Sanctuary: the Sounds card sits after Grounding, opens '
      'Sounds silently, and shows when sound is playing', (tester) async {
    await pump(tester, screen: const SanctuaryScreen());
    await settleIo(tester);
    final card = find.byKey(const ValueKey('sanctuary-sounds'));
    await tester.scrollUntilVisible(card, 200);
    expect(
      tester.getTopLeft(card).dy,
      greaterThan(tester.getTopLeft(find.text('Grounding')).dy),
    );
    expect(find.text('Rain, ocean, wind and more. Nothing plays until you '
        'choose.'), findsOneWidget);

    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SoundsScreen), findsOneWidget);
    expect(backend.prepares, 0);

    await tester.tap(toggle('wind'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('activity-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Playing now'), findsOneWidget);
    expect(backend.layerFor('wind')!.playing, isTrue); // keeps playing
    await end(tester);
  });
}
