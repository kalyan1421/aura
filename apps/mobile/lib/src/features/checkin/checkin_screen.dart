import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/haptics.dart';
import '../../core/a11y/motion.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/inline_notice.dart';
import '../avatar/aura_avatar.dart';
import '../avatar/moments_controller.dart';
import '../companion/companion_lines.dart';
import '../companion/companion_response.dart';
import '../companion/minute_for_you.dart';
import '../companion/prompts.dart';
import '../habits/habit_repository.dart' show noteCompletesJournal;
import '../history/backfill.dart';
import '../onboarding/gate_controller.dart';
import '../progress/progress_view.dart';
import '../push/push_explainer.dart';
import '../rooms/room_offer.dart';
import '../sanctuary/habit_auto_complete.dart';
import '../support/crisis_lexicon.dart';
import '../support/support_sheet.dart';
import 'checkin_details.dart';
import 'checkin_providers.dart';
import 'checkin_repository.dart';
import 'mood_grid.dart';
import 'post_save.dart';
import 'quadrant_glyph.dart';

/// How far the Save button leans towards the picked quadrant's colour.
const double checkInSaveTint = 0.45;

/// Save button fill once a mood is picked. `onAccent` text on it stays
/// ≥ 4.5:1 for every quadrant (REQ-A11Y-03; test/checkin_contrast_test.dart).
Color checkInSaveColor(Quadrant q) =>
    Color.lerp(AuraColors.accent, AuraColors.quadrant(q), checkInSaveTint)!;

/// F1 Mood Check-in. Tap 1 = mood, tap 2 = Save. Tags and a note are
/// optional. Saved locally first — no spinner, no network wait.
///
/// After saving, in this order (F1, PRD 06d): the crisis sheet if the note
/// calls for it → the mood-trigger capsule step (F4; held after the sheet)
/// → the saved moment: Starlight, the companion response, "A minute for
/// you" (not after the sheet) and the room offer (F5). A note of 50+
/// characters also ticks off today's Journal (F2).
///
/// Unsaved input is never dropped silently: ✕ and the system back gesture
/// ask "Leave without saving?" first.
///
/// The first check-in ends onboarding and is the only route, so the system
/// back gesture never leaves the app or skips it: with nothing picked back
/// does nothing; with input it offers "Keep editing" (default) or "Start
/// over", which clears the picker and stays here.
///
/// With [backfillDay] it adds a check-in for a past day from History (F1
/// backfill): the same mood grid and details, saved with that day. It earns
/// nothing, has no streak effect, fires no capsule, completes no habit and
/// gets no companion response, minute card or room offer: just "Added to
/// your sky".
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key, this.first = false, this.backfillDay});

  /// The first check-in at the end of onboarding (no close button).
  final bool first;

  /// A past Aura day, 1–7 days back (F1 backfill); `null` = a live check-in.
  final LocalDay? backfillDay;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  /// Client id, fixed for this screen: a double-tap on Save is one entry.
  late final String _id = ref.read(idsProvider).v7();
  final _draft = CheckInDraft();

  /// The past day this check-in is for (backfill), or `null` (live).
  late LocalDay? _backfillDay = widget.backfillDay;

  bool _details = false;
  bool _saving = false;
  bool _saved = false;
  bool _failed = false;

  /// The past day moved out of the 7-day window before Save (04:00 rolled
  /// over): pick another. Nothing was saved; the input is kept.
  bool _dayOutOfRange = false;

  /// Saved, but the voice note couldn't be kept (storage full).
  bool _voiceDropped = false;

  /// The crisis sheet opened after this save.
  bool _crisisShown = false;

  /// The companion line picked for this check-in.
  String? _lineKey;

  /// The note ticked off today's Journal (F2).
  bool _journalLogged = false;

  /// "Another prompt" taps.
  int _promptTurn = 0;

  /// The person chose to leave (Discard): popping is allowed again.
  bool _leaving = false;

  bool get _backfill => _backfillDay != null;

  @override
  void initState() {
    super.initState();
    _draft.addListener(_onDraft);
  }

  void _onDraft() => setState(() {});

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  /// Picked or typed something that is not saved yet.
  bool get _hasInput => !_saved && !_leaving && _draft.isDirty;

  Future<void> _save() async {
    final mood = _draft.mood;
    if (mood == null || _saving || _saved) return;
    final day = _backfillDay;
    if (day != null &&
        !isBackfillDay(day, ref.read(timeContextProvider).today())) {
      setState(() => _dayOutOfRange = true);
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
      _dayOutOfRange = false;
    });
    // Read before any await: this screen may be gone by the end.
    final repo = ref.read(checkInRepositoryProvider);
    final sync = ref.read(syncControllerProvider);
    final kv = ref.read(kvStoreProvider);
    // Save is never blocked by voice: a recording in progress is finished
    // and saved with the check-in.
    await _draft.finishVoice();
    final note = _draft.note.text;
    var dropped = false;
    try {
      await repo.save(
        id: _id,
        mood: mood,
        tags: _draft.tags.toList(),
        note: note,
        voice: _draft.newVoice,
        onVoiceDropped: () => dropped = true,
        backfillDay: day,
      );
      _voiceDropped = dropped;
      sync.notifyLocalWrite();
    } on BackfillOutOfRange {
      if (mounted) setState(() => _dayOutOfRange = true);
      return;
    } catch (_) {
      // Selection and text are kept; the user can retry.
      if (mounted) setState(() => _failed = true);
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    AuraHaptics.light();
    if (!mounted) return;
    final live = day == null;

    // F2: a note of 50+ characters is journaling. Never for a backfill (it
    // earns nothing); the habit rules decide the rest (shown, not done yet).
    if (live && noteCompletesJournal(note)) {
      unawaited(
        autoCompleteHabitToday(ref, PresetHabitKeys.journal).then((logged) {
          if (logged && mounted) setState(() => _journalLogged = true);
        }),
      );
    }

    // Order after saving (F1, PRD 06d): 1. the crisis sheet…
    final crisis = noteNeedsSupport(note);
    if (crisis) await showSupportSheet(context, crisis: true);
    if (!mounted) return;
    // 2. …a mood-trigger capsule (held after the sheet; never for a
    // backfill, which fires none)…
    if (live) {
      await ref.read(moodTriggerCapsuleStepProvider)(
        context,
        ref,
        checkInId: _id,
        mood: mood,
        crisisShown: crisis,
      );
    }
    // 3. …then the saved moment, with its one line (the neutral pool after
    // the sheet).
    final line = live
        ? await CompanionMemory(kv).pickFor(
            checkInId: _id,
            quadrant: mood.quadrant,
            afterCrisis: crisis,
          )
        : null;
    if (!mounted) return;
    setState(() {
      _saved = true;
      _crisisShown = crisis;
      _lineKey = line;
    });
  }

  Future<void> _finish() async {
    if (_backfill) {
      // Back to History, where the past check-in now shows under its day.
      // (pop, not maybePop: leaving was already confirmed.)
      Navigator.of(context).pop();
      return;
    }
    // Notifications are offered only after a saved check-in, once (PRD
    // 15-permissions); never at launch.
    if (_saved) await offerPushAfterCheckIn(context, ref);
    if (!mounted) return;
    if (widget.first) {
      await ref
          .read(gateControllerProvider.notifier)
          .goTo(OnboardingStage.done);
      // /checkin stays a valid route after onboarding, so go home explicitly.
      if (mounted) context.go('/home');
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// ✕: asks first when something is picked or typed.
  Future<void> _close() async {
    if (_hasInput && !await confirmDiscard(context)) return;
    if (!mounted) return;
    setState(() => _leaving = true);
    await _finish();
  }

  /// System back that was held: unsaved input here, or any back on the
  /// first check-in.
  Future<void> _onBlockedPop() async {
    if (widget.first) {
      // Never leaves the app or skips onboarding. Nothing picked (or already
      // saved: Done is right there): back simply does nothing.
      if (!_hasInput || _saving) return;
      if (await _confirmStartOver(context) && mounted) _startOver();
      return;
    }
    if (!await confirmDiscard(context) || !mounted) return;
    setState(() => _leaving = true);
    await _finish();
  }

  /// "Start over" on the first check-in: empty picker, same screen.
  void _startOver() {
    setState(() {
      _details = false;
      _failed = false;
    });
    _draft.clear();
  }

  /// A past check-in: pick another day (the input stays).
  Future<void> _changeDay() async {
    final picked = await pickBackfillDay(context, ref, selected: _backfillDay);
    if (picked == null || !mounted) return;
    setState(() {
      _backfillDay = picked;
      _dayOutOfRange = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Avatar moments (wake-up, evolve) this check-in causes are found by
    // comparing with the state before it, so the moments listener must be
    // running (not paused) from the start, whatever hosts this screen.
    ref.listen<AvatarMoment?>(momentsControllerProvider, (_, _) {});
    final mood = _draft.mood;
    final tint = mood == null ? null : AuraColors.quadrant(mood.quadrant);
    final Widget saved = _backfill
        ? _BackfillSaved(
            key: const ValueKey('saved'),
            day: _backfillDay!,
            quadrant: mood?.quadrant ?? Quadrant.moonlight,
            onDone: _finish,
          )
        : _SavedMoment(
            key: const ValueKey('saved'),
            checkInId: _id,
            quadrant: mood?.quadrant ?? Quadrant.moonlight,
            lineKey: _lineKey,
            crisisShown: _crisisShown,
            voiceDropped: _voiceDropped,
            journalLogged: _journalLogged,
            onDone: _finish,
          );
    return PopScope(
      // The first check-in is the only route: back is always held there.
      canPop: !widget.first && !_hasInput,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBlockedPop();
      },
      child: Scaffold(
        body: CosmicBackground(
          tint: tint,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: reduceMotionOf(context)
                  ? reducedMotionFade
                  : AuraMotion.calm,
              child: _saved ? saved : _buildPicker(context, l),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPicker(BuildContext context, AppLocalizations l) {
    final theme = Theme.of(context);
    final localeTag = ref.watch(localeControllerProvider);
    final recentTags = ref.watch(recentCustomTagsProvider).value ?? const [];
    final promptsOn = ref.watch(guidedPromptsEnabledProvider).value ?? true;
    final mood = _draft.mood;
    final prompt = promptsOn && mood != null
        ? promptFor(
            l,
            surface: PromptSurface.checkInNote,
            quadrant: mood.quadrant,
            seed: promptSeed(_id),
            turn: _promptTurn,
          )
        : null;
    final Widget details = mood == null
        ? const SizedBox(width: double.infinity)
        : _details
        ? CheckInDetailsEditor(
            draft: _draft,
            recentTags: recentTags,
            notePrompt: prompt,
            onAnotherPrompt: prompt == null
                ? null
                : () => setState(() => _promptTurn++),
          )
        : Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _details = true),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.checkin_addDetails),
            ),
          );
    final day = _backfillDay;
    return Column(
      key: const ValueKey('picker'),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 0),
          child: Row(
            children: [
              if (!widget.first)
                IconButton(
                  key: const ValueKey('checkin-close'),
                  tooltip: l.common_close,
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded),
                )
              else
                const SizedBox(width: 48),
              const SizedBox(width: AuraSpace.s),
              const Flexible(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: HelpNowButton(compact: true),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            // Tight top and grid spacing: at 1.0 text the title, subtitle
            // and all 16 moods fit above the pinned Save on a 390 × 844
            // phone, even in the tall layout (test/mood_grid_fit_test.dart).
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.gutter,
              AuraSpace.xs,
              AuraSpace.gutter,
              AuraSpace.xl,
            ),
            children: [
              Semantics(
                header: true,
                container: true,
                child: Text(
                  day == null ? l.checkin_title : l.backfill_title,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              if (day != null) ...[
                const SizedBox(height: AuraSpace.xs),
                _BackfillDayChip(
                  label: backfillDayLabel(localeTag, day),
                  onTap: _changeDay,
                ),
              ],
              const SizedBox(height: AuraSpace.xs),
              Text(
                l.checkin_subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AuraColors.textSoft,
                ),
              ),
              const SizedBox(height: AuraSpace.m),
              MoodGrid(
                selected: mood,
                localeTag: localeTag,
                onSelected: (m) => _draft.mood = m,
              ),
              const SizedBox(height: AuraSpace.l),
              // The details grow in; under Reduce Motion they just appear.
              if (reduceMotionOf(context))
                details
              else
                AnimatedSize(
                  duration: AuraMotion.calm,
                  curve: AuraMotion.ease,
                  alignment: Alignment.topCenter,
                  child: details,
                ),
              if (_dayOutOfRange) ...[
                const SizedBox(height: AuraSpace.m),
                InlineNotice(
                  l.backfill_outOfRange,
                  key: const ValueKey('backfill-out-of-range'),
                  action: TextButton(
                    onPressed: _changeDay,
                    child: Text(l.backfill_changeDay),
                  ),
                ),
              ],
              if (_failed) ...[
                const SizedBox(height: AuraSpace.m),
                // Ordinary recovery, not a support cue: no lantern tone.
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
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('checkin-save'),
              onPressed: mood == null || _saving ? null : _save,
              style: mood == null
                  ? null
                  : FilledButton.styleFrom(
                      backgroundColor: checkInSaveColor(mood.quadrant),
                    ),
              child: Text(l.checkin_save),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Start over?" on the first check-in (the system back gesture with input).
/// "Keep editing" comes first and holds focus, so a stray confirm keeps the
/// input. Returns true only for "Start over".
Future<bool> _confirmStartOver(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final startOver = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.flows_startOverTitle),
      content: Text(l.flows_startOverBody),
      actions: [
        TextButton(
          key: const ValueKey('startover-keep'),
          autofocus: true,
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.checkin_discardKeep),
        ),
        TextButton(
          key: const ValueKey('startover-confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.flows_startOver),
        ),
      ],
    ),
  );
  return startOver ?? false;
}

/// The day a past check-in is for; a tap picks another.
class _BackfillDayChip extends StatelessWidget {
  const _BackfillDayChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      // One node: "Check-in for Tuesday, October 6", hint "Change day".
      child: Semantics(
        button: true,
        label: l.backfill_forDay(label),
        hint: l.backfill_changeDay,
        onTap: onTap,
        excludeSemantics: true,
        child: TextButton.icon(
          key: const ValueKey('backfill-day'),
          onPressed: onTap,
          icon: const Icon(Icons.edit_calendar_outlined, size: 18),
          label: Text(label),
        ),
      ),
    );
  }
}

/// The saved moment of a live check-in, after the crisis sheet and the
/// capsule step: help first, the avatar's response, Starlight, one warm
/// line, then "A minute for you" and the room offer. Done stays pinned.
///
/// Companion response (PRD 06d): a ≤ 2 s quadrant-tinted shimmer and one
/// line from the quadrant's pool; after a crisis sheet a neutral line and no
/// minute card. If this check-in woke the avatar or crossed a stage, that
/// moment plays instead of the shimmer and its line is the only one shown.
class _SavedMoment extends ConsumerStatefulWidget {
  const _SavedMoment({
    super.key,
    required this.checkInId,
    required this.quadrant,
    required this.lineKey,
    required this.crisisShown,
    required this.onDone,
    this.voiceDropped = false,
    this.journalLogged = false,
  });

  final String checkInId;
  final Quadrant quadrant;

  /// The companion line ([CompanionLines] key).
  final String? lineKey;

  /// The crisis sheet opened for this check-in: no minute card.
  final bool crisisShown;
  final VoidCallback onDone;

  /// The check-in saved without its voice note (PRD F1 "Storage full").
  final bool voiceDropped;

  /// Today's Journal was ticked off by this note.
  final bool journalLogged;

  @override
  ConsumerState<_SavedMoment> createState() => _SavedMomentState();
}

class _SavedMomentState extends ConsumerState<_SavedMoment> {
  /// A wake-up or evolve moment this check-in caused; once seen it stays.
  AvatarMoment? _moment;
  bool _minuteDismissed = false;

  static AvatarMoment? _playable(AvatarMoment? m) =>
      m != null &&
          (m.kind == AvatarMomentKind.wakeUp ||
              m.kind == AvatarMomentKind.evolve)
      ? m
      : null;

  @override
  void initState() {
    super.initState();
    _take(_playable(ref.read(momentsControllerProvider)));
  }

  /// Plays [m] here, and marks it played at once so Home never replays it
  /// (even when Done comes before the moment ends).
  void _take(AvatarMoment? m) {
    if (m == null || _moment != null) return;
    _moment = m;
    final moments = ref.read(momentsControllerProvider.notifier);
    // After this frame: never change a provider while widgets build.
    Future.microtask(() => moments.markPlayed(m));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final view = ref.watch(progressViewProvider);
    final award = view.awards[widget.checkInId];
    final sync = ref.watch(syncControllerProvider);
    final reduce = reduceMotionOf(context);
    // A moment can arrive a beat after the saved moment opens (the progress
    // projection catches up): it then takes over from the shimmer.
    ref.listen<AvatarMoment?>(momentsControllerProvider, (_, next) {
      final m = _playable(next);
      if (_moment == null && m != null) setState(() => _take(m));
    });
    final moment = _moment;

    final avatar = AuraAvatar(
      state: view.avatar,
      size: const Size.square(220),
      moment: moment,
      onMomentDone: (m) =>
          ref.read(momentsControllerProvider.notifier).markPlayed(m),
    );
    final String? line = switch (moment?.kind) {
      AvatarMomentKind.wakeUp => l.home_welcomeBack,
      AvatarMomentKind.evolve => l.home_evolved(
        stageName(l, view.avatar.stage),
      ),
      _ =>
        widget.lineKey == null ? null : CompanionLines.text(l, widget.lineKey!),
    };

    return ValueListenableBuilder<SyncPhase>(
      valueListenable: sync.phase,
      builder: (context, phase, _) {
        final localOnly =
            phase == SyncPhase.offline ||
            phase == SyncPhase.unavailable ||
            phase == SyncPhase.signedOut;
        final starlight = Text(
          l.checkin_savedStarlight(award ?? 0),
          key: const ValueKey('checkin-starlight'),
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            color: AuraColors.starlight,
          ),
        );
        return Column(
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                AuraSpace.gutter,
                AuraSpace.xs,
                AuraSpace.gutter,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: HelpNowButton(compact: true),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AuraSpace.gutter,
                        0,
                        AuraSpace.gutter,
                        AuraSpace.s,
                      ),
                      child: Column(
                        children: [
                          const Spacer(),
                          if (moment != null)
                            avatar
                          else
                            CompanionReaction(
                              quadrant: widget.quadrant,
                              child: avatar,
                            ),
                          const SizedBox(height: AuraSpace.l),
                          if (award == null)
                            const SizedBox(height: 44)
                          else if (award > 0)
                            reduce
                                // Reduce Motion: a plain short fade, no scale
                                // or shimmer (REQ-A11Y-08).
                                ? starlight.animate().fadeIn(
                                    duration: reducedMotionFade,
                                  )
                                : starlight
                                      .animate()
                                      .fadeIn(duration: 400.ms)
                                      .scale(
                                        begin: const Offset(0.85, 0.85),
                                        curve: Curves.easeOutBack,
                                        duration: 600.ms,
                                      )
                                      .then(delay: 200.ms)
                                      .shimmer(
                                        duration: 1400.ms,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      )
                          else
                            Text(
                              l.checkin_savedFull,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium,
                            ).animate().fadeIn(
                              duration: reduce ? reducedMotionFade : 400.ms,
                            ),
                          const SizedBox(height: AuraSpace.s),
                          Semantics(
                            liveRegion: true,
                            container: true,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const ExcludeSemantics(
                                  child: Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 18,
                                    color: AuraColors.textSoft,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    localOnly
                                        ? l.checkin_savedOffline
                                        : l.checkin_saved,
                                    key: const ValueKey('checkin-saved-line'),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AuraColors.textSoft,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.journalLogged) ...[
                            const SizedBox(height: AuraSpace.xs),
                            Semantics(
                              liveRegion: true,
                              container: true,
                              child: Text(
                                l.habits_autoLogged(
                                  habitLabel(l, PresetHabitKeys.journal),
                                ),
                                key: const ValueKey('checkin-journal-logged'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AuraColors.textSoft,
                                ),
                              ),
                            ),
                          ],
                          if (line != null) ...[
                            const SizedBox(height: AuraSpace.m),
                            CompanionLine(line, key: ValueKey(line)),
                          ],
                          if (widget.voiceDropped) ...[
                            const SizedBox(height: AuraSpace.m),
                            InlineNotice(
                              l.voice_dropped,
                              key: const ValueKey('checkin-voice-dropped'),
                              icon: Icons.mic_off_outlined,
                            ),
                          ],
                          const Spacer(),
                          const SizedBox(height: AuraSpace.l),
                          // Never right after the crisis sheet, which has its
                          // own grounding (REQ-CMP-04).
                          if (!widget.crisisShown && !_minuteDismissed) ...[
                            MinuteForYouCard(
                              quadrant: widget.quadrant,
                              onDismiss: () =>
                                  setState(() => _minuteDismissed = true),
                            ),
                            const SizedBox(height: AuraSpace.s),
                          ],
                          // F5: "Join a room of people feeling this" (the
                          // rooms feature fills it; nothing until then).
                          RoomOfferButton(quadrant: widget.quadrant),
                        ],
                      ),
                    ),
                  ),
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
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('checkin-done'),
                  onPressed: widget.onDone,
                  child: Text(l.common_done),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// After a past check-in (F1 backfill): "Added to your sky", the day, and a
/// calm line on why no Starlight shows. No companion response, minute card
/// or room offer (PRD 06d).
class _BackfillSaved extends ConsumerWidget {
  const _BackfillSaved({
    super.key,
    required this.day,
    required this.quadrant,
    required this.onDone,
  });

  final LocalDay day;
  final Quadrant quadrant;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final localeTag = ref.watch(localeControllerProvider);
    return Column(
      children: [
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AuraSpace.gutter,
            AuraSpace.xs,
            AuraSpace.gutter,
            0,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: HelpNowButton(compact: true),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.gutter),
                  child: Column(
                    children: [
                      const Spacer(),
                      ExcludeSemantics(
                        child: Container(
                          width: 88,
                          height: 88,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AuraColors.quadrantDeep(quadrant),
                            border: Border.all(
                              color: AuraColors.quadrant(quadrant)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: QuadrantGlyph(quadrant, size: 40),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.xl),
                      Semantics(
                        header: true,
                        container: true,
                        child: Text(
                          l.backfill_savedTitle,
                          key: const ValueKey('backfill-saved'),
                          textAlign: TextAlign.center,
                          style: t.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s),
                      Semantics(
                        liveRegion: true,
                        container: true,
                        child: Text(
                          l.backfill_savedDay(backfillDayLabel(localeTag, day)),
                          textAlign: TextAlign.center,
                          style: t.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s),
                      Text(
                        l.backfill_savedBody,
                        textAlign: TextAlign.center,
                        style: t.bodyMedium?.copyWith(
                          color: AuraColors.textSoft,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
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
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('checkin-done'),
              onPressed: onDone,
              child: Text(l.common_done),
            ),
          ),
        ),
      ],
    );
  }
}
