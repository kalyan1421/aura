import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import 'capsule_providers.dart';
import 'capsules_list_screen.dart';

/// Entry to "Future you" time capsules (F4), shown in Sanctuary: its own
/// heading and one card (a single button) with how many are sealed and how
/// many are ready. Opens the capsules list.
class CapsulesEntryTile extends ConsumerWidget {
  const CapsulesEntryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    ref.watch(capsuleCoordinatorProvider);
    final rows = ref.watch(capsulesProvider).value ?? const [];
    final ready = ref.watch(readyCapsulesProvider).length;
    final sealed = rows.where((r) => r.openedAt == null).length;
    final soft = t.bodySmall?.copyWith(color: AuraColors.textSoft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AuraSpace.xl,
            bottom: AuraSpace.s,
          ),
          child: Semantics(
            header: true,
            container: true,
            child: Text(l.capsules_title, style: t.titleSmall),
          ),
        ),
        Material(
          key: const ValueKey('sanctuary-capsules'),
          color: AuraColors.surface.withValues(alpha: ready > 0 ? 0.92 : 0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.m),
            side: BorderSide(
              color: ready > 0
                  ? AuraColors.starlight.withValues(alpha: 0.4)
                  : AuraColors.hairline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: MergeSemantics(
            child: Semantics(
              button: true,
              child: InkWell(
                onTap: () => openCapsulesList(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: Padding(
                    padding: const EdgeInsets.all(AuraSpace.l),
                    child: Row(
                      children: [
                        const CapsuleSealGlyph(size: 40),
                        const SizedBox(width: AuraSpace.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rows.isEmpty
                                    ? l.capsules_emptyBody
                                    : l.capsules_entryCount(sealed),
                                style: t.bodyLarge,
                              ),
                              if (ready > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  l.capsules_entryReady(ready),
                                  style: soft?.copyWith(
                                    color: AuraColors.starlight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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
        ),
      ],
    );
  }
}
