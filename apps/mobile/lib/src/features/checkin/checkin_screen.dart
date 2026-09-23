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
import '../onboarding/gate_controller.dart';
import '../progress/progress_view.dart';
import '../push/push_explainer.dart';
import '../support/crisis_lexicon.dart';
import '../support/support_sheet.dart';
import 'checkin_details.dart';
import 'checkin_providers.dart';
import 'mood_grid.dart';

/// How far the Save button leans towards the picked quadrant's colour.
const double checkInSaveTint = 0.45;

/// Save button fill once a mood is picked. `onAccent` text on it stays
/// ≥ 4.5:1 for every quadrant (REQ-A11Y-03; test/checkin_contrast_test.dart).
Color checkInSaveColor(Quadrant q) =>
    Color.lerp(AuraColors.accent, AuraColors.quadrant(q), checkInSaveTint)!;

/// F1 Mood Check-in. Tap 1 = mood, tap 2 = Save. Tags and a note are
/// optional. Saved locally first — no spinner, no network wait.
///
/// Unsaved input is never dropped silently: ✕ and the system back gesture
/// ask "Leave without saving?" first.
///
/// The first check-in ends onboarding and is the only route, so the system
/// back gesture never leaves the app or skips it: with nothing picked back
/// does nothing; with input it offers "Keep editing" (default) or "Start
/// over", which clears the picker and stays here.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key, this.first = false});

  /// The first check-in at the end of onboarding (no close button).
  final bool first;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  /// Client id, fixed for this screen: a double-tap on Save is one entry.
  late final String _id = ref.read(idsProvider).v7();
  final _draft = CheckInDraft();

  bool _details = false;
  bool _saving = false;
  bool _saved = false;
  bool _failed = false;

  /// Saved, but the voice note couldn't be kept (storage full).
  bool _voiceDropped = false;

  /// The person chose to leave (Discard): popping is allowed again.
  bool _leaving = false;

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
    setState(() {
      _saving = true;
      _failed = false;
    });
    // Save is never blocked by voice: a recording in progress is finished
    // and saved with the check-in.
    await _draft.finishVoice();
    final note = _draft.note.text;
    var dropped = false;
    try {
      await ref
          .read(checkInRepositoryProvider)
          .save(
            id: _id,
            mood: mood,
            tags: _draft.tags.toList(),
            note: note,
            voice: _draft.newVoice,
            onVoiceDropped: () => dropped = true,
          );
      _voiceDropped = dropped;
      ref.read(syncControllerProvider).notifyLocalWrite();
    } catch (_) {
      // Selection and text are kept; the user can retry.
      if (mounted) setState(() => _failed = true);
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    AuraHaptics.light();
    if (!mounted) return;
    // Order after saving (F1): crisis sheet first, then Starlight.
    if (noteNeedsSupport(note)) {
      await showSupportSheet(context, crisis: true);
    }
    if (mounted) setState(() => _saved = true);
  }

  Future<void> _finish() async {
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mood = _draft.mood;
    final tint = mood == null ? null : AuraColors.quadrant(mood.quadrant);
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
              child: _saved
                  ? _SavedMoment(
                      key: const ValueKey('saved'),
                      checkInId: _id,
                      voiceDropped: _voiceDropped,
                      onDone: _finish,
                    )
                  : _buildPicker(context, l),
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
    final mood = _draft.mood;
    final Widget details = mood == null
        ? const SizedBox(width: double.infinity)
        : _details
        ? CheckInDetailsEditor(draft: _draft, recentTags: recentTags)
        : Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _details = true),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.checkin_addDetails),
            ),
          );
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
                  l.checkin_title,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
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

/// "+10 Starlight" and a calm "Saved" line. Help stays one tap away.
/// (The room prompt returns when F5 Mood Rooms exist.)
class _SavedMoment extends ConsumerWidget {
  const _SavedMoment({
    super.key,
    required this.checkInId,
    required this.onDone,
    this.voiceDropped = false,
  });

  final String checkInId;
  final VoidCallback onDone;

  /// The check-in saved without its voice note (PRD F1 "Storage full").
  final bool voiceDropped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final view = ref.watch(progressViewProvider);
    final award = view.awards[checkInId];
    final sync = ref.watch(syncControllerProvider);
    final reduce = reduceMotionOf(context);

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
        return CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AuraSpace.gutter,
                  AuraSpace.xs,
                  AuraSpace.gutter,
                  AuraSpace.l,
                ),
                child: Column(
                  children: [
                    const Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: HelpNowButton(compact: true),
                    ),
                    const Spacer(),
                    AuraAvatar(
                      state: view.avatar,
                      size: const Size.square(230),
                    ),
                    const SizedBox(height: AuraSpace.l),
                    if (award == null)
                      const SizedBox(height: 44)
                    else if (award > 0)
                      reduce
                          // Reduce Motion: a plain short fade, no scale or
                          // shimmer (REQ-A11Y-08).
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
                                  color: Colors.white.withValues(alpha: 0.7),
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
                    const SizedBox(height: AuraSpace.xs),
                    Text(
                      l.checkin_savedThanks,
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (voiceDropped) ...[
                      const SizedBox(height: AuraSpace.m),
                      InlineNotice(
                        l.voice_dropped,
                        key: const ValueKey('checkin-voice-dropped'),
                        icon: Icons.mic_off_outlined,
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: AuraSpace.l),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('checkin-done'),
                        onPressed: onDone,
                        child: Text(l.common_done),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
