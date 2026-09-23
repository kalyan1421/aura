import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'core/a11y/haptics.dart';
import 'core/l10n/locale_controller.dart';
import 'core/prefs/comfort_prefs.dart';
import 'core/providers.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'features/avatar/moments_controller.dart';
import 'features/capsules/capsule_providers.dart';
import 'features/onboarding/gate_controller.dart';
import 'features/profile/timezone_sync.dart';
import 'features/push/push_inbox.dart';

class AuraApp extends ConsumerStatefulWidget {
  const AuraApp({super.key});

  @override
  ConsumerState<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends ConsumerState<AuraApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The profile's timezone follows the device (travel, DST-free moves).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => refreshDeviceTimezone(ref),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(gateControllerProvider.notifier).refreshLock();
      refreshDeviceTimezone(ref)
          .whenComplete(() => ref.read(syncControllerProvider).onResume());
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = localeFromTag(ref.watch(localeControllerProvider));
    // Keep sync, push registration and the moment listener alive for the
    // whole session.
    ref.watch(syncControllerProvider);
    ref.watch(pushServiceProvider);
    ref.watch(pushInboxProvider); // F14: in-app notices + tap routing
    ref.watch(momentsControllerProvider);
    // Capsule unlock scheduling and trigger arming (F4) for the whole session.
    ref.watch(capsuleCoordinatorProvider);
    final router = ref.watch(routerProvider);
    final comfort = ref.watch(comfortControllerProvider);
    AuraHaptics.enabled = comfort.haptics;

    final theme = buildAuraTheme(locale);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...systemLocalizationDelegates,
      ],
      routerConfig: router,
      // In-app Reduce Motion joins the OS setting (REQ-A11Y-08): every
      // `reduceMotionOf(context)` / `disableAnimations` check sees both.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        if (!comfort.reduceMotion || mq.disableAnimations) return child!;
        return MediaQuery(
          data: mq.copyWith(disableAnimations: true),
          child: child!,
        );
      },
    );
  }
}
