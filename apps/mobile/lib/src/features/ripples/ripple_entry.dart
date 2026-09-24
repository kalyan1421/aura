import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import 'ripple_channel.dart';
import 'ripple_models.dart';
import 'ripple_screen.dart';
import 'ripples_providers.dart';

/// Home: quick-match with the one global queue (fresh pseudonym). Hidden
/// while Breath Ripples is switched off or rooms aren't usable here.
class RipplesHomeCard extends ConsumerWidget {
  const RipplesHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(ripplesReadyProvider)) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('ripples-home-card'),
      margin: const EdgeInsets.only(top: AuraSpace.m),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        onTap: () => openRipples(context),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.l),
          child: Row(
            children: [
              const Icon(Icons.waves_rounded, color: AuraColors.rain),
              const SizedBox(width: AuraSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.ripples_homeCard, style: t.titleMedium),
                    const SizedBox(height: AuraSpace.xs),
                    Text(
                      l.ripples_homeCardBody,
                      style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// In a room: "Breathe together" (opens or joins the room's invite, with the
/// room pseudonym) and the invite banner — "Quiet Comet wants to breathe
/// together · 2/4" — for the 20 s it is open (PRD 06b F7 "Room invite"; 12
/// "In-room banner only"). The banner listens on `ripples:<roomId>` (ids
/// only) and fetches the block-filtered invite from the server.
class RoomRippleEntry extends ConsumerStatefulWidget {
  const RoomRippleEntry({
    super.key,
    required this.roomId,
    this.readOnly = false,
  });

  final String roomId;

  /// A memory: no invites.
  final bool readOnly;

  @override
  ConsumerState<RoomRippleEntry> createState() => _RoomRippleEntryState();
}

class _RoomRippleEntryState extends ConsumerState<RoomRippleEntry> {
  RippleChannel? _channel;
  RippleInvite? _invite;
  Timer? _expiry;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    if (!widget.readOnly) {
      unawaited(_listen());
      unawaited(_fetch());
    }
  }

  Future<void> _listen() async {
    final open = ref.read(rippleChannelOpenerProvider);
    if (open == null) return;
    try {
      final ch = await open('ripples:${widget.roomId}');
      if (_disposed) {
        unawaited(ch.close());
        return;
      }
      _channel = ch;
      ch.onEvent((event, _) {
        if (event == 'ripple_invite' || event == 'ripple_invite_closed') {
          unawaited(_fetch());
        }
      });
      ch.subscribe((_) {});
    } on Object {
      // No banner; the button still works.
    }
  }

  Future<void> _fetch() async {
    final api = ref.read(ripplesApiProvider);
    if (api == null) return;
    try {
      final inv = await api.roomInvite(widget.roomId);
      if (_disposed) return;
      _expiry?.cancel();
      if (inv != null) {
        final left = inv.startsAtMs - DateTime.now().millisecondsSinceEpoch;
        _expiry = Timer(
          Duration(milliseconds: left.clamp(0, 30000)),
          () => mounted ? setState(() => _invite = null) : null,
        );
      }
      setState(() => _invite = inv);
    } on Object {
      // Keep what shows; the invite simply expires.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    final ch = _channel;
    if (ch != null) unawaited(ch.close());
    super.dispose();
  }

  void _open() =>
      openRipples(context, entry: RippleEntry.room, roomId: widget.roomId);

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly || !ref.watch(ripplesReadyProvider)) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final inv = _invite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (inv != null && !inv.mine)
          Semantics(
            liveRegion: true,
            container: true,
            child: Card(
              key: const ValueKey('ripple-invite-banner'),
              color: AuraColors.surfaceHigh,
              child: Padding(
                padding: const EdgeInsets.all(AuraSpace.m),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.ripples_invite(
                          inv.fromPseudonym,
                          inv.humans,
                          inv.capacity,
                        ),
                        style: t.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s),
                    FilledButton(
                      key: const ValueKey('ripple-invite-join'),
                      onPressed: _open,
                      child: Text(l.ripples_inviteJoin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        OutlinedButton.icon(
          key: const ValueKey('ripple-room-breathe'),
          onPressed: _open,
          icon: const Icon(Icons.waves_rounded),
          label: Text(l.ripples_breatheTogether),
        ),
      ],
    );
  }
}
