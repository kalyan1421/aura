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

const QUOTED = /"([^"\n]*)"|'([^'\n]*)'|`([^`\n]*)`/g;

export function scrubErrorText(text: string, max = 300): string {
  const out = text.replace(QUOTED, (match: string, _d: string, _s: string, _b: string, offset: number, whole: string) => {
    const before = whole.slice(Math.max(0, offset - 24), offset);
    if (IDENTIFIER_BEFORE.test(before)) return match;
    const q = match[0];
    return `${q}…${q}`;
  });
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
