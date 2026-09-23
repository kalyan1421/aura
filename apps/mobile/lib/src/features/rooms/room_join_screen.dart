import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/remote_config/remote_config_providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../../core/widgets/inline_notice.dart';
import '../account/deletion_pending.dart';
import '../checkin/quadrant_glyph.dart';
import 'room_guidelines.dart';
import 'room_navigation.dart';
import 'room_status.dart';
import 'rooms_providers.dart';
import 'rooms_repository.dart';

enum _Phase {
  starting,
  matching,
  failed,
  pool,
  poolNotified,
  noRequest,
  updateNeeded,
}

/// Finds a room for a saved check-in (`POST /v1/rooms/match`): "Finding
/// people who feel this way right now…", then the room replaces this
/// screen. Offline it says so and makes no call, then tries again by itself
/// on reconnect (REQ-ROOM-01). Hindi + Hinglish before that pool opens:
/// "Join an English room for now?".
///
/// Community guidelines (REQ-SAFE-04) are recorded on the server: the
/// sheet comes first when this phone has no record of them, and again
/// whenever the match answers `409 guidelines_required` (another phone, a
/// material change); agreeing records them (`POST
/// /v1/safety/guidelines/accept`) and the match is tried again. Leaving the
/// sheet never enters a room. Guidelines newer than this build's copy: "update
/// Aura".
class RoomJoinScreen extends ConsumerStatefulWidget {
  const RoomJoinScreen({super.key, required this.request});

  /// `null` when opened without a check-in (nothing to match).
  final RoomJoinRequest? request;

  @override
  ConsumerState<RoomJoinScreen> createState() => _RoomJoinScreenState();
}

class _RoomJoinScreenState extends ConsumerState<RoomJoinScreen> {
  _Phase _phase = _Phase.starting;
  RoomsFailure? _failure;

  /// Agreed to the guidelines on this screen (never asked twice here).
  bool _agreed = false;

  /// ... and the server has that on record.
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  Future<void> _start() async {
    if (!mounted) return;
    if (widget.request == null) {
      setState(() => _phase = _Phase.noRequest);
      return;
    }
    // The phone's flag only saves a round trip; the server decides.
    if (!await roomGuidelinesCached(ref.read(kvStoreProvider))) {
      if (!mounted || !await _agree()) return;
    }
    await _match();
  }

  /// The guidelines (once per visit), then the server's record of them.
  /// `false`: the person left them (this screen closes, no room), or the
  /// record didn't go through (the screen says why).
  Future<bool> _agree() async {
    if (!_agreed) {
      final agreed = await showRoomGuidelines(context);
      if (!mounted) return false;
      if (!agreed) {
        Navigator.of(context).maybePop();
        return false;
      }
      _agreed = true;
    }
    return _record();
  }

  Future<bool> _record() async {
    setState(() {
      _phase = _Phase.matching;
      _failure = null;
    });
    try {
      await ref
          .read(roomsRepositoryProvider)
          .acceptGuidelines(roomGuidelinesVersion);
      _recorded = true;
      await cacheRoomGuidelines(
        ref.read(kvStoreProvider),
        roomGuidelinesVersion,
      );
      return mounted;
    } on RoomsFailure catch (f) {
      if (!mounted) return false;
      setState(() {
        // Refused as too old: the server needs newer guidelines than this
        // build carries.
        _phase = f.kind == RoomsFailureKind.guidelinesRequired
            ? _Phase.updateNeeded
            : _Phase.failed;
        _failure = f;
      });
      return false;
    }
  }

  /// "Try again" and back-online: the guidelines' record first if that is
  /// what didn't go through, then the match.
  Future<void> _retry() async {
    if (_agreed && !_recorded && !await _record()) return;
    await _match();
  }

  /// `409 guidelines_required` from the match: the sheet, the record, the
  /// same match again (once per visit, never a loop).
  Future<void> _guidelinesRequired(
    RoomsFailure f, {
    required bool poolFallback,
  }) async {
    await forgetRoomGuidelines(ref.read(kvStoreProvider));
    if (!mounted) return;
    final version = f.guidelinesVersion ?? roomGuidelinesVersion;
    if (version > roomGuidelinesVersion || _recorded) {
      setState(() {
        _phase = version > roomGuidelinesVersion
            ? _Phase.updateNeeded
            : _Phase.failed;
        _failure = f;
      });
      return;
    }
    if (await _agree()) await _match(poolFallback: poolFallback);
  }

  Future<void> _match({bool poolFallback = false}) async {
    final request = widget.request;
    if (!mounted || request == null) return;
    // Remote flags (PRD 19 REQ-ADM-12): what the server has switched off is
    // known here already, so no call is made (the server refuses it anyway).
    final flags = ref.read(remoteFlagsProvider);
    if (!flags.roomsEnabled) {
      setState(() {
        _phase = _Phase.failed;
        _failure = const RoomsFailure(RoomsFailureKind.paused);
      });
      return;
    }
    final tag = ref.read(localeControllerProvider);
    if (!poolFallback &&
        !flags.roomsPoolHi &&
        (tag == 'hi' || tag == 'hi-Latn')) {
      setState(() {
        _phase = _Phase.pool;
        _failure = null;
      });
      return;
    }
    setState(() {
      _phase = _Phase.matching;
      _failure = null;
    });
    try {
      final result = await ref
          .read(roomsRepositoryProvider)
          .match(
            quadrant: request.quadrant,
            moodId: request.moodId,
            allowPoolFallback: poolFallback,
          );
      ref.invalidate(myRoomsProvider);
      if (!mounted) return;
      openRoom(context, result.detail.room.roomId, replace: true);
    } on RoomsFailure catch (f) {
      if (!mounted) return;
      if (f.kind == RoomsFailureKind.guidelinesRequired) {
        await _guidelinesRequired(f, poolFallback: poolFallback);
        return;
      }
      setState(() {
        _phase = f.kind == RoomsFailureKind.poolUnavailable
            ? _Phase.pool
            : _Phase.failed;
        _failure = f;
      });
    }
  }

  Future<void> _notifyWhenOpen() async {
    try {
      await ref.read(kvStoreProvider).set(roomsNotifyHiPoolKey, '1');
    } on Object catch (e) {
      debugPrint('rooms: notify flag (${e.runtimeType})');
    }
    if (mounted) setState(() => _phase = _Phase.poolNotified);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Offline → back online: try again by itself ("Retry on reconnect").
    ref.listen(connectivityProvider, (prev, next) {
      if (next.value == true &&
          prev?.value == false &&
          _phase == _Phase.failed &&
          (_failure?.isTransient ?? false)) {
        unawaited(_retry());
      }
    });
    final request = widget.request;
    return Scaffold(
      appBar: helpAppBar(context, title: l.rooms_joinTitle),
      body: CosmicBackground(
        tint: request == null ? null : AuraColors.quadrant(request.quadrant),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AuraSpace.gutter),
            children: [
              const SizedBox(height: AuraSpace.xl),
              switch (_phase) {
                _Phase.starting => const SizedBox.shrink(),
                _Phase.matching => _Finding(request: request!),
                _Phase.failed => _Failed(failure: _failure!, onRetry: _retry),
                _Phase.updateNeeded => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InlineNotice(
                      l.rooms_guidelinesUpdate,
                      key: const ValueKey('rooms-guidelines-update'),
                    ),
                    const SizedBox(height: AuraSpace.l),
                    FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(l.common_done),
                    ),
                  ],
                ),
                _Phase.pool => _PoolChoice(
                  onEnglish: () => unawaited(_match(poolFallback: true)),
                  onNotify: () => unawaited(_notifyWhenOpen()),
                  onClose: () => Navigator.of(context).maybePop(),
                ),
                _Phase.poolNotified => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InlineNotice(
                      l.rooms_poolNotifyDone,
                      key: const ValueKey('rooms-pool-notified'),
                    ),
                    const SizedBox(height: AuraSpace.l),
                    FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(l.common_done),
                    ),
                  ],
                ),
                _Phase.noRequest => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InlineNotice(l.rooms_noRequest),
                    const SizedBox(height: AuraSpace.l),
                    FilledButton(
                      onPressed: () => openRoomsTab(context),
                      child: Text(l.rooms_backToRooms),
                    ),
                  ],
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

/// "Finding people who feel this way right now…" with the quadrant's glyph
/// breathing softly (still under Reduce Motion).
class _Finding extends StatefulWidget {
  const _Finding({required this.request});

  final RoomJoinRequest request;

  @override
  State<_Finding> createState() => _FindingState();
}

class _FindingState extends State<_Finding>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final q = widget.request.quadrant;
    return Column(
      children: [
        ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AuraColors.quadrant(q)
                        .withValues(alpha: 0.18 + 0.14 * _c.value),
                    AuraColors.quadrant(q).withValues(alpha: 0),
                  ],
                ),
              ),
              child: child,
            ),
            child: Center(child: QuadrantGlyph(q, size: 40)),
          ),
        ),
        const SizedBox(height: AuraSpace.xl),
        Semantics(
          liveRegion: true,
          child: Text(
            l.rooms_finding,
            key: const ValueKey('rooms-finding'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _Failed extends ConsumerWidget {
  const _Failed({required this.failure, required this.onRetry});

  final RoomsFailure failure;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure.kind == RoomsFailureKind.deletionPending)
          const DeletionPendingCard()
        else
          RoomsFailureNotice(failure: failure, joining: true, onRetry: onRetry),
        if (failure.kind == RoomsFailureKind.joinLimit) ...[
          const SizedBox(height: AuraSpace.l),
          FilledButton(
            key: const ValueKey('rooms-see-yours'),
            onPressed: () => openRoomsTab(context),
            child: Text(l.rooms_seeYourRooms),
          ),
        ],
      ],
    );
  }
}

/// PRD States: "Hindi and Hinglish rooms are opening soon. Join an English
/// room for now?" → Join English room / Tell me when they open / close.
class _PoolChoice extends StatelessWidget {
  const _PoolChoice({
    required this.onEnglish,
    required this.onNotify,
    required this.onClose,
  });

  final VoidCallback onEnglish;
  final VoidCallback onNotify;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      key: const ValueKey('rooms-pool-choice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.rooms_poolUnavailable,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AuraSpace.l),
        FilledButton(
          key: const ValueKey('rooms-pool-english'),
          onPressed: onEnglish,
          child: Text(l.rooms_poolJoinEnglish),
        ),
        const SizedBox(height: AuraSpace.s),
        OutlinedButton(
          key: const ValueKey('rooms-pool-notify'),
          onPressed: onNotify,
          child: Text(l.rooms_poolNotify),
        ),
        const SizedBox(height: AuraSpace.s),
        TextButton(onPressed: onClose, child: Text(l.common_notNow)),
      ],
    );
  }
}
