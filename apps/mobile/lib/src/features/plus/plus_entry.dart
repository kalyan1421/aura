import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import 'paywall_gate.dart';

/// Route of the paywall (Aura Plus explainer) above the shell.
const String plusRoute = '/plus';

/// Route of the personal sky + Stardust screen.
const String plusSkiesRoute = '/plus/skies';

/// Opens the paywall for [surface] (a limit screen or Settings).
void openPlus(BuildContext context, PaywallSurface surface) =>
    context.push('$plusRoute?from=${surface.name}');

/// The Plus entry on a limit screen (4th mood capsule, long voice, a Plus sky
/// or Sounds stem, deeper Insights), under [PaywallGate]'s P0 rules:
/// - Plus on → nothing;
/// - excluded moment (crisis flow today, straight after a Storm/Rain
///   check-in, first 24 h, under-13 lock) → only "Part of Aura Plus";
/// - the day's one unprompted showing → [explainer] + "See Aura Plus";
/// - later that day → the explainer line with a small "About Aura Plus" link.
/// The free path always stays next to it (the caller's own action).
class PlusLimitNote extends ConsumerStatefulWidget {
  const PlusLimitNote({
    super.key,
    required this.surface,
    required this.explainer,
  });

  final PaywallSurface surface;

  /// What Plus adds here, in one calm line.
  final String explainer;

  static Key keyFor(PaywallSurface s) => ValueKey('plus-note-${s.name}');
  static Key buttonKeyFor(PaywallSurface s) =>
      ValueKey('plus-note-open-${s.name}');

  @override
  ConsumerState<PlusLimitNote> createState() => _PlusLimitNoteState();
}

class _PlusLimitNoteState extends ConsumerState<PlusLimitNote> {
  bool _marked = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final mode = ref.watch(paywallModeProvider(widget.surface));
    if (mode == PaywallMode.none) return const SizedBox.shrink();
    if (mode == PaywallMode.explainer && !_marked) {
      _marked = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => markUnpromptedShown(ref),
      );
    }
    final soft = t.bodyMedium?.copyWith(color: AuraColors.textSoft);
    return Semantics(
      key: PlusLimitNote.keyFor(widget.surface),
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 16,
                  color: AuraColors.lavender,
                ),
              ),
              const SizedBox(width: AuraSpace.xs),
              Flexible(
                child: Text(
                  l.plus_lockedOnly,
                  style: t.labelMedium?.copyWith(color: AuraColors.lavender),
                ),
              ),
            ],
          ),
          if (mode != PaywallMode.lockedOnly) ...[
            const SizedBox(height: AuraSpace.xs),
            Text(widget.explainer, style: soft),
            const SizedBox(height: AuraSpace.xs),
            if (mode == PaywallMode.explainer)
              OutlinedButton(
                key: PlusLimitNote.buttonKeyFor(widget.surface),
                onPressed: () => openPlus(context, widget.surface),
                child: Text(l.plus_seePlus),
              )
            else
              TextButton(
                key: PlusLimitNote.buttonKeyFor(widget.surface),
                onPressed: () => openPlus(context, widget.surface),
                child: Text(l.plus_about),
              ),
          ],
        ],
      ),
    );
  }
}

/// Shows the Plus note for a tapped Plus-only item (a Sounds stem, a Plus
/// sky) as a small sheet; closes with "Not now".
Future<void> showPlusNoteSheet(
  BuildContext context, {
  required PaywallSurface surface,
  required String explainer,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        0,
        AuraSpace.gutter,
        AuraSpace.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlusLimitNote(surface: surface, explainer: explainer),
          const SizedBox(height: AuraSpace.s),
          TextButton(
            key: const ValueKey('plus-note-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).common_notNow),
          ),
        ],
      ),
    ),
  ),
);

/// Only the way in, for a limit screen that already says what is locked in
/// its own words (Insights' "Part of Aura Plus" preview, the capsule limit
/// notice): "See Aura Plus" for the day's one unprompted showing, a small
/// "About Aura Plus" link after that, nothing at an excluded moment or with
/// Plus on.
class PlusOpenButton extends ConsumerStatefulWidget {
  const PlusOpenButton({super.key, required this.surface});

  final PaywallSurface surface;

  @override
  ConsumerState<PlusOpenButton> createState() => _PlusOpenButtonState();
}

class _PlusOpenButtonState extends ConsumerState<PlusOpenButton> {
  bool _marked = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mode = ref.watch(paywallModeProvider(widget.surface));
    switch (mode) {
      case PaywallMode.none || PaywallMode.lockedOnly:
        return const SizedBox.shrink();
      case PaywallMode.explainer:
        if (!_marked) {
          _marked = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => markUnpromptedShown(ref),
          );
        }
        return OutlinedButton(
          key: PlusLimitNote.buttonKeyFor(widget.surface),
          onPressed: () => openPlus(context, widget.surface),
          child: Text(l.plus_seePlus),
        );
      case PaywallMode.link:
        return TextButton(
          key: PlusLimitNote.buttonKeyFor(widget.surface),
          onPressed: () => openPlus(context, widget.surface),
          child: Text(l.plus_about),
        );
    }
  }
}
