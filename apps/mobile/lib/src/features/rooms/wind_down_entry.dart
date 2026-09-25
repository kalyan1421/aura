import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/remote_config/remote_config_providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../ripples/ripple_engine.dart' show ServerClock;
import '../sanctuary/calm_route.dart';
import 'room_controller.dart';
import 'room_realtime.dart' show WindDownEvent;
import 'wind_down_api.dart';
import 'wind_down_screen.dart';

/// In a room during Lantern Hour, from 22:30 on the region clock: "Wind down
/// together" (PRD 06b "Lantern Hour wind-down (Milestone C)"; REQ-QUIET-07).
/// The room sees only "N winding down" (a room total, `wind_down` on the room
/// topic). Hidden in a memory, while the kill switch is off, or when this
/// build has no API.
class RoomWindDownEntry extends ConsumerStatefulWidget {
  const RoomWindDownEntry({
    super.key,
    required this.roomId,
    this.readOnly = false,
    this.wallMs,
  });

  final String roomId;
  final bool readOnly;

  /// The wall clock (tests pin it).
  final int Function()? wallMs;

  @override
  ConsumerState<RoomWindDownEntry> createState() => _RoomWindDownEntryState();
}

class _RoomWindDownEntryState extends ConsumerState<RoomWindDownEntry> {
  final ServerClock _clock = ServerClock();
  WindDownView? _view;
  StreamSubscription<WindDownEvent>? _events;
  Timer? _next;
  bool _busy = false;
  bool _failed = false;
  bool _disposed = false;

  int _wall() => widget.wallMs?.call() ?? DateTime.now().millisecondsSinceEpoch;

  bool get _enabled =>
      !widget.readOnly &&
      ref.read(windDownApiProvider) != null &&
      ref.read(remoteFlagsProvider).lanternWindDownEnabled;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    try {
      _events = ref
          .read(roomControllerProvider(widget.roomId).notifier)
          .windDownEvents
          .listen(_onEvent);
    } on Object {
      // No live count; the fetch and the schedule still work.
    }
    unawaited(_fetch());
  }

  void _onEvent(WindDownEvent e) {
    if (_disposed) return;
    if (e.state == 'ended') {
      setState(() => _view = null);
      return;
    }
    final v = _view;
    if (v == null || v.state != e.state) {
      unawaited(_fetch());
    } else {
      setState(() => _view = v.copyWith(count: e.count));
    }
  }

  Future<void> _fetch() async {
    final api = ref.read(windDownApiProvider);
    if (api == null) return;
    try {
      final sent = _wall();
      final r = await api.get(widget.roomId);
      if (_disposed) return;
      _clock.sample(
        sentMs: sent,
        receivedMs: _wall(),
        serverMs: r.serverTimeMs,
      );
      setState(() => _view = r.view);
      _schedule();
    } on Object {
      // Nothing shows; the next hint or the schedule tries again.
    }
  }

  /// Opens at 22:30 and ends at 22:50 on the region clock, even if the hint
  /// is late.
  void _schedule() {
    _next?.cancel();
    final v = _view;
    if (v == null) return;
    final now = _clock.toServer(_wall());
    final at = v.isOpen ? v.endsAtMs : v.startsAtMs;
    _next = Timer(
      Duration(milliseconds: (at - now + 500).clamp(0, 1 << 31)),
      () {
        if (_disposed) return;
        if (v.isOpen) {
          setState(() => _view = null);
        } else {
          unawaited(_fetch());
        }
      },
    );
  }

  Future<void> _open() async {
    final api = ref.read(windDownApiProvider);
    final v = _view;
    if (api == null || v == null || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final sent = _wall();
      final r = await api.join(widget.roomId);
      if (_disposed) return;
      _clock.sample(
        sentMs: sent,
        receivedMs: _wall(),
        serverMs: r.serverTimeMs,
      );
      final joined = r.view;
      setState(() {
        _busy = false;
        _view = joined;
      });
      if (joined == null || !mounted) return;
      await pushCalm<void>(
        context,
        (_) => WindDownScreen(
          roomId: widget.roomId,
          view: joined,
          clock: _clock,
          wallMs: widget.wallMs,
        ),
      );
      if (!_disposed) unawaited(_fetch());
    } on Object {
      if (!_disposed) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _next?.cancel();
    unawaited(_events?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _view;
    if (!_enabled || v == null || !v.isOpen) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('wind-down-card'),
      margin: const EdgeInsets.only(top: AuraSpace.m),
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
            child: Text(l.rooms_windDownTitle, style: t.titleMedium),
          ),
          const SizedBox(height: AuraSpace.xs),
          Text(
            l.rooms_windDownBody,
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.s),
          Semantics(
            liveRegion: true,
            child: Text(
              l.rooms_windDownCount(v.count),
              key: const ValueKey('wind-down-count'),
              style: t.bodyMedium?.copyWith(color: AuraColors.starlight),
            ),
          ),
          const SizedBox(height: AuraSpace.m),
          FilledButton(
            key: const ValueKey('wind-down-join'),
            onPressed: _busy ? null : _open,
            child: Text(
              v.joined ? l.rooms_windDownBack : l.rooms_windDownTitle,
            ),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: AuraSpace.s),
              child: Text(l.rooms_windDownFailed, style: t.bodySmall),
            ),
        ],
      ),
    );
  }
}
