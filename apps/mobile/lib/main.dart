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
import 'src/core/security/secure_store.dart';
import 'src/core/time/clock.dart';
import 'src/core/time/device_timezone.dart';
import 'src/features/onboarding/age_gate.dart';
import 'src/features/onboarding/gate_controller.dart';
import 'src/features/push/push_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureTimeZonesLoaded();

  final secure = FlutterSecureStore();
  final db = await openAppDatabase(secure);
  final kv = KvStore(db);
  // Unknown device zones resolve to a fixed-offset zone (never silent UTC);
  // the same id goes into the profile and every mutation.
  final timezone = await resolveDeviceTimezone();

  // Read before the first frame, so a locked device never sees DOB flash.
  final gate = await loadGateState(kv, AgeGate(secure, const Clock()));
  final locale =
      await kv.get(KvKeys.locale) ??
      defaultLocaleTag(PlatformDispatcher.instance.locales);

  if (Env.hasSupabase) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseKey,
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
