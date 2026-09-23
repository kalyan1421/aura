import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import 'capsule_opening.dart';
import 'capsule_providers.dart';

/// Home card: "Something you sealed is ready to open." (F4 date unlock).
///
/// Shown while a date capsule's 10:00 (in the current zone) has passed and
/// it isn't opened — also when the unlock passed while the phone was off
/// (it shows on the next launch). Nothing otherwise. Opens the soonest one.
///
/// Also starts the capsule coordinator (local notices follow the capsules,
/// the zone and the language for the whole session).
class CapsuleReadyCard extends ConsumerWidget {
  const CapsuleReadyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(capsuleCoordinatorProvider);
    final ready = ref.watch(readyDateCapsulesProvider);
    if (ready.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s),
      child: Material(
        key: const ValueKey('capsule-ready-card'),
        color: AuraColors.surface.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.l),
          side: BorderSide(color: AuraColors.starlight.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.mark_email_unread_outlined,
                      color: AuraColors.starlight,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            l.capsules_readyTitle,
                            style: t.titleMedium,
                          ),
                        ),
                        if (ready.length > 1) ...[
                          const SizedBox(height: 2),
                          Text(
                            l.capsules_readyMore(ready.length),
                            style: t.bodySmall?.copyWith(
                              color: AuraColors.textSoft,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.m),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.tonal(
                  key: const ValueKey('capsule-ready-open'),
                  onPressed: () => openCapsule(context, ready.first.id),
                  child: Text(l.capsules_readyOpen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
