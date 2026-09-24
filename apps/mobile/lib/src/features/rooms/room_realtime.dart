import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'room_models.dart';

/// The realtime link, for the "Reconnecting…" chip (PRD States: Room).
enum RoomLink {
  /// Not connected and not trying (no realtime in this build, a memory, or
  /// the room was left).
  off,

  /// The first join is on its way.
  connecting,

  /// Both private topics are joined.
  live,

  /// Dropped (or refused): trying again with backoff.
  reconnecting,
}

// ---- events (contracts/api/v1-rooms.md §3) -----------------------------------

/// A server broadcast on `room:<roomId>` or `member:<memberId>`. Payloads are
/// ids, pseudonyms and preset keys only (DS-10). Delivery is best-effort:
/// they are hints, and the room detail is refetched after (re)subscribing.
@immutable
sealed class RoomEvent {
  const RoomEvent();
}

class MemberJoinedEvent extends RoomEvent {
  const MemberJoinedEvent(this.member, this.counts);
  final RoomMember member;
  final RoomCounts? counts;
}

class MemberLeftEvent extends RoomEvent {
  const MemberLeftEvent(this.memberId, this.counts);
  final String memberId;
  final RoomCounts? counts;
}

/// "Here now" changed.
class PresenceEvent extends RoomEvent {
  const PresenceEvent(this.counts);
  final RoomCounts counts;
}

/// Every delivered gesture, anonymous ("others see an unnamed animation").
class GestureSentEvent extends RoomEvent {
  const GestureSentEvent(this.gesture);
  final RoomGesture gesture;
}

/// Only on your own member topic: who sent you what.
class GestureReceivedEvent extends RoomEvent {
  const GestureReceivedEvent(this.gesture, {this.reflectionId});
  final ReceivedGesture gesture;

  /// Set when the gesture was on your reflection (F6).
  final String? reflectionId;
}

/// A reflection changed (F6, contracts/api/v1-reflections.md §2): ids only,
/// the reflections list refetches. [event] is the broadcast's name
/// (`reflection_published`, `reflection_removed`, `reflection_status`);
/// [status] only for your own (`reflection_status`).
class ReflectionEvent extends RoomEvent {
  const ReflectionEvent(this.event, this.reflectionId, {this.status});
  final String event;
  final String reflectionId;
  final String? status;
}

class RoomStateEvent extends RoomEvent {
  const RoomStateEvent({
    required this.state,
    required this.readOnly,
    this.joinsCloseAt,
    this.memoryAt,
    this.purgeAt,
    this.carriesTotals = false,
    this.lantern,
    this.intention,
  });

  final String state;
  final bool readOnly;
  final DateTime? joinsCloseAt;
  final DateTime? memoryAt;
  final DateTime? purgeAt;

  /// The payload has the Milestone B room totals (`lantern`, `intention`,
  /// either may be null). Room totals only: no member id, ever.
  final bool carriesTotals;
  final RoomLantern? lantern;
  final RoomIntention? intention;
}

class LanternHourEvent extends RoomEvent {
  const LanternHourEvent(this.lanternHour);
  final LanternHour lanternHour;
}

/// Parses one broadcast; `null` for an unknown event or a payload that
/// doesn't fit (ignored: the next refetch has the truth).
RoomEvent? parseRoomEvent(String event, Map<String, dynamic> payload) {
  RoomCounts? counts() => payload['counts'] is Map<String, dynamic>
      ? RoomCounts.fromJson(payload['counts'] as Map<String, dynamic>)
      : null;
  DateTime? time(String key) =>
      payload[key] is String ? DateTime.tryParse(payload[key] as String) : null;
  try {
    switch (event) {
      case 'member_joined':
        final m = payload['member'];
        if (m is! Map<String, dynamic>) return null;
        // A new member is live; mute and "me" are this phone's business.
        return MemberJoinedEvent(
          RoomMember.fromJson(m)
              .copyWith(live: true, muted: false, isMe: false),
          counts(),
        );
      case 'member_left':
        final id = payload['memberId'];
        return id is String ? MemberLeftEvent(id, counts()) : null;
      case 'presence':
        final c = counts();
        return c == null ? null : PresenceEvent(c);
      case 'gesture_sent':
        return GestureSentEvent(RoomGesture.fromJson(payload));
      case 'gesture_received':
        final onReflection = payload['reflectionId'];
        return GestureReceivedEvent(
          ReceivedGesture.fromJson(payload),
          reflectionId: onReflection is String ? onReflection : null,
        );
      case 'reflection_published' ||
          'reflection_removed' ||
          'reflection_status':
        final id = payload['reflectionId'];
        if (id is! String) return null;
        final status = payload['status'];
        return ReflectionEvent(
          event,
          id,
          status: status is String ? status : null,
        );
      case 'room_state':
        final state = payload['state'];
        if (state is! String) return null;
        final lantern = payload['lantern'];
        final intention = payload['intention'];
        return RoomStateEvent(
          state: state,
          readOnly: payload['readOnly'] == true,
          joinsCloseAt: time('joinsCloseAt'),
          memoryAt: time('memoryAt'),
          purgeAt: time('purgeAt'),
          carriesTotals:
              payload.containsKey('lantern') ||
              payload.containsKey('intention'),
          lantern: lantern is Map<String, dynamic>
              ? RoomLantern.fromJson(lantern)
              : null,
          intention: intention is Map<String, dynamic>
              ? RoomIntention.fromJson(intention)
              : null,
        );
      case 'lantern_hour':
        final lantern = payload['lanternHour'];
        if (lantern is! Map<String, dynamic>) return null;
        return LanternHourEvent(LanternHour.fromJson(lantern));
    }
  } on Object catch (e) {
    debugPrint('rooms: realtime payload skipped ($event, ${e.runtimeType})');
  }
  return null;
}

// ---- channels -----------------------------------------------------------------

enum RoomChannelStatus { subscribed, error, closed, timedOut }

/// One private Broadcast channel (a topic). Abstract so tests can drive it.
abstract interface class RoomChannel {
  /// Every broadcast on the topic. Register before [subscribe].
  void onEvent(void Function(String event, Map<String, dynamic> payload) cb);

  /// Joins; [onStatus] may be called again later (a drop, a rejoin).
  void subscribe(void Function(RoomChannelStatus status) onStatus);

  /// Leaves the topic for good.
  Future<void> close();
}

/// Opens a (not yet subscribed) private channel for a topic.
typedef RoomChannelOpener = Future<RoomChannel> Function(String topic);

/// Backoff between reconnect attempts: 1, 2, 4, 8, 16 then 30 s, each with
/// up to 20% jitter so a room full of phones doesn't rejoin in step.
Duration realtimeBackoff(int attempt, [math.Random? random]) {
  final base = math.min(30000, 1000 * (1 << math.min(attempt, 5)));
  final jitter = ((random ?? _random).nextDouble() * 0.2 * base).round();
  return Duration(milliseconds: base + jitter);
}

final math.Random _random = math.Random();

/// Keeps a room's two private topics joined: `room:<roomId>` (everyone) and
/// `member:<memberId>` (only you). Any drop, refusal or timeout closes both
/// and joins again after a backoff; every successful (re)join calls
/// [onSubscribed] so the room refetches what it may have missed. [stop]
/// leaves both (always after leaving a room: Realtime only re-checks access
/// on join and token refresh).
class RoomRealtime {
  RoomRealtime({
    required this.open,
    required this.onEvent,
    required this.onLink,
    required this.onSubscribed,
    Duration Function(int attempt)? backoff,
  }) : backoff = backoff ?? realtimeBackoff;

  final RoomChannelOpener open;
  final void Function(RoomEvent event) onEvent;
  final void Function(RoomLink link) onLink;
  final VoidCallback onSubscribed;
  final Duration Function(int attempt) backoff;

  RealtimeTopics? _topics;
  final List<RoomChannel> _channels = [];
  final Set<String> _joined = {};

  /// Bumped on every (re)connect and on [stop]: late callbacks from older
  /// channels are ignored.
  int _generation = 0;
  int _attempt = 0;
  Timer? _retry;
  bool _stopped = true;
  bool _everLive = false;
  RoomLink _link = RoomLink.off;

  RoomLink get link => _link;

  void start(RealtimeTopics topics) {
    _topics = topics;
    _stopped = false;
    unawaited(_connect());
  }

  /// Reconnects at once (app back in the foreground, connection back),
  /// unless already live.
  void retryNow() {
    if (_stopped || _topics == null || _link == RoomLink.live) return;
    _retry?.cancel();
    _retry = null;
    _attempt = 0;
    unawaited(_connect());
  }

  Future<void> stop() async {
    _stopped = true;
    _generation++;
    _retry?.cancel();
    _retry = null;
    _setLink(RoomLink.off);
    final channels = [..._channels];
    _channels.clear();
    _joined.clear();
    for (final c in channels) {
      await _closeQuietly(c);
    }
  }

  Future<void> _connect() async {
    final topics = _topics;
    if (topics == null || _stopped) return;
    final gen = ++_generation;
    final old = [..._channels];
    _channels.clear();
    _joined.clear();
    for (final c in old) {
      unawaited(_closeQuietly(c));
    }
    _setLink(
      _everLive || _attempt > 0 ? RoomLink.reconnecting : RoomLink.connecting,
    );
    for (final topic in [topics.roomTopic, topics.memberTopic]) {
      final RoomChannel channel;
      try {
        channel = await open(topic);
      } on Object catch (e) {
        debugPrint('rooms: realtime open failed (${e.runtimeType})');
        _failed(gen);
        return;
      }
      if (gen != _generation || _stopped) {
        unawaited(_closeQuietly(channel));
        return;
      }
      _channels.add(channel);
      channel.onEvent((event, payload) {
        if (gen != _generation || _stopped) return;
        final parsed = parseRoomEvent(event, payload);
        if (parsed != null) onEvent(parsed);
      });
      channel.subscribe((status) => _onStatus(gen, topic, status));
    }
  }

  void _onStatus(int gen, String topic, RoomChannelStatus status) {
    if (gen != _generation || _stopped) return;
    if (status == RoomChannelStatus.subscribed) {
      _joined.add(topic);
      if (_joined.length == 2) {
        _attempt = 0;
        _everLive = true;
        _setLink(RoomLink.live);
        onSubscribed();
      }
      return;
    }
    _joined.remove(topic);
    _failed(gen);
  }

  void _failed(int gen) {
    if (gen != _generation || _stopped) return;
    _setLink(RoomLink.reconnecting);
    if (_retry != null) return;
    _retry = Timer(backoff(_attempt++), () {
      _retry = null;
      if (!_stopped) unawaited(_connect());
    });
  }

  void _setLink(RoomLink link) {
    if (link == _link) return;
    _link = link;
    onLink(link);
  }

  static Future<void> _closeQuietly(RoomChannel c) async {
    try {
      await c.close();
    } on Object catch (e) {
      debugPrint('rooms: realtime close (${e.runtimeType})');
    }
  }
}

// ---- Supabase ------------------------------------------------------------------

/// Private channels on Supabase Realtime, authorised by RLS on
/// `realtime.messages` with the user's access token. The token is set
/// fresh before each join (supabase_flutter also keeps it current on
/// refresh, which is when the server re-checks access).
RoomChannelOpener supabaseRoomChannels(
  sb.SupabaseClient client,
  Future<String?> Function() accessToken,
) => (topic) async {
  final token = await accessToken();
  if (token != null) {
    try {
      await client.realtime.setAuth(token);
    } on Object catch (e) {
      debugPrint('rooms: realtime auth (${e.runtimeType})');
    }
  }
  final channel = client.channel(
    topic,
    opts: const sb.RealtimeChannelConfig(private: true),
  );
  return _SupabaseRoomChannel(client, channel);
};

class _SupabaseRoomChannel implements RoomChannel {
  _SupabaseRoomChannel(this._client, this._channel);

  final sb.SupabaseClient _client;
  final sb.RealtimeChannel _channel;

  @override
  void onEvent(void Function(String event, Map<String, dynamic> payload) cb) {
    _channel.onBroadcast(
      event: '*',
      callback: (message) {
        // `{type: broadcast, event, payload: {…}}`; Realtime adds an `id`
        // to the payload, which is ignored.
        final event = message['event'];
        final payload = message['payload'];
        if (event is! String) return;
        cb(
          event,
          payload is Map ? Map<String, dynamic>.from(payload) : message,
        );
      },
    );
  }

  @override
  void subscribe(void Function(RoomChannelStatus status) onStatus) {
    _channel.subscribe((status, error) {
      if (error != null) {
        debugPrint('rooms: realtime ${status.name} (${error.runtimeType})');
      }
      onStatus(switch (status) {
        sb.RealtimeSubscribeStatus.subscribed => RoomChannelStatus.subscribed,
        sb.RealtimeSubscribeStatus.channelError => RoomChannelStatus.error,
        sb.RealtimeSubscribeStatus.closed => RoomChannelStatus.closed,
        sb.RealtimeSubscribeStatus.timedOut => RoomChannelStatus.timedOut,
      });
    });
  }

  @override
  Future<void> close() async {
    await _client.removeChannel(_channel);
  }
}
