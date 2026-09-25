import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';

import '../checkin/checkin_repository.dart';
import 'widget_store.dart';

/// One widget check-in the app just imported.
@immutable
class ImportedWidgetCheckIn {
  const ImportedWidgetCheckIn({required this.id, required this.mood});

  final String id;
  final Mood mood;
}

/// Brings check-ins saved in the home-screen widget into Drift (F11 "Data
/// path"): each goes through [CheckInRepository.importWidgetCheckIn], so the
/// row and its outbox upsert land together and every check-in rule applies
/// as usual; sync then sends it to `POST /v1/sync/push` with the widget's own
/// `deviceTs`, `localDay` and `tz`.
///
/// Exactly once (REQ-WID-02): the repository ignores an id it already has,
/// and every handled id is acknowledged so the widget drops it. A record is
/// handled when it was imported, was already here, belongs to another
/// account (owner token), or can't be read; nothing handled is retried.
///
/// Mood-only by construction: a widget record carries no note, tags or
/// voice, so there is nothing to crisis-scan and nothing personal to log.
class WidgetIngestor {
  WidgetIngestor({required this._host, required this._checkIns});

  final WidgetHost _host;
  final CheckInRepository _checkIns;

  Future<List<ImportedWidgetCheckIn>>? _running;

  /// Imports what the widget saved for [owner] (the current owner token).
  /// Concurrent calls share one run. Never throws: a failure leaves the
  /// records in the widget's store for the next launch.
  Future<List<ImportedWidgetCheckIn>> ingest({required String owner}) =>
      _running ??= _ingest(owner).whenComplete(() => _running = null);

  Future<List<ImportedWidgetCheckIn>> _ingest(String owner) async {
    final PendingWidgetCheckIns pending;
    try {
      pending = parsePendingWidgetCheckIns(await _host.readPending());
    } catch (e) {
      debugPrint('widget: read failed (${e.runtimeType})');
      return const [];
    }
    if (pending.isEmpty) return const [];

    final handled = <String>[...pending.unreadableIds];
    final imported = <ImportedWidgetCheckIn>[];
    final records = [...pending.records]
      ..sort((a, b) => a.deviceTs.compareTo(b.deviceTs));
    for (final r in records) {
      final mood = moodById(r.moodId);
      if (r.owner != owner || mood == null) {
        handled.add(r.id);
        continue;
      }
      // The same zone policy as the app's own stamps: an id the tz database
      // doesn't know becomes a fixed-offset zone (the server would refuse it
      // as `invalid_tz`).
      final tz = resolveTimeZone(r.tz, Duration(minutes: r.tzOffsetMinutes));
      final day = r.localDay ?? auraDay(r.deviceTs, tz);
      try {
        final inserted = await _checkIns.importWidgetCheckIn(
          id: r.id,
          mood: mood,
          deviceTs: r.deviceTs,
          tzOffsetMinutes: r.tzOffsetMinutes,
          tz: tz,
          localDay: day,
        );
        handled.add(r.id);
        if (inserted) imported.add(ImportedWidgetCheckIn(id: r.id, mood: mood));
      } catch (e) {
        // Left in the widget's store (not acknowledged): tried again later.
        debugPrint('widget: import failed (${e.runtimeType})');
      }
    }
    try {
      await _host.writeAcked(handled);
    } catch (e) {
      debugPrint('widget: ack failed (${e.runtimeType})');
    }
    return imported;
  }
}
