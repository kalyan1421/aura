import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/widgets/inline_notice.dart';
import '../health/health_providers.dart';
import '../health/health_source.dart';

/// The opt-in card for step-lit path stones (W06). It exists only when the
/// phone has a health source; with none, the universe shows nothing about
/// health at all. Off by default; declining changes nothing.
class RealLifeCard extends ConsumerStatefulWidget {
  const RealLifeCard({super.key});

  @override
  ConsumerState<RealLifeCard> createState() => _RealLifeCardState();
}

class _RealLifeCardState extends ConsumerState<RealLifeCard> {
  bool _denied = false;
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    setState(() {
      _busy = true;
      _denied = false;
    });
    final result = await ref
        .read(healthStepsEnabledProvider.notifier)
        .setEnabled(on);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _denied = result == HealthToggleResult.denied;
    });
    if (result == HealthToggleResult.enabled ||
        result == HealthToggleResult.disabled) {
      ref.invalidate(worldStepsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(healthAvailabilityProvider).value;
    if (availability == null || availability == HealthAvailability.unavailable) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final enabled = ref.watch(healthStepsEnabledProvider).value ?? false;
    return Card(
      key: const ValueKey('universe-reallife'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.universe_reallifeTitle, style: t.titleLarge),
            const SizedBox(height: 8),
            Text(l.universe_reallifeBody, style: t.bodyMedium),
            SwitchListTile(
              key: const ValueKey('universe-reallife-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.universe_reallifeSwitch),
              value: enabled,
              onChanged: _busy ? null : _toggle,
            ),
            if (_denied)
              InlineNotice(
                l.universe_reallifeDenied,
                key: const ValueKey('universe-reallife-denied'),
              ),
          ],
        ),
      ),
    );
  }
}
