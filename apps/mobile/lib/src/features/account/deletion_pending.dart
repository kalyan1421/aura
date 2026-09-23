import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/inline_notice.dart';
import '../auth/busy_button_label.dart';
import 'account_providers.dart';

/// "Your account is set to be deleted on {date}. Keep it?" with
/// "Keep my account" (`DELETE /v1/account/deletion`) and "Let it go"
/// (contracts/api/v1.md "Account deletion", F8 REQ-ACC-11). A failed keep
/// shows a calm notice and changes nothing. Past the grace period
/// (`409 account_deletion_in_progress`) the account can't be kept: it says
/// so and offers only "Sign out", which runs [onLetGo] (never a retry).
class DeletionChoice extends ConsumerStatefulWidget {
  const DeletionChoice({
    super.key,
    required this.pending,
    required this.onKept,
    required this.onLetGo,
    this.autofocusKeep = false,
  });

  final DeletionPending pending;
  final VoidCallback onKept;
  final Future<void> Function() onLetGo;

  /// Dialogs start on the safe choice; an inline card never steals focus.
  final bool autofocusKeep;

  @override
  ConsumerState<DeletionChoice> createState() => _DeletionChoiceState();
}

class _DeletionChoiceState extends ConsumerState<DeletionChoice> {
  bool _busy = false;
  bool _failed = false;
  bool _tooLate = false;

  Future<void> _keep() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final result = await ref.read(deletionHoldProvider.notifier).keep();
      if (!mounted) return;
      switch (result) {
        case KeepResult.kept:
          widget.onKept();
        case KeepResult.tooLate:
          setState(() => _tooLate = true);
      }
    } catch (e) {
      debugPrint('account: keep ${e.runtimeType}');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _letGo() async {
    setState(() => _busy = true);
    try {
      await widget.onLetGo();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final date = widget.pending.scheduledFor;
    if (_tooLate) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              l.acct_inProgress,
              key: const ValueKey('acct-in-progress'),
              style: t.bodyLarge,
            ),
          ),
          const SizedBox(height: AuraSpace.l),
          FilledButton(
            key: const ValueKey('acct-in-progress-sign-out'),
            autofocus: widget.autofocusKeep,
            onPressed: _busy ? null : _letGo,
            child: BusyButtonLabel(l.settings_signOut, busy: _busy),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          date == null
              ? l.acct_pendingBodySoon
              : l.acct_pendingBody(formatAccountDate(context, date)),
          key: const ValueKey('acct-pending-body'),
          style: t.bodyLarge,
        ),
        if (_failed) ...[
          const SizedBox(height: AuraSpace.m),
          InlineNotice(
            l.acct_keepFailed,
            key: const ValueKey('acct-keep-failed'),
          ),
        ],
        const SizedBox(height: AuraSpace.l),
        FilledButton(
          key: const ValueKey('acct-keep'),
          autofocus: widget.autofocusKeep,
          onPressed: _busy ? null : _keep,
          child: BusyButtonLabel(l.acct_keep, busy: _busy),
        ),
        const SizedBox(height: AuraSpace.s),
        TextButton(
          key: const ValueKey('acct-let-go'),
          onPressed: _busy ? null : _letGo,
          child: Text(l.acct_letGo),
        ),
      ],
    );
  }
}

/// Asks "Keep your account?" (after a sign-in finds a scheduled deletion).
/// `true`: the deletion was cancelled. `false`: "Let it go" (or too late to
/// keep it) — the caller signs out ([DeletionHold.letGo]) once the dialog is
/// closed. `null`: the dialog went away without a choice (sync keeps
/// holding; Settings asks).
Future<bool?> showKeepAccountDialog(
  BuildContext context,
  DeletionPending pending,
) {
  final l = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        key: const ValueKey('acct-pending-dialog'),
        title: Semantics(header: true, child: Text(l.acct_pendingTitle)),
        content: SingleChildScrollView(
          child: DeletionChoice(
            pending: pending,
            autofocusKeep: true,
            onKept: () => Navigator.pop(context, true),
            onLetGo: () async => Navigator.pop(context, false),
          ),
        ),
      ),
    ),
  );
}

/// The same choice inline, for a deletion that sync discovered
/// (`403 account_deletion_pending`) while the app was in use. Shown in
/// Settings; empty when nothing is pending.
class DeletionPendingCard extends ConsumerWidget {
  const DeletionPendingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(deletionHoldProvider);
    if (pending == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('acct-pending-card'),
      padding: const EdgeInsetsDirectional.all(AuraSpace.l),
      decoration: BoxDecoration(
        color: AuraColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AuraRadius.m),
        border: Border.all(color: AuraColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l.acct_pendingTitle, style: t.titleMedium),
          ),
          const SizedBox(height: AuraSpace.s),
          DeletionChoice(
            pending: pending,
            onKept: () {},
            onLetGo: () => ref.read(deletionHoldProvider.notifier).letGo(),
          ),
        ],
      ),
    );
  }
}
