import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../shell/app_shell.dart' show openCheckIn;
import 'room_join_screen.dart';
import 'room_screen.dart';

/// What to match a room for: the saved check-in's quadrant and mood. Passed
/// as the route's `extra`, never in the location (a mood is health data and
/// locations can end up in logs).
@immutable
class RoomJoinRequest {
  const RoomJoinRequest({required this.quadrant, required this.moodId});

  final Quadrant quadrant;
  final String moodId;
}

/// Opens room [roomId] (`/rooms/:id`, above the shell). Outside the app's
/// router (a bare navigator) the screen is pushed directly.
void openRoom(BuildContext context, String roomId, {bool replace = false}) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    final route = MaterialPageRoute<void>(
      builder: (_) => RoomScreen(roomId: roomId),
    );
    final navigator = Navigator.of(context);
    if (replace) {
      navigator.pushReplacement(route);
    } else {
      navigator.push(route);
    }
    return;
  }
  final location = Routes.room(roomId);
  if (replace) {
    router.pushReplacement(location);
  } else {
    router.push(location);
  }
}

/// Matches a room for a saved check-in (`/rooms/join`).
void openRoomJoin(BuildContext context, RoomJoinRequest request) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RoomJoinScreen(request: request)),
    );
    return;
  }
  router.push(Routes.roomJoin, extra: request);
}

/// The Rooms tab (its first screen). Outside the app's router: back.
void openRoomsTab(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).maybePop();
    return;
  }
  router.go(Routes.rooms);
}

/// A new check-in (rooms are found from one). Needs the app's router.
void openRoomCheckIn(BuildContext context) {
  if (GoRouter.maybeOf(context) == null) return;
  openCheckIn(context);
}
