import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../progress/progress_view.dart';
import '../share/share_card_data.dart';
import '../share/share_sheet.dart';
import 'keepsake_seal.dart';
import 'keepsakes_api.dart';
import 'keepsakes_providers.dart';
import 'keepsakes_repository.dart';

/// Where the private box lives (above the shell, opened from Insights, the
/// new-seal card on Home and Settings › Account).
const String keepsakesRoute = '/keepsakes';

/// "Kept on 12 Oct 2026" date, in the UI language (romanized locales read
/// dates in English, as elsewhere in the app).
String keepsakeDateLabel(BuildContext context, LocalDay day) {
  final loc = Localizations.localeOf(context);
  final intl = loc.scriptCode == 'Latn' ? 'en' : loc.languageCode;
  final date = DateTime(day.year, day.month, day.day);
  try {
    return DateFormat('d MMM y', intl).format(date);
  } on Object {
    return DateFormat('d MMM y', 'en').format(date);
  }
}

/// The private keepsake box (PRD F13 "Private box in Insights"). It shows only
/// the seals earned, each with the day it was earned: no locked slots, no
/// progress bars, no "next seal" hints and no count, so collecting never
/// becomes a chore. Only the person sees it; a seal leaves the phone only as
/// the person's own share card.
class KeepsakesScreen extends ConsumerStatefulWidget {
  const KeepsakesScreen({super.key});

  @override
  ConsumerState<KeepsakesScreen> createState() => _KeepsakesScreenState();
}

class _KeepsakesScreenState extends ConsumerState<KeepsakesScreen> {
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final r = await ref.read(keepsakesRepositoryProvider).refresh();
    if (mounted) setState(() => _offline = r == KeepsakesRefresh.offline);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final list = ref.watch(keepsakesProvider).value ?? const <OwnKeepsake>[];
    final avatar = ref.watch(progressViewProvider.select((v) => v.avatar));
    final reduce = reduceMotionOf(context);

    return Scaffold(
      appBar: helpAppBar(context, title: l.keepsakes_title),
      body: CosmicBackground(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const ValueKey('keepsakes-list'),
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.gutter,
              AuraSpace.s,
              AuraSpace.gutter,
              AuraSpace.xxl,
            ),
            children: [
              Text(
                l.keepsakes_intro,
                style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
              ),
              if (_offline) ...[
                const SizedBox(height: AuraSpace.s),
                Text(
                  l.keepsakes_offline,
                  key: const ValueKey('keepsakes-offline'),
                  style: t.bodySmall?.copyWith(color: AuraColors.textMuted),
                ),
              ],
              const SizedBox(height: AuraSpace.l),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AuraSpace.xl),
                  child: Text(
                    l.keepsakes_empty,
                    key: const ValueKey('keepsakes-empty'),
                    textAlign: TextAlign.center,
                    style: t.bodyLarge,
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, box) {
                    final columns = box.maxWidth >= 520 ? 3 : 2;
                    final gap = AuraSpace.m;
                    final w = (box.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final (i, k) in list.indexed)
                          SizedBox(
                            width: w,
                            // Under Reduce Motion the seals simply appear.
                            child: reduce
                                ? _SealTile(keepsake: k, avatar: avatar)
                                : _SealTile(
                                    keepsake: k,
                                    avatar: avatar,
                                  ).animate().fadeIn(
                                    delay: (60 * i).ms,
                                    duration: AuraMotion.calm,
                                  ),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: AuraSpace.xl),
              if (avatar.stage != AuraStage.spark)
                OutlinedButton.icon(
                  key: const ValueKey('keepsakes-share-aura'),
                  onPressed: () => showShareCardSheet(
                    context,
                    ShareCardData.evolution(avatar),
                  ),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(l.keepsakes_shareAura),
                ),
              const SizedBox(height: AuraSpace.l),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: AuraColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s),
                  Expanded(
                    child: Text(
                      l.keepsakes_privateNote,
                      style: t.bodySmall?.copyWith(color: AuraColors.textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SealTile extends StatelessWidget {
  const _SealTile({required this.keepsake, required this.avatar});

  final OwnKeepsake keepsake;
  final AuraAvatarState avatar;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final line = keepsakeLine(l, keepsake.key);
    final date = keepsakeDateLabel(context, keepsake.earnedOn);
    return Material(
      key: ValueKey('keepsake-${keepsake.key}'),
      color: AuraColors.surface.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuraRadius.m),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: l.keepsakes_sealSemantic(line, date),
        hint: l.keepsakes_shareThis,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => showShareCardSheet(
            context,
            ShareCardData.keepsake(avatar, keepsake.key),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.m),
            child: Column(
              children: [
                KeepsakeSeal(keepsakeKey: keepsake.key, size: 88),
                const SizedBox(height: AuraSpace.s),
                Text(line, textAlign: TextAlign.center, style: t.titleSmall),
                const SizedBox(height: AuraSpace.xs),
                Text(
                  l.keepsakes_keptOn(date),
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(color: AuraColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Entry row to the private box, for Insights (F10 owner) and Settings.
class KeepsakesEntryTile extends StatelessWidget {
  const KeepsakesEntryTile({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    // A card, like the other entry cards at the end of Insights: entry
    // points share one look.
    return Semantics(
      container: true,
      button: true,
      child: Material(
        color: AuraColors.surface.withValues(alpha: 0.82),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.l),
          side: const BorderSide(color: AuraColors.hairline),
        ),
        child: InkWell(
          key: const ValueKey('keepsakes-entry'),
          borderRadius: BorderRadius.circular(AuraRadius.l),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.l),
            child: Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: AuraColors.starlight,
                  ),
                ),
                const SizedBox(width: AuraSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.keepsakes_entry, style: t.titleMedium),
                      const SizedBox(height: AuraSpace.xs),
                      Text(
                        l.keepsakes_entryNote,
                        style: t.bodyMedium?.copyWith(
                          color: AuraColors.textSoft,
                        ),
                      ),
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
    );
  }
}
