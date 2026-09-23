import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/haptics.dart';
import '../../core/a11y/motion.dart';
import '../../core/db/database.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../../core/widgets/inline_notice.dart';
import '../support/support_sheet.dart';
import '../voice/voice_note_field.dart' show VoicePlaybackRow;
import '../voice/voice_playback.dart';
import 'capsule_format.dart';
import 'capsule_media_loader.dart';
import 'capsule_payload.dart';
import 'capsule_providers.dart';
import 'capsule_repository.dart';

/// Opens capsule [id]: the ceremony, then its content. Resolves when the
/// person is done (the post-save order of a check-in waits for it). Above the
/// tab bar: the ceremony is full-screen from any tab.
Future<void> openCapsule(BuildContext context, String id) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => CapsuleOpeningScreen(id: id)),
    );

/// The in-app card after a check-in matched a trigger capsule (never a
/// push, PRD 12-notifications). [held]: the crisis collision rule — shown
/// after the support sheet, "A note from past you is waiting. Open now, or
/// later?". Returns true for "Now"; dismissing is "Later".
Future<bool> showCapsuleTriggerCard(
  BuildContext context, {
  required bool held,
}) async {
  final now = await showModalBottomSheet<bool>(
    context: context,
    // Over the navigation bar too: a modal never leaves the tabs tappable.
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => CapsuleTriggerCard(held: held),
  );
  return now ?? false;
}

class CapsuleTriggerCard extends StatelessWidget {
  const CapsuleTriggerCard({super.key, required this.held});

  final bool held;

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
              Icons.mark_email_unread_outlined,
              size: 40,
              color: AuraColors.starlight,
            ),
          ),
          const SizedBox(height: AuraSpace.l),
          Semantics(
            header: true,
            child: Text(
              held ? l.capsules_holdTitle : l.capsules_triggerTitle,
              key: ValueKey(
                held ? 'capsule-hold-title' : 'capsule-trigger-title',
              ),
              textAlign: TextAlign.center,
              style: t.titleLarge,
            ),
          ),
          const SizedBox(height: AuraSpace.xl),
          FilledButton(
            key: const ValueKey('capsule-now'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.capsules_now),
          ),
          const SizedBox(height: AuraSpace.s),
          TextButton(
            key: const ValueKey('capsule-later'),
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.capsules_later),
          ),
        ],
      ),
    );
  }
}

enum _Stage { loading, cantRead, gate, ceremony, open, sealed }

/// Opening a capsule (PRD F4): a hard-moment capsule first says "You wrote
/// this during a hard moment. Open when you're ready." with a help button;
/// then a skippable ~4 s ceremony (a still crossfade under Reduce Motion);
/// then the content. Opening is recorded as the content is revealed and is
/// one-way. A trigger capsule offers "Keep for next time".
class CapsuleOpeningScreen extends ConsumerStatefulWidget {
  const CapsuleOpeningScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<CapsuleOpeningScreen> createState() =>
      _CapsuleOpeningScreenState();
}

class _CapsuleOpeningScreenState extends ConsumerState<CapsuleOpeningScreen> {
  _Stage _stage = _Stage.loading;
  CapsuleRow? _row;
  CapsulePayload? _payload;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final repo = ref.read(capsuleRepositoryProvider);
    final row = await repo.row(widget.id);
    final payload = row == null ? null : await repo.payloadOf(row);
    if (!mounted) return;
    setState(() {
      _row = row;
      _payload = payload;
      if (row == null || row.deletedAt != null) {
        _stage = _Stage.sealed;
      } else if (payload == null) {
        _stage = _Stage.cantRead;
      } else if (row.openedAt != null) {
        _stage = _Stage.open; // read again: no ceremony
      } else if (payload.hardMoment) {
        _stage = _Stage.gate;
      } else {
        _stage = _Stage.ceremony;
      }
    });
    if (_stage == _Stage.ceremony) await _recordOpen();
  }

  /// One-way: the capsule is opened as its content is revealed.
  Future<void> _recordOpen() async {
    final repo = ref.read(capsuleRepositoryProvider);
    final sync = ref.read(syncControllerProvider);
    try {
      await repo.open(widget.id);
      sync.notifyLocalWrite();
    } on CapsuleNotOpenable {
      if (mounted) setState(() => _stage = _Stage.sealed);
    }
  }

  Future<void> _openFromGate() async {
    AuraHaptics.selection();
    setState(() => _stage = _Stage.ceremony);
    await _recordOpen();
  }

  void _ceremonyDone() {
    if (!mounted || _stage != _Stage.ceremony) return;
    setState(() => _stage = _Stage.open);
    final view = View.maybeOf(context);
    final title = _payload?.title.trim() ?? '';
    if (view != null && title.isNotEmpty) {
      unawaited(
        SemanticsService.sendAnnouncement(
          view,
          title,
          Directionality.of(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reduce = reduceMotionOf(context);
    final Widget body = switch (_stage) {
      _Stage.loading => const SizedBox.expand(key: ValueKey('capsule-loading')),
      _Stage.cantRead => _Message(
        key: const ValueKey('capsule-cant-read'),
        text: l.capsules_cantRead,
      ),
      _Stage.sealed => _Message(
        key: const ValueKey('capsule-still-sealed'),
        text: l.capsules_detailNoEarly,
      ),
      _Stage.gate => _HardMomentGate(
        key: const ValueKey('capsule-hard-moment'),
        onOpen: _openFromGate,
      ),
      _Stage.ceremony => CapsuleCeremony(
        key: const ValueKey('capsule-ceremony'),
        tint: ceremonyTintOf(_row),
        onDone: _ceremonyDone,
      ),
      _Stage.open => CapsuleOpenedView(
        key: const ValueKey('capsule-open'),
        row: _row!,
        payload: _payload!,
        showKeep: true,
        showDone: true,
      ),
    };
    return Scaffold(
      appBar: helpAppBar(context, title: l.capsules_title),
      body: CosmicBackground(
        tint: ceremonyTintOf(_row),
        child: AnimatedSwitcher(
          // Reduce Motion: a crossfade of at most 300 ms (REQ-A11Y-08).
          duration: reduce ? reducedMotionFade : AuraMotion.slow,
          child: body,
        ),
      ),
    );
  }
}

/// The ceremony's colour: the feeling a trigger capsule waited for, or
/// starlight for a date capsule.
Color ceremonyTintOf(CapsuleRow? row) {
  final target = row == null ? null : moodTargetOf(row);
  final q =
      target?.quadrant ??
      (target?.moodId == null ? null : moodById(target!.moodId!)?.quadrant);
  return q == null ? AuraColors.starlight : AuraColors.quadrant(q);
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AuraSpace.gutter),
      children: [
        const SizedBox(height: AuraSpace.xxl),
        InlineNotice(text, icon: Icons.lock_outline_rounded),
        const SizedBox(height: AuraSpace.l),
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l.common_close),
        ),
      ],
    );
  }
}

/// "You wrote this during a hard moment. Open when you're ready." with help
/// right there (PRD F4).
class _HardMomentGate extends StatelessWidget {
  const _HardMomentGate({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.xxl,
        AuraSpace.gutter,
        AuraSpace.xl,
      ),
      children: [
        const ExcludeSemantics(
          child: Icon(Icons.spa_outlined, size: 44, color: AuraColors.lavender),
        ),
        const SizedBox(height: AuraSpace.l),
        Semantics(
          header: true,
          child: Text(
            l.capsules_hardMoment,
            key: const ValueKey('capsule-hard-moment-text'),
            textAlign: TextAlign.center,
            style: t.titleLarge,
          ),
        ),
        const SizedBox(height: AuraSpace.xl),
        FilledButton(
          key: const ValueKey('capsule-open-now'),
          onPressed: onOpen,
          child: Text(l.capsules_readyOpen),
        ),
        const SizedBox(height: AuraSpace.s),
        TextButton(
          key: const ValueKey('capsule-not-now'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l.common_notNow),
        ),
        const SizedBox(height: AuraSpace.l),
        const Center(child: HelpNowButton()),
      ],
    );
  }
}

/// A short opening moment (~4 s, skippable): the seal gathers light, opens
/// in slow rings and fades into the note. Calm by design — brightness rises
/// once and falls once (no flashing, REQ-A11Y-09). Under Reduce Motion
/// nothing moves: it hands over at once and the screen crossfades
/// (REQ-A11Y-08).
class CapsuleCeremony extends StatefulWidget {
  const CapsuleCeremony({
    super.key,
    required this.onDone,
    this.tint = AuraColors.starlight,
    this.duration = defaultDuration,
  });

  final VoidCallback onDone;
  final Color tint;
  final Duration duration;

  static const Duration defaultDuration = Duration(seconds: 4);

  @override
  State<CapsuleCeremony> createState() => _CapsuleCeremonyState();
}

class _CapsuleCeremonyState extends State<CapsuleCeremony>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_onStatus);
  bool _done = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotionOf(context)) {
      // Still: no animation at all; the parent crossfades to the note.
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else {
      unawaited(_c.forward());
    }
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) _finish();
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reduce = reduceMotionOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            label: l.capsules_opening,
            liveRegion: true,
            container: true,
            child: RepaintBoundary(
              child: reduce
                  ? CustomPaint(
                      key: const ValueKey('capsule-ceremony-still'),
                      painter: _SealPainter(progress: 0, tint: widget.tint),
                    )
                  : AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) => CustomPaint(
                        painter: _SealPainter(
                          progress: _c.value,
                          tint: widget.tint,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AuraSpace.xl,
          child: SafeArea(
            top: false,
            child: Center(
              child: TextButton(
                key: const ValueKey('capsule-skip'),
                onPressed: () {
                  _c.stop();
                  _finish();
                },
                child: Text(l.capsules_skip),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The seal: an orb of the capsule's tint in a thin ring. [progress] 0…1:
/// gather light (to 0.45), open in three slow rings (to 0.8), fade (to 1).
class _SealPainter extends CustomPainter {
  _SealPainter({required this.progress, required this.tint});

  final double progress;
  final Color tint;

  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = math.min(size.width, size.height) * 0.14;
    final gather = Curves.easeInOut.transform(_seg(progress, 0, 0.45));
    final open = Curves.easeOut.transform(_seg(progress, 0.45, 0.8));
    final fade = 1 - Curves.easeIn.transform(_seg(progress, 0.8, 1));

    // Halo: grows once, fades once.
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          tint.withValues(alpha: (0.18 + 0.32 * gather) * fade),
          tint.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: base * (2.4 + open)));
    canvas.drawCircle(c, base * (2.4 + open), halo);

    // Rings leaving the seal, staggered, each fading as it widens.
    for (var i = 0; i < 3; i++) {
      final t = _seg(open, i * 0.15, 0.7 + i * 0.15);
      if (t <= 0) continue;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = tint.withValues(alpha: (1 - t) * 0.7 * fade);
      canvas.drawCircle(c, base * (1.1 + 2.2 * t), ring);
    }

    // The orb: warms towards starlight as it opens, then fades.
    final core = Color.lerp(tint, AuraColors.starlight, open)!;
    final orb = Paint()
      ..shader = RadialGradient(
        colors: [
          core.withValues(alpha: 0.95 * fade),
          tint.withValues(alpha: 0.55 * fade),
          tint.withValues(alpha: 0),
        ],
        stops: const [0, 0.65, 1],
      ).createShader(Rect.fromCircle(center: c, radius: base));
    canvas.drawCircle(c, base * (1 + 0.08 * gather - 0.2 * open), orb);

    // The seal's ring, until it opens.
    if (open < 1) {
      final seal = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AuraColors.starlight.withValues(
          alpha: (0.5 + 0.3 * gather) * (1 - open) * fade,
        );
      canvas.drawCircle(c, base * 1.12, seal);
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.progress != progress || old.tint != tint;
}

/// An opened capsule: its title, words, voice note and photos. Media load
/// lazily; offline, what's only on the server says it arrives later.
/// [showKeep]: "Keep for next time" on a trigger capsule; [showDone]: Done.
class CapsuleOpenedView extends ConsumerStatefulWidget {
  const CapsuleOpenedView({
    super.key,
    required this.row,
    required this.payload,
    this.showKeep = false,
    this.showDone = false,
    this.footer,
  });

  final CapsuleRow row;
  final CapsulePayload payload;
  final bool showKeep;
  final bool showDone;

  /// Extra controls under the content (e.g. Delete on the capsule's page).
  final Widget? footer;

  @override
  ConsumerState<CapsuleOpenedView> createState() => _CapsuleOpenedViewState();
}

class _CapsuleOpenedViewState extends ConsumerState<CapsuleOpenedView> {
  VoicePlaybackController? _voice;
  bool _voiceLocal = true;
  bool _rearming = false;
  bool _limit = false;

  @override
  void initState() {
    super.initState();
    final media = widget.payload.voice;
    if (media != null) {
      final loader = ref.read(capsuleMediaLoaderProvider);
      final store = ref.read(capsuleMediaStoreProvider);
      _voice = VoicePlaybackController(
        createPlayer: ref.read(voicePlayerFactoryProvider),
        load: () => loader.voice(widget.row.id),
        deleteTemp: store.deleteTemp,
        duration: media.durationMs == null
            ? null
            : Duration(milliseconds: media.durationMs!),
      );
      unawaited(_checkVoiceLocal());
    }
  }

  Future<void> _checkVoiceLocal() async {
    final media = await ref
        .read(capsuleRepositoryProvider)
        .mediaOf(widget.row.id);
    final local = media.any(
      (m) => m.slot == CapsuleSlots.voice && m.file != null,
    );
    if (mounted && local != _voiceLocal) setState(() => _voiceLocal = local);
  }

  @override
  void dispose() {
    _voice?.dispose();
    super.dispose();
  }

  Future<void> _keepForNextTime() async {
    if (_rearming) return;
    setState(() => _rearming = true);
    final repo = ref.read(capsuleRepositoryProvider);
    final sync = ref.read(syncControllerProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = AppLocalizations.of(context);
    try {
      await repo.rearm(widget.row.id);
      sync.notifyLocalWrite();
      messenger?.showSnackBar(SnackBar(content: Text(l.capsules_keptNextTime)));
      if (mounted) Navigator.of(context).maybePop();
    } on TriggerCapsuleLimitReached {
      if (mounted) setState(() => _limit = true);
    } on CapsuleNotOpenable {
      // Already re-armed or gone (another phone): nothing to do.
    } finally {
      if (mounted) setState(() => _rearming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tag = ref.watch(localeControllerProvider);
    final tz = ref.watch(deviceTimezoneProvider);
    final online = ref.watch(syncControllerProvider).online.value;
    final row = widget.row;
    final p = widget.payload;
    final photos = p.photos;
    final isTrigger = row.unlockType == CapsuleUnlockType.mood.name;
    final title = capsuleTitleOf(l, tag, row, p, tz);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.l,
        AuraSpace.gutter,
        AuraSpace.xxl,
      ),
      children: [
        Text(
          l.capsules_openedTitle,
          style: t.labelLarge?.copyWith(color: AuraColors.starlight),
        ),
        const SizedBox(height: AuraSpace.xs),
        Semantics(
          header: true,
          child: Text(
            title,
            key: const ValueKey('capsule-title'),
            style: t.headlineSmall,
          ),
        ),
        const SizedBox(height: AuraSpace.xs),
        Text(
          l.capsules_sealedOn(capsuleDayOf(tag, row.sealedAt, tz)),
          style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
        ),
        if (p.voice != null && !_voiceLocal && !online) ...[
          const SizedBox(height: AuraSpace.l),
          InlineNotice(
            l.capsules_voiceOffline,
            key: const ValueKey('capsule-voice-offline'),
            icon: Icons.cloud_off_outlined,
          ),
        ],
        if (p.text.trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.l),
          Container(
            padding: const EdgeInsets.all(AuraSpace.l),
            decoration: BoxDecoration(
              color: AuraColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AuraRadius.m),
              border: Border.all(color: AuraColors.outline),
            ),
            child: Text(
              p.text,
              key: const ValueKey('capsule-text'),
              style: t.bodyLarge?.copyWith(height: 1.55),
            ),
          ),
        ],
        if (_voice != null) ...[
          const SizedBox(height: AuraSpace.l),
          Container(
            padding: const EdgeInsets.all(AuraSpace.m),
            decoration: BoxDecoration(
              color: AuraColors.skyHigh,
              borderRadius: BorderRadius.circular(AuraRadius.m),
              border: Border.all(color: AuraColors.outline),
            ),
            child: VoicePlaybackRow(controller: _voice!),
          ),
        ],
        for (var i = 0; i < photos.length; i++) ...[
          const SizedBox(height: AuraSpace.l),
          _CapsulePhoto(
            capsuleId: row.id,
            media: photos[i],
            index: i + 1,
            count: photos.length,
          ),
        ],
        if (widget.showKeep || widget.showDone)
          const SizedBox(height: AuraSpace.xl),
        if (widget.showKeep && _limit) ...[
          InlineNotice(
            l.capsules_limitBody,
            key: const ValueKey('capsule-keep-limit'),
          ),
          const SizedBox(height: AuraSpace.s),
        ],
        if (widget.showKeep && isTrigger && row.deletedAt == null && !_limit)
          OutlinedButton.icon(
            key: const ValueKey('capsule-keep-next-time'),
            onPressed: _rearming ? null : _keepForNextTime,
            icon: const Icon(Icons.replay_rounded),
            label: Text(l.capsules_keepNextTime),
          ),
        if (widget.showDone) ...[
          const SizedBox(height: AuraSpace.s),
          FilledButton(
            key: const ValueKey('capsule-done'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l.common_done),
          ),
        ],
        ?widget.footer,
      ],
    );
  }
}

/// One photo, decrypted in memory when shown (downloaded first if it's
/// only on the server).
class _CapsulePhoto extends ConsumerStatefulWidget {
  const _CapsulePhoto({
    required this.capsuleId,
    required this.media,
    required this.index,
    required this.count,
  });

  final String capsuleId;
  final CapsuleMediaRef media;
  final int index;
  final int count;

  @override
  ConsumerState<_CapsulePhoto> createState() => _CapsulePhotoState();
}

class _CapsulePhotoState extends ConsumerState<_CapsulePhoto> {
  late Future<Uint8List> _bytes = _load();

  Future<Uint8List> _load() => ref
      .read(capsuleMediaLoaderProvider)
      .photo(widget.capsuleId, widget.media.slot);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = widget.media.width;
    final h = widget.media.height;
    final aspect = (w != null && h != null && w > 0 && h > 0) ? w / h : 4 / 3;
    return Semantics(
      image: true,
      label: l.capsules_photoSemantic(widget.index, widget.count),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        child: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (context, snap) {
            if (snap.hasData) {
              return Image.memory(
                snap.data!,
                key: ValueKey('capsule-photo-${widget.index}'),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              );
            }
            final offline =
                snap.error is CapsuleMediaUnavailable &&
                (snap.error! as CapsuleMediaUnavailable).offline;
            return AspectRatio(
              aspectRatio: aspect.clamp(0.5, 2.0),
              child: ColoredBox(
                color: AuraColors.skyHigh,
                child: Center(
                  child: snap.hasError
                      ? Padding(
                          padding: const EdgeInsets.all(AuraSpace.l),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                offline
                                    ? l.capsules_photosOffline
                                    : l.capsules_mediaFailed,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _bytes = _load()),
                                child: Text(l.capsules_retry),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
