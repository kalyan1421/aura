import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capsules/capsule_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/net/aura_api.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../../core/widgets/busy_button_label.dart';
import '../../core/widgets/inline_notice.dart';
import 'account_providers.dart';

enum _Phase { idle, requesting, scheduled }

/// In-app account deletion (`/settings/delete-account`, F8 REQ-ACC-11,
/// Apple 5.1.1(v)); three taps from Settings: the Settings row, "Delete my
/// account" here, and the confirmation.
///
/// Says what is deleted, the 7-day grace, that store subscriptions are
/// managed and cancelled in the store, and that it needs a connection. Only
/// after the server accepts (`POST /v1/account/deletion`) is this phone
/// cleared, with the same wipe as Sign out; the scheduled date is then shown
/// on the cleared phone and "Done" goes to Welcome. A failure changes
/// nothing and offers a retry.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  _Phase _phase = _Phase.idle;
  DateTime? _scheduledFor;
  String? _failure;

  /// Completed by "Done" (or back): the wiped app then returns to Welcome.
  Completer<void>? _done;

  @override
  void dispose() {
    // Never leave sign-out waiting on a screen that is gone.
    final done = _done;
    if (done != null && !done.isCompleted) done.complete();
    super.dispose();
  }

  Future<void> _confirm() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('acct-confirm-dialog'),
        title: Semantics(header: true, child: Text(l.acct_confirmTitle)),
        content: SingleChildScrollView(child: Text(l.acct_confirmBody)),
        actions: [
          // The safe choice comes first and holds the initial focus.
          TextButton(
            key: const ValueKey('acct-confirm-cancel'),
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.common_cancel),
          ),
          // Destructive: the warm danger tone, an icon and bolder words,
          // never the same weight as Cancel.
          TextButton.icon(
            key: const ValueKey('acct-confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            style: destructiveTextButtonStyle(context),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: Text(l.acct_deleteTitle),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _request();
  }

  Future<void> _request() async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(accountRepositoryProvider);
    if (repo == null || _phase != _Phase.idle) return;
    setState(() {
      _phase = _Phase.requesting;
      _failure = null;
    });
    final DateTime date;
    try {
      date = await repo.requestDeletion();
    } catch (e) {
      debugPrint('account: delete ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _phase = _Phase.idle;
          _failure = e is ApiException && e.isNetwork
              ? l.acct_failedOffline
              : l.acct_failed;
        });
      }
      return;
    }
    // Accepted: clear this phone now, show the date on the cleared phone,
    // then Welcome once the person is done reading.
    final done = _done = Completer<void>();
    await ref
        .read(signOutServiceProvider)
        .signOut(
          onWiped: () async {
            if (!mounted) return;
            setState(() {
              _phase = _Phase.scheduled;
              _scheduledFor = date;
            });
            await done.future;
          },
        );
  }

  void _finish() {
    final done = _done;
    if (done != null && !done.isCompleted) done.complete();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: _phase == _Phase.idle,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _phase == _Phase.scheduled) _finish();
      },
      child: Scaffold(
        appBar: helpAppBar(
          context,
          title: l.acct_deleteTitle,
          automaticallyImplyLeading: _phase == _Phase.idle,
        ),
        body: CosmicBackground(
          child: _phase == _Phase.scheduled
              ? _scheduledView(context)
              : _explainView(context),
        ),
      ),
    );
  }

  Widget _explainView(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final online = ref.watch(connectivityProvider).value ?? true;
    final repo = ref.watch(accountRepositoryProvider);
    final user =
        ref.watch(authUserProvider).value ??
        ref.read(authRepositoryProvider).currentUser;
    final requesting = _phase == _Phase.requesting;

    final String? blocked = repo == null
        ? l.acct_unavailable
        : user == null
        ? l.acct_signedOut
        : !online
        ? l.acct_needsConnection
        : null;
    final soft = t.bodyLarge?.copyWith(color: AuraColors.textSoft);

    Widget item(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 20, color: AuraColors.lavender),
            ),
          ),
          const SizedBox(width: AuraSpace.m),
          Expanded(child: Text(text, style: t.bodyLarge)),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.l,
        AuraSpace.gutter,
        AuraSpace.xxl,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(l.acct_deleteIntro, style: t.titleMedium),
        ),
        const SizedBox(height: AuraSpace.m),
        item(Icons.edit_note_rounded, l.acct_itemCheckIns),
        item(Icons.spa_outlined, l.acct_itemHabits),
        item(Icons.auto_awesome_outlined, l.acct_itemProgress),
        item(Icons.alternate_email_rounded, l.acct_itemAccount),
        // F4 edge case: "the confirmation states how many sealed ones will be
        // lost". Nothing when there are none.
        if ((ref.watch(sealedCapsuleCountProvider).value ?? 0) case final n
            when n > 0)
          item(Icons.lock_clock_outlined, l.capsules_accountDeletionCount(n)),
        const SizedBox(height: AuraSpace.l),
        Text(l.acct_grace, key: const ValueKey('acct-grace'), style: soft),
        const SizedBox(height: AuraSpace.m),
        Text(l.acct_store, key: const ValueKey('acct-store'), style: soft),
        const SizedBox(height: AuraSpace.m),
        Text(l.acct_phone, style: soft),
        const SizedBox(height: AuraSpace.xl),
        if (blocked != null) ...[
          InlineNotice(
            blocked,
            key: const ValueKey('acct-blocked'),
            icon: !online
                ? Icons.cloud_off_rounded
                : Icons.info_outline_rounded,
          ),
          const SizedBox(height: AuraSpace.l),
        ],
        if (_failure != null) ...[
          InlineNotice(
            _failure!,
            key: const ValueKey('acct-failed'),
            icon: Icons.error_outline_rounded,
            action: TextButton(
              key: const ValueKey('acct-retry'),
              onPressed: blocked == null ? _request : null,
              child: Text(l.acct_retry),
            ),
          ),
          const SizedBox(height: AuraSpace.l),
        ],
        // Destructive, not primary: outlined in the warm danger tone.
        OutlinedButton(
          key: const ValueKey('acct-delete'),
          style: destructiveOutlinedButtonStyle(context),
          onPressed: blocked != null || requesting ? null : _confirm,
          child: BusyButtonLabel(
            l.acct_deleteTitle,
            busy: requesting,
            icon: Icons.delete_outline_rounded,
          ),
        ),
      ],
    );
  }

  Widget _scheduledView(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final date = _scheduledFor!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.xl,
        AuraSpace.gutter,
        AuraSpace.xxl,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(l.acct_scheduledTitle, style: t.headlineSmall),
        ),
        const SizedBox(height: AuraSpace.m),
        Semantics(
          liveRegion: true,
          child: Text(
            l.acct_scheduledBody(formatAccountDate(context, date)),
            key: const ValueKey('acct-scheduled'),
            style: t.bodyLarge,
          ),
        ),
        const SizedBox(height: AuraSpace.m),
        Text(
          l.acct_phoneCleared,
          style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
        ),
        const SizedBox(height: AuraSpace.xl),
        FilledButton(
          key: const ValueKey('acct-done'),
          autofocus: true,
          onPressed: _finish,
          child: Text(l.common_done),
        ),
      ],
    );
  }
}
