/**
 * MASVS F-2 (docs/security/masvs-l1.md) and CLAUDE.md: never log mood notes,
 * reflection text, capsule content, voice, DOB, email or tokens.
 *
 * Parses every file under src/ and inspects the arguments of Nest `Logger`
 * calls (`this.logger.warn(…)`, `Logger.log(…)`, `log.warn(…)`) and
 * `console.*`. An argument fails when:
 *  1. an interpolated or passed expression names something sensitive (a
 *     camelCase/snake_case part of an identifier is in SENSITIVE), unless it
 *     ends in a content-free member such as `.length`, `.name` or `.code`, or
 *     is wrapped in a scrubber / code extractor (SAFE_CALLS); or
 *  2. it logs raw error text (`err.message`, `err.stack`, `String(err)`,
 *     `${err}`) without `errorText()` / `scrubErrorText()`
 *     (src/common/log-scrub.ts): driver and parser messages quote input.
 * A reviewed exception goes in ALLOWLIST with its justification.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import * as ts from 'typescript';
import { errorStack, errorText, scrubErrorText } from '../../src/common/log-scrub';

const SENSITIVE = new Set([
  'note', 'notes', 'reflection', 'reflections', 'capsule', 'capsules',
  'voice', 'audio', 'recording', 'transcript',
  'dob', 'birth', 'birthday', 'birthdate',
  'email', 'emails', 'recipient', 'recipients',
  'token', 'tokens', 'jwt', 'password', 'secret', 'otp', 'code_verifier',
  'text', 'body', 'content', 'caption', 'plaintext', 'payload', 'draft',
  'path', 'paths',
]);

/** Members that never carry content, whatever they're read from. */
const SAFE_TAIL = /\.(length|size|name|code|status|kind|type|count|keyId|version|seq|action|ticket|round)$/;

/** Calls whose result is a code, a count or scrubbed text. */
const SAFE_CALLS = /^(errorText|scrubErrorText|errorStack|errCode|errorKind|mailErrorCode|pgCode|fcmCode|Object\.keys\(.*\)\.length)\b/;

/** Raw error text: `e.message`, `err?.stack`, `err.message.slice(0, 80)`, `String(err)`, a bare `err`. */
const ERR = '(e|err|error|exception|ex|reason)';
const RAW_ERROR = new RegExp(
  `^(${ERR}|String\\(${ERR}\\)|${ERR}\\??\\.toString\\(\\)|${ERR}\\??\\.(message|stack)\\b.*)$`,
);

const LOG_METHODS = new Set(['log', 'warn', 'error', 'debug', 'verbose', 'fatal', 'info']);
const LOG_TARGET = /^(this\.)?(logger|log|Logger|console|_logger)$/;

/** `path (relative to server/aura-api) :: expression` → why it is safe. */
const ALLOWLIST: Record<string, string> = {
  // Config errors name the variable, never its value (milestone-b-review §4
  // "Config errors name the variable"); the process exits right after.
  'src/main.ts :: err.message': 'bootstrap config error: names variables, never values',
  'src/main.ts :: String(err)': 'bootstrap config error: names variables, never values',
  'src/worker.ts :: err.message': 'bootstrap config error: names variables, never values',
  'src/worker.ts :: String(err)': 'bootstrap config error: names variables, never values',
  // BullMQ `worker.on('error')` and ioredis `error` events are connection and
  // Redis protocol errors (ECONNREFUSED, READONLY…); they never carry job data.
  'src/reflections/reflections.worker.ts :: err.message': 'BullMQ worker connection error',
  'src/user-mail/user-mail.worker.ts :: err.message': 'BullMQ worker connection error',
  'src/admin/paging/paging.worker.ts :: err.message': 'BullMQ worker connection error',
  'src/quiet/quiet.worker.ts :: err.message': 'BullMQ worker connection error',
  'src/ripples/ripples.worker.ts :: err.message': 'BullMQ worker connection error',
  'src/keepsakes/keepsakes.worker.ts :: err.message': 'BullMQ worker connection error',
  'src/billing/billing.worker.ts :: err.message': 'BullMQ worker connection error',
  'src/queues/worker-host.service.ts :: err.message': 'BullMQ worker connection error (the job-failed handler uses errorText)',
  'src/queues/queues.service.ts :: e.message': 'ioredis connection error',
  // `error` holds mailErrorCode(e) (src/admin/mail/mailer.ts), a fixed code.
  'src/admin/deletion-cases.service.ts :: error': 'a mailErrorCode() code, not error text',
  // OAuthError messages are fixed strings built in fcm.transport.ts.
  'src/notifications/fcm.transport.ts :: err.message': 'OAuthError: fixed message text written in this file',
};

interface Finding {
  file: string;
  line: number;
  expression: string;
  problem: string;
}

function identifierParts(expression: string): string[] {
  const parts: string[] = [];
  for (const m of expression.matchAll(/[A-Za-z_$][A-Za-z0-9_$]*/g)) {
    for (const word of m[0].replace(/\$/g, '').split('_')) {
      for (const p of word.matchAll(/[A-Z]?[a-z0-9]+|[A-Z]+(?![a-z])/g)) parts.push(p[0].toLowerCase());
    }
  }
  return parts;
}

function problem(expression: string): string | null {
  const e = expression.trim();
  if (SAFE_CALLS.test(e)) return null;
  if (RAW_ERROR.test(e)) return 'logs raw error text (it can quote input); wrap it in errorText() from src/common/log-scrub.ts';
  if (SAFE_TAIL.test(e)) return null;
  // Identifiers only: ignore the words inside string literals in the expression.
  const code = e.replace(/'[^']*'|"[^"]*"/g, "''");
  const hits = [...new Set(identifierParts(code).filter((p) => SENSITIVE.has(p)))];
  return hits.length ? `names sensitive data (${hits.join(', ')})` : null;
}

export function scanSource(file: string, source: string): { findings: Finding[]; calls: number } {
  const sf = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true);
  const findings: Finding[] = [];
  let calls = 0;

  const check = (node: ts.Expression): void => {
    const text = node.getText(sf);
    const why = problem(text);
    if (why) findings.push({ file, line: sf.getLineAndCharacterOfPosition(node.getStart(sf)).line + 1, expression: text, problem: why });
  };
  const checkArg = (arg: ts.Expression): void => {
    if (ts.isStringLiteral(arg) || ts.isNoSubstitutionTemplateLiteral(arg) || ts.isNumericLiteral(arg)) return;
    if (ts.isTemplateExpression(arg)) {
      for (const span of arg.templateSpans) checkArg(span.expression);
      return;
    }
    if (
      ts.isBinaryExpression(arg) &&
      [ts.SyntaxKind.PlusToken, ts.SyntaxKind.QuestionQuestionToken, ts.SyntaxKind.BarBarToken].includes(arg.operatorToken.kind)
    ) {
      checkArg(arg.left);
      checkArg(arg.right);
      return;
    }
    if (ts.isParenthesizedExpression(arg)) return checkArg(arg.expression);
    if (ts.isConditionalExpression(arg)) {
      // Only the branches are printed.
      checkArg(arg.whenTrue);
      checkArg(arg.whenFalse);
      return;
    }
    check(arg);
  };
  const visit = (node: ts.Node): void => {
    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression)) {
      const method = node.expression.name.text;
      const target = node.expression.expression.getText(sf);
      if (LOG_METHODS.has(method) && LOG_TARGET.test(target)) {
        calls++;
        // Nest: log(message, context) / error(message, stack, context). Every
        // argument can reach the output, so every argument is checked.
        node.arguments.forEach(checkArg);
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(sf);
  return { findings, calls };
}

function tsFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) return tsFiles(p);
    return p.endsWith('.ts') && !p.endsWith('.d.ts') ? [p] : [];
  });
}

const ALLOW_KEYS = new Set(Object.keys(ALLOWLIST));

describe('no content in logs (MASVS F-2)', () => {
  it('flags content and raw error text, passes content-free lines', () => {
    const src = `
      class X {
        run(err: Error, note: string, userEmail: string, voicePaths: string[], accessToken: string, dob: string) {
          this.logger.warn(\`sync: \${err.name}\`);
          this.logger.log(\`voice cleanup for \${voicePaths.length} object(s)\`);
          this.logger.warn(\`saved "\${note}"\`);
          Logger.log('mail to ' + userEmail, 'Mail');
          this.logger.debug(\`push token=\${accessToken}\`);
          log.warn(\`dob \${dob}\`);
          this.logger.error(\`unhandled: \${err.message}\`, err.stack);
          console.log(String(err));
          this.logger.error(\`x \${err?.message ?? String(err)}\`);
          this.logger.warn(\`job failed: \${err.message.slice(0, 80)}\`);
          this.logger.warn(\`failed: \${errorText(err)}\`);
          this.logger.warn(\`message \${message.type}\`);
        }
      }`;
    const { findings } = scanSource('fixture.ts', src);
    expect(findings.map((f) => f.expression)).toEqual([
      'note',
      'userEmail',
      'accessToken',
      'dob',
      'err.message',
      'err.stack',
      'String(err)',
      'err?.message',
      'String(err)',
      'err.message.slice(0, 80)',
    ]);
  });

  it('src/** logs no personal content, secrets or raw error text', () => {
    const root = join(__dirname, '..', '..');
    const findings: Finding[] = [];
    let calls = 0;
    for (const f of tsFiles(join(root, 'src'))) {
      const r = scanSource(relative(root, f), readFileSync(f, 'utf8'));
      findings.push(...r.findings);
      calls += r.calls;
    }
    expect(calls).toBeGreaterThan(80); // the scanner is actually matching logger calls

    const used = new Set<string>();
    const violations = findings.filter((f) => {
      const key = `${f.file} :: ${f.expression}`;
      if (ALLOW_KEYS.has(key)) {
        used.add(key);
        return false;
      }
      return true;
    });
    expect(violations.map((v) => `${v.file}:${v.line} \`${v.expression}\`: ${v.problem}`)).toEqual([]);
    expect([...ALLOW_KEYS].filter((k) => !used.has(k))).toEqual([]); // stale allowlist entries
  });
});

describe('log scrubbing (src/common/log-scrub.ts)', () => {
  it('removes quoted values and keeps quoted SQL identifiers', () => {
    expect(scrubErrorText('invalid input syntax for type uuid: "my secret note"')).toBe('invalid input syntax for type uuid: "…"');
    expect(scrubErrorText(`Unexpected token 'h', "hello there" is not valid JSON`)).toBe(`Unexpected token '…', "…" is not valid JSON`);
    expect(scrubErrorText('duplicate key value violates unique constraint "checkins_pkey"')).toBe(
      'duplicate key value violates unique constraint "checkins_pkey"',
    );
    expect(scrubErrorText('column "note_ct" of relation "checkins" does not exist')).toBe('column "note_ct" of relation "checkins" does not exist');
    expect(scrubErrorText('x'.repeat(400)).length).toBe(301);
  });

  it('errorText / errorStack scrub thrown values', () => {
    const err = new Error('value too long for type character varying(200): "dear diary"');
    expect(errorText(err)).toBe('value too long for type character varying(200): "…"');
    expect(errorStack(err)?.split('\n')[0]).toBe('Error: value too long for type character varying(200): "…"');
    expect(errorText({ note: 'x' })).toBe('non-error thrown');
    expect(errorStack('nope')).toBeUndefined();
  });
});
