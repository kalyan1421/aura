import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/net/aura_api.dart' show ApiException;
import '../sanctuary/breath_pacer.dart';
import 'ripple_channel.dart';
import 'ripple_engine.dart';
import 'ripple_feedback.dart';
import 'ripple_models.dart';
import 'ripples_api.dart';

/// Where the whole experience is (the screen's top-level switch).
enum RipplePhase {
  /// Looking for others; the local pacer runs at once (PRD 14 "Pacer starts
  /// at once: Looking for others to breathe with…").
  lobby,
  playing,

  /// The end screen ("Breathe again", "Back to room", "Done").
  ended,

  /// Can't breathe together right now: a calm line and the solo pacer.
  unavailable,
}

/// How another light is behaving (PRD F7 "Player states"). Nobody is ever
/// shown as "left", "failed" or "disconnected": a quiet light simply follows
/// the pacer, then dims into an echo.
enum LightMode { live, quiet, echo, guide }

/// One light as drawn this frame.
@immutable
class LightView {
  const LightView({
    required this.seat,
    required this.kind,
    required this.mode,
    required this.fill,
    required this.me,
    this.label,
    this.pulseAge,
    this.gesture,
    this.muted = false,
  });

  final int seat;
  final SeatKind kind;
  final LightMode mode;

  /// 0–1: how full this light's breath is.
  final double fill;
  final bool me;

  /// Humans (live or quiet): their pseudonym.
  final String? label;

  /// ms since this light's last pulse (a visual ring), or null.
  final int? pulseAge;

  /// A gesture this light just sent (shown briefly by it).
  final RippleGesture? gesture;
  final bool muted;
}

/// A received gesture or pulse, for the live region and the gesture label.
@immutable
class RippleNotice {
  const RippleNotice(this.seat, this.label, {this.gesture});

  final int seat;
  final String? label;

  /// `null` = a pulse.
  final RippleGesture? gesture;
}

class _Other {
  _Other(this.seat, this.lastHeardMs);

  final int seat;
  int lastHeardMs;
  bool inhaling = false;
  int phaseAtMs = 0;
  final List<int> offsets = [];
  final EventBudget budget = EventBudget(10);
  final MinInterval pulses = MinInterval(3000);
  final MinInterval gestures = MinInterval(5000);
  bool flooded = false;
  int? pulseAtMs;
  RippleGesture? gesture;
  int? gestureAtMs;

  int get medianOffset {
    if (offsets.isEmpty) return 0;
    final s = [...offsets]..sort();
    return s[s.length ~/ 2];
  }
}

/// A Breath Ripples session on this phone, from the lobby to the end screen
/// (PRD 06b F7; contracts/api/v1-ripples.md). Plain Dart + timers: the
/// screen drives time with [advance] from its ticker (so pauses of the UI
/// never shift the shared pacer) and renders [lights]. Never shows a
/// failure: a lost connection keeps the session going locally.
class RippleController extends ChangeNotifier {
  RippleController({
    required this.api,
    required this.openChannel,
    required this.entry,
    required this.newTicketId,
    required this.isOnline,
    required this.wallMs,
    required this.feedback,
    this.roomId,
    this.onBreatheHabit,
    this.backoff = _defaultBackoff,
  });

  final RipplesApi? api;
  final RippleChannelOpener? openChannel;
  final RippleEntry entry;
  final String? roomId;
  final String Function() newTicketId;
  final bool Function() isOnline;

  /// The wall clock (ms since epoch), for the server-clock estimate only.
  final int Function() wallMs;
  final RippleFeedback feedback;

  /// ≥ 6 cycles (60 s, as F15 Breathe): tick off today's Breathe habit (F2).
  final Future<void> Function()? onBreatheHabit;
  final Duration Function(int attempt) backoff;

  static Duration _defaultBackoff(int attempt) =>
      Duration(milliseconds: 1000 * (1 << math.min(attempt, 3)));

  /// Breathe habit after this many cycles (PRD F7 "≥6 cycles (60 s)").
  static const int habitCycles = 6;

  // ---- public state -----------------------------------------------------------
  RipplePhase phase = RipplePhase.lobby;
  RipplesUnavailable? unavailable;
  RippleSession? session;
  RippleInvite? invite;

  /// The realtime link dropped: "You're breathing on your own for a moment."
  bool linkLost = false;

  /// Still alone after the rejoin window: the session finishes on this phone.
  bool alone = false;

  /// Tap-to-switch input, tones, and sync carried by tone and haptic
  /// strength (REQ-A11Y-07).
  bool accessibleMode = false;

  /// "Let my breathing become an echo" (on by default; §2.7).
  bool echoConsent = true;

  /// My input: breathing in (holding / toggled on).
  bool inhaling = false;
  bool habitLogged = false;

  /// The latest pulse or gesture that reached this phone (live region).
  RippleNotice? notice;

  /// Bumps every frame: painters repaint on it without rebuilding widgets.
  final ValueNotifier<int> frame = ValueNotifier(0);

  final Set<int> muted = {};
  final Set<int> blocked = {};

  // ---- internals ---------------------------------------------------------------
  final ServerClock _clock = ServerClock();
  RippleTimeline? _timeline;
  GroupSync? _sync;
  EchoTrace? _trace;
  RippleChannel? _channel;
  int _channelGen = 0;
  String? _ticketId;
  Timer? _poll;
  Timer? _retry;
  int _retryAttempt = 0;
  int _pollFailures = 0;
  int _elapsedMs = 0;
  int? _serverAtZero;
  int? _lostAtMs;
  int _myPhaseAtMs = 0;
  bool _myEver = false;
  int _lastSentMs = -1 << 40;
  int _lastStep = -1;
  int _synthNext = 0;
  bool _finishing = false;
  bool _disposed = false;
  bool _habitTried = false;
  final Map<int, _Other> _others = {};
  late final EventBudget _sendBudget = EventBudget(10);
  late MinInterval _pulseOut = MinInterval(3000);
  late MinInterval _gestureOut = MinInterval(5000);

  /// Calm 4/6 from the moment the lobby opens (the same F15 engine).
  static const BreathPacer lobbyPacer = BreathPacer();

  int get elapsedMs => _elapsedMs;
  RippleTimeline? get timeline => _timeline;

  /// Server-clock now (ms), once matched.
  int get serverNowMs => (_serverAtZero ?? 0) + _elapsedMs;

  RippleStage get stage =>
      _timeline?.stageAt(serverNowMs) ?? RippleStage.settle;

  /// The pacer now (the lobby's own until the session starts).
  BreathMoment get moment {
    final t = _timeline;
    if (t == null || phase == RipplePhase.lobby) {
      return lobbyPacer.at(Duration(milliseconds: _elapsedMs));
    }
    return t.momentAt(serverNowMs);
  }

  /// On-device group sync (never shown as a number, never sent).
  double get sync => _sync?.value ?? 0;

  int get cyclesDone => _timeline?.cyclesAt(serverNowMs) ?? 0;

  // ---- lobby -------------------------------------------------------------------
  Future<void> start() async {
    if (api == null || !isOnline()) {
      _unavailable(RipplesUnavailable.offline);
      return;
    }
    unawaited(_loadConsent());
    _ticketId = newTicketId();
    await _pollOnce();
  }

  Future<void> _loadConsent() async {
    try {
      final on = await api!.echoConsent();
      if (_disposed) return;
      echoConsent = on;
      notifyListeners();
    } on Object {
      // Stays on (the default); the server decides anyway.
    }
  }

  Future<void> setEchoConsent(bool on) async {
    echoConsent = on;
    notifyListeners();
    try {
      final got = await api?.setEchoConsent(on);
      if (got != null && !_disposed) {
        echoConsent = got;
        notifyListeners();
      }
    } on Object catch (e) {
      debugPrint('ripples: echo consent not saved (${e.runtimeType})');
    }
  }

  Future<void> _pollOnce() async {
    final a = api;
    final ticket = _ticketId;
    if (a == null ||
        ticket == null ||
        _disposed ||
        phase != RipplePhase.lobby) {
      return;
    }
    final sent = wallMs();
    try {
      final r = await a.match(ticket, entry, roomId: roomId);
      if (_disposed || phase != RipplePhase.lobby) return;
      _clock.sample(
        sentMs: sent,
        receivedMs: wallMs(),
        serverMs: r.serverTimeMs,
      );
      _pollFailures = 0;
      switch (r) {
        case MatchMatched(:final session):
          _begin(session);
        case MatchWaiting(:final pollAfterMs, invite: final inv):
          invite = inv;
          notifyListeners();
          _poll = Timer(
            Duration(milliseconds: pollAfterMs.clamp(250, 5000)),
            () => unawaited(_pollOnce()),
          );
      }
    } on Object catch (e) {
      if (_disposed) return;
      final kind = unavailableFor(e);
      if (kind != null && kind != RipplesUnavailable.offline) {
        _unavailable(kind);
        return;
      }
      if (e is ApiException && e.status == 404) _ticketId = newTicketId();
      // Network hiccups: keep the lobby calm and try again; give up gently.
      if (++_pollFailures >= 4 || !isOnline()) {
        _unavailable(RipplesUnavailable.offline);
        return;
      }
      _poll = Timer(const Duration(seconds: 2), () => unawaited(_pollOnce()));
    }
  }

  void _unavailable(RipplesUnavailable why) {
    _poll?.cancel();
    unavailable = why;
    phase = RipplePhase.unavailable;
    notifyListeners();
  }

  /// "Leave anytime" from the lobby.
  Future<void> cancelLobby() async {
    _poll?.cancel();
    final t = _ticketId;
    _ticketId = null;
    if (t != null && phase == RipplePhase.lobby) {
      try {
        await api?.cancel(t);
      } on Object {
        // The ticket goes quiet on its own after 6 s.
      }
    }
  }

  // ---- session -----------------------------------------------------------------
  void _begin(RippleSession s) {
    _poll?.cancel();
    session = s;
    _timeline = RippleTimeline(s);
    _sync = GroupSync(_timeline!);
    _trace = EchoTrace(_timeline!);
    _pulseOut = MinInterval(s.limits.pulseMinMs);
    _gestureOut = MinInterval(s.limits.gestureMinMs);
    _serverAtZero = _clock.toServer(wallMs()) - _elapsedMs;
    for (final seat in s.seats) {
      if (seat.seat != s.mySeat && seat.kind == SeatKind.human) {
        _others[seat.seat] = _Other(seat.seat, serverNowMs);
      }
    }
    inhaling = false;
    _lastStep = -1;
    phase = RipplePhase.playing;
    notifyListeners();
    unawaited(_connect());
  }

  Future<void> _connect() async {
    final open = openChannel;
    final s = session;
    if (open == null || s == null || _disposed || alone) {
      if (open == null) _linkDropped();
      return;
    }
    final gen = ++_channelGen;
    final old = _channel;
    _channel = null;
    if (old != null) unawaited(_closeQuietly(old));
    final RippleChannel ch;
    try {
      ch = await open(s.channelTopic);
    } on Object {
      _linkDropped();
      return;
    }
    if (gen != _channelGen || _disposed) {
      unawaited(_closeQuietly(ch));
      return;
    }
    _channel = ch;
    ch.onEvent((event, payload) {
      if (gen == _channelGen && !_disposed) _onEvent(event, payload);
    });
    ch.subscribe((status) {
      if (gen != _channelGen || _disposed) return;
      if (status == RippleLinkStatus.subscribed) {
        _retryAttempt = 0;
        _lostAtMs = null;
        if (linkLost) {
          linkLost = false;
          notifyListeners();
        }
        unawaited(ch.track({'seat': s.mySeat}).catchError((Object _) {}));
        unawaited(_refresh());
      } else {
        _linkDropped();
      }
    });
  }

  /// Silent rejoin within the window; after it, the session ends gently on
  /// this phone (PRD 14 "Error: connection lost"). Never a failure screen.
  void _linkDropped() {
    if (_disposed || phase != RipplePhase.playing || alone) return;
    _lostAtMs ??= serverNowMs;
    if (!linkLost) {
      linkLost = true;
      notifyListeners();
    }
    final window = session?.limits.rejoinWindowMs ?? 10000;
    if (serverNowMs - _lostAtMs! >= window) {
      _goAlone();
      return;
    }
    if (_retry != null) return;
    // Never wait past the window: then the session carries on here, alone.
    final left = window - (serverNowMs - _lostAtMs!);
    final wait = backoff(_retryAttempt++);
    _retry = Timer(
      wait.inMilliseconds > left ? Duration(milliseconds: left) : wait,
      () {
        _retry = null;
        if (_disposed || phase != RipplePhase.playing) return;
        if (serverNowMs - (_lostAtMs ?? serverNowMs) >= window) {
          _goAlone();
        } else {
          unawaited(_connect());
        }
      },
    );
  }

  void _goAlone() {
    alone = true;
    _retry?.cancel();
    _retry = null;
    _channelGen++;
    final ch = _channel;
    _channel = null;
    if (ch != null) unawaited(_closeQuietly(ch));
    notifyListeners();
  }

  /// The server's truth after a (re)join or a `seat_update` hint: kinds and
  /// labels only ever come from here, never from the channel.
  Future<void> _refresh() async {
    final s = session;
    if (s == null || api == null) return;
    try {
      final fresh = await api!.session(s.sessionId);
      if (_disposed || session?.sessionId != fresh.sessionId) return;
      session = fresh;
      notifyListeners();
    } on Object {
      // Keep what we have; the pacer carries on.
    }
  }

  void _onEvent(String event, Map<String, dynamic> p) {
    final s = session;
    if (s == null) return;
    final now = serverNowMs;
    switch (event) {
      case 'seat_update':
        unawaited(_refresh());
        return;
      case 'breath_state' || 'heartbeat' || 'pulse' || 'gesture':
        break;
      default:
        return; // session_start / session_end are hints: this phone keeps its own clock
    }
    final seatNo = p['seat'];
    if (seatNo is! num) return;
    final o = _others[seatNo.toInt()];
    // Only other humans breathe on the channel; echoes and guides never pulse.
    if (o == null || s.seat(o.seat)?.kind != SeatKind.human) return;
    if (!o.budget.allow(now)) {
      if (!o.flooded) {
        o.flooded = true;
        unawaited(api?.flood(s.sessionId, o.seat).catchError((Object _) {}));
      }
      return;
    }
    o.lastHeardMs = now;
    final t = p['t'] is num
        ? (p['t'] as num).toInt().clamp(now - 1500, now)
        : now;
    switch (event) {
      case 'breath_state':
        final inhale = p['phase'] == 'in';
        o.inhaling = inhale;
        o.phaseAtMs = t;
        final tl = _timeline!;
        final k = tl.nearestTransition(t, inhale: inhale);
        final off = t - tl.transitionAt(k);
        if (off.abs() <= 2000) {
          _sync?.record(o.seat, k, t);
          o.offsets.add(off);
          if (o.offsets.length > 8) o.offsets.removeAt(0);
        }
      case 'pulse':
        if (!o.pulses.allow(now) || _hidden(o.seat)) return;
        o.pulseAtMs = now;
        feedback.pulse();
        notice = RippleNotice(o.seat, s.seat(o.seat)?.label);
        notifyListeners();
      case 'gesture':
        final g = RippleGesture.parse(p['type']);
        if (g == null || !o.gestures.allow(now) || _hidden(o.seat)) return;
        o.gesture = g;
        o.gestureAtMs = now;
        feedback.pulse();
        notice = RippleNotice(o.seat, s.seat(o.seat)?.label, gesture: g);
        notifyListeners();
    }
  }

  bool _hidden(int seat) => muted.contains(seat) || blocked.contains(seat);

  // ---- time ----------------------------------------------------------------------
  /// Called every frame with the ticker's elapsed time.
  void advance(Duration elapsed) {
    if (_disposed) return;
    _elapsedMs = elapsed.inMilliseconds;
    if (phase == RipplePhase.lobby || phase == RipplePhase.unavailable) {
      frame.value++;
      return;
    }
    if (phase != RipplePhase.playing) return;
    final tl = _timeline!;
    final now = serverNowMs;
    final st = tl.stageAt(now);
    if (st == RippleStage.breathing) {
      final m = tl.momentAt(now);
      if (m.step != _lastStep) {
        _lastStep = m.step;
        feedback.phase(
          inhale: m.phase == BreathPhase.inhale,
          strength: accessibleMode ? sync : null,
          tone: accessibleMode,
        );
        notifyListeners(); // phase words change
      }
    } else if (st == RippleStage.fade && _lastStep != -2) {
      _lastStep = -2;
      notifyListeners();
    }
    _scoreSync(now);
    _heartbeat(now);
    if (!_habitTried && tl.cyclesAt(now) >= habitCycles) {
      _habitTried = true;
      unawaited(_logHabit());
    }
    if (st == RippleStage.done) {
      unawaited(_finish());
      return;
    }
    // Widgets (labels, tap targets, the visual pulse) rebuild only when what
    // the lights show changes; the painter repaints every frame.
    final sig = [
      for (final v in lights())
        '${v.seat}${v.mode.name}${v.pulseAge != null}${v.gesture?.name}${v.muted}',
    ].join('|');
    if (sig != _lightsSig) {
      _lightsSig = sig;
      notifyListeners();
    }
    frame.value++;
  }

  String _lightsSig = '';

  /// Pacer-following lights (guides, echoes, quiet humans) count at their
  /// own recorded / pacer times; then due transitions are scored.
  void _scoreSync(int now) {
    final tl = _timeline!;
    final s = session!;
    final sync = _sync!;
    while (_synthNext < tl.transitions &&
        tl.transitionAt(_synthNext) + sync.closeAfterMs <= now) {
      final k = _synthNext;
      final at = tl.transitionAt(k);
      for (final seat in s.seats) {
        if (seat.seat == s.mySeat) continue;
        final v = viewOf(seat, now);
        switch (v.mode) {
          case LightMode.guide:
            sync.record(seat.seat, k, at);
          case LightMode.echo || LightMode.quiet:
            final o = _others[seat.seat];
            if (seat.kind == SeatKind.echo && o == null) {
              final tr = seat.trace;
              final step = tr.isEmpty ? 0 : tr[k % tr.length];
              if (step != null) sync.record(seat.seat, k, at + step * 50);
            } else {
              sync.record(seat.seat, k, at + (o?.medianOffset ?? 0));
            }
          case LightMode.live:
            break;
        }
      }
      _synthNext++;
    }
    sync.close(now, [for (final seat in s.seats) seat.seat]);
  }

  void _heartbeat(int now) {
    final s = session!;
    if (alone || linkLost || _channel == null) return;
    if (now - _lastSentMs >= s.limits.heartbeatMs) {
      _send('heartbeat', {'seat': s.mySeat, 't': now});
    }
  }

  Future<void> _logHabit() async {
    final cb = onBreatheHabit;
    if (cb == null) return;
    try {
      await cb();
      if (!_disposed) {
        habitLogged = true;
        notifyListeners();
      }
    } on Object {
      // Never disturbs the session.
    }
  }

  // ---- input -----------------------------------------------------------------------
  /// Hold to breathe in.
  void press() => _setInhaling(true);

  /// Release to breathe out.
  void release() => _setInhaling(false);

  /// Accessible mode: one tap switches between in and out.
  void toggle() => _setInhaling(!inhaling);

  void _setInhaling(bool on) {
    if (phase != RipplePhase.playing && phase != RipplePhase.lobby) return;
    if (inhaling == on && _myEver) return;
    inhaling = on;
    _myEver = true;
    final s = session;
    if (phase == RipplePhase.playing && s != null) {
      final now = serverNowMs;
      _myPhaseAtMs = now;
      final tl = _timeline!;
      if (tl.stageAt(now) == RippleStage.breathing) {
        _trace?.record(now, inhale: on);
        final k = tl.nearestTransition(now, inhale: on);
        if ((now - tl.transitionAt(k)).abs() <= 2000) {
          _sync?.record(s.mySeat, k, now);
        }
      }
      _send('breath_state', {
        'seat': s.mySeat,
        'phase': on ? 'in' : 'out',
        't': now,
      });
    } else {
      _myPhaseAtMs = _elapsedMs;
    }
    notifyListeners();
  }

  /// One-tap haptic pulse to everyone (≤ 1 per 3 s). Returns whether sent.
  bool sendPulse() {
    final s = session;
    if (s == null || phase != RipplePhase.playing) return false;
    if (!_pulseOut.allow(serverNowMs)) return false;
    _send('pulse', {'seat': s.mySeat, 't': serverNowMs});
    return true;
  }

  /// Hug, Deep Breath or You're Not Alone to everyone (≤ 1 per 5 s).
  bool sendGesture(RippleGesture g) {
    final s = session;
    if (s == null || phase != RipplePhase.playing) return false;
    if (!_gestureOut.allow(serverNowMs)) return false;
    _send('gesture', {'seat': s.mySeat, 'type': g.wire, 't': serverNowMs});
    return true;
  }

  void _send(String event, Map<String, dynamic> payload) {
    final ch = _channel;
    if (ch == null || alone) return;
    final now = serverNowMs;
    if (!_sendBudget.allow(now)) return; // the sender throttles first
    _lastSentMs = now;
    unawaited(ch.send(event, payload).catchError((Object _) {}));
  }

  // ---- safety on a light -----------------------------------------------------------------
  void setMuted(int seat, bool on) {
    if (on) {
      muted.add(seat);
    } else {
      muted.remove(seat);
    }
    notifyListeners();
  }

  /// → whether the Safety Center should open.
  Future<bool> report(int seat, int reason, {String? note}) async {
    final s = session;
    final a = api;
    if (s == null || a == null) return false;
    return a.report(s.sessionId, seat, reason, note: note);
  }

  Future<void> block(int seat) async {
    final s = session;
    final a = api;
    if (s == null || a == null) return;
    await a.block(s.sessionId, seat);
    blocked.add(seat);
    notifyListeners();
  }

  // ---- end ----------------------------------------------------------------------------
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    phase = RipplePhase.ended;
    notifyListeners();
    await _wrapUp(leaving: false);
  }

  /// ✕ during a session: silent, no penalty; the light dims into an echo.
  Future<void> leave() async {
    if (phase == RipplePhase.lobby) return cancelLobby();
    if (phase != RipplePhase.playing || _finishing) return;
    _finishing = true;
    await _wrapUp(leaving: true);
  }

  Future<void> _wrapUp({required bool leaving}) async {
    _retry?.cancel();
    _channelGen++;
    final ch = _channel;
    _channel = null;
    final s = session;
    final a = api;
    if (s != null && a != null) {
      final now = serverNowMs;
      final cycles = _timeline?.cyclesAt(now) ?? 0;
      final offsets = echoConsent ? _trace?.upTo(now) : null;
      try {
        if (leaving) await a.leave(s.sessionId);
        await a.complete(s.sessionId, cycles, offsets);
      } on Object catch (e) {
        debugPrint('ripples: wrap-up skipped (${e.runtimeType})');
      }
    }
    if (ch != null) await _closeQuietly(ch);
  }

  // ---- views ----------------------------------------------------------------------------
  /// Every light as drawn now, by seat.
  List<LightView> lights() {
    final s = session;
    if (s == null) {
      return [
        LightView(
          seat: 1,
          kind: SeatKind.human,
          mode: LightMode.live,
          fill: _myFill(_elapsedMs),
          me: true,
        ),
      ];
    }
    return [for (final seat in s.seats) viewOf(seat, serverNowMs)];
  }

  LightView viewOf(RippleSeat seat, int now) {
    final s = session!;
    final tl = _timeline!;
    if (seat.seat == s.mySeat) {
      return LightView(
        seat: seat.seat,
        kind: SeatKind.human,
        mode: LightMode.live,
        fill: _myFill(now),
        me: true,
        label: seat.label,
      );
    }
    final o = _others[seat.seat];
    final LightMode mode;
    if (seat.kind == SeatKind.guide) {
      mode = LightMode.guide;
    } else if (seat.kind == SeatKind.echo) {
      mode = LightMode.echo;
    } else {
      final quietFor = now - (o?.lastHeardMs ?? now);
      mode = quietFor > s.limits.echoAfterMs
          ? LightMode.echo
          : quietFor > s.limits.disconnectAfterMs || alone
          ? LightMode.quiet
          : LightMode.live;
    }
    final double fill;
    if (mode == LightMode.live && o != null && o.phaseAtMs > 0) {
      fill = _fillFor(o.inhaling, now - o.phaseAtMs, s);
    } else if (seat.kind == SeatKind.echo && o == null) {
      final k = math.max(0, tl.transitionsBy(now) - 1);
      final tr = seat.trace;
      final step = tr.isEmpty ? 0 : (tr[k % tr.length] ?? 0);
      fill = tl.pacerFill(now, offsetMs: step * 50);
    } else {
      fill = tl.pacerFill(now, offsetMs: o?.medianOffset ?? 0);
    }
    final pulseAge = o?.pulseAtMs == null ? null : now - o!.pulseAtMs!;
    final showGesture = o?.gestureAtMs != null && now - o!.gestureAtMs! < 4000;
    return LightView(
      seat: seat.seat,
      kind: seat.kind,
      mode: mode,
      fill: fill,
      me: false,
      label: mode == LightMode.live || mode == LightMode.quiet
          ? seat.label
          : null,
      pulseAge: pulseAge != null && pulseAge < 1500 && !_hidden(seat.seat)
          ? pulseAge
          : null,
      gesture: showGesture && !_hidden(seat.seat) ? o.gesture : null,
      muted: _hidden(seat.seat),
    );
  }

  double _myFill(int now) {
    if (!_myEver) return 0;
    final s = session;
    return _fillFor(inhaling, now - _myPhaseAtMs, s);
  }

  static double _fillFor(bool inhale, int sinceMs, RippleSession? s) {
    final inMs = s?.inhaleMs ?? 4000;
    final outMs = s?.exhaleMs ?? 6000;
    double ease(double t) => 0.5 - 0.5 * math.cos(math.pi * t.clamp(0, 1));
    return inhale ? ease(sinceMs / inMs) : 1 - ease(sinceMs / outMs);
  }

  static Future<void> _closeQuietly(RippleChannel c) async {
    try {
      await c.close();
    } on Object {
      // already gone
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _retry?.cancel();
    final ch = _channel;
    _channel = null;
    if (ch != null) unawaited(_closeQuietly(ch));
    frame.dispose();
    super.dispose();
  }
}
