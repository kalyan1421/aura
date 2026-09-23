import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../capsules/capsules_entry.dart';
import '../progress/progress_view.dart';
import 'breath_orb.dart';
import 'sanctuary_activities.dart';

/// The Sanctuary tab (F15 v1): a private, calm space. Top to bottom: the
/// person's Aura as a still orb, "Today's minute" (one suggestion per Aura
/// day), Breathe, the grounding library and the "Future you" capsules entry.
/// "I need help now" sits in the header, right after the title
/// (REQ-SAN-08). Everything works offline; nothing here shows other people,
/// plays sound or starts on its own. Each activity opens full screen.
class SanctuaryScreen extends ConsumerWidget {
  const SanctuaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final hue = ref.watch(progressViewProvider.select((v) => v.avatar.hue));
    final time = ref.watch(timeContextProvider);
    // Ticks every 30 s, so Today's minute changes at the 04:00 rollover.
    final now = ref.watch(nowProvider).value ?? time.now();
    final today = todaysMinuteFor(time.dayOf(now));

    Widget section(String text) => Padding(
      padding: const EdgeInsets.only(top: AuraSpace.xl, bottom: AuraSpace.s),
      child: Semantics(
        header: true,
        container: true,
        child: Text(text, style: t.titleSmall),
      ),
    );

    return Scaffold(
      appBar: helpAppBar(
        context,
        title: l.sanctuary_title,
        automaticallyImplyLeading: false,
      ),
      body: CosmicBackground(
        tint: glowColorForHue(hue),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.gutter,
            AuraSpace.l,
            AuraSpace.gutter,
            AuraSpace.xxl,
          ),
          children: [
            // Your Aura as a calm orb (still; nothing moves here).
            Center(child: BreathOrb(hue: hue, size: 128, still: true)),
            const SizedBox(height: AuraSpace.m),
            Text(
              l.sanctuary_intro,
              textAlign: TextAlign.center,
              style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
            ),
            section(l.sanctuary_todayTitle),
            SanctuaryActivityCard(
              key: const ValueKey('sanctuary-today'),
              activity: today,
              featured: true,
            ),
            section(l.sanctuary_breatheSection),
            SanctuaryActivityCard(
              key: const ValueKey('sanctuary-breathe'),
              activity: SanctuaryActivity.breathe,
              leading: BreathOrb(hue: hue, size: 44, still: true),
            ),
            section(l.sanctuary_groundingSection),
            for (final a in groundingLibrary)
              Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s),
                child: SanctuaryActivityCard(
                  key: ValueKey('sanctuary-${a.name}'),
                  activity: a,
                ),
              ),
            const SizedBox(height: AuraSpace.l),
            // F4 "Future you": the capsules feature fills this tile (and its
            // own heading); it renders nothing until then.
            const CapsulesEntryTile(),
          ],
        ),
      ),
    );
  }
}

/// One activity as a card: icon, title and a line about it. The whole card
/// is one button (one focus stop, ≥ 48 dp) that opens the activity.
class SanctuaryActivityCard extends StatelessWidget {
  const SanctuaryActivityCard({
    super.key,
    required this.activity,
    this.featured = false,
    this.leading,
  });

  final SanctuaryActivity activity;

  /// Today's minute: a "Begin" label instead of a chevron.
  final bool featured;

  /// Replaces the activity's icon (the Breathe card's mini orb).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      color: AuraColors.surface.withValues(alpha: featured ? 0.9 : 0.75),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          featured ? AuraRadius.l : AuraRadius.m,
        ),
        side: BorderSide(
          color: featured
              ? AuraColors.starlight.withValues(alpha: 0.35)
              : AuraColors.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      // One node: "title, line, button".
      child: MergeSemantics(
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: () => openSanctuaryActivity(context, activity),
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
                      child:
                          leading ??
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AuraColors.lavender.withValues(
                                alpha: 0.12,
                              ),
                            ),
                            child: Icon(
                              activity.icon,
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
                          Text(activity.title(l), style: t.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            activity.body(l),
                            style: t.bodyMedium?.copyWith(
                              color: AuraColors.textSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s),
                    if (featured)
                      Text(
                        l.sanctuary_begin,
                        style: t.labelLarge?.copyWith(
                          color: AuraColors.lavender,
                        ),
                      )
                    else
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
