import 'dart:async';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/router/deep_links.dart';
import '../../core/router/router.dart';
import '../capsules/capsule_providers.dart';
import '../capsules/capsules_list_screen.dart';
import '../onboarding/gate_controller.dart';
import 'push_messaging.dart';

/// What a push needs from the capsules feature (F4). The capsules feature
/// owns both answers; tests replace it.
abstract interface class CapsulePushBridge {
  /// Whether this phone should show the server's `capsule_unlocked` push for
  /// [capsuleId]: not when the capsule is opened or deleted here, or when this
  /// phone's own offline notice for it already fired (same capsule → shown
  /// once). When the push comes first, the offline notice is cancelled.
  Future<bool> shouldShow(String capsuleId);

  /// Opens the capsules for a tapped push (the list, where ready ones wait).
  Future<void> open(BuildContext context, String? capsuleId);
}

/// [CapsulePushBridge] over the capsules feature
/// (`CapsuleUnlockScheduler.shouldShowServerPush`, `openCapsuleFromNotice`).
class CapsulesFeatureBridge implements CapsulePushBridge {
  CapsulesFeatureBridge(this._ref);

  final Ref _ref;

  @override
  Future<bool> shouldShow(String capsuleId) =>
      _ref.read(capsuleUnlockSchedulerProvider).shouldShowServerPush(capsuleId);

  @override
  Future<void> open(BuildContext context, String? capsuleId) =>
      openCapsuleFromNotice(context, capsuleId);
}

final capsulePushBridgeProvider = Provider<CapsulePushBridge>(
  CapsulesFeatureBridge.new,
);

/// Opens the right place for a tapped push, respecting the gate (the
/// under-13 lock and onboarding win, as for `aura://` links): the daily
/// reminder → the check-in (above whatever shows); a capsule → the capsules.
class PushRouter {
  PushRouter({
    required this._router,
    required this._gate,
    required this._capsules,
  });

  final GoRouter Function() _router;
  final GateState Function() _gate;
  final CapsulePushBridge Function() _capsules;

  Future<void> open(PushEnvelope push) async {
    final router = _router();
    await _whenRouted(router);
    final gate = _gate();
    if (gate.isBlocked || !gate.onboarded) return;
    switch (push.type) {
      case PushTypes.dailyReminder:
        openDeepLink(router, gate, Routes.checkIn);
      case PushTypes.capsuleUnlocked:
        final context = router.routerDelegate.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          await _capsules().open(context, push.id);
        }
    }
  }

  /// A cold start from a tapped notification: wait for the first screen.
  static Future<void> _whenRouted(GoRouter router) async {
    for (var frame = 0; frame < 30; frame++) {
      if (router.routerDelegate.currentConfiguration.isNotEmpty) return;
      await WidgetsBinding.instance.endOfFrame;
    }
  }
}

/// Shows an in-app notice for a push that arrived while Aura was open;
/// [open] goes where tapping the notification would.
typedef PushNoticePresenter = void Function(
  PushEnvelope push,
  VoidCallback open,
);

/// Creates (or renames, after a language change) the Android channels.
typedef ChannelSetup = Future<void> Function();

/// Push handling while the app runs (F14, contracts/api/v1-notifications.md):
///
/// - **Foreground** — never a system notification for these pushes (FCM on
///   Android doesn't show one; iOS presentation is switched off): a calm
///   in-app notice instead. The reminder only if there's no check-in today
///   on this phone; a capsule once per capsule, only when the capsules
///   feature says this phone hasn't announced it already.
/// - **Tap / launch** from a notification → [PushRouter].
/// - Android notification channels (Reminders, Capsules) exist before the
///   first push, named in the app language.
class PushInbox {
  PushInbox({
    required this._source,
    required this._router,
    required this._capsules,
    required this._checkedInToday,
    required this._present,
    this._channels,
  });

  final PushInboxSource? _source;
  final PushRouter _router;
  final CapsulePushBridge Function() _capsules;
  final Future<bool> Function() _checkedInToday;
  final PushNoticePresenter _present;
  final ChannelSetup? _channels;

  final List<StreamSubscription<PushEnvelope>> _subs = [];
  final Set<String> _announced = {};
  bool _disposed = false;

  /// False when push is off in this build (nothing to listen to).
  bool get isActive => _source != null;

  void start() {
    final s = _source;
    if (s == null) return;
    unawaited(_quietly('presentation', s.quietWhileOpen));
    final channels = _channels;
    if (channels != null) unawaited(_quietly('channels', channels));
    _subs
      ..add(s.foreground.listen((e) => unawaited(onForeground(e))))
      ..add(s.opened.listen((e) => unawaited(_open(e))));
    unawaited(() async {
      try {
        final first = await s.initial();
        if (first != null && !_disposed) await _open(first);
      } catch (e) {
        debugPrint('push: initial ${e.runtimeType}');
      }
    }());
  }

  /// Re-applies the channel names (the app language changed).
  Future<void> refreshChannels() async {
    final channels = _channels;
    if (_source != null && channels != null) {
      await _quietly('channels', channels);
    }
  }

  /// A push while Aura is open.
  @visibleForTesting
  Future<void> onForeground(PushEnvelope push) async {
    if (_disposed) return;
    try {
      switch (push.type) {
        case PushTypes.dailyReminder:
          if (await _checkedInToday()) return;
        case PushTypes.capsuleUnlocked:
          final id = push.id;
          if (id == null || _announced.contains(id)) return;
          if (!await _capsules().shouldShow(id)) return;
          _announced.add(id);
        default:
          return; // a type this build doesn't know: nothing to show
      }
      if (_disposed) return;
      _present(push, () => unawaited(_open(push)));
    } catch (e) {
      debugPrint('push: foreground ${push.type} ${e.runtimeType}');
    }
  }

  Future<void> _open(PushEnvelope push) async {
    if (_disposed) return;
    try {
      await _router.open(push);
    } catch (e) {
      debugPrint('push: open ${push.type} ${e.runtimeType}');
    }
  }

  static Future<void> _quietly(String what, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('push: $what ${e.runtimeType}');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }
}

/// A check-in for the Aura day [day] exists on this phone (not deleted; a
/// backfill always carries an earlier day, so it never counts for today).
Future<bool> checkedInOn(AppDatabase db, String day) async {
  final row =
      await (db.select(db.checkIns)
            ..where((t) => t.localDay.equals(day) & t.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();
  return row != null;
}

/// The in-app notice: a calm floating bar with one action, over whatever
/// screen shows (the app-level ScaffoldMessenger).
void showPushNotice(GoRouter router, PushEnvelope push, VoidCallback open) {
  final context = router.routerDelegate.navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final l = AppLocalizations.of(context);
  final (text, action) = switch (push.type) {
    PushTypes.dailyReminder => (l.notif_reminderBanner, l.notif_reminderAction),
    PushTypes.capsuleUnlocked => (l.notif_capsuleBanner, l.notif_capsuleAction),
    _ => (null, null),
  };
  if (text == null || action == null) return;
  messenger.showSnackBar(
    SnackBar(
      key: ValueKey('push-notice-${push.type}'),
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 8),
      action: SnackBarAction(label: action, onPressed: open),
    ),
  );
}

/// Android channel ids (the server's `channel_id`, contracts/api/v1-
/// notifications.md): reminders and capsules can be muted separately.
abstract final class PushChannels {
  static const String reminders = 'reminders';
  static const String capsules = 'capsules';
}

/// Creates the Reminders and Capsules channels in [localeTag]'s language
/// (Android 8+; nothing elsewhere). No permission prompt.
Future<void> ensureAndroidChannels(String localeTag) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final android = FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android == null) return;
  final l = lookupAppLocalizations(localeFromTag(localeTag));
  await android.createNotificationChannel(
    AndroidNotificationChannel(
      PushChannels.reminders,
      l.notif_channelReminders,
      description: l.notif_channelRemindersDescription,
    ),
  );
  await android.createNotificationChannel(
    AndroidNotificationChannel(
      PushChannels.capsules,
      l.capsules_channelName,
      description: l.capsules_channelDescription,
    ),
  );
}

final pushRouterProvider = Provider<PushRouter>(
  (ref) => PushRouter(
    router: () => ref.read(routerProvider),
    gate: () => ref.read(gateControllerProvider),
    capsules: () => ref.read(capsulePushBridgeProvider),
  ),
);

/// Push handling for the session; kept alive by `AuraApp`.
final pushInboxProvider = Provider<PushInbox>((ref) {
  final messaging = ref.watch(pushMessagingProvider);
  final inbox = PushInbox(
    source: messaging is PushInboxSource ? messaging as PushInboxSource : null,
    router: ref.watch(pushRouterProvider),
    capsules: () => ref.read(capsulePushBridgeProvider),
    checkedInToday: () => checkedInOn(
      ref.read(appDatabaseProvider),
      ref.read(timeContextProvider).today().toIso(),
    ),
    present: (push, open) =>
        showPushNotice(ref.read(routerProvider), push, open),
    channels: () => ensureAndroidChannels(ref.read(localeControllerProvider)),
  )..start();
  ref.listen(
    localeControllerProvider,
    (_, _) => unawaited(inbox.refreshChannels()),
  );
  ref.onDispose(() => unawaited(inbox.dispose()));
  return inbox;
});
