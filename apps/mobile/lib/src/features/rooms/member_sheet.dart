import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/aura_tokens.dart';
import '../checkin/quadrant_glyph.dart';
import 'room_controller.dart';
import 'room_models.dart';
import 'room_widgets.dart';

/// What was picked in a member sheet; the room screen carries it out (it
/// outlives the sheet).
enum MemberAction { report, block, mute, unmute }

@immutable
class MemberChoice {
  const MemberChoice.gesture(GestureType this.gesture) : action = null;
  const MemberChoice.action(MemberAction this.action) : gesture = null;

  final GestureType? gesture;
  final MemberAction? action;
}

/// Tap a silhouette: pseudonym, silhouette and mood chip; the 8 gestures
/// for this one person; and Report · Block · Mute, each the second tap
/// (REQ-ROOM-08). No profile, no history, no DM.
Future<MemberChoice?> showMemberSheet(
  BuildContext context, {
  required String roomId,
  required RoomMember member,
}) => showModalBottomSheet<MemberChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  builder: (_) => MemberSheet(roomId: roomId, member: member),
);

class MemberSheet extends ConsumerWidget {
  const MemberSheet({super.key, required this.roomId, required this.member});

  final String roomId;
  final RoomMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final tag = ref.watch(localeControllerProvider);
    final room = ref.watch(roomControllerProvider(roomId));
    // The member as the room sees them now (e.g. just muted).
    final m =
        room.detail?.members
            .where((x) => x.memberId == member.memberId)
            .firstOrNull ??
        member;
    final mood = moodById(m.moodChip);
    final canSend = room.canSend;
    void pick(MemberChoice c) => Navigator.of(context).pop(c);

    return SingleChildScrollView(
      key: const ValueKey('member-sheet'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AuraSpace.gutter,
        0,
        AuraSpace.gutter,
        AuraSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RoomSilhouette(
                silhouette: m.silhouette,
                size: 72,
                dimmed: m.muted,
              ),
              const SizedBox(width: AuraSpace.m),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AuraSpace.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(m.pseudonym, style: t.titleLarge),
                      ),
                      const SizedBox(height: AuraSpace.xs),
                      if (mood != null)
                        Row(
                          children: [
                            QuadrantGlyph(mood.quadrant, size: 14),
                            const SizedBox(width: AuraSpace.xs),
                            Flexible(
                              child: Text(
                                mood.nameFor(tag),
                                style: t.bodyMedium?.copyWith(
                                  color: AuraColors.textSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      Text(
                        m.muted
                            ? l.rooms_memberMuted
                            : m.live
                            ? l.rooms_memberHereNow
                            : l.rooms_memberAway,
                        style: t.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('member-close'),
                tooltip: l.common_close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          // Report · Block · Mute first, never below the fold (REQ-ROOM-08:
          // the second tap from the silhouette, at any text size).
          const SizedBox(height: AuraSpace.m),
          Wrap(
            spacing: AuraSpace.s,
            runSpacing: AuraSpace.s,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('member-report'),
                onPressed: () =>
                    pick(const MemberChoice.action(MemberAction.report)),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(l.rooms_report),
              ),
              OutlinedButton.icon(
                key: const ValueKey('member-block'),
                onPressed: () =>
                    pick(const MemberChoice.action(MemberAction.block)),
                icon: const Icon(Icons.block_rounded, size: 18),
                label: Text(l.rooms_block),
              ),
              OutlinedButton.icon(
                key: const ValueKey('member-mute'),
                onPressed: () => pick(
                  MemberChoice.action(
                    m.muted ? MemberAction.unmute : MemberAction.mute,
                  ),
                ),
                icon: Icon(
                  m.muted
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                  size: 18,
                ),
                label: Text(m.muted ? l.rooms_unmute : l.rooms_mute),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.xs),
          Text(l.rooms_safetyNote, style: t.bodySmall),
          if (!room.isMemory) ...[
            const SizedBox(height: AuraSpace.l),
            const Divider(color: AuraColors.hairline),
            const SizedBox(height: AuraSpace.s),
            Text(l.rooms_sendTo(m.pseudonym), style: t.titleSmall),
            const SizedBox(height: AuraSpace.s),
            LayoutBuilder(
              builder: (context, box) {
                // Two to four per row; each label may wrap, never cut.
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final perRow = (box.maxWidth / (88 * scale.clamp(1.0, 2.0)))
                    .floor()
                    .clamp(2, 4);
                final width =
                    (box.maxWidth - (perRow - 1) * AuraSpace.s) / perRow;
                return Wrap(
                  spacing: AuraSpace.s,
                  runSpacing: AuraSpace.s,
                  children: [
                    for (final g in GestureType.values)
                      GestureButton(
                        type: g,
                        width: width,
                        hint: l.rooms_gestureHintMember(m.pseudonym),
                        onPressed: canSend
                            ? () => pick(MemberChoice.gesture(g))
                            : null,
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
