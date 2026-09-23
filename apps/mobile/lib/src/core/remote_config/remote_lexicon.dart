import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../features/support/crisis_lexicon.dart';
import '../../features/support/crisis_lexicon_data.dart';
import 'remote_config_store.dart';
import 'signed_bundle.dart';

/// Crisis lexicon versions without an app release (PRD 19 REQ-ADM-12; 06c
/// F9 "versioned signed bundle … refreshed on sync").
///
/// A downloaded bundle is used only when, in this order:
///  1. its Ed25519 signature verifies with a key this build embeds
///     ([BundleKeys]) — over the exact bytes, before anything is read;
///  2. it is a `crisis_lexicon` bundle whose `seq` is newer than the one this
///     phone already uses (an older one is a replay; a rollback on the server
///     is a new signature with a higher seq);
///  3. its content follows contracts/safety (the same rules as
///     tool/gen_lexicon.py and the server) and compiles;
///  4. every case in its `vectors` (the contract vectors + the version's own)
///     gives the expected verdict with THIS build's matcher.
/// Then it becomes [CrisisLexicon.active] and its raw envelope is kept for
/// the next start (checked again, the same way, before use). Anything else
/// leaves the last verified version in place, or the bundled v1 when there
/// is none. Lexicon words and texts are never logged.
class RemoteLexicon {
  RemoteLexicon({required this.keys, required this._store});

  static const String kind = 'crisis_lexicon';

  /// Store entry holding `{ "etag": …, "bundle": <envelope> }`.
  static const String storeName = 'crisis_lexicon.json';

  final BundleKeys keys;
  final RemoteConfigStore _store;

  int _seq = 0;
  String? _etag;
  int? _refusedSeq;

  /// The seq of the active remote version (0: the bundled one is active).
  int get activeSeq => _seq;

  /// The seq of the last downloaded bundle that was refused (in memory): not
  /// fetched again until the server points at another one.
  int? get refusedSeq => _refusedSeq;

  /// The ETag of the active remote version (for `If-None-Match`).
  String? get etag => _etag;

  /// At start: the kept envelope, verified again; bundled v1 when absent or
  /// no longer valid (e.g. its key was retired in this build).
  Future<void> restore() async {
    final text = await _store.read(storeName);
    if (text == null) return;
    try {
      final saved = jsonDecode(text) as Map<String, dynamic>;
      final lexicon = await _check(saved['bundle'], minSeq: 0);
      _seq = lexicon.seq;
      _etag = saved['etag'] as String?;
      CrisisLexicon.activate(lexicon.lexicon);
    } on Object catch (e) {
      debugPrint('lexicon: kept bundle not used (${_why(e)})');
      await _store.delete(storeName);
    }
  }

  /// A freshly downloaded envelope ([json] decoded). Returns whether it is
  /// now active; never throws.
  Future<bool> apply(Object? json, {String? etag}) async {
    try {
      final lexicon = await _check(json, minSeq: _seq + 1);
      await _store.write(storeName, jsonEncode({'etag': etag, 'bundle': json}));
      _seq = lexicon.seq;
      _etag = etag;
      _refusedSeq = null;
      CrisisLexicon.activate(lexicon.lexicon);
      debugPrint(
        'lexicon: v${lexicon.lexicon.version} active (seq ${lexicon.seq})',
      );
      return true;
    } on Object catch (e) {
      _refusedSeq = _claimedSeq(json);
      debugPrint('lexicon: bundle not used (${_why(e)})');
      return false;
    }
  }

  Future<({CrisisLexicon lexicon, int seq})> _check(
    Object? json, {
    required int minSeq,
  }) async {
    final bundle = await verifySignedBundle(json, keys, kind: kind);
    if (bundle.seq < minSeq) {
      throw const BundleRejected(BundleRejection.replayed);
    }
    final lexicon = compileLexicon(bundle.content);
    if (!vectorsPass(lexicon, bundle.vectors)) {
      throw const BundleRejected(BundleRejection.vectorsFailed);
    }
    return (lexicon: lexicon, seq: bundle.seq);
  }

  static String _why(Object e) =>
      e is BundleRejected ? e.reason.name : e.runtimeType.toString();

  /// The seq a refused envelope claims (unverified: only used to skip
  /// downloading the same refused bundle again).
  static int? _claimedSeq(Object? json) {
    try {
      final payload = (json as Map<String, dynamic>)['payload'] as String;
      final decoded = jsonDecode(
        utf8.decode(base64.decode(payload)),
      ) as Map<String, dynamic>;
      return decoded['seq'] as int?;
    } on Object {
      return null;
    }
  }
}

const Map<String, String> _languages = {
  'en': 'Latin',
  'te': 'Telugu',
  'te-Latn': 'Latin',
  'hi': 'Devanagari',
  'hi-Latn': 'Latin',
};

final RegExp _latinForm = RegExp("^[A-Za-z0-9 '’-]+\$");
final RegExp _space = RegExp(r'\s');

/// A lexicon document (contracts/safety schema) → a compiled [CrisisLexicon],
/// or [BundleRejected] ([BundleRejection.invalidContent]). The same rules as
/// the server and tool/gen_lexicon.py, never stricter (a version the server
/// published must never be refused here for a rule it doesn't have).
CrisisLexicon compileLexicon(Map<String, dynamic> doc) {
  Never invalid() => throw const BundleRejected(BundleRejection.invalidContent);
  if (doc['name'] != 'aura.crisis_lexicon') invalid();
  final version = doc['version'];
  if (version is! int || version < 1) invalid();
  final languages = doc['languages'];
  if (languages is! Map<String, dynamic> ||
      !setEquals(languages.keys.toSet(), _languages.keys.toSet())) {
    invalid();
  }
  final raw = doc['entries'];
  if (raw is! List<dynamic> || raw.isEmpty || raw.length > 5000) invalid();
  final seen = <String>{};
  final entries = <CrisisLexiconEntry>[];
  for (final e in raw) {
    if (e is! Map<String, dynamic>) invalid();
    final id = e['id'];
    final language = e['language'];
    final kind = e['kind'];
    final stem = e['stem'] ?? false;
    final phrase = e['phrase'];
    final variants = e['variants'] ?? const <dynamic>[];
    if (id is! String || !seen.add(id)) invalid();
    if (language is! String || !_languages.containsKey(language)) invalid();
    if (!RegExp('^${RegExp.escape(language)}\\.[a-z0-9_]+\$').hasMatch(id)) {
      invalid();
    }
    if (kind != 'crisis' && kind != 'soft') invalid();
    if (stem is! bool || phrase is! String || variants is! List<dynamic>) {
      invalid();
    }
    final forms = <String>[phrase];
    for (final v in variants) {
      if (v is! String) invalid();
      forms.add(v);
    }
    if (forms.toSet().length != forms.length) invalid();
    final script = _languages[language]!;
    for (final form in forms) {
      if (form.trim().isEmpty || form.length > 200) invalid();
      if (script == 'Latin') {
        if (!_latinForm.hasMatch(form)) invalid();
        continue;
      }
      final (lo, hi) = script == 'Telugu' ? (0x0C00, 0x0C7F) : (0x0900, 0x097F);
      for (final rune in form.runes) {
        if (_space.hasMatch(String.fromCharCode(rune))) continue;
        final inScript = rune >= lo && rune <= hi;
        if (!inScript && rune != 0x200C && rune != 0x200D) invalid();
      }
    }
    entries.add((
      id: id,
      language: language,
      kind: kind as String,
      stem: stem,
      forms: List.unmodifiable(forms),
    ));
  }
  return CrisisLexicon.fromEntries(entries, version: version);
}

/// Every vector (`{text, verdict}`) gives its verdict with [lexicon]. A
/// vector in another shape counts as a failure.
bool vectorsPass(CrisisLexicon lexicon, List<dynamic> vectors) {
  for (final v in vectors) {
    if (v is! Map<String, dynamic>) return false;
    final text = v['text'];
    final verdict = v['verdict'];
    if (text is! String || verdict is! String) return false;
    final expected = LexiconVerdict.values.asNameMap()[verdict];
    if (expected == null || lexicon.verdict(text) != expected) return false;
  }
  return true;
}

/// The bundled lexicon's version, for comparisons in UI and tests.
int get bundledLexiconVersion => crisisLexiconVersion;
