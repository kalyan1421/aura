import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../avatar/aura_avatar.dart';
import '../onboarding/gate_controller.dart';
import '../progress/progress_view.dart';
import '../push/push_explainer.dart';
import '../support/crisis_lexicon.dart';
import '../support/support_sheet.dart';
import 'checkin_repository.dart';
import 'mood_grid.dart';
import 'quadrant_glyph.dart';

/// F1 Mood Check-in. Tap 1 = mood, tap 2 = Save. Tags and a note are
/// optional. Saved locally first — no spinner, no network wait.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key, this.first = false});

  /// The first check-in at the end of onboarding.
  final bool first;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  /// Client id, fixed for this screen: a double-tap on Save is one entry.
  late final String _id = ref.read(idsProvider).v7();
  final _note = TextEditingController();
  final _customTag = TextEditingController();

  Mood? _mood;
  final Set<String> _tags = {};
  final List<String> _customTags = [];
  bool _details = false;
  bool _saving = false;
  bool _saved = false;
  bool _failed = false;

  @override
  void dispose() {
    _note.dispose();
    _customTag.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final mood = _mood;
    if (mood == null || _saving || _saved) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref
          .read(checkInRepositoryProvider)
          .save(id: _id, mood: mood, tags: _tags.toList(), note: _note.text);
      ref.read(syncControllerProvider).notifyLocalWrite();
    } catch (_) {
      // Selection and text are kept; the user can retry.
      if (mounted) setState(() => _failed = true);
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    HapticFeedback.lightImpact();
    if (!mounted) return;
    // Order after saving (F1): crisis sheet first, then Starlight + room.
    if (noteNeedsSupport(_note.text)) {
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

  void _addCustomTag() {
    final t = _customTag.text.trim();
    if (t.isEmpty || _customTags.contains(t)) return;
    setState(() {
      _customTags.add(t);
      if (_tags.length < maxTagsPerCheckIn) _tags.add(t);
      _customTag.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tint = _mood == null ? null : AuraColors.quadrant(_mood!.quadrant);
    return Scaffold(
      body: CosmicBackground(
        tint: tint,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: AuraMotion.calm,
            child: _saved
                ? _SavedMoment(
                    key: const ValueKey('saved'),
                    checkInId: _id,
                    onDone: _finish,
                  )
                : _buildPicker(context, l),
          ),
        ),
      ),
    );
  }

  Widget _buildPicker(BuildContext context, AppLocalizations l) {
    final theme = Theme.of(context);
    final localeTag = ref.watch(localeControllerProvider);
    return Column(
      key: const ValueKey('picker'),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 0),
          child: Row(
            children: [
              if (!widget.first)
                IconButton(
                  tooltip: l.common_close,
                  onPressed: _finish,
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
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.gutter,
              AuraSpace.s,
              AuraSpace.gutter,
              AuraSpace.xl,
            ),
            children: [
              Text(l.checkin_title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AuraSpace.xs),
              Text(
                l.checkin_subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AuraColors.textSoft,
                ),
              ),
              const SizedBox(height: AuraSpace.l),
              MoodGrid(
                selected: _mood,
                localeTag: localeTag,
                onSelected: (m) => setState(() => _mood = m),
              ),
              const SizedBox(height: AuraSpace.l),
              AnimatedSize(
                duration: AuraMotion.calm,
                curve: AuraMotion.ease,
                alignment: Alignment.topCenter,
                child: _mood == null
                    ? const SizedBox(width: double.infinity)
                    : _details
                    ? _buildDetails(context, l)
                    : Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _details = true),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l.checkin_addDetails),
                        ),
                      ),
              ),
              if (_failed) ...[
                const SizedBox(height: AuraSpace.m),
                Text(
                  l.checkin_saveFailed,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AuraColors.lantern,
                  ),
                ),
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
              onPressed: _mood == null || _saving ? null : _save,
              style: _mood == null
                  ? null
                  : FilledButton.styleFrom(
                      backgroundColor: Color.lerp(
                        AuraColors.accent,
                        AuraColors.quadrant(_mood!.quadrant),
                        0.45,
                      ),
                    ),
              child: Text(l.checkin_save),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetails(BuildContext context, AppLocalizations l) {
    final theme = Theme.of(context);
    final allTags = [...contextTags, ..._customTags];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.checkin_tagsTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: AuraSpace.s),
        Wrap(
          spacing: AuraSpace.s,
          runSpacing: AuraSpace.s,
          children: [
            for (final t in allTags)
              FilterChip(
                label: Text(tagLabel(l, t)),
                selected: _tags.contains(t),
                onSelected: (on) => setState(() {
                  if (on && _tags.length < maxTagsPerCheckIn) {
                    _tags.add(t);
                  } else {
                    _tags.remove(t);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.m),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customTag,
                maxLength: maxCustomTagLength,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addCustomTag(),
                decoration: InputDecoration(
                  hintText: l.checkin_customTag,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: AuraSpace.s),
            IconButton.filledTonal(
              tooltip: l.checkin_customTagAdd,
              onPressed: _addCustomTag,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.l),
        TextField(
          controller: _note,
          maxLength: maxNoteLength,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.checkin_noteLabel,
            helperText: l.checkin_noteHint,
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

/// "+10 Starlight", then the (coming soon) room prompt.
class _SavedMoment extends ConsumerWidget {
  const _SavedMoment({super.key, required this.checkInId, required this.onDone});

  final String checkInId;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final view = ref.watch(progressViewProvider);
    final award = view.awards[checkInId];
    final sync = ref.watch(syncControllerProvider);

    return ValueListenableBuilder<SyncPhase>(
      valueListenable: sync.phase,
      builder: (context, phase, _) {
        final localOnly = phase == SyncPhase.offline ||
            phase == SyncPhase.unavailable ||
            phase == SyncPhase.signedOut;
        return Padding(
          padding: const EdgeInsets.all(AuraSpace.gutter),
          child: Column(
            children: [
              const Spacer(),
              AuraAvatar(state: view.avatar, size: const Size.square(230)),
              const SizedBox(height: AuraSpace.l),
              if (award == null)
                const SizedBox(height: 44)
              else if (award > 0)
                Text(
                      l.checkin_savedStarlight(award),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AuraColors.starlight,
                      ),
                    )
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
                ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: AuraSpace.s),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: AuraColors.textSoft,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    localOnly ? l.checkin_savedOffline : l.checkin_saved,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AuraColors.textSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.xs),
              Text(
                l.checkin_savedThanks,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // F5 Mood Rooms are not built yet: shown, disabled.
              _RoomPrompt(label: l.checkin_roomButton, badge: l.common_comingSoon)
                  .animate()
                  .fadeIn(delay: 700.ms, duration: 500.ms),
              const SizedBox(height: AuraSpace.m),
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
        );
      },
    );
  }
}

class _RoomPrompt extends StatelessWidget {
  const _RoomPrompt({required this.label, required this.badge});

  final String label;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          disabledForegroundColor: AuraColors.textSoft,
          side: const BorderSide(color: AuraColors.outline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_2_outlined, size: 20),
            const SizedBox(width: AuraSpace.s),
            Flexible(child: Text(label, textAlign: TextAlign.center)),
            const SizedBox(width: AuraSpace.s),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AuraColors.surfaceHigh,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
              ),
              child: Text(badge, style: theme.textTheme.labelSmall),
            ),
          ],
        ),
      ),
    );
  }
}
