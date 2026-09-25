import 'dart:async';
import 'dart:convert';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The store the app and the home-screen widget share (F11): iOS App Group
/// `group.com.akvega.aura` user defaults, Android app-private shared
/// preferences (`aura_widget`). Three JSON strings, each with one writer, so
/// the widget and the app never overwrite each other:
///
/// | key                  | writer | what                                    |
/// |----------------------|--------|-----------------------------------------|
/// | `aura.widget.display`| app    | what the widget shows (buildWidgetDisplay) |
/// | `aura.widget.pending`| widget | check-ins saved in the widget            |
/// | `aura.widget.acked`  | app    | ids of pending check-ins already handled |
///
/// The widget drops acknowledged ids from `pending` the next time it writes
/// it. The avatar PNG sits next to the store (App Group container / app
/// files dir), written by the app only.
///
/// Versioned: every record carries `v`. The importer accepts every version up
/// to [widgetStoreVersion] (and newer ones when their fields still parse), so
/// a check-in saved by an older widget survives an app update.
const int widgetStoreVersion = 1;

/// A mood-only check-in the widget saved (F11 "client id + day stamp").
@immutable
class WidgetCheckIn {
  const WidgetCheckIn({
    required this.id,
    required this.moodId,
    required this.deviceTs,
    required this.tzOffsetMinutes,
    required this.tz,
    required this.localDay,
    required this.owner,
    this.version = widgetStoreVersion,
  });

  /// Client UUIDv7 made by the widget.
  final String id;
  final String moodId;

  /// When the mood was tapped (UTC).
  final DateTime deviceTs;
  final int tzOffsetMinutes;

  /// IANA zone the widget stamped [localDay] in.
  final String tz;

  /// The Aura day (04:00 rollover) the widget stamped; `null` when missing
  /// or malformed (the importer then derives it from [deviceTs] and [tz]).
  final LocalDay? localDay;

  /// The owner token the app published when this was saved; a check-in
  /// saved for another account (or before sign-in) is never imported.
  final String? owner;
  final int version;

  Map<String, Object?> toJson() => {
    'v': version,
    'id': id,
    'moodId': moodId,
    'deviceTs': deviceTs.toUtc().toIso8601String(),
    'tzOffsetMinutes': tzOffsetMinutes,
    'tz': tz,
    if (localDay != null) 'localDay': localDay!.toIso(),
    if (owner != null) 'owner': owner,
  };
}

/// What `aura.widget.pending` holds: the records that parse, and the ids of
/// those that don't (they are acknowledged so the widget drops them).
@immutable
class PendingWidgetCheckIns {
  const PendingWidgetCheckIns(this.records, this.unreadableIds);

  static const PendingWidgetCheckIns empty = PendingWidgetCheckIns([], []);

  final List<WidgetCheckIn> records;
  final List<String> unreadableIds;

  bool get isEmpty => records.isEmpty && unreadableIds.isEmpty;
}

final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Parses `aura.widget.pending`. Tolerant: a malformed store reads as empty,
/// a malformed record is skipped (its id, when it has one, is reported so it
/// can be acknowledged), unknown fields are ignored.
PendingWidgetCheckIns parsePendingWidgetCheckIns(String? raw) {
  if (raw == null || raw.trim().isEmpty) return PendingWidgetCheckIns.empty;
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return PendingWidgetCheckIns.empty;
  }
  final list = switch (decoded) {
    final List<Object?> l => l,
    {'records': final List<Object?> l} => l,
    _ => const <Object?>[],
  };
  final records = <WidgetCheckIn>[];
  final unreadable = <String>[];
  final seen = <String>{};
  for (final item in list) {
    if (item is! Map) continue;
    final id = item['id'];
    if (id is! String || !_uuid.hasMatch(id.toLowerCase())) continue;
    final record = _record(item, id.toLowerCase());
    if (record == null) {
      unreadable.add(id);
    } else if (seen.add(record.id)) {
      records.add(record);
    }
  }
  return PendingWidgetCheckIns(records, unreadable);
}

WidgetCheckIn? _record(Map<Object?, Object?> m, String id) {
  final moodId = m['moodId'];
  final ts = m['deviceTs'];
  final tz = m['tz'];
  if (moodId is! String || ts is! String || tz is! String || tz.isEmpty) {
    return null;
  }
  final deviceTs = DateTime.tryParse(ts);
  if (deviceTs == null) return null;
  final offset = m['tzOffsetMinutes'];
  final day = m['localDay'];
  final version = m['v'];
  final owner = m['owner'];
  return WidgetCheckIn(
    id: id,
    moodId: moodId,
    deviceTs: deviceTs.toUtc(),
    tzOffsetMinutes: offset is num ? offset.round() : 0,
    tz: tz,
    localDay: day is String ? LocalDay.tryParse(day) : null,
    owner: owner is String ? owner : null,
    version: version is num ? version.round() : widgetStoreVersion,
  );
}

/// The platform side of the shared store (MethodChannel
/// `com.akvega.aura/widget`; iOS AppDelegate `AuraWidgetChannel`, Android
/// `AuraWidgetBridge`). Every call is best-effort: without a widget host
/// (tests, desktop) they do nothing.
abstract class WidgetHost {
  /// The raw `aura.widget.pending` JSON, or null.
  Future<String?> readPending();

  /// Replaces `aura.widget.acked` with [ids].
  Future<void> writeAcked(List<String> ids);

  /// Writes `aura.widget.display` and the avatar PNG ([avatarPng] null →
  /// removed), then asks the OS to redraw the widgets.
  Future<void> publish({required String display, Uint8List? avatarPng});

  /// Fires when the widget saved a check-in while this process runs
  /// (Android: same process; iOS: a Darwin notification from the extension).
  Stream<void> get pendingChanged;
}

class ChannelWidgetHost implements WidgetHost {
  ChannelWidgetHost({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pendingChanged') _changes.add(null);
      return null;
    });
  }

  static const String channelName = 'com.akvega.aura/widget';

  final MethodChannel _channel;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get pendingChanged => _changes.stream;

  @override
  Future<String?> readPending() => _call<String>('readPending');

  @override
  Future<void> writeAcked(List<String> ids) =>
      _call<void>('writeAcked', jsonEncode(ids));

  @override
  Future<void> publish({required String display, Uint8List? avatarPng}) =>
      _call<void>('publish', {'display': display, 'avatar': avatarPng});

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('widget: $method failed (${e.code})');
      return null;
    }
  }
}
