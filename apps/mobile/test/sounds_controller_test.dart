import 'package:aura/src/core/entitlements/plus.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/features/sanctuary/sounds/saved_mixes.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_backend.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_controller.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_library.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_session_log.dart';
import 'package:aura/src/features/sanctuary/sounds/stem_manifest.dart';
import 'package:aura/src/features/sanctuary/sounds/wind_down.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'sounds_fakes.dart';

/// The Sounds mixer (PRD 06d, REQ-SAN-09…13) against a fake audio backend.
/// Runs in testWidgets for fake time: fades, the timer and the wind-down
/// are driven by pumping.
void main() {
  late FakeSoundsBackend backend;
  late RecordingSessionLog log;

  ProviderContainer make({
    bool plus = false,
    StemManifest? manifest,
    FakeStemStore? store,
  }) {
    backend = FakeSoundsBackend();
    log = RecordingSessionLog();
    final c = ProviderContainer(
      overrides: [
        soundsBackendProvider.overrideWithValue(backend),
        stemStoreProvider.overrideWithValue(store ?? FakeStemStore()),
        plusActiveProvider.overrideWithValue(plus),
        timeContextProvider.overrideWithValue(testTime()),
        soundsSessionLogProvider.overrideWithValue(log),
        if (manifest != null) stemManifestProvider.overrideWithValue(manifest),
      ],
    );
    c.read(soundsLibraryProvider); // loads the download state
    return c;
  }

  SoundsController ctl(ProviderContainer c) =>
      c.read(soundsControllerProvider.notifier);
  SoundsState st(ProviderContainer c) => c.read(soundsControllerProvider);

  Future<void> wait(WidgetTester tester, Duration d) async {
    await tester.pump(d);
  }

  /// Ends everything so no timer is left pending.
  Future<void> end(WidgetTester tester, ProviderContainer c) async {
    ctl(c).stop();
    await tester.pump(const Duration(seconds: 2));
    c.dispose();
  }

  testWidgets('silent until chosen: nothing is set up or plays on its own', (
    tester,
  ) async {
    final c = make();
    expect(st(c).isIdle, isTrue);
    await wait(tester, const Duration(minutes: 5));
    expect(backend.prepares, 0);
    expect(backend.layers, isEmpty);
    expect(backend.media, isEmpty);
    c.dispose();
  });

  testWidgets('a tap starts the stem, fading in over at least 2 s', (
    tester,
  ) async {
    final c = make();
    expect(ctl(c).toggle('brown_noise'), SoundsToggle.added);
    await tester.pump();
    final layer = backend.layerFor('brown_noise')!;
    expect(layer.playing, isTrue);
    expect(backend.prepares, isNonZero); // idempotent; set up on the tap
    expect(backend.media.last, (true, true));
    expect(layer.volume, 0);

    await wait(tester, const Duration(seconds: 1));
    expect(layer.volume, lessThan(soundsDefaultVolume * 0.5));
    await wait(tester, const Duration(milliseconds: 900)); // 1.9 s
    expect(layer.volume, lessThan(soundsDefaultVolume));
    await wait(tester, const Duration(seconds: 2));
    expect(layer.volume, closeTo(soundsDefaultVolume, 0.001));
    await end(tester, c);
  });

  testWidgets('the first play after launch still publishes the media session '
      '(foreground service + lock-screen controls)', (tester) async {
    final c = make();
    // The real media session is built inside prepare(), which runs after the tap's first publish.
    backend.dropMediaBeforePrepare = true;
    ctl(c).toggle('brown_noise');
    await tester.pump();
    // Without the republish after prepare() this stays empty: the sound plays but Android never gets a
    // foreground service, so it may silence it once the screen locks (found on a release emulator run).
    expect(backend.media, isNotEmpty);
    expect(backend.media.last, (true, true));
    await end(tester, c);
  });

  testWidgets('up to four at once, each with its own volume', (tester) async {
    final c = make();
    for (final id in ['rain', 'ocean', 'wind', 'chimes']) {
      expect(ctl(c).toggle(id), SoundsToggle.added);
    }
    expect(ctl(c).toggle('brown_noise'), SoundsToggle.full);
    expect(st(c).layers, hasLength(4));
    await wait(tester, const Duration(seconds: 4));
    ctl(c).setVolume('ocean', 0.25);
    await wait(tester, const Duration(milliseconds: 400));
    expect(backend.layerFor('ocean')!.volume, closeTo(0.25, 0.001));
    expect(backend.layerFor('rain')!.volume, closeTo(0.6, 0.001));

    // Taking one out fades it and frees a place.
    expect(ctl(c).toggle('ocean'), SoundsToggle.removed);
    await wait(tester, const Duration(seconds: 1));
    expect(backend.layerFor('ocean'), isNull);
    expect(ctl(c).toggle('brown_noise'), SoundsToggle.added);
    await end(tester, c);
  });

  testWidgets('taking out the last stem ends the session: released, '
      'controls removed, one content-free record', (tester) async {
    final c = make();
    ctl(c).toggle('chimes');
    await wait(tester, const Duration(seconds: 90));
    expect(ctl(c).toggle('chimes'), SoundsToggle.removed);
    expect(st(c).isIdle, isTrue);
    await wait(tester, const Duration(seconds: 1));
    expect(backend.live, isEmpty);
    expect(backend.releases, greaterThan(0));
    expect(backend.media.last, (false, false));
    final r = log.records.single;
    expect(r.activity, 'sounds');
    expect(r.variant, 'open');
    expect(r.durationS, closeTo(90, 1));
    expect(r.localDay, const LocalDay(2026, 10, 8));
    c.dispose();
  });

  testWidgets('Plus stems are locked on Free and play with Plus', (
    tester,
  ) async {
    final free = make();
    expect(ctl(free).toggle('pink_noise'), SoundsToggle.locked);
    expect(st(free).isIdle, isTrue);
    await tester.pump();
    expect(backend.layers, isEmpty);
    free.dispose();

    final plus = make(plus: true);
    expect(ctl(plus).toggle('pink_noise'), SoundsToggle.added);
    await end(tester, plus);
  });

  testWidgets('a recording-only stem needs its download first', (
    tester,
  ) async {
    final store = FakeStemStore();
    final c = make(plus: true, manifest: downloadableManifest(), store: store);
    await tester.pump();
    expect(ctl(c).toggle('stream'), SoundsToggle.needsDownload);
    // The base recording has a generated stand-in, so it plays at once.
    expect(ctl(c).toggle('rain'), SoundsToggle.added);
    await tester.pump();
    expect(backend.layerFor('rain')!.path, 'gen/rain');
    await end(tester, c);

    final c2 = make(
      plus: true,
      manifest: downloadableManifest(),
      store: FakeStemStore(downloaded: {'rain', 'stream'}),
    );
    await tester.pump();
    expect(ctl(c2).toggle('stream'), SoundsToggle.added);
    expect(ctl(c2).toggle('rain'), SoundsToggle.added);
    await tester.pump();
    expect(backend.layerFor('rain')!.path, 'rec/rain');
    await end(tester, c2);
  });

  testWidgets('timer: plays until the last 30 s, fades out, then stops', (
    tester,
  ) async {
    final c = make();
    ctl(c).setTimer(const Duration(minutes: 15));
    ctl(c).toggle('ocean');
    await tester.pump();
    final layer = backend.layerFor('ocean')!;
    await wait(tester, const Duration(minutes: 14, seconds: 20));
    expect(st(c).isPlaying, isTrue);
    expect(st(c).fadingOut, isFalse);
    expect(layer.volume, closeTo(soundsDefaultVolume, 0.001));
    expect(st(c).timerLeft!.inSeconds, lessThanOrEqualTo(60));

    await wait(tester, const Duration(seconds: 15)); // 14:35
    expect(st(c).fadingOut, isTrue);
    expect(layer.volume, lessThan(soundsDefaultVolume));
    expect(layer.volume, greaterThan(0));

    await wait(tester, const Duration(seconds: 26)); // 15:01
    expect(st(c).isIdle, isTrue);
    await wait(tester, const Duration(seconds: 1));
    expect(layer.disposed, isTrue);
    expect(log.records.single.variant, 'timer_15');
    expect(log.records.single.durationS, closeTo(900, 1));
    c.dispose();
  });

  testWidgets('setting the timer again during the fade brings it back', (
    tester,
  ) async {
    final c = make();
    ctl(c).setTimer(const Duration(minutes: 15));
    ctl(c).toggle('wind');
    await wait(tester, const Duration(minutes: 14, seconds: 45));
    expect(st(c).fadingOut, isTrue);
    ctl(c).setTimer(const Duration(minutes: 30));
    expect(st(c).fadingOut, isFalse);
    await wait(tester, const Duration(seconds: 5));
    expect(
      backend.layerFor('wind')!.volume,
      closeTo(soundsDefaultVolume, 0.001),
    );
    ctl(c).setTimer(null);
    expect(st(c).timerLeft, isNull);
    await end(tester, c);
  });

  testWidgets('lock-screen controls: pause, play (fading in), stop', (
    tester,
  ) async {
    final c = make();
    ctl(c).toggle('rain');
    await wait(tester, const Duration(seconds: 3));
    final layer = backend.layerFor('rain')!;

    backend.transport!.pause();
    expect(st(c).phase, SoundsPhase.paused);
    expect(backend.media.last, (true, false));
    await wait(tester, const Duration(seconds: 1));
    expect(layer.playing, isFalse);

    // Paused time is not heard time.
    await wait(tester, const Duration(minutes: 10));

    backend.transport!.play();
    expect(layer.playing, isTrue);
    await wait(tester, const Duration(seconds: 1));
    expect(layer.volume, lessThan(soundsDefaultVolume * 0.5));
    await wait(tester, const Duration(seconds: 3));
    expect(layer.volume, closeTo(soundsDefaultVolume, 0.001));

    backend.transport!.stop();
    expect(st(c).isIdle, isTrue);
    expect(backend.media.last, (false, false));
    await wait(tester, const Duration(seconds: 1));
    expect(layer.disposed, isTrue);
    expect(log.records.single.durationS, lessThan(15));
    c.dispose();
  });

  testWidgets('a call pauses and, when it ends, resumes; headphones out '
      'pause and stay paused (never to the speaker)', (tester) async {
    final c = make();
    ctl(c).toggle('rain');
    await wait(tester, const Duration(seconds: 3));
    final layer = backend.layerFor('rain')!;

    backend.emit(SoundsInterruption.pause);
    await tester.pump();
    expect(st(c).phase, SoundsPhase.paused);
    backend.emit(SoundsInterruption.resume);
    await tester.pump();
    expect(st(c).isPlaying, isTrue);
    await wait(tester, const Duration(seconds: 3));

    backend.emit(SoundsInterruption.noisy);
    await tester.pump();
    expect(st(c).phase, SoundsPhase.paused);
    await wait(tester, const Duration(seconds: 1));
    expect(layer.playing, isFalse);
    backend.emit(SoundsInterruption.resume);
    await tester.pump();
    expect(st(c).phase, SoundsPhase.paused);

    // A paused-by-hand mix doesn't resume after a call either.
    ctl(c).play();
    await wait(tester, const Duration(seconds: 3));
    ctl(c).pause();
    backend.emit(SoundsInterruption.resume);
    await tester.pump();
    expect(st(c).phase, SoundsPhase.paused);
    await end(tester, c);
  });

  testWidgets('another sound ducks it, then it comes back', (tester) async {
    final c = make();
    ctl(c).toggle('ocean');
    await wait(tester, const Duration(seconds: 3));
    final layer = backend.layerFor('ocean')!;
    backend.emit(SoundsInterruption.duck);
    await tester.pump();
    expect(layer.volume, closeTo(soundsDefaultVolume * soundsDuckLevel, 0.01));
    backend.emit(SoundsInterruption.unduck);
    await tester.pump();
    expect(layer.volume, closeTo(soundsDefaultVolume, 0.01));
    await end(tester, c);
  });

  testWidgets('night wind-down: tonight\'s base lineup, then silence and one '
      'record', (tester) async {
    final c = make(plus: true);
    expect(ctl(c).startWindDown(), isTrue);
    final s = st(c);
    expect(s.isWindDown, isTrue);
    final base = [
      for (final stem in StemManifest.bundled.listed)
        if (!stem.isPlus) stem,
    ];
    expect(s.windDown!.order, windDownOrderFor(const LocalDay(2026, 10, 8), base));
    expect([for (final l in s.layers) l.stemId], s.windDown!.order);
    // Only base stems, even with Plus.
    for (final l in s.layers) {
      expect(StemManifest.bundled.byId(l.stemId)!.isPlus, isFalse);
    }
    expect(ctl(c).toggle('brown_noise'), SoundsToggle.busy);

    await wait(tester, const Duration(minutes: 5));
    final gains = s.windDown!.gainsAt(const Duration(minutes: 5));
    for (final id in s.windDown!.order) {
      expect(
        backend.layerFor(id)!.volume,
        closeTo(gains[id]!, 0.01),
        reason: id,
      );
    }
    expect(st(c).windDownLeft!.inMinutes, lessThanOrEqualTo(15));

    await wait(tester, const Duration(minutes: 15, seconds: 1));
    expect(st(c).isIdle, isTrue);
    await wait(tester, const Duration(seconds: 1));
    expect(backend.live, isEmpty);
    final r = log.records.single;
    expect(r.activity, 'night_wind_down');
    expect(r.variant, 'v1');
    expect(r.durationS, closeTo(1200, 1));
    c.dispose();
  });

  testWidgets('a saved mix plays what it can (a locked stem is left out)', (
    tester,
  ) async {
    final c = make();
    final ok = ctl(c).playMix(
      const SavedMix([('pink_noise', 0.5), ('rain', 0.3), ('chimes', 0.8)]),
    );
    expect(ok, isTrue);
    expect([for (final l in st(c).layers) l.stemId], ['rain', 'chimes']);
    expect(st(c).volumeOf('rain'), 0.3);
    expect(ctl(c).currentMix!.stemIds, ['rain', 'chimes']);
    await end(tester, c);

    final c2 = make();
    expect(ctl(c2).playMix(const SavedMix([('pink_noise', 0.5)])), isFalse);
    expect(st(c2).isIdle, isTrue);
    c2.dispose();
  });

  test('SavedMix JSON round-trip and equality', () {
    const mix = SavedMix([('rain', 0.6), ('chimes', 0.333)]);
    final back = SavedMix.fromJson(mix.toJson());
    expect(back.stemIds, ['rain', 'chimes']);
    expect(back.sameAs(mix), isTrue);
    expect(back.sameAs(const SavedMix([('rain', 0.6)])), isFalse);
    expect(
      SavedMix.fromJson({
        'layers': [
          {'id': 'rain', 'v': 7},
          {'id': 3},
        ],
      }).layers,
      [('rain', 1.0)],
    );
  });
}
