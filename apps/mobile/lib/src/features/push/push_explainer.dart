import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import 'push_service.dart';

/// Offers notifications right after a check-in is saved (PRD
/// 15-permissions): the warm explainer first, and only "Allow" fires the OS
/// prompt. Shown at most once per account; a no-op when push is off.
Future<void> offerPushAfterCheckIn(BuildContext context, WidgetRef ref) =>
    ref.read(pushServiceProvider).offerAfterCheckIn(() async {
      if (!context.mounted) return null;
      return showModalBottomSheet<SoftAskAnswer>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => const PushExplainerSheet(),
      );
    });

/// "Want a gentle nudge each evening?" with Allow / Not now.
class PushExplainerSheet extends StatelessWidget {
  const PushExplainerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.xl,
        AuraSpace.gutter,
        AuraSpace.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.nights_stay_rounded,
              size: 40,
              color: AuraColors.starlight,
            ),
          ),
          const SizedBox(height: AuraSpace.l),
          Semantics(
            header: true,
            child: Text(
              l.push_title,
              textAlign: TextAlign.center,
              style: t.headlineSmall,
            ),
          ),
          const SizedBox(height: AuraSpace.s),
          Text(
            l.push_body,
            textAlign: TextAlign.center,
            style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.xl),
          FilledButton(
            key: const ValueKey('push-allow'),
            onPressed: () => Navigator.pop(context, SoftAskAnswer.allow),
            child: Text(l.push_allow),
          ),
          const SizedBox(height: AuraSpace.s),
          TextButton(
            key: const ValueKey('push-not-now'),
            onPressed: () => Navigator.pop(context, SoftAskAnswer.notNow),
            child: Text(l.common_notNow),
          ),
        ],
      ),
    );
  }
}
