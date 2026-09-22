import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/aura_tokens.dart';
import 'quadrant_glyph.dart';

/// The fixed 4×4 mood grid: energy (up/down) × pleasantness (left/right).
/// Never reorders. Every quadrant gets the same treatment — Storm is not
/// darker or "worse" than Sunrise.
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final axis = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: AuraColors.textMuted, letterSpacing: 0.6);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Label width inside a tile: half a quadrant minus paddings/borders.
        final quadWidth = (constraints.maxWidth - AuraSpace.s) / 2;
        // Keep in step with the card (6) and tile (3) horizontal paddings.
        final tileWidth = (quadWidth - 2 * 6 - 2 - 6) / 2;
        final labelWidth = tileWidth - 2 * 3 - 2;
        Widget quad(Quadrant q) => Expanded(
          child: _QuadrantCard(
            quadrant: q,
            selected: selected,
            onSelected: onSelected,
            localeTag: localeTag,
            labelWidth: labelWidth,
          ),
        );
        return _grid(l, axis, quad);
      },
    );
  }

  Widget _grid(
    AppLocalizations l,
    TextStyle? axis,
    Widget Function(Quadrant) quad,
  ) {
    return Column(
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              Text('↑ ${l.checkin_moreEnergy}', style: axis),
              const Spacer(),
              Text('${l.checkin_pleasant} →', style: axis),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              quad(Quadrant.storm),
              const SizedBox(width: AuraSpace.s),
              quad(Quadrant.sunrise),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              quad(Quadrant.rain),
              const SizedBox(width: AuraSpace.s),
              quad(Quadrant.moonlight),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s),
        ExcludeSemantics(
          child: Row(
            children: [
              Text('← ${l.checkin_unpleasant}', style: axis),
              const Spacer(),
              Text('↓ ${l.checkin_lessEnergy}', style: axis),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuadrantCard extends StatelessWidget {
  const _QuadrantCard({
    required this.quadrant,
    required this.selected,
    required this.onSelected,
    required this.localeTag,
    required this.labelWidth,
  });

  final double labelWidth;
  final Quadrant quadrant;
  final Mood? selected;
  final ValueChanged<Mood> onSelected;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = AuraColors.quadrant(quadrant);
    final moods = moodsIn(quadrant);
    final active = selected?.quadrant == quadrant;

    return AnimatedContainer(
      duration: AuraMotion.calm,
      curve: AuraMotion.ease,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: AuraSpace.s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        gradient: RadialGradient(
          center: const Alignment(-0.6, -0.8),
          radius: 1.4,
          colors: [
            Color.lerp(
              AuraColors.quadrantDeep(quadrant),
              accent,
              active ? 0.22 : 0.12,
            )!,
            AuraColors.quadrantDeep(quadrant),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: active ? 0.55 : 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 4,
              bottom: 6,
              top: 2,
            ),
            child: Row(
              children: [
                QuadrantGlyph(quadrant, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    quadrantName(l, quadrant),
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: accent),
                  ),
                ),
              ],
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _tile(context, moods[0]),
                const SizedBox(width: 6),
                _tile(context, moods[1]),
              ],
            ),
          ),
          const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _tile(context, moods[2]),
                const SizedBox(width: 6),
                _tile(context, moods[3]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Mood mood) => Expanded(
    child: MoodTile(
      mood: mood,
      selected: selected == mood,
      dimmed: selected != null && selected != mood,
      localeTag: localeTag,
      labelWidth: labelWidth,
      onTap: () => onSelected(mood),
    ),
  );
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
  });

  /// Width available for the name (see [MoodGrid]).
  final double labelWidth;

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
    final label = l.mood_semantic(
      name,
      quadrantName(l, mood.quadrant),
      mood.quadrant.energy == Energy.high
          ? l.semantic_highEnergy
          : l.semantic_lowEnergy,
      mood.quadrant.pleasant ? l.semantic_pleasant : l.semantic_unpleasant,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: selected ? 1.04 : 1,
        duration: AuraMotion.quick,
        child: AnimatedOpacity(
          opacity: dimmed ? 0.62 : 1,
          duration: AuraMotion.quick,
          child: Material(
            color: selected
                ? accent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.035),
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
                HapticFeedback.selectionClick();
                onTap();
              },
              splashColor: accent.withValues(alpha: 0.2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MoodDot(color: accent, lit: selected),
                      const SizedBox(height: 6),
                      _FitWordsText(
                        name,
                        maxWidth: labelWidth,
                        locale: localeFromTag(localeTag),
                        style: theme.textTheme.labelMedium!.copyWith(
                          fontSize: localeTag == 'te' ? 12.5 : 13.5,
                          letterSpacing: 0,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AuraColors.text,
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

/// Centered label that shrinks (down to 75 %) so its longest word fits on
/// one line — long romanized words ("Ukkiribikkiriga") never break mid-word.
/// Still wraps between words, and still honours the user's text scale.
class _FitWordsText extends StatelessWidget {
  const _FitWordsText(
    this.text, {
    required this.style,
    required this.locale,
    required this.maxWidth,
  });

  final String text;
  final TextStyle style;
  final Locale locale;

  /// Width available for the label (measured once by [MoodGrid]; a
  /// LayoutBuilder cannot sit under the grid's IntrinsicHeight rows).
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    var fitted = style;
    final longest = text
        .split(RegExp(r'\s+'))
        .reduce((a, b) => a.length >= b.length ? a : b);
    final painter = TextPainter(
      text: TextSpan(text: longest, style: style, locale: locale),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    if (maxWidth.isFinite && painter.width > maxWidth && painter.width > 0) {
      // 3 % margin for glyph rounding; never below 62 % of the base size.
      final factor = (maxWidth / painter.width * 0.97).clamp(0.6, 1.0);
      fitted = style.copyWith(fontSize: style.fontSize! * factor);
    }
    painter.dispose();
    return Text(
      text,
      textAlign: TextAlign.center,
      style: fitted,
      locale: locale,
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
    width: lit ? 14 : 9,
    height: lit ? 14 : 9,
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
