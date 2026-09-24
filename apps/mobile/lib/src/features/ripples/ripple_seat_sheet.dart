import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/busy_button_label.dart';
import '../../core/widgets/inline_notice.dart';
import '../rooms/contact_check.dart' show containsContactDetails;
import '../rooms/room_copy.dart' show reportReasonLabel;
import '../rooms/room_models.dart' show ReportReason;
import '../support/crisis_lexicon.dart' show noteNeedsSupport;
import 'ripple_controller.dart';

/// What happened in a light's sheet.
enum SeatSheetResult { muted, unmuted, blocked, reported, helpNow }

/// Tap a light: mute, block, report — all three in ≤ 2 taps (PRD 06b
/// "Breath Ripples HUD: Tap a light: all three"). Echoes and guides are never
/// people, so they have no sheet. No gift, purchase or upsell anywhere
/// (REQ-GAME-08).
Future<SeatSheetResult?> showSeatSheet(
  BuildContext context, {
  required RippleController controller,
  required int seat,
  required String name,
}) => showModalBottomSheet<SeatSheetResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  builder: (_) => _SeatSheet(controller: controller, seat: seat, name: name),
);

class _SeatSheet extends StatefulWidget {
  const _SeatSheet({
    required this.controller,
    required this.seat,
    required this.name,
  });

  final RippleController controller;
  final int seat;
  final String name;

  @override
  State<_SeatSheet> createState() => _SeatSheetState();
}

class _SeatSheetState extends State<_SeatSheet> {
  final TextEditingController _note = TextEditingController();
  bool _reporting = false;
  ReportReason? _reason;
  bool _busy = false;
  bool _contact = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _block() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await widget.controller.block(widget.seat);
      if (mounted) Navigator.of(context).pop(SeatSheetResult.blocked);
    } on Object {
      if (mounted) setState(() => _error = l.ripples_actionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      final help = await widget.controller.report(
        widget.seat,
        reason.wire,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        help || (note.isNotEmpty && noteNeedsSupport(note))
            ? SeatSheetResult.helpNow
            : SeatSheetResult.reported,
      );
    } on Object {
      if (mounted) setState(() => _error = l.ripples_actionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final muted = widget.controller.muted.contains(widget.seat);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const ValueKey('ripple-seat-sheet'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AuraSpace.gutter,
          AuraSpace.m,
          AuraSpace.gutter,
          AuraSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                l.ripples_lightHuman(widget.name),
                style: t.titleLarge,
              ),
            ),
            const SizedBox(height: AuraSpace.l),
            if (!_reporting) ...[
              OutlinedButton.icon(
                key: const ValueKey('ripple-mute'),
                onPressed: _busy
                    ? null
                    : () {
                        widget.controller.setMuted(widget.seat, !muted);
                        Navigator.of(context).pop(
                          muted
                              ? SeatSheetResult.unmuted
                              : SeatSheetResult.muted,
                        );
                      },
                icon: Icon(
                  muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                ),
                label: Text(muted ? l.ripples_unmute : l.ripples_mute),
              ),
              const SizedBox(height: AuraSpace.s),
              OutlinedButton.icon(
                key: const ValueKey('ripple-block'),
                onPressed: _busy ? null : _block,
                icon: const Icon(Icons.block_rounded),
                label: BusyButtonLabel(l.ripples_block, busy: _busy),
              ),
              const SizedBox(height: AuraSpace.s),
              OutlinedButton.icon(
                key: const ValueKey('ripple-report'),
                onPressed: _busy
                    ? null
                    : () => setState(() => _reporting = true),
                icon: const Icon(Icons.flag_outlined),
                label: Text(l.ripples_report),
              ),
            ] else ...[
              Text(
                l.rooms_reportWhy,
                style: t.titleSmall?.copyWith(color: AuraColors.textSoft),
              ),
              const SizedBox(height: AuraSpace.s),
              for (final r in ReportReason.values)
                Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: r == _reason,
                  button: true,
                  label: reportReasonLabel(l, r),
                  excludeSemantics: true,
                  child: InkWell(
                    key: ValueKey('ripple-reason-${r.wire}'),
                    onTap: _busy ? null : () => setState(() => _reason = r),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        children: [
                          Icon(
                            r == _reason
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: r == _reason
                                ? AuraColors.accent
                                : AuraColors.textSoft,
                          ),
                          const SizedBox(width: AuraSpace.m),
                          Expanded(child: Text(reportReasonLabel(l, r))),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AuraSpace.m),
              TextField(
                key: const ValueKey('ripple-report-note'),
                controller: _note,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                maxLength: 200,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
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
              const SizedBox(height: AuraSpace.m),
              FilledButton(
                key: const ValueKey('ripple-report-send'),
                onPressed: _reason == null || _busy ? null : _send,
                child: BusyButtonLabel(l.rooms_reportSend, busy: _busy),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AuraSpace.m),
              InlineNotice(_error!, key: const ValueKey('ripple-sheet-error')),
            ],
          ],
        ),
      ),
    );
  }
}
