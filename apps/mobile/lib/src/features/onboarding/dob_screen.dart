import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/aura_tokens.dart';
import 'gate_controller.dart';
import 'onboarding_frame.dart';

/// Neutral DOB gate (F8, REQ-ACC-02): empty day, month and year pickers, no
/// default year, no copy mentioning 13 or 18. Continue stays disabled until
/// all three are set. No auth call happens before this step.
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
    if (d == null) return false;
    final now = DateTime.now();
    return d.isAfter(LocalDay(now.year, now.month, now.day));
  }

  Future<void> _continue() async {
    final d = _date;
    if (d == null || _future || _busy) return;
    setState(() => _busy = true);
    await ref.read(gateControllerProvider.notifier).submitBirthDate(d);
    if (mounted) setState(() => _busy = false);
  }

  Future<int?> _pick(String title, List<(int, String)> options) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AuraSpace.s),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, i) => ListTile(
                    key: ValueKey('dob-option-${options[i].$1}'),
                    title: Text(options[i].$2, textAlign: TextAlign.center),
                    onTap: () => Navigator.of(context).pop(options[i].$1),
                  ),
                ),
              ),
            ],
          ),
        ),
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

    final thisYear = DateTime.now().year;
    final error = !_complete
        ? null
        : _date == null
        ? l.dob_invalid
        : _future
        ? l.dob_future
        : null;

    return OnboardingFrame(
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
                  ]);
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
                  ]);
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
                  final v = await _pick(l.dob_year, [
                    for (var y = thisYear; y >= thisYear - 100; y--) (y, '$y'),
                  ]);
                  if (v != null) setState(() => _year = v);
                },
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AuraSpace.m),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AuraColors.lantern,
            ),
          ),
        ],
      ],
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
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: t.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    value ?? '—',
                    style: t.titleMedium?.copyWith(
                      color: value == null ? AuraColors.textMuted : AuraColors.text,
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
