import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/remote_config/remote_config_providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../../core/widgets/inline_notice.dart';
import '../account/account_providers.dart';
import '../account/deletion_pending.dart';
import '../checkin/quadrant_glyph.dart';
import '../shell/app_shell.dart' show ShellSettingsButton, isShellTabRoot;
import 'room_copy.dart';
import 'room_models.dart';
import 'room_navigation.dart';
import 'room_status.dart';
import 'room_widgets.dart';
import 'rooms_providers.dart';
import 'rooms_repository.dart';

/// The Rooms tab (F5): the rooms you are in (go back with the same
/// pseudonym), your memories, what rooms are (a fresh name in every room,
/// no messages, gestures only), when Lantern Hour is, and "Check in to find
/// a room". There is no browsing of other rooms. "I need help now" is in
/// the top bar (within the first three focus stops, REQ-A11Y-11).
class RoomsHomeScreen extends ConsumerWidget {
  const RoomsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final auth = ref.watch(authRepositoryProvider);
    final ready = ref.watch(roomsReadyProvider);
    final signedIn = ref.watch(authUserProvider).value != null;
    final rooms = ref.watch(myRoomsProvider);
    final held = ref.watch(deletionHoldProvider) != null;
    final list = rooms.value ?? const <RoomSummary>[];
    final active = [
      for (final r in list)
        if (!r.room.isMemory) r,
    ];
    final memories = [
      for (final r in list)
        if (r.room.isMemory) r,
    ];
    final error = rooms.error;
    final loaded = rooms.hasValue && !rooms.isLoading;

    return Scaffold(
      appBar: helpAppBar(
        context,
        title: l.rooms_title,
        // The tab's first screen: Settings instead of Back (app shell).
        leading: isShellTabRoot(context) ? const ShellSettingsButton() : null,
      ),
      body: CosmicBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            if (!ready) return;
            ref.invalidate(myRoomsProvider);
            try {
              await ref.read(myRoomsProvider.future);
            } on Object {
              // Shown inline.
            }
          },
          child: ListView(
            key: const ValueKey('rooms-home'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.gutter,
              AuraSpace.s,
              AuraSpace.gutter,
              AuraSpace.xxl,
            ),
            children: [
              if (held) ...[
                const DeletionPendingCard(),
                const SizedBox(height: AuraSpace.l),
              ],
              // Kill switch `rooms_enabled` (remote flag, PRD 19).
              if (!ref.watch(remoteFlagsProvider).roomsEnabled) ...[
                InlineNotice(
                  l.rooms_paused,
                  key: const ValueKey('rooms-paused'),
                ),
                const SizedBox(height: AuraSpace.l),
              ],
              if (auth.isAvailable && !signedIn) ...[
                InlineNotice(
                  l.rooms_signedOut,
                  key: const ValueKey('rooms-signed-out'),
                  action: GoRouter.maybeOf(context) == null
                      ? null
                      : TextButton(
                          onPressed: () => context.push(Routes.signIn),
                          child: Text(l.rooms_signIn),
                        ),
                ),
                const SizedBox(height: AuraSpace.l),
              ],
              if (error is RoomsFailure && !held) ...[
                RoomsFailureNotice(
                  failure: error,
                  onRetry: () async {
                    ref.invalidate(myRoomsProvider);
                    try {
                      await ref.read(myRoomsProvider.future);
                    } on Object {
                      // Shown inline.
                    }
                  },
                ),
                const SizedBox(height: AuraSpace.l),
              ],
              if (active.isNotEmpty) ...[
                _Heading(l.rooms_yourRooms),
                for (final r in active) _RoomCard(summary: r),
                const SizedBox(height: AuraSpace.l),
              ],
              if (memories.isNotEmpty) ...[
                _Heading(l.rooms_memories),
                for (final r in memories) _RoomCard(summary: r),
                const SizedBox(height: AuraSpace.l),
              ],
              if (ready && loaded && list.isEmpty) ...[
                Text(
                  l.rooms_empty,
                  key: const ValueKey('rooms-empty'),
                  style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
                ),
                const SizedBox(height: AuraSpace.l),
              ],
              const _WhatRoomsAre(),
              // Paused rooms: no join offer (the notice above says why).
              if (ref.watch(remoteFlagsProvider).roomsEnabled) ...[
                const SizedBox(height: AuraSpace.l),
                FilledButton(
                  key: const ValueKey('rooms-check-in'),
                  onPressed: () => openRoomCheckIn(context),
                  child: Text(l.rooms_checkInCta, textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AuraSpace.s),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

/// One of your rooms: its theme, your name there and how many are here now
/// (or, for a memory, until when you can look back).
class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.summary});

  final RoomSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final room = summary.room;
    final theme = roomThemeName(l, room.theme);
    final memory = room.isMemory;
    final lantern = !memory && room.lanternHour.active;
    final status = memory
        ? l.rooms_memoryUntil(roomDate(context, room.purgeAt))
        : l.rooms_hereNow(summary.counts.hereNow);
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s),
      child: Semantics(
        button: true,
        label: [
          theme,
          l.rooms_youAre(summary.me.pseudonym),
          memory
              ? status
              : l.rooms_countsSemantic(
                  summary.counts.hereNow,
                  summary.counts.today,
                ),
          if (lantern) l.rooms_lanternNow,
        ].join(', '),
        hint: l.rooms_openHint,
        onTap: () => openRoom(context, room.roomId),
        excludeSemantics: true,
        child: Material(
          color: AuraColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AuraRadius.m),
          child: InkWell(
            key: ValueKey('room-card-${room.roomId}'),
            borderRadius: BorderRadius.circular(AuraRadius.m),
            onTap: () => openRoom(context, room.roomId),
            child: Padding(
              padding: const EdgeInsets.all(AuraSpace.l),
              child: Row(
                children: [
                  Opacity(
                    opacity: memory ? 0.6 : 1,
                    child: QuadrantGlyph(room.quadrantValue, size: 28),
                  ),
                  const SizedBox(width: AuraSpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(theme, style: t.titleMedium),
                        Text(
                          l.rooms_youAre(summary.me.pseudonym),
                          style: t.bodySmall?.copyWith(
                            color: AuraColors.lavender,
                          ),
                        ),
                        const SizedBox(height: AuraSpace.xs),
                        Text(
                          status,
                          style: t.bodyMedium?.copyWith(
                            color: AuraColors.textSoft,
                          ),
                        ),
                        if (lantern)
                          Padding(
                            padding: const EdgeInsets.only(top: AuraSpace.xs),
                            child: Row(
                              children: [
                                const LanternGlyph(size: 16),
                                const SizedBox(width: AuraSpace.xs),
                                Flexible(
                                  child: Text(
                                    l.rooms_lanternNow,
                                    style: t.labelMedium?.copyWith(
                                      color: AuraColors.starlight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AuraColors.textSoft,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Short and calm: what a room is, what it never has, and Lantern Hour.
class _WhatRoomsAre extends StatelessWidget {
  const _WhatRoomsAre();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: AuraSpace.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: AuraColors.lavender),
          ),
          const SizedBox(width: AuraSpace.m),
          Expanded(child: Text(text, style: t.bodyMedium)),
        ],
      ),
    );
    return Container(
      key: const ValueKey('rooms-what'),
      padding: const EdgeInsets.all(AuraSpace.l),
      decoration: BoxDecoration(
        color: AuraColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AuraRadius.l),
        border: Border.all(color: AuraColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(l.rooms_whatTitle, style: t.titleMedium),
          ),
          const SizedBox(height: AuraSpace.s),
          Text(
            l.rooms_whatBody,
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          point(Icons.badge_outlined, l.rooms_pointName),
          point(Icons.volunteer_activism_outlined, l.rooms_pointGestures),
          point(Icons.hourglass_bottom_rounded, l.rooms_pointTime),
          const Divider(height: AuraSpace.xl, color: AuraColors.hairline),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: ExcludeSemantics(child: LanternGlyph()),
              ),
              const SizedBox(width: AuraSpace.m),
              Expanded(
                child: Text(
                  l.rooms_lanternNote,
                  key: const ValueKey('rooms-lantern-note'),
                  style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
