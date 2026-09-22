import 'dart:async';
import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/kv_store.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
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
class HelpNowButton extends StatelessWidget {
  const HelpNowButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      sortKey: const OrdinalSortKey(1),
      child: OutlinedButton.icon(
        onPressed: () => showSupportSheet(context),
        icon: const Icon(Icons.favorite_rounded, size: 18),
        label: Text(l.help_button, maxLines: 3, softWrap: true),
        style: OutlinedButton.styleFrom(
          foregroundColor: AuraColors.lantern,
          side: BorderSide(color: AuraColors.lantern.withValues(alpha: 0.6)),
          backgroundColor: AuraColors.lantern.withValues(alpha: 0.08),
          minimumSize: const Size(48, 44),
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 10),
          textStyle: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }
}

class SupportSheet extends ConsumerStatefulWidget {
  const SupportSheet({super.key, this.crisis = false});

  final bool crisis;

  @override
  ConsumerState<SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends ConsumerState<SupportSheet> {
  bool _isMinor = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMinor());
  }

  Future<void> _loadMinor() async {
    final raw = await ref.read(kvStoreProvider).get(KvKeys.minorUntil);
    final until = LocalDay.tryParse(raw);
    if (until == null || !mounted) return;
    final now = DateTime.now();
    final today = LocalDay(now.year, now.month, now.day);
    setState(() => _isMinor = today.isBefore(until));
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
          Text(
            widget.crisis ? l.help_crisisTitle : l.help_title,
            style: theme.textTheme.headlineSmall,
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
            for (var i = 0; i < lines.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s),
                child: _HelplineTile(line: lines[i], autofocus: i == 0),
              ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s),
            Text(l.help_otherEmergency, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AuraSpace.xl),
          const GroundingExercise(),
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
  const _HelplineTile({required this.line, this.autofocus = false});

  final Helpline line;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: l.help_callSemantic(line.name, line.number),
      excludeSemantics: true,
      child: Material(
        color: AuraColors.surface,
        borderRadius: BorderRadius.circular(AuraRadius.m),
        child: InkWell(
          autofocus: autofocus,
          borderRadius: BorderRadius.circular(AuraRadius.m),
          onTap: () => launchUrl(Uri(scheme: 'tel', path: line.dial)),
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
                  child: const Icon(Icons.call_rounded, color: AuraColors.lantern),
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
/// gentle prompts change every 12 s. Pausable; never timed-out
/// (REQ-A11Y-12). Under Reduce Motion the circle stays still.
class GroundingExercise extends StatefulWidget {
  const GroundingExercise({super.key});

  @override
  State<GroundingExercise> createState() => _GroundingExerciseState();
}

class _GroundingExerciseState extends State<GroundingExercise>
    with SingleTickerProviderStateMixin {
  static const int total = 60;
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );
  Timer? _timer;
  int _elapsed = 0;
  bool _running = false;

  void _toggle() {
    setState(() => _running = !_running);
    if (_running) {
      if (_elapsed >= total) _elapsed = 0;
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!reduce) _breath.repeat();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed++);
        if (_elapsed >= total) {
          _timer?.cancel();
          _breath.stop();
          setState(() => _running = false);
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
    final prompt = done
        ? l.help_groundingDone
        : _elapsed == 0 && !_running
        ? l.help_groundingBody
        : prompts[math.min(_elapsed ~/ 12, prompts.length - 1)];

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
          SizedBox(
            height: 150,
            child: AnimatedBuilder(
              animation: _breath,
              builder: (context, _) {
                // 0–0.4 inhale, 0.4–1 exhale.
                final v = _breath.value;
                final inhale = v < 0.4;
                final s = inhale
                    ? Curves.easeInOut.transform(v / 0.4)
                    : 1 - Curves.easeInOut.transform((v - 0.4) / 0.6);
                final size = 70 + 70 * (_running ? s : 0.35);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
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
                      alignment: Alignment.center,
                      child: _running
                          ? Text(
                              inhale ? l.help_breatheIn : l.help_breatheOut,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AuraColors.onAccent,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AuraSpace.m),
          Text(
            prompt,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (_running || (_elapsed > 0 && !done)) ...[
            const SizedBox(height: AuraSpace.xs),
            Text(
              l.help_secondsLeft(total - _elapsed),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AuraSpace.m),
          OutlinedButton(
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
