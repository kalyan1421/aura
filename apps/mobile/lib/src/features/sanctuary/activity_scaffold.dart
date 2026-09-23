import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../support/support_sheet.dart' show HelpNowButton;

/// A full-screen Sanctuary activity: ✕ to leave at any time (nothing is lost,
/// nothing is mentioned) and "I need help now" in the header, the first two
/// focus stops (REQ-SAN-08), over the calm sky.
class ActivityScaffold extends StatelessWidget {
  const ActivityScaffold({
    super.key,
    required this.child,
    this.tint,
    this.onHelp,
  });

  final Widget child;

  /// Optional sky wash (the person's hue).
  final Color? tint;

  /// Runs just before "I need help now" opens the Safety Center (a pacer
  /// pauses, REQ-SAN-08).
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: CosmicBackground(
        tint: tint,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('activity-close'),
                      tooltip: l.common_close,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: AuraSpace.s),
                    // Flexible: large text wraps the label, never overflows.
                    Flexible(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: HelpNowButton(compact: true, onOpen: onHelp),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// A page title inside an activity (a header for screen readers).
class ActivityTitle extends StatelessWidget {
  const ActivityTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    container: true,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall,
    ),
  );
}
