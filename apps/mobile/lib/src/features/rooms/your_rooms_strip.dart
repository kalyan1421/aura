import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/remote_config/remote_config_providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../checkin/quadrant_glyph.dart';
import 'room_copy.dart';
import 'room_navigation.dart';
import 'rooms_providers.dart';

/// Home "Your rooms" strip (F5): the rooms you are in right now (at most
/// one per quadrant), each a pill with the quadrant glyph, theme and "N
/// here now"; tap to go back with the same pseudonym. Cached rooms keep
/// their links while presence is being refreshed or unavailable, without
/// claiming live counts. Nothing when there are none. Wraps at large text;
/// every pill is at least 48 dp tall. No
/// LayoutBuilder: Home measures this with a dry layout.
class YourRoomsStrip extends ConsumerWidget {
  const YourRoomsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myRoomsProvider);
    final rooms = state.value ?? const [];
    final presenceFresh =
        ref.watch(roomsReadyProvider) &&
        state.hasValue &&
        !state.isLoading &&
        !state.hasError &&
        (ref.watch(connectivityProvider).value ?? false) &&
        ref.watch(remoteFlagsProvider).roomsEnabled;
    final active = [
      for (final r in rooms)
        if (!r.room.isMemory) r,
    ];
    if (active.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('your-rooms-strip'),
      padding: const EdgeInsets.only(top: AuraSpace.s, bottom: AuraSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.rooms_yourRooms,
              style: t.labelLarge?.copyWith(color: AuraColors.textSoft),
            ),
          ),
          const SizedBox(height: AuraSpace.xs),
          Wrap(
            spacing: AuraSpace.s,
            runSpacing: AuraSpace.s,
            children: [
              for (final r in active)
                Semantics(
                  button: true,
                  label: presenceFresh
                      ? l.rooms_stripSemantic(
                          roomThemeName(l, r.room.theme),
                          r.counts.hereNow,
                        )
                      : '${roomThemeName(l, r.room.theme)}, '
                            '${l.rooms_presenceStale}',
                  hint: l.rooms_openHint,
                  onTap: () => openRoom(context, r.room.roomId),
                  excludeSemantics: true,
                  child: Material(
                    color: AuraColors.surface.withValues(alpha: 0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AuraRadius.pill),
                      side: const BorderSide(color: AuraColors.outline),
                    ),
                    child: InkWell(
                      key: ValueKey('strip-room-${r.room.roomId}'),
                      customBorder: const StadiumBorder(),
                      onTap: () => openRoom(context, r.room.roomId),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AuraSpace.m,
                            vertical: AuraSpace.s,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              QuadrantGlyph(r.room.quadrantValue, size: 18),
                              const SizedBox(width: AuraSpace.s),
                              Flexible(
                                child: Text(
                                  '${roomThemeName(l, r.room.theme)} · '
                                  '${presenceFresh ? l.rooms_hereNow(r.counts.hereNow) : l.rooms_presenceStale}',
                                  style: t.labelLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
