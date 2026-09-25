import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/prefs/comfort_prefs.dart';
import '../../core/providers.dart';
import '../avatar/avatar_assets.dart';
import '../capsules/capsule_providers.dart';
import '../capsules/capsule_repository.dart' show triggerCapsuleOf;
import '../onboarding/gate_controller.dart';
import '../progress/progress_view.dart';
import 'avatar_snapshot.dart';
import 'widget_display.dart';
import 'widget_ingest.dart';
import 'widget_prefs.dart';
import 'widget_store.dart';

/// The platform side of the widget store (overridden in tests).
final widgetHostProvider = Provider<WidgetHost>((ref) => ChannelWidgetHost());

/// Renders the avatar PNG the widget shows (overridden in tests).
final avatarSnapshotterProvider = Provider<AvatarSnapshotter>((ref) {
  return (state) async {
    AvatarAssets? assets;
    try {
      assets = await ref.read(avatarAssetsProvider.future);
    } catch (_) {
      assets = null; // the painter still draws its fallback orb
    }
    return renderAvatarPng(state, assets);
  };
});

final widgetIngestorProvider = Provider<WidgetIngestor>(
  (ref) => WidgetIngestor(
    host: ref.watch(widgetHostProvider),
    checkIns: ref.watch(checkInRepositoryProvider),
  ),
);

/// Keeps the home-screen widget (F11) and the app in step for the session
/// (watched by `AuraApp`):
///
/// * **Import:** at start, on every resume, and when the widget saves while
///   the app runs, widget check-ins are imported into Drift
///   ([WidgetIngestor]) and sync is nudged. Each imported check-in is queued
///   in [followUps] for the mood-trigger capsule step at this app open
///   (PRD 12 "after a widget check-in it waits for the next app open"); no
///   companion response replays (PRD 06d "Widget check-in").
/// * **Publish:** whenever what the widget shows changes (a check-in, the
///   04:00 rollover, the avatar, a setting, the language, sign-out), the
///   display state and avatar PNG are handed to the widget, which redraws
///   (F11 "Refresh after each check-in, at 04:00 and on Nebula change").
class WidgetBridge {
  WidgetBridge(this._ref);

  final Ref _ref;

  /// Widget check-ins imported at this app open, oldest first, waiting for
  /// the capsule step (drained by `WidgetCheckInFollowUp`).
  final ValueNotifier<List<ImportedWidgetCheckIn>> followUps = ValueNotifier(
    const [],
  );

  final List<StreamSubscription<void>> _subs = [];
  AppLifecycleListener? _lifecycle;
  Timer? _debounce;
  bool _disposed = false;
  Future<void>? _publishing;
  bool _publishAgain = false;

  String? _lastDisplay;
  AuraAvatarState? _lastAvatarState;
  Uint8List? _lastAvatar;
  bool _published = false;

  void start() {
    _subs.add(
      _ref.read(widgetHostProvider).pendingChanged.listen((_) {
        unawaited(syncNow());
      }),
    );
    try {
      _lifecycle = AppLifecycleListener(onResume: () => unawaited(syncNow()));
    } catch (_) {
      // No binding (pure unit tests): imports run on demand only.
    }
    void changed(Object? _, Object? _) => schedulePublish();
    _ref
      ..listen(gateControllerProvider, changed)
      ..listen(localeControllerProvider, changed)
      ..listen(comfortControllerProvider, changed)
      ..listen(widgetPrefsProvider, changed)
      ..listen(progressViewProvider, changed)
      ..listen(readyCapsulesProvider, changed)
      ..listen(capsulesProvider, changed);
    unawaited(syncNow());
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _lifecycle?.dispose();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    followUps.dispose();
  }

  bool get _ready {
    final gate = _ref.read(gateControllerProvider);
    return gate.onboarded && !gate.isBlocked;
  }

  /// Imports pending widget check-ins (when set up), then publishes.
  Future<void> syncNow() async {
    if (_disposed) return;
    if (_ready) {
      final owner = await _owner();
      final imported = await _ref
          .read(widgetIngestorProvider)
          .ingest(owner: owner);
      if (_disposed) return;
      if (imported.isNotEmpty) {
        _ref.read(syncControllerProvider).notifyLocalWrite();
        followUps.value = [...followUps.value, ...imported];
      }
    }
    await publishNow();
  }

  void schedulePublish() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(publishNow());
    });
  }

  /// Publishes now (serialised: a change during a publish runs once more).
  Future<void> publishNow() async {
    if (_disposed) return;
    if (_publishing != null) {
      _publishAgain = true;
      return _publishing;
    }
    final run = _publish();
    _publishing = run;
    try {
      await run;
    } finally {
      _publishing = null;
      if (_publishAgain && !_disposed) {
        _publishAgain = false;
        await publishNow();
      }
    }
  }

  Future<void> _publish() async {
    try {
      final input = await _input();
      final tag = _ref.read(localeControllerProvider);
      final l = lookupAppLocalizations(localeFromTag(tag));

      Uint8List? avatar;
      if (input.ready && !input.discreet) {
        final state = _ref.read(progressViewProvider).avatar;
        // Whole degrees: a tiny hue drift doesn't redraw the PNG.
        final rounded = state.copyWith(hue: state.hue.roundToDouble());
        if (rounded != _lastAvatarState || _lastAvatar == null) {
          avatar = await _ref.read(avatarSnapshotterProvider)(rounded);
          _lastAvatarState = rounded;
          _lastAvatar = avatar;
        } else {
          avatar = _lastAvatar;
        }
      }
      final display = encodeWidgetDisplay(
        buildWidgetDisplay(
          WidgetDisplayInput(
            ready: input.ready,
            owner: input.owner,
            today: input.today,
            timezone: input.timezone,
            checkedInToday: input.checkedInToday,
            lastMood: input.lastMood,
            showLastMood: input.showLastMood,
            discreet: input.discreet,
            streakDays: input.streakDays,
            capsuleWaiting: input.capsuleWaiting,
            triggerMoodIds: input.triggerMoodIds,
            awardsToday: input.awardsToday,
            awardsFreshDay: input.awardsFreshDay,
            hasAvatar: avatar != null,
          ),
          l,
          tag,
        ),
      );
      if (_disposed) return;
      final avatarChanged = !identical(avatar, _lastPublishedAvatar);
      if (_published && display == _lastDisplay && !avatarChanged) return;
      await _ref
          .read(widgetHostProvider)
          .publish(display: display, avatarPng: avatar);
      _published = true;
      _lastDisplay = display;
      _lastPublishedAvatar = avatar;
    } catch (e) {
      debugPrint('widget: publish failed (${e.runtimeType})');
    }
  }

  Uint8List? _lastPublishedAvatar;

  Future<WidgetDisplayInput> _input() async {
    final time = _ref.read(timeContextProvider);
    final now = _ref.read(nowProvider).value ?? time.now();
    final today = time.dayOf(now);
    final prefs = _ref.read(widgetPrefsProvider);
    if (!_ready) {
      return WidgetDisplayInput(
        ready: false,
        owner: '',
        today: today,
        timezone: time.timezone,
        discreet: prefs.discreet,
      );
    }
    final owner = await _owner();
    final view = _ref.read(progressViewProvider);
    final events =
        _ref.read(progressEventsProvider).value ?? const <ProgressEvent>[];
    final awards = widgetAwards(events, today, time.timezone);
    final checkedIn = events.any(
      (e) =>
          e.kind == ProgressKind.checkIn && !e.deleted && e.localDay == today,
    );
    final hideStreak = _ref.read(comfortControllerProvider).hideStreak;
    final showStreak =
        !hideStreak && view.glow != GlowStatus.carriesOn && view.loaded;
    return WidgetDisplayInput(
      ready: true,
      owner: owner,
      today: today,
      timezone: time.timezone,
      checkedInToday: checkedIn,
      lastMood: prefs.showLastMood && !prefs.discreet
          ? await _lastMood()
          : null,
      showLastMood: prefs.showLastMood,
      discreet: prefs.discreet,
      streakDays: showStreak ? view.streak.glowStreak : null,
      capsuleWaiting: _ref.read(readyCapsulesProvider).isNotEmpty,
      triggerMoodIds: prefs.discreet ? const {} : await _triggerMoods(now),
      awardsToday: awards.today,
      awardsFreshDay: awards.freshDay,
    );
  }

  /// The owner token for the signed-in person on this phone (made once;
  /// wiped at sign-out with the rest of their KV rows).
  Future<String> _owner() async {
    final kv = _ref.read(kvStoreProvider);
    final existing = await kv.get(WidgetKvKeys.owner);
    if (existing != null && existing.isNotEmpty) return existing;
    final token = _ref.read(idsProvider).v7();
    await kv.set(WidgetKvKeys.owner, token);
    return token;
  }

  Future<Mood?> _lastMood() async {
    final db = _ref.read(appDatabaseProvider);
    final row =
        await (db.select(db.checkIns)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.deviceTs)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : moodById(row.moodId);
  }

  /// Moods a check-in right now would fire a mood-trigger capsule for
  /// (RULES.md §9, same rule as the check-in's own capsule step).
  Future<Set<String>> _triggerMoods(DateTime now) async {
    final List<CapsuleRow> rows;
    try {
      rows = await _ref.read(capsuleRepositoryProvider).allRows();
    } catch (_) {
      return const {};
    }
    final capsules = [
      for (final r in rows)
        if (r.rejected == null) triggerCapsuleOf(r),
    ];
    if (capsules.isEmpty) return const {};
    return {
      for (final m in moodCatalog)
        if (!pickTrigger(
          capsules,
          TriggerCheckIn(
            moodId: m.id,
            quadrant: m.quadrant,
            deviceTs: now,
            live: true,
            crisis: false,
          ),
        ).isNone)
          m.id,
    };
  }
}

final widgetBridgeProvider = Provider<WidgetBridge>((ref) {
  final bridge = WidgetBridge(ref);
  ref.onDispose(bridge.dispose);
  bridge.start();
  return bridge;
});
