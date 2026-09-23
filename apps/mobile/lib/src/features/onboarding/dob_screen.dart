import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/inline_notice.dart';
import '../support/support_sheet.dart';
import 'gate_controller.dart';
import 'onboarding_frame.dart';

/// Neutral DOB gate (F8, REQ-ACC-02): empty day, month and year pickers, no
/// default year, no copy mentioning 13 or 18. Continue stays disabled until
/// all three are set. No auth call happens before this step.
///
/// An impossible or future date is a calm [InlineNotice] (live region), not
/// lantern text: lantern is reserved for immediate support.
class DobScreen extends ConsumerStatefulWidget {
  const DobScreen({super.key});

  @override
  ConsumerState<DobScreen> createState() => _DobScreenState();
}

class _DobScreenState extends ConsumerState<DobScreen> {
  int? _day;
  int? _month;
  int? _year;
  bool _busy = false;

  /// The device's calendar date, from the shared clock (as the gate uses).
  LocalDay get _today {
    final now = ref.read(timeContextProvider).now().toLocal();
    return LocalDay(now.year, now.month, now.day);
  }

  LocalDay? get _date {
    final d = _day, m = _month, y = _year;
    if (d == null || m == null || y == null) return null;
    final dt = DateTime.utc(y, m, d);
    // Rejects impossible dates (e.g. 30 Feb rolls over to March).
    if (dt.month != m || dt.day != d) return null;
    return LocalDay(y, m, d);
  }

  bool get _complete => _day != null && _month != null && _year != null;

  bool get _future {
    final d = _date;
    return d != null && d.isAfter(_today);
  }

  Future<void> _continue() async {
    final d = _date;
    if (d == null || _future || _busy) return;
    setState(() => _busy = true);
    await ref.read(gateControllerProvider.notifier).submitBirthDate(d);
    if (mounted) setState(() => _busy = false);
  }

  Future<int?> _pick(
    String title,
    List<(int, String)> options, {
    int? selected,
    bool typeYear = false,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DobPickerSheet(
        title: title,
        options: options,
        selected: selected,
        typeYear: typeYear,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tag = ref.watch(localeControllerProvider);
    final locale = localeFromTag(tag);
    final intlLocale = locale.scriptCode == 'Latn' ? 'en' : locale.languageCode;
    String monthName(int m) {
      try {
        return DateFormat.MMMM(intlLocale).format(DateTime(2000, m));
      } catch (_) {
        return DateFormat.MMMM('en').format(DateTime(2000, m));
      }
    }

    final thisYear = _today.year;
    final error = !_complete
        ? null
        : _date == null
        ? l.dob_invalid
        : _future
        ? l.dob_future
        : null;

    return OnboardingFrame(
      onBack: ref.read(gateControllerProvider.notifier).back,
      trailing: const HelpNowButton(compact: true),
      primary: FilledButton(
        key: const ValueKey('dob-continue'),
        onPressed: _date != null && !_future && !_busy ? _continue : null,
        child: Text(l.common_continue),
      ),
      children: [
        StepTitle(l.dob_title, body: l.dob_body),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _PickerField(
                key: const ValueKey('dob-day'),
                label: l.dob_day,
                value: _day?.toString(),
                onTap: () async {
                  final v = await _pick(l.dob_day, [
                    for (var d = 1; d <= 31; d++) (d, '$d'),
                  ], selected: _day);
                  if (v != null) setState(() => _day = v);
                },
              ),
            ),
            const SizedBox(width: AuraSpace.s),
            Expanded(
              flex: 5,
              child: _PickerField(
                key: const ValueKey('dob-month'),
                label: l.dob_month,
                value: _month == null ? null : monthName(_month!),
                onTap: () async {
                  final v = await _pick(l.dob_month, [
                    for (var m = 1; m <= 12; m++) (m, monthName(m)),
                  ], selected: _month);
                  if (v != null) setState(() => _month = v);
                },
              ),
            ),
            const SizedBox(width: AuraSpace.s),
            Expanded(
              flex: 4,
              child: _PickerField(
                key: const ValueKey('dob-year'),
                label: l.dob_year,
                value: _year?.toString(),
                onTap: () async {
                  final v = await _pick(
                    l.dob_year,
                    [
                      for (var y = thisYear; y >= thisYear - 100; y--)
                        (y, '$y'),
                    ],
                    selected: _year,
                    typeYear: true,
                  );
                  if (v != null) setState(() => _year = v);
                },
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AuraSpace.m),
          InlineNotice(error, key: const ValueKey('dob-error')),
        ],
      ],
    );
  }
}

/// One DOB picker (day, month or year) in a bottom sheet.
///
/// - Header: the title (a semantic header) and a visible close button, so the
///   sheet never needs a drag to dismiss (screen-plan "Sheets").
/// - The current value carries a check and selected semantics, and is
///   scrolled into view when the sheet reopens.
/// - [typeYear]: a 4-digit field on top filters the years as they are typed
///   and Done picks a single match. It starts empty and suggests no year
///   (REQ-ACC-02).
/// - Rows share the tallest label's height (a prototype), measured at the
///   current text scale, so the list scrolls at 200% without clipping.
@visibleForTesting
class DobPickerSheet extends StatefulWidget {
  const DobPickerSheet({
    super.key,
    required this.title,
    required this.options,
    this.selected,
    this.typeYear = false,
  });

  final String title;
  final List<(int, String)> options;
  final int? selected;
  final bool typeYear;

  @override
  State<DobPickerSheet> createState() => _DobPickerSheetState();
}

class _DobPickerSheetState extends State<DobPickerSheet> {
  final _scroll = ScrollController();
  final _typed = TextEditingController();

  List<(int, String)> get _visible {
    final q = _typed.text;
    if (q.isEmpty) return widget.options;
    return [
      for (final o in widget.options)
        if (o.$2.startsWith(q)) o,
    ];
  }

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _typed.dispose();
    super.dispose();
  }

  /// Centres the current value. Every row has the prototype's height, so the
  /// row extent follows from the list's total extent.
  void _revealSelected() {
    if (!mounted || !_scroll.hasClients) return;
    final i = widget.options.indexWhere((o) => o.$1 == widget.selected);
    final pos = _scroll.position;
    if (i < 0 || pos.maxScrollExtent <= 0) return;
    final row =
        (pos.maxScrollExtent + pos.viewportDimension) / widget.options.length;
    final target = i * row - (pos.viewportDimension - row) / 2;
    _scroll.jumpTo(target.clamp(0.0, pos.maxScrollExtent));
  }

  void _submitTyped(String _) {
    final matches = _visible;
    if (_typed.text.isNotEmpty && matches.length == 1) {
      Navigator.of(context).pop(matches.single.$1);
    }
  }

  Widget _row((int, String) option, {Key? key}) {
    final selected = option.$1 == widget.selected;
    return ListTile(
      key: key,
      selected: selected,
      selectedColor: AuraColors.text,
      selectedTileColor: AuraColors.surfaceHigh,
      // Balances the check so labels stay centred.
      leading: const SizedBox(width: 24),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AuraColors.lavender)
          : const SizedBox(width: 24),
      title: Text(option.$2, textAlign: TextAlign.center),
      onTap: () => Navigator.of(context).pop(option.$1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final visible = _visible;
    final longest = widget.options.reduce(
      (a, b) => b.$2.length > a.$2.length ? b : a,
    );

    final maxHeight = (mq.size.height - mq.viewInsets.bottom) * 0.8;
    // The year sheet keeps one height while the typed year filters the list,
    // so the field does not jump under the finger.
    final steady = widget.typeYear;

    return Padding(
      // Keeps the typed-year field above the keyboard.
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: steady ? maxHeight : 0,
          maxHeight: maxHeight,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: steady ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AuraSpace.gutter,
                  0,
                  AuraSpace.s,
                  AuraSpace.s,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(widget.title, style: t.titleMedium),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('dob-sheet-close'),
                      tooltip: l.common_close,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(48),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              if (widget.typeYear)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.gutter,
                    0,
                    AuraSpace.gutter,
                    AuraSpace.m,
                  ),
                  child: TextField(
                    key: const ValueKey('dob-year-input'),
                    controller: _typed,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: l.onb_dobYearType,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _submitTyped,
                  ),
                ),
              Flexible(
                fit: steady ? FlexFit.tight : FlexFit.loose,
                child: visible.isEmpty
                    ? Align(
                        alignment: AlignmentDirectional.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AuraSpace.gutter,
                            0,
                            AuraSpace.gutter,
                            AuraSpace.l,
                          ),
                          child: InlineNotice(
                            l.onb_dobYearNoMatch,
                            key: const ValueKey('dob-year-nomatch'),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: visible.length,
                        prototypeItem: _row(longest),
                        itemBuilder: (context, i) => _row(
                          visible[i],
                          key: ValueKey('dob-option-${visible[i].$1}'),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // The merged label replaces the InkWell's semantics, so the tap action is
    // declared here too (a screen-reader double-tap opens the picker).
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: AuraColors.skyHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.m),
          side: BorderSide(
            color: value == null ? AuraColors.outline : AuraColors.lavender,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AuraRadius.m),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.m,
                vertical: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: t.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    value ?? '—',
                    style: t.titleMedium?.copyWith(
                      color: value == null
                          ? AuraColors.textMuted
                          : AuraColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
