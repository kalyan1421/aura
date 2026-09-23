#!/usr/bin/env python3
"""Crisis lexicon -> lib/src/features/support/crisis_lexicon_data.dart
(+ the NestJS copy, server/aura-api/src/remote-config/lexicon/lexicon-contract.data.ts).

    python3 tool/gen_lexicon.py            # write both files
    python3 tool/gen_lexicon.py --check    # exit 1 if either is out of date

Reads contracts/safety/crisis_lexicon.v1.json (the reviewed source of truth,
see contracts/safety/README.md), validates it and writes a const Dart copy
plus the Unicode tables the matcher needs for NFC over Latin, Devanagari and
Telugu (Dart has no Unicode normalization of its own).

The server copy carries the same Unicode tables (so the TypeScript matcher
normalizes exactly like the app's), the baseline lexicon and the contract
vectors (crisis_lexicon.vectors.json), which every signed lexicon version
must pass before NestJS publishes it (docs/setup/lexicon-and-flags.md).

NEEDS NATIVE + SAFE-MESSAGING REVIEW (A9) before alpha.
"""
import json
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
SOURCE = os.path.join(ROOT, "contracts", "safety", "crisis_lexicon.v1.json")
VECTORS = os.path.join(ROOT, "contracts", "safety", "crisis_lexicon.vectors.json")
OUT = os.path.join(
    HERE, "..", "lib", "src", "features", "support", "crisis_lexicon_data.dart"
)
SERVER_OUT = os.path.join(
    ROOT, "server", "aura-api", "src", "remote-config", "lexicon", "lexicon-contract.data.ts"
)

LANGUAGES = {"en": "Latin", "te": "Telugu", "te-Latn": "Latin", "hi": "Devanagari", "hi-Latn": "Latin"}
KINDS = {"crisis", "soft"}
LATIN_FORM = re.compile(r"^[A-Za-z0-9 '’-]+$")
SCRIPT_RANGES = {"Telugu": (0x0C00, 0x0C7F), "Devanagari": (0x0900, 0x097F)}

# Code points whose NFC the matcher computes itself.
LATIN = range(0x00C0, 0x0250)  # Latin-1 Supplement letters .. Latin Extended-B
DEVANAGARI = range(0x0900, 0x0980)
TELUGU = range(0x0C00, 0x0C80)
COMBINING = range(0x0300, 0x0370)  # Combining Diacritical Marks


def fail(message):
    raise SystemExit(f"gen_lexicon: {message}")


def validate(data):
    if data.get("name") != "aura.crisis_lexicon":
        fail("name must be 'aura.crisis_lexicon'")
    version = data.get("version")
    if not isinstance(version, int) or version < 1:
        fail("version must be a positive integer")
    declared = data.get("languages") or {}
    if set(declared) != set(LANGUAGES):
        fail(f"languages must be exactly {sorted(LANGUAGES)}")
    entries = data.get("entries")
    if not isinstance(entries, list) or not entries:
        fail("entries must be a non-empty list")
    seen = set()
    for e in entries:
        eid = e.get("id")
        where = f"entry {eid!r}"
        if not isinstance(eid, str) or eid in seen:
            fail(f"{where}: missing or duplicate id")
        seen.add(eid)
        lang = e.get("language")
        if lang not in LANGUAGES:
            fail(f"{where}: unknown language {lang!r}")
        if not re.fullmatch(re.escape(lang) + r"\.[a-z0-9_]+", eid):
            fail(f"{where}: id must be '<language>.<snake_case>'")
        if e.get("kind") not in KINDS:
            fail(f"{where}: kind must be one of {sorted(KINDS)}")
        if not isinstance(e.get("stem", False), bool):
            fail(f"{where}: stem must be true or false")
        forms = forms_of(e)
        if len(set(forms)) != len(forms):
            fail(f"{where}: a variant repeats")
        script = LANGUAGES[lang]
        for form in forms:
            if not form.strip():
                fail(f"{where}: empty phrase or variant")
            if script == "Latin":
                if not LATIN_FORM.match(form):
                    fail(f"{where}: {form!r} is not plain Latin script")
            else:
                lo, hi = SCRIPT_RANGES[script]
                letters = [c for c in form if not c.isspace()]
                if not all(lo <= ord(c) <= hi or c == "\u200c" or c == "\u200d" for c in letters):
                    fail(f"{where}: {form!r} is not {script} script")
    return entries


def forms_of(entry):
    variants = entry.get("variants", [])
    if not isinstance(variants, list):
        fail(f"entry {entry.get('id')!r}: variants must be a list")
    return [unicodedata.normalize("NFC", entry.get("phrase") or "")] + [
        unicodedata.normalize("NFC", v) for v in variants
    ]


def dart_string(s):
    escaped = s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    return f"'{escaped}'"


def hex4(cp):
    return f"0x{cp:04X}"


def unicode_tables():
    decompositions = {}
    for cp in list(LATIN) + list(DEVANAGARI) + list(TELUGU):
        ch = chr(cp)
        nfd = unicodedata.normalize("NFD", ch)
        if nfd != ch:
            decompositions[cp] = [ord(c) for c in nfd]
    classes = {}
    for cp in list(COMBINING) + list(DEVANAGARI) + list(TELUGU):
        ccc = unicodedata.combining(chr(cp))
        if ccc:
            classes[cp] = ccc
    compositions = {}
    for cp in list(DEVANAGARI) + list(TELUGU):
        raw = unicodedata.decomposition(chr(cp))
        if not raw or raw.startswith("<"):
            continue
        parts = [int(p, 16) for p in raw.split()]
        pair = "".join(chr(p) for p in parts)
        # A primary composite: NFC puts it back together (not an exclusion).
        if len(parts) == 2 and unicodedata.normalize("NFC", pair) == chr(cp):
            compositions[(parts[0], parts[1])] = cp
    return decompositions, classes, compositions


def render(data, entries):
    decompositions, classes, compositions = unicode_tables()
    out = []
    w = out.append
    w("// GENERATED by tool/gen_lexicon.py from")
    w("// contracts/safety/crisis_lexicon.v1.json. Do not edit by hand: edit the")
    w("// JSON (see contracts/safety/README.md), then run")
    w("// `python3 tool/gen_lexicon.py` in apps/mobile.")
    w("//")
    w("// NEEDS NATIVE + SAFE-MESSAGING REVIEW (A9) before alpha.")
    w("//")
    w(f"// Unicode tables from Python's unicodedata {unicodedata.unidata_version}.")
    w("")
    w("/// Version of the bundled lexicon (the JSON's `version`).")
    w(f"const int crisisLexiconVersion = {data['version']};")
    w("")
    w("/// One lexicon entry: `forms` is the phrase, then its variants; `kind` is")
    w("/// `crisis` or `soft`.")
    w("typedef CrisisLexiconEntry = ({")
    w("  String id,")
    w("  String language,")
    w("  String kind,")
    w("  bool stem,")
    w("  List<String> forms,")
    w("});")
    w("")
    w("/// Every entry, in file order.")
    w("const List<CrisisLexiconEntry> crisisLexiconEntries = [")
    for e in entries:
        w("  (")
        w(f"    id: {dart_string(e['id'])},")
        w(f"    language: {dart_string(e['language'])},")
        w(f"    kind: {dart_string(e['kind'])},")
        w(f"    stem: {'true' if e.get('stem', False) else 'false'},")
        # As `dart format` lays it out: one line when it fits in 80 columns.
        items = [dart_string(form) for form in forms_of(e)]
        one_line = f"    forms: [{', '.join(items)}],"
        if len(one_line) <= 80:
            w(one_line)
        else:
            w("    forms: [")
            for item in items:
                w(f"      {item},")
            w("    ],")
        w("  ),")
    w("];")
    w("")
    w("/// Canonical (NFD) decompositions of the Latin, Devanagari and Telugu")
    w("/// characters that have one.")
    w("const Map<int, List<int>> lexiconDecompositions = {")
    for cp, parts in sorted(decompositions.items()):
        w(f"  {hex4(cp)}: [{', '.join(hex4(p) for p in parts)}],")
    w("};")
    w("")
    w("/// Non-zero canonical combining classes (combining diacritics,")
    w("/// Devanagari, Telugu).")
    w("const Map<int, int> lexiconCombiningClasses = {")
    for cp, ccc in sorted(classes.items()):
        w(f"  {hex4(cp)}: {ccc},")
    w("};")
    w("")
    w("/// Canonical compositions (Devanagari, Telugu), keyed")
    w("/// `first << 21 | second`; composition exclusions are left out.")
    w("const Map<int, int> lexiconCompositions = {")
    for (a, b), cp in sorted(compositions.items()):
        w(f"  {hex4(a)} << 21 | {hex4(b)}: {hex4(cp)},")
    w("};")
    return "\n".join(out) + "\n"


def ts_hex(cp):
    return f"0x{cp:04x}"


def render_ts(data, vectors):
    """The NestJS copy: Unicode tables, baseline lexicon, contract vectors.

    JSON is emitted ASCII-only (\\uXXXX escapes), so the invisible and bidi
    characters of the vectors never appear raw in the TypeScript source.
    """
    decompositions, classes, compositions = unicode_tables()
    out = []
    w = out.append
    w("// GENERATED by apps/mobile/tool/gen_lexicon.py from contracts/safety")
    w("// (crisis_lexicon.v1.json, crisis_lexicon.vectors.json). Do not edit by hand:")
    w("// edit the JSON (see contracts/safety/README.md), then run")
    w("// `python3 tool/gen_lexicon.py` in apps/mobile.")
    w("//")
    w("// NEEDS NATIVE + SAFE-MESSAGING REVIEW (A9) before alpha.")
    w("//")
    w(f"// Unicode tables from Python's unicodedata {unicodedata.unidata_version} (the same as the app's).")
    w("")
    w("/** contracts/safety/crisis_lexicon.v1.json: the baseline lexicon every app build bundles. */")
    w(f"export const BASELINE_LEXICON: unknown = {json.dumps(data, ensure_ascii=True, indent=2)};")
    w("")
    w("/** contracts/safety/crisis_lexicon.vectors.json: every published version must pass these. */")
    w(f"export const CONTRACT_VECTORS: unknown = {json.dumps(vectors, ensure_ascii=True, indent=2)};")
    w("")
    w("/** Canonical (NFD) decompositions of the Latin, Devanagari and Telugu characters that have one. */")
    w("export const LEXICON_DECOMPOSITIONS: ReadonlyMap<number, readonly number[]> = new Map<number, readonly number[]>([")
    for cp, parts in sorted(decompositions.items()):
        w(f"  [{ts_hex(cp)}, [{', '.join(ts_hex(p) for p in parts)}]],")
    w("]);")
    w("")
    w("/** Non-zero canonical combining classes (combining diacritics, Devanagari, Telugu). */")
    w("export const LEXICON_COMBINING_CLASSES: ReadonlyMap<number, number> = new Map<number, number>([")
    for cp, ccc in sorted(classes.items()):
        w(f"  [{ts_hex(cp)}, {ccc}],")
    w("]);")
    w("")
    w("/** Canonical compositions (Devanagari, Telugu), keyed `first * 0x200000 + second`; exclusions left out. */")
    w("export const LEXICON_COMPOSITIONS: ReadonlyMap<number, number> = new Map<number, number>([")
    for (a, b), cp in sorted(compositions.items()):
        w(f"  [{ts_hex(a)} * 0x200000 + {ts_hex(b)}, {ts_hex(cp)}],")
    w("]);")
    return "\n".join(out) + "\n"


def stale(path, text):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read() != text
    except FileNotFoundError:
        return True


def main():
    check = "--check" in sys.argv[1:]
    with open(SOURCE, encoding="utf-8") as f:
        data = json.load(f)
    with open(VECTORS, encoding="utf-8") as f:
        vectors = json.load(f)
    entries = validate(data)
    text = render(data, entries)
    server_text = render_ts(data, vectors)
    if check:
        if stale(OUT, text):
            print("gen_lexicon: crisis_lexicon_data.dart is out of date; run tool/gen_lexicon.py")
            sys.exit(1)
        if stale(SERVER_OUT, server_text):
            print("gen_lexicon: lexicon-contract.data.ts (server) is out of date; run tool/gen_lexicon.py")
            sys.exit(1)
        print("gen_lexicon: up to date")
        return
    for path, content in ((OUT, text), (SERVER_OUT, server_text)):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(content)
    crisis = sum(1 for e in entries if e["kind"] == "crisis")
    print(
        f"gen_lexicon: v{data['version']}, {len(entries)} entries "
        f"({crisis} crisis, {len(entries) - crisis} soft) -> {os.path.relpath(OUT, ROOT)}, "
        f"{os.path.relpath(SERVER_OUT, ROOT)}"
    )


if __name__ == "__main__":
    main()
