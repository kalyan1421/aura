import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/kv_store.dart';
import '../../core/net/api_models.dart';
import '../../core/providers.dart';

part 'progress_view.g.dart';

/// What Home shows: the avatar, Starlight and glow streak.
@immutable
class ProgressView {
  const ProgressView({
    required this.loaded,
    required this.today,
    required this.avatar,
    required this.todayStarlight,
    required this.totalStarlight,
    required this.streak,
    required this.glow,
    required this.provisional,
    required this.hasActivity,
    required this.awards,
    required this.localHue,
  });

  final bool loaded;
  final LocalDay today;
  final AuraAvatarState avatar;
  final int todayStarlight;
  final int totalStarlight;
  final StreakState streak;
  final GlowStatus glow;

  /// True while local writes are not yet confirmed by the server.
  final bool provisional;
  final bool hasActivity;

  /// Provisional Starlight per local event id (for the "+10" moment).
  final Map<String, int> awards;
  final double? localHue;

  /// How far all-time Starlight is toward the next stage; `null` at
  /// Constellation, which grows stars instead (F2).
  StageProgress? get stageProgress =>
      stageProgressFor(avatar.stage, totalStarlight);
}

/// Progress from the shown [stage] toward the next one (Home's quiet bar).
@immutable
class StageProgress {
  const StageProgress({
    required this.next,
    required this.total,
    required this.fraction,
  });

  final AuraStage next;

  /// All-time Starlight so far; `next.threshold` is the target.
  final int total;

  /// 0–1 across the current stage's span.
  final double fraction;
}

/// The next stage after [stage] and the share of the way there for an
/// all-time [total]; `null` at the last stage. Thresholds come from
/// [AuraStage] (RULES.md §4). The shown stage can be ahead of [total] (the
/// server's stage never regresses on screen), so the share is clamped.
StageProgress? stageProgressFor(AuraStage stage, int total) {
  final next = stage.next;
  if (next == null) return null;
  final span = next.threshold - stage.threshold;
  final into = total - stage.threshold;
  return StageProgress(
    next: next,
    total: total,
    fraction: span <= 0 ? 1 : (into / span).clamp(0.0, 1.0),
  );
}

/// Combines the on-device projection with the last server snapshot.
///
/// - Pending local writes → the local projection (optimistic), never below
///   the server's stage/total (stages never regress on screen).
/// - Nothing pending and a snapshot exists → the server snapshot (DS-5), with
///   resting/today re-evaluated for the current Aura day.
ProgressView computeProgressView({
  required List<ProgressEvent> events,
  required bool loaded,
  required Snapshot? snapshot,
  required int pending,
  required DateTime now,
  required String timezone,
  required double? lastHue,
}) {
  final local = projectProgress(
    events: events,
    now: now,
    timezone: timezone,
    previousHue: lastHue,
  );
  final today = local.today;

  if (snapshot == null) {
    return ProgressView(
      loaded: loaded,
      today: today,
      avatar: local.avatar,
      todayStarlight: local.todayStarlight,
      totalStarlight: local.totalStarlight,
      streak: local.streak,
      glow: glowStatus(local.streak, today),
      provisional: pending > 0,
      hasActivity: events.isNotEmpty,
      awards: local.awards,
      localHue: local.hue,
    );
  }

  final server = snapshot.avatarState(fallbackHue: local.hue ?? lastHue);
  final serverStreak = snapshot.streakState;
  final snapshotIsToday = snapshot.auraDay == today.toIso();
  // The longest run never decreases on screen, whichever side knows more.
  final longest = math.max(
    local.streak.longestGlowStreak,
    serverStreak.longestGlowStreak,
  );

  if (pending > 0) {
    final total = math.max(local.totalStarlight, snapshot.starlight.total);
    final stage = stageFor(total).atLeast(server.stage);
    return ProgressView(
      loaded: loaded,
      today: today,
      avatar: local.avatar.copyWith(
        stage: stage,
        ringCount: math.max(local.avatar.ringCount, server.ringCount),
        glowLevel: math.max(local.avatar.glowLevel, server.glowLevel),
        constellationStars: constellationStarsFor(total),
        equippedCosmetics: server.equippedCosmetics,
      ),
      todayStarlight: local.todayStarlight,
      totalStarlight: total,
      streak:
          (local.streak.lifetimeGlowDays >= serverStreak.lifetimeGlowDays
                  ? local.streak
                  : serverStreak)
              .copyWith(longestGlowStreak: longest),
      glow: glowStatus(local.streak, today),
      provisional: true,
      hasActivity: true,
      awards: local.awards,
      localHue: local.hue,
    );
  }

  return ProgressView(
    loaded: loaded,
    today: today,
    avatar: server.copyWith(
      stage: server.stage.atLeast(stageFor(local.totalStarlight)),
      isResting: isResting(serverStreak.lastActiveDay, today),
    ),
    todayStarlight: snapshotIsToday
        ? snapshot.starlight.today
        : local.todayStarlight,
    totalStarlight: snapshot.starlight.total,
    streak: serverStreak.copyWith(longestGlowStreak: longest),
    glow: glowStatus(serverStreak, today),
    provisional: false,
    hasActivity: events.isNotEmpty || serverStreak.lifetimeGlowDays > 0,
    awards: local.awards,
    localHue: local.hue,
  );
}

@Riverpod(keepAlive: true)
Stream<List<ProgressEvent>> progressEvents(Ref ref) =>
    ref.watch(progressRepositoryProvider).watchEvents();

@Riverpod(keepAlive: true)
Stream<Snapshot?> snapshot(Ref ref) =>
    ref.watch(progressRepositoryProvider).watchSnapshot();

@Riverpod(keepAlive: true)
Stream<double?> lastHue(Ref ref) => ref
    .watch(kvStoreProvider)
    .watch(KvKeys.lastHue)
    .map((v) => v == null ? null : double.tryParse(v));

@Riverpod(keepAlive: true)
ProgressView progressView(Ref ref) {
  final events = ref.watch(progressEventsProvider);
  final time = ref.watch(timeContextProvider);
  final view = computeProgressView(
    events: events.value ?? const [],
    loaded: events.hasValue,
    snapshot: ref.watch(snapshotProvider).value,
    pending: ref.watch(pendingCountProvider).value ?? 0,
    now: ref.watch(nowProvider).value ?? time.now(),
    timezone: time.timezone,
    lastHue: ref.watch(lastHueProvider).value,
  );
  // Remember the mood-mix hue so it holds when the 14-day window empties.
  final hue = view.localHue;
  if (hue != null) {
    final last = ref.read(lastHueProvider).value;
    if (last == null || (last - hue).abs() > 0.5) {
      Future.microtask(
        () => ref.read(progressRepositoryProvider).saveLastHue(hue),
      );
    }
  }
  return view;
}
