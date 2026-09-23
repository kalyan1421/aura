import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../checkin/quadrant_glyph.dart' show habitLabel;
import '../onboarding/gate_controller.dart';
import '../sanctuary/habit_auto_complete.dart';
import '../support/support_sheet.dart';
import 'helpline_list.dart';

/// The Safety Center (`/safety`, F9): what "I need help now" opens, from
/// every screen and every gate state (onboarding and the under-13 screen
/// included) and from `aura://safety`.
///
/// Immediate help first: the region's verified helplines (tap to call), or
/// the local-emergency card where none is listed; when to call emergency
/// services; the 60-second grounding; the boundary ("Aura is not a medical
/// device or an emergency service"). Bundled data only: offline, signed out,
/// no spinner. Close returns to the screen underneath (a check-in keeps its
/// input). Contextual interception (a lexicon hit) keeps the support sheet.
class SafetyCenterScreen extends ConsumerStatefulWidget {
  const SafetyCenterScreen({super.key});

  @override
  ConsumerState<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends ConsumerState<SafetyCenterScreen> {
  /// Set when the finished minute ticked off today's Breathe habit.
  bool _breatheLogged = false;

  Future<void> _completeBreathe() async {
    final logged = await autoCompleteHabitToday(ref, PresetHabitKeys.breathe);
    if (logged && mounted) setState(() => _breatheLogged = true);
  }

  /// Back to wherever help was opened. Opened on its own (a deep link with
  /// nothing underneath), the gate decides where the person belongs.
  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    GoRouter.maybeOf(context)?.go(Routes.root);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final gate = ref.watch(gateControllerProvider);
    final signedIn = ref.watch(authUserProvider).value != null;
    // Settings only exists after onboarding (the gate would bounce it).
    final settings = signedIn && gate.onboarded && !gate.isBlocked;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AuraColors.sky,
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const ValueKey('safety-close'),
          tooltip: l.common_close,
          onPressed: _close,
          icon: const Icon(Icons.close_rounded),
        ),
        title: Semantics(
          header: true,
          container: true,
          child: Text(l.help_title),
        ),
      ),
      body: CosmicBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            key: const ValueKey('safety-list'),
            padding: const EdgeInsetsDirectional.fromSTEB(
              AuraSpace.gutter,
              AuraSpace.s,
              AuraSpace.gutter,
              AuraSpace.xxl,
            ),
            children: [
              Text(
                l.help_subtitle,
                style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
              ),
              const SizedBox(height: AuraSpace.xl),
              // Immediate help first; focus starts on the first helpline.
              const HelplineList(keyPrefix: 'safety', emergencyLine: false),
              const SizedBox(height: AuraSpace.s),
              const _WhenToCallEmergency(),
              const SizedBox(height: AuraSpace.xl),
              GroundingExercise(onComplete: _completeBreathe),
              if (_breatheLogged) ...[
                const SizedBox(height: AuraSpace.s),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l.help_breatheLogged(
                      habitLabel(l, PresetHabitKeys.breathe),
                    ),
                    key: const ValueKey('safety-breathe-logged'),
                    style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: AuraSpace.xl),
              Text(
                l.help_disclaimer,
                key: const ValueKey('safety-disclaimer'),
                style: t.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (settings) ...[
                const SizedBox(height: AuraSpace.l),
                Center(
                  child: TextButton.icon(
                    key: const ValueKey('safety-settings'),
                    onPressed: () => context.push(Routes.settings),
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    // Inside the button so the hint joins its node.
                    label: Semantics(
                      hint: l.safety_settingsHint,
                      child: Text(l.safety_settingsLink),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// When to call emergency services rather than a helpline. Calm and direct;
/// never red (design system: support without alarm).
class _WhenToCallEmergency extends StatelessWidget {
  const _WhenToCallEmergency();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey('safety-when-emergency'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AuraSpace.l,
        AuraSpace.m,
        AuraSpace.l,
        AuraSpace.m,
      ),
      decoration: BoxDecoration(
        color: AuraColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AuraRadius.m),
        border: Border.all(color: AuraColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(top: 2),
            child: ExcludeSemantics(
              child: Icon(
                Icons.emergency_outlined,
                size: 20,
                color: AuraColors.lantern,
              ),
            ),
          ),
          const SizedBox(width: AuraSpace.m),
          Expanded(
            child: Text(
              l.safety_emergencyWhen,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AuraColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
