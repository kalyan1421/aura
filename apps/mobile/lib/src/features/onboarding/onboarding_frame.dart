import 'package:flutter/material.dart';

import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';

/// Shared layout for onboarding steps: calm sky, a scrollable body (text
/// scales to 200% without clipping) and the primary action pinned below.
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.children,
    this.primary,
    this.secondary,
    this.leading,
    this.trailing,
    this.hero,
  });

  final List<Widget> children;
  final Widget? primary;
  final Widget? secondary;
  final Widget? leading;
  final Widget? trailing;
  final Widget? hero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CosmicBackground(
        child: SafeArea(
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    ?leading,
                    const Spacer(),
                    if (trailing != null)
                      Flexible(
                        flex: 4,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: trailing,
                        ),
                      ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.gutter + 4,
                    AuraSpace.s,
                    AuraSpace.gutter + 4,
                    AuraSpace.xl,
                  ),
                  children: [?hero, ...children],
                ),
              ),
              if (primary != null || secondary != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.gutter,
                    AuraSpace.s,
                    AuraSpace.gutter,
                    AuraSpace.l,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [?primary, ?secondary],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StepTitle extends StatelessWidget {
  const StepTitle(this.title, {super.key, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: t.headlineMedium),
        ),
        if (body != null) ...[
          const SizedBox(height: AuraSpace.m),
          Text(body!, style: t.bodyLarge?.copyWith(color: AuraColors.textSoft)),
        ],
        const SizedBox(height: AuraSpace.xl),
      ],
    );
  }
}
