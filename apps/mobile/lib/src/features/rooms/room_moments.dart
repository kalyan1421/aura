import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/theme/aura_tokens.dart';
import 'room_controller.dart';
import 'room_copy.dart';

/// The words for a gesture moment: what is announced (REQ-A11Y-06) and
/// shown on the banner.
String momentText(AppLocalizations l, GestureMoment m) {
  final name = gestureName(l, m.type);
  return switch (m.kind) {
    GestureMomentKind.sent =>
      m.toRoom || m.pseudonym == null
          ? l.rooms_sentToRoom(name)
          : l.rooms_sentToMember(name, m.pseudonym!),
    GestureMomentKind.received => l.rooms_receivedLine(m.pseudonym ?? '', name),
    GestureMomentKind.room =>
      m.toRoom ? l.rooms_someoneSentRoom(name) : l.rooms_someoneSent(name),
  };
}

/// Plays gesture moments over the room: the gesture's glyph rises softly
/// from the tray and fades (under Reduce Motion it only fades in place, in
/// ≤ 300 ms steps). A gesture sent to you also shows a named banner for
/// 5 s ("Quiet Comet sent you Warm Tea"); others' gestures stay unnamed.
/// Purely visual: the words are announced by the room screen.
class RoomMomentLayer extends StatelessWidget {
  const RoomMomentLayer({super.key, required this.moments, required this.onDone});

  final List<GestureMoment> moments;
  final ValueChanged<GestureMoment> onDone;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final m in moments)
            _MomentView(
              key: ValueKey('moment-${m.serial}'),
              moment: m,
              onDone: () => onDone(m),
            ),
        ],
      ),
    ),
  );
}

class _MomentView extends StatefulWidget {
  const _MomentView({super.key, required this.moment, required this.onDone});

  final GestureMoment moment;
  final VoidCallback onDone;

  @override
  State<_MomentView> createState() => _MomentViewState();
}

class _MomentViewState extends State<_MomentView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final bool _reduce;

  bool get _named => widget.moment.kind == GestureMomentKind.received;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.duration != null) return;
    _reduce = reduceMotionOf(context);
    // A named banner stays 5 s (information, REQ-A11Y-12 / design system);
    // a glyph alone is 2.2 s (1.6 s still).
    _c.duration = _named
        ? const Duration(seconds: 5)
        : _reduce
        ? const Duration(milliseconds: 1600)
        : const Duration(milliseconds: 2200);
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// In over the first [fadeIn] share, out over the last [fadeOut] share.
  double _opacity(double t, double fadeIn, double fadeOut) {
    if (t < fadeIn) return t / fadeIn;
    if (t > 1 - fadeOut) return ((1 - t) / fadeOut).clamp(0.0, 1.0);
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final m = widget.moment;
    final ms = _c.duration!.inMilliseconds;
    // ≤ 300 ms fades under Reduce Motion (REQ-A11Y-08).
    final fade = (_reduce ? 300 : 420) / ms;
    final glyphShare = _named ? 2200 / ms : 1.0;
    final small = m.kind == GestureMomentKind.room;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final glyphT = (v / glyphShare).clamp(0.0, 1.0);
        final glyphOpacity = v > glyphShare
            ? 0.0
            : _opacity(glyphT, fade / glyphShare, 0.3);
        final rise = _reduce ? 0.0 : 150 * Curves.easeOutCubic.transform(glyphT);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (m.animate)
              Align(
                alignment: const Alignment(0, 0.72),
                child: Transform.translate(
                  offset: Offset(0, -rise),
                  child: Opacity(
                    opacity: glyphOpacity * (small ? 0.75 : 1),
                    child: Container(
                      width: small ? 52 : 68,
                      height: small ? 52 : 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AuraColors.starlight.withValues(alpha: 0.35),
                            AuraColors.starlight.withValues(alpha: 0),
                          ],
                        ),
                      ),
                      child: Icon(
                        gestureIcon(m.type),
                        size: small ? 26 : 34,
                        color: AuraColors.starlight,
                      ),
                    ),
                  ),
                ),
              ),
            if (_named)
              Align(
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: _opacity(v, fade, fade),
                  child: Padding(
                    padding: const EdgeInsets.all(AuraSpace.gutter),
                    child: Container(
                      key: const ValueKey('room-received-banner'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpace.l,
                        vertical: AuraSpace.m,
                      ),
                      decoration: BoxDecoration(
                        color: AuraColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(AuraRadius.m),
                        border: Border.all(
                          color: AuraColors.starlight.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            gestureIcon(m.type),
                            size: 20,
                            color: AuraColors.starlight,
                          ),
                          const SizedBox(width: AuraSpace.s),
                          Flexible(
                            child: Text(
                              momentText(l, m),
                              style: t.bodyMedium?.copyWith(
                                color: AuraColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
