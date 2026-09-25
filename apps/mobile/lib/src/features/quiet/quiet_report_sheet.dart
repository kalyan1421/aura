import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/busy_button_label.dart';
import '../../core/widgets/inline_notice.dart';
import '../rooms/contact_check.dart';
import '../rooms/report_sheet.dart' show ReportOutcome, reportNoteMaxChars;
import '../rooms/room_copy.dart';
import '../rooms/room_models.dart' show ReportReason;
import '../support/crisis_lexicon.dart';

/// "Report a problem here" in Quiet Together (PRD 06b table: "Session menu";
/// REQ-QUIET-06): one of the 9 reasons (F9 lanes, as in rooms), an optional
/// note for moderators, send. Nobody is shown in a session, so there is no
/// per-person report, block or mute. `null` when nothing was sent.
Future<ReportOutcome?> showQuietReportSheet(
  BuildContext context,
  Future<bool> Function(ReportReason reason, {String? note}) send,
) => showModalBottomSheet<ReportOutcome>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  builder: (_) => QuietReportSheet(send: send),
);

class QuietReportSheet extends StatefulWidget {
  const QuietReportSheet({super.key, required this.send});

  final Future<bool> Function(ReportReason reason, {String? note}) send;

  @override
  State<QuietReportSheet> createState() => _QuietReportSheetState();
}

class _QuietReportSheetState extends State<QuietReportSheet> {
  final TextEditingController _note = TextEditingController();
  ReportReason? _reason;
  bool _busy = false;
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
      final helplines = await widget.send(
        reason,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        ReportOutcome(
          reason: reason,
          showHelplines:
              helplines || (note.isNotEmpty && noteNeedsSupport(note)),
        ),
      );
    } on Object {
      if (mounted) setState(() => _error = l.quiet_reportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        key: const ValueKey('quiet-report-sheet'),
        shrinkWrap: true,
        padding: const EdgeInsets.all(AuraSpace.gutter),
        children: [
          Semantics(
            header: true,
            child: Text(l.quiet_report, style: t.titleLarge),
          ),
          const SizedBox(height: AuraSpace.s),
          Text(
            l.quiet_reportBody,
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.m),
          for (final r in ReportReason.values)
            Semantics(
              selected: r == _reason,
              inMutuallyExclusiveGroup: true,
              button: true,
              child: ListTile(
                key: ValueKey('quiet-reason-${r.wire}'),
                leading: Icon(
                  r == _reason
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: AuraColors.lavender,
                ),
                title: Text(reportReasonLabel(l, r)),
                onTap: _busy ? null : () => setState(() => _reason = r),
              ),
            ),
          const SizedBox(height: AuraSpace.s),
          TextField(
            key: const ValueKey('quiet-report-note'),
            controller: _note,
            maxLength: reportNoteMaxChars,
            minLines: 1,
            maxLines: 4,
            onChanged: (_) {
              if (_contact) setState(() => _contact = false);
            },
            decoration: InputDecoration(labelText: l.quiet_reportNote),
          ),
          if (_contact) InlineNotice(l.rooms_reportNoteContact),
          if (_error != null)
            InlineNotice(_error!, key: const ValueKey('quiet-report-error')),
          const SizedBox(height: AuraSpace.m),
          FilledButton(
            key: const ValueKey('quiet-report-send'),
            onPressed: _reason == null || _busy ? null : _send,
            child: BusyButtonLabel(l.quiet_reportSend, busy: _busy),
          ),
        ],
      ),
    );
  }
}
