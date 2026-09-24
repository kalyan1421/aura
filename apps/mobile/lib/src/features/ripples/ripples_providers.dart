import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/env/env.dart';
import '../../core/providers.dart';
import '../../core/remote_config/remote_config_providers.dart';
import '../rooms/rooms_providers.dart' show roomsReadyProvider;
import 'ripple_channel.dart';
import 'ripples_api.dart';

/// Plain providers (no codegen). Tests override the API, the channel opener
/// and `rippleFeedbackProvider`.

/// `null` when this build has no API (debug builds without config).
final ripplesApiProvider = Provider<RipplesApi?>((ref) {
  if (!Env.hasApi) return null;
  final auth = ref.watch(authRepositoryProvider);
  return HttpRipplesApi(baseUrl: Env.apiUrl, accessToken: auth.accessToken);
});

/// Private Realtime channels, or `null` without Supabase (the session then
/// runs on this phone alone — never a failure).
final rippleChannelOpenerProvider = Provider<RippleChannelOpener?>((ref) {
  if (!Env.hasSupabase) return null;
  final auth = ref.watch(authRepositoryProvider);
  if (!auth.isAvailable) return null;
  try {
    return supabaseRippleChannels(
      sb.Supabase.instance.client,
      auth.accessToken,
    );
  } on Object {
    return null;
  }
});

/// Whether the Breath Ripples entries show: a signed-in, onboarded account
/// (the same as rooms) and the `ripples_enabled` kill switch on. The flag
/// only hides UI; the server enforces it.
final ripplesReadyProvider = Provider<bool>(
  (ref) =>
      ref.watch(roomsReadyProvider) &&
      ref.watch(ripplesApiProvider) != null &&
      ref.watch(remoteFlagsProvider).ripplesEnabled,
);
