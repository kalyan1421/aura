import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';

Future<void> showRestDaysSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      // Over the navigation bar too: a modal never leaves the tabs tappable.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const RestDaysSheet(),
    );

/// A short explainer for rest days (F3): how they are earned (numbers from
/// the rules in aura_domain), that they apply on their own, and that glow
/// days stay. No countdowns, no loss words.
class RestDaysSheet extends StatelessWidget {
  const RestDaysSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;

    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: AuraColors.moonlight),
          ),
          const SizedBox(width: AuraSpace.m),
          Expanded(child: Text(text, style: t.bodyLarge)),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AuraSpace.gutter,
        0,
        AuraSpace.gutter,
        AuraSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.home_restInfoTitle, style: t.headlineSmall),
                ),
              ),
              IconButton(
                key: const ValueKey('rest-close'),
                tooltip: l.common_close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.l),
          point(
            Icons.nightlight_round,
            l.home_restInfoEarn(activeDaysPerRestDay, maxRestBank),
          ),
          point(Icons.bedtime_outlined, l.home_restInfoUse),
          point(Icons.star_rounded, l.home_restInfoKeep),
        ],
      ),
    );
  }
}
