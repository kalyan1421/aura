import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'analytics_event.dart';
import 'analytics_gate.dart';
import 'analytics_privacy.dart';

/// Product analytics for the app (PRD 13-analytics). Feature code calls
/// [track] with a typed [AnalyticsEvent] — one line, fire-and-forget; it
/// never throws and never waits. Everything else (consent, age, the
/// server's answer, the SDK) is decided here.
abstract interface class AnalyticsService {
  /// False when this build has no analytics key: [track] then does nothing.
  bool get isEnabled;

  /// Records [event] if the gate allows it now, holds it while the age or
  /// the server's answer is unknown, or drops it.
  void track(AnalyticsEvent event);

  /// What the gate decides from changed (consent, age, sign-in, the
  /// server's answer, the under-13 lock).
  void update(AnalyticsGateInputs inputs);

  /// Sends what is queued (app going to the background).
  Future<void> flush();
}

/// No analytics key in this build (local dev, tests, CI): nothing is held,
/// started or sent.
class NoopAnalytics implements AnalyticsService {
  const NoopAnalytics();

  @override
  bool get isEnabled => false;

  @override
  void track(AnalyticsEvent event) {}

  @override
  void update(AnalyticsGateInputs inputs) {}

  @override
  Future<void> flush() async {}
}

/// The analytics SDK behind [GatedAnalytics] (PostHog in the app, a fake in
/// tests). Called one at a time, in order.
abstract interface class AnalyticsSink {
  /// Starts the SDK. Called at most once, and only when the first event may
  /// really be sent (never for someone under 18).
  Future<void> start();
  Future<void> capture(String name, Map<String, Object> properties);

  /// Links this install's anonymous events to [distinctId] (the server's
  /// random analytics id).
  Future<void> identify(String distinctId);
  Future<void> optIn();
  Future<void> optOut();

  /// Forgets the analytics identity (a new anonymous id next time).
  Future<void> reset();
  Future<void> flush();
}

/// The gated service: every event goes through the privacy filter, then
/// [routeFor] decides — drop, hold in memory, or send. See
/// analytics_gate.dart for the rules and docs/setup/analytics.md.
///
/// SDK calls run one at a time, in order, each decided with the inputs of
/// the moment it was requested: an event recorded before a sign-out still
/// goes out as that account, and a withdrawal stops everything after it.
class GatedAnalytics implements AnalyticsService {
  GatedAnalytics({
    required AnalyticsSink sink,
    required Map<String, Object?> Function() globals,
    this.maxHeld = 100,
  }) : _sink = sink,
       _globals = globals;

  final AnalyticsSink _sink;
  final Map<String, Object?> Function() _globals;

  /// Events held before the age or the server's answer is known; the oldest
  /// go first beyond this.
  final int maxHeld;

  AnalyticsGateInputs _inputs = const AnalyticsGateInputs();
  final Queue<CleanEvent> _held = Queue();
  bool _started = false;
  bool _optedOut = false;
  String? _identified;
  Future<void> _chain = Future<void>.value();

  /// The current inputs (tests).
  @visibleForTesting
  AnalyticsGateInputs get inputs => _inputs;

  /// How many events wait in memory (tests).
  @visibleForTesting
  int get heldCount => _held.length;

  /// Resolves when every queued SDK call has run (tests).
  @visibleForTesting
  Future<void> settled() => _chain;

  @override
  bool get isEnabled => true;

  @override
  void track(AnalyticsEvent event) {
    final clean = sanitizeEvent(
      event.name,
      event.properties,
      onDropped: kDebugMode
          ? (key) => debugPrint('analytics: ${event.name} dropped "$key"')
          : null,
    );
    if (clean == null) return;
    switch (routeFor(_inputs)) {
      case AnalyticsRoute.drop:
        return;
      case AnalyticsRoute.hold:
        _held.addLast(clean);
        while (_held.length > maxHeld) {
          _held.removeFirst();
        }
      case AnalyticsRoute.send:
        _send([clean]);
    }
  }

  @override
  void update(AnalyticsGateInputs inputs) {
    if (inputs == _inputs) return;
    final before = _inputs;
    final wasRoute = routeFor(before);
    _inputs = inputs;
    final route = routeFor(inputs);

    // Signed out: what was queued goes, then the identity is forgotten.
    // Anything held belonged to the account that just left.
    if (before.signedIn && !inputs.signedIn) {
      _held.clear();
      _enqueue(() async {
        if (!_started) return;
        await _sink.flush();
        await _sink.reset();
        _identified = null;
      });
    }

    switch (route) {
      case AnalyticsRoute.drop:
        _held.clear();
        if (wasRoute != AnalyticsRoute.drop) {
          // Consent withdrawn, under 18, the under-13 lock or the server
          // said no: stop at once and forget the identity.
          _enqueue(() async {
            if (!_started || _optedOut) return;
            await _sink.optOut();
            _optedOut = true;
            await _sink.reset();
            _identified = null;
          });
        }
      case AnalyticsRoute.hold:
        break;
      case AnalyticsRoute.send:
        final held = _held.toList();
        _held.clear();
        _send(held);
    }
  }

  /// Sends [events] as the inputs stand now. An empty list only brings the
  /// identity up to date, and never starts the SDK by itself.
  void _send(List<CleanEvent> events) {
    final snapshot = _inputs;
    final globals = _globals();
    final outgoing = [
      for (final e in events) (e.name, outgoingProperties(e, globals)),
    ];
    _enqueue(() async {
      if (outgoing.isEmpty && !_started) return;
      if (!_started) {
        await _sink.start();
        _started = true;
        _optedOut = false;
      } else if (_optedOut) {
        await _sink.optIn();
        _optedOut = false;
      }
      final verdict = snapshot.verdict;
      if (snapshot.signedIn && verdict.isOn) {
        final id = verdict.distinctId!;
        if (_identified != id) {
          // A different analytics id (another account, or a fresh consent):
          // never merge it into the previous one.
          if (_identified != null) await _sink.reset();
          await _sink.identify(id);
          _identified = id;
        }
      }
      for (final (name, props) in outgoing) {
        await _sink.capture(name, props);
      }
    });
  }

  @override
  Future<void> flush() {
    _enqueue(() async {
      if (_started && !_optedOut) await _sink.flush();
    });
    return _chain;
  }

  void _enqueue(Future<void> Function() call) {
    _chain = _chain.then((_) async {
      try {
        await call();
      } on Object catch (e) {
        // Analytics never disturbs the app; errors say nothing about data.
        debugPrint('analytics: sdk ${e.runtimeType}');
      }
    });
  }
}
