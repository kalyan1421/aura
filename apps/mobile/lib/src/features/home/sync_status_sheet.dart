import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/aura_tokens.dart';

/// What the sync indicator says, from the sync phase and the outbox size.
/// Saving never depends on it: everything is on the phone first (PRD
/// Offline); this only explains where things are.
enum SyncStatus { saved, waiting, local }

SyncStatus syncStatusOf(SyncPhase phase, int pending) => switch (phase) {
  SyncPhase.offline ||
  SyncPhase.unavailable ||
  SyncPhase.signedOut => SyncStatus.local,
  _ when pending > 0 => SyncStatus.waiting,
  _ => SyncStatus.saved,
};

IconData _iconFor(SyncStatus s) => switch (s) {
  SyncStatus.local => Icons.cloud_off_outlined,
  SyncStatus.waiting => Icons.cloud_upload_outlined,
  SyncStatus.saved => Icons.cloud_done_outlined,
};

String _labelFor(AppLocalizations l, SyncStatus s, int pending) => switch (s) {
  SyncStatus.local => l.home_syncLocal,
  SyncStatus.waiting => l.home_syncPending(pending),
  SyncStatus.saved => l.home_syncIdle,
};

/// The small cloud on Home's top bar (PRD States: Home offline). A 48 dp
/// target that opens [showSyncStatusSheet].
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sync = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    return ValueListenableBuilder<SyncPhase>(
      valueListenable: sync.phase,
      builder: (context, phase, _) {
        final status = syncStatusOf(phase, pending);
        final label = _labelFor(l, status, pending);
        return Semantics(
          button: true,
          label: label,
          hint: l.home_syncHint,
          excludeSemantics: true,
          onTap: () => showSyncStatusSheet(context),
          child: IconButton(
            key: const ValueKey('home-sync'),
            tooltip: label,
            onPressed: () => showSyncStatusSheet(context),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(_iconFor(status), size: 20, color: AuraColors.textMuted),
          ),
        );
      },
    );
  }
}

Future<void> showSyncStatusSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const SyncStatusSheet(),
    );

/// Where your things are: the current state, one line of explanation, and
/// "Sync now" when online and signed in.
class SyncStatusSheet extends ConsumerWidget {
  const SyncStatusSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final sync = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    final online = ref.watch(connectivityProvider).value ?? true;
    final signedIn = ref.watch(authUserProvider).value != null;

    return ValueListenableBuilder<SyncPhase>(
      valueListenable: sync.phase,
      builder: (context, phase, _) {
        final status = syncStatusOf(phase, pending);
        final explain = switch (status) {
          SyncStatus.local => switch (phase) {
            SyncPhase.signedOut => l.home_syncExplainSignedOut,
            SyncPhase.unavailable => l.home_syncExplainUnavailable,
            _ => l.home_syncExplainOffline,
          },
          SyncStatus.waiting => l.home_syncExplainPending,
          SyncStatus.saved => l.home_syncExplainIdle,
        };
        final canSync = online && signedIn && phase != SyncPhase.unavailable;
        final syncing = phase == SyncPhase.syncing;

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
                  Icon(_iconFor(status), color: AuraColors.lavender),
                  const SizedBox(width: AuraSpace.m),
                  Expanded(
                    child: Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        _labelFor(l, status, pending),
                        key: const ValueKey('sync-sheet-status'),
                        style: t.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.common_close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s),
              Text(
                explain,
                style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
              ),
              if (canSync) ...[
                const SizedBox(height: AuraSpace.xl),
                // Keeps its width while syncing; the label says what is
                // happening (design-system "Filled button").
                OutlinedButton.icon(
                  key: const ValueKey('sync-now'),
                  onPressed: syncing ? null : sync.syncNow,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(syncing ? l.home_syncing : l.home_syncNow),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
