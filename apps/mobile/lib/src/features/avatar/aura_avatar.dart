import 'dart:ui' show FramePhase;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/perf/device_profile.dart';
import 'aura_avatar_painter.dart';
import 'avatar_assets.dart';

export 'aura_avatar_painter.dart' show AvatarTier;

/// The avatar as used in the app: loads the shared assets and renders
/// [AuraAvatarView]. While assets load, the glow alone shows (never blank).
class AuraAvatar extends ConsumerWidget {
  const AuraAvatar({
    super.key,
    required this.state,
    this.size = const Size.square(300),
    this.tier,
    this.useShaders = true,
    this.moment,
    this.onMomentDone,
  });

  final AuraAvatarState state;
  final Size size;
  final AvatarTier? tier;
  final bool useShaders;
  final AvatarMoment? moment;
  final ValueChanged<AvatarMoment>? onMomentDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(avatarAssetsProvider).value;
    return AuraAvatarView(
      state: state,
      assets: assets,
      size: size,
      tier: tier,
      useShaders: useShaders,
      moment: moment,
      onMomentDone: onMomentDone,
    );
  }
}

/// Renderer widget: a pure function of [state] + elapsed time.
class AuraAvatarView extends StatefulWidget {
  const AuraAvatarView({
    super.key,
    required this.state,
    required this.assets,
    this.size = const Size.square(300),
    this.tier,
    this.useShaders = true,
    this.moment,
    this.onMomentDone,
    this.fixedTime,
  });

  final AuraAvatarState state;
  final AvatarAssets? assets;
  final Size size;

  /// Forces a tier; otherwise High, Low when frames run over budget, and
  /// Still under Reduce Motion.
  final AvatarTier? tier;
  final bool useShaders;
  final AvatarMoment? moment;
  final ValueChanged<AvatarMoment>? onMomentDone;

  /// Freezes time (goldens, share cards).
  final double? fixedTime;

  @override
  State<AuraAvatarView> createState() => _AuraAvatarViewState();
}

class _AuraAvatarViewState extends State<AuraAvatarView>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<double> _time = ValueNotifier(widget.fixedTime ?? 0);
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  AvatarTier _tier = AvatarTier.high;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    FrameBudget.instance.ensureStarted();
    FrameBudget.instance.overBudget.addListener(_onBudget);
    DeviceProfile.instance.prefersLowTier.addListener(_onBudget);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _resolveTier();
  }

  @override
  void didUpdateWidget(AuraAvatarView old) {
    super.didUpdateWidget(old);
    if (old.tier != widget.tier || old.fixedTime != widget.fixedTime) {
      if (widget.fixedTime != null) _time.value = widget.fixedTime!;
      _resolveTier();
    }
  }

  void _onBudget() => setState(_resolveTier);

  void _resolveTier() {
    final forced = widget.tier;
    final AvatarTier next;
    if (_reduceMotion) {
      next = AvatarTier.still;
    } else if (forced != null) {
      next = forced;
    } else {
      // Low: frames over budget, or (at launch / on resume) a ≤ 3 GB Android
      // or battery saver (PRD F2 tiers, REQ-AVA-07).
      next =
          FrameBudget.instance.overBudget.value ||
              DeviceProfile.instance.prefersLowTier.value
          ? AvatarTier.low
          : AvatarTier.high;
    }
    _tier = next;
    // Still: one frame, except a slow glow under Reduce Motion.
    final animate =
        widget.fixedTime == null && (next != AvatarTier.still || _reduceMotion);
    if (animate) {
      _ticker ??= createTicker(_onTick);
      if (!_ticker!.isActive) _ticker!.start();
    } else {
      _ticker?.stop();
    }
  }

  void _onTick(Duration elapsed) {
    // Low tier idles at ~30 fps; Still (Reduce Motion) at ~10 fps.
    final minStep = switch (_tier) {
      AvatarTier.high => Duration.zero,
      AvatarTier.low => const Duration(milliseconds: 33),
      AvatarTier.still => const Duration(milliseconds: 100),
    };
    if (elapsed - _lastTick < minStep) return;
    _lastTick = elapsed;
    _time.value = elapsed.inMicroseconds / 1e6;
  }

  @override
  void dispose() {
    FrameBudget.instance.overBudget.removeListener(_onBudget);
    DeviceProfile.instance.prefersLowTier.removeListener(_onBudget);
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  CustomPaint _paint({double evolve = 1, double wake = 1}) => CustomPaint(
    size: widget.size,
    isComplex: true,
    painter: AuraAvatarPainter(
      state: widget.state,
      time: _time,
      assets: widget.assets,
      // Under Reduce Motion the painter still gets Still-tier geometry; only
      // the glow breathes (ticker at 10 fps).
      tier: _tier,
      useShaders: widget.useShaders,
      evolve: evolve,
      wake: wake,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget child = RepaintBoundary(child: _paint());

    final m = widget.moment;
    if (m != null) {
      final quick = _reduceMotion;
      child = GestureDetector(
        // Moments are skippable.
        onTap: () => widget.onMomentDone?.call(m),
        child: Animate(
          key: ValueKey(m.id),
          onComplete: (_) => widget.onMomentDone?.call(m),
          effects: switch (m.kind) {
            AvatarMomentKind.evolve => [
              CustomEffect(
                duration: quick ? 300.ms : 1800.ms,
                builder: (context, v, _) =>
                    RepaintBoundary(child: _paint(evolve: v)),
              ),
              if (!quick)
                const ScaleEffect(
                  begin: Offset(0.92, 0.92),
                  end: Offset(1, 1),
                  duration: Duration(milliseconds: 900),
                  curve: Curves.easeOutBack,
                ),
            ],
            AvatarMomentKind.wakeUp || AvatarMomentKind.celebrate => [
              CustomEffect(
                duration: quick ? 300.ms : 3200.ms,
                curve: Curves.easeInOut,
                builder: (context, v, _) =>
                    RepaintBoundary(child: _paint(wake: v)),
              ),
            ],
          },
          child: child,
        ),
      );
    }

    return Semantics(
      label: avatarSemanticLabel(l, widget.state),
      image: true,
      liveRegion: m != null,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// "Your Aura, Glow stage, violet glow, resting in a soft nebula, …"
/// (REQ-A11Y-05). Particles and shader layers stay out of the tree.
String avatarSemanticLabel(AppLocalizations l, AuraAvatarState s) {
  final parts = <String>[
    l.avatar_semantic(stageName(l, s.stage), hueName(l, s.hue)),
    if (s.isResting) l.avatar_semanticResting,
    if (s.ringCount > 0) l.avatar_semanticRings(s.ringCount),
    if (s.constellationStars > 0) l.avatar_semanticStars(s.constellationStars),
  ];
  return parts.join(', ');
}

String stageName(AppLocalizations l, AuraStage s) => switch (s) {
  AuraStage.spark => l.stage_spark,
  AuraStage.ember => l.stage_ember,
  AuraStage.glow => l.stage_glow,
  AuraStage.radiance => l.stage_radiance,
  AuraStage.constellation => l.stage_constellation,
};

String hueName(AppLocalizations l, double hue) {
  final h = hue % 360;
  if (h < 20 || h >= 330) return l.hue_rose;
  if (h < 75) return l.hue_gold;
  if (h < 150) return l.hue_green;
  if (h < 192) return l.hue_teal;
  if (h < 240) return l.hue_silverBlue;
  return l.hue_violet;
}

/// Watches frame timings; if frames run over budget for ~2 s the avatar
/// drops to the Low tier for the rest of the session (PRD F2 tiers). The
/// launch-time rule (≤ 3 GB Android, battery saver) is [DeviceProfile].
class FrameBudget {
  FrameBudget._();

  static final FrameBudget instance = FrameBudget._();

  final ValueNotifier<bool> overBudget = ValueNotifier(false);
  final List<(int, bool)> _window = [];
  bool _started = false;

  static const int _budgetMicros = 25000; // 1.5 × a 60 fps frame

  void ensureStarted() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (overBudget.value) return;
    for (final t in timings) {
      final end = t.timestampInMicroseconds(FramePhase.rasterFinish);
      _window.add((end, t.totalSpan.inMicroseconds > _budgetMicros));
    }
    if (_window.isEmpty) return;
    final cutoff = _window.last.$1 - 2000000;
    _window.removeWhere((e) => e.$1 < cutoff);
    if (_window.length < 30) return;
    final slow = _window.where((e) => e.$2).length;
    if (slow / _window.length > 0.5) {
      overBudget.value = true;
      debugPrint('avatar: frames over budget, switching to Low tier');
    }
  }

  @visibleForTesting
  void reset() {
    overBudget.value = false;
    _window.clear();
  }
}
