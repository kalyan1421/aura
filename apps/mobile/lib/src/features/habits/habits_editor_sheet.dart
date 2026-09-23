import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/haptics.dart';
import '../../core/a11y/motion.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/inline_notice.dart';
import '../support/crisis_lexicon.dart';
import '../support/support_sheet.dart';
import 'habit_providers.dart';
import 'habit_repository.dart';
import 'habits_section.dart';

/// Opens the habits editor (F2: "user picks which show").
Future<void> showHabitsEditor(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const HabitsEditorSheet(),
    );

/// Choose which habits show on Home: a switch per preset, up to 3 active
/// custom habits (≤ 30 characters), and remove one of your own. Every change
/// goes through [HabitRepository] and the outbox. A custom name that matches
/// the crisis lexicon still saves, then the support sheet opens (F2, F9).
/// Scrolls at 200% text and has an explicit Close.
class HabitsEditorSheet extends ConsumerStatefulWidget {
  const HabitsEditorSheet({super.key});

  @override
  ConsumerState<HabitsEditorSheet> createState() => _HabitsEditorSheetState();
}

class _HabitsEditorSheetState extends ConsumerState<HabitsEditorSheet> {
  final TextEditingController _name = TextEditingController();

  /// Calm recovery note under the add field (never `lantern`).
  String? _notice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _name
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  HabitRepository get _repo => ref.read(habitRepositoryProvider);

  void _synced() => ref.read(syncControllerProvider).notifyLocalWrite();

  /// Runs a habit write; a failed local save keeps the sheet and says so.
  Future<void> _write(Future<String?> Function(AppLocalizations l) body) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    String? notice;
    try {
      notice = await body(l);
    } on Object catch (e) {
      debugPrint('habits: save failed (${e.runtimeType})');
      notice = l.habits_saveFailed;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = notice;
    });
  }

  Future<void> _setPreset(String key, bool shown) => _write((l) async {
    AuraHaptics.selection();
    await _repo.setPresetShown(key, shown);
    _synced();
    return null;
  });

  Future<void> _setCustom(String habitId, bool shown) => _write((l) async {
    AuraHaptics.selection();
    final r = await _repo.setCustomShown(habitId, shown);
    if (r == CustomHabitResult.tooMany) {
      return l.habits_limit(HabitRepository.maxActiveCustomHabits);
    }
    _synced();
    return null;
  });

  Future<void> _add() async {
    final raw = _name.text;
    if (raw.trim().isEmpty || _busy) return;
    var crisis = false;
    await _write((l) async {
      final name = HabitRepository.cleanCustomName(raw);
      if (name == null) return l.habits_tooLong;
      final r = await _repo.addCustom(name);
      switch (r) {
        case CustomHabitResult.saved:
          AuraHaptics.light();
          _synced();
          _name.clear();
          // Scanned on device only; the habit is saved either way.
          crisis = noteNeedsSupport(name);
          return null;
        case CustomHabitResult.tooMany:
          return l.habits_limit(HabitRepository.maxActiveCustomHabits);
        case CustomHabitResult.invalid:
          return l.habits_tooLong;
      }
    });
    if (crisis && mounted) await showSupportSheet(context);
  }

  Future<void> _remove(HabitSetting h) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.habits_removeTitle(h.name!)),
        content: Text(l.habits_removeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.common_cancel),
          ),
          TextButton(
            key: const ValueKey('habits-remove-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.habits_removeConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _write((l) async {
      await _repo.removeCustom(h.habitId!);
      _synced();
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final settings =
        ref.watch(habitSettingsProvider).value ??
        [for (final p in presetHabits) HabitSetting.preset(p, shown: true)];
    final presets = settings.where((h) => !h.isCustom).toList();
    final custom = settings.where((h) => h.isCustom).toList();
    final atLimit =
        custom.where((h) => h.shown).length >=
        HabitRepository.maxActiveCustomHabits;
    final canAdd = !_busy && !atLimit && _name.text.trim().isNotEmpty;
    final limitText = l.habits_limit(HabitRepository.maxActiveCustomHabits);
    // At the limit the limit note already shows; don't repeat it.
    final notice = atLimit && _notice == limitText ? null : _notice;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: AuraSpace.l, bottom: AuraSpace.xs),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: t.titleSmall?.copyWith(color: AuraColors.textSoft),
        ),
      ),
    );

    return AnimatedPadding(
      // Follows the keyboard; no slide under Reduce Motion.
      duration: reduceMotionOf(context) ? Duration.zero : AuraMotion.quick,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsetsDirectional.fromSTEB(
            AuraSpace.gutter,
            0,
            AuraSpace.gutter,
            AuraSpace.xxl,
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AuraSpace.s),
                    child: Semantics(
                      header: true,
                      child: Text(l.habits_sheetTitle, style: t.headlineSmall),
                    ),
                  ),
                ),
                const SizedBox(width: AuraSpace.s),
                IconButton(
                  key: const ValueKey('habits-close'),
                  tooltip: l.common_close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.xs),
            Text(
              l.habits_sheetBody,
              style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
            ),
            section(l.habits_presetsTitle),
            for (final h in presets)
              SwitchListTile(
                key: ValueKey('habit-switch-${h.key}'),
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  presetHabitIcons[h.key],
                  color: AuraColors.textSoft,
                ),
                title: Text(habitDisplayName(l, preset: h.preset)),
                value: h.shown,
                onChanged: _busy ? null : (v) => _setPreset(h.key, v),
              ),
            section(l.habits_customTitle),
            for (final h in custom)
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      key: ValueKey('habit-switch-${h.key}'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(
                        customHabitIcon,
                        color: AuraColors.textSoft,
                      ),
                      title: Text(h.name!),
                      value: h.shown,
                      onChanged: _busy ? null : (v) => _setCustom(h.key, v),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('habit-remove-${h.key}'),
                    tooltip: l.habits_remove(h.name!),
                    onPressed: _busy ? null : () => _remove(h),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            const SizedBox(height: AuraSpace.s),
            if (atLimit)
              InlineNotice(limitText, key: const ValueKey('habits-limit'))
            else ...[
              TextField(
                key: const ValueKey('habits-add-field'),
                controller: _name,
                maxLength: HabitRepository.maxCustomNameChars,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => unawaited(_add()),
                decoration: InputDecoration(
                  labelText: l.habits_addLabel,
                  hintText: l.habits_addHint,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  key: const ValueKey('habits-add'),
                  onPressed: canAdd ? _add : null,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.habits_add),
                ),
              ),
            ],
            if (notice != null) ...[
              const SizedBox(height: AuraSpace.s),
              InlineNotice(notice, key: const ValueKey('habits-notice')),
            ],
          ],
        ),
      ),
    );
  }
}
