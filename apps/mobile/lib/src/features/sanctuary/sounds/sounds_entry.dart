import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/aura_tokens.dart';
import '../calm_route.dart';
import 'sounds_controller.dart';
import 'sounds_screen.dart';

/// Opens Sanctuary › Sounds. Opening plays nothing (REQ-SAN-09).
Future<void> openSounds(BuildContext context) =>
    pushCalm<void>(context, (_) => const SoundsScreen());

/// The Sounds card on the Sanctuary tab (PRD 06d layout: after Grounding).
/// One button, one focus stop; says "Playing now" while sounds play, so the
/// way back to Stop is obvious.
class SoundsEntryCard extends ConsumerWidget {
  const SoundsEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final active = ref.watch(
      soundsControllerProvider.select((s) => !s.isIdle),
    );
    return Material(
      color: AuraColors.surface.withValues(alpha: 0.75),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        side: BorderSide(
          color: active
              ? AuraColors.lavender.withValues(alpha: 0.45)
              : AuraColors.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          child: InkWell(
            key: const ValueKey('sanctuary-sounds'),
            onTap: () => openSounds(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.l,
                  vertical: AuraSpace.m,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AuraColors.lavender.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          active
                              ? Icons.graphic_eq_rounded
                              : Icons.headphones_outlined,
                          size: 22,
                          color: AuraColors.lavender,
                        ),
                      ),
                    ),
                    const SizedBox(width: AuraSpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.sounds_title, style: t.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            active ? l.sounds_cardPlaying : l.sounds_cardBody,
                            style: t.bodyMedium?.copyWith(
                              color: active
                                  ? AuraColors.lavender
                                  : AuraColors.textSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s),
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AuraColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
