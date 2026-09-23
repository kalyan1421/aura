import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';

/// What the phone knows about the person's age (PRD 13-analytics
/// principles 6 and 7).
enum AgeStatus {
  /// No date of birth yet (Welcome, trust step): events wait in memory.
  unknown,

  /// Under 18 by DOB or a platform age signal: nothing is ever sent.
  minor,

  /// 18 or over, and no signal says otherwise.
  adult,
}

/// The age status from the stored "protections until" day
/// (`KvKeys.minorUntil`: the 18th birthday from the DOB, moved later by an
/// under-18 platform age signal, never earlier) and today's calendar date.
/// No stored day → [AgeStatus.unknown] (the DOB step hasn't happened on this
/// phone for this person).
AgeStatus ageStatusFrom(String? minorUntil, LocalDay today) {
  final until = LocalDay.tryParse(minorUntil);
  if (until == null) return AgeStatus.unknown;
  return today.isBefore(until) ? AgeStatus.minor : AgeStatus.adult;
}

/// The server's answer for the signed-in account (`PUT
/// /v1/analytics/consent`): whether it may be tracked, and as whom. The
/// server decides from the stored DOB, platform age signals, the recorded
/// consent and a pending deletion; it never says which of them turned
/// tracking off (no under-18 flag ever reaches a client, REQ-ROOM-12).
@immutable
class ServerVerdict {
  const ServerVerdict._(this.state, this.distinctId);

  /// Not asked yet for this account: events wait in memory.
  static const ServerVerdict unknown = ServerVerdict._(_Verdict.unknown, null);

  /// Tracking is off for this account.
  static const ServerVerdict off = ServerVerdict._(_Verdict.off, null);

  /// Tracking is on, as [distinctId] (a random analytics id; never the
  /// account id or email).
  const ServerVerdict.on(String this.distinctId) : state = _Verdict.on;

  final _Verdict state;
  final String? distinctId;

  bool get isUnknown => state == _Verdict.unknown;
  bool get isOff => state == _Verdict.off;
  bool get isOn => state == _Verdict.on;

  @override
  bool operator ==(Object other) =>
      other is ServerVerdict &&
      other.state == state &&
      other.distinctId == distinctId;

  @override
  int get hashCode => Object.hash(state, distinctId);

  @override
  String toString() => 'ServerVerdict(${state.name})';
}

enum _Verdict { unknown, off, on }

/// Everything the gate decides from.
@immutable
class AnalyticsGateInputs {
  const AnalyticsGateInputs({
    this.blocked = false,
    this.age = AgeStatus.unknown,
    this.consent = false,
    this.signedIn = false,
    this.verdict = ServerVerdict.unknown,
  });

  /// The under-13 device lock is on.
  final bool blocked;
  final AgeStatus age;

  /// "Help improve Aura" (PRD principle 5).
  final bool consent;

  /// An account is signed in on this phone.
  final bool signedIn;

  /// The server's answer for that account (ignored while signed out).
  final ServerVerdict verdict;

  AnalyticsGateInputs copyWith({
    bool? blocked,
    AgeStatus? age,
    bool? consent,
    bool? signedIn,
    ServerVerdict? verdict,
  }) => AnalyticsGateInputs(
    blocked: blocked ?? this.blocked,
    age: age ?? this.age,
    consent: consent ?? this.consent,
    signedIn: signedIn ?? this.signedIn,
    verdict: verdict ?? this.verdict,
  );

  @override
  bool operator ==(Object other) =>
      other is AnalyticsGateInputs &&
      other.blocked == blocked &&
      other.age == age &&
      other.consent == consent &&
      other.signedIn == signedIn &&
      other.verdict == verdict;

  @override
  int get hashCode => Object.hash(blocked, age, consent, signedIn, verdict);
}

/// What happens to an event now.
enum AnalyticsRoute {
  /// Never sent, and anything waiting is thrown away.
  drop,

  /// Held in memory until the age or the server's answer is known.
  hold,

  /// Sent (anonymously while signed out; as the server's analytics id when
  /// signed in).
  send,
}

/// The gate (pure):
/// - the under-13 lock, no consent, or under 18 → [AnalyticsRoute.drop];
///   the PostHog SDK is never started for them (principle 6);
/// - no DOB yet → [AnalyticsRoute.hold] (principle 7: pre-age-gate events
///   wait in memory; 18+ → flushed, otherwise discarded);
/// - 18+ and signed out → [AnalyticsRoute.send] (anonymous, no person
///   profile);
/// - 18+ and signed in → the server decides: off → drop, not asked yet →
///   hold, on → send as its analytics id.
AnalyticsRoute routeFor(AnalyticsGateInputs s) {
  if (s.blocked || !s.consent) return AnalyticsRoute.drop;
  switch (s.age) {
    case AgeStatus.minor:
      return AnalyticsRoute.drop;
    case AgeStatus.unknown:
      return AnalyticsRoute.hold;
    case AgeStatus.adult:
      if (!s.signedIn) return AnalyticsRoute.send;
      if (s.verdict.isOff) return AnalyticsRoute.drop;
      if (s.verdict.isUnknown) return AnalyticsRoute.hold;
      return AnalyticsRoute.send;
  }
}
