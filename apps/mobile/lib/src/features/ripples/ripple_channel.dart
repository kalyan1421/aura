import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// How a private Realtime channel is doing.
enum RippleLinkStatus { subscribed, error, closed, timedOut }

/// One private channel: `game:<sessionId>` (Broadcast + Presence, the
/// players write too) or `ripples:<roomId>` (invite hints, read only).
/// Abstract so tests can drive it.
abstract interface class RippleChannel {
  /// Every broadcast on the topic. Register before [subscribe].
  void onEvent(void Function(String event, Map<String, dynamic> payload) cb);

  void subscribe(void Function(RippleLinkStatus status) onStatus);

  /// Client-to-client broadcast (breath_state, pulse, gesture, heartbeat).
  Future<void> send(String event, Map<String, dynamic> payload);

  /// Presence for join/leave: `{seat}` only.
  Future<void> track(Map<String, dynamic> payload);

  Future<void> close();
}

typedef RippleChannelOpener = Future<RippleChannel> Function(String topic);

/// Private channels on Supabase Realtime, authorised by RLS on
/// `realtime.messages` (migration 20261005000021) with the user's token.
RippleChannelOpener supabaseRippleChannels(
  sb.SupabaseClient client,
  Future<String?> Function() accessToken,
) => (topic) async {
  final token = await accessToken();
  if (token != null) {
    try {
      await client.realtime.setAuth(token);
    } on Object catch (e) {
      debugPrint('ripples: realtime auth (${e.runtimeType})');
    }
  }
  final channel = client.channel(
    topic,
    opts: const sb.RealtimeChannelConfig(private: true),
  );
  return _SupabaseRippleChannel(client, channel);
};

class _SupabaseRippleChannel implements RippleChannel {
  _SupabaseRippleChannel(this._client, this._channel);

  final sb.SupabaseClient _client;
  final sb.RealtimeChannel _channel;

  @override
  void onEvent(void Function(String event, Map<String, dynamic> payload) cb) {
    _channel.onBroadcast(
      event: '*',
      callback: (message) {
        final event = message['event'];
        final payload = message['payload'];
        if (event is! String) return;
        cb(
          event,
          payload is Map ? Map<String, dynamic>.from(payload) : const {},
        );
      },
    );
  }

  @override
  void subscribe(void Function(RippleLinkStatus status) onStatus) {
    _channel.subscribe((status, error) {
      onStatus(switch (status) {
        sb.RealtimeSubscribeStatus.subscribed => RippleLinkStatus.subscribed,
        sb.RealtimeSubscribeStatus.channelError => RippleLinkStatus.error,
        sb.RealtimeSubscribeStatus.closed => RippleLinkStatus.closed,
        sb.RealtimeSubscribeStatus.timedOut => RippleLinkStatus.timedOut,
      });
    });
  }

  @override
  Future<void> send(String event, Map<String, dynamic> payload) async {
    await _channel.sendBroadcastMessage(event: event, payload: payload);
  }

  @override
  Future<void> track(Map<String, dynamic> payload) async {
    await _channel.track(payload);
  }

  @override
  Future<void> close() async {
    await _client.removeChannel(_channel);
  }
}
