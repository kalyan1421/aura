import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/env/env.dart';
import '../../core/providers.dart';
import '../../core/remote_config/device_ban.dart';
import '../../core/remote_config/remote_config_providers.dart';
import '../account/account_providers.dart';
import '../auth/account_closed.dart';
import '../onboarding/gate_controller.dart';
import 'room_models.dart';
import 'room_realtime.dart';
import 'rooms_api.dart';
import 'rooms_repository.dart';

part 'rooms_providers.g.dart';

/// Rooms never retry on their own: offline or failing, the screen says so
/// and the person (or a reconnect) tries again.
Duration? noRoomsRetry(int retryCount, Object error) => null;

/// `null` when this build has no API (debug builds without config).
@Riverpod(keepAlive: true)
RoomsApi? roomsApi(Ref ref) {
  if (!Env.hasApi) return null;
  final auth = ref.watch(authRepositoryProvider);
  return HttpRoomsApi(
    baseUrl: Env.apiUrl,
    accessToken: auth.accessToken,
    // Device bans (REQ-ADM-14): the install id on the match; 403
    // device_banned → the app-wide screen.
    deviceHeaders: ref.watch(installIdProvider).headers,
    onDeviceBanned: () {
      if (ref.mounted) ref.read(deviceBannedProvider.notifier).report();
    },
  );
}

@Riverpod(keepAlive: true)
RoomsRepository roomsRepository(Ref ref) => RoomsRepository(
  api: ref.watch(roomsApiProvider),
  isOnline: () => ref.read(connectivityProvider).value ?? true,
  timezone: () => ref.read(timeContextProvider).timezone,
  // Same hold as sync: "Keep my account?" (REQ-ACC-11).
  onDeletionPending: () =>
      unawaited(ref.read(deletionHoldProvider.notifier).reportFromSync()),
  // Same calm "This account is closed" screen as every other API path (F9).
  onAccountClosed: () => ref.read(accountClosedProvider.notifier).report(),
);

/// Opens the private Realtime channels, or `null` when this build has no
/// Supabase (the room then polls with its heartbeat).
@Riverpod(keepAlive: true)
RoomChannelOpener? roomChannelOpener(Ref ref) {
  if (!Env.hasSupabase) return null;
  final auth = ref.watch(authRepositoryProvider);
  if (!auth.isAvailable) return null;
  try {
    return supabaseRoomChannels(sb.Supabase.instance.client, auth.accessToken);
  } on Object {
    return null; // Supabase didn't initialise
  }
}

/// Whether rooms can be used here at all: an API and Supabase sign-in in
/// this build, a signed-in account and a finished onboarding.
@riverpod
bool roomsReady(Ref ref) {
  final auth = ref.watch(authRepositoryProvider);
  final user = ref.watch(authUserProvider).value;
  final gate = ref.watch(gateControllerProvider);
  return auth.isAvailable &&
      ref.watch(roomsApiProvider) != null &&
      user != null &&
      gate.onboarded &&
      !gate.isBlocked;
}

/// The rooms you are in (`GET /v1/rooms`), newest first: active ones and
/// memories. Empty until rooms are usable ([roomsReady]); offline it fails
/// with [RoomsFailureKind.offline] and never calls. Refreshed on reconnect,
/// on resume and every 90 s while something shows it.
@Riverpod(retry: noRoomsRetry)
class MyRooms extends _$MyRooms {
  @override
  Future<List<RoomSummary>> build() async {
    if (!ref.watch(roomsReadyProvider)) return const [];
    // Wait for the first known connection state (never call on a guess).
    final online = await ref.watch(connectivityProvider.future);
    if (!online) throw const RoomsFailure(RoomsFailureKind.offline);
    if (!ref.mounted) return const [];
    final refresh = Timer(const Duration(seconds: 90), ref.invalidateSelf);
    final life = AppLifecycleListener(onResume: ref.invalidateSelf);
    ref.onDispose(() {
      refresh.cancel();
      life.dispose();
    });
    return ref.read(roomsRepositoryProvider).myRooms();
  }
}

/// "Tell me when they open" (Hindi + Hinglish rooms): kept on this phone
/// for an in-app note when the pool opens.
const String roomsNotifyHiPoolKey = 'rooms.notify_hi_pool';
