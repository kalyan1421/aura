import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../features/support/helplines.dart';
import 'remote_config_store.dart';
import 'signed_bundle.dart';

/// The crisis helpline directory without an app release (PRD 18
/// "Helplines by country": remote config, localized, cached on device;
/// 16-offline "list refreshed on sync"; contracts/safety/helplines.schema.json).
///
/// A downloaded `helplines` bundle replaces the working numbers only when, in
/// this order:
///  1. its Ed25519 signature verifies with a key this build embeds
///     ([BundleKeys]) — over the exact bytes, before anything is read;
///  2. it is a `helplines` bundle whose `seq` is newer than the one this phone
///     already uses (an older one is a replay);
///  3. its content follows the contract ([compileHelplines]): every number's
///     digits are its dial string, every region has a line for everyone, and
///     every region this build bundles (India, the US) is still there — so a
///     bundle can never leave the sheet empty where it has numbers today;
///  4. every case in its `vectors` (region × adult/minor → the dial list)
///     comes out the same with THIS build's resolver.
/// Then it becomes [HelplineDirectory.active] and its raw envelope is kept for
/// the next start (checked again, the same way). Anything else — unsigned,
/// tampered, replayed, malformed, an unknown key — leaves the last verified
/// directory in place, else the bundled one.
class RemoteHelplines {
  RemoteHelplines({required this.keys, required this._store});

  static const String kind = 'helplines';

  /// Store entry holding `{ "etag": …, "bundle": <envelope> }`.
  static const String storeName = 'helplines.json';

  final BundleKeys keys;
  final RemoteConfigStore _store;

  int _seq = 0;
  String? _etag;
  int? _refusedSeq;

  /// The seq of the active remote version (0: the bundled one is active).
  int get activeSeq => _seq;

  /// The seq of the last downloaded bundle that was refused (in memory).
  int? get refusedSeq => _refusedSeq;

  String? get etag => _etag;

  /// At start: the kept envelope, verified again; the bundled directory when
  /// absent or no longer valid.
  Future<void> restore() async {
    final text = await _store.read(storeName);
    if (text == null) return;
    try {
      final saved = jsonDecode(text) as Map<String, dynamic>;
      final checked = await _check(saved['bundle'], minSeq: 0);
      _seq = checked.seq;
      _etag = saved['etag'] as String?;
      HelplineDirectory.activate(checked.directory);
    } on Object catch (e) {
      debugPrint('helplines: kept bundle not used (${_why(e)})');
      await _store.delete(storeName);
    }
  }

  /// A freshly downloaded envelope ([json] decoded). Returns whether it is
  /// now active; never throws.
  Future<bool> apply(Object? json, {String? etag}) async {
    try {
      final checked = await _check(json, minSeq: _seq + 1);
      await _store.write(storeName, jsonEncode({'etag': etag, 'bundle': json}));
      _seq = checked.seq;
      _etag = etag;
      _refusedSeq = null;
      HelplineDirectory.activate(checked.directory);
      debugPrint(
        'helplines: v${checked.directory.version} active (seq ${checked.seq})',
      );
      return true;
    } on Object catch (e) {
      _refusedSeq = _claimedSeq(json);
      debugPrint('helplines: bundle not used (${_why(e)})');
      return false;
    }
  }

  Future<({HelplineDirectory directory, int seq})> _check(
    Object? json, {
    required int minSeq,
  }) async {
    final bundle = await verifySignedBundle(json, keys, kind: kind);
    if (bundle.seq < minSeq) {
      throw const BundleRejected(BundleRejection.replayed);
    }
    final directory = compileHelplines(bundle.content);
    if (bundle.version != directory.version) {
      throw const BundleRejected(BundleRejection.invalidContent);
    }
    if (!helplineVectorsPass(directory, bundle.vectors)) {
      throw const BundleRejected(BundleRejection.vectorsFailed);
    }
    return (directory: directory, seq: bundle.seq);
  }

  static String _why(Object e) =>
      e is BundleRejected ? e.reason.name : e.runtimeType.toString();

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

const Set<String> _locales = {'en', 'te', 'te-Latn', 'hi', 'hi-Latn'};
final RegExp _country = RegExp(r'^[A-Z]{2}$');
final RegExp _lineId = RegExp(r'^[a-z]{2}\.[a-z0-9_]{1,40}$');
final RegExp _number = RegExp(r'^[0-9+() -]{2,24}$');
final RegExp _dial = RegExp(r'^[0-9]{2,15}$');
final RegExp _control = RegExp(r'[\x00-\x1f\x7f]');
final RegExp _nonDigit = RegExp('[^0-9]');

/// A directory document (contracts/safety/helplines.schema.json) → a
/// [HelplineDirectory], or [BundleRejected] ([BundleRejection.invalidContent]).
/// The same rules as tool/gen_helplines.py and the server, plus the one that
/// protects this build: every region it bundles must still be listed.
HelplineDirectory compileHelplines(Map<String, dynamic> doc) {
  Never invalid() => throw const BundleRejected(BundleRejection.invalidContent);
  if (doc['name'] != 'aura.helplines') invalid();
  final version = doc['version'];
  if (version is! int || version < 1 || version > 1000000) invalid();
  final countries = doc['countries'];
  if (countries is! Map<String, dynamic> ||
      countries.isEmpty ||
      countries.length > 250) {
    invalid();
  }
  final seen = <String>{};
  final out = <String, List<HelplineEntry>>{};
  for (final MapEntry(key: code, value: lines) in countries.entries) {
    if (!_country.hasMatch(code)) invalid();
    if (lines is! List<dynamic> || lines.isEmpty || lines.length > 10) {
      invalid();
    }
    final entries = <HelplineEntry>[];
    for (final line in lines) {
      if (line is! Map<String, dynamic>) invalid();
      final id = line['id'];
      final number = line['number'];
      final dial = line['dial'];
      final audience = line['audience'];
      final names = line['names'];
      if (id is! String ||
          !_lineId.hasMatch(id) ||
          !id.startsWith('${code.toLowerCase()}.') ||
          !seen.add(id)) {
        invalid();
      }
      if (number is! String || !_number.hasMatch(number)) invalid();
      if (dial is! String || !_dial.hasMatch(dial)) invalid();
      // What is shown is what is dialled.
      if (number.replaceAll(_nonDigit, '') != dial) invalid();
      if (audience != 'everyone' && audience != 'minors') invalid();
      if (names is! Map<String, dynamic> || names['en'] is! String) invalid();
      final localized = <String, String>{};
      for (final MapEntry(key: locale, value: name) in names.entries) {
        if (!_locales.contains(locale)) invalid();
        if (name is! String ||
            name.trim().isEmpty ||
            name.length > 80 ||
            _control.hasMatch(name)) {
          invalid();
        }
        localized[locale] = name;
      }
      entries.add(
        HelplineEntry(
          id: id,
          number: number,
          dial: dial,
          minorsOnly: audience == 'minors',
          names: Map.unmodifiable(localized),
        ),
      );
    }
    if (entries.every((e) => e.minorsOnly)) invalid();
    out[code] = List.unmodifiable(entries);
  }
  // Never lose a region this build lists: a bundle can change its numbers,
  // not take the whole list away (that needs an app release).
  for (final code in HelplineDirectory.bundled.countries.keys) {
    if (!out.containsKey(code)) invalid();
  }
  return HelplineDirectory(version: version, countries: Map.unmodifiable(out));
}

/// Every vector (`{country, minor, dials}`) lists exactly those dial strings
/// with [directory]. A vector in another shape counts as a failure.
bool helplineVectorsPass(HelplineDirectory directory, List<dynamic> vectors) {
  for (final v in vectors) {
    if (v is! Map<String, dynamic>) return false;
    final country = v['country'];
    final minor = v['minor'];
    final dials = v['dials'];
    if (country is! String || minor is! bool || dials is! List<dynamic>) {
      return false;
    }
    final got = [
      for (final e in directory.resolve(country, isMinor: minor)) e.dial,
    ];
    if (!listEquals<Object?>(got, dials)) return false;
  }
  return true;
}
