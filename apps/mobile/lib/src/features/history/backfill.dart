import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../checkin/checkin_repository.dart' show maxBackfillDays;
import '../checkin/checkin_screen.dart';
import '../sanctuary/calm_route.dart';
import 'history_format.dart';

/// The Aura days a past check-in can be added for on [today]: yesterday
/// back to [maxBackfillDays] days ago, newest first (F1 backfill).
List<LocalDay> backfillDays(LocalDay today) => [
  for (var back = 1; back <= maxBackfillDays; back++) today.addDays(-back),
];

/// The day of a past check-in as a full date ("Tuesday, October 6"), never
/// "Yesterday", so it reads well inside a sentence.
String backfillDayLabel(String localeTag, LocalDay day) =>
    dateLabel(localeTag, day, day);

/// History › "Add a past check-in": pick a day (the last 7), then the usual
/// mood grid and details for that day ([CheckInScreen.backfillDay]). Back
/// in History afterwards, where it shows under its day.
Future<void> addPastCheckIn(BuildContext context, WidgetRef ref) async {
  final day = await pickBackfillDay(context, ref);
  if (day == null || !context.mounted) return;
  await pushCalm<void>(context, (_) => CheckInScreen(backfillDay: day));
}

/// "Which day?": a sheet listing yesterday and the 6 days before it (Aura
/// days, so it follows the 04:00 rollover). Returns the picked day, or
/// `null` when closed. [selected] is marked when changing a day.
Future<LocalDay?> pickBackfillDay(
  BuildContext context,
  WidgetRef ref, {
  LocalDay? selected,
}) {
  final today = ref.read(timeContextProvider).today();
  final localeTag = ref.read(localeControllerProvider);
  return showModalBottomSheet<LocalDay>(
    context: context,
    // Over the navigation bar too: a modal never leaves the tabs tappable.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _DayPicker(
      days: backfillDays(today),
      today: today,
      localeTag: localeTag,
      selected: selected,
    ),
  );
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.days,
    required this.today,
    required this.localeTag,
    this.selected,
  });

  final List<LocalDay> days;
  final LocalDay today;
  final String localeTag;
  final LocalDay? selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AuraSpace.gutter,
          0,
          AuraSpace.gutter,
          AuraSpace.xl,
        ),
        children: [
          // An explicit Close: never rely on drag or the scrim alone.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AuraSpace.s),
                  child: Semantics(
                    header: true,
                    child: Text(l.backfill_pickTitle, style: t.headlineSmall),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('backfill-pick-close'),
                tooltip: l.common_close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.xs),
          Text(
            l.backfill_pickBody(maxBackfillDays),
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.l),
          for (final day in days)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s),
              child: Material(
                color: AuraColors.surface.withValues(alpha: 0.85),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.m),
                  side: BorderSide(
                    color: day == selected
                        ? AuraColors.lavender
                        : AuraColors.hairline,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: ValueKey('backfill-day-${day.toIso()}'),
                  minTileHeight: 56,
                  selected: day == selected,
                  title: Text(historyDayLabel(l, localeTag, day, today)),
                  trailing: day == selected
                      ? const Icon(Icons.check_rounded)
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(day),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
