import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/remote_config/remote_config_providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aura_tokens.dart';
import '../onboarding/gate_controller.dart';
import 'room_navigation.dart';
import 'rooms_providers.dart';

/// "Join a room of people feeling this" in the check-in saved moment
/// (F5 REQ-ROOM-01): the same offer at every age.
///
/// - Offline: "Rooms open when you're back online", and no call at all
///   (the button appears by itself once the connection is back).
/// - Signed out: a calm line and Sign in; during the first check-in (still
///   onboarding) a line that rooms are in the Rooms tab. Never a dead
///   button; nothing at all in a build without rooms.
/// - Otherwise: the join screen matches the room for this check-in's mood,
///   with the community guidelines first when the server has no record of
///   them yet (REQ-SAFE-04, room_join_screen.dart).
class RoomOfferButton extends ConsumerStatefulWidget {
  const RoomOfferButton({super.key, required this.quadrant, this.moodId});

  final Quadrant quadrant;

  /// The saved check-in's mood. When not given: the newest live check-in
  /// in [quadrant] on this phone (the one just saved).
  final String? moodId;

  @override
  ConsumerState<RoomOfferButton> createState() => _RoomOfferButtonState();
}

class _RoomOfferButtonState extends ConsumerState<RoomOfferButton> {
  bool _busy = false;

  Future<void> _join() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final moodId =
          widget.moodId ??
          await latestMoodIn(ref.read(appDatabaseProvider), widget.quadrant);
      if (!mounted || moodId == null) return;
      openRoomJoin(
        context,
        RoomJoinRequest(quadrant: widget.quadrant, moodId: moodId),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auth = ref.watch(authRepositoryProvider);
    final gate = ref.watch(gateControllerProvider);
    // This build can't do rooms at all (no sign-in or API configured).
    if (!auth.isAvailable ||
        ref.watch(roomsApiProvider) == null ||
        gate.isBlocked) {
      return const SizedBox.shrink();
    }
    if (!gate.onboarded) return _Note(l.rooms_offerLater);
    final user = ref.watch(authUserProvider).value;
    if (user == null) {
      return _Note(
        l.rooms_signedOut,
        action: GoRouter.maybeOf(context) == null
            ? null
            : TextButton(
                key: const ValueKey('room-offer-sign-in'),
                onPressed: () => context.push(Routes.signIn),
                child: Text(l.rooms_signIn),
              ),
      );
    }
    final online = ref.watch(connectivityProvider).value ?? true;
    if (!online) {
      return _Note(
        l.rooms_offerOffline,
        key: const ValueKey('room-offer-offline'),
        icon: Icons.cloud_off_outlined,
      );
    }
    // Kill switch `rooms_enabled` (remote flag; the server refuses joins too).
    if (!ref.watch(remoteFlagsProvider).roomsEnabled) {
      return _Note(l.rooms_paused, key: const ValueKey('room-offer-paused'));
    }
    // One node: the button's label and action plus the hint.
    return MergeSemantics(
      child: Semantics(
        hint: l.rooms_offerHint,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('room-offer'),
            onPressed: _busy ? null : () => unawaited(_join()),
            icon: const Icon(Icons.groups_rounded),
            label: Text(l.rooms_offer, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

/// The newest live (not deleted) check-in in [quadrant] on this phone.
Future<String?> latestMoodIn(AppDatabase db, Quadrant quadrant) async {
  try {
    final row =
        await (db.select(db.checkIns)
              ..where(
                (t) => t.quadrant.equals(quadrant.name) & t.deletedAt.isNull(),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.deviceTs),
                (t) => OrderingTerm.desc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row?.moodId;
  } on Object catch (e) {
    debugPrint('rooms: latest mood (${e.runtimeType})');
    return null;
  }
}

class _Note extends StatelessWidget {
  const _Note(
    this.text, {
    super.key,
    this.icon = Icons.groups_outlined,
    this.action,
  });

  final String text;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: AuraColors.textSoft),
          ),
          const SizedBox(width: AuraSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AuraColors.textSoft),
                ),
                ?action,
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
