import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/net/aura_api.dart' show ApiException;
import '../ripples/ripple_channel.dart';
import '../ripples/ripple_engine.dart' show ServerClock;
import '../rooms/room_models.dart' show GestureType, ReportReason;
import 'quiet_api.dart';
import 'quiet_models.dart';
import 'quiet_providers.dart' show QuietCues;

enum QuietPhase { joining, here, unavailable, left }

/// One Quiet Together visit on this phone (PRD 06b F16; contracts/api/
/// v1-quiet.md): join, the 30 s heartbeat (which also carries you into the
/// next block), the read-only `quiet:<id>` channel (counts and unnamed
/// gestures), gestures to the whole session, the optional 25/5 rhythm and
/// leaving. Plain Dart + timers, so tests drive it with fake time.
///
/// Never shows a failure once you are here: a dropped link or a failed
/// heartbeat is a "Reconnecting…" chip while everything keeps going locally
/// (the shared sound plays from the phone's cache). Leaving costs nothing.
class QuietController extends ChangeNotifier {
  QuietController({
    required this.api,
    required this.openChannel,
    required this.mode,
    required this.isOnline,
    required this.cues,
    this.timezone,
    this.chimeAllowed,
    int Function()? wallMs,
    Duration Function(int attempt)? backoff,
  }) : wallMs = wallMs ?? _wall,
       backoff = backoff ?? _defaultBackoff;

  final QuietApi? api;
  final RippleChannelOpener? openChannel;
  final QuietMode mode;
  final bool Function() isOnline;
  final QuietCues cues;

  /// The device's IANA zone (picks the region); `null` = the profile's.
  final String? Function()? timezone;

  /// The rhythm's soft chime plays only while the shared sound does.
  final bool Function()? chimeAllowed;
  final int Function() wallMs;
  final Duration Function(int attempt) backoff;

  static int _wall() => DateTime.now().millisecondsSinceEpoch;
  static Duration _defaultBackoff(int attempt) =>
      Duration(milliseconds: 1000 * (1 << math.min(attempt, 4)));

  /// Shown near the end of a block: "The next session starts at 10:00."
  static const Duration nextBlockNoteBefore = Duration(minutes: 5);

  // ---- public state ------------------------------------------------------------
  QuietPhase phase = QuietPhase.joining;
  QuietUnavailable? unavailable;
  QuietSession? session;

  /// Live people here, including you ("12 here"). A number, never a list.
  int count = 0;

  /// Off by default (REQ-QUIET-05); a phone-side choice, never sent.
  bool rhythmOn = false;
  RhythmMoment? rhythmNow;

  /// Bumped at every rhythm change while it is on (the screen announces it).
  int rhythmCues = 0;

  /// "Hide gestures": for yourself only.
  bool hideGestures = false;

  /// The tray rests between gestures (the server's 1 per 10 s).
  bool coolingDown = false;

  /// The latest gesture on screen (unnamed; yours say "You sent …").
  QuietMoment? moment;

  /// The session changed (the next block): the screen re-aligns the sound.
  void Function(QuietSession previous, QuietSession next)? onSessionChanged;

  final ServerClock clock = ServerClock();

  bool get linkLost => _channelLost || _beatLost;

  /// Server-clock now (ms).
  int get serverNowMs => clock.toServer(wallMs());

  bool get nearBlockEnd {
    final s = session;
    if (s == null) return false;
    final left = s.endsAtMs - serverNowMs;
    return left > 0 && left <= nextBlockNoteBefore.inMilliseconds;
  }

  // ---- internals -----------------------------------------------------------------
  RippleChannel? _channel;
  int _channelGen = 0;
  int _channelAttempt = 0;
  bool _channelLost = false;
  bool _beatLost = false;
  bool _beating = false;
  bool _disposed = false;
  int _serial = 0;
  final Set<String> _ownIds = {};
  Timer? _heartbeat;
  Timer? _blockEnd;
  Timer? _rhythm;
  Timer? _cooldown;
  Timer? _reopen;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---- join ---------------------------------------------------------------------
  Future<void> start() async {
    final a = api;
    if (a == null || !isOnline()) {
      _setUnavailable(QuietUnavailable.offline);
      return;
    }
    phase = QuietPhase.joining;
    unavailable = null;
    _notify();
    try {
      final sent = wallMs();
      final s = await a.join(mode, timezone: timezone?.call());
      if (_disposed || phase == QuietPhase.left) return;
      _sample(sent, s);
      _adopt(s);
    } on Object catch (e) {
      if (_disposed || phase == QuietPhase.left) return;
      _setUnavailable(quietUnavailableFor(e) ?? QuietUnavailable.failed);
    }
  }

  void _setUnavailable(QuietUnavailable why) {
    _stopTimers();
    _closeChannel();
    phase = QuietPhase.unavailable;
    unavailable = why;
    _notify();
  }

  void _sample(int sentMs, QuietSession s) => clock.sample(
    sentMs: sentMs,
    receivedMs: wallMs(),
    serverMs: s.serverTimeMs,
  );

  void _adopt(QuietSession s) {
    final previous = session;
    session = s;
    count = math.max(1, s.count);
    phase = QuietPhase.here;
    unavailable = null;
    _beatLost = false;
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
      Duration(milliseconds: math.max(5000, s.heartbeatMs)),
      (_) => unawaited(_beat()),
    );
    _scheduleBlockEnd();
    _scheduleRhythm();
    if (previous == null || previous.sessionId != s.sessionId) {
      unawaited(_openChannel(s));
      if (previous != null) onSessionChanged?.call(previous, s);
    }
    _notify();
  }

  // ---- heartbeat, next block ---------------------------------------------------------
  Future<void> _beat() async {
    final a = api;
    final s = session;
    if (a == null || s == null || _disposed || _beating) return;
    if (phase != QuietPhase.here) return;
    _beating = true;
    try {
      final sent = wallMs();
      final next = await a.heartbeat(s.sessionId);
      if (_disposed || phase != QuietPhase.here) return;
      _sample(sent, next);
      _adopt(next);
    } on ApiException catch (e) {
      if (_disposed || phase != QuietPhase.here) return;
      if (e.status == 404) {
        // Went quiet too long, or joined elsewhere: drop in again, silently.
        await _rejoin();
      } else if (!e.isNetwork && e.status != null && e.status! < 500) {
        final why = quietUnavailableFor(e);
        if (why != null) {
          _setUnavailable(why);
        } else {
          _beatLost = true;
          _notify();
        }
      } else {
        _beatLost = true; // "Reconnecting…": the next beat tries again
        _notify();
      }
    } on Object {
      if (!_disposed) {
        _beatLost = true;
        _notify();
      }
    } finally {
      _beating = false;
    }
  }

  Future<void> _rejoin() async {
    final a = api;
    if (a == null) return;
    try {
      final sent = wallMs();
      final s = await a.join(mode, timezone: timezone?.call());
      if (_disposed || phase != QuietPhase.here) return;
      _sample(sent, s);
      _adopt(s);
    } on Object catch (e) {
      if (_disposed) return;
      final why = quietUnavailableFor(e);
      if (why != null && why != QuietUnavailable.offline) {
        _setUnavailable(why);
      } else {
        _beatLost = true;
        _notify();
      }
    }
  }

  /// Just after the block's end the heartbeat carries you into the next one.
  void _scheduleBlockEnd() {
    _blockEnd?.cancel();
    final s = session;
    if (s == null) return;
    final wait = s.endsAtMs - serverNowMs + 1500;
    _blockEnd = Timer(
      Duration(milliseconds: math.max(0, wait)),
      () => unawaited(_beat()),
    );
  }

  /// Connectivity changed (the screen listens): back online beats at once
  /// and reopens a lost channel; an offline start tries again.
  void onConnectivity(bool online) {
    if (_disposed) return;
    if (!online) {
      if (phase == QuietPhase.here) {
        _beatLost = true;
        _notify();
      }
      return;
    }
    if (phase == QuietPhase.unavailable &&
        unavailable == QuietUnavailable.offline) {
      unawaited(start());
    } else if (phase == QuietPhase.here) {
      unawaited(_beat());
      final s = session;
      if (_channelLost && s != null) unawaited(_openChannel(s));
    }
  }

  // ---- realtime ------------------------------------------------------------------------
  Future<void> _openChannel(QuietSession s) async {
    _closeChannel();
    final open = openChannel;
    if (open == null) return;
    final gen = ++_channelGen;
    try {
      final ch = await open(s.realtimeTopic);
      if (_disposed || gen != _channelGen) {
        unawaited(ch.close());
        return;
      }
      _channel = ch;
      ch.onEvent((event, payload) {
        if (gen == _channelGen) _onEvent(event, payload);
      });
      ch.subscribe((status) {
        if (gen != _channelGen || _disposed) return;
        if (status == RippleLinkStatus.subscribed) {
          _channelAttempt = 0;
          if (_channelLost) {
            _channelLost = false;
            _notify();
          }
          return;
        }
        _channelLost = true;
        _notify();
        _reopenLater(s);
      });
    } on Object {
      if (_disposed || gen != _channelGen) return;
      _channelLost = true;
      _notify();
      _reopenLater(s);
    }
  }

  void _reopenLater(QuietSession s) {
    _reopen?.cancel();
    _reopen = Timer(backoff(_channelAttempt++), () {
      if (_disposed || phase != QuietPhase.here) return;
      if (session?.sessionId == s.sessionId) unawaited(_openChannel(s));
    });
  }

  void _closeChannel() {
    _channelGen++;
    _reopen?.cancel();
    final ch = _channel;
    _channel = null;
    if (ch != null) unawaited(ch.close());
  }

  void _onEvent(String event, Map<String, dynamic> payload) {
    if (phase != QuietPhase.here) return;
    switch (event) {
      case 'count':
        final n = payload['count'];
        if (n is num && n >= 1) {
          count = n.toInt();
          _notify();
        }
      case 'gesture':
        final id = payload['gestureId'];
        final type = GestureType.fromWire(payload['type'] as String?);
        if (type == null || id is! String || _ownIds.contains(id)) return;
        if (hideGestures) return;
        moment = QuietMoment(
          id: id,
          type: type,
          mine: false,
          serial: ++_serial,
        );
        _notify();
    }
  }

  // ---- gestures ------------------------------------------------------------------------
  /// A preset to the whole session (REQ-QUIET-02). Yours animates at once;
  /// any failure is silent (it simply wasn't seen).
  void sendGesture(GestureType type) {
    final a = api;
    final s = session;
    if (a == null || s == null || coolingDown || phase != QuietPhase.here) {
      return;
    }
    coolingDown = true;
    _cooldown?.cancel();
    _cooldown = Timer(Duration(milliseconds: s.gestureMinIntervalMs), () {
      coolingDown = false;
      _notify();
    });
    moment = QuietMoment(
      id: 'own-${++_serial}',
      type: type,
      mine: true,
      serial: _serial,
    );
    _notify();
    unawaited(
      a
          .gesture(s.sessionId, type)
          .then((id) {
            if (id.isNotEmpty) _ownIds.add(id);
          })
          .catchError((Object e) {
            if (e is ApiException && e.code == 'block_over') unawaited(_beat());
          }),
    );
  }

  void setHideGestures(bool hide) {
    hideGestures = hide;
    if (hide) moment = null;
    _notify();
  }

  // ---- the focus rhythm -----------------------------------------------------------------
  void setRhythm(bool on) {
    rhythmOn = on && session?.rhythm != null;
    rhythmNow = null; // turning it on is not a change to cue
    _scheduleRhythm();
    _notify();
  }

  /// Recomputes where the shared rhythm is and schedules the next change.
  /// A change since the last look (the timer, or a heartbeat landing on the
  /// boundary) cues once: a haptic, a chime while the shared sound plays.
  void _scheduleRhythm() {
    _rhythm?.cancel();
    final s = session;
    final r = s?.rhythm;
    final before = rhythmNow;
    if (s == null || r == null || !rhythmOn) {
      rhythmNow = null;
      return;
    }
    final now = rhythmAt(s.t0Ms, serverNowMs, r);
    rhythmNow = now;
    if (before != null && before.onBreak != now.onBreak) {
      cues.rhythm(toBreak: now.onBreak, chime: chimeAllowed?.call() ?? false);
      rhythmCues++;
    }
    final wait = now.nextChangeMs - serverNowMs + 50;
    _rhythm = Timer(Duration(milliseconds: math.max(0, wait)), () {
      if (_disposed || !rhythmOn) return;
      _scheduleRhythm();
      _notify();
    });
  }

  // ---- safety ----------------------------------------------------------------------------
  /// "Report a problem here" → whether the Safety Center should open.
  Future<bool> report(ReportReason reason, {String? note}) async {
    final a = api;
    final s = session;
    if (a == null || s == null) throw const ApiException(code: 'no_session');
    return a.report(s.sessionId, reason, note: note);
  }

  // ---- leaving ----------------------------------------------------------------------------
  /// Leaving costs nothing: no confirmation, no "left early".
  void leave() {
    if (phase == QuietPhase.left) return;
    final s = session;
    phase = QuietPhase.left;
    _stopTimers();
    _closeChannel();
    final a = api;
    if (a != null && s != null) {
      unawaited(a.leave(s.sessionId).catchError((Object _) {}));
    }
    _notify();
  }

  void _stopTimers() {
    _heartbeat?.cancel();
    _blockEnd?.cancel();
    _rhythm?.cancel();
    _cooldown?.cancel();
    _reopen?.cancel();
  }

  @override
  void dispose() {
    leave();
    _disposed = true;
    super.dispose();
  }
}
