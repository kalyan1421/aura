import 'package:aura_domain/aura_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../onboarding/gate_controller.dart';
import '../profile/profile_service.dart';
import 'age_signals.dart';
import 'auth_repository.dart';
import 'social_sign_in.dart';

part 'auth_providers.g.dart';

/// Which social buttons this build offers (from `--dart-define`s).
@Riverpod(keepAlive: true)
SocialSignInConfig socialSignInConfig(Ref ref) => SocialSignInConfig.fromEnv();

/// Native Apple / Google → Supabase session. `null` when this build has no
/// Supabase (sign-in is unavailable, so no social button shows either).
@Riverpod(keepAlive: true)
SocialSignInService? socialSignIn(Ref ref) {
  final auth = ref.watch(authRepositoryProvider);
  if (auth case final SocialSessionExchange exchange) {
    final config = ref.watch(socialSignInConfigProvider);
    final ios = config.platform == SocialPlatform.ios;
    return SocialSignInService(
      config: config,
      exchange: exchange,
      google: config.googleConfigured
          ? PluginGoogleSignIn(
              serverClientId: config.googleWebClientId,
              clientId: ios ? config.googleIosClientId : null,
              fetchAccessToken: ios,
            )
          : null,
    );
  }
  return null;
}

/// Apple Declared Age Range / Play Age Signals (REQ-ACC-04).
@Riverpod(keepAlive: true)
AgeSignalSource ageSignalSource(Ref ref) => const ChannelAgeSignalSource();

/// Applies a signal: the under-13 block or the invisible under-18 flag (on
/// the phone, and on the server with the next profile POST).
@Riverpod(keepAlive: true)
AgeSignalPolicy ageSignalPolicy(Ref ref) => AgeSignalPolicy(
  kv: ref.watch(kvStoreProvider),
  blockUnder13: () => ref.read(gateControllerProvider.notifier).blockUnder13(),
  // The device's calendar date, as the DOB gate uses.
  today: () {
    final now = ref.read(timeContextProvider).now().toLocal();
    return LocalDay(now.year, now.month, now.day);
  },
  onMinor: () async {
    await ref.read(profileServiceProvider).noteAgeSignal(AgeBand.under18);
    ref.read(syncControllerProvider).notifyLocalWrite();
  },
);
