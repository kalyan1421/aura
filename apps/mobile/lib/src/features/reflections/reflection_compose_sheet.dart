import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/busy_button_label.dart';
import '../../core/widgets/inline_notice.dart';
import '../support/crisis_lexicon.dart';
import '../support/support_sheet.dart';
import 'reflection_copy.dart';
import 'reflection_draft.dart';
import 'reflection_filter.dart';
import 'reflection_models.dart';
import 'reflections_controller.dart';
import 'reflections_providers.dart';
import 'reflections_repository.dart';

/// How long "Sending gently…" stays when the check takes longer (PRD
/// 14-states "moderation > 2 s").
const Duration reflectionSlowNoteFor = Duration(seconds: 2);

/// How the composer closed.
sealed class ComposeResult {
  const ComposeResult();
}

/// It reached a decision the room shows (published, pending or held).
class ComposeSent extends ComposeResult {
  const ComposeSent(this.outcome);
  final SendOutcome outcome;
}

/// The crisis lexicon matched on this phone: the room opens the support
/// sheet at once and still sends [draft] (it reaches the crisis lane).
class ComposeCrisisLocal extends ComposeResult {
  const ComposeCrisisLocal(this.draft);
  final ReflectionDraft draft;
}

/// The server diverted it to crisis support (never published, no rejection
/// wording): the room opens the support sheet.
class ComposeCrisisDiverted extends ComposeResult {
  const ComposeCrisisDiverted();
}

/// The reflection composer (F6, PRD 14-states "Reflection composer") as a
/// modal sheet: ≤ 200 characters (grapheme clusters), "2 of 3 left today",
/// the on-device checks (crisis lexicon, then contact details / links), a
/// draft kept on this phone and "I need help now" under it. `null` when it
/// was closed without sending.
Future<ComposeResult?> showReflectionComposer(
  BuildContext context, {
  required String roomId,
}) => showModalBottomSheet<ComposeResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  builder: (_) => ReflectionComposeSheet(roomId: roomId),
);

class ReflectionComposeSheet extends ConsumerStatefulWidget {
  const ReflectionComposeSheet({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<ReflectionComposeSheet> createState() =>
      _ReflectionComposeSheetState();
}

class _ReflectionComposeSheetState
    extends ConsumerState<ReflectionComposeSheet> {
  final TextEditingController _text = TextEditingController();
  late final ReflectionDraftStore _store;

  /// This draft's id (UUIDv7), generated once and reused on every retry.
  String? _reflectionId;
  bool _loaded = false;

  /// The draft was sent (or diverted): nothing more is saved.
  bool _done = false;
  bool _busy = false;

  /// "Sending gently…" (the check is taking longer).
  bool _slowNote = false;

  /// Contact details or a link: nothing was sent.
  bool _contactBlocked = false;

  /// A calm line about the last Send (rejected, failed, limit…).
  String? _message;
  Timer? _saveSoon;

  @override
  void initState() {
    super.initState();
    _store = ref.read(reflectionDraftStoreProvider);
    _text.addListener(_onChanged);
    unawaited(_restore());
  }

  @override
  void dispose() {
    _saveSoon?.cancel();
    if (!_done && _reflectionId != null) unawaited(_save());
    _text.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final draft = await _store.load(widget.roomId);
    if (!mounted) return;
    _reflectionId = draft?.reflectionId ?? ref.read(idsProvider).v7();
    if (draft != null && _text.text.isEmpty) {
      _text.value = TextEditingValue(
        text: draft.text,
        selection: TextSelection.collapsed(offset: draft.text.length),
      );
    }
    setState(() => _loaded = true);
  }

  void _onChanged() {
    if (_contactBlocked || _message != null) {
      setState(() {
        _contactBlocked = false;
        _message = null;
      });
    } else {
      setState(() {}); // the counter
    }
    _saveSoon?.cancel();
    _saveSoon = Timer(const Duration(milliseconds: 300), () {
      unawaited(_save());
    });
  }

  ReflectionDraft get _draft =>
      ReflectionDraft(reflectionId: _reflectionId!, text: _text.text);

  Future<void> _save() async {
    final id = _reflectionId;
    if (_done || id == null) return;
    try {
      if (_text.text.isEmpty) {
        await _store.clear(widget.roomId);
      } else {
        await _store.save(widget.roomId, _draft);
      }
    } on Object catch (e) {
      debugPrint('reflections: draft not saved (${e.runtimeType})');
    }
  }

  Future<void> _finish(ComposeResult result) async {
    _done = true;
    _saveSoon?.cancel();
    try {
      await _store.clear(widget.roomId);
    } on Object catch (e) {
      debugPrint('reflections: draft not cleared (${e.runtimeType})');
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _send() async {
    if (_busy || _reflectionId == null) return;
    final text = _text.text;
    if (text.trim().isEmpty) return;
    // 1. Crisis lexicon first (it wins over everything, contact details
    // included): help opens at once and the reflection is still sent, so
    // it reaches the crisis lane. The room carries the send.
    if (noteNeedsSupport(text)) {
      _saveSoon?.cancel();
      // Kept (same id) until the server has decided; the room clears it.
      await _save();
      _done = true;
      if (mounted) Navigator.of(context).pop(ComposeCrisisLocal(_draft));
      return;
    }
    // 2. Contact details and links never leave the phone.
    if (checkReflectionText(text).blocksSend) {
      setState(() => _contactBlocked = true);
      return;
    }
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    await _save();
    final controller = ref.read(
      roomReflectionsProvider(widget.roomId).notifier,
    );
    try {
      final outcome = await controller.send(
        reflectionId: _reflectionId!,
        text: text,
      );
      if (!mounted) return;
      switch (outcome.statusValue) {
        case ReflectionStatus.crisisDiverted:
          await _finish(const ComposeCrisisDiverted());
        case ReflectionStatus.rejected:
          // The words stay to edit; the next Send is a new reflection (a
          // replay of this id would only answer this rejection again).
          _reflectionId = ref.read(idsProvider).v7();
          await _save();
          if (!mounted) return;
          setState(() {
            _busy = false;
            _contactBlocked = false;
            _message = rejectReasonText(l, outcome.rejectReasonValue);
          });
        case ReflectionStatus.pending || ReflectionStatus.unknown:
          setState(() => _slowNote = true);
          _done = true;
          await _store.clear(widget.roomId);
          await Future<void>.delayed(reflectionSlowNoteFor);
          if (mounted) Navigator.of(context).pop(ComposeSent(outcome));
        case ReflectionStatus.published ||
            ReflectionStatus.held ||
            ReflectionStatus.removed:
          await _finish(ComposeSent(outcome));
      }
    } on ReflectionsFailure catch (f) {
      if (!mounted) return;
      if (f.kind == ReflectionsFailureKind.idConflict) {
        _reflectionId = ref.read(idsProvider).v7();
        await _save();
        if (!mounted) return;
      }
      setState(() {
        _busy = false;
        _message = switch (f.kind) {
          // Shown by the composer state line instead.
          ReflectionsFailureKind.roomLimit ||
          ReflectionsFailureKind.dailyLimit ||
          ReflectionsFailureKind.paused ||
          ReflectionsFailureKind.readOnly => null,
          ReflectionsFailureKind.offline => l.reflections_draftKept,
          _ => l.reflections_sendFailed,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final s = ref.watch(roomReflectionsProvider(widget.roomId));
    final online = ref.watch(connectivityProvider).value ?? true;
    final allowed = ref.watch(reflectionsComposerAllowedProvider);
    final composer = s.composer;
    final max = composer?.maxChars ?? reflectionMaxChars;
    final count = _text.text.characters.length;
    final over = count > max;
    final stateLine = composerStateText(l, composer, allowed: allowed);
    final open = stateLine == null;
    final canSend =
        _loaded &&
        !_busy &&
        !_slowNote &&
        online &&
        open &&
        !over &&
        _text.text.trim().isNotEmpty;
    final error = Theme.of(context).colorScheme.error;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const ValueKey('reflection-composer'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AuraSpace.gutter,
          0,
          AuraSpace.gutter,
          AuraSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AuraSpace.m),
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.reflections_composeTitle,
                        style: t.titleLarge,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('reflection-composer-close'),
                  tooltip: l.common_close,
                  onPressed: _busy || _slowNote
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.xs),
            Text(
              l.reflections_composeNote,
              style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
            ),
            if (composer != null && composer.isOpen && allowed) ...[
              const SizedBox(height: AuraSpace.s),
              Text(
                l.reflections_left(composer.remainingInRoom, composer.perRoom),
                key: const ValueKey('reflection-left'),
                style: t.labelLarge?.copyWith(color: AuraColors.lavender),
              ),
            ],
            if (composer?.slow ?? false) ...[
              const SizedBox(height: AuraSpace.s),
              Text(
                l.reflections_slow,
                key: const ValueKey('reflection-slow'),
                style: t.bodySmall,
              ),
            ],
            const SizedBox(height: AuraSpace.l),
            TextField(
              key: const ValueKey('reflection-field'),
              controller: _text,
              enabled: _loaded && !_busy && !_slowNote,
              minLines: 3,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.reflections_composeLabel,
                alignLabelWithHint: true,
                errorText: _contactBlocked
                    ? l.reflections_contactBlocked
                    : over
                    ? l.reflections_tooLong(max)
                    : null,
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: AuraSpace.xs),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Semantics(
                label: l.reflections_counterSemantic(count, max),
                excludeSemantics: true,
                child: Text(
                  l.reflections_counter(count, max),
                  key: const ValueKey('reflection-counter'),
                  style: t.labelMedium?.copyWith(
                    color: over ? error : AuraColors.textSoft,
                  ),
                ),
              ),
            ),
            if (stateLine != null) ...[
              const SizedBox(height: AuraSpace.m),
              InlineNotice(stateLine, key: const ValueKey('reflection-state')),
            ] else if (!online) ...[
              const SizedBox(height: AuraSpace.m),
              InlineNotice(
                l.reflections_draftKept,
                key: const ValueKey('reflection-offline'),
                icon: Icons.cloud_off_rounded,
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: AuraSpace.m),
              InlineNotice(
                _message!,
                key: const ValueKey('reflection-message'),
              ),
            ],
            if (_slowNote) ...[
              const SizedBox(height: AuraSpace.m),
              Semantics(
                liveRegion: true,
                child: Text(
                  l.reflections_sending,
                  key: const ValueKey('reflection-sending'),
                  textAlign: TextAlign.center,
                  style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
                ),
              ),
            ],
            const SizedBox(height: AuraSpace.l),
            FilledButton(
              key: const ValueKey('reflection-send'),
              onPressed: canSend ? _send : null,
              child: BusyButtonLabel(
                l.reflections_send,
                busy: _busy || _slowNote,
              ),
            ),
            const SizedBox(height: AuraSpace.s),
            // The help link under the composer (PRD 06b stranger surfaces).
            Center(
              child: TextButton.icon(
                key: const ValueKey('reflection-help'),
                style: TextButton.styleFrom(
                  foregroundColor: AuraColors.lantern,
                ),
                onPressed: () => openSafetyCenter(context),
                icon: const Icon(Icons.favorite_rounded, size: 18),
                label: Text(l.help_button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
