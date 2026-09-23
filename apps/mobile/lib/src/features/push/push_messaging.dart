import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// OS notification permission, platform-neutral.
enum PushPermission {
  notDetermined,
  denied,
  authorized,

  /// iOS provisional: delivered quietly to Notification Center.
  provisional;

  bool get allowsPush => this == authorized || this == provisional;
}

/// The slice of FCM that [PushService] uses. Wrapped so the service is
/// unit-testable with a fake, and so message payloads are reduced to their
/// `type` before anything else sees them.
abstract interface class PushMessaging {
  /// `ios` | `android` (the `platform` of `PUT /v1/devices`).
  String get platform;

  /// iOS: FCM needs the APNs token first.
  bool get needsApnsToken;

  /// iOS only: a quiet, prompt-free grant is possible.
  bool get supportsProvisional;

  /// Current OS permission, without prompting.
  Future<PushPermission> permission();

  /// Fires the OS prompt (Android 13+ `POST_NOTIFICATIONS`, iOS alert).
  /// With [provisional] on iOS there is no prompt at all.
  Future<PushPermission> requestPermission({bool provisional = false});

  /// FCM auto-init is off until the user opts in (Info.plist /
  /// AndroidManifest), so no token exists before the soft ask.
  Future<void> setAutoInitEnabled(bool enabled);

  Future<String?> apnsToken();

  Future<String?> token();

  Future<void> deleteToken();

  Stream<String> get onTokenRefresh;

  /// Foreground messages, reduced to their `type`.
  Stream<String?> get onMessageType;

  /// A notification tap that brought the app back from the background.
  Stream<String?> get onOpenedType;
}

/// Push types the app handles (contracts/api/v1-notifications.md).
abstract final class PushTypes {
  static const String dailyReminder = 'daily_reminder';
  static const String capsuleUnlocked = 'capsule_unlocked';
}

/// Payloads are content-free by design (`{type, id?}`, PRD Notifications
/// rule 3). Only a short machine `type` is ever read; anything else is
/// ignored, so nothing personal can reach a log.
String? pushType(Map<String, dynamic> data) {
  final t = data['type'];
  if (t is! String) return null;
  return RegExp(r'^[a-z0-9_.-]{1,40}$').hasMatch(t) ? t : 'unrecognised';
}

final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final RegExp _noticeTag = RegExp(r'^[0-9]{1,10}$');

/// A push as the app may see it: its machine [type], the opaque record [id]
/// (a UUID, e.g. the capsule) and the Android notification [tag] the server
/// set (for a capsule: this phone's local notice id for that date). Nothing
/// else from a payload is ever kept.
@immutable
class PushEnvelope {
  const PushEnvelope({required this.type, this.id, this.tag});

  final String type;
  final String? id;
  final String? tag;

  @override
  bool operator ==(Object other) =>
      other is PushEnvelope &&
      other.type == type &&
      other.id == id &&
      other.tag == tag;

  @override
  int get hashCode => Object.hash(type, id, tag);

  @override
  String toString() => 'PushEnvelope($type)'; // never the id
}

/// Reduces a payload to a [PushEnvelope] (null without a usable `type`).
PushEnvelope? pushEnvelope(Map<String, dynamic> data, {String? tag}) {
  final type = pushType(data);
  if (type == null) return null;
  final id = data['id'];
  return PushEnvelope(
    type: type,
    id: id is String && _uuid.hasMatch(id) ? id.toLowerCase() : null,
    tag: tag != null && _noticeTag.hasMatch(tag) ? tag : null,
  );
}

PushEnvelope? _envelopeOf(RemoteMessage m) =>
    pushEnvelope(m.data, tag: m.notification?.android?.tag);

/// Where the app hears about pushes for routing and in-app banners
/// ([PushInbox]). Separate from [PushMessaging] so the registration fakes
/// stay as they are.
abstract interface class PushInboxSource {
  /// Pushes that arrive while Aura is open (no system notification shows).
  Stream<PushEnvelope> get foreground;

  /// A tapped notification brought Aura back from the background.
  Stream<PushEnvelope> get opened;

  /// The tapped notification that launched Aura, if any (once).
  Future<PushEnvelope?> initial();

  /// iOS: never present a system banner while Aura is open (Android never
  /// does for FCM notifications): the app shows its own in-app notice.
  Future<void> quietWhileOpen();
}

class FirebasePushMessaging implements PushMessaging, PushInboxSource {
  FirebasePushMessaging([FirebaseMessaging? messaging])
    : _m = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _m;

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  String get platform => _ios ? 'ios' : 'android';

  @override
  bool get needsApnsToken => _ios;

  @override
  bool get supportsProvisional => _ios;

  @override
  Future<PushPermission> permission() async =>
      _map((await _m.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission({bool provisional = false}) async =>
      _map(
        (await _m.requestPermission(provisional: provisional))
            .authorizationStatus,
      );

  @override
  Future<void> setAutoInitEnabled(bool enabled) =>
      _m.setAutoInitEnabled(enabled);

  @override
  Future<String?> apnsToken() => _m.getAPNSToken();

  @override
  Future<String?> token() => _m.getToken();

  @override
  Future<void> deleteToken() => _m.deleteToken();

  @override
  Stream<String> get onTokenRefresh => _m.onTokenRefresh;

  @override
  Stream<String?> get onMessageType =>
      FirebaseMessaging.onMessage.map((m) => pushType(m.data));

  @override
  Stream<String?> get onOpenedType =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => pushType(m.data));

  @override
  Stream<PushEnvelope> get foreground => FirebaseMessaging.onMessage
      .map(_envelopeOf)
      .where((e) => e != null)
      .cast<PushEnvelope>();

  @override
  Stream<PushEnvelope> get opened => FirebaseMessaging.onMessageOpenedApp
      .map(_envelopeOf)
      .where((e) => e != null)
      .cast<PushEnvelope>();

  @override
  Future<PushEnvelope?> initial() async {
    final m = await _m.getInitialMessage();
    return m == null ? null : _envelopeOf(m);
  }

  @override
  Future<void> quietWhileOpen() =>
      _m.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

  static PushPermission _map(AuthorizationStatus s) => switch (s) {
    AuthorizationStatus.authorized => PushPermission.authorized,
    AuthorizationStatus.provisional => PushPermission.provisional,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };
}

/// The capsule notice id a `capsule_unlocked` push stands for: its Android
/// `tag` is this phone's local "ready to open" notice id for the unlock date
/// (contracts/api/v1-notifications.md §2).
int? capsuleNoticeIdOf(PushEnvelope e) =>
    e.type == PushTypes.capsuleUnlocked ? int.tryParse(e.tag ?? '') : null;

/// Cancels one local notification (the capsules feature's offline notice).
typedef LocalNoticeCancel = Future<void> Function(int id);

Future<void> _cancelLocalNotice(int id) =>
    FlutterLocalNotificationsPlugin().cancel(id: id);

/// Android: the OS already shows the server's capsule push, so this phone's
/// own offline notice for the same date (pending or shown) would be a
/// duplicate — cancel it; the person sees the capsule once. (iOS replaces
/// the notice by its identifier: the push's collapse id is the same.)
@visibleForTesting
Future<bool> dropDuplicateCapsuleNotice(
  PushEnvelope e, {
  LocalNoticeCancel cancel = _cancelLocalNotice,
}) async {
  final id = capsuleNoticeIdOf(e);
  if (id == null) return false;
  try {
    await cancel(id);
    return true;
  } catch (e) {
    debugPrint('push: notice cleanup ${e.runtimeType}');
    return false;
  }
}

/// Messages received while the app is in the background or terminated
/// (Android runs this in its own isolate for every message; iOS only for
/// silent ones). The OS shows the notification itself; here only the
/// duplicate local capsule notice goes. Only the `type` is logged, in debug.
@pragma('vm:entry-point')
Future<void> auraPushBackgroundHandler(RemoteMessage message) async {
  final e = _envelopeOf(message);
  if (kDebugMode) debugPrint('push: background type=${e?.type}');
  if (e == null || defaultTargetPlatform != TargetPlatform.android) return;
  await dropDuplicateCapsuleNotice(e);
}
