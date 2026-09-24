import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/theme/aura_tokens.dart';
import 'room_models.dart';

/// Room lanterns and Tonight's intention (F5, Milestone B; contracts
/// §1.9). Both are room totals: nothing here can say who lit or held
/// anything, not even your own share. Procedural art only (no assets):
/// a painted lantern whose glow follows the room's level. Under Reduce
/// Motion everything is still (REQ-A11Y-16); nothing ever flashes
/// (REQ-A11Y-09: the flicker is a ≤ 0.5 Hz swell of a few percent).

/// The localized preset, or `null` for a key this build doesn't know (the
/// card is then hidden rather than showing a raw key).
String? intentionText(AppLocalizations l, String key) => switch (key) {
  'sleep_before_midnight' => l.rooms_intention_sleep_before_midnight,
  'gentle_with_myself' => l.rooms_intention_gentle_with_myself,
  'phone_down_10' => l.rooms_intention_phone_down_10,
  'water_before_bed' => l.rooms_intention_water_before_bed,
  'one_kind_thought' => l.rooms_intention_one_kind_thought,
  'slow_breaths' => l.rooms_intention_slow_breaths,
  _ => null,
};

/// The words under the lantern: an invitation, a glow, fully lit, or —
/// once the hour is over — the level it reached. Never "failed" or "almost".
String lanternLine(AppLocalizations l, RoomLantern lantern) {
  if (!lantern.active) return l.rooms_lanternKept;
  if (lantern.isFull) return l.rooms_lanternFull;
  return lantern.level == 0 ? l.rooms_lanternStart : l.rooms_lanternGlowing;
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: AuraColors.surface.withValues(alpha: 0.9),
  borderRadius: BorderRadius.circular(AuraRadius.l),
  border: Border.all(color: AuraColors.hairline),
);

/// "Tonight's lantern": the painted lantern, its level as small lights,
/// and one calm line. Read as "Tonight's lantern, 3 of 5 lights lit".
class RoomLanternCard extends StatelessWidget {
  const RoomLanternCard({super.key, required this.lantern});

  final RoomLantern lantern;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      key: const ValueKey('room-lantern-card'),
      container: true,
      label:
          '${l.rooms_lanternSemantic(lantern.level, lantern.maxLevel)}. '
          '${lanternLine(l, lantern)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AuraSpace.l),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            LanternLamp(
              level: lantern.level,
              maxLevel: lantern.maxLevel,
              live: lantern.active,
            ),
            const SizedBox(width: AuraSpace.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.rooms_lanternTitle, style: t.titleMedium),
                  const SizedBox(height: AuraSpace.xs),
                  Text(
                    lanternLine(l, lantern),
                    key: const ValueKey('room-lantern-line'),
                    style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                  ),
                  const SizedBox(height: AuraSpace.s),
                  _LevelLights(level: lantern.level, max: lantern.maxLevel),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The level as a row of small lights (a room total, like a moon phase:
/// no numbers on screen).
class _LevelLights extends StatelessWidget {
  const _LevelLights({required this.level, required this.max});

  final int level;
  final int max;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('room-lantern-lights'),
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < max; i++)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: AnimatedContainer(
            duration: reduceMotionOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 600),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < level
                  ? AuraColors.starlight
                  : AuraColors.starlight.withValues(alpha: 0.14),
              border: Border.all(
                color: AuraColors.starlight.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
    ],
  );
}

/// A painted paper lantern whose glow grows with [level]. While [live]
/// (Lantern Hour) the flame swells very slowly; still under Reduce Motion
/// and afterwards. A level rise eases in (never down: the room never
/// shows a lower level, controller `keepRoomTotals`).
class LanternLamp extends StatefulWidget {
  const LanternLamp({
    super.key,
    required this.level,
    required this.maxLevel,
    this.live = false,
    this.size = 64,
  });

  final int level;
  final int maxLevel;
  final bool live;
  final double size;

  @override
  State<LanternLamp> createState() => _LanternLampState();
}

class _LanternLampState extends State<LanternLamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
    value: 0.5,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LanternLamp old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (!widget.live || reduceMotionOf(context)) {
      _flicker
        ..stop()
        ..value = 0.5;
    } else if (!_flicker.isAnimating) {
      _flicker.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.maxLevel <= 0
        ? 0.0
        : (widget.level / widget.maxLevel).clamp(0.0, 1.0);
    final reduce = reduceMotionOf(context);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        key: const ValueKey('room-lantern-lamp'),
        tween: Tween(end: target),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, glow, _) => AnimatedBuilder(
          animation: _flicker,
          builder: (context, _) => CustomPaint(
            size: Size(widget.size, widget.size * 1.25),
            painter: LanternPainter(glow: glow, flicker: _flicker.value),
          ),
        ),
      ),
    );
  }
}

/// The lantern itself: a halo, a rounded paper body with ribs, cap, handle
/// and a flame. [glow] 0–1 (the room's level), [flicker] 0–1 (a gentle
/// ±4% swell, far below any flash threshold).
class LanternPainter extends CustomPainter {
  LanternPainter({required this.glow, this.flicker = 0.5});

  final double glow;
  final double flicker;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final cx = w / 2;
    final bodyTop = h * 0.2;
    final bodyBottom = h * 0.86;
    final bodyRect = Rect.fromLTRB(w * 0.18, bodyTop, w * 0.82, bodyBottom);
    final swell = 1 + (flicker - 0.5) * 0.08;
    final g = glow.clamp(0.0, 1.0);

    // Halo: grows with the level (a dim ember at level 0).
    final haloR = w * (0.45 + 0.35 * g) * swell;
    canvas.drawCircle(
      bodyRect.center,
      haloR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AuraColors.starlight.withValues(alpha: 0.10 + 0.40 * g),
            AuraColors.starlight.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: bodyRect.center, radius: haloR)),
    );

    // Paper body, lit from inside.
    final body = RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.3));
    canvas.drawRRect(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.2),
          colors: [
            Color.lerp(
              AuraColors.surfaceHigh,
              AuraColors.starlight,
              0.25 + 0.7 * g,
            )!,
            Color.lerp(AuraColors.surface, AuraColors.sunrise, 0.15 + 0.5 * g)!,
          ],
        ).createShader(bodyRect),
    );
    final line = Paint()
      ..color = AuraColors.starlight.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * 0.025);
    canvas.drawRRect(body, line);
    // Ribs.
    for (final f in [0.36, 0.5, 0.64]) {
      final x = w * f;
      final path = Path()
        ..moveTo(x, bodyTop + 2)
        ..quadraticBezierTo(
          cx + (x - cx) * 1.35,
          (bodyTop + bodyBottom) / 2,
          x,
          bodyBottom - 2,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = AuraColors.starlight.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, w * 0.015),
      );
    }
    // Cap, base and handle.
    final cap = Paint()..color = AuraColors.outline;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.34, bodyTop - h * 0.05, w * 0.66, bodyTop + 2),
        const Radius.circular(3),
      ),
      cap,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          w * 0.36,
          bodyBottom - 2,
          w * 0.64,
          bodyBottom + h * 0.05,
        ),
        const Radius.circular(3),
      ),
      cap,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, bodyTop - h * 0.05), radius: w * 0.14),
      math.pi,
      math.pi,
      false,
      line,
    );
    // Flame: taller with the level; a small ember at 0.
    final fh = h * (0.08 + 0.16 * g) * swell;
    final fy = bodyRect.center.dy + h * 0.1;
    final flame = Path()
      ..moveTo(cx, fy - fh)
      ..quadraticBezierTo(cx + w * 0.09, fy - fh * 0.3, cx, fy)
      ..quadraticBezierTo(cx - w * 0.09, fy - fh * 0.3, cx, fy - fh)
      ..close();
    canvas.drawPath(
      flame,
      Paint()..color = AuraColors.sunrise.withValues(alpha: 0.55 + 0.45 * g),
    );
  }

  @override
  bool shouldRepaint(LanternPainter old) =>
      old.glow != glow || old.flicker != flicker;
}

/// "Tonight's intention": the preset, one tap to hold it, and the room
/// total ("12 holding this tonight"). Never who holds it, no free text, no
/// follow-up. After the hour it stays read-only with the total.
class IntentionCard extends StatelessWidget {
  const IntentionCard({
    super.key,
    required this.intention,
    required this.text,
    required this.holding,
    required this.canHold,
    required this.onHold,
  });

  final RoomIntention intention;

  /// The localized preset.
  final String text;

  /// You hold it (only you see this).
  final bool holding;
  final bool canHold;
  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final total = intention.open
        ? l.rooms_intentionHolds(intention.holds)
        : l.rooms_intentionHeld(intention.holds);
    return Container(
      key: const ValueKey('room-intention-card'),
      padding: const EdgeInsets.all(AuraSpace.l),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(l.rooms_intentionTitle, style: t.labelLarge),
          ),
          const SizedBox(height: AuraSpace.s),
          Text(
            text,
            key: const ValueKey('room-intention-text'),
            style: t.titleMedium?.copyWith(color: AuraColors.starlight),
          ),
          const SizedBox(height: AuraSpace.s),
          Semantics(
            liveRegion: true,
            child: Text(
              total,
              key: const ValueKey('room-intention-total'),
              style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
            ),
          ),
          if (intention.open) ...[
            const SizedBox(height: AuraSpace.m),
            if (holding)
              Row(
                key: const ValueKey('room-intention-holding'),
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 20,
                    color: AuraColors.starlight,
                  ),
                  const SizedBox(width: AuraSpace.s),
                  Flexible(
                    child: Text(l.rooms_intentionHolding, style: t.bodyMedium),
                  ),
                ],
              )
            else
              OutlinedButton(
                key: const ValueKey('room-intention-hold'),
                onPressed: canHold ? onHold : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                child: Text(l.rooms_intentionHold),
              ),
            const SizedBox(height: AuraSpace.s),
            Text(
              l.rooms_intentionPrivate,
              style: t.bodySmall?.copyWith(color: AuraColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// The one shared moment when the room's lantern becomes fully lit:
/// small lanterns rise softly and fade (≈ 4 s). Under Reduce Motion it is
/// a still image of the lanterns with a line of text. Purely visual; the
/// room screen announces the line. [serial] 0 = nothing yet; each new
/// value plays once.
class LanternRiseLayer extends StatefulWidget {
  const LanternRiseLayer({super.key, required this.serial});

  final int serial;

  @override
  State<LanternRiseLayer> createState() => _LanternRiseLayerState();
}

class _LanternRiseLayerState extends State<LanternRiseLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  bool _showing = false;

  @override
  void didUpdateWidget(LanternRiseLayer old) {
    super.didUpdateWidget(old);
    if (widget.serial != old.serial && widget.serial > 0) _play();
  }

  void _play() {
    setState(() => _showing = true);
    _c
      ..reset()
      ..forward().whenComplete(() {
        if (mounted) setState(() => _showing = false);
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showing) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final reduce = reduceMotionOf(context);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            // Soft in and out; ≤ 300 ms fades under Reduce Motion.
            final fadeShare = reduce ? 300 / 4200 : 0.18;
            final opacity = v < fadeShare
                ? v / fadeShare
                : v > 1 - fadeShare
                ? (1 - v) / fadeShare
                : 1.0;
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Stack(
                key: ValueKey(
                  reduce ? 'room-lantern-rise-still' : 'room-lantern-rise',
                ),
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i < 7; i++)
                    _risingLantern(context, i, reduce ? 0.35 : v),
                  Align(
                    alignment: const Alignment(0, 0.35),
                    child: Padding(
                      padding: const EdgeInsets.all(AuraSpace.gutter),
                      child: Container(
                        key: const ValueKey('room-lantern-rise-line'),
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
                        child: Text(
                          l.rooms_lanternRise,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Lantern [i] of 7 at progress [v]: spread across the width, each a
  /// little slower, drifting up from the bottom.
  Widget _risingLantern(BuildContext context, int i, double v) {
    final x = -0.85 + i * (1.7 / 6);
    final speed = 0.75 + (i % 3) * 0.12;
    final start = 1.1 - (i.isEven ? 0 : 0.15);
    final y = start - 1.9 * (v * speed);
    return Align(
      alignment: Alignment(x, y),
      child: SizedBox(
        width: 26 + (i % 3) * 6,
        height: (26 + (i % 3) * 6) * 1.25,
        child: CustomPaint(painter: LanternPainter(glow: 1)),
      ),
    );
  }
}
