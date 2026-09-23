import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/haptics.dart';
import '../../core/db/database.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/inline_notice.dart';
import '../checkin/checkin_details.dart';
import '../checkin/checkin_providers.dart';
import '../checkin/checkin_repository.dart';
import '../checkin/checkin_screen.dart' show checkInSaveColor;
import '../checkin/mood_grid.dart';
import '../checkin/quadrant_glyph.dart';
import '../support/crisis_lexicon.dart';
import '../support/support_sheet.dart';
import 'history_format.dart';
import 'history_providers.dart';

/// One check-in (`/history/:id`): mood, time, tags, the private note and
/// its sync status. Edit within 24 h of making it (same id, never re-earns);
/// delete any time — a tombstone that keeps Starlight and glow days (F1).
class CheckInDetailScreen extends ConsumerStatefulWidget {
  const CheckInDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<CheckInDetailScreen> createState() =>
      _CheckInDetailScreenState();
}

class _CheckInDetailScreenState extends ConsumerState<CheckInDetailScreen> {
  /// Non-null while editing.
  CheckInDraft? _draft;
  bool _saving = false;
  bool _failed = false;

  /// The person chose to leave (Discard / after delete).
  bool _leaving = false;

  bool get _hasInput => !_leaving && (_draft?.isDirty ?? false);

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  void _onDraft() => setState(() {});

  Future<void> _startEdit(CheckInRow row) async {
    // Read the note directly: editing must start from the stored words.
    final note = await ref.read(checkInRepositoryProvider).noteOf(row.id);
    if (!mounted) return;
    final draft = CheckInDraft(
      mood: moodById(row.moodId),
      tags: row.tags,
      note: note,
    )..addListener(_onDraft);
    setState(() {
      _draft = draft;
      _failed = false;
    });
  }

  void _endEdit() {
    final draft = _draft;
    setState(() {
      _draft = null;
      _failed = false;
    });
    // Its fields are still mounted this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => draft?.dispose());
  }

  Future<void> _cancelEdit() async {
    if (_hasInput && !await confirmDiscard(context)) return;
    if (mounted) _endEdit();
  }

  Future<void> _saveEdit() async {
    final draft = _draft;
    final mood = draft?.mood;
    if (draft == null || mood == null || _saving) return;
    final note = draft.note.text;
    final noteEdited = draft.noteChanged;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref
          .read(checkInRepositoryProvider)
          .edit(
            id: widget.id,
            mood: mood,
            tags: draft.tags.toList(),
            note: note,
          );
      ref.read(syncControllerProvider).notifyLocalWrite();
    } catch (_) {
      // The edit stays on screen; Save can be tried again.
      if (mounted) setState(() => _failed = true);
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    AuraHaptics.light();
    if (!mounted) return;
    _endEdit();
    // Saved first, then support if the edited words call for it (F1/F9).
    if (noteEdited && noteNeedsSupport(note)) {
      await showSupportSheet(context, crisis: true);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.history_deleteTitle),
        content: Text(l.history_deleteBody),
        actions: [
          TextButton(
            key: const ValueKey('delete-cancel'),
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.common_cancel),
          ),
          TextButton(
            key: const ValueKey('delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.history_delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(checkInRepositoryProvider).delete(widget.id);
      ref.read(syncControllerProvider).notifyLocalWrite();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    AuraHaptics.light();
    if (!mounted) return;
    setState(() => _leaving = true);
    _leave();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.history);
    }
  }

  Future<void> _back() async {
    if (_hasInput && !await confirmDiscard(context)) return;
    if (!mounted) return;
    setState(() => _leaving = true);
    _leave();
  }

  Future<void> _onBlockedPop() async {
    if (!await confirmDiscard(context) || !mounted) return;
    setState(() => _leaving = true);
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final entry = ref.watch(checkInEntryProvider(widget.id));
    final row = entry.value;

    final Widget body;
    if (row == null && entry.isLoading) {
      body = const SizedBox.shrink(); // local read: a blink at most
    } else if (row == null || row.deletedAt != null) {
      body = _Missing(message: l.history_missing);
    } else {
      body = _draft == null ? _view(context, row) : _edit(context, _draft!);
    }

    return PopScope(
      canPop: !_hasInput,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBlockedPop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _back),
          title: Semantics(
            header: true,
            container: true,
            child: Text(l.history_entryTitle),
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
        body: CosmicBackground(child: body),
      ),
    );
  }

  Widget _view(BuildContext context, CheckInRow row) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final localeTag = ref.watch(localeControllerProvider);
    final time = ref.watch(timeContextProvider);
    final now = ref.watch(nowProvider).value ?? time.now();
    final note = ref.watch(checkInNoteProvider(widget.id)).value;
    final pending = ref.watch(checkInPendingProvider(widget.id)).value ?? true;
    final synced = row.synced && !pending;
    final mood = moodById(row.moodId);
    final quadrant = mood?.quadrant ?? quadrantByName(row.quadrant);
    final hasNote = note != null && note.trim().isNotEmpty;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: AuraSpace.xl, bottom: AuraSpace.s),
      child: Semantics(
        header: true,
        container: true,
        child: Text(title, style: t.titleSmall),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.l,
        AuraSpace.gutter,
        AuraSpace.xxl,
      ),
      children: [
        Row(
          children: [
            if (quadrant != null) ...[
              ExcludeSemantics(child: QuadrantGlyph(quadrant, size: 32)),
              const SizedBox(width: AuraSpace.m),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    container: true,
                    child: Text(
                      mood?.nameFor(localeTag) ?? row.moodId,
                      style: t.headlineSmall,
                    ),
                  ),
                  if (quadrant != null)
                    Text(
                      quadrantName(l, quadrant),
                      style: t.labelLarge?.copyWith(
                        color: AuraColors.quadrant(quadrant),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s),
        Text(
          l.history_when(
            historyDayLabel(
              l,
              localeTag,
              LocalDay.parse(row.localDay),
              time.dayOf(now),
            ),
            historyTimeLabel(context, row, time.timezone),
          ),
          style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
        ),
        if (row.tags.isNotEmpty) ...[
          section(l.history_tags),
          Wrap(
            spacing: AuraSpace.s,
            runSpacing: AuraSpace.s,
            children: [
              for (final tag in row.tags) Chip(label: Text(tagLabel(l, tag))),
            ],
          ),
        ],
        if (hasNote) ...[
          section(l.history_note),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AuraSpace.l),
            decoration: BoxDecoration(
              color: AuraColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AuraRadius.m),
              border: Border.all(color: AuraColors.hairline),
            ),
            child: Text(
              note,
              key: const ValueKey('history-note'),
              style: t.bodyLarge,
            ),
          ),
          const SizedBox(height: AuraSpace.s),
          _Line(icon: Icons.lock_outline_rounded, text: l.checkin_noteHint),
        ],
        const SizedBox(height: AuraSpace.xl),
        Semantics(
          liveRegion: true,
          container: true,
          child: _Line(
            key: const ValueKey('history-sync'),
            icon: synced
                ? Icons.cloud_done_outlined
                : Icons.phone_iphone_rounded,
            text: synced ? l.history_synced : l.checkin_savedOffline,
          ),
        ),
        const SizedBox(height: AuraSpace.xl),
        if (canEditCheckIn(row, now))
          FilledButton.icon(
            key: const ValueKey('history-edit'),
            onPressed: () => _startEdit(row),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l.history_edit),
          )
        else
          _Line(
            key: const ValueKey('history-edit-closed'),
            icon: Icons.info_outline_rounded,
            text: row.noteLocked
                ? l.history_editNoteLocked
                : l.history_editWindowOver,
          ),
        const SizedBox(height: AuraSpace.m),
        OutlinedButton.icon(
          key: const ValueKey('history-delete'),
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline_rounded),
          label: Text(l.history_delete),
        ),
        if (_failed) ...[
          const SizedBox(height: AuraSpace.m),
          InlineNotice(l.checkin_saveFailed),
        ],
      ],
    );
  }

  Widget _edit(BuildContext context, CheckInDraft draft) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final localeTag = ref.watch(localeControllerProvider);
    final recentTags = ref.watch(recentCustomTagsProvider).value ?? const [];
    final mood = draft.mood;
    // Save / Cancel stay pinned below the list, like the check-in's Save.
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.gutter,
              AuraSpace.l,
              AuraSpace.gutter,
              AuraSpace.xl,
            ),
            children: [
              Semantics(
                header: true,
                container: true,
                child: Text(l.checkin_title, style: t.headlineSmall),
              ),
              const SizedBox(height: AuraSpace.l),
              MoodGrid(
                selected: mood,
                localeTag: localeTag,
                onSelected: (m) => draft.mood = m,
              ),
              const SizedBox(height: AuraSpace.l),
              CheckInDetailsEditor(draft: draft, recentTags: recentTags),
              if (_failed) ...[
                const SizedBox(height: AuraSpace.m),
                InlineNotice(l.checkin_saveFailed),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.gutter,
            AuraSpace.s,
            AuraSpace.gutter,
            AuraSpace.l,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('history-edit-cancel'),
                  onPressed: _cancelEdit,
                  child: Text(l.common_cancel),
                ),
              ),
              const SizedBox(width: AuraSpace.m),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('history-edit-save'),
                  onPressed: mood != null && draft.isDirty && !_saving
                      ? _saveEdit
                      : null,
                  style: mood == null
                      ? null
                      : FilledButton.styleFrom(
                          backgroundColor: checkInSaveColor(mood.quadrant),
                        ),
                  child: Text(l.checkin_save),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Icon + calm text line (privacy note, sync status, edit window).
class _Line extends StatelessWidget {
  const _Line({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: ExcludeSemantics(
          child: Icon(icon, size: 16, color: AuraColors.textSoft),
        ),
      ),
      const SizedBox(width: AuraSpace.s),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AuraColors.textSoft),
        ),
      ),
    ],
  );
}

class _Missing extends StatelessWidget {
  const _Missing({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AuraSpace.gutter),
    children: [
      const SizedBox(height: AuraSpace.xxl),
      Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: AuraColors.textSoft),
      ),
    ],
  );
}
