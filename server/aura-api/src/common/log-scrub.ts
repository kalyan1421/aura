/**
 * MASVS F-2 / CLAUDE.md "never log mood notes, reflection text, capsule
 * content or DOB": error text from drivers and parsers can quote the value
 * that failed, e.g. Postgres `invalid input syntax for type uuid: "…"` or
 * JSON `Unexpected token 'h', "hello" is not valid JSON`. Every request body
 * is zod-validated before it reaches SQL, so this is defence in depth
 * (milestone-b-review §5.11): quoted values are replaced with `"…"` before
 * an error message or stack is logged. Quoted SQL identifiers (`relation
 * "users"`, `constraint "x_pkey"`, `column "note"`) are kept because they
 * name schema, not data. Guarded by test/unit/logs.no-content.spec.ts.
 */
const IDENTIFIER_BEFORE =
  /\b(constraint|relation|column|table|index|function|type|schema|role|database|operator|sequence|trigger|view|extension|queue|job)\s*$/i;

const WORD_CHAR = /[\p{L}\p{N}]/u;

/**
 * Quoted values (`"…"`, `` `…` ``, and `'…'` that opens a token, so apostrophes in "can't" are prose) become `"…"`,
 * whatever they hold: line breaks and escaped quotes (`"a\"b"`) included. An opening `"` or backtick that never
 * closes (a value cut off mid-message) drops the rest of the text.
 */
export function scrubErrorText(text: string, max = 300): string {
  let out = '';
  let i = 0;
  while (i < text.length) {
    const c = text[i];
    const opens = c === '"' || c === '`' || (c === "'" && (i === 0 || !WORD_CHAR.test(text[i - 1])));
    if (!opens) {
      out += c;
      i++;
      continue;
    }
    let j = i + 1;
    while (j < text.length && text[j] !== c && !(c === "'" && text[j] === '\n')) j += text[j] === '\\' ? 2 : 1;
    if (j < text.length && text[j] === c) {
      out += IDENTIFIER_BEFORE.test(out.slice(-24)) ? text.slice(i, j + 1) : `${c}…${c}`;
      i = j + 1;
    } else if (c === "'") {
      out += c; // a lone apostrophe-like quote: prose
      i++;
    } else {
      out += `${c}…`; // unclosed value: nothing after it is logged
      break;
    }
  }
  return out.length > max ? `${out.slice(0, max)}…` : out;
}

/** `scrubErrorText` for an unknown thrown value's message. */
export function errorText(err: unknown, max = 300): string {
  if (err instanceof Error) return scrubErrorText(err.message, max);
  return typeof err === 'string' ? scrubErrorText(err, max) : 'non-error thrown';
}

/** A scrubbed stack (first line carries the message), for `Logger.error`'s trace argument. */
export function errorStack(err: unknown): string | undefined {
  return err instanceof Error && err.stack ? scrubErrorText(err.stack, 4000) : undefined;
}
