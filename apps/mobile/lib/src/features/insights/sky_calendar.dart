import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/theme/aura_tokens.dart';
import '../checkin/quadrant_glyph.dart';
import 'insights_copy.dart';
import 'insights_providers.dart';
import 'sky_painter.dart';

enum SkyView { month, year }

/// The Aura Sky calendar (PRD F10 "Sky calendar"): each day is a star in its
/// most frequent quadrant's colour and glyph, a split star for mixed days, a
/// faint ring for rest days; quiet days are plain dark sky, never grey or
/// crossed out. Month and year views; tap a day for its entries.
///
/// Never gated (REQ-INS-05). Each day is one screen-reader node with its
/// date and quadrant in words (REQ-A11Y-10). The halo shimmers slowly; under
/// Reduce Motion it is still.
class SkyCalendar extends StatefulWidget {
  const SkyCalendar({
    super.key,
    required this.model,
    required this.localeTag,
    required this.onDayTap,
  });

  final InsightsModel model;
  final String localeTag;
  final ValueChanged<LocalDay> onDayTap;

  static const Key monthViewKey = ValueKey('sky-month');
  static const Key yearViewKey = ValueKey('sky-year');
  static Key dayKey(LocalDay day) => ValueKey('sky-day-${day.toIso()}');
  static Key monthTileKey(int month) => ValueKey('sky-year-month-$month');

  @override
  State<SkyCalendar> createState() => _SkyCalendarState();
}

class _SkyCalendarState extends State<SkyCalendar>
    with SingleTickerProviderStateMixin {
  SkyView _view = SkyView.month;
  late int _year = widget.model.today.year;
  late int _month = widget.model.today.month;

  AnimationController? _twinkle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion: no controller at all, so nothing ticks.
    if (reduceMotionOf(context)) {
      _twinkle?.dispose();
      _twinkle = null;
    } else {
      _twinkle ??= AnimationController(
        vsync: this,
        duration: const Duration(seconds: 7),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _twinkle?.dispose();
    super.dispose();
  }

  LocalDay get _today => widget.model.today;
  LocalDay get _first => widget.model.firstDay;

  bool get _canGoBack => _view == SkyView.month
      ? (_year * 12 + _month) > (_first.year * 12 + _first.month)
      : _year > _first.year;

  bool get _canGoForward => _view == SkyView.month
      ? (_year * 12 + _month) < (_today.year * 12 + _today.month)
      : _year < _today.year;

  void _step(int delta) => setState(() {
    if (_view == SkyView.year) {
      _year += delta;
      return;
    }
    final m = _year * 12 + (_month - 1) + delta;
    _year = m ~/ 12;
    _month = m % 12 + 1;
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final month = _view == SkyView.month;
    final title = month
        ? monthYearLabel(widget.localeTag, _year, _month)
        : '$_year';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<SkyView>(
          key: const ValueKey('sky-view-switch'),
          segments: [
            ButtonSegment(
              value: SkyView.month,
              label: Text(l.insights_viewMonth),
            ),
            ButtonSegment(
              value: SkyView.year,
              label: Text(l.insights_viewYear),
            ),
          ],
          selected: {_view},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _view = s.first),
        ),
        const SizedBox(height: AuraSpace.s),
        Row(
          children: [
            IconButton(
              key: const ValueKey('sky-prev'),
              tooltip: month ? l.insights_prevMonth : l.insights_prevYear,
              onPressed: _canGoBack ? () => _step(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  title,
                  key: const ValueKey('sky-title'),
                  textAlign: TextAlign.center,
                  style: t.titleMedium,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('sky-next'),
              tooltip: month ? l.insights_nextMonth : l.insights_nextYear,
              onPressed: _canGoForward ? () => _step(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.xs),
        AnimatedSwitcher(
          duration: reduceMotionOf(context)
              ? reducedMotionFade
              : AuraMotion.calm,
          child: month
              ? _MonthGrid(
                  key: SkyCalendar.monthViewKey,
                  model: widget.model,
                  localeTag: widget.localeTag,
                  days: calendarMonth(_year, _month),
                  twinkle: _twinkle,
                  onDayTap: widget.onDayTap,
                )
              : _YearGrid(
                  key: SkyCalendar.yearViewKey,
                  model: widget.model,
                  localeTag: widget.localeTag,
                  year: _year,
                  onMonthTap: (m) => setState(() {
                    _month = m;
                    _view = SkyView.month;
                  }),
                ),
        ),
        const SizedBox(height: AuraSpace.m),
        const _Legend(),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    super.key,
    required this.model,
    required this.localeTag,
    required this.days,
    required this.twinkle,
    required this.onDayTap,
  });

  final InsightsModel model;
  final String localeTag;
  final DayRange days;
  final Animation<double>? twinkle;
  final ValueChanged<LocalDay> onDayTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final initials = weekdayInitials(localeTag);
    final lead = isoWeekday(days.from) - 1;
    final slots = lead + days.length;
    final rows = (slots / 7).ceil();

    return LayoutBuilder(
      builder: (context, box) {
        final cell = box.maxWidth / 7;
        return Column(
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  for (final d in initials)
                    SizedBox(
                      width: cell,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          d,
                          style: t.labelSmall?.copyWith(
                            color: AuraColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.xs),
            for (var r = 0; r < rows; r++)
              Row(
                children: [
                  for (var c = 0; c < 7; c++)
                    SizedBox.square(
                      dimension: cell,
                      child: () {
                        final i = r * 7 + c - lead;
                        if (i < 0 || i >= days.length) {
                          return const SizedBox.shrink();
                        }
                        final day = days.from.addDays(i);
                        return _DayCell(
                          day: day,
                          model: model,
                          localeTag: localeTag,
                          twinkle: twinkle,
                          onTap: onDayTap,
                        );
                      }(),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.model,
    required this.localeTag,
    required this.twinkle,
    required this.onTap,
  });

  final LocalDay day;
  final InsightsModel model;
  final String localeTag;
  final Animation<double>? twinkle;
  final ValueChanged<LocalDay> onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final future = day.isAfter(model.today);
    final star = future ? DayStar.empty : model.starOf(day);
    final count = model.byDay[day]?.length ?? 0;
    final label = daySemantics(l, dayLabel(localeTag, day), star, count);

    return LayoutBuilder(
      builder: (context, box) {
        final size = box.maxWidth;
        final number = Text(
          '${day.day}',
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(maxScaleFactor: 1.4),
          style: t.labelSmall?.copyWith(
            color: future ? AuraColors.textMuted : AuraColors.textSoft,
          ),
        );
        return Semantics(
          container: true,
          button: !future,
          label: label,
          hint: count > 0 ? l.insights_dayHint : null,
          excludeSemantics: true,
          onTap: future ? null : () => onTap(day),
          child: InkWell(
            key: SkyCalendar.dayKey(day),
            customBorder: const CircleBorder(),
            onTap: future ? null : () => onTap(day),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: StarHaloPainter(
                      star: star,
                      twinkle: twinkle,
                      phase: (day.day * 0.137) % 1,
                      today: day == model.today,
                    ),
                  ),
                ),
                _Glyphs(star: star, size: size),
                PositionedDirectional(top: 2, start: 4, child: number),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The quadrant glyph(s) of a day: one, two side by side, or a small 2×2.
class _Glyphs extends StatelessWidget {
  const _Glyphs({required this.star, required this.size});

  final DayStar star;
  final double size;

  @override
  Widget build(BuildContext context) {
    final qs = star.quadrants;
    if (qs.isEmpty) return const SizedBox.shrink();
    if (qs.length == 1) return QuadrantGlyph(qs.single, size: size * 0.42);
    final g = qs.length == 2 ? size * 0.3 : size * 0.24;
    Widget glyph(Quadrant q) => QuadrantGlyph(q, size: g);
    if (qs.length == 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [glyph(qs[0]), glyph(qs[1])],
      );
    }
    return SizedBox(
      width: g * 2,
      child: Wrap(children: [for (final q in qs) glyph(q)]),
    );
  }
}

class _YearGrid extends StatelessWidget {
  const _YearGrid({
    super.key,
    required this.model,
    required this.localeTag,
    required this.year,
    required this.onMonthTap,
  });

  final InsightsModel model;
  final String localeTag;
  final int year;
  final ValueChanged<int> onMonthTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final today = model.today;
    // Two columns at large text, three otherwise.
    final columns = MediaQuery.textScalerOf(context).scale(14) > 20 ? 2 : 3;

    DayStar starOf(LocalDay d) =>
        d.isAfter(today) ? DayStar.empty : model.starOf(d);

    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - AuraSpace.s * (columns - 1)) / columns;
        return Wrap(
          spacing: AuraSpace.s,
          runSpacing: AuraSpace.s,
          children: [
            for (var m = 1; m <= 12; m++)
              () {
                final days = calendarMonth(year, m);
                final future = days.from.isAfter(today);
                final name = monthLabel(localeTag, m);
                return SizedBox(
                  width: width,
                  child: Semantics(
                    container: true,
                    button: !future,
                    label: l.insights_monthSemantic(
                      monthYearLabel(localeTag, year, m),
                      model.daysIn(days),
                    ),
                    excludeSemantics: true,
                    onTap: future ? null : () => onMonthTap(m),
                    child: InkWell(
                      key: SkyCalendar.monthTileKey(m),
                      borderRadius: BorderRadius.circular(AuraRadius.s),
                      onTap: future ? null : () => onMonthTap(m),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: kMinInteractiveDimension,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AuraSpace.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: t.labelMedium?.copyWith(
                                  color: future
                                      ? AuraColors.textMuted
                                      : AuraColors.textSoft,
                                ),
                              ),
                              const SizedBox(height: 2),
                              AspectRatio(
                                aspectRatio: 7 / 6,
                                child: CustomPaint(
                                  painter: YearMonthPainter(
                                    days: days,
                                    stars: starOf,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }(),
          ],
        );
      },
    );
  }
}

/// What the marks mean: the four quadrants (glyph + name), a rest day and a
/// mixed day. Read as plain text by screen readers.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: AuraColors.textSoft);
    Widget item(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: mark),
        const SizedBox(width: AuraSpace.xs),
        Flexible(child: Text(label, style: t)),
      ],
    );
    return Wrap(
      spacing: AuraSpace.l,
      runSpacing: AuraSpace.s,
      children: [
        for (final q in Quadrant.values)
          item(QuadrantGlyph(q, size: 16), quadrantName(l, q)),
        item(
          SizedBox.square(
            dimension: 16,
            child: CustomPaint(painter: StarHaloPainter(star: DayStar.rest)),
          ),
          l.insights_legendRest,
        ),
        item(
          const SizedBox(
            width: 16,
            height: 16,
            child: Row(
              children: [
                QuadrantGlyph(Quadrant.rain, size: 8),
                QuadrantGlyph(Quadrant.sunrise, size: 8),
              ],
            ),
          ),
          l.insights_legendMixed,
        ),
      ],
    );
  }
}
