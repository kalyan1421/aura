import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import 'capsule_composer_screen.dart';
import 'capsule_detail_screen.dart';
import 'capsule_format.dart';
import 'capsule_opening.dart';
import 'capsule_providers.dart';
import 'capsule_repository.dart';

/// Opens "Future you", the capsules list (a Navigator route; the lead can
/// map it to `/sanctuary/capsules`).
Future<void> openCapsulesList(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const CapsulesListScreen()),
    );

/// "Future you" (PRD F4, 14-states): capsules ready to open, sealed ones
/// ("Sealed until 12 Oct 2027. It'll keep." / "Waiting for a feeling" — no
/// content, no early open) and opened ones to read again. A kept draft sits
/// on top. Empty: "Write to future you. Seal it for a date, or for a
/// feeling." → "Seal your first capsule". Renders from the local store at
/// once; works offline.
class CapsulesListScreen extends ConsumerWidget {
  const CapsulesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    ref.watch(capsuleCoordinatorProvider);
    final rows = ref.watch(capsulesProvider).value;
    final hasDraft = ref.watch(capsuleHasDraftProvider).value ?? false;
    return Scaffold(
      appBar: helpAppBar(context, title: l.capsules_title),
      body: CosmicBackground(
        child: rows == null
            ? const SizedBox.expand()
            : rows.isEmpty && !hasDraft
            ? const _Empty()
            : _List(rows: rows, hasDraft: hasDraft),
      ),
    );
  }
}

/// A still seal: an orb in a thin ring (the ceremony's first frame).
class CapsuleSealGlyph extends StatelessWidget {
  const CapsuleSealGlyph({super.key, this.size = 72, this.tint});

  final double size;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = tint ?? AuraColors.starlight;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AuraColors.starlight.withValues(alpha: 0.55),
              width: 1.5,
            ),
            gradient: RadialGradient(
              colors: [
                c.withValues(alpha: 0.9),
                c.withValues(alpha: 0.35),
                c.withValues(alpha: 0),
              ],
              stops: const [0, 0.6, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.xxl * 2,
        AuraSpace.gutter,
        AuraSpace.xl,
      ),
      children: [
        const Center(child: CapsuleSealGlyph()),
        const SizedBox(height: AuraSpace.xl),
        Text(
          l.capsules_emptyBody,
          key: const ValueKey('capsules-empty'),
          textAlign: TextAlign.center,
          style: t.titleMedium,
        ),
        const SizedBox(height: AuraSpace.xl),
        FilledButton(
          key: const ValueKey('capsules-first'),
          onPressed: () => openCapsuleComposer(context),
          child: Text(l.capsules_emptyCta),
        ),
      ],
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.rows, required this.hasDraft});

  final List<CapsuleRow> rows;
  final bool hasDraft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tz = ref.watch(deviceTimezoneProvider);
    final now =
        ref.watch(nowProvider).value ?? ref.read(timeContextProvider).now();
    final ready = [
      for (final r in rows)
        if (isCapsuleReady(r, tz, now)) r,
    ];
    final sealed = [
      for (final r in rows)
        if (r.openedAt == null && !isCapsuleReady(r, tz, now)) r,
    ];
    final opened = [
      for (final r in rows)
        if (r.openedAt != null) r,
    ];

    Widget section(String text) => Padding(
      padding: const EdgeInsets.only(top: AuraSpace.xl, bottom: AuraSpace.s),
      child: Semantics(
        header: true,
        container: true,
        child: Text(text, style: t.titleSmall),
      ),
    );

    Widget tile(CapsuleRow r, {required bool ready}) => Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s),
      child: _CapsuleTile(row: r, ready: ready),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.s,
        AuraSpace.gutter,
        AuraSpace.xxl,
      ),
      children: [
        if (hasDraft) ...[
          const SizedBox(height: AuraSpace.m),
          const _DraftCard(),
        ],
        if (ready.isNotEmpty) ...[
          section(l.capsules_sectionReady),
          for (final r in ready) tile(r, ready: true),
        ],
        if (sealed.isNotEmpty) ...[
          section(l.capsules_sectionSealed),
          for (final r in sealed) tile(r, ready: false),
        ],
        if (opened.isNotEmpty) ...[
          section(l.capsules_sectionOpened),
          for (final r in opened) tile(r, ready: false),
        ],
        const SizedBox(height: AuraSpace.xl),
        if (!hasDraft)
          FilledButton.icon(
            key: const ValueKey('capsules-new'),
            onPressed: () => openCapsuleComposer(context),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l.capsules_new),
          ),
      ],
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return _Card(
      key: const ValueKey('capsules-draft'),
      highlight: true,
      onTap: () => openCapsuleComposer(context),
      leading: const Icon(Icons.edit_note_rounded, color: AuraColors.starlight),
      title: l.capsules_draftTitle,
      subtitle: Text(
        l.capsules_draftBody,
        style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
      ),
    );
  }
}

class _CapsuleTile extends ConsumerWidget {
  const _CapsuleTile({required this.row, required this.ready});

  final CapsuleRow row;
  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tag = ref.watch(localeControllerProvider);
    final tz = ref.watch(deviceTimezoneProvider);
    final payload = ref.watch(capsulePayloadProvider(row)).value;
    final date = unlockDateOf(row);
    final isMood = row.unlockType == CapsuleUnlockType.mood.name;
    final String status;
    final IconData icon;
    if (row.rejected != null) {
      status = l.capsules_limitBody;
      icon = Icons.info_outline_rounded;
    } else if (ready) {
      status = l.capsules_readyRow;
      icon = Icons.mark_email_unread_outlined;
    } else if (row.openedAt != null) {
      status = l.capsules_openedOn(capsuleDayOf(tag, row.openedAt!, tz));
      icon = Icons.drafts_outlined;
    } else if (!isMood && date != null) {
      status = l.capsules_sealedUntil(capsuleDateLabel(tag, date));
      icon = Icons.lock_clock_outlined;
    } else {
      status = l.capsules_waitingFeeling;
      icon = Icons.lock_outline_rounded;
    }
    return _Card(
      key: ValueKey('capsule-row-${row.id}'),
      highlight: ready,
      onTap: () => ready
          ? openCapsule(context, row.id)
          : openCapsuleDetail(context, row.id),
      leading: Icon(
        icon,
        color: ready ? AuraColors.starlight : AuraColors.lavender,
      ),
      title: capsuleTitleOf(l, tag, row, payload, tz),
      subtitle: Text(
        status,
        style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
      ),
    );
  }
}

/// One row: a card that is a single button (one focus stop, ≥ 48 dp).
class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.highlight = false,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final Widget subtitle;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: AuraColors.surface.withValues(alpha: highlight ? 0.92 : 0.75),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        side: BorderSide(
          color: highlight
              ? AuraColors.starlight.withValues(alpha: 0.4)
              : AuraColors.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.all(AuraSpace.m),
                child: Row(
                  children: [
                    ExcludeSemantics(child: leading),
                    const SizedBox(width: AuraSpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: t.bodyLarge),
                          const SizedBox(height: 2),
                          subtitle,
                        ],
                      ),
                    ),
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AuraColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
