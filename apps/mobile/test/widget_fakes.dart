import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/src/features/widget/widget_store.dart';

/// The widget store in memory: what the native widget and the app would
/// share (F11). Records what the app publishes.
class MemoryWidgetHost implements WidgetHost {
  MemoryWidgetHost({List<Map<String, Object?>>? pending})
    : pending = pending ?? [];

  /// `aura.widget.pending` as the widget wrote it.
  List<Map<String, Object?>> pending;

  /// `aura.widget.acked` as the app last wrote it.
  List<String> acked = [];

  final List<Map<String, Object?>> published = [];
  Uint8List? avatar;
  int publishCalls = 0;
  int readCalls = 0;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  Map<String, Object?>? get lastDisplay =>
      published.isEmpty ? null : published.last;

  /// What the widget does on its next write: drops acknowledged records.
  void widgetPrunes() {
    pending = [
      for (final r in pending)
        if (!acked.contains(r['id'])) r,
    ];
  }

  /// The widget saved while the app runs.
  void notifyChanged() => _changes.add(null);

  @override
  Stream<void> get pendingChanged => _changes.stream;

  @override
  Future<String?> readPending() async {
    readCalls++;
    return jsonEncode(pending);
  }

  @override
  Future<void> writeAcked(List<String> ids) async => acked = [...ids];

  @override
  Future<void> publish({required String display, Uint8List? avatarPng}) async {
    publishCalls++;
    published.add(jsonDecode(display) as Map<String, Object?>);
    avatar = avatarPng;
  }
}

/// A widget check-in as the native widget writes it.
Map<String, Object?> widgetRecord({
  required String id,
  String moodId = 'calm',
  required DateTime deviceTs,
  String tz = 'Asia/Kolkata',
  int tzOffsetMinutes = 330,
  String? localDay,
  String? owner,
  int v = widgetStoreVersion,
}) => {
  'v': v,
  'id': id,
  'moodId': moodId,
  'deviceTs': deviceTs.toUtc().toIso8601String(),
  'tzOffsetMinutes': tzOffsetMinutes,
  'tz': tz,
  'localDay': ?localDay,
  'owner': ?owner,
};
