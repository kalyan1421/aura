import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/l10n/locale_controller.dart' show tagFromLocale;
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/busy_button_label.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../../core/widgets/inline_notice.dart';
import '../plus/plus_format.dart' show plusDate;
import 'data_export.dart';

/// Settings › Account › "Download a copy of my data" (F8 REQ-ACC-12). Says
/// what the copy holds and doesn't, that the files aren't encrypted, then
/// builds it on the phone and hands it to the share sheet. A failure keeps
/// nothing half-made and offers a retry (PRD 14 "Settings and data export").
class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

enum _Phase { idle, busy, done, failed }

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  _Phase _phase = _Phase.idle;
  final _button = GlobalKey();

  Future<void> _make() async {
    final l = AppLocalizations.of(context);
    final localeTag = tagFromLocale(Localizations.localeOf(context));
    final now = DateTime.now();
    final labels = ExportLabels(
      title: l.export_hTitle,
      exported: l.export_hExported(plusDate(context, now)),
      checkIns: l.export_hCheckIns,
      habits: l.export_hHabits,
      capsules: l.export_hCapsules,
      account: l.export_hAccount,
      reflections: l.export_hReflections,
      sanctuary: l.export_hSanctuary,
      sealed: l.export_sealed,
      voiceNote: l.export_voiceNote,
      nothing: l.export_nothing,
      commitmentSince: l.export_hCommitment,
      pausedUntil: l.export_hPausedUntil,
    );
    final box = _button.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _phase = _Phase.busy);
    try {
      final files = await ref.read(dataExportProvider)(labels, localeTag);
      await ref
          .read(exportShareProvider)
          .share(files, text: l.export_shareText, origin: origin);
      if (mounted) setState(() => _phase = _Phase.done);
    } on Object catch (e) {
      debugPrint('export: ${e.runtimeType}');
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final busy = _phase == _Phase.busy;
    return Scaffold(
      appBar: helpAppBar(context, title: l.export_title),
      body: CosmicBackground(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AuraSpace.gutter,
            AuraSpace.s,
            AuraSpace.gutter,
            AuraSpace.xxl,
          ),
          children: [
            Text(l.export_body, style: t.bodyLarge),
            const SizedBox(height: AuraSpace.m),
            Text(
              l.export_where,
              style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
            ),
            const SizedBox(height: AuraSpace.s),
            Text(
              l.export_media,
              style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
            ),
            const SizedBox(height: AuraSpace.l),
            InlineNotice(
              l.export_private,
              key: const ValueKey('export-private'),
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: AuraSpace.xl),
            FilledButton(
              key: _button,
              onPressed: busy ? null : _make,
              child: BusyButtonLabel(
                busy ? l.export_busy : l.export_make,
                busy: busy,
              ),
            ),
            if (_phase == _Phase.done) ...[
              const SizedBox(height: AuraSpace.m),
              InlineNotice(
                l.export_done,
                key: const ValueKey('export-done'),
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
            if (_phase == _Phase.failed) ...[
              const SizedBox(height: AuraSpace.m),
              InlineNotice(
                l.export_failed,
                key: const ValueKey('export-failed'),
                icon: Icons.cloud_off_outlined,
                action: TextButton(
                  key: const ValueKey('export-retry'),
                  onPressed: _make,
                  child: Text(l.acct_retry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
