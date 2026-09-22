/// On-device crisis check for notes (F9 L1). Runs locally only; note text
/// never leaves the phone for classification (DS-1).
///
/// TODO(F9): replace this seed list with the versioned, signed lexicon bundle
/// (English, Telugu, Tenglish, Hindi, Hinglish incl. transliteration variants,
/// idiom → soft card, NFC normalisation). These are a few high-confidence
/// phrases only. NEEDS NATIVE REVIEW + safe-messaging review before alpha.
bool noteNeedsSupport(String note) {
  final n = note
      .toLowerCase()
      .replaceAll(RegExp('[​-‍﻿]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  return _phrases.any(n.contains);
}

const List<String> _phrases = [
  // English
  'kill myself', 'end my life', 'suicide', 'want to die', 'better off dead',
  'no reason to live', 'hurt myself',
  // Tenglish (romanised Telugu)
  'chachipovalani', 'chanipovalani', 'sachipovali', 'chachipotha',
  'atmahatya', 'aatmahatya',
  // Telugu
  'చచ్చిపోవాలని', 'చనిపోవాలని', 'ఆత్మహత్య',
];
