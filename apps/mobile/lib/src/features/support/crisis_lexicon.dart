/// On-device crisis check (F9 L1) over notes, custom habit names and, later,
/// reflections and capsule text. Runs locally only: the text never leaves the
/// phone for classification (DS-1) and is never logged.
///
/// The words come from `contracts/safety/crisis_lexicon.v1.json` (English,
/// Telugu and Tenglish now; Hindi and Hinglish are empty until beta), bundled
/// as `crisis_lexicon_data.dart` by `tool/gen_lexicon.py`. The matching rules
/// are part of that contract (`contracts/safety/README.md`) so the NestJS
/// matcher gives the same answers; `crisis_lexicon.vectors.json` holds the
/// cases both must pass.
///
/// Newer versions arrive as signed bundles without an app release (PRD 19
/// REQ-ADM-12, `core/remote_config/remote_lexicon.dart`): only a bundle whose
/// Ed25519 signature checks out and whose own vectors pass here is
/// [CrisisLexicon.activate]d; otherwise the last verified one stays, else the
/// bundled v1. [noteNeedsSupport] and [lexiconVerdict] always use the active
/// one.
///
/// NEEDS NATIVE + SAFE-MESSAGING REVIEW (A9) before alpha.
library;

import 'package:flutter/foundation.dart';

import 'crisis_lexicon_data.dart';

/// What the lexicon found in a piece of text.
enum LexiconVerdict {
  /// Nothing from the lexicon.
  none,

  /// Only an idiom that borrows crisis words ("dying of boredom"): never the
  /// crisis sheet; a caller may offer a gentle "Help is here" card.
  soft,

  /// A high-confidence phrase: save first, then open the support sheet with
  /// the crisis wording.
  crisis,
}

/// Whether [note] needs the crisis support sheet (a [LexiconVerdict.crisis]
/// match). Used by check-in, the habits editor and history.
bool noteNeedsSupport(String note) =>
    lexiconVerdict(note) == LexiconVerdict.crisis;

/// The lexicon's verdict for [text] (see [LexiconVerdict]), with the active
/// version ([CrisisLexicon.active]).
LexiconVerdict lexiconVerdict(String text) =>
    CrisisLexicon.active.verdict(text);

/// Where the active lexicon came from.
enum LexiconSource { bundled, remote }

/// A compiled lexicon: the bundled one, compiled once on first use, or a
/// verified remote version ([CrisisLexicon.fromEntries]).
class CrisisLexicon {
  CrisisLexicon._(
    Iterable<CrisisLexiconEntry> entries, {
    required this.version,
    required this.source,
  }) {
    for (final e in entries) {
      final soft = e.kind == 'soft';
      for (final form in e.forms) {
        final n = normalizeForLexicon(form).replaceAll('\n', ' ');
        if (n.isEmpty) continue;
        if (!_ascii.hasMatch(n)) {
          // Telugu (later Devanagari): a substring.
          _scriptForms.add((text: n, soft: soft));
          continue;
        }
        // Latin: word by word, split exactly like the text.
        final words = [
          for (final m in _wordPattern.allMatches(n)) _readDigits(m[0]!),
        ];
        if (words.isEmpty) continue;
        _index(words, soft: soft, stem: e.stem);
        // Written as one word ("wanttodie", "killmyself").
        if (words.length > 1) _index([words.join()], soft: soft, stem: e.stem);
      }
    }
  }

  /// Compiled from `crisis_lexicon_data.dart`.
  static final CrisisLexicon bundled = CrisisLexicon._(
    crisisLexiconEntries,
    version: crisisLexiconVersion,
    source: LexiconSource.bundled,
  );

  /// A version that arrived as a signed bundle. Call only with entries that
  /// passed the contract checks (`remote_lexicon.dart` does both the
  /// signature and the checks before it gets here).
  factory CrisisLexicon.fromEntries(
    Iterable<CrisisLexiconEntry> entries, {
    required int version,
  }) =>
      CrisisLexicon._(entries, version: version, source: LexiconSource.remote);

  /// The lexicon version (the JSON's `version`).
  final int version;
  final LexiconSource source;

  static CrisisLexicon? _active;

  /// What [noteNeedsSupport] and [lexiconVerdict] use: the last verified
  /// remote version, else the bundled one.
  static CrisisLexicon get active => _active ?? bundled;

  /// Makes a verified remote version the active one (in memory; the verified
  /// bundle itself is kept by the remote config store for the next start).
  static void activate(CrisisLexicon lexicon) => _active = lexicon;

  /// Back to the bundled lexicon (tests).
  @visibleForTesting
  static void resetToBundled() => _active = null;

  /// Word forms by their first word (the whole form when [_Form.stem] is
  /// false or the form has more than one word).
  final Map<String, List<_Form>> _byFirstWord = {};

  /// One-word stems, matched as a prefix of any word.
  final List<_Form> _oneWordStems = [];

  /// Forms in other scripts (Telugu), matched as substrings.
  final List<({String text, bool soft})> _scriptForms = [];

  void _index(List<String> words, {required bool soft, required bool stem}) {
    final form = _Form(words, soft: soft, stem: stem);
    if (stem && words.length == 1) {
      _oneWordStems.add(form);
    } else {
      (_byFirstWord[words.first] ??= []).add(form);
    }
  }

  LexiconVerdict verdict(String text) {
    final normalized = normalizeForLexicon(text);
    if (normalized.isEmpty) return LexiconVerdict.none;
    final hits = [..._wordHits(normalized), ..._scriptHits(normalized)];
    final soft = [
      for (final h in hits)
        if (h.soft) h,
    ];
    final crisis = hits.any(
      (c) => !c.soft && !soft.any((s) => s.start < c.end && c.start < s.end),
    );
    if (crisis) return LexiconVerdict.crisis;
    return soft.isEmpty ? LexiconVerdict.none : LexiconVerdict.soft;
  }

  Iterable<_Hit> _wordHits(String normalized) sync* {
    final words = _wordPattern.allMatches(normalized).toList();
    if (words.isEmpty) return;
    final values = [for (final m in words) _readDigits(m[0]!)];

    // Whether a clause ends between word i and word i + 1.
    bool breakAfter(int i) => _clauseBreak.hasMatch(
      normalized.substring(words[i].end, words[i + 1].start),
    );

    for (var i = 0; i < values.length; i++) {
      for (final form in _byFirstWord[values[i]] ?? const <_Form>[]) {
        final n = form.words.length;
        if (i + n > values.length) continue;
        var matches = true;
        for (var k = 1; k < n && matches; k++) {
          final want = form.words[k];
          final have = values[i + k];
          matches = form.stem && k == n - 1
              ? have.startsWith(want)
              : have == want;
        }
        if (!matches) continue;
        // An idiom never spans a clause break (it would explain away the
        // crisis words of another sentence); crisis phrases may.
        if (form.soft) {
          var crossesClause = false;
          for (var k = i; k < i + n - 1; k++) {
            crossesClause = crossesClause || breakAfter(k);
          }
          if (crossesClause) continue;
        }
        yield _Hit(words[i].start, words[i + n - 1].end, soft: form.soft);
      }
      for (final form in _oneWordStems) {
        if (values[i].startsWith(form.words.single)) {
          yield _Hit(words[i].start, words[i].end, soft: form.soft);
        }
      }
    }
  }

  Iterable<_Hit> _scriptHits(String normalized) sync* {
    // Line breaks read as spaces here; offsets stay the same.
    final flat = normalized.replaceAll('\n', ' ');
    for (final form in _scriptForms) {
      for (
        var at = flat.indexOf(form.text);
        at >= 0;
        at = flat.indexOf(form.text, at + 1)
      ) {
        final end = at + form.text.length;
        if (form.soft && normalized.substring(at, end).contains('\n')) {
          continue;
        }
        yield _Hit(at, end, soft: form.soft);
      }
    }
  }

  /// A normalized form in plain Latin script: matched word by word.
  static final RegExp _ascii = RegExp(r'^[\x00-\x7F]*$');

  static final RegExp _wordPattern = RegExp('[a-z0-9]+');

  static final RegExp _clauseBreak = RegExp('[.!?;:।॥\n]');

  /// Inside a word that mixes letters and digits, digits read as the letters
  /// they stand in for (`k1ll` → `kill`, `m4rna` → `marna`).
  static String _readDigits(String word) {
    if (!_hasDigit.hasMatch(word) || !_hasLetter.hasMatch(word)) return word;
    return word.replaceAllMapped(
      _hasDigit,
      (m) => _digitLetters[m[0]] ?? m[0]!,
    );
  }

  static final RegExp _hasDigit = RegExp('[0-9]');
  static final RegExp _hasLetter = RegExp('[a-z]');
  static const Map<String, String> _digitLetters = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
  };
}

class _Form {
  _Form(this.words, {required this.soft, required this.stem});

  final List<String> words;
  final bool soft;

  /// The last word may carry suffixes (agglutinative romanized stems).
  final bool stem;
}

class _Hit {
  const _Hit(this.start, this.end, {required this.soft});

  /// Character offsets in the normalized text.
  final int start;
  final int end;
  final bool soft;
}

/// Text as the lexicon compares it (contracts/safety/README.md, "Matching"):
/// invisible format characters stripped; NFC for Latin, Devanagari and
/// Telugu; combining diacritics dropped and lower-cased; apostrophes
/// deleted; whitespace collapsed (a run with a line break becomes one line
/// break) and trimmed. The original text is never changed: this is only for
/// matching (zero-width joiners matter when Telugu is displayed).
String normalizeForLexicon(String text) {
  final runes = <int>[];
  for (final rune in text.runes) {
    if (_isInvisible(rune)) continue;
    final parts = lexiconDecompositions[rune];
    if (parts == null) {
      runes.add(rune);
    } else {
      runes.addAll(parts);
    }
  }
  _reorderMarks(runes);
  final composed = _compose(runes);
  final folded = StringBuffer();
  for (final rune in composed) {
    if (rune >= 0x0300 && rune <= 0x036F) continue; // díe → die
    if (_apostrophes.contains(rune)) continue; // can't → cant
    folded.writeCharCode(rune);
  }
  return folded
      .toString()
      .toLowerCase()
      .replaceAllMapped(
        _whitespace,
        (m) => _lineBreak.hasMatch(m[0]!) ? '\n' : ' ',
      )
      .trim();
}

final RegExp _whitespace = RegExp(r'\s+');
final RegExp _lineBreak = RegExp('[\n\r\u0085\u2028\u2029]');

const Set<int> _apostrophes = {0x0027, 0x2019, 0x2018, 0x02BC, 0x0060, 0x00B4};

/// Zero-width and other invisible format characters (README step 1.1).
bool _isInvisible(int rune) =>
    (rune >= 0x200B && rune <= 0x200F) ||
    (rune >= 0x202A && rune <= 0x202E) ||
    (rune >= 0x2060 && rune <= 0x2064) ||
    (rune >= 0x2066 && rune <= 0x2069) ||
    rune == 0xFEFF ||
    rune == 0x00AD ||
    rune == 0x180E;

int _classOf(int rune) => lexiconCombiningClasses[rune] ?? 0;

/// Canonical ordering: a stable sort of each run of combining marks by
/// combining class.
void _reorderMarks(List<int> runes) {
  for (var i = 1; i < runes.length; i++) {
    final c = _classOf(runes[i]);
    if (c == 0) continue;
    var j = i;
    while (j > 0) {
      final before = _classOf(runes[j - 1]);
      if (before <= c) break;
      final t = runes[j - 1];
      runes[j - 1] = runes[j];
      runes[j] = t;
      j--;
    }
  }
}

/// Canonical composition over decomposed, ordered text.
List<int> _compose(List<int> runes) {
  final out = <int>[];
  var starter = -1;
  var lastClass = 0;
  for (final rune in runes) {
    final c = _classOf(rune);
    if (starter >= 0) {
      final adjacent = starter == out.length - 1;
      final composite = lexiconCompositions[out[starter] << 21 | rune];
      if (composite != null &&
          (adjacent || (lastClass != 0 && lastClass < c))) {
        out[starter] = composite;
        continue;
      }
    }
    if (c == 0) starter = out.length;
    lastClass = c;
    out.add(rune);
  }
  return out;
}
