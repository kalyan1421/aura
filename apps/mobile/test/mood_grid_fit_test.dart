import 'dart:io';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura/src/features/checkin/mood_grid.dart';
import 'package:aura/src/features/checkin/quadrant_glyph.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The check-in picker on real phone sizes, drawn in real fonts: at 1.0 text
/// the title, subtitle, axis labels and all 16 moods sit above the pinned
/// Save button with no scrolling, in every alpha locale and whichever layout
/// it gets (F1: 2 taps; "Feelings have equal dignity": no quadrant is below
/// the fold). Larger text may scroll but never overflows.
///
/// The test font is far wider than any real one (Tenglish would drop to the
/// one-mood-per-row list), so the system text families are replaced by SF Pro
/// (macOS `SFNS.ttf`, the iPhone's font) or, elsewhere, Roboto from the
/// Flutter SDK; Telugu script uses the bundled Noto Sans Telugu.
void main() {
  final sdkFonts =
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts';
  const sf = ['/System/Library/Fonts/SFNS.ttf'];
  final roboto = [
    '$sdkFonts/Roboto-Regular.ttf',
    '$sdkFonts/Roboto-Medium.ttf',
    '$sdkFonts/Roboto-Bold.ttf',
  ];
  final latin = sf.every((p) => File(p).existsSync())
      ? sf
      : roboto.every((p) => File(p).existsSync())
      ? roboto
      : null;
  final skip = latin == null ? 'no SF Pro or Roboto font file found' : null;

  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  setUpAll(() async {
    if (latin == null) return;
    // The families the iOS type scale asks for (Typography.material2021).
    await load('CupertinoSystemText', latin);
    await load('CupertinoSystemDisplay', latin);
    await load('NotoSansTelugu', const [
      'assets/fonts/NotoSansTelugu-Regular.ttf',
      'assets/fonts/NotoSansTelugu-Medium.ttf',
      'assets/fonts/NotoSansTelugu-SemiBold.ttf',
    ]);
    await load('NotoSansDevanagari', const [
      'assets/fonts/NotoSansDevanagari-Regular.ttf',
      'assets/fonts/NotoSansDevanagari-Medium.ttf',
      'assets/fonts/NotoSansDevanagari-SemiBold.ttf',
    ]);
  });

  const phones = [
    // iPhone 12–14: 47 pt status bar, 34 pt home indicator.
    (name: '390×844', size: Size(390, 844), top: 47.0),
    // iPhone 16 Pro (Dynamic Island).
    (name: '402×874', size: Size(402, 874), top: 62.0),
  ];
  const tags = ['te-Latn', 'te', 'en', 'hi', 'hi-Latn'];

  Future<void> pumpPicker(
    WidgetTester tester, {
    required Size size,
    required double top,
    required String tag,
    double scale = 1,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = FakeViewPadding(top: top * 3, bottom: 34 * 3);
    tester.view.viewPadding = FakeViewPadding(top: top * 3, bottom: 34 * 3);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
    }
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: memoryDb(), locale: tag),
        child: localized(const CheckInScreen(), locale: localeFromTag(tag)),
      ),
    );
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Finder tileOf(Mood m) => find.byKey(ValueKey('mood-${m.id}'));
  Finder inTile(Mood m, Finder f) =>
      find.descendant(of: tileOf(m), matching: f);
  Finder labelOf(Mood m) => inTile(m, find.byType(Text));
  // The mood dot: the only circle drawn inside a tile.
  Finder dotOf(Mood m) => inTile(
    m,
    find.byWidgetPredicate(
      (w) =>
          w is AnimatedContainer &&
          (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
    ),
  );

  /// The layout, read off the tiles: distinct columns and rows of moods.
  MoodGridLayout layoutOf(WidgetTester tester) {
    final xs = <int>{}, ys = <int>{};
    for (final m in moodCatalog) {
      final r = tester.getRect(tileOf(m));
      xs.add(r.left.round());
      ys.add(r.top.round());
    }
    return switch ((xs.length, ys.length)) {
      (4, 4) => MoodGridLayout.grid,
      (2, 8) => MoodGridLayout.tall,
      (2, _) => MoodGridLayout.stacked,
      _ => MoodGridLayout.list,
    };
  }

  /// One shared label size, whole words, labels that keep the width they
  /// were measured for (the inline dot included), equal 48 dp+ tiles, and
  /// the tile shape of the layout.
  void expectTiles(WidgetTester tester, String tag) {
    final layout = layoutOf(tester);
    final sizes = <double>{};
    final tileSizes = <Size>{};
    for (final m in moodCatalog) {
      final tile = tester.getRect(tileOf(m));
      expect(tile.width, greaterThanOrEqualTo(moodTileMinTarget), reason: m.id);
      expect(
        tile.height,
        greaterThanOrEqualTo(moodTileMinTarget),
        reason: m.id,
      );
      tileSizes.add(
        Size(tile.width.roundToDouble(), tile.height.roundToDouble()),
      );

      final text = tester.widget<Text>(labelOf(m));
      sizes.add(text.style!.fontSize!);

      // The label box got the whole width the fit measured for it: had the
      // measurement ignored the inline dot, the row would squeeze it.
      final box = find
          .ancestor(of: labelOf(m), matching: find.byType(SizedBox))
          .first;
      expect(
        tester.getSize(box).width,
        moreOrLessEquals(tester.widget<SizedBox>(box).width!, epsilon: 0.01),
        reason: '${m.id}: label box squeezed',
      );
      final label = tester.getRect(box);
      expect(label.right, lessThanOrEqualTo(tile.right + 0.01), reason: m.id);

      // Whole words: none is wider than its line.
      final rp = tester.renderObject<RenderParagraph>(
        inTile(m, find.byType(RichText)),
      );
      for (final w in m.nameFor(tag).split(' ')) {
        final p = TextPainter(
          text: TextSpan(text: w, style: rp.text.style),
          textDirection: TextDirection.ltr,
          textScaler: rp.textScaler,
          maxLines: 1,
        )..layout();
        expect(
          p.width,
          lessThanOrEqualTo(rp.size.width + 0.5),
          reason: '"$w" in ${m.id}',
        );
        p.dispose();
      }

      final dot = tester.getRect(
        find.ancestor(of: dotOf(m), matching: find.byType(SizedBox)).first,
      );
      if (layout == MoodGridLayout.grid) {
        expect(dot.bottom, lessThanOrEqualTo(label.top), reason: m.id);
      } else {
        // Row tile: the dot inline at the start of the label.
        expect(dot.right, lessThanOrEqualTo(label.left), reason: m.id);
        expect(dot.center.dy, greaterThan(label.top), reason: m.id);
        expect(dot.center.dy, lessThan(label.bottom), reason: m.id);
      }
    }
    expect(sizes, hasLength(1), reason: 'one label size: $sizes');
    expect(tileSizes, hasLength(1), reason: 'equal tiles: $tileSizes');
  }

  for (final phone in phones) {
    for (final tag in tags) {
      testWidgets('$tag on ${phone.name} at 1.0: title, subtitle, axes and '
          'all 16 moods sit above Save, no scrolling', (tester) async {
        await pumpPicker(tester, size: phone.size, top: phone.top, tag: tag);
        expect(tester.takeException(), isNull);
        final l = lookupAppLocalizations(localeFromTag(tag));

        final list = find.byType(ListView).first;
        final viewport = tester.getRect(list);
        final save = tester.getRect(find.byKey(const ValueKey('checkin-save')));
        expect(viewport.bottom, lessThanOrEqualTo(save.top));
        void onScreen(Finder f, String what) {
          expect(f, findsOneWidget, reason: what);
          final r = tester.getRect(f);
          expect(
            r.top >= viewport.top - 0.01 && r.bottom <= viewport.bottom + 0.01,
            isTrue,
            reason:
                '$what at $r is outside the list $viewport '
                '(Save at ${save.top})',
          );
        }

        onScreen(find.text(l.checkin_title), 'title');
        onScreen(find.text(l.checkin_subtitle), 'subtitle');
        onScreen(find.text('↑ ${l.checkin_moreEnergy}'), 'energy axis');
        onScreen(find.text('${l.checkin_pleasant} →'), 'pleasant axis');
        onScreen(find.text('← ${l.checkin_unpleasant}'), 'unpleasant axis');
        onScreen(find.text('↓ ${l.checkin_lessEnergy}'), 'less-energy axis');
        for (final q in Quadrant.values) {
          onScreen(find.text(quadrantName(l, q)), q.name);
        }
        for (final m in moodCatalog) {
          onScreen(tileOf(m), m.id);
        }
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: list, matching: find.byType(Scrollable)),
            )
            .position;
        expect(position.pixels, 0);

        final layout = layoutOf(tester);
        expect(layout, isIn([MoodGridLayout.grid, MoodGridLayout.tall]));
        expectTiles(tester, tag);
        final size = tester.widget<Text>(labelOf(moodCatalog.first)).style;
        expect(size!.fontSize, greaterThanOrEqualTo(moodLabelMinFontSize));
        if (layout == MoodGridLayout.tall) {
          // Row tiles: one line tall, the 48 dp target and no more.
          for (final m in moodCatalog) {
            expect(tester.getSize(tileOf(m)).height, moodTileMinTarget);
          }
        }

        // Fixed energy × pleasantness order: Storm | Sunrise over Rain |
        // Moonlight.
        Rect at(String id) => tester.getRect(find.byKey(ValueKey('mood-$id')));
        expect(at('overwhelmed').left, lessThan(at('joyful').left));
        expect(at('melancholy').left, lessThan(at('calm').left));
        expect(at('frustrated').bottom, lessThan(at('melancholy').top));
        expect(at('energised').bottom, lessThan(at('calm').top));
        expect(at('overwhelmed').top, at('joyful').top);

        await unmount(tester);
      }, skip: skip != null);
    }
  }

  for (final reduceMotion in [false, true]) {
    testWidgets('row tiles keep the selected state: border, '
        '${reduceMotion ? 'no scale under Reduce Motion' : 'scale'}, lit dot '
        'and bold, with no layout shift; each tile reads name + group', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPicker(
        tester,
        size: phones.last.size,
        top: phones.last.top,
        tag: 'te-Latn',
        reduceMotion: reduceMotion,
      );
      expect(layoutOf(tester), MoodGridLayout.tall);
      final l = lookupAppLocalizations(localeFromTag('te-Latn'));
      String semantic(Mood m) => l.mood_semantic(
        m.nameFor('te-Latn'),
        quadrantName(l, m.quadrant),
        m.quadrant.energy == Energy.high
            ? l.semantic_highEnergy
            : l.semantic_lowEnergy,
        m.quadrant.pleasant ? l.semantic_pleasant : l.semantic_unpleasant,
      );
      for (final m in moodCatalog) {
        expect(find.bySemanticsLabel(semantic(m)), findsOneWidget);
      }

      final picked = moodCatalog.firstWhere((m) => m.id == 'overwhelmed');
      final other = moodCatalog.firstWhere((m) => m.id == 'calm');
      // Layout size and centre (the selection scale is a paint transform
      // around the centre), relative to the grid: picking a mood scrolls
      // the details into view, which moves the whole grid, not its tiles.
      (Offset, Size) place(Mood m) => (
        tester.getCenter(tileOf(m)) - tester.getTopLeft(find.byType(MoodGrid)),
        tester.getSize(tileOf(m)),
      );
      final before = {for (final m in moodCatalog) m.id: place(m)};
      await tester.tap(tileOf(picked));
      await tester.pumpAndSettle();

      for (final m in moodCatalog) {
        expect(place(m), before[m.id], reason: m.id);
      }
      expect(
        tester.getSemantics(tileOf(picked)),
        isSemantics(label: semantic(picked), isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(tileOf(other)),
        isSemantics(label: semantic(other), isButton: true, isSelected: false),
      );

      TextStyle style(Mood m) => tester.widget<Text>(labelOf(m)).style!;
      expect(style(picked).fontWeight, FontWeight.w700);
      expect(style(other).fontWeight, FontWeight.w500);

      BorderSide side(Mood m) =>
          (tester
                      .widget<Material>(
                        find
                            .ancestor(
                              of: tileOf(m),
                              matching: find.byType(Material),
                            )
                            .first,
                      )
                      .shape!
                  as RoundedRectangleBorder)
              .side;
      expect(side(picked).width, 1.5);
      expect(side(picked).color, isNot(side(other).color));

      // The lit dot is bigger (and white); its box keeps the label still.
      expect(
        tester.getSize(dotOf(picked)).width,
        greaterThan(tester.getSize(dotOf(other)).width),
      );

      double scale(Mood m) => tester
          .widget<AnimatedScale>(
            find.ancestor(of: tileOf(m), matching: find.byType(AnimatedScale)),
          )
          .scale;
      expect(scale(picked), reduceMotion ? 1 : greaterThan(1));
      expect(scale(other), 1);

      // Still visible above Save, which is now enabled.
      final save = find.byKey(const ValueKey('checkin-save'));
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      expect(
        tester.getRect(tileOf(picked)).bottom,
        lessThan(tester.getRect(save).top),
      );

      handle.dispose();
      await unmount(tester);
    }, skip: skip != null);
  }

  for (final phone in phones) {
    for (final tag in tags) {
      for (final scale in [1.5, 2.0]) {
        testWidgets('$tag on ${phone.name} at ${scale}x: may scroll, never '
            'overflows', (tester) async {
          await pumpPicker(
            tester,
            size: phone.size,
            top: phone.top,
            tag: tag,
            scale: scale,
          );
          expect(tester.takeException(), isNull);
          expectTiles(tester, tag);
          final size = tester.widget<Text>(labelOf(moodCatalog.first)).style;
          expect(
            size!.fontSize! * scale,
            greaterThanOrEqualTo(moodLabelMinFontSize),
          );

          // Scroll through the whole picker: nothing overflows on the way.
          final list = find.byType(ListView).first;
          await tester.scrollUntilVisible(
            tileOf(moodCatalog.firstWhere((m) => m.id == 'grateful')),
            200,
            scrollable: find
                .descendant(of: list, matching: find.byType(Scrollable))
                .first,
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          await unmount(tester);
        }, skip: skip != null);
      }
    }
  }
}
