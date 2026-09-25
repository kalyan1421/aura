import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';

/// Tonight's intention words from the server (`GET /v1/intentions`,
/// contracts/api/v1-rooms.md §1.10): every preset key's line in the five app
/// languages, edited in the admin console. Public and content-free (the same
/// for everyone), so no sign-in header. The room shows these words first, so
/// a reworded or newly added preset reaches phones without a release; the
/// bundled `rooms_intention_*` strings are the fallback (offline, older
/// server), and a key with neither hides the card (never a raw key).
typedef IntentionCopy = Map<String, Map<String, String>>;

/// The app locale's tag as the server keys it: `en`, `te`, `te-Latn`, `hi`,
/// `hi-Latn` (anything else → `en`).
String intentionLocaleTag(Locale locale) {
  final lang = locale.languageCode;
  if (lang != 'te' && lang != 'hi') return 'en';
  return locale.scriptCode == 'Latn' ? '$lang-Latn' : lang;
}

/// Parses the response; anything malformed is dropped (never shown).
@visibleForTesting
IntentionCopy parseIntentionCopy(Object? json) {
  final out = <String, Map<String, String>>{};
  if (json is! Map) return out;
  final list = json['intentions'];
  if (list is! List) return out;
  final keyRe = RegExp(r'^[a-z][a-z0-9_]{1,47}$');
  for (final item in list) {
    if (item is! Map) continue;
    final key = item['key'];
    final texts = item['texts'];
    if (key is! String || !keyRe.hasMatch(key) || texts is! Map) continue;
    final lines = <String, String>{};
    texts.forEach((l, t) {
      if (l is String &&
          t is String &&
          t.trim().isNotEmpty &&
          t.length <= 160) {
        lines[l] = t.trim();
      }
    });
    if (lines.isNotEmpty) out[key] = lines;
  }
  return out;
}

/// The server's line for [key] in [locale], else `null` (use the bundled
/// string).
String? serverIntentionText(IntentionCopy? copy, String key, Locale locale) =>
    copy?[key]?[intentionLocaleTag(locale)];

/// How the words are fetched (tests replace it; no network in tests).
typedef IntentionCopyLoader = Future<IntentionCopy> Function();

/// `GET /v1/intentions` on the API (public: no sign-in header). No API in
/// this build → nothing (the bundled strings take over).
Future<IntentionCopy> loadIntentionCopy() async {
  if (!Env.hasApi) return const {};
  final res = await Dio(
    BaseOptions(
      baseUrl: Env.apiUrl,
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 8),
      responseType: ResponseType.json,
    ),
  ).get<Object?>('/v1/intentions');
  return parseIntentionCopy(res.data);
}

final intentionCopyLoaderProvider = Provider<IntentionCopyLoader>(
  (ref) => loadIntentionCopy,
);

/// Loads the words once per room screen (tiny); an error → empty (the
/// bundled strings take over).
final intentionCopyProvider = FutureProvider.autoDispose<IntentionCopy>((
  ref,
) async {
  try {
    return await ref.read(intentionCopyLoaderProvider)();
  } on Object catch (e) {
    debugPrint('intentions: words not loaded (${e.runtimeType})');
    return const {};
  }
});
