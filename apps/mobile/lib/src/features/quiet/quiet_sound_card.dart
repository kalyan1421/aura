import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../sanctuary/sounds/sounds_controller.dart';
import '../sanctuary/sounds/sounds_library.dart';

/// "The shared sound" (PRD F16 "Shared soundscape, played locally";
/// REQ-QUIET-03): silent until the person taps "Play the shared sound";
/// per-person volume; a one-time download note when a base recording isn't
/// on the phone yet (the session works silently meanwhile). Used by Quiet
/// Together and the Lantern Hour wind-down.
class SharedSoundCard extends ConsumerStatefulWidget {
  const SharedSoundCard({
    super.key,
    required this.soundKey,
    required this.stemIds,
    required this.build,
    this.title,
    this.body,
  });

  /// The [SharedSound.key] this card plays.
  final String soundKey;
  final List<String> stemIds;

  /// Builds the shared sound at the moment of the tap (positions come from
  /// the shared clock then).
  final SharedSound Function() build;
  final String? title;
  final String? body;

  @override
  ConsumerState<SharedSoundCard> createState() => _SharedSoundCardState();
}

class _SharedSoundCardState extends ConsumerState<SharedSoundCard> {
  bool _unplayable = false;
  bool _downloading = false;

  void _play() {
    final ok = ref
        .read(soundsControllerProvider.notifier)
        .startShared(widget.build());
    setState(() => _unplayable = !ok);
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    await ref.read(soundsLibraryProvider.notifier).downloadBase();
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final sounds = ref.watch(soundsControllerProvider);
    final library = ref.watch(soundsLibraryProvider);
    final playing = sounds.shared == widget.soundKey && !sounds.isIdle;
    final needsDownload =
        library.loaded &&
        widget.stemIds.any((id) {
          final stem = library.manifest.byId(id);
          return stem != null &&
              !stem.isPlus &&
              stem.hasRecording &&
              !library.downloaded.contains(id);
        });

    return Container(
      key: const ValueKey('shared-sound-card'),
      padding: const EdgeInsets.all(AuraSpace.l),
      decoration: BoxDecoration(
        color: AuraColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AuraRadius.l),
        border: Border.all(color: AuraColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              widget.title ?? l.quiet_soundTitle,
              style: t.titleMedium,
            ),
          ),
          const SizedBox(height: AuraSpace.xs),
          Text(
            widget.body ?? l.quiet_soundBody,
            style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.m),
          if (needsDownload && !playing) ...[
            Text(
              l.quiet_soundDownload,
              key: const ValueKey('shared-sound-download-note'),
              style: t.bodyMedium,
            ),
            const SizedBox(height: AuraSpace.s),
            OutlinedButton.icon(
              key: const ValueKey('shared-sound-download'),
              onPressed: _downloading ? null : _download,
              icon: const Icon(Icons.download_rounded),
              label: Text(l.quiet_soundDownloadCta),
            ),
          ] else if (playing) ...[
            Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.volume_down_rounded,
                    color: AuraColors.textSoft,
                  ),
                ),
                Expanded(
                  child: Slider(
                    key: const ValueKey('shared-sound-volume'),
                    value: sounds.sharedLevel,
                    label: l.quiet_soundVolume,
                    semanticFormatterCallback: (v) =>
                        '${l.quiet_soundVolume} ${(v * 100).round()}%',
                    onChanged: (v) => ref
                        .read(soundsControllerProvider.notifier)
                        .setSharedLevel(v),
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              key: const ValueKey('shared-sound-stop'),
              onPressed: () => ref
                  .read(soundsControllerProvider.notifier)
                  .stopShared(widget.soundKey),
              icon: const Icon(Icons.stop_rounded),
              label: Text(l.quiet_soundStop),
            ),
          ] else ...[
            FilledButton.icon(
              key: const ValueKey('shared-sound-play'),
              onPressed: _play,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l.quiet_soundPlay),
            ),
            if (_unplayable)
              Padding(
                padding: const EdgeInsets.only(top: AuraSpace.s),
                child: Text(
                  l.quiet_soundUnavailable,
                  style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
