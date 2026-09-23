import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/haptics.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../checkin/quadrant_glyph.dart' show habitLabel;
import 'habit_providers.dart';
import 'habit_repository.dart';
import 'habits_editor_sheet.dart';

/// Icons for the six presets; custom habits share [customHabitIcon].
const Map<String, IconData> presetHabitIcons = {
  'hydrate': Icons.local_drink_outlined,
  'sleep_on_time': Icons.bedtime_outlined,
  'move': Icons.directions_walk,
  'breathe': Icons.air,
  'journal': Icons.edit_note,
  'go_outside': Icons.park_outlined,
};

/// The one generic icon every custom habit uses.
const IconData customHabitIcon = Icons.spa_outlined;

/// A habit's display name: the localized preset label or the custom name.
String habitDisplayName(
  AppLocalizations l, {
  PresetHabit? preset,
  String? name,
}) => preset != null ? habitLabel(l, preset.key) : (name ?? '');

/// Home's "Small things today": binary, self-reported chips (F2) with an
/// Edit entry to the habits editor. No "missed" state, red or cross. With
/// every habit hidden it invites one small thing; check-ins alone still grow
/// the avatar.
class HabitsSection extends ConsumerWidget {
  const HabitsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final habits =
        ref.watch(habitsTodayProvider).value ??
        [for (final p in presetHabits) HabitToday(preset: p, done: false)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(l.home_habitsTitle, style: t.titleMedium),
              ),
            ),
            const SizedBox(width: AuraSpace.s),
            TextButton(
              key: const ValueKey('habits-edit'),
              onPressed: () => showHabitsEditor(context),
              child: Semantics(
                label: l.habits_editSemantic,
                excludeSemantics: true,
                child: Text(l.habits_edit),
              ),
            ),
          ],
        ),
        // Edit's 48 dp tap target already leaves air under the title.
        const SizedBox(height: AuraSpace.xs),
        if (habits.isEmpty)
          Text(
            l.habits_empty,
            key: const ValueKey('habits-empty'),
            style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
          )
        else
          Wrap(
            spacing: AuraSpace.s,
            // No run spacing: each chip's 48 dp tap target already puts
            // clear space between the rows of pills (so Home fits all six
            // presets above the check-in bar).
            children: [for (final h in habits) _HabitChip(habit: h)],
          ),
      ],
    );
  }
}

class _HabitChip extends ConsumerWidget {
  const _HabitChip({required this.habit});

  final HabitToday habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final h = habit;
    final name = habitDisplayName(l, preset: h.preset, name: h.name);
    final icon = h.done
        ? Icons.check_rounded
        : h.isCustom
        ? customHabitIcon
        : presetHabitIcons[h.preset!.key];
    Future<void> toggle() async {
      AuraHaptics.selection();
      final repo = ref.read(habitRepositoryProvider);
      if (h.isCustom) {
        await repo.toggleCustomToday(h.habitId!);
      } else {
        await repo.toggleToday(h.preset!.key);
      }
      ref.read(syncControllerProvider).notifyLocalWrite();
    }

    // One node: "Hydrate, done today" + toggled state. The chip's own
    // semantics are replaced, so the tap action is restored here.
    return Semantics(
      label: h.done ? l.home_habitDone(name) : l.home_habitNotYet(name),
      toggled: h.done,
      onTap: toggle,
      excludeSemantics: true,
      child: FilterChip(
        key: ValueKey('habit-${h.key}'),
        avatar: Icon(
          icon,
          size: 18,
          color: h.done ? AuraColors.onAccent : AuraColors.textSoft,
        ),
        label: Text(name),
        selected: h.done,
        selectedColor: AuraColors.starlight,
        labelStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: h.done ? AuraColors.onAccent : AuraColors.text),
        onSelected: (_) => toggle(),
      ),
    );
  }
}
