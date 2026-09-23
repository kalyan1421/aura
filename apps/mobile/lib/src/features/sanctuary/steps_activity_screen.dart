import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/theme/aura_tokens.dart';
import '../progress/progress_view.dart';
import 'activity_scaffold.dart';

/// The self-paced grounding activities: prompts only, one step at a time
/// with "Next" (PRD 06d grounding library, REQ-SAN-05).
enum StepsActivity {
  /// 5-4-3-2-1: five things you can see, four you can touch, …
  senses,

  /// Three small things from today, brought to mind one at a time.
  gratitude,

  /// Replay one good moment from today (Sunrise's minute).
  savour,
}

/// A step-through grounding activity. There is no text field, no timer and
/// no score: nothing typed, said or picked here is stored or synced. Leave
/// at any time with ✕; "Back" revisits a step. Each new step is announced
/// once (a live region).
class StepsActivityScreen extends ConsumerStatefulWidget {
  const StepsActivityScreen({super.key, required this.activity});

  final StepsActivity activity;

  @override
  ConsumerState<StepsActivityScreen> createState() =>
      _StepsActivityScreenState();
}

class _StepsActivityScreenState extends ConsumerState<StepsActivityScreen> {
  int _step = 0;
  bool _done = false;

  String _title(AppLocalizations l) => switch (widget.activity) {
    StepsActivity.senses => l.senses_title,
    StepsActivity.gratitude => l.gratitude_title,
    StepsActivity.savour => l.minute_savourTitle,
  };

  String _intro(AppLocalizations l) => switch (widget.activity) {
    StepsActivity.senses => l.senses_intro,
    StepsActivity.gratitude => l.gratitude_intro,
    StepsActivity.savour => l.savour_intro,
  };

  String _doneText(AppLocalizations l) => switch (widget.activity) {
    StepsActivity.senses => l.senses_done,
    StepsActivity.gratitude => l.gratitude_done,
    StepsActivity.savour => l.savour_done,
  };

  /// (title, hint) for each step.
  List<(String, String?)> _steps(AppLocalizations l) =>
      switch (widget.activity) {
        StepsActivity.senses => [
          (l.senses_see, l.senses_seeBody),
          (l.senses_touch, l.senses_touchBody),
          (l.senses_hear, l.senses_hearBody),
          (l.senses_smell, l.senses_smellBody),
          (l.senses_taste, l.senses_tasteBody),
        ],
        StepsActivity.gratitude => [
          (l.gratitude_1, l.gratitude_1Body),
          (l.gratitude_2, l.gratitude_2Body),
          (l.gratitude_3, l.gratitude_3Body),
        ],
        StepsActivity.savour => [
          (l.savour_1, null),
          (l.savour_2, null),
          (l.savour_3, null),
        ],
      };

  void _next(int count) => setState(() {
    if (_step + 1 >= count) {
      _done = true;
    } else {
      _step++;
    }
  });

  void _back() => setState(() => _step = _step > 0 ? _step - 1 : 0);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final hue = ref.watch(progressViewProvider.select((v) => v.avatar.hue));
    final steps = _steps(l);
    final reduce = reduceMotionOf(context);
    final (title, hint) = steps[_step];

    final Widget content = _done
        ? Semantics(
            key: const ValueKey('steps-done'),
            liveRegion: true,
            container: true,
            child: Text(
              _doneText(l),
              key: const ValueKey('steps-done-line'),
              textAlign: TextAlign.center,
              style: t.headlineSmall,
            ),
          )
        : Column(
            key: ValueKey('step-$_step'),
            children: [
              Semantics(
                liveRegion: true,
                container: true,
                child: Column(
                  children: [
                    Text(
                      title,
                      key: const ValueKey('steps-title'),
                      textAlign: TextAlign.center,
                      style: t.headlineSmall,
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: AuraSpace.s),
                      Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: t.bodyLarge?.copyWith(
                          color: AuraColors.textSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AuraSpace.xl),
              _StepDots(
                count: steps.length,
                current: _step,
                label: l.senses_step(_step + 1, steps.length),
              ),
            ],
          );

    return ActivityScaffold(
      tint: glowColorForHue(hue),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.gutter,
                AuraSpace.s,
                AuraSpace.gutter,
                AuraSpace.xl,
              ),
              children: [
                ActivityTitle(_title(l)),
                const SizedBox(height: AuraSpace.s),
                if (!_done && _step == 0)
                  Text(
                    _intro(l),
                    key: const ValueKey('steps-intro'),
                    textAlign: TextAlign.center,
                    style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
                  ),
                const SizedBox(height: AuraSpace.xxl),
                AnimatedSwitcher(
                  duration: reduce ? reducedMotionFade : AuraMotion.calm,
                  child: content,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.gutter,
              AuraSpace.s,
              AuraSpace.gutter,
              AuraSpace.l,
            ),
            child: _done
                ? SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('steps-finish'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(l.common_done),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _step > 0
                            ? TextButton(
                                key: const ValueKey('steps-back'),
                                onPressed: _back,
                                child: Text(l.common_back),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(width: AuraSpace.m),
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('steps-next'),
                          onPressed: () => _next(steps.length),
                          child: Text(l.sanctuary_next),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Quiet dots for where you are; read as "Step 2 of 5" (not a score).
class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.count,
    required this.current,
    required this.label,
  });

  final int count;
  final int current;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    container: true,
    child: ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == current ? AuraColors.starlight : AuraColors.outline,
              ),
            ),
        ],
      ),
    ),
  );
}
