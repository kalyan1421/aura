import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';

import '../../core/net/aura_api.dart' show ApiException;
import 'room_models.dart';
import 'rooms_api.dart';

/// Why a rooms call didn't go through, in the terms the screens need
/// (contracts/api/v1-rooms.md §4.4 codes + v1.md).
enum RoomsFailureKind {
  /// No connection: nothing was called (rooms are online only).
  offline,

  /// The server couldn't be reached or failed (5xx, timeout): retry later.
  network,

  /// No signed-in account (or the token was refused).
  signedOut,

  /// This build has no API configured.
  unavailable,

  /// `409 profile_required`: onboarding hasn't reached the server yet.
  profileRequired,

  /// `403 account_deletion_pending`: the account is in its deletion grace
  /// period ("Keep my account?" takes over).
  deletionPending,

  /// `403 rooms_suspended`: room access is suspended or paused.
  suspended,

  /// `403 account_closed`.
  closed,

  /// `409 language_pool_unavailable`: Hindi + Hinglish rooms aren't open.
  poolUnavailable,

  /// `503 rooms_paused`: the rooms kill switch is off (flag `rooms_enabled`,
  /// PRD 19). Not retried on its own; the remote flags say when it's back.
  paused,

  /// `409 guidelines_required` (REQ-SAFE-04): the community guidelines in
  /// [RoomsFailure.guidelinesVersion] must be accepted before a room.
  guidelinesRequired,

  /// `429 room_join_limit`: 3 new rooms for this quadrant in 24 h.
  joinLimit,

  /// `429 report_limit`.
  reportLimit,

  /// `409 room_read_only`: the room became a memory.
  readOnly,

  /// `404 not_found`: not (or no longer) your room, or it was purged.
  notFound,

  /// `404 member_not_found`: that member left.
  memberNotFound,

  /// `400 invalid_target`: yourself.
  invalidTarget,

  /// Anything else (a bad request is a bug; it is never retried).
  other,
}

class RoomsFailure implements Exception {
  const RoomsFailure(
    this.kind, {
    this.code,
    this.status,
    this.guidelinesVersion,
  });

  factory RoomsFailure.from(ApiException e) {
    final kind = switch ((e.status, e.code)) {
      _ when e.isNetwork => RoomsFailureKind.network,
      (401, _) => RoomsFailureKind.signedOut,
      (403, ApiException.deletionPendingCode) =>
        RoomsFailureKind.deletionPending,
      (403, 'rooms_suspended') => RoomsFailureKind.suspended,
      (403, 'account_closed') => RoomsFailureKind.closed,
      (409, 'profile_required') => RoomsFailureKind.profileRequired,
      (409, 'language_pool_unavailable') => RoomsFailureKind.poolUnavailable,
      (503, 'rooms_paused') => RoomsFailureKind.paused,
      (409, GuidelinesRequiredException.guidelinesRequiredCode) =>
        RoomsFailureKind.guidelinesRequired,
      (409, 'room_read_only') => RoomsFailureKind.readOnly,
      (429, 'room_join_limit') => RoomsFailureKind.joinLimit,
      (429, 'report_limit') => RoomsFailureKind.reportLimit,
      (404, 'member_not_found') => RoomsFailureKind.memberNotFound,
      (404, _) => RoomsFailureKind.notFound,
      (400, 'invalid_target') => RoomsFailureKind.invalidTarget,
      (final int s, _) when s >= 500 || s == 408 || s == 429 =>
        RoomsFailureKind.network,
      _ => RoomsFailureKind.other,
    };
    return RoomsFailure(
      kind,
      code: e.code,
      status: e.status,
      guidelinesVersion: switch (e) {
        GuidelinesRequiredException(:final version) => version,
        _ when kind == RoomsFailureKind.guidelinesRequired => 1,
        _ => null,
      },
    );
  }

  final RoomsFailureKind kind;
  final String? code;
  final int? status;

  /// [RoomsFailureKind.guidelinesRequired]: the version to accept.
  final int? guidelinesVersion;

  /// Worth trying again later (a connection or server hiccup).
  bool get isTransient =>
      kind == RoomsFailureKind.offline || kind == RoomsFailureKind.network;

  /// The room (or rooms at all) can't be used any more on this account.
  bool get isTerminal => const {
    RoomsFailureKind.notFound,
    RoomsFailureKind.deletionPending,
    RoomsFailureKind.suspended,
    RoomsFailureKind.closed,
    RoomsFailureKind.signedOut,
  }.contains(kind);

  @override
  String toString() => 'RoomsFailure(${kind.name}, $status, $code)';
}

/// Mood Rooms data for the app (F5) plus the room safety actions (F9).
///
/// Rooms are **online only** (PRD Offline Mode): offline, every method
/// throws [RoomsFailureKind.offline] without calling the server, and
/// nothing is ever queued here (the room screen's 30 s gesture queue is
/// the only exception, and it lives with the room). Errors come back as
/// [RoomsFailure]. `403 account_deletion_pending` also runs
/// [onDeletionPending], like sync does; `403 account_closed` runs
/// [onAccountClosed] (the app-wide closed screen, like every `AuraApi` call).
class RoomsRepository {
  RoomsRepository({
    required this._api,
    required this._isOnline,
    required this._timezone,
    this._onDeletionPending,
    this._onAccountClosed,
  });

  final RoomsApi? _api;
  final bool Function() _isOnline;
  final String Function() _timezone;
  final void Function()? _onDeletionPending;
  final void Function()? _onAccountClosed;

  /// The detail a match returned, handed to the room screen once so it
  /// doesn't fetch the same room again.
  final Map<String, RoomDetail> _prefetched = {};

  bool get isAvailable => _api != null;

  Future<T> _guard<T>(Future<T> Function(RoomsApi api) call) async {
    final api = _api;
    if (api == null) throw const RoomsFailure(RoomsFailureKind.unavailable);
    if (!_isOnline()) throw const RoomsFailure(RoomsFailureKind.offline);
    try {
      return await call(api);
    } on ApiException catch (e) {
      final failure = RoomsFailure.from(e);
      if (failure.kind == RoomsFailureKind.deletionPending) {
        _onDeletionPending?.call();
      }
      if (failure.kind == RoomsFailureKind.closed) _onAccountClosed?.call();
      // Codes only: never ids, pseudonyms or bodies (DS-10).
      debugPrint('rooms: ${failure.kind.name} (${e.status}, ${e.code})');
      throw failure;
    } on RoomsFailure {
      rethrow;
    } on Object catch (e) {
      // A response that doesn't fit the contract: never shown raw.
      debugPrint('rooms: unexpected response (${e.runtimeType})');
      throw const RoomsFailure(RoomsFailureKind.other);
    }
  }

  /// Joins (or returns to) the room for this check-in: step 0 gives back
  /// your room for this quadrant with the same pseudonym.
  Future<MatchResult> match({
    required Quadrant quadrant,
    required String moodId,
    bool allowPoolFallback = false,
  }) async {
    final result = await _guard(
      (api) => api.match(
        MatchRequest(
          quadrant: quadrant,
          moodId: moodId,
          timezone: _timezone(),
          allowPoolFallback: allowPoolFallback,
        ),
      ),
    );
    _prefetched[result.detail.room.roomId] = result.detail;
    return result;
  }

  /// The detail a match just returned for [roomId] (once), else `null`.
  RoomDetail? takePrefetched(String roomId) => _prefetched.remove(roomId);

  Future<List<RoomSummary>> myRooms() => _guard((api) => api.rooms());

  Future<RoomDetail> room(String roomId) => _guard((api) => api.room(roomId));

  Future<HeartbeatResult> heartbeat(String roomId) =>
      _guard((api) => api.heartbeat(roomId));

  /// `202` whether delivered or silently dropped (over a limit, a block, a
  /// mute): it always looks sent.
  Future<GestureAck> sendGesture(
    String roomId,
    GestureType type, {
    String? toMemberId,
  }) => _guard((api) => api.sendGesture(roomId, type, toMemberId: toMemberId));

  Future<bool> leave(String roomId) => _guard((api) => api.leave(roomId));

  /// Tonight's intention (§1.9). `intention_closed` / `intention_paused`
  /// come back as a [RoomsFailure] with that [RoomsFailure.code].
  Future<IntentionHoldResult> holdIntention(String roomId) =>
      _guard((api) => api.holdIntention(roomId));

  Future<void> survey(String roomId, SurveyAnswer answer) =>
      _guard((api) => api.survey(roomId, answer));

  Future<void> mute(String roomId, String memberId) =>
      _guard((api) => api.mute(roomId, memberId));

  Future<void> unmute(String roomId, String memberId) =>
      _guard((api) => api.unmute(roomId, memberId));

  Future<ReportAck> report(
    ReportTarget target,
    ReportReason reason, {
    String? note,
  }) => _guard((api) => api.report(target, reason, note: note));

  Future<String> block(String roomId, String memberId) =>
      _guard((api) => api.block(roomId, memberId));

  Future<SafetyStanding> standing() => _guard((api) => api.standing());

  /// REQ-SAFE-04: records on the server that the person accepted community
  /// guidelines [version] (the text this build showed). Online only, like
  /// every rooms call.
  Future<GuidelinesStatus> acceptGuidelines(int version) =>
      _guard((api) => api.acceptGuidelines(version));
}
