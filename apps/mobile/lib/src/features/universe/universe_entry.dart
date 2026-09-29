import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/router/routes.dart';

class UniverseEntry extends StatelessWidget {
  const UniverseEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: const ValueKey('universe-entry'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          leading: const Icon(Icons.public_rounded, size: 32),
          title: Text(l.universe_title),
          subtitle: Text(l.universe_entry),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push(Routes.universe),
        ),
      ),
    );
  }
}
