import 'package:aura_domain/aura_domain.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/core/db/connection.dart';
import 'src/core/db/kv_store.dart';
import 'src/core/env/env.dart';
import 'src/core/l10n/locale_controller.dart';
import 'src/core/providers.dart';
import 'src/core/security/secure_session_storage.dart';
import 'src/core/security/secure_store.dart';
import 'src/core/time/clock.dart';
import 'src/core/time/device_timezone.dart';
import 'src/features/onboarding/age_gate.dart';
import 'src/features/onboarding/gate_controller.dart';
import 'src/features/push/push_messaging.dart';
import 'src/features/voice/voice_devices.dart';
import 'src/features/widget/widget_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureTimeZonesLoaded();

  // Key material (DB key, data keys) is ThisDeviceOnly; older items move on
  // first read (MASVS F-3, secure_store.dart).
  final secure = DeviceBoundKeyStore.platform();
  // iOS: keep the database directory out of iCloud backup (Apple 5.1.3).
  final db = await openAppDatabase(
    secure,
    excludeFromBackup: const ChannelAuraPlatform().excludeFromBackup,
  );
  final kv = KvStore(db);
  // Unknown device zones resolve to a fixed-offset zone (never silent UTC);
  // the same id goes into the profile and every mutation.
  final timezone = await resolveDeviceTimezone();

  // Read before the first frame, so a locked device never sees DOB flash.
  final gate = await loadGateState(
    kv,
    AgeGate(secure, const Clock(), platformDeviceLockMirror()),
  );
  final locale =
      await kv.get(KvKeys.locale) ??
      defaultLocaleTag(PlatformDispatcher.instance.locales);

  if (Env.hasSupabase) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseKey,
        // Session in Keychain / Keystore, not SharedPreferences (MASVS).
        authOptions: secureAuthOptions(supabaseUrl: Env.supabaseUrl, kv: kv),
      );
    } catch (e) {
      // The app still works fully on this phone without auth.
      debugPrint('supabase: init failed (${e.runtimeType})');
    }
  }

  // Push (FCM) is optional: if Firebase can't start, the app starts anyway
  // and simply never registers for push.
  PushMessaging? push;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5));
    FirebaseMessaging.onBackgroundMessage(auraPushBackgroundHandler);
    push = FirebasePushMessaging();
  } catch (e) {
    debugPrint('firebase: init failed (${e.runtimeType}); push is off');
  }

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureStoreProvider.overrideWithValue(secure),
        initialTimezoneProvider.overrideWithValue(timezone),
        initialGateProvider.overrideWithValue(gate),
        initialLocaleTagProvider.overrideWithValue(locale),
        pushMessagingProvider.overrideWithValue(push),
      ],
      child: const AuraApp(),
    ),
  );
}

/// Headless entrypoint for widget background refresh (F11; Android
/// `WidgetSyncWorker`, iOS `AuraWidgetBackgroundSync`): imports widget
/// check-ins and pushes the outbox without UI (widget_background.dart).
@pragma('vm:entry-point')
Future<void> widgetBackgroundMain() => runWidgetBackgroundEntry();
