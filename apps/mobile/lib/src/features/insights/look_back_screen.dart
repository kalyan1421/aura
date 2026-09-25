import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/db/database.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/help_app_bar.dart';
import '../checkin/quadrant_glyph.dart';
import '../history/history_format.dart';
import '../plus/sky_themes.dart';
import '../support/crisis_lexicon.dart';
import '../voice/voice_note_field.dart' show VoicePlaybackRow;
import '../voice/voice_playback.dart';
import 'insight_cards.dart';
import 'insights_copy.dart';
import 'look_back.dart';
import 'sky_painter.dart';

/// The way into Look back from Insights: the only one there is (PRD F10
/// "pull-only"). Shown only while [lookBackAvailableProvider] is true, i.e.
/// the safety gate is open and a past week has something to show. Opening it
/// pushes [LookBackScreen] on this tab's navigator; there is no route, so no
/// link, push, widget or share path can reach it.
class LookBackEntryCard extends ConsumerWidget {
  const LookBackEntryCard({super.key});

  static const Key cardKey = ValueKey('insights-look-back');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(lookBackAvailableProvider)) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return InsightCard(
      padding: EdgeInsets.zero,
      child: Semantics(
        button: true,
        child: InkWell(
          key: cardKey,
          borderRadius: BorderRadius.circular(AuraRadius.l),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LookBackScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.l),
            child: Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.history_rounded,
                    color: AuraColors.starlight,
                  ),
                ),
                const SizedBox(width: AuraSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.insights_lookBackTitle, style: t.titleMedium),
                      const SizedBox(height: AuraSpace.xs),
                      Text(
                        l.insights_lookBackTileBody,
                        style: t.bodyMedium?.copyWith(
                          color: AuraColors.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AuraColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Look back (PRD F10, REQ-INS-08): the person's sky from the same week 1
/// month, 6 months and 1 year ago, each a row of seven still stars. Tapping
/// a day lists its entries (mood, glyph, time); a note or voice note opens
/// only on a further tap. Weeks with nothing to show are left out.
///
/// Watches the safety gate the whole time it is open: if it closes (help was
/// opened from this screen's "I need help now", or a Storm check-in synced
/// in), the weeks give way to one calm line that never says why.
class LookBackScreen extends ConsumerWidget {
  const LookBackScreen({super.key});

  static const Key listKey = ValueKey('look-back-list');
  static const Key emptyKey = ValueKey('look-back-empty');
  static const Key closedKey = ValueKey('look-back-closed');
  static Key weekKey(int months) => ValueKey('look-back-week-$months');
  static Key dayKey(LocalDay day) => ValueKey('look-back-day-${day.toIso()}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final gate = ref.watch(lookBackGateProvider);
    final model = ref.watch(lookBackModelProvider);
    final localeTag = ref.watch(localeControllerProvider);
    final soft = t.bodyLarge?.copyWith(color: AuraColors.textSoft);

    Widget body;
    if (gate == null || !model.loaded) {
      body = const SizedBox.shrink(); // local reads: a blink at most
    } else if (!gate.isOpen) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.gutter),
          child: Text(
            l.insights_lookBackClosed,
            key: closedKey,
            textAlign: TextAlign.center,
            style: soft,
          ),
        ),
      );
    } else {
      body = ListView(
        key: listKey,
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.m,
          AuraSpace.s,
          AuraSpace.m,
          AuraSpace.xxl,
        ),
        children: [
          _Gutter(
            child: Text(
              l.insights_lookBackIntro,
              style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
            ),
          ),
          if (model.isEmpty) ...[
            const SizedBox(height: AuraSpace.xl),
            _Gutter(
              child: Text(
                l.insights_lookBackEmpty,
                key: emptyKey,
                textAlign: TextAlign.center,
                style: soft,
              ),
            ),
          ],
          for (final week in model.weeks) ...[
            const SizedBox(height: AuraSpace.l),
            _WeekSection(week: week, model: model, localeTag: localeTag),
          ],
          const SizedBox(height: AuraSpace.xl),
          _Gutter(
            child: Text(
              l.insights_lookBackSettingsHint,
              style: t.bodySmall?.copyWith(color: AuraColors.textMuted),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: helpAppBar(context, title: l.insights_lookBackTitle),
      body: PersonalSkyBackground(child: body),
    );
  }
}

class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AuraSpace.gutter - AuraSpace.m,
    ),
    child: child,
  );
}

String _weekTitle(AppLocalizations l, int months) => switch (months) {
  1 => l.insights_lookBackMonth,
  6 => l.insights_lookBackSixMonths,
  _ => l.insights_lookBackYear,
};

class _WeekSection extends ConsumerWidget {
  const _WeekSection({
    required this.week,
    required this.model,
    required this.localeTag,
  });

  final LookBackWeek week;
  final LookBackModel model;
  final String localeTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final from = week.window.range.from;
    final initials = weekdayInitials(localeTag);
    return InsightCard(
      key: LookBackScreen.weekKey(week.window.months),
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s,
        vertical: AuraSpace.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s),
            child: Semantics(
              header: true,
              child: Text(
                _weekTitle(l, week.window.months),
                style: t.titleMedium,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s),
            child: Text(
              l.insights_lookBackWeekOf(
                dateLabel(localeTag, from, model.today),
              ),
              style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
            ),
          ),
          const SizedBox(height: AuraSpace.s),
          LayoutBuilder(
            builder: (context, box) {
              final cell = box.maxWidth / 7;
              return Column(
                children: [
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          SizedBox(
                            width: cell,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                initials[(isoWeekday(from.addDays(i)) - 1)],
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
                  Row(
                    children: [
                      for (final day in week.sky.days)
                        SizedBox.square(
                          dimension: cell,
                          child: _LookBackDayCell(
                            day: day,
                            model: model,
                            localeTag: localeTag,
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One still star (no shimmer: Look back holds the past quietly, and needs
/// nothing to stop under Reduce Motion). Only days with entries to show are
/// tappable.
class _LookBackDayCell extends ConsumerWidget {
  const _LookBackDayCell({
    required this.day,
    required this.model,
    required this.localeTag,
  });

  final LookBackDay day;
  final LookBackModel model;
  final String localeTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final count = day.entryIds.length;
    final label = daySemantics(
      l,
      dayLabel(localeTag, day.day),
      day.star,
      count,
    );
    final open = count == 0
        ? null
        : () => showLookBackDaySheet(
            context,
            day: day,
            model: model,
            localeTag: localeTag,
            timezone: ref.read(timeContextProvider).timezone,
          );
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.maxWidth;
        return Semantics(
          container: true,
          button: open != null,
          label: label,
          hint: open != null ? l.insights_dayHint : null,
          excludeSemantics: true,
          onTap: open,
          child: InkWell(
            key: LookBackScreen.dayKey(day.day),
            customBorder: const CircleBorder(),
            onTap: open,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: StarHaloPainter(
                      star: day.star,
                      phase: (day.day.day * 0.137) % 1,
                    ),
                  ),
                ),
                _Glyphs(star: day.star, size: size),
                PositionedDirectional(
                  top: 2,
                  start: 4,
                  child: Text(
                    '${day.day.day}',
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.4),
                    style: t.labelSmall?.copyWith(color: AuraColors.textSoft),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The quadrant glyph(s) of a day (REQ-A11Y-10: never colour alone).
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

// ---- a day's entries ------------------------------------------------------------------

/// A Look back day's entries (mood, glyph, time). Notes and voice notes stay
/// closed; each opens only on a further tap of its entry. No edit, delete or
/// share here.
Future<void> showLookBackDaySheet(
  BuildContext context, {
  required LookBackDay day,
  required LookBackModel model,
  required String localeTag,
  required String timezone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (sheet) {
      final t = Theme.of(sheet).textTheme;
      final rows = [for (final id in day.entryIds) ?model.rows[id]];
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scroll) => ListView(
          key: const ValueKey('look-back-day-sheet'),
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.gutter,
            AuraSpace.l,
            AuraSpace.gutter,
            AuraSpace.xxl,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(
                dateLabel(localeTag, day.day, model.today),
                style: t.titleLarge,
              ),
            ),
            const SizedBox(height: AuraSpace.m),
            for (final row in rows)
              LookBackEntryTile(
                row: row,
                localeTag: localeTag,
                timezone: timezone,
              ),
          ],
        ),
      );
    },
  );
}

/// One entry: mood, glyph and time. When it has a note or a voice note, a
/// "Show note" button opens them (the further tap); the lexicon is re-run on
/// the note right then, and a match keeps it closed.
class LookBackEntryTile extends ConsumerStatefulWidget {
  const LookBackEntryTile({
    super.key,
    required this.row,
    required this.localeTag,
    required this.timezone,
  });

  final CheckInRow row;
  final String localeTag;
  final String timezone;

  static Key tileKey(String id) => ValueKey('look-back-entry-$id');
  static Key openKey(String id) => ValueKey('look-back-open-$id');
  static Key hideKey(String id) => ValueKey('look-back-hide-$id');
  static Key noteKey(String id) => ValueKey('look-back-note-$id');
  static Key voiceKey(String id) => ValueKey('look-back-voice-$id');

  @override
  ConsumerState<LookBackEntryTile> createState() => _LookBackEntryTileState();
}

class _LookBackEntryTileState extends ConsumerState<LookBackEntryTile> {
  bool _open = false;
  VoicePlaybackController? _playback;

  CheckInRow get _row => widget.row;

  bool get _hasVoice => _row.voiceFile != null || _row.voicePath != null;

  String? get _note {
    final n = _row.note;
    if (n == null || n.trim().isEmpty) return null;
    return n;
  }

  @override
  void dispose() {
    _playback?.dispose();
    super.dispose();
  }

  VoicePlaybackController _voice() {
    final existing = _playback;
    if (existing != null) return existing;
    final ms = _row.voiceMs;
    return _playback = VoicePlaybackController(
      createPlayer: ref.read(voicePlayerFactoryProvider),
      load: () => ref
          .read(voiceLoaderProvider)
          .load(checkInId: _row.id, file: _row.voiceFile, path: _row.voicePath),
      deleteTemp: ref.read(voiceStoreProvider).deleteTemp,
      duration: ms == null ? null : Duration(milliseconds: ms),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final mood = moodById(_row.moodId);
    final quadrant = mood?.quadrant ?? quadrantByName(_row.quadrant);
    final note = _note;
    // Re-run on display (PRD F10): a note the lexicon now matches stays shut.
    final noteShows = note != null && !noteNeedsSupport(note);
    final canOpen = noteShows || _hasVoice;
    final time = isBackfillRow(_row, widget.timezone)
        ? l.history_addedLater
        : historyTimeLabel(context, _row, widget.timezone);

    final tile = Column(
      key: LookBackEntryTile.tileKey(_row.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            leading: quadrant == null
                ? null
                : ExcludeSemantics(child: QuadrantGlyph(quadrant, size: 24)),
            title: Text(
              mood?.nameFor(widget.localeTag) ?? _row.moodId,
              style: t.titleMedium,
            ),
            subtitle: quadrant == null
                ? null
                : Text(
                    quadrantName(l, quadrant),
                    style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
                  ),
            trailing: Text(
              time,
              style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
            ),
          ),
        ),
        if (canOpen && !_open)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: LookBackEntryTile.openKey(_row.id),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => setState(() => _open = true),
              icon: Icon(
                noteShows ? Icons.lock_open_rounded : Icons.graphic_eq_rounded,
                size: 18,
              ),
              label: Text(
                noteShows
                    ? l.insights_lookBackShowNote
                    : l.insights_lookBackShowVoice,
              ),
            ),
          ),
        if (canOpen && _open) ...[
          if (noteShows)
            Container(
              key: LookBackEntryTile.noteKey(_row.id),
              padding: const EdgeInsets.all(AuraSpace.m),
              decoration: BoxDecoration(
                color: AuraColors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AuraRadius.m),
                border: Border.all(color: AuraColors.hairline),
              ),
              child: Text(note, style: t.bodyLarge),
            ),
          if (_hasVoice) ...[
            const SizedBox(height: AuraSpace.s),
            Container(
              key: LookBackEntryTile.voiceKey(_row.id),
              padding: const EdgeInsets.all(AuraSpace.m),
              decoration: BoxDecoration(
                color: AuraColors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AuraRadius.m),
                border: Border.all(color: AuraColors.hairline),
              ),
              child: VoicePlaybackRow(controller: _voice()),
            ),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: LookBackEntryTile.hideKey(_row.id),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => setState(() => _open = false),
              child: Text(l.insights_lookBackHideNote),
            ),
          ),
        ],
        const SizedBox(height: AuraSpace.s),
      ],
    );
    // Opening eases the height; under Reduce Motion it simply appears.
    if (reduceMotionOf(context)) return tile;
    return AnimatedSize(
      duration: AuraMotion.calm,
      alignment: Alignment.topCenter,
      child: tile,
    );
  }
}
