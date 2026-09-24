import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/kv_store.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/time/clock.dart';
import 'rooms_providers.dart';

/// "Tell me when they open" on the Hindi + Hinglish pool screen (PRD 06b F5,
/// 14-states; contracts/api/v1-notifications.md "room_pool_waitlist").
///
/// The tap is kept on this phone and queued for `POST /v1/sync/push` (the one
/// write path) as `room_pool_waitlist` `upsert {pool}`, in one transaction.
/// When the pool opens the server sends one `rooms_pool_open` push — generic,
/// in the app language, on the "Rooms & Lantern Hour" channel, under quiet
/// hours and the daily cap — and forgets the request.
class PoolWaitlist {
  PoolWaitlist({
    required this._db,
    required this._kv,
    required this._outbox,
    required this._time,
    this._notifySync,
  });

  static const String entity = 'room_pool_waitlist';

  /// The pool that opens later (rooms.language_pool `hi`: Hindi + Hinglish).
  static const String hindiPool = 'hi';

  final AppDatabase _db;
  final KvStore _kv;
  final OutboxRepository _outbox;
  final TimeContext Function() _time;
  final void Function()? _notifySync;

  /// Records the request here and for the server, then nudges sync.
  Future<void> request({String pool = hindiPool}) async {
    final t = _time();
    final now = t.now().toUtc();
    await _db.transaction(() async {
      await _kv.set(roomsNotifyHiPoolKey, '1');
      await _outbox.enqueue(
        entity: entity,
        op: Ops.upsert,
        entityId: '$entity:$pool',
        deviceTs: now,
        localDay: t.today(),
        payload: {'pool': pool},
        tz: t.timezone,
      );
    });
    try {
      _notifySync?.call();
    } on Object catch (e) {
      debugPrint('rooms: waitlist sync nudge (${e.runtimeType})');
    }
  }
}

final poolWaitlistProvider = Provider<PoolWaitlist>(
  (ref) => PoolWaitlist(
    db: ref.watch(appDatabaseProvider),
    kv: ref.watch(kvStoreProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    time: () => ref.read(timeContextProvider),
    notifySync: () => ref.read(syncControllerProvider).notifyLocalWrite(),
  ),
);
