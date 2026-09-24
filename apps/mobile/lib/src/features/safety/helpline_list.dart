import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/kv_store.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/copy_fallback_notice.dart';
import '../onboarding/gate_controller.dart';
import '../support/helplines.dart';

/// Verified tap-to-call helplines for the device region (never IP or GPS),
/// or, where none is listed, the "call your local emergency number" card:
/// never an empty list (PRD States: Crisis support sheet). The bundled
/// directory, or a signed newer one the phone already verified, so it works
/// offline, signed out and with no spinner (F9).
///
/// Shared by the Safety Center and the support sheet. The first helpline
/// takes focus when the screen opens (REQ-A11Y-11). A device that can't
/// dial (an iPad, a simulator) shows the number under the row it tapped,
/// with a Copy action, until closed.
class HelplineList extends ConsumerStatefulWidget {
  const HelplineList({
    super.key,
    this.keyPrefix = 'support',
    this.emergencyLine = true,
  });

  /// Prefix of the row keys: `<prefix>-call-<digits>` and
  /// `<prefix>-call-failed-<digits>`.
  final String keyPrefix;

  /// Whether the short "call your local emergency number" line follows a
  /// non-empty list (the Safety Center has its own emergency guidance).
  final bool emergencyLine;

  @override
  ConsumerState<HelplineList> createState() => _HelplineListState();
}

class _HelplineListState extends ConsumerState<HelplineList> {
  bool _isMinor = false;

  /// The helpline this device couldn't dial.
  Helpline? _couldNotCall;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMinor());
  }

  /// Childline (India) is listed until the 18th birthday, judged on the
  /// app's shared clock and Aura day (04:00 rollover in the person's zone),
  /// like every other day in the app. Around midnight that can list it a
  /// few hours longer, never shorter.
  Future<void> _loadMinor() async {
    final raw = await ref.read(kvStoreProvider).get(KvKeys.minorUntil);
    final until = LocalDay.tryParse(raw);
    if (until == null || !mounted) return;
    final today = ref.read(timeContextProvider).today();
    setState(() => _isMinor = today.isBefore(until));
  }

  /// Dials at once (nothing is checked first, so a phone that can call is
  /// never slowed down). If the device can't place calls, the number shows
  /// under the row with a Copy action.
  Future<void> _call(Helpline line) async {
    var placed = false;
    try {
      placed = await launchUrl(Uri(scheme: 'tel', path: line.dial));
    } on Object {
      placed = false;
    }
    if (!mounted) return;
    setState(() => _couldNotCall = placed ? null : line);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final region = ref.watch(deviceRegionProvider);
    // Behind the under-13 lock everyone here is a child: Childline stays
    // listed (the lock clears the stored birthday, so it can't say so).
    final blocked = ref.watch(
      gateControllerProvider.select((g) => g.isBlocked),
    );
    final lines = helplinesFor(
      region,
      l,
      isMinor: _isMinor || blocked,
      directory: ref.watch(helplineDirectoryProvider),
    );

    if (lines.isEmpty) {
      return Container(
        key: ValueKey('${widget.keyPrefix}-local-emergency'),
        width: double.infinity,
        padding: const EdgeInsets.all(AuraSpace.l),
        decoration: BoxDecoration(
          color: AuraColors.surface,
          borderRadius: BorderRadius.circular(AuraRadius.m),
          border: Border.all(color: AuraColors.hairline),
        ),
        child: Text(l.help_otherEmergency, style: theme.textTheme.titleMedium),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s),
            child: HelplineTile(
              key: ValueKey('${widget.keyPrefix}-call-${lines[i].dial}'),
              line: lines[i],
              autofocus: i == 0,
              onCall: () => unawaited(_call(lines[i])),
            ),
          ),
          if (_couldNotCall?.dial == lines[i].dial)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s),
              child: CopyFallbackNotice(
                key: ValueKey(
                  '${widget.keyPrefix}-call-failed-${lines[i].dial}',
                ),
                message: l.polish_helpCallFailed(lines[i].number),
                copyText: lines[i].number,
                copyLabel: l.polish_helpCopyNumber,
                copiedLabel: l.polish_helpNumberCopied,
                onClose: () => setState(() => _couldNotCall = null),
              ),
            ),
        ],
        if (widget.emergencyLine) ...[
          const SizedBox(height: AuraSpace.s),
          Text(l.help_otherEmergency, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// One tap-to-call helpline: its name, then the number in the warm lantern
/// tone. Screen readers hear "Call Tele-MANAS · free, 24×7, 14416", not bare
/// digits, and a double-tap places the call.
class HelplineTile extends StatelessWidget {
  const HelplineTile({
    super.key,
    required this.line,
    required this.onCall,
    this.autofocus = false,
  });

  final Helpline line;
  final VoidCallback onCall;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The InkWell's semantics are replaced, so the tap action is restored
    // here: a screen-reader double-tap must place the call.
    return Semantics(
      button: true,
      label: l.help_callSemantic(line.name, line.number),
      onTap: onCall,
      excludeSemantics: true,
      child: Material(
        color: AuraColors.surface,
        borderRadius: BorderRadius.circular(AuraRadius.m),
        child: InkWell(
          autofocus: autofocus,
          borderRadius: BorderRadius.circular(AuraRadius.m),
          onTap: onCall,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.l,
              vertical: AuraSpace.m,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AuraColors.lantern.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    color: AuraColors.lantern,
                  ),
                ),
                const SizedBox(width: AuraSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.name, style: theme.textTheme.titleSmall),
                      Text(
                        line.number,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AuraColors.lantern,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
