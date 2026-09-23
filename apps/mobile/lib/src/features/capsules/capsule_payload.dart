import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

// PRD F4 limits, enforced on the phone (the server only ever sees
// ciphertext, contracts/api/v1-capsules.md §1). Lengths are grapheme
// clusters, like every text limit.

/// Title, visible while sealed.
const int maxCapsuleTitleLength = 60;

/// The note inside.
const int maxCapsuleTextLength = 2000;

/// Free: 2 minutes (REQ-CAP-05). Plus (10 min) is not built.
const Duration maxCapsuleVoiceDuration = Duration(minutes: 2);

/// Photos per capsule, and their longest edge after resizing.
const int maxCapsulePhotos = 3;
const int maxCapsulePhotoEdge = 2048;

/// Largest ciphertexts `POST /v1/media/upload-url` accepts per kind.
const int maxCapsuleVoiceUploadBytes = 2097152;
const int maxCapsulePhotoUploadBytes = 4194304;

/// Media slots: `voice`, `photo-0` … `photo-2` (server object names).
abstract final class CapsuleSlots {
  static const String voice = 'voice';
  static String photo(int index) => 'photo-$index';

  static bool isPhoto(String slot) => slot.startsWith('photo-');

  /// The photo index of [slot] (`photo-1` → 1), or `null`.
  static int? photoIndex(String slot) =>
      isPhoto(slot) ? int.tryParse(slot.substring('photo-'.length)) : null;

  static const List<String> all = [voice, 'photo-0', 'photo-1', 'photo-2'];

  /// `POST /v1/media/upload-url` kind of [slot].
  static String kindOf(String slot) =>
      isPhoto(slot) ? 'capsule_photo' : 'capsule_voice';

  /// The associated data a slot's ciphertext is bound to.
  static String aadOf(String capsuleId, String slot) =>
      '${capsuleId.toLowerCase()}/$slot';

  /// The server object of [slot] (`<user_id>/capsules/<id>/<slot>`).
  static String objectPath(String userId, String capsuleId, String slot) =>
      '${userId.toLowerCase()}/capsules/${capsuleId.toLowerCase()}/$slot';
}

/// One media object inside a capsule (a reference; the bytes are separate
/// ciphertexts in Storage and on the phone).
@immutable
class CapsuleMediaRef {
  const CapsuleMediaRef({
    required this.slot,
    this.durationMs,
    this.width,
    this.height,
  });

  factory CapsuleMediaRef.fromJson(Map<String, dynamic> j) => CapsuleMediaRef(
    slot: j['slot'] as String,
    durationMs: (j['durationMs'] as num?)?.toInt(),
    width: (j['w'] as num?)?.toInt(),
    height: (j['h'] as num?)?.toInt(),
  );

  final String slot;

  /// Voice length.
  final int? durationMs;

  /// Photo size in pixels (after resizing).
  final int? width;
  final int? height;

  bool get isVoice => slot == CapsuleSlots.voice;
  bool get isPhoto => CapsuleSlots.isPhoto(slot);

  Map<String, Object?> toJson() => {
    'slot': slot,
    'durationMs': ?durationMs,
    'w': ?width,
    'h': ?height,
  };

  @override
  bool operator ==(Object other) =>
      other is CapsuleMediaRef &&
      other.slot == slot &&
      other.durationMs == durationMs &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(slot, durationMs, width, height);
}

/// What a capsule holds (the plaintext of `payloadCt`, versioned). Only this
/// phone ever sees it; the server stores it encrypted.
@immutable
class CapsulePayload {
  const CapsulePayload({
    this.title = '',
    this.text = '',
    this.hardMoment = false,
    this.media = const [],
  });

  /// Reads any version; unknown fields are ignored, missing ones default.
  factory CapsulePayload.fromJson(Map<String, dynamic> j) => CapsulePayload(
    title: (j['title'] as String?) ?? '',
    text: (j['text'] as String?) ?? '',
    hardMoment: (j['hardMoment'] as bool?) ?? false,
    media: [
      for (final m in (j['media'] as List<dynamic>?) ?? const [])
        if (m is Map<String, dynamic> && m['slot'] is String)
          CapsuleMediaRef.fromJson(m),
    ],
  );

  factory CapsulePayload.decode(String json) =>
      CapsulePayload.fromJson(jsonDecode(json) as Map<String, dynamic>);

  static const int version = 1;

  final String title;
  final String text;

  /// PRD `sealed_in_hard_moment`: the crisis lexicon matched while sealing.
  /// Only inside the ciphertext; the opening reads it after decrypting.
  final bool hardMoment;
  final List<CapsuleMediaRef> media;

  CapsuleMediaRef? get voice {
    for (final m in media) {
      if (m.isVoice) return m;
    }
    return null;
  }

  /// Photos in slot order.
  List<CapsuleMediaRef> get photos =>
      media.where((m) => m.isPhoto).toList()
        ..sort((a, b) => a.slot.compareTo(b.slot));

  bool get isEmpty =>
      title.trim().isEmpty && text.trim().isEmpty && media.isEmpty;

  Map<String, Object?> toJson() => {
    'v': version,
    'title': title,
    'text': text,
    'hardMoment': hardMoment,
    'media': [for (final m in media) m.toJson()],
  };

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is CapsulePayload &&
      other.title == title &&
      other.text == text &&
      other.hardMoment == hardMoment &&
      listEquals(other.media, media);

  @override
  int get hashCode =>
      Object.hash(title, text, hardMoment, Object.hashAll(media));
}

/// [text] trimmed and cut to [max] grapheme clusters (an emoji or a Telugu
/// conjunct is never split).
String clampCapsuleText(String text, int max) =>
    text.trim().characters.take(max).toString();
