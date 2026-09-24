import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'procedural_synth.dart';
import 'stem_manifest_bundled.dart';

/// The Sounds stem manifest (`contracts/sounds/stems.v1.json`, bundled as
/// [bundledStemManifestJson]). One entry per stem: its id, title key, tier
/// (free base set or Plus), role (a continuous bed or a struck accent) and
/// where its audio comes from: generated in code, or a recorded file that is
/// downloaded once and verified by SHA-256.

enum StemTier { free, plus }

enum StemKind { procedural, file }

/// A continuous texture (rain, noise) or a struck accent (bowl, chimes).
/// The night wind-down always keeps a bed underneath.
enum StemRole { bed, accent }

enum StemStatus { available, pendingSourcing }

/// A recorded stem's file (relative to the Sounds download base URL).
@immutable
class StemFile {
  const StemFile({
    required this.path,
    required this.bytes,
    required this.sha256,
  });

  final String path;
  final int bytes;

  /// Lower-case hex.
  final String sha256;
}

@immutable
class Stem {
  const Stem({
    required this.id,
    required this.titleKey,
    required this.tier,
    required this.role,
    required this.kind,
    required this.status,
    this.generator,
    this.fallbackGenerator,
    this.file,
    this.licence,
    this.sourceUrl,
  });

  final String id;

  /// ARB key of the stem's name (`sounds_stemRain`).
  final String titleKey;
  final StemTier tier;
  final StemRole role;
  final StemKind kind;
  final StemStatus status;

  /// Procedural stems: what generates them.
  final StemGenerator? generator;

  /// File stems: what plays until the recording is downloaded (or while it
  /// is still being sourced).
  final StemGenerator? fallbackGenerator;

  /// File stems whose recording is available.
  final StemFile? file;
  final String? licence;
  final String? sourceUrl;

  bool get isPlus => tier == StemTier.plus;

  /// A recorded file exists for this stem (it may not be downloaded yet).
  bool get hasRecording =>
      kind == StemKind.file && status == StemStatus.available && file != null;

  /// What plays without any download, if anything.
  StemGenerator? get generatedSource =>
      kind == StemKind.procedural ? generator : fallbackGenerator;

  /// Shown in the app: generated in code, a recording that exists, or a
  /// recording still being sourced that has a generated stand-in. A stem
  /// that is only a pending recording stays hidden.
  bool get listed => generatedSource != null || hasRecording;
}

@immutable
class StemManifest {
  const StemManifest({
    required this.version,
    required this.maxLayers,
    required this.stems,
  });

  /// Parses manifest JSON. A wrong `version` or shape throws
  /// [FormatException]; a single bad entry (unknown generator, a file
  /// without its size or hash, a duplicate id) is skipped, so a newer
  /// manifest never breaks an older app.
  factory StemManifest.parse(String source) {
    final root = jsonDecode(source);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('stem manifest: not an object');
    }
    if (root['version'] != 1) {
      throw FormatException('stem manifest: unsupported version ${root['version']}');
    }
    final rawStems = root['stems'];
    if (rawStems is! List) {
      throw const FormatException('stem manifest: no stems list');
    }
    final maxLayers = root['max_layers'];
    final stems = <Stem>[];
    final seen = <String>{};
    for (final raw in rawStems) {
      final stem = _parseStem(raw);
      if (stem == null || !seen.add(stem.id)) {
        debugPrint('sounds: skipped a manifest entry');
        continue;
      }
      stems.add(stem);
    }
    return StemManifest(
      version: 1,
      maxLayers: maxLayers is int && maxLayers > 0 ? maxLayers : 4,
      stems: List.unmodifiable(stems),
    );
  }

  /// The manifest shipped with the app.
  static final StemManifest bundled = StemManifest.parse(
    bundledStemManifestJson,
  );

  final int version;

  /// How many stems may play at once (PRD: up to 4).
  final int maxLayers;
  final List<Stem> stems;

  /// The stems the app shows, in manifest order.
  List<Stem> get listed => [
    for (final s in stems)
      if (s.listed) s,
  ];

  Stem? byId(String id) {
    for (final s in stems) {
      if (s.id == id) return s;
    }
    return null;
  }
}

final RegExp _sha256Hex = RegExp(r'^[0-9a-f]{64}$');
final RegExp _stemId = RegExp(r'^[a-z][a-z0-9_]{0,39}$');

Stem? _parseStem(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final id = raw['id'];
  final titleKey = raw['title_key'];
  if (id is! String || !_stemId.hasMatch(id)) return null;
  if (titleKey is! String || titleKey.isEmpty) return null;
  final tier = switch (raw['tier']) {
    'free' => StemTier.free,
    'plus' => StemTier.plus,
    _ => null,
  };
  final role = switch (raw['role'] ?? 'bed') {
    'bed' => StemRole.bed,
    'accent' => StemRole.accent,
    _ => null,
  };
  final kind = switch (raw['kind']) {
    'procedural' => StemKind.procedural,
    'file' => StemKind.file,
    _ => null,
  };
  final status = switch (raw['status']) {
    'available' => StemStatus.available,
    'pending_sourcing' => StemStatus.pendingSourcing,
    _ => null,
  };
  if (tier == null || role == null || kind == null || status == null) {
    return null;
  }
  final licence = raw['licence'] is String ? raw['licence'] as String : null;
  final sourceUrl = raw['source_url'] is String
      ? raw['source_url'] as String
      : null;

  if (kind == StemKind.procedural) {
    final generator = StemGenerator.byId(raw['generator'] as String?);
    if (generator == null) return null;
    return Stem(
      id: id,
      titleKey: titleKey,
      tier: tier,
      role: role,
      kind: kind,
      status: StemStatus.available,
      generator: generator,
      licence: licence,
    );
  }

  final fallbackId = raw['fallback_generator'];
  final fallback = fallbackId == null
      ? null
      : StemGenerator.byId(fallbackId as String?);
  if (fallbackId != null && fallback == null) return null;

  StemFile? file;
  if (status == StemStatus.available) {
    final path = raw['file'];
    final bytes = raw['bytes'];
    final sha = raw['sha256'];
    // A downloadable file needs its size (shown before downloading), its
    // hash (checked after) and a licence (docs/sounds/licence-log.md).
    if (path is! String ||
        path.isEmpty ||
        path.contains('..') ||
        path.startsWith('/') ||
        bytes is! int ||
        bytes <= 0 ||
        sha is! String ||
        !_sha256Hex.hasMatch(sha) ||
        licence == null) {
      return null;
    }
    file = StemFile(path: path, bytes: bytes, sha256: sha);
  }
  return Stem(
    id: id,
    titleKey: titleKey,
    tier: tier,
    role: role,
    kind: kind,
    status: status,
    fallbackGenerator: fallback,
    file: file,
    licence: licence,
    sourceUrl: sourceUrl,
  );
}
