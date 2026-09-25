import 'dart:async';
import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/icon_scale.dart';
import '../../core/a11y/motion.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aura_tokens.dart';
import '../checkin/quadrant_glyph.dart' show habitLabel;
import '../safety/helpline_list.dart';
import '../sanctuary/habit_auto_complete.dart';
import '../safety/safety_center_screen.dart';
import '../insights/look_back.dart' show recordLookBackHelp;
import '../plus/paywall_gate.dart' show markCrisisFlow;
import 'crisis_follow_up.dart';

/// Opens the support sheet: contextual help that keeps the task underneath
/// (a crisis-lexicon hit after saving, a custom habit name). "I need help
/// now" opens the Safety Center instead ([openSafetyCenter]). Works offline
/// from bundled data, with no login. Shown over everything, the navigation
/// bar included.
Future<void> showSupportSheet(
  BuildContext context, {
  bool crisis = false,
  SupportOrigin origin = SupportOrigin.checkIn,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => SupportSheet(crisis: crisis, origin: origin),
  );
}

/// What was just saved when a crisis-lexicon hit opened the sheet: its
/// reassurance line and the way back name it ("Your capsule is sealed.").
enum SupportOrigin {
  checkIn,
  capsule,

  /// A reflection that was crisis-diverted (F6): never published, no
  /// rejection wording, "Back to the room".
  reflection,
}

/// Opens the Safety Center (`/safety`), a full route above everything, from
/// any screen and gate state. Outside the app's router (a bare navigator)
/// the same screen is pushed directly. Never opens a second copy on top of
/// itself.
void openSafetyCenter(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SafetyCenterScreen()),
      ),
    );
    return;
  }
  final open = router.routerDelegate.currentConfiguration;
  if (open.isNotEmpty && router.state.matchedLocation == Routes.safety) {
    return;
  }
  unawaited(router.push<void>(Routes.safety));
}

/// "I need help now" — always visible (Home, and every screen where it
/// normally appears). Warm lantern tone, never alarm red. Opens the Safety
/// Center ([openSafetyCenter]).
///
/// A pill while the label fits on one line. The [compact] (top bar) button
/// never wraps: above [largeText] text scale, or where its one-line label
/// does not fit the space it is given (a longer language, a narrow bar), it
/// collapses to a heart-only round button of at least 48 dp whose label
/// stays in its tooltip and screen-reader label. The full-size button (in
/// content) may wrap; it then becomes a rounded rectangle
/// ([AuraRadius.m]), never a near-circle that clips its label.
class HelpNowButton extends StatelessWidget {
  const HelpNowButton({
    super.key,
    this.compact = false,
    this.onOpen,
    this.iconOnly,
  });

  final bool compact;

  /// Called just before the Safety Center opens, e.g. to pause a breathing
  /// pacer underneath (REQ-SAN-08).
  final VoidCallback? onOpen;

  /// Heart only (true), the labelled pill (false), or, when null, decided
  /// here: [compact] buttons collapse above [largeText] or when the label
  /// does not fit on one line in the width they are given.
  final bool? iconOnly;

  /// The heart-only button's key (tests, screenshots).
  static const Key iconOnlyKey = ValueKey('help-now-icon-only');

  static const double _iconSize = 18;
  static const double _iconOnlySize = 22;
  static const double _minHeight = 44; // 48 dp tap target (padded)
  static const double _vPad = 10;

  /// Above this text scale a compact button is heart-only.
  static const double largeText = 1.3;

  static bool _isLarge(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(100) / 100 > largeText;

  static double _hPad(BuildContext context, {required bool compact}) {
    final large =
        MediaQuery.textScalerOf(context).scale(100) / 100 >= largeText;
    return compact ? (large ? 16 : 12) : (large ? 20 : 16);
  }

  static TextStyle? _labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge;

  /// The width of the heart-only button (its padded tap target).
  static const double iconOnlyWidth = kMinInteractiveDimension;

  /// Whether a [compact] button collapses to the heart at this context's
  /// text scale, before any width check.
  static bool iconOnlyForTextScale(BuildContext context) => _isLarge(context);

  /// The width this button needs to keep its label on one line, so a top
  /// bar can decide what else still fits beside it.
  static double oneLineWidth(BuildContext context, {bool compact = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: AppLocalizations.of(context).help_button,
        style: _labelStyle(context),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final label = painter.width;
    painter.dispose();
    // Label, icon and its gap, side padding and the 1 dp border.
    return label +
        scaledIconSize(context, _iconSize) +
        AuraSpace.s +
        2 * _hPad(context, compact: compact) +
        2;
  }

  void _open(BuildContext context) {
    onOpen?.call();
    openSafetyCenter(context);
  }

  @override
  Widget build(BuildContext context) {
    final forced = iconOnly;
    if (forced != null) {
      return forced ? _heart(context) : _pill(context);
    }
    if (!compact) return _pill(context);
    if (_isLarge(context)) return _heart(context);
    return LayoutBuilder(
      builder: (context, box) =>
          box.maxWidth.isFinite &&
              box.maxWidth < oneLineWidth(context, compact: true)
          ? _heart(context)
          : _pill(context),
    );
  }

  /// Heart only: the label lives in the tooltip and the screen-reader label.
  Widget _heart(BuildContext context) {
    final l = AppLocalizations.of(context);
    return MergeSemantics(
      child: Semantics(
        sortKey: const OrdinalSortKey(1),
        label: l.help_button,
        button: true,
        child: Tooltip(
          message: l.help_button,
          excludeFromSemantics: true,
          child: OutlinedButton(
            key: iconOnlyKey,
            onPressed: () => _open(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AuraColors.lantern,
              side: BorderSide(
                color: AuraColors.lantern.withValues(alpha: 0.6),
              ),
              backgroundColor: AuraColors.lantern.withValues(alpha: 0.08),
              minimumSize: const Size.square(_minHeight),
              padding: const EdgeInsets.all(AuraSpace.s),
              shape: const CircleBorder(),
            ),
            child: Icon(
              Icons.favorite_rounded,
              size: scaledIconSize(context, _iconOnlySize),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context) {
    final l = AppLocalizations.of(context);
    final style = _labelStyle(context);
    final line =
        MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 14) *
        (style?.height ?? 1.4);
    // One line (with a little slack) is a pill; anything taller has wrapped.
    final pillUpTo = math.max(_minHeight, line + 2 * _vPad) + line / 2;
    // One node: the button's own label, flag and tap action plus the early
    // sort key (REQ-A11Y-11). A bare `button: true` wrapper here used to add
    // an empty, action-less "button" stop before the real one.
    return MergeSemantics(
      child: Semantics(
        sortKey: const OrdinalSortKey(1),
        child: OutlinedButton.icon(
          onPressed: () => _open(context),
          icon: Icon(
            Icons.favorite_rounded,
            size: scaledIconSize(context, _iconSize),
          ),
          // Wrapped lines hug the longest one, so the button stays compact.
          label: Text(
            l.help_button,
            softWrap: !compact,
            maxLines: compact ? 1 : null,
            textWidthBasis: TextWidthBasis.longestLine,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AuraColors.lantern,
            side: BorderSide(color: AuraColors.lantern.withValues(alpha: 0.6)),
            backgroundColor: AuraColors.lantern.withValues(alpha: 0.08),
            minimumSize: const Size(48, _minHeight),
            padding: EdgeInsets.symmetric(
              horizontal: _hPad(context, compact: compact),
              vertical: _vPad,
            ),
            textStyle: style,
            shape: _HelpShape(pillUpTo: pillUpTo),
          ),
        ),
      ),
    );
  }
}

/// A pill up to [pillUpTo] dp tall; a rounded rectangle ([AuraRadius.m])
/// once the label has wrapped.
class _HelpShape extends OutlinedBorder {
  const _HelpShape({super.side, required this.pillUpTo});

  final double pillUpTo;

  RoundedRectangleBorder _at(Rect rect) => RoundedRectangleBorder(
    side: side,
    borderRadius: BorderRadius.circular(
      rect.height <= pillUpTo ? rect.shortestSide / 2 : AuraRadius.m,
    ),
  );

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  ShapeBorder scale(double t) =>
      _HelpShape(side: side.scale(t), pillUpTo: pillUpTo * t);

  @override
  _HelpShape copyWith({BorderSide? side}) =>
      _HelpShape(side: side ?? this.side, pillUpTo: pillUpTo);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _at(rect).getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _at(rect).getOuterPath(rect, textDirection: textDirection);

  @override
  bool get preferPaintInterior => true;

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) =>
      _at(rect)
          .paintInterior(canvas, rect, paint, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) =>
      _at(rect).paint(canvas, rect, textDirection: textDirection);

  @override
  bool operator ==(Object other) =>
      other is _HelpShape && other.side == side && other.pillUpTo == pillUpTo;

  @override
  int get hashCode => Object.hash(side, pillUpTo);
}

/// The support sheet ([showSupportSheet]): the same help as the Safety
/// Center (helplines, grounding, disclaimer) over the task in progress, with
/// crisis wording and a way back to what was just saved after a lexicon
/// hit ("Back to my check-in" / "Back to my capsule").
class SupportSheet extends ConsumerStatefulWidget {
  const SupportSheet({
    super.key,
    this.crisis = false,
    this.origin = SupportOrigin.checkIn,
  });

  final bool crisis;
  final SupportOrigin origin;

  @override
  ConsumerState<SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends ConsumerState<SupportSheet> {
  /// Set when the finished minute ticked off today's Breathe habit.
  bool _breatheLogged = false;

  @override
  void initState() {
    super.initState();
    // PRD 12 crisis follow-up: an in-app card on the next open 12–72 h later
    // (crisis_follow_up.dart). Kept on this phone only.
    if (widget.crisis) {
      unawaited(
        recordCrisisSheetShown(
          ref.read(kvStoreProvider),
          ref.read(timeContextProvider).now(),
        ),
      );
    }
    // F12 P0: no Aura Plus paywall for the rest of this Aura day after any
    // support / crisis sheet (features/plus/paywall_gate.dart).
    unawaited(markCrisisFlow(ref));
    // F10 Look back rests for 24 h after a crisis sheet on this phone
    // (device-only, never synced: DS-7).
    unawaited(
      recordLookBackHelp(
        ref.read(kvStoreProvider),
        ref.read(timeContextProvider).now(),
      ),
    );
  }

  Future<void> _completeBreathe() async {
    // F2: the finished 60 s grounding ticks off today's Breathe (the shared
    // auto-complete rule: onboarded, shown on Home, idempotent).
    final logged = await autoCompleteHabitToday(ref, PresetHabitKeys.breathe);
    if (logged && mounted) setState(() => _breatheLogged = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AuraSpace.gutter,
          0,
          AuraSpace.gutter,
          AuraSpace.xxl,
        ),
        children: [
          // An explicit Close: never rely on drag or the scrim alone.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AuraSpace.s),
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.crisis ? l.help_crisisTitle : l.help_title,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s),
              IconButton(
                key: const ValueKey('support-close'),
                tooltip: l.common_close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s),
          Text(
            !widget.crisis
                ? l.help_subtitle
                : switch (widget.origin) {
                    SupportOrigin.checkIn => l.help_crisisSubtitle,
                    SupportOrigin.capsule => l.help_crisisSubtitleCapsule,
                    SupportOrigin.reflection => l.reflections_supportSubtitle,
                  },
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AuraColors.textSoft,
            ),
          ),
          const SizedBox(height: AuraSpace.xl),
          // Focus starts on the first helpline (REQ-A11Y-11).
          const HelplineList(),
          const SizedBox(height: AuraSpace.xl),
          GroundingExercise(onComplete: _completeBreathe),
          if (_breatheLogged) ...[
            const SizedBox(height: AuraSpace.s),
            Semantics(
              liveRegion: true,
              child: Text(
                l.help_breatheLogged(habitLabel(l, PresetHabitKeys.breathe)),
                key: const ValueKey('support-breathe-logged'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AuraColors.textSoft,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: AuraSpace.xl),
          Text(
            l.help_disclaimer,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (widget.crisis) ...[
            const SizedBox(height: AuraSpace.l),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(switch (widget.origin) {
                SupportOrigin.checkIn => l.help_backToCheckin,
                SupportOrigin.capsule => l.help_backToCapsule,
                SupportOrigin.reflection => l.reflections_backToRoom,
              }),
            ),
          ],
        ],
      ),
    );
  }
}

/// A 60-second grounding: breathe with the circle (4 s in, 6 s out) while
/// gentle prompts change every 12 s. Pausable; never timed-out and no
/// countdown: a quiet ring shows how far through the minute you are
/// (REQ-A11Y-12). Under Reduce Motion the circle stays still and the
/// in/out cue crossfades on the 1 s timer (REQ-A11Y-08).
class GroundingExercise extends StatefulWidget {
  const GroundingExercise({super.key, this.onComplete});

  /// Called each time the full minute completes (F2 Breathe auto-complete).
  final VoidCallback? onComplete;

  @override
  State<GroundingExercise> createState() => _GroundingExerciseState();
}

class _GroundingExerciseState extends State<GroundingExercise>
    with SingleTickerProviderStateMixin {
  static const int total = 60;

  /// One breath: 4 s in, 6 s out.
  static const int breathSeconds = 10;
  static const int inhaleSeconds = 4;

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: breathSeconds),
  );
  Timer? _timer;
  int _elapsed = 0;
  bool _running = false;
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = reduceMotionOf(context);
    // Reduce Motion can change mid-exercise.
    if (_reduce) {
      _breath.stop();
    } else if (_running && !_breath.isAnimating) {
      _breath.repeat();
    }
  }

  void _toggle() {
    setState(() => _running = !_running);
    if (_running) {
      if (_elapsed >= total) {
        _elapsed = 0;
        _breath.value = 0;
      }
      if (!_reduce) _breath.repeat();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed++);
        if (_elapsed >= total) {
          _timer?.cancel();
          _breath.stop();
          setState(() => _running = false);
          widget.onComplete?.call();
        }
      });
    } else {
      _timer?.cancel();
      _breath.stop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  /// A gentle word for how far through the minute this is (no numbers).
  String _progressWord(AppLocalizations l) {
    if (_elapsed >= total) return l.help_progressDone;
    if (_elapsed < total / 3) return l.help_progressBegun;
    if (_elapsed < total * 2 / 3) return l.help_progressHalf;
    return l.help_progressNearly;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final prompts = [
      l.help_ground1,
      l.help_ground2,
      l.help_ground3,
      l.help_ground4,
      l.help_ground5,
    ];
    final done = _elapsed >= total;
    final started = _running || _elapsed > 0;
    final prompt = done
        ? l.help_groundingDone
        : _elapsed == 0 && !_running
        ? l.help_groundingBody
        : prompts[math.min(_elapsed ~/ 12, prompts.length - 1)];

    Widget circle(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AuraColors.starlight.withValues(alpha: 0.9),
            AuraColors.accent.withValues(alpha: 0.35),
            AuraColors.accent.withValues(alpha: 0.0),
          ],
        ),
      ),
    );

    // The in/out cue sits under the ring, on the card surface (never on the
    // glow, which is too low-contrast for text and too small at 200%). It
    // crossfades; the key is the phase, so it only fades when that changes.
    Widget cue(bool inhale) => Visibility(
      visible: _running,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: AnimatedSwitcher(
        duration: _reduce ? reducedMotionFade : AuraMotion.quick,
        child: Text(
          inhale ? l.help_breatheIn : l.help_breatheOut,
          key: ValueKey(inhale),
          style: theme.textTheme.titleSmall?.copyWith(
            color: AuraColors.lavender,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );

    // Under Reduce Motion: a still circle, and the phase follows the 1 s
    // timer (4 s in, 6 s out). Otherwise the circle and cue follow [_breath].
    Widget breathing(BuildContext context, Widget? ring) {
      final double size;
      final bool inhale;
      if (_reduce) {
        size = 112;
        inhale = _elapsed % breathSeconds < inhaleSeconds;
      } else {
        const split = inhaleSeconds / breathSeconds;
        final v = _breath.value;
        inhale = v < split;
        final s = inhale
            ? Curves.easeInOut.transform(v / split)
            : 1 - Curves.easeInOut.transform((v - split) / (1 - split));
        size = 70 + 70 * (_running ? s : 0.35);
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 156,
            width: 156,
            child: Stack(
              alignment: Alignment.center,
              children: [ring!, circle(size)],
            ),
          ),
          const SizedBox(height: AuraSpace.s),
          cue(inhale),
        ],
      );
    }

    // Quiet progress through the minute: no numbers, no countdown; read as
    // "About halfway" and the like.
    final ring = Semantics(
      container: true,
      label: l.help_groundingProgress,
      value: started ? _progressWord(l) : null,
      child: ExcludeSemantics(
        child: SizedBox.expand(
          child: CircularProgressIndicator(
            key: const ValueKey('grounding-progress'),
            value: _elapsed / total,
            strokeWidth: 3,
            color: AuraColors.starlight.withValues(alpha: 0.7),
            backgroundColor: AuraColors.outline.withValues(alpha: 0.6),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AuraSpace.l),
      decoration: BoxDecoration(
        color: AuraColors.surface,
        borderRadius: BorderRadius.circular(AuraRadius.l),
        border: Border.all(color: AuraColors.hairline),
      ),
      child: Column(
        children: [
          Text(l.help_groundingTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AuraSpace.l),
          if (_reduce)
            breathing(context, ring)
          else
            AnimatedBuilder(
              animation: _breath,
              builder: breathing,
              child: ring,
            ),
          const SizedBox(height: AuraSpace.m),
          Text(
            prompt,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AuraSpace.m),
          OutlinedButton(
            key: const ValueKey('grounding-toggle'),
            onPressed: _toggle,
            child: Text(
              _running
                  ? l.help_groundingPause
                  : (_elapsed > 0 && !done)
                  ? l.help_groundingResume
                  : l.help_groundingStart,
            ),
          ),
        ],
      ),
    );
  }
}
