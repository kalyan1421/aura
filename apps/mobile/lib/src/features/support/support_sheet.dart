import 'dart:async';
import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/db/kv_store.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/copy_fallback_notice.dart';
import '../checkin/quadrant_glyph.dart' show habitLabel;
import '../onboarding/gate_controller.dart';
import 'helplines.dart';

/// Opens the support sheet. Works offline from bundled data, with no login.
Future<void> showSupportSheet(BuildContext context, {bool crisis = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SupportSheet(crisis: crisis),
  );
}

/// "I need help now" — always visible (Home, and every screen where it
/// normally appears). Warm lantern tone, never alarm red.
///
/// A pill while the label fits on one line. When it wraps (a narrow top
/// bar, 200% text, a longer language) it becomes a rounded rectangle
/// ([AuraRadius.m]), so a tall button never turns into a near-circle that
/// clips its label. The label is never cut to a line count.
class HelpNowButton extends StatelessWidget {
  const HelpNowButton({super.key, this.compact = false});

  final bool compact;

  static const double _iconSize = 18;
  static const double _minHeight = 44; // 48 dp tap target (padded)
  static const double _vPad = 10;

  /// From this text scale the sides get more room.
  static const double _largeText = 1.3;

  static double _hPad(BuildContext context, {required bool compact}) {
    final large =
        MediaQuery.textScalerOf(context).scale(100) / 100 >= _largeText;
    return compact ? (large ? 16 : 12) : (large ? 20 : 16);
  }

  static TextStyle? _labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge;

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
        _iconSize +
        AuraSpace.s +
        2 * _hPad(context, compact: compact) +
        2;
  }

  @override
  Widget build(BuildContext context) {
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
          onPressed: () => showSupportSheet(context),
          icon: const Icon(Icons.favorite_rounded, size: _iconSize),
          // Wrapped lines hug the longest one, so the button stays compact.
          label: Text(
            l.help_button,
            softWrap: true,
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

class SupportSheet extends ConsumerStatefulWidget {
  const SupportSheet({super.key, this.crisis = false});

  final bool crisis;

  @override
  ConsumerState<SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends ConsumerState<SupportSheet> {
  bool _isMinor = false;

  /// Set when the finished minute ticked off today's Breathe habit.
  bool _breatheLogged = false;

  /// The helpline this device couldn't dial (an iPad, a simulator): its
  /// number shows under it with a Copy action until closed.
  Helpline? _couldNotCall;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMinor());
  }

  /// Childline (India) is listed until the 18th birthday, judged on the
  /// app's shared clock and Aura day (04:00 rollover in the person's zone),
  /// like every other day in the app. Around midnight that can list it a
  /// few hours longer, never shorter.
  Future<void> _loadMinor() async {
    final raw = await ref.read(kvStoreProvider).get(KvKeys.minorUntil);
    final until = LocalDay.tryParse(raw);
    if (until == null || !mounted) return;
    final today = ref.read(timeContextProvider).today();
    setState(() => _isMinor = today.isBefore(until));
  }

  /// Dials at once (nothing is checked first, so a phone that can call is
  /// never slowed down). If the device can't place calls, the number shows
  /// under the row with a Copy action.
  Future<void> _call(Helpline line) async {
    var placed = false;
    try {
      placed = await launchUrl(Uri(scheme: 'tel', path: line.dial));
    } on Object {
      placed = false;
    }
    if (!mounted) return;
    setState(() => _couldNotCall = placed ? null : line);
  }

  /// F2: finishing the 60 s exercise auto-completes today's Breathe habit,
  /// only for an onboarded person who shows Breathe on Home. Nothing is read
  /// or written from the Blocked (under-13) screen or before onboarding, and
  /// a failure here never disturbs the sheet.
  Future<void> _completeBreathe() async {
    try {
      final gate = ref.read(gateControllerProvider);
      if (gate.isBlocked || !gate.onboarded) return;
      final logged = await ref
          .read(habitRepositoryProvider)
          .completeToday(PresetHabitKeys.breathe);
      if (!logged) return;
      ref.read(syncControllerProvider).notifyLocalWrite();
      if (mounted) setState(() => _breatheLogged = true);
    } on Object catch (e) {
      debugPrint('support: breathe auto-complete skipped (${e.runtimeType})');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final region = ref.watch(deviceRegionProvider);
    final lines = helplinesFor(region, l, isMinor: _isMinor);

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
            widget.crisis ? l.help_crisisSubtitle : l.help_subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AuraColors.textSoft,
            ),
          ),
          const SizedBox(height: AuraSpace.xl),
          if (lines.isEmpty)
            _Card(
              child: Text(
                l.help_otherEmergency,
                style: theme.textTheme.titleMedium,
              ),
            )
          else
            for (var i = 0; i < lines.length; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s),
                child: _HelplineTile(
                  line: lines[i],
                  autofocus: i == 0,
                  onCall: () => unawaited(_call(lines[i])),
                ),
              ),
              if (_couldNotCall?.dial == lines[i].dial)
                Padding(
                  padding: const EdgeInsets.only(bottom: AuraSpace.s),
                  child: CopyFallbackNotice(
                    key: ValueKey('support-call-failed-${lines[i].dial}'),
                    message: l.polish_helpCallFailed(lines[i].number),
                    copyText: lines[i].number,
                    copyLabel: l.polish_helpCopyNumber,
                    copiedLabel: l.polish_helpNumberCopied,
                    onClose: () => setState(() => _couldNotCall = null),
                  ),
                ),
            ],
          if (lines.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s),
            Text(l.help_otherEmergency, style: theme.textTheme.bodySmall),
          ],
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
              child: Text(l.help_backToCheckin),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AuraSpace.l),
    decoration: BoxDecoration(
      color: AuraColors.surface,
      borderRadius: BorderRadius.circular(AuraRadius.m),
      border: Border.all(color: AuraColors.hairline),
    ),
    child: child,
  );
}

class _HelplineTile extends StatelessWidget {
  const _HelplineTile({
    required this.line,
    required this.onCall,
    this.autofocus = false,
  });

  final Helpline line;
  final VoidCallback onCall;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The InkWell's semantics are replaced, so the tap action is restored
    // here: a screen-reader double-tap must place the call.
    return Semantics(
      button: true,
      label: l.help_callSemantic(line.name, line.number),
      onTap: onCall,
      excludeSemantics: true,
      child: Material(
        color: AuraColors.surface,
        borderRadius: BorderRadius.circular(AuraRadius.m),
        child: InkWell(
          key: ValueKey('support-call-${line.dial}'),
          autofocus: autofocus,
          borderRadius: BorderRadius.circular(AuraRadius.m),
          onTap: onCall,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.l,
              vertical: AuraSpace.m,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AuraColors.lantern.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    color: AuraColors.lantern,
                  ),
                ),
                const SizedBox(width: AuraSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.name, style: theme.textTheme.titleSmall),
                      Text(
                        line.number,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AuraColors.lantern,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
