import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/legal_links.dart';
import '../support/support_sheet.dart';
import 'gate_controller.dart';
import 'onboarding_frame.dart';

/// Onboarding "Privacy & boundaries" step (screen plan `/onboarding/trust`),
/// between Welcome and the DOB gate: private by default, wellness support
/// rather than therapy (F9 "App Review positioning"), the "not a medical
/// device or an emergency service" disclaimer (REQ-SAFE-12) and where help
/// lives. Nothing to tick: one Continue, no pre-selected consent.
class TrustScreen extends ConsumerWidget {
  const TrustScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gate = ref.read(gateControllerProvider.notifier);
    return OnboardingFrame(
      onBack: gate.back,
      trailing: const HelpNowButton(compact: true),
      primary: FilledButton(
        key: const ValueKey('trust-continue'),
        onPressed: () => gate.goTo(OnboardingStage.dob),
        child: Text(l.common_continue),
      ),
      children: [
        StepTitle(l.onb_trustTitle, body: l.onb_trustBody),
        _TrustPoint(
          icon: Icons.lock_outline_rounded,
          title: l.onb_trustPrivateTitle,
          lines: [l.onb_trustPrivateBody],
        ),
        _TrustPoint(
          icon: Icons.spa_outlined,
          title: l.onb_trustCareTitle,
          // The disclaimer is its own sentence, verbatim (F9, REQ-SAFE-12).
          lines: [l.onb_trustCareBody, l.help_disclaimer],
        ),
        _TrustPoint(
          icon: Icons.favorite_rounded,
          // Same warm tone and glyph as the help button it points to.
          iconColor: AuraColors.lantern,
          title: l.onb_trustHelpTitle,
          lines: [l.onb_trustHelpBody(l.help_button)],
        ),
        const SizedBox(height: AuraSpace.s),
        // TODO(legal): the lawyer-approved SPDI consent notice (REQ-ACC-15)
        // goes here, above the policy links. Do not draft consent wording in
        // the app, and never pre-tick a consent control.
        const LegalLinks(),
      ],
    );
  }
}

/// One scannable promise: a quiet glyph, a short heading and one or two
/// sentences. Headings are semantic headers so screen-reader users can jump
/// between points.
class _TrustPoint extends StatelessWidget {
  const _TrustPoint({
    required this.icon,
    required this.title,
    required this.lines,
    this.iconColor = AuraColors.lavender,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AuraSpace.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AuraColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
          const SizedBox(width: AuraSpace.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: t.titleMedium),
                ),
                for (final line in lines) ...[
                  const SizedBox(height: AuraSpace.xs),
                  Text(
                    line,
                    style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
