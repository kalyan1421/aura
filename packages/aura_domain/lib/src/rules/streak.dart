import 'package:freezed_annotation/freezed_annotation.dart';

import '../local_day.dart';

part 'streak.freezed.dart';

/// Glow-streak state (RULES.md section 7). Immutable; fold new active days in
/// with [foldStreak].
@freezed
class StreakState with _$StreakState {
  const StreakState({
    this.glowStreak = 0,
    this.longestGlowStreak = 0,
    this.lifetimeGlowDays = 0,
    this.restBank = 1,
    this.earnCounter = 0,
    this.lastActiveDay,
  });

  /// A new user: no streak, 1 welcome rest day.
  static const StreakState initial = StreakState();

  /// Parses the API `Snapshot.streak` shape.
  factory StreakState.fromWire(Map<String, Object?> json) {
    final glow = (json['glowStreak'] as num?)?.toInt() ?? 0;
    return StreakState(
      glowStreak: glow,
      // Older snapshots have no longest: at least the current run.
      longestGlowStreak: (json['longestGlowStreak'] as num?)?.toInt() ?? glow,
      lifetimeGlowDays: (json['lifetimeGlowDays'] as num?)?.toInt() ?? 0,
      restBank: (json['restBank'] as num?)?.toInt() ?? 1,
      earnCounter: (json['earnCounter'] as num?)?.toInt() ?? 0,
      lastActiveDay: LocalDay.tryParse(json['lastActiveDay'] as String?),
    );
  }

  /// Active days in the current run (rest days bridge it but add nothing).
  final int glowStreak;

  /// The longest run so far; never decreases. Shown only in Insights (F3
  /// "Longest streak lives only in Insights").
  final int longestGlowStreak;

  /// Distinct active days ever; never decreases.
  final int lifetimeGlowDays;

  /// Banked rest days, 0–3.
  final int restBank;

  /// Active days towards the next rest day, 0–3 (paused while the bank is 3).
  final int earnCounter;

  final LocalDay? lastActiveDay;

  Map<String, Object?> toWire() => {
    'glowStreak': glowStreak,
    'longestGlowStreak': longestGlowStreak,
    'lifetimeGlowDays': lifetimeGlowDays,
    'restBank': restBank,
    'earnCounter': earnCounter,
    'lastActiveDay': lastActiveDay?.toIso(),
  };
}

/// Maximum banked rest days.
const int maxRestBank = 3;

/// Active days needed to earn one rest day.
const int activeDaysPerRestDay = 4;

/// Folds distinct active Aura [days] (any order, duplicates allowed) into
/// [state]. Days on or before `state.lastActiveDay` are already counted and
/// are ignored.
StreakState foldStreak(StreakState state, Iterable<LocalDay> days) {
  final sorted = days.toSet().toList()..sort();
  var glowStreak = state.glowStreak;
  var longest = state.longestGlowStreak;
  var lifetime = state.lifetimeGlowDays;
  var bank = state.restBank;
  var counter = state.earnCounter;
  var last = state.lastActiveDay;

  for (final day in sorted) {
    if (last != null && !day.isAfter(last)) continue;
    if (last == null) {
      glowStreak = 1;
    } else {
      final gap = day.daysSince(last) - 1;
      if (gap == 0) {
        glowStreak += 1;
      } else if (gap <= bank) {
        bank -= gap;
        glowStreak += 1;
      } else {
        glowStreak = 1; // the run ends; nothing is spent
      }
    }
    lifetime += 1;
    if (bank < maxRestBank) {
      counter += 1;
      if (counter >= activeDaysPerRestDay) {
        bank += 1;
        counter = 0;
      }
    }
    if (glowStreak > longest) longest = glowStreak;
    last = day;
  }

  return StreakState(
    glowStreak: glowStreak,
    longestGlowStreak: longest,
    lifetimeGlowDays: lifetime,
    restBank: bank,
    earnCounter: counter,
    lastActiveDay: last,
  );
}

/// What Home may say about the glow streak on [today] (never guilt).
enum GlowStatus {
  /// No active day yet.
  fresh,

  /// Today already counts.
  activeToday,

  /// Yesterday counted; today is still open.
  continuing,

  /// Idle days so far are covered by the rest bank: "your glow is safe".
  restCovered,

  /// The gap is bigger than the bank; the next active day starts a new run.
  /// Home shows nothing about it (no countdowns, no loss copy).
  carriesOn,
}

GlowStatus glowStatus(StreakState state, LocalDay today) {
  final last = state.lastActiveDay;
  if (last == null) return GlowStatus.fresh;
  final idle = today.daysSince(last) - 1;
  if (idle < 0) return GlowStatus.activeToday;
  if (idle == 0) return GlowStatus.continuing;
  if (idle <= state.restBank) return GlowStatus.restCovered;
  return GlowStatus.carriesOn;
}
