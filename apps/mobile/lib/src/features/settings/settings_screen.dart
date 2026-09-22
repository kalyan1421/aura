import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/env/env.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../onboarding/language_screen.dart';
import '../support/support_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final auth = ref.watch(authRepositoryProvider);
    final user = ref.watch(authUserProvider).value;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: AuraSpace.xl, bottom: AuraSpace.m),
      child: Semantics(header: true, child: Text(title, style: t.titleSmall)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.settings_title),
        backgroundColor: AuraColors.sky,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: const HelpNowButton(compact: true),
            ),
          ),
        ],
      ),
      body: CosmicBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.gutter,
            0,
            AuraSpace.gutter,
            AuraSpace.xxl,
          ),
          children: [
            section(l.settings_language),
            const LanguagePicker(),
            if (auth.isAvailable) ...[
              section(l.settings_account),
              if (user == null)
                FilledButton(
                  onPressed: () => context.push('/sign-in'),
                  child: Text(l.settings_signIn),
                )
              else ...[
                Text(l.settings_signedInAs(user.email ?? ''), style: t.bodyLarge),
                const SizedBox(height: AuraSpace.m),
                OutlinedButton(
                  onPressed: () => _signOut(context, ref),
                  child: Text(l.settings_signOut),
                ),
              ],
            ],
            section(l.settings_about),
            Text(l.help_disclaimer, style: t.bodyMedium),
            const SizedBox(height: AuraSpace.s),
            Text(l.settings_version(Env.appVersion), style: t.bodySmall),
            if (Env.debugTools) ...[
              const SizedBox(height: AuraSpace.l),
              TextButton.icon(
                onPressed: () => context.push('/debug/avatar'),
                icon: const Icon(Icons.science_outlined),
                label: Text(l.settings_avatarLab),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Warns when unsynced items would be lost (PRD States: Settings), then
  /// signs out and wipes this phone's personal data (shared phones).
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final pending = await ref.read(outboxRepositoryProvider).count();
    if (pending > 0 && context.mounted) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l.settings_signOutPending(pending)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.settings_stay),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.settings_signOutAnyway),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    await ref.read(signOutServiceProvider).signOut();
  }
}
