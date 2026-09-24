import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/haptics.dart';
import '../../core/providers.dart' show idsProvider;
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/inline_notice.dart';
import '../rooms/report_sheet.dart';
import '../rooms/room_controller.dart';
import '../rooms/room_copy.dart';
import '../rooms/room_models.dart';
import '../rooms/room_widgets.dart' show announceRoom;
import '../support/support_sheet.dart';
import 'reflection_compose_sheet.dart';
import 'reflection_copy.dart';
import 'reflection_draft.dart';
import 'reflection_models.dart';
import 'reflections_controller.dart';
import 'reflections_providers.dart';
import 'reflections_repository.dart';

/// A calm note at the top of the section (stays until closed).
@immutable
class _Notice {
  const _Notice(this.text, {this.undo});

  final String text;
  final VoidCallback? undo;
}

enum _CardAction { report, block, mute, delete }

/// Reflections inside a room (F6): "Share a reflection" with today's
/// allowance, then the reflections newest first. Cards show the pseudonym
/// and the text as written, the 8 gestures (no replies, no editing), and a
/// ⋯ menu with Report · Block · Mute, or Delete / Withdraw on your own.
/// Your own pending, held, rejected and removed ones show only to you with
/// calm words; your published ones show their gesture count (only authors
/// see counts). A memory is read-only: no composer, no gestures.
///
/// Shows nothing in a build without an API.
class ReflectionsSection extends ConsumerStatefulWidget {
  const ReflectionsSection({
    super.key,
    required this.roomId,
    required this.detail,
  });

  final String roomId;
  final RoomDetail detail;

  @override
  ConsumerState<ReflectionsSection> createState() => _ReflectionsSectionState();
}

class _ReflectionsSectionState extends ConsumerState<ReflectionsSection> {
  _Notice? _notice;

  /// The words of the last gesture you sent here, under its card.
  ({String reflectionId, String text})? _sent;

  RoomReflections get _controller =>
      ref.read(roomReflectionsProvider(widget.roomId).notifier);

  RoomController get _room =>
      ref.read(roomControllerProvider(widget.roomId).notifier);

  void _say(String text, {VoidCallback? undo}) {
    if (!mounted) return;
    setState(() => _notice = _Notice(text, undo: undo));
  }

  // ---- composing ---------------------------------------------------------------

  Future<void> _compose() async {
    final l = AppLocalizations.of(context);
    final result = await showReflectionComposer(context, roomId: widget.roomId);
    if (!mounted || result == null) return;
    switch (result) {
      case ComposeCrisisLocal(:final draft):
        // Help first (< 1 s, REQ-REF-04), and it is still sent so it reaches
        // the crisis lane.
        unawaited(_sendAfterCrisis(draft));
        await _support();
      case ComposeCrisisDiverted():
        await _support();
      case ComposeSent(:final outcome):
        final text = switch (outcome.statusValue) {
          ReflectionStatus.held =>
            outcome.reviewValue == ReviewHint.overnight
                ? l.reflections_heldOvernight
                : l.reflections_heldSoon,
          _ => null,
        };
        if (text != null) _say(text);
    }
  }

  Future<void> _support() =>
      showSupportSheet(context, crisis: true, origin: SupportOrigin.reflection);

  /// The crisis-lexicon send the composer handed over. The draft stays on
  /// the phone (same id) until the server has decided.
  Future<void> _sendAfterCrisis(ReflectionDraft draft) async {
    final store = ref.read(reflectionDraftStoreProvider);
    final ids = ref.read(idsProvider);
    try {
      final outcome = await _controller.send(
        reflectionId: draft.reflectionId,
        text: draft.text,
      );
      if (outcome.statusValue == ReflectionStatus.rejected) {
        // Unlikely (crisis wins on the server too): keep the words, fresh id.
        await store.save(widget.roomId, draft.copyWith(reflectionId: ids.v7()));
      } else {
        await store.clear(widget.roomId);
      }
    } on ReflectionsFailure catch (f) {
      // Kept on the phone for the next try (the same id replays safely).
      debugPrint('reflections: crisis send kept (${f.kind.name})');
    }
  }

  // ---- card actions --------------------------------------------------------------

  RoomMember _memberFor(ReflectionAuthor a) =>
      widget.detail.members
          .where((m) => m.memberId == a.memberId)
          .firstOrNull ??
      RoomMember(memberId: a.memberId, pseudonym: a.pseudonym);

  Future<void> _gesture(Reflection r, GestureType type) async {
    final ok = await _controller.sendGesture(r, type);
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    if (!ok) {
      _say(l.rooms_actionFailed);
      return;
    }
    final text = l.reflections_gestureSent(
      gestureName(l, type),
      r.author.pseudonym,
    );
    announceRoom(context, text);
    AuraHaptics.light();
    setState(() => _sent = (reflectionId: r.reflectionId, text: text));
  }

  Future<void> _openMenu(Reflection r) async {
    final l = AppLocalizations.of(context);
    final member = _memberFor(r.author);
    final withdraw =
        r.statusValue == ReflectionStatus.pending ||
        r.statusValue == ReflectionStatus.held;
    final choice = await showModalBottomSheet<_CardAction>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          key: const ValueKey('reflection-menu'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!r.isMine) ...[
              ListTile(
                key: const ValueKey('reflection-menu-report'),
                leading: const Icon(Icons.flag_outlined),
                title: Text(l.rooms_report),
                onTap: () => Navigator.of(context).pop(_CardAction.report),
              ),
              ListTile(
                key: const ValueKey('reflection-menu-block'),
                leading: const Icon(Icons.block_rounded),
                title: Text(l.rooms_block),
                onTap: () => Navigator.of(context).pop(_CardAction.block),
              ),
              ListTile(
                key: const ValueKey('reflection-menu-mute'),
                leading: const Icon(Icons.volume_off_outlined),
                title: Text(l.rooms_mute),
                onTap: () => Navigator.of(context).pop(_CardAction.mute),
              ),
            ] else
              ListTile(
                key: const ValueKey('reflection-menu-delete'),
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(
                  withdraw ? l.reflections_withdraw : l.reflections_delete,
                ),
                onTap: () => Navigator.of(context).pop(_CardAction.delete),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _CardAction.report:
        await _report(r);
      case _CardAction.block:
        await _block(member);
      case _CardAction.mute:
        await _mute(member);
      case _CardAction.delete:
        await _delete(r, withdraw: withdraw);
    }
  }

  Future<void> _report(Reflection r) async {
    final target = ReflectionReportTarget(widget.roomId, r.reflectionId);
    final outcome = await showReportSheet(
      context,
      target: target,
      pseudonym: r.author.pseudonym,
    );
    if (!mounted || outcome == null) return;
    _controller.reported(r.reflectionId);
    final l = AppLocalizations.of(context);
    _say(
      outcome.showHelplines ? l.rooms_reportCrisis : l.reflections_reportHidden,
    );
    // Crisis lane: the reporter sees helplines at once (F9).
    if (outcome.showHelplines) openSafetyCenter(context);
  }

  Future<void> _block(RoomMember member) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('reflection-block-confirm'),
        title: Semantics(
          header: true,
          child: Text(l.rooms_blockTitle(member.pseudonym)),
        ),
        content: SingleChildScrollView(child: Text(l.rooms_blockBody)),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.common_cancel),
          ),
          FilledButton.icon(
            key: const ValueKey('reflection-block-confirm-button'),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.block_rounded, size: 18),
            label: Text(l.rooms_block),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await _room.block(member);
    if (!mounted) return;
    if (done) _controller.hideAuthor(member.memberId);
    _say(done ? l.rooms_blocked(member.pseudonym) : l.rooms_actionFailed);
  }

  Future<void> _mute(RoomMember member, {bool muted = true}) async {
    final l = AppLocalizations.of(context);
    final done = await _room.setMuted(member, muted: muted);
    if (!mounted) return;
    if (!done) {
      _say(l.rooms_actionFailed);
      return;
    }
    if (muted) {
      _controller.hideAuthor(member.memberId);
      _say(
        l.rooms_muted(member.pseudonym),
        undo: () => unawaited(_mute(member, muted: false)),
      );
    } else {
      _controller.showAuthor(member.memberId);
      _say(l.rooms_unmuted(member.pseudonym));
    }
  }

  Future<void> _delete(Reflection r, {required bool withdraw}) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('reflection-delete-confirm'),
        title: Semantics(
          header: true,
          child: Text(
            withdraw ? l.reflections_withdrawTitle : l.reflections_deleteTitle,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            withdraw ? l.reflections_withdrawBody : l.reflections_deleteBody,
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.common_cancel),
          ),
          FilledButton(
            key: const ValueKey('reflection-delete-confirm-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              withdraw ? l.reflections_withdraw : l.reflections_delete,
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await _controller.delete(r);
    if (!mounted) return;
    _say(done ? l.reflections_deleted : l.rooms_actionFailed);
  }

  // ---- build ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final provider = roomReflectionsProvider(widget.roomId);
    final s = ref.watch(provider);
    ref.listen(provider.select((s) => s.supportSerial), (prev, next) {
      if (next > (prev ?? 0)) unawaited(_support());
    });
    final failure = s.failure;
    if (failure?.kind == ReflectionsFailureKind.unavailable) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final memory = widget.detail.room.isMemory;
    final room = ref.watch(roomControllerProvider(widget.roomId));
    final allowed = ref.watch(reflectionsComposerAllowedProvider);
    final composer = s.composer;
    final stateLine = memory
        ? l.reflections_memory
        : composerStateText(l, composer, allowed: allowed);
    final notice = _notice;
    final canGesture = !memory && !room.left && !s.coolingDown;

    return Column(
      key: const ValueKey('reflections-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.reflections_title, style: t.titleMedium),
        ),
        const SizedBox(height: AuraSpace.xs),
        Text(
          l.reflections_intro,
          style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
        ),
        const SizedBox(height: AuraSpace.m),
        if (notice != null) ...[
          InlineNotice(
            notice.text,
            key: const ValueKey('reflections-notice'),
            action: Wrap(
              spacing: AuraSpace.s,
              children: [
                if (notice.undo != null)
                  TextButton(
                    key: const ValueKey('reflections-notice-undo'),
                    onPressed: () {
                      setState(() => _notice = null);
                      notice.undo!();
                    },
                    child: Text(l.rooms_undo),
                  ),
                TextButton(
                  key: const ValueKey('reflections-notice-close'),
                  onPressed: () => setState(() => _notice = null),
                  child: Text(l.common_close),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.m),
        ],
        // The composer is hidden in a memory (read-only list).
        if (!memory) ...[
          if (stateLine == null)
            OutlinedButton.icon(
              key: const ValueKey('reflections-share'),
              onPressed: room.left ? null : () => unawaited(_compose()),
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(l.reflections_share),
            ),
          if (stateLine == null && composer != null) ...[
            const SizedBox(height: AuraSpace.xs),
            Text(
              l.reflections_left(composer.remainingInRoom, composer.perRoom),
              key: const ValueKey('reflections-left'),
              textAlign: TextAlign.center,
              style: t.bodySmall,
            ),
          ],
          if (composer?.slow ?? false) ...[
            const SizedBox(height: AuraSpace.xs),
            Text(
              l.reflections_slow,
              key: const ValueKey('reflections-slow'),
              textAlign: TextAlign.center,
              style: t.bodySmall,
            ),
          ],
        ],
        if (stateLine != null)
          Text(
            stateLine,
            key: const ValueKey('reflections-state'),
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
        const SizedBox(height: AuraSpace.m),
        if (s.load == ReflectionsLoad.loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AuraSpace.m),
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AuraColors.lavender,
                ),
              ),
            ),
          )
        else if (failure != null && s.isEmpty)
          InlineNotice(
            failure.kind == ReflectionsFailureKind.offline
                ? l.reflections_offline
                : l.reflections_loadFailed,
            key: const ValueKey('reflections-failed'),
            action: TextButton(
              key: const ValueKey('reflections-retry'),
              onPressed: () => unawaited(_controller.refresh()),
              child: Text(l.rooms_tryAgain),
            ),
          )
        else if (s.isEmpty)
          Text(
            memory ? l.reflections_emptyMemory : l.reflections_empty,
            key: const ValueKey('reflections-empty'),
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          )
        else
          for (final r in s.reflections)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.m),
              child: ReflectionCard(
                reflection: r,
                canGesture: canGesture,
                sentLine: _sent?.reflectionId == r.reflectionId
                    ? _sent!.text
                    : null,
                onGesture: (g) => unawaited(_gesture(r, g)),
                onMenu: () => unawaited(_openMenu(r)),
              ),
            ),
      ],
    );
  }
}

/// One reflection: the pseudonym (or "Your reflection"), the text as
/// written, and either the gestures (someone else's published one) or what
/// only the author sees. No reply and no edit affordance anywhere.
class ReflectionCard extends StatelessWidget {
  const ReflectionCard({
    super.key,
    required this.reflection,
    required this.canGesture,
    required this.onGesture,
    required this.onMenu,
    this.sentLine,
  });

  final Reflection reflection;
  final bool canGesture;
  final ValueChanged<GestureType> onGesture;
  final VoidCallback onMenu;

  /// The gesture you just sent on it ("Hug sent to Quiet Comet").
  final String? sentLine;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final r = reflection;
    final own = ownStatusText(l, r);
    final id = r.reflectionId;
    return Container(
      key: ValueKey('reflection-$id'),
      padding: const EdgeInsets.all(AuraSpace.l),
      decoration: BoxDecoration(
        color: r.isMine
            ? AuraColors.surfaceHigh.withValues(alpha: 0.9)
            : AuraColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AuraRadius.m),
        border: Border.all(color: AuraColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label: r.isMine
                            ? l.reflections_mine
                            : l.reflections_cardLabel(r.author.pseudonym),
                        excludeSemantics: true,
                        child: Text(
                          r.isMine ? l.reflections_mine : r.author.pseudonym,
                          style: t.labelLarge?.copyWith(
                            color: AuraColors.lavender,
                          ),
                        ),
                      ),
                      Text(
                        roomTime(context, r.publishedAt ?? r.createdAt),
                        style: t.bodySmall,
                      ),
                      const SizedBox(height: AuraSpace.s),
                      // As written: never translated.
                      Text(
                        r.text,
                        key: ValueKey('reflection-text-$id'),
                        style: t.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('reflection-menu-button-$id'),
                tooltip: l.reflections_options,
                onPressed: onMenu,
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          if (own != null) ...[
            const SizedBox(height: AuraSpace.s),
            Text(
              own,
              key: ValueKey('reflection-status-$id'),
              style: t.bodyMedium?.copyWith(color: AuraColors.starlight),
            ),
            if (r.statusValue == ReflectionStatus.rejected ||
                r.statusValue == ReflectionStatus.removed)
              Text(
                rejectReasonText(l, r.rejectReasonValue),
                style: t.bodySmall,
              ),
            Text(l.reflections_onlyYou, style: t.bodySmall),
          ] else if (r.isMine) ...[
            const SizedBox(height: AuraSpace.s),
            Text(
              l.reflections_gestureCount(r.gestureCount ?? 0),
              key: ValueKey('reflection-count-$id'),
              style: t.bodyMedium?.copyWith(color: AuraColors.starlight),
            ),
            Text(l.reflections_countPrivate, style: t.bodySmall),
          ] else ...[
            const SizedBox(height: AuraSpace.m),
            SingleChildScrollView(
              key: ValueKey('reflection-gestures-$id'),
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final g in GestureType.values) ...[
                    _GestureChip(
                      key: ValueKey('reflection-gesture-$id-${g.wire}'),
                      type: g,
                      hint: l.reflections_gestureHint(r.author.pseudonym),
                      onPressed: canGesture ? () => onGesture(g) : null,
                    ),
                    if (g != GestureType.values.last)
                      const SizedBox(width: AuraSpace.xs),
                  ],
                ],
              ),
            ),
            if (sentLine != null) ...[
              const SizedBox(height: AuraSpace.xs),
              Text(
                sentLine!,
                style: t.labelMedium?.copyWith(color: AuraColors.starlight),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// A gesture under a reflection: a compact chip (≥ 48 dp), icon and name.
class _GestureChip extends StatelessWidget {
  const _GestureChip({
    super.key,
    required this.type,
    required this.hint,
    required this.onPressed,
  });

  final GestureType type;
  final String hint;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final enabled = onPressed != null;
    final name = gestureName(l, type);
    return Semantics(
      button: true,
      enabled: enabled,
      label: name,
      hint: hint,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: AuraColors.skyHigh.withValues(alpha: enabled ? 0.9 : 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          side: const BorderSide(color: AuraColors.outline),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AuraSpace.m),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    gestureIcon(type),
                    size: 18,
                    color: enabled
                        ? AuraColors.starlight
                        : AuraColors.textMuted,
                  ),
                  const SizedBox(width: AuraSpace.xs),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: enabled ? AuraColors.text : AuraColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
