import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aura_tokens.dart';
import '../checkin/quadrant_glyph.dart';
import '../history/history_format.dart';

/// A day's check-ins, from a tap on its star (PRD F10 "tap a day for its
/// entries"). Mood, glyph and time only: a note never shows here; each row
/// opens the check-in's own page (where the 24 h edit and delete live).
Future<void> showDaySheet(
  BuildContext context, {
  required LocalDay day,
  required LocalDay today,
  required List<CheckInRow> rows,
  required String localeTag,
  required String timezone,
}) {
  // The sheet's own context is gone once it closes; open the entry with the
  // router from underneath.
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (sheet) {
      final l = AppLocalizations.of(sheet);
      final t = Theme.of(sheet).textTheme;
      // Oldest first within the day, as the day unfolded.
      final ordered = [...rows]
        ..sort((a, b) => a.deviceTs.compareTo(b.deviceTs));
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scroll) => ListView(
          key: const ValueKey('insights-day-sheet'),
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
                historyDayLabel(l, localeTag, day, today),
                style: t.titleLarge,
              ),
            ),
            const SizedBox(height: AuraSpace.m),
            if (ordered.isEmpty)
              Text(
                l.insights_dayNone,
                style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
              ),
            for (final row in ordered)
              _EntryRow(
                row: row,
                localeTag: localeTag,
                time: isBackfillRow(row, timezone)
                    ? l.history_addedLater
                    : historyTimeLabel(context, row, timezone),
                onTap: () {
                  Navigator.of(sheet).pop();
                  router.push(Routes.historyEntry(row.id));
                },
              ),
          ],
        ),
      );
    },
  );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.row,
    required this.localeTag,
    required this.time,
    required this.onTap,
  });

  final CheckInRow row;
  final String localeTag;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final mood = moodById(row.moodId);
    final quadrant = mood?.quadrant ?? quadrantByName(row.quadrant);
    return MergeSemantics(
      child: ListTile(
        key: ValueKey('insights-day-entry-${row.id}'),
        contentPadding: EdgeInsets.zero,
        minTileHeight: 56,
        leading: quadrant == null
            ? null
            : ExcludeSemantics(child: QuadrantGlyph(quadrant, size: 24)),
        title: Text(
          mood?.nameFor(localeTag) ?? row.moodId,
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
        onTap: onTap,
      ),
    );
  }
}
