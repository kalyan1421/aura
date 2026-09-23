import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/theme/aura_tokens.dart';
import '../avatar/aura_avatar.dart';
import '../support/support_sheet.dart';
import 'gate_controller.dart';
import 'onboarding_frame.dart';

/// First launch (F8). Begin leads to the trust step, not straight to the
/// DOB gate. "I need help now" is reachable before any setup (F9).
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // The hero eases in; under Reduce Motion the fade is a short crossfade
    // (REQ-A11Y-08).
    final fade = reduceMotionOf(context) ? reducedMotionFade : AuraMotion.slow;
    return OnboardingFrame(
      trailing: const HelpNowButton(compact: true),
      hero: Center(
        child: AuraAvatar(
          state: AuraAvatarState(stage: AuraStage.glow, ringCount: 1),
          size: const Size.square(300),
        ),
      ).animate().fadeIn(duration: fade, curve: AuraMotion.ease),
      primary: FilledButton(
        key: const ValueKey('welcome-begin'),
        onPressed: () => ref
            .read(gateControllerProvider.notifier)
            .goTo(OnboardingStage.trust),
        child: Text(l.welcome_begin),
      ),
      children: [
        const SizedBox(height: AuraSpace.s),
        StepTitle(l.welcome_title, body: l.welcome_body),
      ],
    );
  }
}
