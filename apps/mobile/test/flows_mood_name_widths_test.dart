import 'dart:io';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/theme/aura_tokens.dart';
import 'package:aura/src/features/checkin/mood_grid.dart';
import 'package:aura/src/features/checkin/quadrant_glyph.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The measurements behind docs/l10n/tenglish-mood-names.md: which mood
/// names keep the check-in grid out of its 4×4 layout at 1.0 text scale, and
/// whether the proposed shorter spellings would fit.
///
/// It runs the grid's own fit ([resolveMoodGridFit], 11 px floor, bold
/// labels measured, quadrant headers checked) with real fonts instead of the
/// test font: Roboto (Android's system font, from the Flutter SDK), the
/// bundled Noto Sans Telugu, and — on macOS only — SF Pro (iOS's system font,
/// SFNS.ttf at opsz 17 / wght 700; an approximation of the iPhone).
///
/// Print the full report:
///   AURA_MOOD_WIDTHS=1 flutter test test/flows_mood_name_widths_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const widths = [360.0, 375.0, 390.0, 412.0];
  final sdkFonts =
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts';
  final roboto = [
    '$sdkFonts/Roboto-Regular.ttf',
    '$sdkFonts/Roboto-Medium.ttf',
    '$sdkFonts/Roboto-Bold.ttf',
  ];
  const sf = ['/System/Library/Fonts/SFNS.ttf'];
  const telugu = [
    'assets/fonts/NotoSansTelugu-Regular.ttf',
    'assets/fonts/NotoSansTelugu-Medium.ttf',
    'assets/fonts/NotoSansTelugu-SemiBold.ttf',
  ];
  const devanagari = [
    'assets/fonts/NotoSansDevanagari-Regular.ttf',
    'assets/fonts/NotoSansDevanagari-Medium.ttf',
    'assets/fonts/NotoSansDevanagari-SemiBold.ttf',
  ];
  final hasRoboto = roboto.every((p) => File(p).existsSync());
  final hasSf = sf.every((p) => File(p).existsSync());

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
    if (hasRoboto) await load('Roboto', roboto);
    if (hasSf) await load('SFPro', sf);
    await load('NotoSansTelugu', telugu);
    await load('NotoSansDevanagari', devanagari);
  });

  /// The grid's label style for [tag], drawn in [font].
  TextStyle inFont(TextStyle s, String font) => s.copyWith(
    fontFamily: font,
    fontVariations: font == 'SFPro'
        ? [
            FontVariation.weight(s.fontWeight!.value.toDouble()),
            const FontVariation('opsz', 17),
          ]
        : null,
  );

  /// The same fit MoodGrid runs, for [names] on a [screenWidth] phone.
  MoodGridFit fitFor(
    String tag,
    String font,
    Iterable<String> names,
    double screenWidth,
  ) {
    final locale = localeFromTag(tag);
    final theme = buildAuraTheme(locale);
    final l = lookupAppLocalizations(locale);
    final base = inFont(MoodGrid.labelBaseStyle(theme, tag), font);
    double measure(String text, TextStyle style, {double? maxWidth}) {
      final p = TextPainter(
        text: TextSpan(text: text, style: style, locale: locale),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        textAlign: TextAlign.center,
        maxLines: maxWidth == null ? 1 : null,
      )..layout(maxWidth: maxWidth ?? double.infinity);
      final v = maxWidth == null ? p.width : p.height;
      p.dispose();
      return v;
    }

    return resolveMoodGridFit(
      // The check-in list pads the grid by the page gutter on both sides.
      width: screenWidth - 2 * AuraSpace.gutter,
      baseFontSize: base.fontSize!,
      names: names,
      measureWord: (w, size) => measure(w, base.copyWith(fontSize: size)),
      measureHeight: (n, size, max) =>
          measure(n, base.copyWith(fontSize: size), maxWidth: max),
      headerFits: (headerWidth) {
        for (final q in Quadrant.values) {
          final style = inFont(MoodGrid.headerStyle(theme, q), font);
          for (final word in quadrantName(l, q).split(RegExp(r'\s+'))) {
            if (measure(word, style) > headerWidth) return false;
          }
        }
        return true;
      },
    );
  }

  /// Widest word of [name] at the 11 px floor.
  double needs(String tag, String font, String name) {
    final theme = buildAuraTheme(localeFromTag(tag));
    final style = inFont(
      MoodGrid.labelBaseStyle(theme, tag),
      font,
    ).copyWith(fontSize: moodLabelMinFontSize);
    var widest = 0.0;
    for (final w in name.split(RegExp(r'\s+'))) {
      final p = TextPainter(
        text: TextSpan(text: w, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (p.width > widest) widest = p.width;
      p.dispose();
    }
    return widest;
  }

  List<int> fitsAt(String tag, String font, String name) => [
    for (final w in widths)
      if (fitFor(tag, font, [name], w).layout == MoodGridLayout.grid) w.toInt(),
  ];

  // Proposals in docs/l10n/tenglish-mood-names.md (for native review; the
  // catalogue is unchanged). Each must fit the 4×4 at 360 dp on Android.
  const teLatnProposals = [
    'Moddubaari', 'Moddugaa', 'Moddu baarinattu', // numb
    'Shaantanga', 'Prashantam ga', 'Shaantam ga', // calm
    'Thankful ga', 'Krutagnata', 'Krutagnyata', // grateful
    'Ukkiri bikkiriga', 'Ukkiribikkiri', 'Ukkiri bikkiri', // overwhelmed
    'Alasipoyi', 'Alasi poyinattu', 'Neerasanga', // drained
    'Andolanaga', 'Tension ga', 'Kangaruga', // anxious
    'Ashantiga', 'Ashaantiga', 'Kuduruga ledu', // restless
    'Aanandam ga', 'Anandanga', 'Husharuga', 'Utsahanga', // iOS-only ones
  ];
  const teProposals = [
    'అలసిపోయి', 'అలసటగా', 'నీరసంగా', // drained
    'మొద్దుబారి', 'మొద్దుగా', 'స్తబ్దంగా', // numb
    'ఉక్కిరిబిక్కిరి', 'సతమతంగా', // overwhelmed
  ];

  // Milestone B (docs/l10n/hinglish-mood-names.md): the one Hinglish name
  // that blocks (iOS, 360 dp) and the PRD 18 table's alternatives.
  const hiLatnProposals = [
    'Chidh', 'Khij', 'Frustrated', // frustrated (Jhunjhlahat)
    'Bahut bojh', 'Ghabrahat', 'Proud', // PRD 18 table
  ];
  const hiProposals = ['चिढ़', 'खीज', 'भारीपन', 'घबराहट'];

  test('every proposed spelling fits the 4×4 at 360 dp (Android / Telugu / '
      'Devanagari)', () {
    for (final name in teLatnProposals) {
      expect(fitsAt('te-Latn', 'Roboto', name), contains(360), reason: name);
    }
    for (final name in teProposals) {
      expect(fitsAt('te', 'NotoSansTelugu', name), contains(360), reason: name);
    }
    for (final name in hiLatnProposals) {
      expect(fitsAt('hi-Latn', 'Roboto', name), contains(360), reason: name);
    }
    for (final name in hiProposals) {
      expect(
        fitsAt('hi', 'NotoSansDevanagari', name),
        contains(360),
        reason: name,
      );
    }
  }, skip: hasRoboto ? false : 'Roboto not found in the Flutter SDK');

  test('Hindi and Hinglish mood names keep the 4×4 on Android and in '
      'Devanagari at 360 dp', () {
    for (final (tag, font) in const [
      ('hi-Latn', 'Roboto'),
      ('hi', 'NotoSansDevanagari'),
    ]) {
      final names = [for (final m in moodCatalog) m.nameFor(tag)];
      expect(
        fitFor(tag, font, names, 360).layout,
        MoodGridLayout.grid,
        reason: tag,
      );
    }
  }, skip: hasRoboto ? false : 'Roboto not found in the Flutter SDK');

  test(
    'report (AURA_MOOD_WIDTHS=1 prints it)',
    () {
      final out = StringBuffer();
      out.writeln(
        'label width: ${[for (final w in widths) '$w→${moodLabelWidth(MoodGridLayout.grid, w - 2 * AuraSpace.gutter)}']}',
      );
      for (final (tag, fonts) in [
        ('en', ['Roboto', if (hasSf) 'SFPro']),
        ('te-Latn', ['Roboto', if (hasSf) 'SFPro']),
        ('te', ['NotoSansTelugu']),
        // Milestone B: Hinglish and Hindi (docs/l10n/hinglish-mood-names.md).
        ('hi-Latn', ['Roboto', if (hasSf) 'SFPro']),
        ('hi', ['NotoSansDevanagari']),
      ]) {
        for (final font in fonts) {
          out.writeln('=== $tag / $font');
          final names = [for (final m in moodCatalog) m.nameFor(tag)];
          for (final w in widths) {
            final all = fitFor(tag, font, names, w);
            final blockers = [
              for (final n in names)
                if (fitFor(tag, font, [n], w).layout != MoodGridLayout.grid) n,
            ];
            out.writeln(
              '  ${w.toInt()} dp: ${all.layout.name} '
              '@${all.fontSize.toStringAsFixed(2)}  blockers: $blockers',
            );
          }
          final proposals = switch (tag) {
            'te' => teProposals,
            'te-Latn' => teLatnProposals,
            'hi' => hiProposals,
            'hi-Latn' => hiLatnProposals,
            _ => const <String>[],
          };
          for (final n in [...names, ...proposals]) {
            final need = needs(tag, font, n);
            // Screen width at which the label width equals the need.
            final minScreen = 4 * (need + 15.5) + 2 * AuraSpace.gutter + 8;
            out.writeln(
              '  ${need.toStringAsFixed(2)} px  ≥${minScreen.toStringAsFixed(0)} dp  '
              'fits ${fitsAt(tag, font, n)}  "$n"',
            );
          }
        }
      }
      // ignore: avoid_print
      print(out);
    },
    skip: !hasRoboto
        ? 'Roboto not found in the Flutter SDK'
        : Platform.environment['AURA_MOOD_WIDTHS'] == null
        ? 'set AURA_MOOD_WIDTHS=1 to print the report'
        : false,
  );
}
