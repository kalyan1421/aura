import 'dart:async';
import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/theme/aura_tokens.dart';
import '../avatar/aura_avatar.dart';
import '../avatar/avatar_assets.dart';
import 'room_copy.dart';
import 'room_models.dart';

/// Reads [message] to VoiceOver / TalkBack (REQ-A11Y-06: gestures sent and
/// received always have words).
void announceRoom(BuildContext context, String message) {
  final view = View.maybeOf(context);
  if (view == null) return;
  unawaited(
    SemanticsService.sendAnnouncement(
      view,
      message,
      Directionality.of(context),
    ),
  );
}

/// A member's silhouette: their Aura at its stage and (30°-bucketed) hue,
/// painted still (no ticker: a room can hold 24). Not a fingerprint: no
/// traits, rings or cosmetics. Dimmed when away or muted. Decorative: the
/// tile around it carries the words.
class RoomSilhouette extends ConsumerWidget {
  const RoomSilhouette({
    super.key,
    required this.silhouette,
    this.size = 56,
    this.dimmed = false,
  });

  final Silhouette silhouette;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(avatarAssetsProvider).value;
    final state = AuraAvatarState(
      stage: silhouette.stageValue,
      hue: silhouette.hue ?? AuraAvatarState.defaultHue,
    );
    return ExcludeSemantics(
      child: Opacity(
        opacity: dimmed ? 0.45 : 1,
        child: SizedBox.square(
          dimension: size,
          child: AuraAvatarView(
            state: state,
            assets: assets,
            size: Size.square(size),
            tier: AvatarTier.still,
            useShaders: false,
            fixedTime: 0,
          ),
        ),
      ),
    );
  }
}

/// A gesture preset: its icon over its name. At least 48 dp; the label
/// never truncates (it may wrap in the member sheet's grid). [width]: a
/// fixed width in grids; `null` hugs the label (the tray's scrolling row).
class GestureButton extends StatelessWidget {
  const GestureButton({
    super.key,
    required this.type,
    required this.onPressed,
    required this.hint,
    this.width,
  });

  final GestureType type;
  final VoidCallback? onPressed;

  /// Screen-reader hint: who it goes to.
  final String hint;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final enabled = onPressed != null;
    final name = gestureName(l, type);
    final child = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.m,
        vertical: AuraSpace.s,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            gestureIcon(type),
            size: 24,
            color: enabled ? AuraColors.starlight : AuraColors.textMuted,
          ),
          const SizedBox(height: AuraSpace.xs),
          Text(
            name,
            textAlign: TextAlign.center,
            softWrap: width != null,
            style: t.labelMedium?.copyWith(
              color: enabled ? AuraColors.text : AuraColors.textMuted,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: name,
      hint: hint,
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        child: Material(
          color: enabled
              ? AuraColors.surfaceHigh.withValues(alpha: 0.9)
              : AuraColors.surface.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.m),
            side: const BorderSide(color: AuraColors.outline),
          ),
          child: InkWell(
            key: ValueKey('gesture-${type.wire}'),
            borderRadius: BorderRadius.circular(AuraRadius.m),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64, minWidth: 72),
              child: Center(widthFactor: 1, heightFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small lantern, painted (Lantern Hour marker; never the help colour).
class LanternGlyph extends StatelessWidget {
  const LanternGlyph({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _LanternPainter(color ?? AuraColors.starlight),
    ),
  );
}

class _LanternPainter extends CustomPainter {
  _LanternPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.08)
      ..strokeCap = StrokeCap.round;
    // Handle, cap, glass body, base and the flame inside.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, w * 0.18), radius: w * 0.12),
      math.pi,
      math.pi,
      false,
      stroke,
    );
    canvas.drawLine(Offset(w * 0.32, w * 0.24), Offset(w * 0.68, w * 0.24), stroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.3, w * 0.26, w * 0.7, w * 0.82),
        Radius.circular(w * 0.1),
      ),
      stroke,
    );
    canvas.drawLine(Offset(w * 0.26, w * 0.9), Offset(w * 0.74, w * 0.9), stroke);
    final flame = Path()
      ..moveTo(w * 0.5, w * 0.38)
      ..quadraticBezierTo(w * 0.62, w * 0.56, w * 0.5, w * 0.68)
      ..quadraticBezierTo(w * 0.38, w * 0.56, w * 0.5, w * 0.38)
      ..close();
    canvas.drawPath(flame, Paint()..color = color.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_LanternPainter old) => old.color != color;
}

/// "Reconnecting…" (PRD States: realtime dropped). Announced once.
class ReconnectingChip extends StatelessWidget {
  const ReconnectingChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reduce = reduceMotionOf(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const ValueKey('room-reconnecting'),
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.m,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AuraColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(color: AuraColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 12,
              child: reduce
                  ? const Icon(
                      Icons.sync_rounded,
                      size: 12,
                      color: AuraColors.lavender,
                    )
                  : const CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: AuraColors.lavender,
                    ),
            ),
            const SizedBox(width: AuraSpace.s),
            Flexible(
              child: Text(
                l.rooms_reconnecting,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Lantern Hour glow behind a room: a warm starlight wash at the top
/// that breathes slowly (a 6 s swell, far below any flash threshold). Still
/// under Reduce Motion. Text never sits on it without a card.
class LanternGlow extends StatefulWidget {
  const LanternGlow({super.key});

  @override
  State<LanternGlow> createState() => _LanternGlowState();
}

class _LanternGlowState extends State<LanternGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
    value: 0.6,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _c.stop();
      _c.value = 0.6;
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
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => DecoratedBox(
          key: const ValueKey('room-lantern-glow'),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -1.05),
              radius: 1.1,
              colors: [
                AuraColors.starlight.withValues(alpha: 0.10 + 0.08 * _c.value),
                AuraColors.starlight.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
