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
import '../../features/rooms/room_join_screen.dart';
import '../../features/rooms/room_navigation.dart' show RoomJoinRequest;
import '../../features/rooms/room_screen.dart';
import '../../features/rooms/rooms_home_screen.dart';
import '../../features/safety/safety_center_screen.dart';
import '../../features/sanctuary/sanctuary_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../a11y/motion.dart';
import 'deep_links.dart';
import 'routes.dart';

export 'routes.dart';

part 'router.g.dart';

/// Calm transitions: a soft fade with a slight rise. Under reduced motion a
/// plain crossfade of at most 300 ms (REQ-A11Y-08).
CustomTransitionPage<void> _page(
  GoRouterState state,
  Widget child, {
  required bool reduceMotion,
}) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: reduceMotion
      ? reducedMotionFade
      : const Duration(milliseconds: 380),
  reverseTransitionDuration: reduceMotion
      ? const Duration(milliseconds: 200)
      : const Duration(milliseconds: 260),
  transitionsBuilder: (context, animation, _, child) {
    final reduce = reduceMotionOf(context);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
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
    pageBuilder: (context, state) =>
        _page(state, build(state), reduceMotion: reduceMotionOf(context)),
  );

  StatefulShellBranch tab(String path, Widget screen) =>
      StatefulShellBranch(routes: [route(path, (_) => screen)]);

  return GoRouter(
    initialLocation: Routes.root,
    refreshListenable: gate,
    onEnter: (context, current, next, router) =>
        deepLinkOnEnter(router, next.uri, () => gate.value),
    redirect: (context, state) =>
        gateRedirect(gate.value, state.matchedLocation),
    routes: [
      route(Routes.root, (_) => const SizedBox.shrink()),
      route(Routes.welcome, (_) => const WelcomeScreen()),
      route(Routes.trust, (_) => const TrustScreen()),
      route(Routes.dob, (_) => const DobScreen()),
      route(Routes.language, (_) => const LanguageScreen()),
      route(Routes.onboardingSignIn, (_) => const SignInScreen()),
      route(Routes.blocked, (_) => const BlockedScreen()),
      // Home · Sanctuary · [Check in] · Rooms · Insights. Branch order is
      // ShellTab's.
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, shell) => _page(
          state,
          AppShell(shell: shell),
          reduceMotion: reduceMotionOf(context),
        ),
        branches: [
          tab(Routes.home, const HomeScreen()),
          tab(Routes.sanctuary, const SanctuaryScreen()),
          tab(Routes.rooms, const RoomsHomeScreen()),
          tab(Routes.insights, const HistoryScreen()),
        ],
      ),
      route(
        Routes.checkIn,
        (_) => CheckInScreen(
          first: gate.value.stage == OnboardingStage.firstCheckIn,
        ),
      ),
      route(Routes.safety, (_) => const SafetyCenterScreen()),
      route(Routes.settings, (_) => const SettingsScreen()),
      route(Routes.deleteAccount, (_) => const DeleteAccountScreen()),
      // The history list is the Insights tab (until F10 gives Insights its
      // own screen); older links and fallbacks land there.
      GoRoute(path: Routes.history, redirect: (_, _) => Routes.insights),
      route(
        '${Routes.history}/:id',
        (s) => CheckInDetailScreen(id: s.pathParameters['id']!),
      ),
      // F5 Mood Rooms, above the shell. The join screen gets the saved
      // check-in's quadrant and mood as `extra` (never in the location).
      route(
        Routes.roomJoin,
        (s) => RoomJoinScreen(
          request: s.extra is RoomJoinRequest ? s.extra! as RoomJoinRequest : null,
        ),
      ),
      route(
        '${Routes.rooms}/:id',
        (s) => RoomScreen(roomId: s.pathParameters['id']!),
      ),
      route(Routes.signIn, (_) => const SignInScreen(standalone: true)),
      route(Routes.debugAvatar, (_) => const AvatarDebugScreen()),
    ],
  );
}
