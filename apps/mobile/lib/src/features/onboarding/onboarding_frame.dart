import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';

/// Shared layout for onboarding steps: calm sky, a scrollable body (text
/// scales to 200% without clipping) and the primary action pinned below.
///
/// The top bar holds [leading] (or, with [onBack], a back button) and
/// [trailing] — onboarding screens put `HelpNowButton(compact: true)` there
/// so help sits within the first three focus stops (REQ-A11Y-11).
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.children,
    this.primary,
    this.secondary,
    this.leading,
    this.trailing,
    this.hero,
    this.onBack,
  });

  final List<Widget> children;
  final Widget? primary;
  final Widget? secondary;
  final Widget? leading;
  final Widget? trailing;
  final Widget? hero;

  /// Goes to the previous onboarding step (usually
  /// `GateController.back`). Shows a back button when [leading] is null and
  /// also answers the system back gesture, which would otherwise close the
  /// app: onboarding steps replace each other rather than stack.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final lead =
        leading ?? (onBack == null ? null : OnboardingBackButton(onBack!));
    final scaffold = Scaffold(
      body: CosmicBackground(
        child: SafeArea(
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    ?lead,
                    const Spacer(),
                    if (trailing != null)
                      Flexible(
                        flex: 4,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: trailing,
                        ),
                      ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.gutter + 4,
                    AuraSpace.s,
                    AuraSpace.gutter + 4,
                    AuraSpace.xl,
                  ),
                  children: [?hero, ...children],
                ),
              ),
              if (primary != null || secondary != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.gutter,
                    AuraSpace.s,
                    AuraSpace.gutter,
                    AuraSpace.l,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [?primary, ?secondary],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (onBack == null) return scaffold;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack!();
      },
      child: scaffold,
    );
  }
}

/// Back to the previous onboarding step: 48 dp, "Back" tooltip (its screen
/// reader label) and the platform's direction-aware back icon.
class OnboardingBackButton extends StatelessWidget {
  const OnboardingBackButton(this.onPressed, {super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('onboarding-back'),
      tooltip: AppLocalizations.of(context).common_back,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        foregroundColor: AuraColors.lavender,
      ),
      icon: const BackButtonIcon(),
    );
  }
}

class StepTitle extends StatelessWidget {
  const StepTitle(this.title, {super.key, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: t.headlineMedium)),
        if (body != null) ...[
          const SizedBox(height: AuraSpace.m),
          Text(body!, style: t.bodyLarge?.copyWith(color: AuraColors.textSoft)),
        ],
        const SizedBox(height: AuraSpace.xl),
      ],
    );
  }
}
