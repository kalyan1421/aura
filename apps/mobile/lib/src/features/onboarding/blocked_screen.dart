import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/env/env.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/copy_fallback_notice.dart';
import '../../core/widgets/inline_notice.dart';
import '../support/helplines.dart';
import '../support/support_sheet.dart';
import 'onboarding_frame.dart';

/// Helplines the under-13 screen offers in India (F8: Childline 1098 and
/// 112), taken from the verified list in `helplines.dart`.
const _blockedDials = {'1098', '112'};

/// The "Entered the wrong date?" email (F8 edge case): the support address
/// and a subject line only. Never the date of birth or anything else about
/// the person — the device keeps nothing about them, and a URL is logged in
/// too many places.
@visibleForTesting
Uri wrongDateMailto(String email, String subject) => Uri(
  scheme: 'mailto',
  path: email,
  query: 'subject=${Uri.encodeComponent(subject)}',
);

/// Under-13 block (F8). Kind, with help by region. Shown on every launch for
/// 30 days (device lock); no account, email or device id is created.
class BlockedScreen extends ConsumerStatefulWidget {
  const BlockedScreen({super.key, this.supportEmail});

  /// Overrides [Env.supportEmail] (tests). Empty hides the wrong-date link.
  final String? supportEmail;

  @override
  ConsumerState<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends ConsumerState<BlockedScreen> {
  bool _mailFailed = false;

  Future<void> _writeToSupport(String email) async {
    final l = AppLocalizations.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        wrongDateMailto(email, l.onb_blockedMailSubject),
      );
    } on Object {
      opened = false;
    }
    if (mounted) setState(() => _mailFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final region = ref.watch(deviceRegionProvider);
    final india = region == 'IN';
    final lines = india
        ? [
            for (final h in helplinesFor(region, l, isMinor: true))
              if (_blockedDials.contains(h.dial)) h,
          ]
        : const <Helpline>[];
    final email = widget.supportEmail ?? Env.supportEmail;
    final t = Theme.of(context).textTheme;
    return OnboardingFrame(
      trailing: const HelpNowButton(compact: true),
      children: [
        const SizedBox(height: AuraSpace.xl),
        const ExcludeSemantics(
          child: Icon(
            Icons.nights_stay_outlined,
            size: 56,
            color: AuraColors.starlight,
          ),
        ),
        const SizedBox(height: AuraSpace.xl),
        Semantics(
          header: true,
          child: Text(
            l.blocked_title,
            key: const ValueKey('blocked-title'),
            style: t.headlineMedium,
          ),
        ),
        const SizedBox(height: AuraSpace.m),
        Text(
          l.blocked_body,
          style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
        ),
        const SizedBox(height: AuraSpace.xxl),
        Container(
          padding: const EdgeInsets.all(AuraSpace.l),
          decoration: BoxDecoration(
            color: AuraColors.surface,
            borderRadius: BorderRadius.circular(AuraRadius.m),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                india ? l.blocked_helpIndia : l.blocked_helpOther,
                style: t.bodyLarge,
              ),
              for (final line in lines) ...[
                const SizedBox(height: AuraSpace.s),
                _HelplineButton(line),
              ],
            ],
          ),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.l),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('blocked-wrong-date'),
              onPressed: () => _writeToSupport(email),
              // Inside the button so the hint joins its semantics node.
              child: Semantics(
                hint: l.onb_blockedWrongDateHint,
                child: Text(l.onb_blockedWrongDate),
              ),
            ),
          ),
          if (_mailFailed) ...[
            const SizedBox(height: AuraSpace.s),
            InlineNotice(
              l.onb_blockedMailFailed(email),
              key: const ValueKey('blocked-mail-failed'),
            ),
          ],
        ],
      ],
    );
  }
}

/// Tap-to-call row. Screen readers hear the helpline's name with its number
/// ("Call Childline · for under-18s, 1098"), not the bare digits. The label
/// replaces the button's own semantics, so the call action is declared here
/// too, or a screen-reader double-tap would do nothing. On a device that
/// can't dial (iPad, simulator) the number is shown with a Copy action.
class _HelplineButton extends StatefulWidget {
  const _HelplineButton(this.line);

  final Helpline line;

  @override
  State<_HelplineButton> createState() => _HelplineButtonState();
}

class _HelplineButtonState extends State<_HelplineButton> {
  bool _couldNotCall = false;

  Helpline get line => widget.line;

  /// Dials at once; only a failed launch shows the fallback.
  Future<void> _call() async {
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: line.dial));
    } on Object catch (e) {
      debugPrint('blocked: call failed (${e.runtimeType})');
    }
    if (!opened && mounted) setState(() => _couldNotCall = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    void call() => unawaited(_call());
    final button = Semantics(
      button: true,
      label: l.help_callSemantic(line.name, line.number),
      onTap: call,
      excludeSemantics: true,
      child: OutlinedButton(
        key: ValueKey('blocked-call-${line.dial}'),
        onPressed: call,
        style: OutlinedButton.styleFrom(
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AuraSpace.l,
            vertical: AuraSpace.m,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.call_rounded, size: 20, color: AuraColors.lantern),
            const SizedBox(width: AuraSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.name,
                    style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                  ),
                  Text(
                    line.number,
                    style: t.titleMedium?.copyWith(color: AuraColors.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!_couldNotCall) return button;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        button,
        const SizedBox(height: AuraSpace.s),
        CopyFallbackNotice(
          key: ValueKey('blocked-call-failed-${line.dial}'),
          message: l.polish_helpCallFailed(line.number),
          copyText: line.number,
          copyLabel: l.polish_helpCopyNumber,
          copiedLabel: l.polish_helpNumberCopied,
          onClose: () => setState(() => _couldNotCall = false),
        ),
      ],
    );
  }
}
