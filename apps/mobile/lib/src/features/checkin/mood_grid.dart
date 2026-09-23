import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/haptics.dart';
import '../../core/a11y/motion.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/aura_tokens.dart';
import 'quadrant_glyph.dart';

/// Smallest mood-label size (logical px, before the user's text scale). Below
/// this the grid switches to a roomier layout instead of shrinking further.
const double moodLabelMinFontSize = 11;

/// Opacity of the other tiles once a mood is picked. 0.72 keeps the label at
/// ≥ 4.5:1 over the brightest tile ground in every quadrant (REQ-A11Y-03;
/// test/checkin_contrast_test.dart). 0.62 dropped to 4.0:1 on Sunrise.
const double moodTileDimmedOpacity = 0.72;

/// White wash of an unselected tile over its quadrant card.
const double moodTileWashAlpha = 0.035;

/// The brightest ground of a quadrant card: the centre of its radial wash
/// ([active] = the quadrant holding the selected mood).
Color quadrantCardGlow(Quadrant q, {required bool active}) => Color.lerp(
  AuraColors.quadrantDeep(q),
  AuraColors.quadrant(q),
  active ? 0.22 : 0.12,
)!;

// Geometry shared by the layout maths and the widgets below.
const double _cardPadH = 5;
const double _cardBorder = 1;
const double _tileGap = 5;
const double _tilePadH = 3;
const double _labelSlack = 1; // float rounding in the Row split
const double _headerGlyph = 16;
const double _headerGap = 6;
const double _headerStart = 4;
const double _dotBox = 14;

/// How the 16 moods are arranged. Every layout keeps the fixed
/// energy × pleasantness order (Storm, Sunrise, Rain, Moonlight; REQ-A11Y-10)
/// and gives each quadrant the same geometry.
enum MoodGridLayout {
  /// 2 × 2 quadrants, each a 2 × 2 of moods (the default).
  grid,

  /// 2 × 2 quadrants, each with its moods one per row: twice the label
  /// width, same energy × pleasantness axes (long names, narrow phones).
  tall,

  /// One quadrant per row, its moods in a 2 × 2 (large text).
  stacked,

  /// One quadrant per row, one mood per row (very large text).
  list,
}

extension on MoodGridLayout {
  /// Quadrants sit side by side (the axes read left/right, up/down).
  bool get twoByTwo =>
      this == MoodGridLayout.grid || this == MoodGridLayout.tall;

  /// Moods per row inside a quadrant.
  int get columns =>
      this == MoodGridLayout.grid || this == MoodGridLayout.stacked ? 2 : 1;
}

/// One label size for the whole grid, and the layout it fits in.
@immutable
class MoodGridFit {
  const MoodGridFit({
    required this.layout,
    required this.fontSize,
    required this.labelWidth,
    required this.labelHeight,
  });

  final MoodGridLayout layout;

  /// Shared label size (before text scaling).
  final double fontSize;

  /// Width every label is laid out in.
  final double labelWidth;

  /// Tallest label at [fontSize]: every label gets this height, so tiles
  /// stay equal even when a two-word name wraps between its words.
  final double labelHeight;
}

/// Width a mood label gets in [layout] for a grid [width] wide.
double moodLabelWidth(MoodGridLayout layout, double width) {
  final columns = layout.columns;
  final inner = _quadWidth(layout, width) - 2 * (_cardPadH + _cardBorder);
  final tile = (inner - _tileGap * (columns - 1)) / columns;
  return tile - 2 * _tilePadH - _labelSlack;
}

/// Width a quadrant name gets in its card header.
double quadrantHeaderWidth(MoodGridLayout layout, double width) =>
    _quadWidth(layout, width) -
    2 * (_cardPadH + _cardBorder) -
    _headerStart -
    _headerGlyph -
    _headerGap;

double _quadWidth(MoodGridLayout layout, double width) =>
    layout.twoByTwo ? (width - AuraSpace.s) / 2 : width;

/// Picks the first layout (grid → tall → stacked → list) in which one label
/// size fits the longest word of every mood on one line, never below
/// [moodLabelMinFontSize]. Words never break inside (romanized names like
/// "Ukkiribikkiriga" are long); names still wrap between words. Only when
/// even one mood per row can't hold a word at the floor does the size go
/// lower (the user's text scale is then very large).
///
/// [measureWord] returns a word's width at a label size (text scale
/// included); [measureHeight] a name's height laid out in a width;
/// [headerFits] says whether the quadrant names fit a header width.
MoodGridFit resolveMoodGridFit({
  required double width,
  required double baseFontSize,
  required Iterable<String> names,
  required double Function(String word, double fontSize) measureWord,
  required double Function(String name, double fontSize, double maxWidth)
  measureHeight,
  bool Function(double headerWidth)? headerFits,
}) {
  final words = {
    for (final n in names)
      ...n.split(RegExp(r'\s+')).where((w) => w.isNotEmpty),
  };
  double widest(double size) =>
      words.fold(0, (m, w) => math.max(m, measureWord(w, size)));
  MoodGridFit fit(MoodGridLayout layout, double size, double labelWidth) =>
      MoodGridFit(
        layout: layout,
        fontSize: size,
        labelWidth: labelWidth,
        labelHeight: names.fold(
          0,
          (m, n) => math.max(m, measureHeight(n, size, labelWidth)),
        ),
      );

  for (final layout in MoodGridLayout.values) {
    final labelWidth = moodLabelWidth(layout, width);
    if (labelWidth <= 0) continue;
    if (headerFits != null && !headerFits(quadrantHeaderWidth(layout, width))) {
      continue;
    }
    var size = baseFontSize;
    var w = widest(size);
    if (w > labelWidth) {
      size = baseFontSize * labelWidth / w;
      // Text scaling can be non-linear and glyphs round: re-measure.
      for (var i = 0; i < 8 && (w = widest(size)) > labelWidth; i++) {
        size *= 0.97;
      }
      // The 3 % steps can overshoot below the floor for a near-miss word
      // (it fits at the floor itself): take the floor then.
      if (size < moodLabelMinFontSize) {
        final atFloor = widest(moodLabelMinFontSize);
        if (atFloor <= labelWidth) {
          size = moodLabelMinFontSize;
          w = atFloor;
        }
      }
    }
    if (size >= moodLabelMinFontSize && w <= labelWidth) {
      return fit(layout, size, labelWidth);
    }
  }
  // Nothing fits at the floor, even one mood per row (an extreme text scale
  // on a small phone): shrink until whole words fit anyway. The user's own
  // text scale still keeps them large, and no word breaks inside.
  final labelWidth = math.max(1.0, moodLabelWidth(MoodGridLayout.list, width));
  var size = moodLabelMinFontSize;
  var w = widest(size);
  for (var i = 0; i < 12 && w > labelWidth; i++) {
    size *= labelWidth / w * 0.99;
    w = widest(size);
  }
  return fit(MoodGridLayout.list, size, labelWidth);
}

/// The fixed 4×4 mood grid: energy (up/down) × pleasantness (left/right).
/// Never reorders. Every quadrant gets the same treatment — Storm is not
/// darker or "worse" than Sunrise. All 16 labels share one size; when that
/// size would get too small the grid becomes roomier ([MoodGridLayout]).
class MoodGrid extends StatelessWidget {
  const MoodGrid({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.localeTag,
  });

  final Mood? selected;
  final ValueChanged<Mood> onSelected;
  final String localeTag;

  /// Base label style: the bold weight is measured, so selecting a mood
  /// (bold label) never makes a word overflow.
  static TextStyle labelBaseStyle(ThemeData theme, String localeTag) =>
      theme.textTheme.labelMedium!.copyWith(
        fontSize: localeTag == 'te' ? 12.5 : 13.5,
        letterSpacing: 0,
        fontWeight: FontWeight.w700,
        color: AuraColors.text,
      );

  static TextStyle headerStyle(ThemeData theme, Quadrant q) =>
      theme.textTheme.labelMedium!.copyWith(color: AuraColors.quadrant(q));

  // One-entry cache: the fit only changes with width, locale, text scale or
  // theme — not with the selection, which rebuilds the grid on every tap.
  static Object? _cacheKey;
  static MoodGridFit? _cacheFit;

  MoodGridFit _fit(BuildContext context, double width) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    final locale = localeFromTag(localeTag);
    final base = labelBaseStyle(theme, localeTag);
    final quadrantNames = [for (final q in Quadrant.values) quadrantName(l, q)];
    final key = (
      width,
      localeTag,
      scaler,
      dir,
      base,
      theme.textTheme.labelMedium,
      quadrantNames.join('|'),
    );
    if (key == _cacheKey && _cacheFit != null) return _cacheFit!;

    TextPainter painter(String text, TextStyle style, {double? maxWidth}) =>
        TextPainter(
          text: TextSpan(text: text, style: style, locale: locale),
          textDirection: dir,
          textScaler: scaler,
          textAlign: TextAlign.center,
          maxLines: maxWidth == null ? 1 : null,
        )..layout(maxWidth: maxWidth ?? double.infinity);

    double measure(String text, TextStyle style) {
      final p = painter(text, style);
      final w = p.width;
      p.dispose();
      return w;
    }

    final fit = resolveMoodGridFit(
      width: width,
      baseFontSize: base.fontSize!,
      names: [for (final m in moodCatalog) m.nameFor(localeTag)],
      measureWord: (word, size) => measure(word, base.copyWith(fontSize: size)),
      measureHeight: (name, size, maxWidth) {
        final p = painter(
          name,
          base.copyWith(fontSize: size),
          maxWidth: maxWidth,
        );
        final h = p.height;
        p.dispose();
        return h;
      },
      headerFits: (headerWidth) {
        for (final q in Quadrant.values) {
          for (final word in quadrantName(l, q).split(RegExp(r'\s+'))) {
            if (measure(word, headerStyle(theme, q)) > headerWidth) {
              return false;
            }
          }
        }
        return true;
      },
    );
    _cacheKey = key;
    _cacheFit = fit;
    return fit;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final axis = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: AuraColors.textMuted, letterSpacing: 0.6);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = _fit(context, constraints.maxWidth);
        Widget quad(Quadrant q) => _QuadrantCard(
          quadrant: q,
          selected: selected,
          onSelected: onSelected,
          localeTag: localeTag,
          fit: fit,
        );
        return fit.layout.twoByTwo ? _grid(l, axis, quad) : _stacked(quad);
      },
    );
  }

  Widget _grid(
    AppLocalizations l,
    TextStyle? axis,
    Widget Function(Quadrant) quad,
  ) {
    Widget axes(String start, String end) => ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(start, style: axis)),
          const SizedBox(width: AuraSpace.s),
          Expanded(
            child: Text(end, style: axis, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
    Widget row(Quadrant a, Quadrant b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: quad(a)),
          const SizedBox(width: AuraSpace.s),
          Expanded(child: quad(b)),
        ],
      ),
    );
    return Column(
      children: [
        axes('↑ ${l.checkin_moreEnergy}', '${l.checkin_pleasant} →'),
        const SizedBox(height: AuraSpace.s),
        row(Quadrant.storm, Quadrant.sunrise),
        const SizedBox(height: AuraSpace.s),
        row(Quadrant.rain, Quadrant.moonlight),
        const SizedBox(height: AuraSpace.s),
        axes('← ${l.checkin_unpleasant}', '↓ ${l.checkin_lessEnergy}'),
      ],
    );
  }

  /// Same reading order as the grid (row by row); each card names its
  /// energy and pleasantness since there are no spatial axes.
  Widget _stacked(Widget Function(Quadrant) quad) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final q in const [
        Quadrant.storm,
        Quadrant.sunrise,
        Quadrant.rain,
        Quadrant.moonlight,
      ]) ...[
        quad(q),
        if (q != Quadrant.moonlight) const SizedBox(height: AuraSpace.s),
      ],
    ],
  );
}

class _QuadrantCard extends StatelessWidget {
  const _QuadrantCard({
    required this.quadrant,
    required this.selected,
    required this.onSelected,
    required this.localeTag,
    required this.fit,
  });

  final Quadrant quadrant;
  final Mood? selected;
  final ValueChanged<Mood> onSelected;
  final String localeTag;
  final MoodGridFit fit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = AuraColors.quadrant(quadrant);
    final moods = moodsIn(quadrant);
    final active = selected?.quadrant == quadrant;
    final stacked = !fit.layout.twoByTwo;

    Widget tile(Mood mood) => MoodTile(
      mood: mood,
      selected: selected == mood,
      dimmed: selected != null && selected != mood,
      localeTag: localeTag,
      labelWidth: fit.labelWidth,
      labelHeight: fit.labelHeight,
      fontSize: fit.fontSize,
      onTap: () => onSelected(mood),
    );
    Widget pair(Mood a, Mood b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: tile(a)),
          const SizedBox(width: _tileGap),
          Expanded(child: tile(b)),
        ],
      ),
    );

    return AnimatedContainer(
      duration: AuraMotion.calm,
      curve: AuraMotion.ease,
      padding: const EdgeInsets.symmetric(
        horizontal: _cardPadH,
        vertical: AuraSpace.s,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        gradient: RadialGradient(
          center: const Alignment(-0.6, -0.8),
          radius: 1.4,
          colors: [
            quadrantCardGlow(quadrant, active: active),
            AuraColors.quadrantDeep(quadrant),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: active ? 0.55 : 0.18),
          width: _cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: _headerStart,
              bottom: 6,
              top: 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    QuadrantGlyph(quadrant, size: _headerGlyph),
                    const SizedBox(width: _headerGap),
                    Flexible(
                      child: Text(
                        quadrantName(l, quadrant),
                        style: MoodGrid.headerStyle(theme, quadrant),
                      ),
                    ),
                  ],
                ),
                if (stacked)
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: _headerGlyph + _headerGap,
                      ),
                      child: Text(
                        l.checkin_quadrantAxes(
                          quadrant.energy == Energy.high
                              ? l.checkin_moreEnergy
                              : l.checkin_lessEnergy,
                          quadrant.pleasant
                              ? l.checkin_pleasant
                              : l.checkin_unpleasant,
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AuraColors.textSoft,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (fit.layout.columns == 1)
            for (final (i, m) in moods.indexed) ...[
              if (i > 0) const SizedBox(height: _tileGap),
              tile(m),
            ]
          else ...[
            pair(moods[0], moods[1]),
            const SizedBox(height: _tileGap),
            pair(moods[2], moods[3]),
          ],
        ],
      ),
    );
  }
}

class MoodTile extends StatelessWidget {
  const MoodTile({
    super.key,
    required this.mood,
    required this.selected,
    required this.dimmed,
    required this.localeTag,
    required this.onTap,
    this.labelWidth = double.infinity,
    this.labelHeight = 0,
    this.fontSize,
  });

  /// Width every label in the grid is laid out in (see [MoodGridFit]).
  final double labelWidth;

  /// Height every label in the grid gets, so all tiles stay the same size.
  final double labelHeight;

  /// Shared label size; `null` uses the base size.
  final double? fontSize;

  final Mood mood;
  final bool selected;
  final bool dimmed;
  final String localeTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = AuraColors.quadrant(mood.quadrant);
    final name = mood.nameFor(localeTag);
    final reduce = reduceMotionOf(context);
    final label = l.mood_semantic(
      name,
      quadrantName(l, mood.quadrant),
      mood.quadrant.energy == Energy.high
          ? l.semantic_highEnergy
          : l.semantic_lowEnergy,
      mood.quadrant.pleasant ? l.semantic_pleasant : l.semantic_unpleasant,
    );
    final base = MoodGrid.labelBaseStyle(theme, localeTag);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedScale(
        // No scale under Reduce Motion (REQ-A11Y-08).
        scale: selected && !reduce ? 1.04 : 1,
        duration: AuraMotion.quick,
        child: AnimatedOpacity(
          opacity: dimmed ? moodTileDimmedOpacity : 1,
          duration: AuraMotion.quick,
          child: Material(
            color: selected
                ? accent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: moodTileWashAlpha),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AuraRadius.s),
              side: BorderSide(
                color: selected ? accent : Colors.white.withValues(alpha: 0.06),
                width: selected ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('mood-${mood.id}'),
              onTap: () {
                AuraHaptics.selection();
                onTap();
              },
              splashColor: accent.withValues(alpha: 0.2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _tilePadH,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Fixed box: the lit (bigger) dot never shifts the
                      // label or changes the tile's height.
                      SizedBox.square(
                        dimension: _dotBox,
                        child: Center(
                          child: _MoodDot(color: accent, lit: selected),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: labelWidth.isFinite ? labelWidth : null,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: labelHeight),
                          child: Center(
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              locale: localeFromTag(localeTag),
                              style: base.copyWith(
                                fontSize: fontSize ?? base.fontSize,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodDot extends StatelessWidget {
  const _MoodDot({required this.color, required this.lit});

  final Color color;
  final bool lit;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AuraMotion.calm,
    width: lit ? _dotBox : 9,
    height: lit ? _dotBox : 9,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: lit ? Colors.white : color,
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: lit ? 0.9 : 0.45),
          blurRadius: lit ? 14 : 6,
          spreadRadius: lit ? 2 : 0,
        ),
      ],
    ),
  );
}
