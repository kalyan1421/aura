import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import 'widget_prefs.dart';

/// Settings → Home-screen widget (F11 privacy defaults): "Show my last
/// mood" and "Discreet widget", both off by default.
class WidgetSettingsSection extends ConsumerWidget {
  const WidgetSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final prefs = ref.watch(widgetPrefsProvider);
    final ctl = ref.read(widgetPrefsProvider.notifier);
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
            child: Text(
              l.widget_settingsTitle,
              key: const ValueKey('set-section-widget'),
              style: t.titleSmall,
            ),
          ),
        ),
        SwitchListTile(
          key: const ValueKey('set-widget-last-mood'),
          contentPadding: EdgeInsets.zero,
          value: prefs.showLastMood && !prefs.discreet,
          // A discreet widget never names a mood.
          onChanged: prefs.discreet
              ? null
              : (v) => ctl.update((p) => p.copyWith(showLastMood: v)),
          title: Text(l.widget_showLastMood),
          subtitle: Text(l.widget_showLastMoodNote),
        ),
        SwitchListTile(
          key: const ValueKey('set-widget-discreet'),
          contentPadding: EdgeInsets.zero,
          value: prefs.discreet,
          onChanged: (v) => ctl.update((p) => p.copyWith(discreet: v)),
          title: Text(l.widget_discreet),
          subtitle: Text(l.widget_discreetNote),
        ),
      ],
    );
  }
}
