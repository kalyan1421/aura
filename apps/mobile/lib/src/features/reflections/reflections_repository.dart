import 'package:flutter/foundation.dart';

import '../../core/net/aura_api.dart' show ApiException;
import '../rooms/room_models.dart' show GestureAck, GestureType;
import 'reflection_models.dart';
import 'reflections_api.dart';

/// Why a reflections call didn't go through, in the terms the composer and
/// the list need (contracts/api/v1-reflections.md §1, §5 + v1-rooms.md).
enum ReflectionsFailureKind {
  /// No connection: nothing was called (reflections are online only).
  offline,

  /// The server couldn't be reached or failed (5xx, timeout): a send keeps
  /// its draft and its `reflectionId` for the retry.
  network,

  /// No signed-in account (or the token was refused).
  signedOut,

  /// This build has no API configured.
  unavailable,

  /// `429 reflection_room_limit`: 3 in this room in 24 h.
  roomLimit,

  /// `429 reflection_daily_limit`: 10 across rooms in 24 h.
  dailyLimit,

  /// `503 reflections_paused`: kill switch, paused pool or reduced mode.
  paused,

  /// `409 room_read_only`: the room became a memory.
  readOnly,

  /// `409 reflection_id_conflict`: the draft needs a fresh id.
  idConflict,

  /// `404 reflection_not_found`: gone, or not visible to you.
  reflectionNotFound,

  /// `404 not_found`: not (or no longer) your room.
  notFound,

  /// `400 invalid_target`: your own reflection.
  invalidTarget,

  /// `403 rooms_suspended` / `account_closed` / `account_deletion_pending`.
  suspended,

  /// Anything else (`400 invalid_request`, `replies_not_supported`: a bug;
  /// never retried).
  other,
}

class ReflectionsFailure implements Exception {
  const ReflectionsFailure(this.kind, {this.code, this.status});

  factory ReflectionsFailure.from(ApiException e) {
    final kind = switch ((e.status, e.code)) {
      _ when e.isNetwork => ReflectionsFailureKind.network,
      (401, _) => ReflectionsFailureKind.signedOut,
      (403, _) => ReflectionsFailureKind.suspended,
      (429, 'reflection_room_limit') => ReflectionsFailureKind.roomLimit,
      (429, 'reflection_daily_limit') => ReflectionsFailureKind.dailyLimit,
      (503, 'reflections_paused') => ReflectionsFailureKind.paused,
      (409, 'room_read_only') => ReflectionsFailureKind.readOnly,
      (409, 'reflection_id_conflict') => ReflectionsFailureKind.idConflict,
      (404, 'reflection_not_found') =>
        ReflectionsFailureKind.reflectionNotFound,
      (404, _) => ReflectionsFailureKind.notFound,
      (400, 'invalid_target') => ReflectionsFailureKind.invalidTarget,
      (final int s, _) when s >= 500 || s == 408 || s == 429 =>
        ReflectionsFailureKind.network,
      _ => ReflectionsFailureKind.other,
    };
    return ReflectionsFailure(kind, code: e.code, status: e.status);
  }

  final ReflectionsFailureKind kind;
  final String? code;
  final int? status;

  /// Worth trying again later with the same draft and id.
  bool get isTransient =>
      kind == ReflectionsFailureKind.offline ||
      kind == ReflectionsFailureKind.network;

  bool get isLimit =>
      kind == ReflectionsFailureKind.roomLimit ||
      kind == ReflectionsFailureKind.dailyLimit;

  @override
  String toString() => 'ReflectionsFailure(${kind.name}, $status, $code)';
}

/// Reflections for the app (F6). Online only: offline every method throws
/// [ReflectionsFailureKind.offline] without calling the server, and nothing
/// is queued here (the composer keeps the draft on the phone instead).
/// Errors come back as [ReflectionsFailure]; only codes are ever logged,
/// never text, ids or pseudonyms.
class ReflectionsRepository {
  ReflectionsRepository({
    required this._api,
    required this._isOnline,
    this._onDeletionPending,
    this._onAccountClosed,
  });

  final ReflectionsApi? _api;
  final bool Function() _isOnline;

  /// Same hooks as the rooms repository: "Keep my account?" and the calm
  /// closed screen.
  final void Function()? _onDeletionPending;
  final void Function()? _onAccountClosed;

  bool get isAvailable => _api != null;

  bool get isOnline => _isOnline();

  Future<T> _guard<T>(Future<T> Function(ReflectionsApi api) call) async {
    final api = _api;
    if (api == null) {
      throw const ReflectionsFailure(ReflectionsFailureKind.unavailable);
    }
    if (!_isOnline()) {
      throw const ReflectionsFailure(ReflectionsFailureKind.offline);
    }
    try {
      return await call(api);
    } on ApiException catch (e) {
      final failure = ReflectionsFailure.from(e);
      if (e.isDeletionPending) _onDeletionPending?.call();
      if (e.isAccountClosed) _onAccountClosed?.call();
      debugPrint('reflections: ${failure.kind.name} (${e.status}, ${e.code})');
      throw failure;
    } on ReflectionsFailure {
      rethrow;
    } on Object catch (e) {
      debugPrint('reflections: unexpected response (${e.runtimeType})');
      throw const ReflectionsFailure(ReflectionsFailureKind.other);
    }
  }

  Future<ReflectionList> list(String roomId) =>
      _guard((api) => api.list(roomId));

  Future<Reflection> get(String roomId, String reflectionId) =>
      _guard((api) => api.get(roomId, reflectionId));

  /// Sends the trimmed [text] under [reflectionId] (reuse it on a retry).
  Future<SendOutcome> send(
    String roomId, {
    required String reflectionId,
    required String text,
  }) => _guard(
    (api) => api.send(roomId, reflectionId: reflectionId, text: text.trim()),
  );

  Future<void> delete(String roomId, String reflectionId) =>
      _guard((api) => api.delete(roomId, reflectionId));

  /// `202` whether delivered or silently dropped: it always looks sent.
  Future<GestureAck> sendGesture(
    String roomId,
    GestureType type, {
    required String reflectionId,
  }) => _guard(
    (api) => api.sendGesture(roomId, type, reflectionId: reflectionId),
  );
}
