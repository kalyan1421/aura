import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/kv_store.dart';
import '../../core/providers.dart';
import 'age_gate.dart';

part 'gate_controller.g.dart';

/// Onboarding order (F8): welcome → trust (privacy & boundaries) → DOB →
/// (under 13: block) → language → sign in → first check-in. DOB comes before
/// sign-in so Aura never receives an under-13's email.
///
/// Stage names are persisted ([KvKeys.onboardingStage]): never rename a
/// value. Installs saved before the trust step (welcome, dob, language,
/// signIn, firstCheckIn, done) resume at the same step; see [loadGateState].
enum OnboardingStage {
  welcome,
  trust,
  dob,
  language,
  signIn,
  firstCheckIn,
  done;

  /// The step an onboarding back button returns to, or `null` where there is
  /// no way back: Welcome is the start, and from the first check-in on the
  /// account already exists.
  OnboardingStage? get previous => switch (this) {
    welcome => null,
    trust => welcome,
    dob => trust,
    language => dob,
    signIn => language,
    firstCheckIn || done => null,
  };
}

@immutable
class GateState {
  const GateState({required this.stage, this.blockedUntil});

  final OnboardingStage stage;

  /// Set while the under-13 device lock is active.
  final DateTime? blockedUntil;

  bool get isBlocked => blockedUntil != null;
  bool get onboarded => stage == OnboardingStage.done;

  @override
  bool operator ==(Object other) =>
      other is GateState &&
      other.stage == stage &&
      other.blockedUntil == blockedUntil;

  @override
  int get hashCode => Object.hash(stage, blockedUntil);
}

/// Loaded before the first frame (main.dart) so a blocked device never sees
/// the DOB screen flash.
@Riverpod(keepAlive: true)
GateState initialGate(Ref ref) =>
    const GateState(stage: OnboardingStage.welcome);

/// Reads the persisted gate state. A stage saved by any earlier build
/// resumes exactly there (a mid-onboarding install at `dob` stays at DOB and
/// is not sent back through trust); a missing or unknown name starts again
/// at Welcome. The under-13 lock is read independently and wins over the
/// stage in [gateRedirect].
Future<GateState> loadGateState(KvStore kv, AgeGate age) async {
  final until = await age.blockedUntil();
  final raw = await kv.get(KvKeys.onboardingStage);
  final stage =
      OnboardingStage.values.asNameMap()[raw] ?? OnboardingStage.welcome;
  return GateState(stage: stage, blockedUntil: until);
}

enum BirthDateResult { ok, blocked }

@Riverpod(keepAlive: true)
class GateController extends _$GateController {
  @override
  GateState build() => ref.read(initialGateProvider);

  AgeGate get _age => AgeGate(
    ref.read(secureStoreProvider),
    ref.read(timeContextProvider).clock,
    ref.read(deviceLockMirrorProvider),
  );

  Future<void> goTo(OnboardingStage stage) async {
    await ref.read(kvStoreProvider).set(KvKeys.onboardingStage, stage.name);
    state = GateState(stage: stage, blockedUntil: state.blockedUntil);
  }

  /// Onboarding back button: returns to [OnboardingStage.previous] and
  /// persists it. No-op at Welcome, after sign-in and while the device lock
  /// is active (the block screen has no way back).
  Future<void> back() async {
    final previous = state.stage.previous;
    if (previous == null || state.isBlocked) return;
    await goTo(previous);
  }

  /// Validates age on device. Under 13 → the device lock; nothing about the
  /// child (not even the DOB) is kept or sent.
  Future<BirthDateResult> submitBirthDate(LocalDay birthDate) async {
    final now = ref.read(timeContextProvider).now();
    final today = LocalDay(
      now.toLocal().year,
      now.toLocal().month,
      now.toLocal().day,
    );
    if (AgeGate.isUnder13(birthDate, today)) {
      await blockUnder13();
      return BirthDateResult.blocked;
    }
    await ref.read(profileServiceProvider).queue(birthDate: birthDate);
    await goTo(OnboardingStage.language);
    return BirthDateResult.ok;
  }

  Future<void> blockUnder13() async {
    final until = await _age.block();
    final kv = ref.read(kvStoreProvider);
    await kv.set(KvKeys.birthDate, null);
    await kv.set(KvKeys.pendingProfile, null);
    await kv.set(KvKeys.minorUntil, null);
    await kv.set(KvKeys.onboardingStage, OnboardingStage.welcome.name);
    state = GateState(stage: OnboardingStage.welcome, blockedUntil: until);
  }

  /// Re-checks the lock (e.g. on resume) so it lifts after 30 days.
  Future<void> refreshLock() async {
    final until = await _age.blockedUntil();
    if (until != state.blockedUntil) {
      state = GateState(stage: state.stage, blockedUntil: until);
    }
  }
}
