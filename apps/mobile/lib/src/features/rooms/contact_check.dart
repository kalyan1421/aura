/// On-device check for contact details in the one free-text field of the
/// room flows (the optional report note, F9 stage 1): phone numbers (spaced,
/// dashed, +91, Telugu or Devanagari digits), emails and UPI ids, links and
/// @handles. Runs locally; the text is never logged. Naming an app
/// ("he asked for my insta") is fine: that is what a moderator needs to
/// know. Numbers spelled out in words are the lexicon's job (F6).
bool containsContactDetails(String text) {
  final t = _asciiDigits(text.toLowerCase());
  if (_emailOrUpi.hasMatch(t)) return true;
  if (_link.hasMatch(t)) return true;
  if (_handle.hasMatch(t)) return true;
  for (final m in _digitRun.allMatches(t)) {
    if (m[0]!.replaceAll(RegExp(r'\D'), '').length >= 7) return true;
  }
  return false;
}

/// name@bank (UPI) and name@mail.com.
final RegExp _emailOrUpi = RegExp(r'[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*');

final RegExp _link = RegExp(
  r'(https?://|www\.)|\b[a-z0-9-]+\.(com|in|net|org|io|me|co|app|ly|gg|link|xyz|info)\b',
);

/// "@quietcomet" (not an email: nothing word-like right before the @).
final RegExp _handle = RegExp(r'(^|[^a-z0-9._%+-])@[a-z0-9_.]{2,}');

/// Digits with the separators people put between them.
final RegExp _digitRun = RegExp(r'\+?\d[\d\s().\-/]{5,}\d');

/// Telugu (౦–౯) and Devanagari (०–९) digits read as 0–9.
String _asciiDigits(String s) {
  final out = StringBuffer();
  for (final rune in s.runes) {
    if (rune >= 0x0C66 && rune <= 0x0C6F) {
      out.writeCharCode(0x30 + rune - 0x0C66);
    } else if (rune >= 0x0966 && rune <= 0x096F) {
      out.writeCharCode(0x30 + rune - 0x0966);
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}
