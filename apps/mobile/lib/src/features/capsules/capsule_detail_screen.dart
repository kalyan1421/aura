import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/busy_button_label.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../../core/widgets/inline_notice.dart';
import 'capsule_format.dart';
import 'capsule_opening.dart';
import 'capsule_providers.dart';
import 'capsule_repository.dart';
import 'capsules_list_screen.dart' show CapsuleSealGlyph;

/// Opens capsule [id]'s page (a Navigator route; the lead can map it to
/// `/sanctuary/capsules/:id`).
Future<void> openCapsuleDetail(BuildContext context, String id) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => CapsuleDetailScreen(id: id)),
    );

/// A capsule's page. Sealed: its title and "Sealed until 12 Oct 2027. It'll
/// keep." (or the feeling it waits for) — never the content, never an early
/// open ("sealed means sealed", PRD 14-states). Opened: the content, to read
/// again. Delete is always there (confirm; never shows content). A mood
/// capsule the server couldn't keep (Free limit) can become a date capsule.
class CapsuleDetailScreen extends ConsumerWidget {
  const CapsuleDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final row = ref.watch(capsuleProvider(id)).value;
    final payload = row == null
        ? null
        : ref.watch(capsulePayloadProvider(row)).value;
    final Widget body;
    if (row == null || row.deletedAt != null) {
      body = const SizedBox.expand();
    } else if (row.openedAt != null && payload != null) {
      body = CapsuleOpenedView(
        row: row,
        payload: payload,
        showKeep: true,
        footer: _DeleteButton(row: row),
      );
    } else {
      body = _Sealed(row: row);
    }
    return Scaffold(
      appBar: helpAppBar(context, title: l.capsules_title),
      body: CosmicBackground(child: body),
    );
  }
}

class _Sealed extends ConsumerStatefulWidget {
  const _Sealed({required this.row});

  final CapsuleRow row;

  @override
  ConsumerState<_Sealed> createState() => _SealedState();
}

class _SealedState extends ConsumerState<_Sealed> {
  bool _converting = false;
  bool _dateProblem = false;

  /// "Make it a date capsule": the same capsule, sealed again as `date`.
  Future<void> _makeDate() async {
    final l = AppLocalizations.of(context);
    final time = ref.read(timeContextProvider);
    final w = unlockWindowFor(time.now(), time.timezone);
    DateTime at(LocalDay d) => DateTime(d.year, d.month, d.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: at(w.first),
      lastDate: at(w.last),
      initialDate: at(
        w.first.addDays(23).isAfter(w.last) ? w.last : w.first.addDays(23),
      ),
      helpText: l.capsules_datePickerHelp,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _converting = true;
      _dateProblem = false;
    });
    final repo = ref.read(capsuleRepositoryProvider);
    final sync = ref.read(syncControllerProvider);
    try {
      await repo.convertToDate(
        widget.row.id,
        LocalDay(picked.year, picked.month, picked.day),
      );
      sync.notifyLocalWrite();
    } on CapsuleUnlockOutOfRange {
      if (mounted) setState(() => _dateProblem = true);
    } on CapsuleNotOpenable {
      // Deleted or opened meanwhile: the page follows the row.
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tag = ref.watch(localeControllerProvider);
    final tz = ref.watch(deviceTimezoneProvider);
    final now =
        ref.watch(nowProvider).value ?? ref.read(timeContextProvider).now();
    final row = widget.row;
    final payload = ref.watch(capsulePayloadProvider(row)).value;
    final date = unlockDateOf(row);
    final target = moodTargetOf(row);
    final ready = isCapsuleReady(row, tz, now);
    final soft = t.bodyMedium?.copyWith(color: AuraColors.textSoft);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.xl,
        AuraSpace.gutter,
        AuraSpace.xxl,
      ),
      children: [
        Center(child: CapsuleSealGlyph(size: 64, tint: ceremonyTintOf(row))),
        const SizedBox(height: AuraSpace.l),
        Semantics(
          header: true,
          child: Text(
            capsuleTitleOf(l, tag, row, payload, tz),
            key: const ValueKey('capsule-detail-title'),
            textAlign: TextAlign.center,
            style: t.headlineSmall,
          ),
        ),
        const SizedBox(height: AuraSpace.s),
        if (date != null)
          Text(
            l.capsules_sealedUntil(capsuleDateLabel(tag, date)),
            key: const ValueKey('capsule-detail-status'),
            textAlign: TextAlign.center,
            style: t.bodyLarge,
          )
        else if (target != null) ...[
          Text(
            l.capsules_detailFeeling(feelingLabel(l, tag, target)),
            key: const ValueKey('capsule-detail-status'),
            textAlign: TextAlign.center,
            style: t.bodyLarge,
          ),
          if (row.armedAt != null && row.armedAt!.isAfter(now)) ...[
            const SizedBox(height: AuraSpace.xs),
            Text(
              l.capsules_detailArming(
                capsuleMomentLabel(context, tag, row.armedAt!, tz),
              ),
              key: const ValueKey('capsule-detail-arming'),
              textAlign: TextAlign.center,
              style: soft,
            ),
          ],
        ],
        const SizedBox(height: AuraSpace.xs),
        Text(
          l.capsules_sealedOn(capsuleDayOf(tag, row.sealedAt, tz)),
          textAlign: TextAlign.center,
          style: soft,
        ),
        const SizedBox(height: AuraSpace.xl),
        if (row.rejected != null) ...[
          InlineNotice(
            l.capsules_limitBody,
            key: const ValueKey('capsule-detail-limit'),
          ),
          if (_dateProblem) ...[
            const SizedBox(height: AuraSpace.s),
            InlineNotice(l.capsules_dateHelp),
          ],
          const SizedBox(height: AuraSpace.m),
          FilledButton(
            key: const ValueKey('capsule-make-date'),
            onPressed: _converting ? null : _makeDate,
            child: BusyButtonLabel(
              l.capsules_makeDate,
              busy: _converting,
              icon: Icons.event_outlined,
            ),
          ),
        ] else if (ready)
          FilledButton(
            key: const ValueKey('capsule-detail-open'),
            onPressed: () => openCapsule(context, row.id),
            child: Text(l.capsules_readyOpen),
          )
        else
          InlineNotice(
            l.capsules_detailNoEarly,
            key: const ValueKey('capsule-detail-no-early'),
            icon: Icons.lock_outline_rounded,
          ),
        const SizedBox(height: AuraSpace.xl),
        _DeleteButton(row: row),
      ],
    );
  }
}

/// Delete (any time, after a confirmation). Never shows the content.
class _DeleteButton extends ConsumerStatefulWidget {
  const _DeleteButton({required this.row});

  final CapsuleRow row;

  @override
  ConsumerState<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends ConsumerState<_DeleteButton> {
  bool _busy = false;

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final opened = widget.row.openedAt != null;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.capsules_deleteTitle),
        content: Text(
          opened ? l.capsules_deleteBodyOpened : l.capsules_deleteBody,
        ),
        actions: [
          TextButton(
            key: const ValueKey('capsule-delete-keep'),
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.capsules_deleteKeep),
          ),
          TextButton(
            key: const ValueKey('capsule-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.capsules_deleteConfirm),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    final repo = ref.read(capsuleRepositoryProvider);
    final sync = ref.read(syncControllerProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    await repo.delete(widget.row.id);
    sync.notifyLocalWrite();
    messenger?.showSnackBar(SnackBar(content: Text(l.capsules_deleted)));
    if (navigator.mounted) unawaited(navigator.maybePop());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Align(
      child: OutlinedButton(
        key: const ValueKey('capsule-delete'),
        onPressed: _busy ? null : _delete,
        child: BusyButtonLabel(
          l.capsules_delete,
          busy: _busy,
          icon: Icons.delete_outline_rounded,
        ),
      ),
    );
  }
}
