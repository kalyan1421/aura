import 'package:flutter/material.dart';

import '../theme/aura_tokens.dart';

/// Calm inline status for ordinary recovery: form errors, a failed local
/// save, offline or "not available here" notes. Announced once to screen
/// readers when it appears (live region). Keeps the user's input in place;
/// put a recovery [action] next to it when there is one.
///
/// Never uses `lantern`: that tone belongs to immediate support ("I need
/// help now", helplines), so an ordinary form error must not look like a
/// crisis cue (design-system.md "Warm support-action rule").
class InlineNotice extends StatelessWidget {
  const InlineNotice(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.action,
  });

  final String text;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AuraSpace.m,
          AuraSpace.m,
          AuraSpace.m,
          AuraSpace.m,
        ),
        decoration: BoxDecoration(
          color: AuraColors.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AuraRadius.m),
          border: Border.all(color: AuraColors.outline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: AuraColors.lavender),
            ),
            const SizedBox(width: AuraSpace.s),
            Expanded(
              child: Text(
                text,
                style: t.bodyMedium?.copyWith(color: AuraColors.text),
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: AuraSpace.s),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
