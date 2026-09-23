import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura/src/features/checkin/mood_grid.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// One label size for all 16 moods, a readable floor, roomier layouts when
/// needed, no mid-word breaks, 48 dp targets (REQ-A11Y-01/02/10/14).
void main() {
  group('resolveMoodGridFit', () {
    // A proportional font: 0.55 em per character.
    double word(String w, double size, [double scale = 1]) =>
        w.length * 0.55 * size * scale;
    MoodGridFit fit(String tag, double width, {double scale = 1}) =>
        resolveMoodGridFit(
          width: width,
          baseFontSize: 13.5,
          names: [for (final m in moodCatalog) m.nameFor(tag)],
          measureWord: (w, size) => word(w, size, scale),
          measureHeight: (name, size, maxWidth) => size * scale * 1.4,
        );

    test('English keeps the 4×4 grid at one shared, readable size', () {
      final f = fit('en', 350);
      expect(f.layout, MoodGridLayout.grid);
      expect(f.fontSize, greaterThanOrEqualTo(moodLabelMinFontSize));
      expect(f.fontSize, lessThan(13.5)); // "Overwhelmed" sets the size
      expect(word('Overwhelmed', f.fontSize), lessThanOrEqualTo(f.labelWidth));
    });

    test('long Tenglish words never shrink below the floor: the quadrants '
        'keep their 2 × 2 but list their moods one per row', () {
      final f = fit('te-Latn', 350);
      expect(f.layout, MoodGridLayout.tall);
      expect(f.fontSize, 13.5);
      expect(
        word('Ukkiribikkiriga', f.fontSize),
        lessThanOrEqualTo(f.labelWidth),
      );
    });

    test('extreme text: words still fit whole (below the floor only then)', () {
      final f = fit('te-Latn', 335, scale: 4);
      expect(f.layout, MoodGridLayout.list);
      expect(f.fontSize, lessThan(moodLabelMinFontSize));
      expect(
        word('Ukkiribikkiriga', f.fontSize, 4),
        lessThanOrEqualTo(f.labelWidth),
      );
    });

    test('very large text: one quadrant per row, one mood per row', () {
      final f = fit('te-Latn', 335, scale: 2);
      expect(f.layout, MoodGridLayout.list);
      expect(f.fontSize, greaterThanOrEqualTo(moodLabelMinFontSize));
      expect(
        word('Ukkiribikkiriga', f.fontSize, 2),
        lessThanOrEqualTo(f.labelWidth),
      );
    });

    test('a header that cannot fit skips the layout', () {
      final f = resolveMoodGridFit(
        width: 350,
        baseFontSize: 13.5,
        names: const ['Calm'],
        measureWord: (w, size) => w.length * 0.55 * size,
        measureHeight: (_, size, _) => size,
        headerFits: (headerWidth) => headerWidth > 200,
      );
      expect(f.layout, MoodGridLayout.stacked);
    });
  });

  for (final tag in ['en', 'te', 'te-Latn']) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('$tag at ${scale}x on 375×812: no overflow, one label size, '
          'whole words, 48 dp tiles, fixed order', (tester) async {
        tester.view.physicalSize = const Size(1125, 2436);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final db = memoryDb();
        await tester.pumpWidget(
          ProviderScope(
            overrides: testOverrides(db: db, locale: tag),
            child: localized(const CheckInScreen(), locale: localeFromTag(tag)),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        // At 200 % the title and subtitle can push the grid below the fold.
        await tester.scrollUntilVisible(find.byType(MoodGrid), 300);
        expect(tester.takeException(), isNull);

        final sizes = <double>{};
        for (final m in moodCatalog) {
          final tile = find.byKey(ValueKey('mood-${m.id}'));
          expect(tile, findsOneWidget);
          final text = tester.widget<Text>(
            find.descendant(of: tile, matching: find.byType(Text)),
          );
          sizes.add(text.style!.fontSize!);

          // Every word fits its line: nothing breaks inside a word.
          final rp = tester.renderObject<RenderParagraph>(
            find.descendant(of: tile, matching: find.byType(RichText)),
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

          final size = tester.getSize(tile);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        expect(sizes, hasLength(1), reason: 'one label size: $sizes');
        // Readable: at 1.0 never below the floor; at large scales the
        // rendered size stays above it too. (The test font is much wider
        // than the real ones, so it hits the extreme fallback at 200 %.)
        if (scale == 1.0) {
          expect(sizes.single, greaterThanOrEqualTo(moodLabelMinFontSize));
        }
        expect(
          sizes.single * scale,
          greaterThanOrEqualTo(moodLabelMinFontSize),
        );

        // Fixed energy × pleasantness order in every layout.
        Offset at(String id) =>
            tester.getTopLeft(find.byKey(ValueKey('mood-$id')));
        expect(at('overwhelmed').dy, lessThan(at('melancholy').dy));
        expect(at('joyful').dy, lessThan(at('calm').dy));
        expect(
          at('overwhelmed').dy < at('joyful').dy ||
              at('overwhelmed').dx < at('joyful').dx,
          isTrue,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }

  testWidgets('each tile still reads name + group (REQ-A11Y-04), and the '
      'title is a heading', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: memoryDb()),
        child: localized(const CheckInScreen()),
      ),
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel('Anxious, Storm group, high energy, unpleasant'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.text('How are you feeling?')),
      matchesSemantics(label: 'How are you feeling?', isHeader: true),
    );

    handle.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
