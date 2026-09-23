import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../theme/aura_tokens.dart';

/// A button label that stays put while work runs: a small progress ring
/// appears in a slot that is always reserved (mirrored on the other side so
/// the label stays centred), so the button never changes width or height
/// (design-system.md "Filled button": keep the label stable, show progress
/// without changing width). The ring is announced as "One moment".
///
/// Used by sign-in (Send / Continue) and account deletion.
class BusyButtonLabel extends StatelessWidget {
  const BusyButtonLabel(this.label, {super.key, required this.busy, this.icon});

  final String label;
  final bool busy;

  /// Shown in the slot while idle (e.g. a delete icon, so a destructive
  /// action never relies on colour alone).
  final IconData? icon;

  static const double _slot = 18;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: _slot,
          child: busy
              ? CircularProgressIndicator(
                  key: const ValueKey('busy-progress'),
                  strokeWidth: 2,
                  color: color,
                  semanticsLabel: AppLocalizations.of(context).signin_busy,
                )
              : icon == null
              ? null
              : Icon(icon, size: _slot),
        ),
        const SizedBox(width: AuraSpace.s),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        const SizedBox(width: AuraSpace.s),
        const SizedBox.square(dimension: _slot),
      ],
    );
  }
}
