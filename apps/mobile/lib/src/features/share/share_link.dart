import 'dart:math';

import 'package:aura_domain/aura_domain.dart';

import '../../core/db/kv_store.dart';

/// Where a shared card points (PRD "store link"). A landing page that picks
/// the right store is expected in production (`AURA_SHARE_URL`); the default
/// is the Play listing.
const String _shareUrl = String.fromEnvironment(
  'AURA_SHARE_URL',
  defaultValue: 'https://play.google.com/store/apps/details?id=com.akvega.aura',
);

/// A random share token (PRD `[ASSUMPTION]`): 16 characters from a secure
/// random source. Never derived from the user id, never stored or sent
/// anywhere by the app; it only rides on the link.
String newShareToken([Random? random]) {
  const alphabet = 'abcdefghijkmnpqrstuvwxyz23456789';
  final r = random ?? Random.secure();
  return List.generate(16, (_) => alphabet[r.nextInt(alphabet.length)]).join();
}

/// The link sent with a card. [token] `null` → the plain store link
/// (REQ-SHR-04: under-18 accounts, and any account whose age this phone
/// doesn't know).
Uri shareLink({String? token, String base = _shareUrl}) {
  final uri = Uri.parse(base);
  if (token == null) return uri;
  final isPlay = uri.host == 'play.google.com';
  return uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      if (isPlay)
        'referrer': 'utm_source=aura_share&utm_content=$token'
      else
        's': token,
    },
  );
}

/// Whether this phone may add a token: only when it knows the person is 18 or
/// older (`minorUntil` set at onboarding and passed). Unknown → no token. The
/// card and the share flow are identical either way.
Future<bool> shareTokenAllowed(KvStore kv, LocalDay today) async {
  final until = LocalDay.tryParse(await kv.get(KvKeys.minorUntil));
  return until != null && !today.isBefore(until);
}
