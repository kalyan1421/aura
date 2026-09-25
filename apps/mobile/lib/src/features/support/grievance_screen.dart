import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/env/env.dart';
import '../../core/l10n/locale_controller.dart' show tagFromLocale;
import '../../core/net/aura_api.dart' show ApiException;
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/busy_button_label.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../../core/widgets/inline_notice.dart';
import '../plus/plus_format.dart' show plusDate;
import 'grievance_api.dart';

/// Localized label of a [GrievanceCategory].
String grievanceCategoryLabel(AppLocalizations l, GrievanceCategory c) =>
    switch (c) {
      GrievanceCategory.general => l.grievance_catGeneral,
      GrievanceCategory.unlawfulContent => l.grievance_catUnlawful,
      GrievanceCategory.nudityCsam => l.grievance_catNudity,
      GrievanceCategory.ncii => l.grievance_catNcii,
      GrievanceCategory.dataRequest => l.grievance_catData,
      GrievanceCategory.moderationAppeal => l.grievance_catAppeal,
    };

/// A plausible address (the server validates it properly).
bool plausibleEmail(String s) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s.trim());

/// The Grievance Officer's in-app form (PRD F9 "Grievance Officer … ticketed
/// form, auto-acknowledged", PRD 19 "the in-app form and email both open a
/// console ticket"; REQ-SAFE-11). Also the in-app way to ask for a review of
/// a moderation decision ("one appeal per action, resolved in 7 days";
/// category [GrievanceCategory.moderationAppeal]).
///
/// Works signed out, on a closed account and on a banned device (the route
/// is public). Needs a connection; on any failure the words stay in the form.
/// Sending answers at once with the ticket id and the date it will be
/// resolved by, and the server emails the same acknowledgement. Nothing typed
/// here is stored on the phone or logged.
class GrievanceFormScreen extends ConsumerStatefulWidget {
  const GrievanceFormScreen({
    super.key,
    this.initialCategory = GrievanceCategory.general,
  });

  final GrievanceCategory initialCategory;

  static Route<void> route({
    GrievanceCategory category = GrievanceCategory.general,
  }) => MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'grievance'),
    builder: (_) => GrievanceFormScreen(initialCategory: category),
  );

  @override
  ConsumerState<GrievanceFormScreen> createState() =>
      _GrievanceFormScreenState();
}

class _GrievanceFormScreenState extends ConsumerState<GrievanceFormScreen> {
  late GrievanceCategory _category = widget.initialCategory;
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _where = TextEditingController();
  bool _busy = false;
  String? _error;
  GrievanceReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    // The account's own address, if signed in; the person can change it.
    final email = ref.read(authRepositoryProvider).currentUser?.email;
    if (email != null) _email.text = email;
    _description.addListener(_onChanged);
    _email.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _description.dispose();
    _where.dispose();
    super.dispose();
  }

  bool get _valid =>
      plausibleEmail(_email.text) &&
      _description.text.trim().length >= GrievanceLimits.descriptionMin;

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final api = ref.read(grievanceApiProvider);
    if (api == null || !_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await api.submit(
        category: _category,
        email: _email.text.trim(),
        description: _description.text.trim(),
        name: _name.text.trim(),
        where: _where.text.trim(),
        locale: tagFromLocale(Localizations.localeOf(context)),
      );
      if (!mounted) return;
      setState(() => _receipt = receipt);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.isNetwork
            ? l.grievance_offline
            : e.status == 429
            ? l.grievance_rateLimited
            : e.status == 400
            ? l.grievance_checkFields
            : l.grievance_failed,
      );
    } on Object {
      if (mounted) setState(() => _error = l.grievance_failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: helpAppBar(context, title: l.grievance_title),
      body: CosmicBackground(
        child: SafeArea(
          top: false,
          child: _receipt == null ? _form(context, l) : _done(context, l),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, AppLocalizations l) {
    final t = Theme.of(context).textTheme;
    final officer = Env.grievanceOfficerName;
    final hasApi = ref.watch(grievanceApiProvider) != null;
    return ListView(
      key: const ValueKey('grievance-form'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AuraSpace.gutter,
        AuraSpace.s,
        AuraSpace.gutter,
        AuraSpace.xxl,
      ),
      children: [
        Text(
          officer.isEmpty ? l.grievance_intro : l.grievance_introNamed(officer),
          style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
        ),
        const SizedBox(height: AuraSpace.l),
        Semantics(
          header: true,
          child: Text(l.grievance_categoryTitle, style: t.titleSmall),
        ),
        const SizedBox(height: AuraSpace.xs),
        RadioGroup<GrievanceCategory>(
          groupValue: _category,
          onChanged: (c) {
            if (c != null && !_busy) setState(() => _category = c);
          },
          child: Column(
            children: [
              for (final c in GrievanceCategory.values)
                RadioListTile<GrievanceCategory>(
                  key: ValueKey('grievance-cat-${c.wire}'),
                  value: c,
                  contentPadding: EdgeInsets.zero,
                  title: Text(grievanceCategoryLabel(l, c)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.m),
        TextField(
          key: const ValueKey('grievance-description'),
          controller: _description,
          enabled: !_busy,
          minLines: 4,
          maxLines: 10,
          maxLength: GrievanceLimits.descriptionMax,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.grievance_descriptionLabel,
            hintText: _category == GrievanceCategory.moderationAppeal
                ? l.grievance_appealHint
                : l.grievance_descriptionHint,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AuraSpace.s),
        TextField(
          key: const ValueKey('grievance-where'),
          controller: _where,
          enabled: !_busy,
          maxLength: GrievanceLimits.whereMax,
          decoration: InputDecoration(
            labelText: l.grievance_whereLabel,
            hintText: l.grievance_whereHint,
          ),
        ),
        const SizedBox(height: AuraSpace.s),
        TextField(
          key: const ValueKey('grievance-email'),
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          inputFormatters: [
            LengthLimitingTextInputFormatter(GrievanceLimits.emailMax),
          ],
          decoration: InputDecoration(
            labelText: l.grievance_emailLabel,
            helperText: l.grievance_emailHelp,
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: AuraSpace.m),
        TextField(
          key: const ValueKey('grievance-name'),
          controller: _name,
          enabled: !_busy,
          autofillHints: const [AutofillHints.name],
          inputFormatters: [
            LengthLimitingTextInputFormatter(GrievanceLimits.nameMax),
          ],
          decoration: InputDecoration(labelText: l.grievance_nameLabel),
        ),
        const SizedBox(height: AuraSpace.l),
        if (_error != null) ...[
          InlineNotice(
            _error!,
            key: const ValueKey('grievance-error'),
            icon: Icons.error_outline_rounded,
          ),
          const SizedBox(height: AuraSpace.m),
        ],
        if (!hasApi) ...[
          InlineNotice(
            l.grievance_noApi,
            key: const ValueKey('grievance-no-api'),
          ),
          const SizedBox(height: AuraSpace.m),
        ],
        FilledButton(
          key: const ValueKey('grievance-send'),
          onPressed: _busy || !_valid || !hasApi ? null : _send,
          child: BusyButtonLabel(l.grievance_send, busy: _busy),
        ),
        const SizedBox(height: AuraSpace.m),
        Text(
          l.grievance_timelines,
          style: t.bodySmall?.copyWith(color: AuraColors.textMuted),
        ),
      ],
    );
  }

  Widget _done(BuildContext context, AppLocalizations l) {
    final t = Theme.of(context).textTheme;
    final receipt = _receipt!;
    return ListView(
      key: const ValueKey('grievance-receipt'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AuraSpace.gutter,
        AuraSpace.l,
        AuraSpace.gutter,
        AuraSpace.xxl,
      ),
      children: [
        const ExcludeSemantics(
          child: Icon(
            Icons.mark_email_read_outlined,
            size: 48,
            color: AuraColors.starlight,
          ),
        ),
        const SizedBox(height: AuraSpace.l),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(l.grievance_sentTitle, style: t.headlineSmall),
        ),
        const SizedBox(height: AuraSpace.m),
        SelectableText(
          l.grievance_ticket(receipt.ticket),
          key: const ValueKey('grievance-ticket'),
          style: t.titleMedium,
        ),
        const SizedBox(height: AuraSpace.s),
        Text(
          l.grievance_sentBody(
            plusDate(context, receipt.resolveBy),
            _email.text.trim(),
          ),
          style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
        ),
        const SizedBox(height: AuraSpace.m),
        Text(
          l.grievance_gac,
          style: t.bodySmall?.copyWith(color: AuraColors.textMuted),
        ),
        const SizedBox(height: AuraSpace.xl),
        FilledButton(
          key: const ValueKey('grievance-done'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l.common_done),
        ),
      ],
    );
  }
}
