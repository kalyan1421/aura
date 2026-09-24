import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/haptics.dart';
import '../../core/entitlements/plus.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/busy_button_label.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../../core/widgets/inline_notice.dart';
import '../checkin/quadrant_glyph.dart' show habitLabel, quadrantName;
import '../companion/prompts.dart';
import '../plus/paywall_gate.dart' show PaywallSurface;
import '../plus/plus_entry.dart' show PlusOpenButton;
import '../push/push_messaging.dart' show PushPermission;
import '../sanctuary/habit_auto_complete.dart';
import '../support/crisis_lexicon.dart';
import '../support/support_sheet.dart';
import '../voice/voice_note_field.dart';
import 'capsule_draft.dart';
import 'capsule_format.dart';
import 'capsule_payload.dart';
import 'capsule_photo_picker.dart';
import 'capsule_providers.dart';
import 'capsule_repository.dart';
import 'photo_processing.dart';

/// Opens the composer (Navigator route; a kept draft is restored).
Future<void> openCapsuleComposer(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const CapsuleComposerScreen()),
    );

enum _Problem { needContent, needUnlock, dateRange, failed }

enum _Leave { keep, discard }

/// "Write to future you" (PRD F4): a title (≤ 60, visible while sealed),
/// words (≤ 2,000, with an optional guided prompt as the hint), a voice
/// note (≤ 2:00), up to 3 photos (resized, EXIF/GPS stripped on the phone)
/// and when it opens — a date (1 week – 5 years; the picker offers nothing
/// else) or a feeling (one mood or a quadrant; it arms after 24 h).
///
/// Works fully offline. The draft is kept on this phone until it is sealed
/// or discarded (never lose input); leaving asks first. Sealing runs the
/// crisis lexicon: a hit still seals (flagged as a hard moment, inside the
/// ciphertext) and then shows the support sheet. Sealing logs today's
/// Journal habit (F2).
class CapsuleComposerScreen extends ConsumerStatefulWidget {
  const CapsuleComposerScreen({super.key});

  @override
  ConsumerState<CapsuleComposerScreen> createState() =>
      _CapsuleComposerScreenState();
}

class _CapsuleComposerScreenState extends ConsumerState<CapsuleComposerScreen> {
  CapsuleDraft? _draft;
  bool _busy = false;
  bool _addingPhoto = false;
  bool _photoFailed = false;
  _Problem? _problem;
  bool _leaving = false;

  /// Set once sealed: the sealed confirmation replaces the form.
  CapsuleUnlock? _sealedWith;
  bool _journalLogged = false;
  bool _mediaLater = false;

  Timer? _saveSoon;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDraft());
  }

  Future<void> _loadDraft() async {
    final kept = await ref.read(capsuleDraftStoreProvider).load();
    if (!mounted) {
      kept?.dispose();
      return;
    }
    final draft =
        kept ?? CapsuleDraft(id: ref.read(capsuleRepositoryProvider).newId);
    draft.addListener(_onDraft);
    setState(() => _draft = draft);
  }

  void _onDraft() {
    if (!mounted) return;
    setState(() {
      if (_problem == _Problem.needContent && _draft!.hasContent) {
        _problem = null;
      }
      if (_problem == _Problem.needUnlock && _draft!.unlock != null) {
        _problem = null;
      }
    });
    _saveSoon?.cancel();
    _saveSoon = Timer(const Duration(milliseconds: 400), _saveDraft);
  }

  /// Keeps (or forgets) the draft on this phone.
  Future<void> _saveDraft() async {
    final draft = _draft;
    if (draft == null || _sealedWith != null) return;
    final store = ref.read(capsuleDraftStoreProvider);
    if (draft.hasContent || draft.unlock != null) {
      await store.save(draft);
    } else {
      await store.clear();
    }
  }

  @override
  void dispose() {
    _saveSoon?.cancel();
    final draft = _draft;
    if (draft != null) {
      draft.removeListener(_onDraft);
      // Deferred: the voice field may still be detaching from it.
      WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
    }
    super.dispose();
  }

  // ---- photos --------------------------------------------------------------------

  Future<void> _addPhotos() async {
    final draft = _draft;
    if (draft == null || draft.atPhotoLimit || _addingPhoto) return;
    AuraHaptics.selection();
    final picker = ref.read(capsulePhotoPickerProvider);
    final store = ref.read(capsuleMediaStoreProvider);
    final List<Uint8List> picked;
    try {
      picked = await picker.pick(limit: maxCapsulePhotos - draft.photos.length);
    } on Object catch (e) {
      debugPrint('capsules: picker ${e.runtimeType}');
      if (mounted) setState(() => _photoFailed = true);
      return;
    }
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _addingPhoto = true;
      _photoFailed = false;
    });
    var failed = false;
    for (final bytes in picked) {
      if (draft.atPhotoLimit) break;
      try {
        final photo = await processCapsulePhotoInBackground(bytes);
        final path = await store.writeDraftPhoto(draft.id, photo.jpeg);
        draft.addPhoto(
          CapsulePhotoDraft(
            path: path,
            width: photo.width,
            height: photo.height,
          ),
        );
      } on Object catch (e) {
        debugPrint('capsules: photo not added (${e.runtimeType})');
        failed = true;
      }
    }
    if (mounted) {
      setState(() {
        _addingPhoto = false;
        _photoFailed = failed;
      });
    }
  }

  // ---- unlock ----------------------------------------------------------------------

  Future<void> _pickDate() async {
    final draft = _draft;
    if (draft == null) return;
    final l = AppLocalizations.of(context);
    final time = ref.read(timeContextProvider);
    final w = unlockWindowFor(time.now(), time.timezone);
    DateTime at(LocalDay d) => DateTime(d.year, d.month, d.day);
    final current = draft.date;
    var initial = current != null && w.contains(current)
        ? current
        : w.first.addDays(23); // about a month from today
    if (initial.isAfter(w.last)) initial = w.last;
    final picked = await showDatePicker(
      context: context,
      // Only 1 week – 5 years can be picked (REQ-CAP-01).
      firstDate: at(w.first),
      lastDate: at(w.last),
      initialDate: at(initial),
      helpText: l.capsules_datePickerHelp,
    );
    if (picked == null || !mounted) return;
    draft.date = LocalDay(picked.year, picked.month, picked.day);
    if (_problem == _Problem.dateRange) setState(() => _problem = null);
  }

  // ---- seal ------------------------------------------------------------------------

  Future<void> _seal() async {
    final draft = _draft;
    if (draft == null || _busy) return;
    // A recording in progress is finished and sealed with it.
    await draft.finishVoice();
    if (!draft.hasContent) {
      setState(() => _problem = _Problem.needContent);
      return;
    }
    final unlock = draft.unlock;
    if (unlock == null) {
      setState(() => _problem = _Problem.needUnlock);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    // Read before any await: this screen may be gone by the end.
    final repo = ref.read(capsuleRepositoryProvider);
    final sync = ref.read(syncControllerProvider);
    final drafts = ref.read(capsuleDraftStoreProvider);
    final store = ref.read(capsuleMediaStoreProvider);
    final online = sync.online.value;
    final content = draft.content;
    // The on-device crisis lexicon (F9 L1) over the words; they never leave
    // the phone for this.
    final hard =
        noteNeedsSupport(content.text) || noteNeedsSupport(content.title);
    try {
      await repo.seal(
        id: draft.id,
        content: content,
        unlock: unlock,
        hardMoment: hard,
        plus: ref.read(plusActiveProvider),
      );
    } on TriggerCapsuleLimitReached {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(activeTriggerCountProvider);
      return;
    } on CapsuleUnlockOutOfRange {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = _Problem.dateRange;
        });
      }
      return;
    } on CapsuleEmpty {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = _Problem.needContent;
        });
      }
      return;
    } catch (e) {
      debugPrint('capsules: seal failed (${e.runtimeType})');
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = _Problem.failed;
        });
      }
      return;
    }
    _saveSoon?.cancel();
    await drafts.clear();
    unawaited(store.deleteDraft(draft.id));
    sync.notifyLocalWrite();
    AuraHaptics.light();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sealedWith = unlock;
      _mediaLater =
          !online && (content.voice != null || content.photos.isNotEmpty);
    });
    // A lexicon hit: help first (the capsule is already sealed and safe).
    if (hard) {
      await showSupportSheet(
        context,
        crisis: true,
        origin: SupportOrigin.capsule,
      );
    }
    if (!mounted) return;
    // F2: sealing a capsule is journaling.
    final logged = await autoCompleteHabitToday(ref, PresetHabitKeys.journal);
    if (logged && mounted) setState(() => _journalLogged = true);
    // PRD 15-permissions: sealing a date capsule is the moment for the one
    // notification re-ask — never right after a hard moment.
    if (!hard && unlock is DateUnlock && mounted) await _offerUnlockNotice();
  }

  /// "Want to know when it opens?": offered once, when push says the OS
  /// prompt may be shown now (`PushService.mayAskAgain`: never asked, or the
  /// one re-ask 30+ days after a decline). Only "Allow" fires the prompt.
  Future<void> _offerUnlockNotice() async {
    try {
      final push = ref.read(pushServiceProvider);
      final kv = ref.read(kvStoreProvider);
      if (!push.isAvailable) return;
      if (await kv.get(capsuleNotifyOfferedKey) != null) return;
      if (await push.permission() == PushPermission.authorized) return;
      if (!await push.mayAskAgain() || !mounted) return;
      await kv.set(capsuleNotifyOfferedKey, 'true');
      if (!mounted) return;
      final allow = await showModalBottomSheet<bool>(
        context: context,
        // Over the navigation bar too: a modal never leaves the tabs tappable.
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => const CapsuleNotifyAskSheet(),
      );
      if (allow == true) await push.requestFromSettings();
    } on Object catch (e) {
      debugPrint('capsules: notify ask skipped (${e.runtimeType})');
    }
  }

  // ---- leaving ---------------------------------------------------------------------

  bool get _canLeaveFreely =>
      _sealedWith != null || _leaving || !(_draft?.hasInput ?? false);

  Future<void> _onBlockedPop() async {
    final draft = _draft;
    if (draft == null) return;
    final choice = await showDialog<_Leave>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l.capsules_leaveTitle),
          content: Text(l.capsules_leaveBody),
          actions: [
            TextButton(
              key: const ValueKey('capsule-leave-editing'),
              autofocus: true,
              onPressed: () => Navigator.pop(context),
              child: Text(l.capsules_leaveEditing),
            ),
            TextButton(
              key: const ValueKey('capsule-leave-discard'),
              onPressed: () => Navigator.pop(context, _Leave.discard),
              child: Text(l.capsules_leaveDiscard),
            ),
            TextButton(
              key: const ValueKey('capsule-leave-keep'),
              onPressed: () => Navigator.pop(context, _Leave.keep),
              child: Text(l.capsules_leaveKeep),
            ),
          ],
        );
      },
    );
    if (choice == null || !mounted) return;
    _saveSoon?.cancel();
    final drafts = ref.read(capsuleDraftStoreProvider);
    if (choice == _Leave.keep) {
      await draft.finishVoice();
      await drafts.save(draft);
    } else {
      final store = ref.read(capsuleMediaStoreProvider);
      draft.removeListener(_onDraft);
      await drafts.clear();
      await store.deleteDraft(draft.id);
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.watch(capsuleCoordinatorProvider);
    final draft = _draft;
    final sealed = _sealedWith;
    return PopScope(
      canPop: _canLeaveFreely,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBlockedPop());
      },
      child: Scaffold(
        appBar: helpAppBar(context, title: l.capsules_composeTitle),
        body: CosmicBackground(
          child: draft == null
              ? const SizedBox.expand()
              : sealed != null
              ? _SealedView(
                  unlock: sealed,
                  journalLogged: _journalLogged,
                  mediaLater: _mediaLater,
                )
              : _form(context, draft),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, CapsuleDraft draft) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final promptsOn = ref.watch(guidedPromptsEnabledProvider).value ?? true;
    final prompt = promptsOn
        ? promptFor(
            l,
            surface: PromptSurface.capsule,
            quadrant: draft.targetQuadrant,
            seed: promptSeed(draft.id),
            turn: draft.promptTurn,
          )
        : null;

    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: AuraSpace.xl, bottom: AuraSpace.s),
      child: Semantics(
        header: true,
        container: true,
        child: Text(text, style: t.titleSmall),
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
        TextField(
          key: const ValueKey('capsule-title-field'),
          controller: draft.title,
          maxLength: maxCapsuleTitleLength,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l.capsules_titleLabel,
            helperText: l.capsules_titleHelper,
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: AuraSpace.l),
        TextField(
          key: const ValueKey('capsule-text-field'),
          controller: draft.text,
          maxLength: maxCapsuleTextLength,
          minLines: 5,
          maxLines: 12,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.capsules_textLabel,
            helperText: l.capsules_textHelper,
            helperMaxLines: 3,
            alignLabelWithHint: true,
            // The prompt is only a hint: never sealed, never counted.
            hintText: prompt,
            hintMaxLines: 3,
            floatingLabelBehavior: prompt == null
                ? null
                : FloatingLabelBehavior.always,
          ),
        ),
        if (prompt != null && draft.text.text.isEmpty)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: const ValueKey('capsule-prompt-another'),
              onPressed: () {
                draft.promptTurn++;
                setState(() {});
              },
              icon: const Icon(Icons.autorenew_rounded, size: 18),
              label: Text(l.prompt_another),
            ),
          ),
        const SizedBox(height: AuraSpace.l),
        VoiceNoteField.custom(
          binding: draft,
          maxDuration: capsuleVoiceLimit(plus: ref.watch(plusActiveProvider)),
          newRecordingPath: () =>
              ref.read(capsuleMediaStoreProvider).newDraftVoicePath(draft.id),
          recordHint: l.capsules_voiceHint,
          limitReachedText: l.capsules_voiceLimit,
        ),
        header(l.capsules_photosTitle),
        _Photos(
          draft: draft,
          adding: _addingPhoto,
          failed: _photoFailed,
          onAdd: _addPhotos,
        ),
        header(l.capsules_unlockTitle),
        _UnlockChooser(
          draft: draft,
          onPickDate: _pickDate,
          dateProblem: _problem == _Problem.dateRange,
        ),
        if (_problem != null && _problem != _Problem.dateRange) ...[
          const SizedBox(height: AuraSpace.l),
          InlineNotice(switch (_problem!) {
            _Problem.needContent => l.capsules_needContent,
            _Problem.needUnlock => l.capsules_needUnlock,
            _Problem.failed => l.capsules_sealFailed,
            _Problem.dateRange => l.capsules_dateHelp,
          }, key: ValueKey('capsule-problem-${_problem!.name}')),
        ],
        const SizedBox(height: AuraSpace.xl),
        FilledButton(
          key: const ValueKey('capsule-seal'),
          onPressed: _busy ? null : _seal,
          child: BusyButtonLabel(
            l.capsules_seal,
            busy: _busy,
            icon: Icons.lock_outline_rounded,
          ),
        ),
      ],
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({
    required this.draft,
    required this.adding,
    required this.failed,
    required this.onAdd,
  });

  final CapsuleDraft draft;
  final bool adding;
  final bool failed;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final photos = draft.photos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty) ...[
          Wrap(
            spacing: AuraSpace.s,
            runSpacing: AuraSpace.s,
            children: [
              for (var i = 0; i < photos.length; i++)
                _Thumb(
                  key: ValueKey('capsule-photo-thumb-$i'),
                  path: photos[i].path,
                  label: l.capsules_photoSemantic(i + 1, photos.length),
                  removeLabel: l.capsules_photoRemove(i + 1),
                  onRemove: () {
                    AuraHaptics.selection();
                    draft.removePhoto(i);
                  },
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s),
        ],
        if (!draft.atPhotoLimit)
          OutlinedButton.icon(
            key: const ValueKey('capsule-add-photo'),
            onPressed: adding ? null : onAdd,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(l.capsules_addPhoto),
          ),
        const SizedBox(height: AuraSpace.xs),
        Text(
          l.capsules_photoHint,
          style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
        ),
        if (adding) ...[
          const SizedBox(height: AuraSpace.s),
          Row(
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AuraSpace.s),
              Flexible(
                child: Text(
                  l.capsules_photoAdding,
                  style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
                ),
              ),
            ],
          ),
        ],
        if (failed) ...[
          const SizedBox(height: AuraSpace.s),
          InlineNotice(
            l.capsules_photoFailed,
            key: const ValueKey('capsule-photo-failed'),
          ),
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.path,
    required this.label,
    required this.removeLabel,
    required this.onRemove,
  });

  final String path;
  final String label;
  final String removeLabel;
  final VoidCallback onRemove;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              image: true,
              label: label,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AuraRadius.s),
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: (_size * 3).round(),
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: AuraColors.skyHigh),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: IconButton.filledTonal(
              tooltip: removeLabel,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              iconSize: 18,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockChooser extends ConsumerWidget {
  const _UnlockChooser({
    required this.draft,
    required this.onPickDate,
    required this.dateProblem,
  });

  final CapsuleDraft draft;
  final VoidCallback onPickDate;
  final bool dateProblem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tag = ref.watch(localeControllerProvider);
    final soft = t.bodySmall?.copyWith(color: AuraColors.textSoft);
    final kind = draft.kind;
    // F12: Aura Plus keeps as many trigger capsules as you like.
    final atLimit =
        !ref.watch(plusActiveProvider) &&
        (ref.watch(activeTriggerCountProvider).value ?? 0) >=
            maxActiveTriggerCapsules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AuraSpace.s,
          runSpacing: AuraSpace.s,
          children: [
            ChoiceChip(
              key: const ValueKey('capsule-unlock-date'),
              label: Text(l.capsules_unlockDate),
              avatar: const Icon(Icons.event_outlined, size: 18),
              selected: kind == CapsuleUnlockKind.date,
              onSelected: (_) {
                AuraHaptics.selection();
                draft.kind = CapsuleUnlockKind.date;
              },
            ),
            ChoiceChip(
              key: const ValueKey('capsule-unlock-feeling'),
              label: Text(l.capsules_unlockFeeling),
              avatar: const Icon(Icons.favorite_border_rounded, size: 18),
              selected: kind == CapsuleUnlockKind.feeling,
              onSelected: (_) {
                AuraHaptics.selection();
                draft.kind = CapsuleUnlockKind.feeling;
              },
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.m),
        if (kind == CapsuleUnlockKind.date) ...[
          Text(l.capsules_dateHelp, style: soft),
          if (draft.date != null) ...[
            const SizedBox(height: AuraSpace.s),
            Text(
              l.capsules_dateChosen(
                capsuleDateLabel(tag, draft.date!),
                capsuleUnlockTimeLabel(context),
              ),
              key: const ValueKey('capsule-date-chosen'),
              style: t.bodyLarge,
            ),
          ],
          if (dateProblem) ...[
            const SizedBox(height: AuraSpace.s),
            InlineNotice(
              l.capsules_dateHelp,
              key: const ValueKey('capsule-problem-dateRange'),
            ),
          ],
          const SizedBox(height: AuraSpace.s),
          OutlinedButton.icon(
            key: const ValueKey('capsule-pick-date'),
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              draft.date == null ? l.capsules_pickDate : l.capsules_changeDate,
            ),
          ),
        ],
        if (kind == CapsuleUnlockKind.feeling && atLimit)
          // REQ-CAP-04: the free path ("make it a date capsule") first, then
          // the way to Aura Plus under the F12 paywall rules.
          InlineNotice(
            l.capsules_limitBody,
            key: const ValueKey('capsule-trigger-limit'),
            action: Wrap(
              spacing: AuraSpace.s,
              children: [
                TextButton(
                  key: const ValueKey('capsule-limit-pick-date'),
                  onPressed: () {
                    draft.kind = CapsuleUnlockKind.date;
                    onPickDate();
                  },
                  child: Text(l.capsules_limitPickDate),
                ),
                const PlusOpenButton(
                  surface: PaywallSurface.capsuleTriggerLimit,
                ),
              ],
            ),
          ),
        if (kind == CapsuleUnlockKind.feeling && !atLimit) ...[
          Text(l.capsules_feelingHelp, style: soft),
          const SizedBox(height: AuraSpace.m),
          for (final q in Quadrant.values) ...[
            Wrap(
              spacing: AuraSpace.s,
              runSpacing: AuraSpace.s,
              children: [
                ChoiceChip(
                  key: ValueKey('capsule-quadrant-${q.name}'),
                  label: Text(l.capsules_anyQuadrant(quadrantName(l, q))),
                  selected: draft.quadrant == q,
                  selectedColor: AuraColors.quadrantDeep(q),
                  side: BorderSide(
                    color: AuraColors.quadrant(q).withValues(alpha: 0.6),
                  ),
                  onSelected: (_) {
                    AuraHaptics.selection();
                    draft.pickQuadrant(q);
                  },
                ),
                for (final m in moodsIn(q))
                  ChoiceChip(
                    key: ValueKey('capsule-mood-${m.id}'),
                    label: Text(m.nameFor(tag)),
                    selected: draft.moodId == m.id,
                    selectedColor: AuraColors.quadrantDeep(q),
                    onSelected: (_) {
                      AuraHaptics.selection();
                      draft.pickMood(m.id);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AuraSpace.m),
          ],
          if (draft.unlock case final MoodUnlock target)
            Text(
              l.capsules_feelingChosen(feelingLabel(l, tag, target)),
              key: const ValueKey('capsule-feeling-chosen'),
              style: t.bodyLarge,
            ),
        ],
      ],
    );
  }
}

/// After sealing: "Sealed until 12 Oct 2027. It'll keep." (or it waits for
/// the feeling), and Done.
class _SealedView extends ConsumerWidget {
  const _SealedView({
    required this.unlock,
    required this.journalLogged,
    required this.mediaLater,
  });

  final CapsuleUnlock unlock;
  final bool journalLogged;
  final bool mediaLater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tag = ref.watch(localeControllerProvider);
    final line = switch (unlock) {
      DateUnlock(:final date) => l.capsules_sealedUntil(
        capsuleDateLabel(tag, date),
      ),
      MoodUnlock() => l.capsules_sealedFeeling,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.xxl,
        AuraSpace.gutter,
        AuraSpace.xl,
      ),
      children: [
        const ExcludeSemantics(
          child: Icon(
            Icons.lock_clock_outlined,
            size: 48,
            color: AuraColors.starlight,
          ),
        ),
        const SizedBox(height: AuraSpace.l),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            l.capsules_sealedTitle,
            textAlign: TextAlign.center,
            style: t.headlineSmall,
          ),
        ),
        const SizedBox(height: AuraSpace.s),
        Text(
          line,
          key: const ValueKey('capsule-sealed-line'),
          textAlign: TextAlign.center,
          style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
        ),
        if (mediaLater) ...[
          const SizedBox(height: AuraSpace.l),
          InlineNotice(
            l.capsules_mediaLater,
            key: const ValueKey('capsule-media-later'),
            icon: Icons.cloud_off_outlined,
          ),
        ],
        if (journalLogged) ...[
          const SizedBox(height: AuraSpace.l),
          Text(
            l.habits_autoLogged(habitLabel(l, PresetHabitKeys.journal)),
            key: const ValueKey('capsule-journal-logged'),
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: AuraColors.starlight),
          ),
        ],
        const SizedBox(height: AuraSpace.xl),
        FilledButton(
          key: const ValueKey('capsule-sealed-done'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l.common_done),
        ),
      ],
    );
  }
}

/// Key/value flag: the capsule notification ask was shown (it never nags).
const String capsuleNotifyOfferedKey = 'capsules.notify_offered';

/// "Want to know when it opens?" — the soft ask before the OS prompt.
/// True for "Allow"; "Not now" never shows the OS prompt.
class CapsuleNotifyAskSheet extends StatelessWidget {
  const CapsuleNotifyAskSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.xl,
        AuraSpace.gutter,
        AuraSpace.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: AuraColors.lavender,
            ),
          ),
          const SizedBox(height: AuraSpace.l),
          Semantics(
            header: true,
            child: Text(
              l.capsules_notifyAskTitle,
              textAlign: TextAlign.center,
              style: t.headlineSmall,
            ),
          ),
          const SizedBox(height: AuraSpace.s),
          Text(
            l.capsules_notifyAskBody,
            textAlign: TextAlign.center,
            style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.xl),
          FilledButton(
            key: const ValueKey('capsule-notify-allow'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.push_allow),
          ),
          const SizedBox(height: AuraSpace.s),
          TextButton(
            key: const ValueKey('capsule-notify-not-now'),
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.common_notNow),
          ),
        ],
      ),
    );
  }
}
