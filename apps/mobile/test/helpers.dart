import 'dart:async';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/core/sync/sync_service.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/avatar/avatar_assets.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/push/push_messaging.dart';
import 'package:aura/src/features/widget/widget_bridge.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'widget_fakes.dart';

/// 15:30 IST on 8 Oct 2026 — a plain afternoon Aura day.
final DateTime testNow = DateTime.utc(2026, 10, 8, 10);

TimeContext testTime([DateTime? now]) =>
    TimeContext(clock: FixedClock(now ?? testNow), timezone: 'Asia/Kolkata');

AppDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// Sync that never touches the network (and starts no timers).
class FakeSync implements SyncController {
  final ValueNotifier<SyncPhase> _phase = ValueNotifier(SyncPhase.offline);
  final ValueNotifier<bool> _online = ValueNotifier(true);
  int writes = 0;
  int syncNowCalls = 0;
  int drainCalls = 0;

  @override
  ValueListenable<SyncPhase> get phase => _phase;
  @override
  ValueListenable<bool> get online => _online;
  @override
  void notifyLocalWrite() => writes++;
  @override
  void onResume() {}
  @override
  void syncNow() => syncNowCalls++;
  @override
  Future<void> pause() async {}
  @override
  void resume() {}
  @override
  Future<void> drain({Duration timeout = const Duration(seconds: 20)}) async =>
      drainCalls++;
}

AvatarAssets emptyAssets() => AvatarAssets(
  manifest: null,
  base: null,
  glowProgram: null,
  nebulaProgram: null,
);

List<Override> testOverrides({
  required AppDatabase db,
  SecureStore? secure,
  GateState gate = const GateState(stage: OnboardingStage.done),
  String locale = 'en',
  AvatarAssets? assets,
  FakeSync? sync,
  TimeContext? time,
  AuthRepository auth = const UnavailableAuthRepository(),
  MemoryWidgetHost? widgetHost,
}) {
  final t = time ?? testTime();
  return [
    appDatabaseProvider.overrideWithValue(db),
    secureStoreProvider.overrideWithValue(secure ?? MemorySecureStore()),
    timeContextProvider.overrideWithValue(t),
    initialTimezoneProvider.overrideWithValue(t.timezone),
    timezoneResolverProvider.overrideWithValue(() async => t.timezone),
    authRepositoryProvider.overrideWithValue(auth),
    syncControllerProvider.overrideWithValue(sync ?? FakeSync()),
    connectivityProvider.overrideWith((ref) => Stream.value(true)),
    nowProvider.overrideWith((ref) => Stream.value(t.now())),
    avatarAssetsProvider.overrideWith((ref) async => assets ?? emptyAssets()),
    initialGateProvider.overrideWithValue(gate),
    initialLocaleTagProvider.overrideWithValue(locale),
    // Home-screen widget (F11): an in-memory store, no PNG rendering.
    widgetHostProvider.overrideWithValue(widgetHost ?? MemoryWidgetHost()),
    avatarSnapshotterProvider.overrideWithValue((_) async => null),
  ];
}

/// Lets real async work (Drift I/O) finish, then pumps frames.
Future<void> settleIo(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Runs a database read outside fake async (Drift uses real timers).
Future<T> io<T>(WidgetTester tester, Future<T> Function() body) async =>
    (await tester.runAsync(body)) as T;

/// A localized MaterialApp around [child] (no router).
Widget localized(Widget child, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      theme: buildAuraTheme(locale),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...systemLocalizationDelegates,
      ],
      home: child,
    );

/// FCM stand-in: records every call, never touches a platform channel.
class FakeMessaging implements PushMessaging {
  FakeMessaging({this.ios = false});

  final bool ios;
  PushPermission granted = PushPermission.notDetermined;

  /// What the OS prompt resolves to when shown.
  PushPermission promptResult = PushPermission.authorized;
  String? apns = 'apns-1';
  String? fcmToken = 'fcm-1';
  Object? deleteError;

  final List<bool> requests = []; // `provisional` flag of each request
  int tokenCalls = 0;
  int apnsCalls = 0;
  int deleteCalls = 0;
  bool? autoInit;

  final refresh = StreamController<String>.broadcast();
  final messages = StreamController<String?>.broadcast();
  final opened = StreamController<String?>.broadcast();

  @override
  String get platform => ios ? 'ios' : 'android';
  @override
  bool get needsApnsToken => ios;
  @override
  bool get supportsProvisional => ios;

  @override
  Future<PushPermission> permission() async => granted;

  @override
  Future<PushPermission> requestPermission({bool provisional = false}) async {
    requests.add(provisional);
    granted = provisional ? PushPermission.provisional : promptResult;
    return granted;
  }

  @override
  Future<void> setAutoInitEnabled(bool enabled) async => autoInit = enabled;

  @override
  Future<String?> apnsToken() async {
    apnsCalls++;
    return apns;
  }

  @override
  Future<String?> token() async {
    tokenCalls++;
    return fcmToken;
  }

  @override
  Future<void> deleteToken() async {
    deleteCalls++;
    final e = deleteError;
    if (e != null) throw e;
    fcmToken = null;
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Stream<String?> get onMessageType => messages.stream;
  @override
  Stream<String?> get onOpenedType => opened.stream;
}
