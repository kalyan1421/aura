import 'dart:io';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/haptics.dart';
import '../../core/theme/aura_tokens.dart';
import '../voice/voice_note_field.dart';
import '../voice/voice_store.dart';
import 'checkin_repository.dart';
import 'quadrant_glyph.dart';

/// What the person has picked for one check-in: mood, tags, note and voice
/// note. Shared by the picker (F1) and the history edit (within 24 h), so
/// both keep the same limits and the same "unsaved input" rule.
class CheckInDraft extends ChangeNotifier {
  CheckInDraft({
    Mood? mood,
    Iterable<String> tags = const [],
    String? note,
    this.savedVoice,
  }) : _mood = mood,
       _initialMoodId = mood?.id,
       tags = {...tags},
       _initialTags = {...tags},
       _initialNote = note?.trim() ?? '',
       note = TextEditingController(text: note ?? '') {
    this.note.addListener(notifyListeners);
    customTag.addListener(notifyListeners);
  }

  // ---- voice note ------------------------------------------------------------

  /// The voice note this check-in already has (edit), or `null`.
  final SavedVoice? savedVoice;
  bool _savedVoiceKept = true;
  VoiceClip? _newVoice;
  bool _recording = false;
  Future<void> Function()? _finishRecording;

  /// A new recording (replaces [savedVoice] when saved).
  VoiceClip? get newVoice => _newVoice;

  /// The saved voice note stays as it is.
  bool get keepsSavedVoice =>
      savedVoice != null && _savedVoiceKept && _newVoice == null;

  /// Saving removes the saved voice note.
  bool get removesVoice =>
      savedVoice != null && !_savedVoiceKept && _newVoice == null;

  /// True while the microphone is recording.
  bool get isRecording => _recording;

  set isRecording(bool value) {
    if (value == _recording) return;
    _recording = value;
    notifyListeners();
  }

  /// The voice field went away mid-recording (its recording is dropped).
  /// Silent: it happens while the tree is being torn down.
  void recordingDropped() => _recording = false;

  /// A finished recording: replaces any earlier one of this draft.
  void setNewVoice(VoiceClip clip) {
    if (_newVoice?.path != clip.path) _discard(_newVoice);
    _newVoice = clip;
    notifyListeners();
  }

  /// No voice note at all (the new recording and a saved one).
  void removeVoice() {
    _discard(_newVoice);
    _newVoice = null;
    _savedVoiceKept = false;
    notifyListeners();
  }

  /// The voice field registers how to finish a recording in progress, so
  /// Save never waits on (or loses) it.
  void attachRecorder(Future<void> Function()? finish) =>
      _finishRecording = finish;

  /// Stops a recording in progress and keeps it (Save calls this first).
  Future<void> finishVoice() async => _finishRecording?.call();

  bool get _voiceChanged =>
      _newVoice != null || (savedVoice != null && !_savedVoiceKept);

  /// A draft recording that won't be saved: its file goes (the saved copy,
  /// once moved into the voice store, is no longer at this path).
  static void _discard(VoiceClip? clip) {
    if (clip == null) return;
    try {
      File(clip.path).deleteSync();
    } on FileSystemException {
      // Already moved or gone.
    }
  }

  Mood? _mood;
  final String? _initialMoodId;
  final Set<String> _initialTags;
  final String _initialNote;

  /// Selected tag keys (context tag keys or custom tag text).
  final Set<String> tags;

  /// Custom tags typed during this session, shown after the offered ones.
  final List<String> addedTags = [];

  final TextEditingController note;
  final TextEditingController customTag = TextEditingController();

  Mood? get mood => _mood;
  set mood(Mood? value) {
    if (value == _mood) return;
    _mood = value;
    notifyListeners();
  }

  /// [maxTagsPerCheckIn] reached: further taps only show the calm hint.
  bool get atTagLimit => tags.length >= maxTagsPerCheckIn;

  /// Something differs from what the draft started with (typed but not yet
  /// added custom-tag text counts too): leaving must ask first.
  bool get isDirty =>
      _mood?.id != _initialMoodId ||
      !setEquals(tags, _initialTags) ||
      note.text.trim() != _initialNote ||
      customTag.text.trim().isNotEmpty ||
      _voiceChanged ||
      _recording;

  /// The note differs from the one the draft started with.
  bool get noteChanged => note.text.trim() != _initialNote;

  /// Empties a new check-in ("Start over" on the onboarding check-in): no
  /// mood, tags, words or half-typed tag.
  void clear() {
    _mood = null;
    tags.clear();
    addedTags.clear();
    _discard(_newVoice);
    _newVoice = null;
    _recording = false;
    note.clear();
    customTag.clear();
    notifyListeners();
  }

  void toggleTag(String tag) {
    if (!tags.remove(tag)) {
      if (atTagLimit) return; // the hint explains it (never silent)
      tags.add(tag);
    }
    notifyListeners();
  }

  /// Adds the typed custom tag (≤ [maxCustomTagLength] chars) and selects it.
  /// A name that matches an offered chip ([offered] keys, compared with their
  /// [labelOf] text too, ignoring case) selects that chip instead.
  void addCustomTag(
    Iterable<String> offered,
    String Function(String key) labelOf,
  ) {
    var text = customTag.text.trim();
    if (text.isEmpty) return;
    if (text.length > maxCustomTagLength) {
      text = text.substring(0, maxCustomTagLength).trim();
    }
    final lower = text.toLowerCase();
    String? existing;
    for (final key in [...offered, ...addedTags]) {
      if (key.toLowerCase() == lower || labelOf(key).toLowerCase() == lower) {
        existing = key;
        break;
      }
    }
    final key = existing ?? text;
    if (existing == null) addedTags.add(text);
    if (!tags.contains(key) && !atTagLimit) tags.add(key);
    customTag.clear(); // notifies
  }

  @override
  void dispose() {
    _discard(_newVoice); // never saved (a saved one was moved away)
    note.dispose();
    customTag.dispose();
    super.dispose();
  }
}

/// Optional details of a check-in: tag chips (context tags, the person's
/// recent custom tags, new ones), a custom-tag field, the private note and
/// an optional voice note (≤ 60 s).
///
/// Guided prompt (REQ-CHK-05): [notePrompt] shows only as the empty note's
/// hint, so typing hides it and it is never saved, synced or counted toward
/// the 500 characters. "Another prompt" ([onAnotherPrompt]) is offered while
/// the note is empty.
class CheckInDetailsEditor extends StatelessWidget {
  const CheckInDetailsEditor({
    super.key,
    required this.draft,
    this.recentTags = const [],
    this.notePrompt,
    this.onAnotherPrompt,
  });

  final CheckInDraft draft;

  /// The person's recent custom tags (most recent first).
  final List<String> recentTags;

  /// The guided prompt for the empty note, or `null` for none.
  final String? notePrompt;

  /// Shows a different prompt; `null` hides "Another prompt".
  final VoidCallback? onAnotherPrompt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final offered = <String>[
          ...contextTags,
          ...recentTags.where((t) => !contextTags.contains(t)),
        ];
        // Tags already on the check-in (edit) stay visible even if they are
        // not among the recent ones.
        final all = <String>[
          ...offered,
          for (final t in [...draft.tags, ...draft.addedTags])
            if (!offered.contains(t)) t,
        ];
        final unique = all.toSet().toList(); // keeps order
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              container: true,
              child: Text(
                l.checkin_tagsTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: AuraSpace.s),
            Wrap(
              spacing: AuraSpace.s,
              runSpacing: AuraSpace.s,
              children: [
                for (final t in unique)
                  FilterChip(
                    key: ValueKey('tag-$t'),
                    label: Text(tagLabel(l, t)),
                    selected: draft.tags.contains(t),
                    onSelected: (_) {
                      AuraHaptics.selection();
                      draft.toggleTag(t);
                    },
                  ),
              ],
            ),
            if (draft.atTagLimit) ...[
              const SizedBox(height: AuraSpace.s),
              Semantics(
                liveRegion: true,
                container: true,
                child: Row(
                  children: [
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AuraColors.textSoft,
                      ),
                    ),
                    const SizedBox(width: AuraSpace.xs),
                    Flexible(
                      child: Text(
                        l.checkin_tagLimit(maxTagsPerCheckIn),
                        key: const ValueKey('checkin-tag-limit'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AuraColors.textSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AuraSpace.m),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('checkin-custom-tag'),
                    controller: draft.customTag,
                    maxLength: maxCustomTagLength,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        draft.addCustomTag(offered, (k) => tagLabel(l, k)),
                    decoration: InputDecoration(
                      hintText: l.checkin_customTag,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: AuraSpace.s),
                IconButton.filledTonal(
                  key: const ValueKey('checkin-custom-tag-add'),
                  tooltip: l.checkin_customTagAdd,
                  onPressed: () =>
                      draft.addCustomTag(offered, (k) => tagLabel(l, k)),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.l),
            TextField(
              key: const ValueKey('checkin-note'),
              controller: draft.note,
              maxLength: maxNoteLength,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.checkin_noteLabel,
                helperText: l.checkin_noteHint,
                alignLabelWithHint: true,
                // The prompt is only a hint: typing hides it, and it is
                // never part of the note.
                hintText: notePrompt,
                hintMaxLines: 3,
                floatingLabelBehavior: notePrompt == null
                    ? null
                    : FloatingLabelBehavior.always,
              ),
            ),
            if (notePrompt != null &&
                onAnotherPrompt != null &&
                draft.note.text.isEmpty)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  key: const ValueKey('checkin-prompt-another'),
                  onPressed: onAnotherPrompt,
                  icon: const Icon(Icons.autorenew_rounded, size: 18),
                  label: Text(l.prompt_another),
                ),
              ),
            const SizedBox(height: AuraSpace.l),
            VoiceNoteField(draft: draft),
          ],
        );
      },
    );
  }
}

/// "Leave without saving?" — asked before unsaved check-in input is dropped
/// (never lose input). "Keep editing" comes first and holds focus, so a
/// stray confirm keeps the input. Returns true only for "Discard".
Future<bool> confirmDiscard(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.checkin_discardTitle),
      actions: [
        TextButton(
          key: const ValueKey('discard-keep'),
          autofocus: true,
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.checkin_discardKeep),
        ),
        TextButton(
          key: const ValueKey('discard-confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.checkin_discardConfirm),
        ),
      ],
    ),
  );
  return discard ?? false;
}
