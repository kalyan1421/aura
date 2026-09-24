import 'package:flutter/foundation.dart';

/// F7 Breath Ripples wire shapes (contracts/api/v1-ripples.md "Shared
/// shapes"). Other people appear only as a seat number, a kind and, for
/// humans, a pseudonym (DS-10). Plain immutable classes: no codegen.

/// Where a session was started from.
enum RippleEntry {
  /// Home: the one global queue, a fresh pseudonym.
  quick,

  /// "Breathe together" in a room: the room pseudonym.
  room,
}

/// What a light is.
enum SeatKind {
  human,

  /// A labelled recording of someone who breathed here before (or a person
  /// who left: their light dims into an echo).
  echo,

  /// The pacer itself; never presented as a person.
  guide;

  static SeatKind parse(Object? v) => switch (v) {
    'human' => SeatKind.human,
    'echo' => SeatKind.echo,
    _ => SeatKind.guide,
  };
}

/// The three in-game gestures (PRD F7 "Contact").
enum RippleGesture {
  hug('hug'),
  deepBreath('deep_breath'),
  youreNotAlone('youre_not_alone');

  const RippleGesture(this.wire);

  final String wire;

  static RippleGesture? parse(Object? v) {
    for (final g in values) {
      if (g.wire == v) return g;
    }
    return null;
  }
}

/// One light on the ocean.
@immutable
class RippleSeat {
  const RippleSeat({
    required this.seat,
    required this.kind,
    this.label,
    this.trace = const [],
  });

  factory RippleSeat.fromJson(Map<String, dynamic> j) => RippleSeat(
    seat: (j['seat'] as num).toInt(),
    kind: SeatKind.parse(j['kind']),
    label: j['label'] is String ? j['label'] as String : null,
    trace: j['trace'] is List
        ? [for (final v in j['trace'] as List) v is num ? v.toInt() : null]
        : const [],
  );

  final int seat;
  final SeatKind kind;

  /// Humans: their pseudonym. Echoes and guides: `null` (labelled here).
  final String? label;

  /// Echoes: pacer-relative transition offsets in 50 ms steps (null =
  /// missed).
  final List<int?> trace;
}

/// Event budgets the server hands out (§1.1 `limits`).
@immutable
class RippleLimits {
  const RippleLimits({
    this.eventsPerSecond = 10,
    this.pulseMinMs = 3000,
    this.gestureMinMs = 5000,
    this.heartbeatMs = 2000,
    this.disconnectAfterMs = 3000,
    this.echoAfterMs = 10000,
    this.rejoinWindowMs = 10000,
  });

  factory RippleLimits.fromJson(Map<String, dynamic>? j) {
    int v(String k, int d) => j?[k] is num ? (j![k] as num).toInt() : d;
    return RippleLimits(
      eventsPerSecond: v('eventsPerSecond', 10),
      pulseMinMs: v('pulseMinMs', 3000),
      gestureMinMs: v('gestureMinMs', 5000),
      heartbeatMs: v('heartbeatMs', 2000),
      disconnectAfterMs: v('disconnectAfterMs', 3000),
      echoAfterMs: v('echoAfterMs', 10000),
      rejoinWindowMs: v('rejoinWindowMs', 10000),
    );
  }

  final int eventsPerSecond;
  final int pulseMinMs;
  final int gestureMinMs;
  final int heartbeatMs;
  final int disconnectAfterMs;
  final int echoAfterMs;
  final int rejoinWindowMs;
}

/// A session as this phone sees it (§2.1).
@immutable
class RippleSession {
  const RippleSession({
    required this.sessionId,
    required this.entry,
    required this.t0Ms,
    required this.mySeat,
    required this.seats,
    this.roomId,
    this.settleMs = 10000,
    this.inhaleMs = 4000,
    this.exhaleMs = 6000,
    this.cycles = 16,
    this.fadeMs = 10000,
    this.pacerVersion = 1,
    this.humans = 1,
    this.echoes = 0,
    this.guides = 0,
    this.ended = false,
    this.topic,
    this.limits = const RippleLimits(),
  });

  factory RippleSession.fromJson(Map<String, dynamic> j) {
    int n(String k, int d) => j[k] is num ? (j[k] as num).toInt() : d;
    final rt = j['realtime'];
    return RippleSession(
      sessionId: j['sessionId'] as String,
      entry: j['entry'] == 'room' ? RippleEntry.room : RippleEntry.quick,
      roomId: j['roomId'] as String?,
      t0Ms: n('t0Ms', 0),
      settleMs: n('settleMs', 10000),
      inhaleMs: n('inhaleMs', 4000),
      exhaleMs: n('exhaleMs', 6000),
      cycles: n('cycles', 16),
      fadeMs: n('fadeMs', 10000),
      pacerVersion: n('pacerVersion', 1),
      mySeat: n('mySeat', 1),
      seats: [
        for (final s in (j['seats'] as List? ?? const []))
          if (s is Map<String, dynamic>) RippleSeat.fromJson(s),
      ],
      humans: n('humans', 1),
      echoes: n('echoes', 0),
      guides: n('guides', 0),
      ended: j['ended'] == true,
      topic: rt is Map && rt['topic'] is String ? rt['topic'] as String : null,
      limits: RippleLimits.fromJson(j['limits'] as Map<String, dynamic>?),
    );
  }

  final String sessionId;
  final RippleEntry entry;
  final String? roomId;

  /// Start of the settle-in, server clock (ms).
  final int t0Ms;
  final int settleMs;
  final int inhaleMs;
  final int exhaleMs;
  final int cycles;
  final int fadeMs;
  final int pacerVersion;
  final int mySeat;
  final List<RippleSeat> seats;

  /// What the session started with, for the intro line only.
  final int humans;
  final int echoes;
  final int guides;
  final bool ended;
  final String? topic;
  final RippleLimits limits;

  int get cycleMs => inhaleMs + exhaleMs;

  /// `t0` + the whole session (180 s at the defaults).
  int get endsAtMs => t0Ms + settleMs + cycles * cycleMs + fadeMs;

  String get channelTopic => topic ?? 'game:$sessionId';

  RippleSeat? seat(int n) {
    for (final s in seats) {
      if (s.seat == n) return s;
    }
    return null;
  }
}

/// "Quiet Comet wants to breathe together · 2/4" (§1.3).
@immutable
class RippleInvite {
  const RippleInvite({
    required this.inviteId,
    required this.fromPseudonym,
    required this.humans,
    required this.capacity,
    required this.startsAtMs,
    this.mine = false,
  });

  factory RippleInvite.fromJson(Map<String, dynamic> j) => RippleInvite(
    inviteId: j['inviteId'] as String,
    fromPseudonym: j['fromPseudonym'] as String? ?? '',
    humans: (j['humans'] as num?)?.toInt() ?? 1,
    capacity: (j['capacity'] as num?)?.toInt() ?? 4,
    startsAtMs: (j['startsAtMs'] as num?)?.toInt() ?? 0,
    mine: j['mine'] == true,
  );

  final String inviteId;
  final String fromPseudonym;
  final int humans;
  final int capacity;
  final int startsAtMs;
  final bool mine;
}

/// One `POST /v1/ripples/match` answer.
@immutable
sealed class MatchPoll {
  const MatchPoll({required this.ticketId, required this.serverTimeMs});

  factory MatchPoll.fromJson(Map<String, dynamic> j) {
    final ticketId = j['ticketId'] as String? ?? '';
    final server = (j['serverTimeMs'] as num?)?.toInt() ?? 0;
    if (j['status'] == 'matched' && j['session'] is Map<String, dynamic>) {
      return MatchMatched(
        ticketId: ticketId,
        serverTimeMs: server,
        session: RippleSession.fromJson(j['session'] as Map<String, dynamic>),
      );
    }
    return MatchWaiting(
      ticketId: ticketId,
      serverTimeMs: server,
      pollAfterMs: (j['pollAfterMs'] as num?)?.toInt() ?? 2000,
      invite: j['invite'] is Map<String, dynamic>
          ? RippleInvite.fromJson(j['invite'] as Map<String, dynamic>)
          : null,
    );
  }

  final String ticketId;
  final int serverTimeMs;
}

class MatchWaiting extends MatchPoll {
  const MatchWaiting({
    required super.ticketId,
    required super.serverTimeMs,
    required this.pollAfterMs,
    this.invite,
  });

  final int pollAfterMs;
  final RippleInvite? invite;
}

class MatchMatched extends MatchPoll {
  const MatchMatched({
    required super.ticketId,
    required super.serverTimeMs,
    required this.session,
  });

  final RippleSession session;
}

/// What the lobby says when breathing together can't happen right now. The
/// person is always offered the solo pacer; never a failure screen.
enum RipplesUnavailable {
  /// "Breathing together needs a connection. Breathe solo instead?"
  offline,

  /// `503 ripples_paused` (kill switch).
  paused,

  /// `403 rooms_suspended`.
  suspended,

  /// `403 account_closed`.
  closed,

  /// `409 guidelines_required`: the community guidelines come first.
  guidelines,
}
