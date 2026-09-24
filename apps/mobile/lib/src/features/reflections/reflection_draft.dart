import 'package:flutter/foundation.dart';

import '../../core/db/kv_store.dart';

/// A reflection being written in one room: the text and the `reflectionId`
/// generated once for it (UUIDv7), reused on every retry so a send that was
/// in flight when the connection dropped is never posted twice
/// (contracts/api/v1-reflections.md §0).
@immutable
class ReflectionDraft {
  const ReflectionDraft({required this.reflectionId, required this.text});

  final String reflectionId;

  /// Never logged.
  final String text;

  ReflectionDraft copyWith({String? reflectionId, String? text}) =>
      ReflectionDraft(
        reflectionId: reflectionId ?? this.reflectionId,
        text: text ?? this.text,
      );
}

/// Keeps each room's draft in the encrypted key/value table ("never lose
/// input", PRD 14-states), until it is sent or cleared. Account-scoped: the
/// sign-out wipe removes it with everything else that isn't device-scoped.
class ReflectionDraftStore {
  ReflectionDraftStore(this._kv);

  final KvStore _kv;

  static String keyFor(String roomId) => 'reflections.draft.$roomId';

  Future<ReflectionDraft?> load(String roomId) async {
    try {
      final json = await _kv.getJson(keyFor(roomId));
      final id = json?['reflectionId'];
      final text = json?['text'];
      if (id is! String || id.isEmpty || text is! String) return null;
      return ReflectionDraft(reflectionId: id, text: text);
    } on Object catch (e) {
      debugPrint('reflections: draft unreadable (${e.runtimeType})');
      return null;
    }
  }

  Future<void> save(String roomId, ReflectionDraft draft) => _kv.setJson(
    keyFor(roomId),
    {'reflectionId': draft.reflectionId, 'text': draft.text},
  );

  Future<void> clear(String roomId) => _kv.set(keyFor(roomId), null);
}
