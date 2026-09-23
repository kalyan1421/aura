import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../checkin/quadrant_glyph.dart';
import '../support/support_sheet.dart';
import 'history_format.dart';
import 'history_providers.dart';

/// Private check-in history (`/history`): newest first, grouped by Aura day.
/// Rows show the mood, time and discreet markers (tags, note, voice) only —
/// never note text.
/// Read from Drift, so it works offline (PRD F10 "history is never gated").
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final entries = ref.watch(historyEntriesProvider);
    final rows = entries.value;

    return Scaffold(
      appBar: AppBar(
        leading: const HistoryBackButton(fallback: Routes.home),
        title: Semantics(
          header: true,
          container: true,
          child: Text(l.history_title),
        ),
        backgroundColor: AuraColors.sky,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AuraSpace.s),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: const HelpNowButton(compact: true),
            ),
          ),
        ],
      ),
      body: CosmicBackground(
        child: rows == null
            ? const SizedBox.shrink() // local read: a blink at most
            : rows.isEmpty
            ? const _Empty()
            : _List(rows: rows),
      ),
    );
  }
}

/// Back that also works when the page was opened directly (deep link).
class HistoryBackButton extends StatelessWidget {
  const HistoryBackButton({super.key, required this.fallback});

  final String fallback;

  @override
  Widget build(BuildContext context) => BackButton(
    onPressed: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(fallback);
      }
    },
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AuraSpace.gutter),
      children: [
        const SizedBox(height: AuraSpace.xxl),
        const ExcludeSemantics(
          child: Icon(
            Icons.nights_stay_outlined,
            size: 40,
            color: AuraColors.starlight,
          ),
        ),
        const SizedBox(height: AuraSpace.l),
        Text(
          l.history_empty,
          textAlign: TextAlign.center,
          style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
        ),
        const SizedBox(height: AuraSpace.xl),
        Center(
          child: FilledButton(
            key: const ValueKey('history-checkin'),
            onPressed: () => context.push(Routes.checkIn),
            child: Text(l.home_checkIn),
          ),
        ),
      ],
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.rows});

  final List<CheckInRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final localeTag = ref.watch(localeControllerProvider);
    final time = ref.watch(timeContextProvider);
    final now = ref.watch(nowProvider).value ?? time.now();
    final today = time.dayOf(now);

    // Flatten into headers + rows (rows arrive sorted by day, then time).
    final items = <Object>[];
    String? day;
    for (final r in rows) {
      if (r.localDay != day) {
        day = r.localDay;
        items.add(LocalDay.parse(r.localDay));
      }
      items.add(r);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.s,
        AuraSpace.gutter,
        AuraSpace.xxl,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s),
            child: Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AuraColors.textMuted,
                  ),
                ),
                const SizedBox(width: AuraSpace.xs),
                Flexible(
                  child: Text(
                    l.history_private,
                    style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
                  ),
                ),
              ],
            ),
          );
        }
        final item = items[i - 1];
        if (item is LocalDay) {
          return Padding(
            padding: const EdgeInsets.only(
              top: AuraSpace.l,
              bottom: AuraSpace.s,
            ),
            child: Semantics(
              header: true,
              container: true,
              child: Text(
                historyDayLabel(l, localeTag, item, today),
                style: t.titleSmall?.copyWith(color: AuraColors.textSoft),
              ),
            ),
          );
        }
        final row = item as CheckInRow;
        return _Row(
          row: row,
          localeTag: localeTag,
          time: historyTimeLabel(context, row, time.timezone),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.localeTag, required this.time});

  final CheckInRow row;
  final String localeTag;
  final String time;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final mood = moodById(row.moodId);
    final quadrant = mood?.quadrant ?? quadrantByName(row.quadrant);
    final hasNote = row.note?.trim().isNotEmpty ?? false;
    final hasVoice = row.voiceFile != null || row.voicePath != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s),
      child: Material(
        color: AuraColors.surface.withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.m),
          side: const BorderSide(color: AuraColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: MergeSemantics(
          child: InkWell(
            key: ValueKey('history-${row.id}'),
            onTap: () => context.push(Routes.historyEntry(row.id)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.l,
                  vertical: AuraSpace.m,
                ),
                child: Row(
                  children: [
                    if (quadrant != null)
                      ExcludeSemantics(
                        child: QuadrantGlyph(quadrant, size: 24),
                      ),
                    const SizedBox(width: AuraSpace.m),
                    Expanded(
                      child: Text(
                        mood?.nameFor(localeTag) ?? row.moodId,
                        style: t.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s),
                    if (row.tags.isNotEmpty) ...[
                      Semantics(
                        label: l.history_tagCount(row.tags.length),
                        excludeSemantics: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.sell_outlined,
                              size: 16,
                              color: AuraColors.textMuted,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${row.tags.length}',
                              style: t.labelMedium?.copyWith(
                                color: AuraColors.textSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s),
                    ],
                    if (hasNote) ...[
                      Semantics(
                        label: l.history_hasNote,
                        excludeSemantics: true,
                        child: const Icon(
                          Icons.notes_rounded,
                          key: ValueKey('history-note-icon'),
                          size: 18,
                          color: AuraColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s),
                    ],
                    if (hasVoice) ...[
                      Semantics(
                        label: l.voice_hasVoice,
                        excludeSemantics: true,
                        child: const Icon(
                          Icons.mic_none_rounded,
                          key: ValueKey('history-voice-icon'),
                          size: 18,
                          color: AuraColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s),
                    ],
                    Text(
                      time,
                      style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
