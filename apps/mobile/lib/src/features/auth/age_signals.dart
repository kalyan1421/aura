import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/db/kv_store.dart';
import '../onboarding/age_gate.dart';

/// Platform age signals (F8 REQ-ACC-04): Apple Declared Age Range (iOS 26+)
/// and Google Play Age Signals, read before any auth call.
///
/// They only ever *add* protection:
/// - the whole range under 13 → the existing under-13 block, whatever the
///   DOB (nothing identifying is kept or sent);
/// - the whole range under 18 → the invisible under-18 protections (the
///   `minorUntil` key), even with an adult DOB;
/// - no signal (unavailable, declined, not shared, too slow) → DOB alone.
///
/// No signal value ever hides a feature from a 13+ person, and no signal is
/// shown, logged or sent anywhere.

/// An age *range* (never an exact age). Both bounds inclusive; `upper` is
/// `null` for the top band (e.g. 18+). [none] = no signal.
@immutable
class AgeSignal {
  const AgeSignal({this.lower, this.upper});

  static const AgeSignal none = AgeSignal();

  final int? lower;
  final int? upper;

  bool get isNone => lower == null && upper == null;

  /// Everyone in the range is under 13.
  bool get under13 => upper != null && upper! < AgeGate.minimumAge;

  /// Everyone in the range is under 18.
  bool get under18 => upper != null && upper! < 18;

  @override
  bool operator ==(Object other) =>
      other is AgeSignal && other.lower == lower && other.upper == upper;

  @override
  int get hashCode => Object.hash(lower, upper);

  @override
  String toString() => 'AgeSignal(<redacted>)';
}

enum AgeSignalOutcome {
  /// DOB alone decides.
  none,

  /// Under 13: the device lock is on; no auth call may follow.
  blocked,

  /// Under 18: invisible protections only.
  minor,
}

/// Reads the platform signal. Never throws: [AgeSignal.none] when there is
/// nothing to read.
abstract interface class AgeSignalSource {
  Future<AgeSignal> read();
}

/// `com.akvega.aura/age_signals` → `read` (AppDelegate.swift,
/// MainActivity.kt). The native side answers
/// `{status: shared|declined|unavailable, lower?, upper?}`:
/// - iOS 26.2+: `AgeRangeService` only where `isEligibleForAgeFeatures`
///   (regions whose law requires age assurance, e.g. Texas). Elsewhere
///   nobody is shown Apple's share sheet, and there is no signal.
/// - Android: Play Age Signals (beta; Brazil, Texas, …). Never shows UI.
class ChannelAgeSignalSource implements AgeSignalSource {
  const ChannelAgeSignalSource();

  static const MethodChannel _channel = MethodChannel(
    'com.akvega.aura/age_signals',
  );

  @override
  Future<AgeSignal> read() async {
    // The channel exists only in the iOS / Android runners.
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) {
      return AgeSignal.none;
    }
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('read');
      if (r == null || r['status'] != 'shared') return AgeSignal.none;
      return AgeSignal(lower: _int(r['lower']), upper: _int(r['upper']));
    } on Object catch (e) {
      debugPrint('age signals: ${e.runtimeType}');
      return AgeSignal.none;
    }
  }

  static int? _int(Object? v) => v is num ? v.toInt() : null;
}

/// The REQ-ACC-04 rule. A DOB that already says under-18 needs nothing from
/// the signal; the signal can only extend protection, never shorten it.
AgeSignalOutcome evaluateAgeSignal(AgeSignal signal) {
  if (signal.under13) return AgeSignalOutcome.blocked;
  if (signal.under18) return AgeSignalOutcome.minor;
  return AgeSignalOutcome.none;
}

/// The last day the under-18 protections could still apply to someone in
/// [signal]'s range, counted from [today]: the youngest possible age
/// (`lower`, at least 13) turning 18.
LocalDay minorUntilFor(AgeSignal signal, LocalDay today) {
  final youngest = max(signal.lower ?? AgeGate.minimumAge, AgeGate.minimumAge);
  final years = max(18 - youngest, 0);
  return LocalDay.fromDateTime(
    DateTime.utc(today.year + years, today.month, today.day),
  );
}

/// Applies an [AgeSignal]: the under-13 block (GateController.blockUnder13)
/// or a later `minorUntil` (the key the help sheet already reads; never
/// moved earlier than the DOB put it).
class AgeSignalPolicy {
  AgeSignalPolicy({
    required this._kv,
    required this._blockUnder13,
    required this._today,
  });

  final KvStore _kv;
  final Future<void> Function() _blockUnder13;
  final LocalDay Function() _today;

  Future<AgeSignalOutcome> apply(AgeSignal signal) async {
    final outcome = evaluateAgeSignal(signal);
    switch (outcome) {
      case AgeSignalOutcome.blocked:
        await _blockUnder13();
      case AgeSignalOutcome.minor:
        // TODO(server): the server's `is_minor` comes from the DOB only; send
        // the range with POST /v1/profile so server-side protections
        // (moderation, analytics exclusion) apply too (contract change).
        final until = minorUntilFor(signal, _today());
        final current = LocalDay.tryParse(await _kv.get(KvKeys.minorUntil));
        if (current == null || current.isBefore(until)) {
          await _kv.set(KvKeys.minorUntil, until.toIso());
        }
      case AgeSignalOutcome.none:
        break;
    }
    return outcome;
  }
}

/// One screen's check: starts reading at once, applies the result whenever
/// it arrives (a late under-13 still blocks), and lets an auth action wait
/// for it at most [maxWait] (REQ-ACC-04: "no signal → waits ≤ 1 s").
class AgeSignalCheck {
  AgeSignalCheck({
    required this._read,
    required this._apply,
    this.maxWait = const Duration(seconds: 1),
  });

  final Future<AgeSignal> Function() _read;
  final Future<AgeSignalOutcome> Function(AgeSignal) _apply;
  final Duration maxWait;

  Future<AgeSignalOutcome>? _outcome;

  /// Idempotent.
  void start() => _outcome ??= _run();

  Future<AgeSignalOutcome> _run() async {
    AgeSignal signal;
    try {
      signal = await _read();
    } on Object {
      signal = AgeSignal.none;
    }
    try {
      return await _apply(signal);
    } on Object catch (e) {
      debugPrint('age signals: apply ${e.runtimeType}');
      return AgeSignalOutcome.none;
    }
  }

  /// The outcome, or [AgeSignalOutcome.none] if it takes longer than
  /// [maxWait] (the check keeps running and still applies later).
  Future<AgeSignalOutcome> outcome() async {
    start();
    try {
      return await _outcome!.timeout(maxWait);
    } on TimeoutException {
      return AgeSignalOutcome.none;
    }
  }
}
