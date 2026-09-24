import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/a11y/haptics.dart';
import '../../../core/a11y/motion.dart';
import '../../../core/entitlements/plus.dart';
import '../../../core/providers.dart';
import '../../../core/theme/aura_tokens.dart';
import '../../../core/widgets/inline_notice.dart';
import '../../plus/paywall_gate.dart' show PaywallSurface;
import '../../plus/plus_entry.dart' show showPlusNoteSheet;
import '../activity_scaffold.dart';
import 'saved_mixes.dart';
import 'sounds_controller.dart';
import 'sounds_library.dart';
import 'stem_labels.dart';
import 'stem_manifest.dart';
import 'stem_store.dart';
import 'wind_down_reminder.dart';

/// Whether downloads can run now (tests set it directly).
final soundsOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).value ?? true,
);

/// Sanctuary › Sounds (F15, PRD 06d): the night wind-down, the stem mixer
/// (up to four, each with its own volume), saved mixes, the timer and the
/// one-time download of recorded stems.
///
/// Opening it plays nothing (REQ-SAN-09): sound starts on a tap and fades
/// in. "I need help now" sits in the header (REQ-SAN-08); sound keeps
/// playing under the Safety Center, as it does with the screen off.
/// Every stem reads as name, state and volume ("Rain, playing, volume 60%",
/// REQ-A11Y-17); under Reduce Motion nothing on this screen moves.
class SoundsScreen extends ConsumerStatefulWidget {
  const SoundsScreen({super.key});

  @override
  ConsumerState<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends ConsumerState<SoundsScreen> {
  StemDownloadError? _downloadError;

  /// The size of what the failed download needed (for "Storage full").
  int _downloadBytes = 0;

  AppLocalizations get _l => AppLocalizations.of(context);

  /// A short calm note. Floats above the play / stop bar, never over it.
  void _note(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final barUp = !ref.read(soundsControllerProvider).isIdle;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            AuraSpace.l,
            0,
            AuraSpace.l,
            barUp ? _transportClearance(context) : AuraSpace.l,
          ),
        ),
      );
  }

  /// Room for the transport bar (it grows with large text).
  static double _transportClearance(BuildContext context) =>
      AuraSpace.l + MediaQuery.textScalerOf(context).scale(56) + 24;

  Future<void> _onStemTap(Stem stem) async {
    final controller = ref.read(soundsControllerProvider.notifier);
    final result = controller.toggle(stem.id);
    switch (result) {
      case SoundsToggle.added || SoundsToggle.removed:
        AuraHaptics.selection();
      case SoundsToggle.locked:
        // F12 Plus explainer (REQ-PAY-11): straight after a Storm/Rain
        // check-in or in a crisis flow it says only "Part of Aura Plus".
        await showPlusNoteSheet(
          context,
          surface: PaywallSurface.soundsStem,
          explainer: _l.plus_explainerSounds,
        );
      case SoundsToggle.full:
        _note(_l.sounds_full);
      case SoundsToggle.busy:
        _note(_l.sounds_windDownBusy);
      case SoundsToggle.needsDownload:
        // A Plus recording downloads when first picked, then plays.
        _downloadBytes = stem.file?.bytes ?? 0;
        final err = await ref
            .read(soundsLibraryProvider.notifier)
            .downloadStem(stem.id);
        if (!mounted) return;
        setState(() => _downloadError = err);
        if (err == null && !ref.read(soundsControllerProvider).isOn(stem.id)) {
          if (controller.toggle(stem.id) == SoundsToggle.added) {
            AuraHaptics.selection();
          }
        }
      case SoundsToggle.unknown:
        break;
    }
  }

  Future<void> _downloadBase() async {
    setState(() {
      _downloadError = null;
      _downloadBytes = ref.read(soundsLibraryProvider).baseDownloadBytes;
    });
    final err = await ref.read(soundsLibraryProvider.notifier).downloadBase();
    if (mounted) setState(() => _downloadError = err);
  }

  Future<void> _pickTimer() async {
    final current = ref.read(soundsControllerProvider).timer;
    final picked = await showModalBottomSheet<_TimerChoice>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheet) => _TimerSheet(current: current),
    );
    if (picked == null || !mounted) return;
    ref.read(soundsControllerProvider.notifier).setTimer(picked.length);
  }

  Future<void> _saveMix() async {
    final mix = ref.read(soundsControllerProvider.notifier).currentMix;
    if (mix == null) return;
    final saved = await ref.read(savedMixesProvider.notifier).save(mix);
    if (mounted) {
      _note(saved ? _l.sounds_mixSaved : _l.sounds_mixAlreadySaved);
    }
  }

  void _playMix(SavedMix mix) {
    final ok = ref.read(soundsControllerProvider.notifier).playMix(mix);
    if (ok) {
      AuraHaptics.selection();
    } else {
      _note(_l.sounds_mixUnavailable);
    }
  }

  Future<void> _removeDownloads() async {
    await ref.read(soundsLibraryProvider.notifier).removeDownloads();
    if (mounted) _note(_l.sounds_downloadsRemoved);
  }

  String _mixName(SoundsLibraryState library, SavedMix mix) => [
    for (final id in mix.stemIds)
      if (library.manifest.byId(id) case final stem?) stemTitle(_l, stem),
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final t = Theme.of(context).textTheme;
    final sounds = ref.watch(soundsControllerProvider);
    final library = ref.watch(soundsLibraryProvider);
    final plus = ref.watch(plusActiveProvider);
    final mixes = ref.watch(savedMixesProvider);
    final online = ref.watch(soundsOnlineProvider);
    final reduce = reduceMotionOf(context);

    Widget section(String text) => Padding(
      padding: const EdgeInsets.only(top: AuraSpace.xl, bottom: AuraSpace.s),
      child: Semantics(
        header: true,
        container: true,
        child: Text(text, style: t.titleSmall),
      ),
    );

    final toDownload = library.baseToDownload;
    return ActivityScaffold(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              key: const ValueKey('sounds-list'),
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.gutter,
                AuraSpace.m,
                AuraSpace.gutter,
                AuraSpace.xxl,
              ),
              children: [
                ActivityTitle(l.sounds_title),
                const SizedBox(height: AuraSpace.s),
                Text(
                  l.sounds_intro,
                  textAlign: TextAlign.center,
                  style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
                ),
                const SizedBox(height: AuraSpace.m),
                _StatusLine(state: sounds),
                const SizedBox(height: AuraSpace.l),
                _WindDownCard(
                  state: sounds,
                  onBegin: () {
                    if (ref
                        .read(soundsControllerProvider.notifier)
                        .startWindDown()) {
                      AuraHaptics.selection();
                    }
                  },
                ),
                if (toDownload.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.l),
                  _DownloadCard(
                    size: megabytes(l, library.baseDownloadBytes),
                    online: online,
                    downloading: library.isDownloading,
                    onDownload: _downloadBase,
                  ),
                ],
                if (_downloadError case final err?) ...[
                  const SizedBox(height: AuraSpace.m),
                  InlineNotice(
                    key: const ValueKey('sounds-download-error'),
                    switch (err) {
                      StemDownloadError.offline => l.sounds_downloadOffline,
                      StemDownloadError.noSpace => l.sounds_noSpace(
                        megabytes(l, _downloadBytes),
                      ),
                      _ => l.sounds_downloadFailed,
                    },
                  ),
                ],
                section(l.sounds_mixSection),
                Text(
                  l.sounds_mixHint,
                  style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                ),
                const SizedBox(height: AuraSpace.m),
                for (final stem in library.stems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s),
                    child: _StemTile(
                      key: ValueKey('sounds-stem-${stem.id}'),
                      stem: stem,
                      volume: sounds.volumeOf(stem.id),
                      playing: sounds.isPlaying,
                      windDown: sounds.isWindDown,
                      locked: stem.isPlus && !plus,
                      needsDownload: library.needsDownload(stem),
                      progress: library.downloading[stem.id],
                      reduceMotion: reduce,
                      onTap: () => _onStemTap(stem),
                      onVolume: (v) => ref
                          .read(soundsControllerProvider.notifier)
                          .setVolume(stem.id, v),
                    ),
                  ),
                if (!sounds.isIdle && !sounds.isWindDown) ...[
                  const SizedBox(height: AuraSpace.s),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      key: const ValueKey('sounds-save-mix'),
                      onPressed: _saveMix,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text(l.sounds_saveMix),
                    ),
                  ),
                ],
                if (mixes.isNotEmpty) ...[
                  section(l.sounds_savedMixes),
                  for (final mix in mixes)
                    _SavedMixRow(
                      name: _mixName(library, mix),
                      onPlay: () => _playMix(mix),
                      onRemove: () =>
                          ref.read(savedMixesProvider.notifier).remove(mix),
                    ),
                ],
                if (library.downloaded.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.l),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const ValueKey('sounds-remove-downloads'),
                      onPressed: _removeDownloads,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(l.sounds_removeDownloads),
                    ),
                  ),
                ],
                const SizedBox(height: AuraSpace.l),
                Text(
                  l.sounds_backgroundNote,
                  style: t.bodySmall?.copyWith(color: AuraColors.textMuted),
                ),
              ],
            ),
          ),
          if (!sounds.isIdle) _TransportBar(state: sounds, onTimer: _pickTimer),
        ],
      ),
    );
  }
}

/// "Nothing playing" / "Playing · fades out in about 12 minutes" /
/// "Paused": one live region, so screen readers hear changes, not ticks.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final SoundsState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final parts = <String>[
      switch (state.phase) {
        SoundsPhase.idle => l.sounds_nothingPlaying,
        SoundsPhase.playing => l.sounds_statePlaying,
        SoundsPhase.paused => l.sounds_statePaused,
      },
      if (!state.isIdle && state.fadingOut)
        l.sounds_fadingOut
      else if (!state.isIdle && state.timerLeft != null)
        l.sounds_timerLeft(_ceilMinutes(state.timerLeft!)),
      if (state.isWindDown && state.windDownLeft != null)
        l.sounds_windDownLeft(_ceilMinutes(state.windDownLeft!)),
    ];
    return Semantics(
      liveRegion: true,
      container: true,
      child: Text(
        parts.join(' · '),
        key: const ValueKey('sounds-status'),
        textAlign: TextAlign.center,
        style: t.labelLarge?.copyWith(color: AuraColors.lavender),
      ),
    );
  }
}

int _ceilMinutes(Duration d) => (d.inMilliseconds / 60000).ceil().clamp(1, 999);

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.highlight = false});

  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AuraSpace.l),
    decoration: BoxDecoration(
      color: AuraColors.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(AuraRadius.l),
      border: Border.all(
        color: highlight
            ? AuraColors.starlight.withValues(alpha: 0.35)
            : AuraColors.hairline,
      ),
    ),
    child: child,
  );
}

class _WindDownCard extends StatelessWidget {
  const _WindDownCard({required this.state, required this.onBegin});

  final SoundsState state;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final active = state.isWindDown;
    return _Panel(
      highlight: active,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: Icon(Icons.bedtime_outlined, color: AuraColors.lavender),
              ),
              const SizedBox(width: AuraSpace.s),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.sounds_windDownTitle, style: t.titleMedium),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s),
          Text(
            l.sounds_windDownBody,
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          if (!active) ...[
            const SizedBox(height: AuraSpace.m),
            FilledButton(
              key: const ValueKey('sounds-wind-down'),
              onPressed: onBegin,
              child: Text(l.sounds_windDownBegin),
            ),
          ],
          // The opt-in wind-down reminder (F14, REQ-NTF-04).
          const WindDownReminderRow(),
        ],
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.size,
    required this.online,
    required this.downloading,
    required this.onDownload,
  });

  final String size;
  final bool online;
  final bool downloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(l.sounds_downloadTitle, style: t.titleMedium),
          ),
          const SizedBox(height: AuraSpace.s),
          Text(
            l.sounds_downloadBody(size),
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.m),
          if (!online)
            InlineNotice(
              l.sounds_downloadOffline,
              key: const ValueKey('sounds-offline'),
              icon: Icons.cloud_off_outlined,
            )
          else
            OutlinedButton.icon(
              key: const ValueKey('sounds-download'),
              onPressed: downloading ? null : onDownload,
              icon: downloading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                downloading ? l.sounds_downloading : l.sounds_download,
              ),
            ),
        ],
      ),
    );
  }
}

/// One stem: a toggle (the whole row, one focus stop) and, while it is in
/// the mix, its volume slider.
class _StemTile extends StatelessWidget {
  const _StemTile({
    super.key,
    required this.stem,
    required this.volume,
    required this.playing,
    required this.windDown,
    required this.locked,
    required this.needsDownload,
    required this.progress,
    required this.reduceMotion,
    required this.onTap,
    required this.onVolume,
  });

  final Stem stem;

  /// Its volume while in the mix, else `null`.
  final double? volume;
  final bool playing;
  final bool windDown;
  final bool locked;
  final bool needsDownload;
  final double? progress;
  final bool reduceMotion;
  final VoidCallback onTap;
  final ValueChanged<double> onVolume;

  bool get _on => volume != null;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final name = stemTitle(l, stem);
    final percent = ((volume ?? 0) * 100).round();
    final size = stem.file == null ? null : megabytes(l, stem.file!.bytes);
    final label = locked
        ? l.sounds_stemLocked(name)
        : progress != null
        ? l.sounds_stemDownloading(name)
        : needsDownload && size != null
        ? l.sounds_stemNeedsDownload(name, size)
        : !_on
        ? l.sounds_stemOff(name)
        : windDown || playing
        ? l.sounds_stemOn(name, percent)
        : l.sounds_stemPaused(name, percent);

    Widget trailing;
    if (locked) {
      trailing = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(color: AuraColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: AuraColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              l.sounds_plusBadge,
              style: t.labelSmall?.copyWith(color: AuraColors.textMuted),
            ),
          ],
        ),
      );
    } else if (progress != null) {
      trailing = SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: progress! > 0 ? progress : null,
        ),
      );
    } else if (needsDownload) {
      trailing = const Icon(
        Icons.download_rounded,
        color: AuraColors.textMuted,
      );
    } else if (_on) {
      final icon = Icon(
        (playing || windDown) ? Icons.graphic_eq_rounded : Icons.pause_rounded,
        color: AuraColors.lavender,
      );
      // A slow glow while it plays; still under Reduce Motion.
      trailing = (playing && !reduceMotion)
          ? icon
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(
                  begin: 0.5,
                  end: 1,
                  duration: const Duration(milliseconds: 1400),
                )
          : icon;
    } else {
      trailing = const Icon(
        Icons.add_circle_outline_rounded,
        color: AuraColors.textMuted,
      );
    }

    return Material(
      color: AuraColors.surface.withValues(alpha: _on ? 0.95 : 0.75),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        side: BorderSide(
          color: _on
              ? AuraColors.lavender.withValues(alpha: 0.45)
              : AuraColors.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Semantics(
            container: true,
            button: true,
            toggled: locked || needsDownload ? null : _on,
            label: label,
            onTap: onTap,
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('sounds-toggle-${stem.id}'),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.l,
                    vertical: AuraSpace.s,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        stemIcon(stem),
                        color: locked
                            ? AuraColors.textMuted
                            : AuraColors.lavender,
                      ),
                      const SizedBox(width: AuraSpace.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: t.titleMedium),
                            if (needsDownload && size != null && !locked)
                              Text(
                                size,
                                style: t.bodySmall?.copyWith(
                                  color: AuraColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s),
                      trailing,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_on && !windDown)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s,
                0,
                AuraSpace.s,
                AuraSpace.xs,
              ),
              child: Semantics(
                container: true,
                label: l.sounds_volume(name),
                child: Slider(
                  key: ValueKey('sounds-volume-${stem.id}'),
                  value: volume!,
                  divisions: 20,
                  onChanged: onVolume,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SavedMixRow extends StatelessWidget {
  const _SavedMixRow({
    required this.name,
    required this.onPlay,
    required this.onRemove,
  });

  final String name;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s),
      child: Material(
        color: AuraColors.surface.withValues(alpha: 0.75),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.m),
          side: const BorderSide(color: AuraColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                container: true,
                button: true,
                label: l.sounds_playMix(name),
                onTap: onPlay,
                excludeSemantics: true,
                child: InkWell(
                  onTap: onPlay,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpace.l,
                        vertical: AuraSpace.s,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.play_circle_outline_rounded,
                            color: AuraColors.lavender,
                          ),
                          const SizedBox(width: AuraSpace.m),
                          Expanded(child: Text(name, style: t.bodyLarge)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: l.sounds_removeMix(name),
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// Play / pause, stop and the timer. Wraps under large text rather than
/// overflowing.
class _TransportBar extends ConsumerWidget {
  const _TransportBar({required this.state, required this.onTimer});

  final SoundsState state;
  final VoidCallback onTimer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final controller = ref.read(soundsControllerProvider.notifier);
    final timer = state.timer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.m,
        AuraSpace.gutter,
        AuraSpace.m,
      ),
      decoration: BoxDecoration(
        color: AuraColors.skyHigh.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: AuraColors.hairline)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AuraSpace.s,
        runSpacing: AuraSpace.s,
        children: [
          if (state.isPlaying)
            FilledButton.icon(
              key: const ValueKey('sounds-pause'),
              onPressed: () {
                AuraHaptics.selection();
                controller.pause();
              },
              icon: const Icon(Icons.pause_rounded),
              label: Text(l.sounds_pause),
            )
          else
            FilledButton.icon(
              key: const ValueKey('sounds-play'),
              onPressed: () {
                AuraHaptics.selection();
                controller.play();
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l.sounds_play),
            ),
          OutlinedButton.icon(
            key: const ValueKey('sounds-stop'),
            onPressed: controller.stop,
            icon: const Icon(Icons.stop_rounded),
            label: Text(l.sounds_stop),
          ),
          if (!state.isWindDown)
            TextButton.icon(
              key: const ValueKey('sounds-timer'),
              onPressed: onTimer,
              icon: const Icon(Icons.timer_outlined),
              label: Text(
                l.sounds_timerValue(
                  timer == null
                      ? l.sounds_timerOff
                      : l.breathe_minutes(timer.inMinutes),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The picked timer (`length` null = off), so "off" differs from a
/// dismissed sheet.
class _TimerChoice {
  const _TimerChoice(this.length);

  final Duration? length;
}

class _TimerSheet extends StatelessWidget {
  const _TimerSheet({required this.current});

  final Duration? current;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    Widget option(Duration? length, String label) {
      final selected = length == current;
      return ListTile(
        key: ValueKey('sounds-timer-${length?.inMinutes ?? 0}'),
        title: Text(label),
        selected: selected,
        trailing: selected ? const Icon(Icons.check_rounded) : null,
        onTap: () => Navigator.of(context).pop(_TimerChoice(length)),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.l,
                vertical: AuraSpace.s,
              ),
              child: Semantics(
                header: true,
                child: Text(l.sounds_timerTitle, style: t.titleMedium),
              ),
            ),
            for (final d in soundsTimerChoices)
              option(d, l.breathe_minutes(d.inMinutes)),
            option(null, l.sounds_timerOff),
          ],
        ),
      ),
    );
  }
}
