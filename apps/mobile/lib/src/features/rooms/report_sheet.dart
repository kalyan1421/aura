import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/busy_button_label.dart';
import '../../core/widgets/inline_notice.dart';
import '../support/crisis_lexicon.dart';
import '../support/support_sheet.dart';
import 'contact_check.dart';
import 'room_copy.dart';
import 'room_models.dart';
import 'rooms_providers.dart';
import 'rooms_repository.dart';

/// The report note's length (the server allows 500; the app asks for less).
const int reportNoteMaxChars = 200;

/// How a report ended (it was sent).
@immutable
class ReportOutcome {
  const ReportOutcome({required this.reason, required this.showHelplines});

  final ReportReason reason;

  /// Open the Safety Center now: the crisis lane (reason 1, the server's
  /// `showHelplines`), or crisis words in the reporter's own note.
  final bool showHelplines;
}

/// Report flow (F9 REQ-SAFE-05): one of 8 reasons, an optional note for
/// moderators, send. Opened from the member sheet, the room menu ("Report a
/// problem here") and a received gesture. `null` when nothing was sent.
Future<ReportOutcome?> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  String? pseudonym,
}) => showModalBottomSheet<ReportOutcome>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  builder: (_) => ReportSheet(target: target, pseudonym: pseudonym),
);

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.target, this.pseudonym});

  final ReportTarget target;

  /// The member's pseudonym (member reports).
  final String? pseudonym;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final TextEditingController _note = TextEditingController();
  ReportReason? _reason;
  bool _busy = false;

  /// The note holds contact details: nothing is sent (on-device check).
  bool _contact = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _busy) return;
    final l = AppLocalizations.of(context);
    final note = _note.text.trim();
    if (note.isNotEmpty && containsContactDetails(note)) {
      setState(() => _contact = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ack = await ref
          .read(roomsRepositoryProvider)
          .report(widget.target, reason, note: note.isEmpty ? null : note);
      if (!mounted) return;
      Navigator.of(context).pop(
        ReportOutcome(
          reason: reason,
          showHelplines:
              ack.showHelplines || (note.isNotEmpty && noteNeedsSupport(note)),
        ),
      );
    } on RoomsFailure catch (f) {
      if (!mounted) return;
      setState(
        () => _error = switch (f.kind) {
          RoomsFailureKind.offline => l.rooms_reportOffline,
          RoomsFailureKind.reportLimit => l.rooms_reportLimit,
          _ => l.rooms_reportFailed,
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _title(AppLocalizations l) => switch (widget.target) {
    MemberReportTarget() => l.rooms_reportMember(widget.pseudonym ?? ''),
    GestureReportTarget() => l.rooms_reportGesture,
    RoomReportTarget() => l.rooms_reportRoom,
    ReflectionReportTarget() => l.reflections_reportTitle,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const ValueKey('report-sheet'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AuraSpace.gutter,
          0,
          AuraSpace.gutter,
          AuraSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AuraSpace.m),
                    child: Semantics(
                      header: true,
                      child: Text(_title(l), style: t.titleLarge),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('report-close'),
                  tooltip: l.common_close,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s),
            Text(
              l.rooms_reportWhy,
              style: t.titleSmall?.copyWith(color: AuraColors.textSoft),
            ),
            const SizedBox(height: AuraSpace.s),
            for (final r in ReportReason.values)
              _ReasonRow(
                reason: r,
                selected: r == _reason,
                onTap: _busy ? null : () => setState(() => _reason = r),
              ),
            const SizedBox(height: AuraSpace.l),
            TextField(
              key: const ValueKey('report-note'),
              controller: _note,
              enabled: !_busy,
              minLines: 2,
              maxLines: 5,
              maxLength: reportNoteMaxChars,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_contact) setState(() => _contact = false);
              },
              decoration: InputDecoration(
                labelText: l.rooms_reportNoteLabel,
                helperText: l.rooms_reportNoteHelp,
                helperMaxLines: 4,
                errorText: _contact ? l.rooms_reportNoteContact : null,
                errorMaxLines: 4,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AuraSpace.m),
              InlineNotice(
                _error!,
                key: const ValueKey('report-error'),
                // Help never waits on a report going through.
                action: _reason == ReportReason.inDanger
                    ? const Padding(
                        padding: EdgeInsets.only(top: AuraSpace.s),
                        child: HelpNowButton(compact: true),
                      )
                    : null,
              ),
            ],
            const SizedBox(height: AuraSpace.l),
            // Why Send is still off: a reason comes first.
            if (_reason == null) ...[
              Text(
                l.rooms_reportPickReason,
                key: const ValueKey('report-pick-reason'),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AuraColors.textSoft),
              ),
              const SizedBox(height: AuraSpace.s),
            ],
            FilledButton(
              key: const ValueKey('report-send'),
              onPressed: _reason == null || _busy ? null : _send,
              child: BusyButtonLabel(l.rooms_reportSend, busy: _busy),
            ),
          ],
        ),
      ),
    );
  }
}

/// One reason: a full-width row (≥ 48 dp) that reads as a radio choice.
class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final ReportReason reason;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = reportReasonLabel(l, reason);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('report-reason-${reason.wire}'),
        borderRadius: BorderRadius.circular(AuraRadius.s),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AuraSpace.s),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AuraColors.accent : AuraColors.textSoft,
                ),
                const SizedBox(width: AuraSpace.m),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
