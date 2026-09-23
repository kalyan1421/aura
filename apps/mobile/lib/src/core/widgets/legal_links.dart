import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../env/env.dart';
import 'copy_fallback_notice.dart';
import '../theme/aura_tokens.dart';

/// Opens [uri] outside the app. Resolves `false` (or throws) when nothing
/// could open it: no browser, or a device that can't place calls.
typedef UrlOpener = Future<bool> Function(Uri uri);

/// The default [LegalLinks.opener]: the system browser.
Future<bool> openInBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Privacy policy and Terms of use, opened in the browser. Used by the
/// onboarding trust step and Settings → Help & Safety. A link whose URL is
/// not configured for this build is left out (see [Env.missingLegalConfig]).
///
/// When the browser can't open, a calm note under the links gives the page
/// address with a Copy action. It stays until closed (design-system.md
/// "Feedback": information stays ≥ 5 s or until dismissed).
class LegalLinks extends StatefulWidget {
  const LegalLinks({super.key, this.opener = openInBrowser});

  /// Opens a page (tests inject one that fails).
  final UrlOpener opener;

  @override
  State<LegalLinks> createState() => _LegalLinksState();
}

class _LegalLinksState extends State<LegalLinks> {
  /// The page that didn't open, shown in the note; `null` hides the note.
  String? _failedUrl;

  Future<void> _open(String url) async {
    var opened = false;
    try {
      opened = await widget.opener(Uri.parse(url));
    } on Object {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _failedUrl = opened ? null : url);
  }

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
    final failed = _failedUrl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AuraSpace.s,
          runSpacing: AuraSpace.xs,
          children: [
            for (final (label, url, key) in links)
              // Merged so the link role and hint sit on the button's own
              // node (with its tap action), not on a separate, action-less
              // node.
              MergeSemantics(
                child: Semantics(
                  link: true,
                  hint: l.legal_opensInBrowser,
                  child: TextButton.icon(
                    key: key,
                    onPressed: () => _open(url),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(label),
                  ),
                ),
              ),
          ],
        ),
        if (failed != null) ...[
          const SizedBox(height: AuraSpace.s),
          CopyFallbackNotice(
            // A different page is a new note (its Copy starts fresh).
            key: ValueKey('legal-open-failed:$failed'),
            message: l.polish_legalOpenFailed(failed),
            copyText: failed,
            copyLabel: l.polish_legalCopyLink,
            copiedLabel: l.polish_legalLinkCopied,
            onClose: () => setState(() => _failedUrl = null),
          ),
        ],
      ],
    );
  }
}
