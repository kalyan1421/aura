import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../avatar/aura_avatar.dart';
import 'gate_controller.dart';
import 'onboarding_frame.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return OnboardingFrame(
      hero: Center(
        child: AuraAvatar(
          state: AuraAvatarState(stage: AuraStage.glow, ringCount: 1),
          size: const Size.square(300),
        ),
      ).animate().fadeIn(duration: 900.ms),
      primary: FilledButton(
        key: const ValueKey('welcome-begin'),
        onPressed: () => ref
            .read(gateControllerProvider.notifier)
            .goTo(OnboardingStage.dob),
        child: Text(l.welcome_begin),
      ),
      children: [
        const SizedBox(height: 8),
        StepTitle(l.welcome_title, body: l.welcome_body),
      ],
    );
  }
}
