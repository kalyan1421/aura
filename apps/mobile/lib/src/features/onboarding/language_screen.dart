import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/aura_tokens.dart';
import 'gate_controller.dart';
import 'onboarding_frame.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return OnboardingFrame(
      primary: FilledButton(
        key: const ValueKey('language-continue'),
        onPressed: () => ref
            .read(gateControllerProvider.notifier)
            .goTo(OnboardingStage.signIn),
        child: Text(l.common_continue),
      ),
      children: [
        StepTitle(l.language_title, body: l.language_body),
        const LanguagePicker(),
      ],
    );
  }
}

/// Used in onboarding and Settings. Switching redraws the UI at once.
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final current = ref.watch(localeControllerProvider);
    final t = Theme.of(context).textTheme;
    String? hint(String tag) => switch (tag) {
      AuraLocales.teLatn => l.language_teLatnHint,
      AuraLocales.hiLatn => l.language_hiLatnHint,
      _ => null,
    };
    final beta = {AuraLocales.hi, AuraLocales.hiLatn};

    return Column(
      children: [
        for (final tag in pickerLocales)
          Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s),
            child: Semantics(
              selected: tag == current,
              inMutuallyExclusiveGroup: true,
              child: Material(
                color: tag == current ? AuraColors.surfaceHigh : AuraColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.m),
                  side: BorderSide(
                    color: tag == current ? AuraColors.lavender : AuraColors.hairline,
                  ),
                ),
                child: InkWell(
                  key: ValueKey('lang-$tag'),
                  borderRadius: BorderRadius.circular(AuraRadius.m),
                  onTap: () =>
                      ref.read(localeControllerProvider.notifier).select(tag),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.l,
                      vertical: AuraSpace.m,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localeEndonyms[tag] ?? tag,
                                style: t.titleMedium,
                                locale: localeFromTag(tag),
                              ),
                              if (hint(tag) != null)
                                Text(hint(tag)!, style: t.bodySmall),
                            ],
                          ),
                        ),
                        if (beta.contains(tag))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(l.language_beta, style: t.labelSmall),
                          ),
                        Icon(
                          tag == current
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: tag == current
                              ? AuraColors.lavender
                              : AuraColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
