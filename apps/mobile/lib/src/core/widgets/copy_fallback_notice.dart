import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../theme/aura_tokens.dart';

/// Calm inline note for when this device couldn't open something (the
/// browser for a legal page, the dialer for a helpline), with the address
/// or number and a Copy action. Stays until closed; announced once when it
/// appears (live region). Never uses `lantern` (not a crisis cue) and
/// never blames the person.
///
/// Used by the legal links, the support sheet's helplines and the under-13
/// screen's helpline buttons.
class CopyFallbackNotice extends StatefulWidget {
  const CopyFallbackNotice({
    super.key,
    required this.message,
    required this.copyText,
    required this.copyLabel,
    required this.copiedLabel,
    required this.onClose,
  });

  final String message;

  /// Put on the clipboard by the Copy action (a public URL or helpline
  /// number, never personal data).
  final String copyText;
  final String copyLabel;
  final String copiedLabel;
  final VoidCallback onClose;

  @override
  State<CopyFallbackNotice> createState() => _CopyFallbackNoticeState();
}

class _CopyFallbackNoticeState extends State<CopyFallbackNotice> {
  bool _copied = false;

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.copyText));
    } on Object catch (e) {
      debugPrint('notice: copy failed (${e.runtimeType})');
      return;
    }
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AuraSpace.m,
        AuraSpace.xs,
        AuraSpace.xs,
        AuraSpace.xs,
      ),
      decoration: BoxDecoration(
        color: AuraColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AuraRadius.m),
        border: Border.all(color: AuraColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: AuraSpace.m + 2),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AuraColors.lavender,
                ),
              ),
              const SizedBox(width: AuraSpace.s),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AuraSpace.m),
                  child: Semantics(
                    liveRegion: true,
                    container: true,
                    child: Text(
                      widget.message,
                      style: t.bodyMedium?.copyWith(color: AuraColors.text),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: l.common_close,
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          // Lined up under the message; announced when it changes to
          // "… copied".
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 14),
            child: MergeSemantics(
              child: Semantics(
                liveRegion: true,
                child: TextButton.icon(
                  onPressed: _copy,
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 18,
                  ),
                  label: Text(_copied ? widget.copiedLabel : widget.copyLabel),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
