import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../env/env.dart';
import '../theme/aura_tokens.dart';

/// Privacy policy and Terms of use, opened in the browser. Used by the
/// onboarding trust step and Settings → Help & Safety. A link whose URL is
/// not configured for this build is left out (see [Env.missingLegalConfig]).
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final links = [
      if (Env.privacyPolicyUrl.isNotEmpty)
        (
          l.legal_privacy,
          Env.privacyPolicyUrl,
          const ValueKey('legal-privacy'),
        ),
      if (Env.termsUrl.isNotEmpty)
        (l.legal_terms, Env.termsUrl, const ValueKey('legal-terms')),
    ];
    if (links.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AuraSpace.s,
      runSpacing: AuraSpace.xs,
      children: [
        for (final (label, url, key) in links)
          // Merged so the link role and hint sit on the button's own node
          // (with its tap action), not on a separate, action-less node.
          MergeSemantics(
            child: Semantics(
              link: true,
              hint: l.legal_opensInBrowser,
              child: TextButton.icon(
                key: key,
                onPressed: () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(label),
              ),
            ),
          ),
      ],
    );
  }
}
