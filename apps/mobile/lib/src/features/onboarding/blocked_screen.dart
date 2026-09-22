import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../support/support_sheet.dart';
import 'onboarding_frame.dart';

/// Under-13 block (F8). Kind, with help by region. Shown on every launch for
/// 30 days (device lock); no account, email or device id is created.
class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final india = ref.watch(deviceRegionProvider) == 'IN';
    final t = Theme.of(context).textTheme;
    return OnboardingFrame(
      trailing: const HelpNowButton(compact: true),
      children: [
        const SizedBox(height: AuraSpace.xl),
        const Icon(Icons.nights_stay_outlined, size: 56, color: AuraColors.starlight),
        const SizedBox(height: AuraSpace.xl),
        Semantics(
          header: true,
          child: Text(
            l.blocked_title,
            key: const ValueKey('blocked-title'),
            style: t.headlineMedium,
          ),
        ),
        const SizedBox(height: AuraSpace.m),
        Text(l.blocked_body, style: t.bodyLarge?.copyWith(color: AuraColors.textSoft)),
        const SizedBox(height: AuraSpace.xxl),
        Container(
          padding: const EdgeInsets.all(AuraSpace.l),
          decoration: BoxDecoration(
            color: AuraColors.surface,
            borderRadius: BorderRadius.circular(AuraRadius.m),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(india ? l.blocked_helpIndia : l.blocked_helpOther, style: t.bodyLarge),
              if (india) ...[
                const SizedBox(height: AuraSpace.m),
                Wrap(
                  spacing: AuraSpace.s,
                  children: [
                    for (final n in const ['1098', '112'])
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri(scheme: 'tel', path: n)),
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: Text(n),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
