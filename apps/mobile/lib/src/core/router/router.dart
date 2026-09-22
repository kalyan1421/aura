import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/sign_in_screen.dart';
import '../../features/avatar/avatar_debug_screen.dart';
import '../../features/account/delete_account_screen.dart';
import '../../features/checkin/checkin_screen.dart';
import '../../features/history/checkin_detail_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/blocked_screen.dart';
import '../../features/onboarding/dob_screen.dart';
import '../../features/onboarding/gate_controller.dart';
import '../../features/onboarding/language_screen.dart';
import '../../features/onboarding/trust_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../env/env.dart';

part 'router.g.dart';

abstract final class Routes {
  static const String root = '/';
  static const String welcome = '/welcome';
  static const String trust = '/onboarding/trust';
  static const String dob = '/onboarding/dob';
  static const String language = '/onboarding/language';
  static const String onboardingSignIn = '/onboarding/sign-in';
  static const String blocked = '/blocked';
  static const String home = '/home';
  static const String checkIn = '/checkin';
  static const String settings = '/settings';
  static const String deleteAccount = '/settings/delete-account';
  static const String history = '/history';
  static String historyEntry(String checkInId) => '/history/$checkInId';
  static const String signIn = '/sign-in';
  static const String debugAvatar = '/debug/avatar';

  static String forStage(OnboardingStage s) => switch (s) {
    OnboardingStage.welcome => welcome,
    OnboardingStage.trust => trust,
    OnboardingStage.dob => dob,
    OnboardingStage.language => language,
    OnboardingStage.signIn => onboardingSignIn,
    OnboardingStage.firstCheckIn => checkIn,
    OnboardingStage.done => home,
  };
}

/// Pure redirect rule (unit-testable): the under-13 lock wins over
/// everything; onboarding steps run in order; after onboarding the
/// onboarding routes bounce to Home.
String? gateRedirect(GateState gate, String location) {
  if (gate.isBlocked) return location == Routes.blocked ? null : Routes.blocked;
  if (location == Routes.blocked) return Routes.root;
  if (location.startsWith('/debug')) return Env.debugTools ? null : Routes.root;

  final target = Routes.forStage(gate.stage);
  if (!gate.onboarded) return location == target ? null : target;

  const onboardingOnly = {
    Routes.root,
    Routes.welcome,
    Routes.trust,
    Routes.dob,
    Routes.language,
    Routes.onboardingSignIn,
  };
  return onboardingOnly.contains(location) ? Routes.home : null;
}

/// Calm transitions: a soft fade with a slight rise.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, _, child) {
        final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        if (reduce) return FadeTransition(opacity: curved, child: child);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final gate = ValueNotifier<GateState>(ref.read(gateControllerProvider));
  ref.listen(gateControllerProvider, (_, next) => gate.value = next);
  ref.onDispose(gate.dispose);

  GoRoute route(String path, Widget Function(GoRouterState s) build) => GoRoute(
    path: path,
    pageBuilder: (context, state) => _page(state, build(state)),
  );

  return GoRouter(
    initialLocation: Routes.root,
    refreshListenable: gate,
    redirect: (context, state) => gateRedirect(gate.value, state.matchedLocation),
    routes: [
      route(Routes.root, (_) => const SizedBox.shrink()),
      route(Routes.welcome, (_) => const WelcomeScreen()),
      route(Routes.trust, (_) => const TrustScreen()),
      route(Routes.dob, (_) => const DobScreen()),
      route(Routes.language, (_) => const LanguageScreen()),
      route(Routes.onboardingSignIn, (_) => const SignInScreen()),
      route(Routes.blocked, (_) => const BlockedScreen()),
      route(Routes.home, (_) => const HomeScreen()),
      route(
        Routes.checkIn,
        (_) => CheckInScreen(
          first: gate.value.stage == OnboardingStage.firstCheckIn,
        ),
      ),
      route(Routes.settings, (_) => const SettingsScreen()),
      route(Routes.deleteAccount, (_) => const DeleteAccountScreen()),
      route(Routes.history, (_) => const HistoryScreen()),
      route(
        '${Routes.history}/:id',
        (s) => CheckInDetailScreen(id: s.pathParameters['id']!),
      ),
      route(Routes.signIn, (_) => const SignInScreen(standalone: true)),
      route(Routes.debugAvatar, (_) => const AvatarDebugScreen()),
    ],
  );
}
