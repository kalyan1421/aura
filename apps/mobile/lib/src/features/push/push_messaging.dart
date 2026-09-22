import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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

/// Payloads are content-free by design (`{type, id?}`, PRD Notifications
/// rule 3). Only a short machine `type` is ever read; anything else is
/// ignored, so nothing personal can reach a log.
String? pushType(Map<String, dynamic> data) {
  final t = data['type'];
  if (t is! String) return null;
  return RegExp(r'^[a-z0-9_.-]{1,40}$').hasMatch(t) ? t : 'unrecognised';
}

class FirebasePushMessaging implements PushMessaging {
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

  static PushPermission _map(AuthorizationStatus s) => switch (s) {
    AuthorizationStatus.authorized => PushPermission.authorized,
    AuthorizationStatus.provisional => PushPermission.provisional,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };
}

/// Messages received while the app is in the background or terminated
/// (Android runs this in its own isolate). Routing comes with F14; for now
/// only the `type` is logged, in debug builds.
@pragma('vm:entry-point')
Future<void> auraPushBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) debugPrint('push: background type=${pushType(message.data)}');
}
