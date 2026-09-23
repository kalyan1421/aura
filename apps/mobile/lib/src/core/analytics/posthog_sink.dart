import 'package:posthog_flutter/posthog_flutter.dart';

import 'analytics_privacy.dart';
import 'analytics_service.dart';

/// [AnalyticsSink] over PostHog Cloud (`posthog_flutter`, PRD Q14), set up
/// from Dart only when the first event may really be sent. Native auto-init
/// is off (`com.posthog.posthog.AUTO_INIT` = false in Info.plist and the
/// Android manifest), so nothing starts before that.
///
/// Everything automatic is off (PRD 13-analytics principle 1, 8):
/// - no lifecycle autocapture, rage clicks, session replay, surveys, logs,
///   error tracking or feature-flag calls;
/// - no push-token registration and no `$push_notification_opened`;
/// - person profiles only after `identify` (18+, consenting, signed in);
/// - `$geoip_disable` on every event, and the project setting "Discard
///   client IP data" (docs/setup/analytics.md) — no IP-derived location.
/// A `beforeSend` drops any Dart-side event or property outside the schema
/// ([finalCheck]), whatever added it.
class PostHogSink implements AnalyticsSink {
  PostHogSink({required this.projectToken, required this.host});

  final String projectToken;
  final String host;

  /// The configuration [start] uses (exposed for tests of the settings).
  PostHogConfig buildConfig() {
    final config = PostHogConfig(projectToken)
      ..host = host
      ..captureApplicationLifecycleEvents = false
      ..sessionReplay = false
      ..surveys = false
      ..personProfiles = PostHogPersonProfiles.identifiedOnly
      ..sendFeatureFlagEvents = false
      ..preloadFeatureFlags = false
      ..capturePushNotificationSubscriptions = false
      ..capturePushNotificationOpened = false
      ..debug = false
      ..optOut = false
      ..flushAt = 20
      ..flushInterval = const Duration(seconds: 30);
    config.rageClickConfig.enabled = false;
    config.errorTrackingConfig
      ..captureFlutterErrors = false
      ..captureSilentFlutterErrors = false
      ..capturePlatformDispatcherErrors = false
      ..captureIsolateErrors = false
      ..captureNativeExceptions = false
      ..captureNativeCrashes = false;
    config.beforeSend = [
      (event) {
        final checked = finalCheck(event.event, event.properties);
        if (checked == null) return null;
        event
          ..properties = checked.properties
          // No person properties, ever.
          ..userProperties = null
          ..userPropertiesSetOnce = null;
        return event;
      },
    ];
    return config;
  }

  @override
  Future<void> start() => Posthog().setup(buildConfig());

  @override
  Future<void> capture(String name, Map<String, Object> properties) =>
      Posthog().capture(eventName: name, properties: properties);

  @override
  Future<void> identify(String distinctId) =>
      Posthog().identify(userId: distinctId);

  @override
  Future<void> optIn() => Posthog().enable();

  @override
  Future<void> optOut() => Posthog().disable();

  @override
  Future<void> reset() => Posthog().reset();

  @override
  Future<void> flush() => Posthog().flush();
}
