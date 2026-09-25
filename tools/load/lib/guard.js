/**
 * Target guard for the Aura load harness — shared by k6 (aura-load.js) and Node (provision.mjs, run.sh via
 * guard-cli.mjs). Plain ES module, no Node or k6 APIs, so both runtimes import the same rules.
 *
 * Default: every target (Supabase URL, NestJS API URL, cleanup DB URL) must be loopback (localhost / 127.0.0.1 / ::1).
 * Staging (later): requires ALL of
 *   - `staging: true` (run.sh --staging / AURA_LOAD_STAGING=1),
 *   - `stagingAck` equal to the exact API host (AURA_LOAD_STAGING_ACK=<host>), so a typo'd or copied URL can't slip in,
 *   - an API host that carries a non-production marker (staging, stg, dev, test, preview, sandbox, qa),
 *   - a Supabase host that is loopback or listed exactly in `stagingSupabaseHosts` (AURA_LOAD_STAGING_SUPABASE_HOST),
 *   - no host that looks like production (prod / production / live / www) or is listed in `prodHosts`
 *     (AURA_LOAD_PROD_HOSTS, comma list — AK adds the production API + Supabase hosts here once they exist).
 * Anything that looks like production is refused even with every opt-in set. There is no override.
 */

const LOOPBACK = new Set(['localhost', '127.0.0.1', '::1', '[::1]']);
const PROD_MARKER = /(^|[.-])(prod|production|live|www)([.-]|$)/i;
const NONPROD_MARKER = /(^|[.-])(staging|stg|dev|test|preview|sandbox|qa)([.-]|\d|$)/i;

export class GuardError extends Error {}

/** Host of a URL (http, https, ws, wss, postgres). Throws GuardError for anything unparsable. */
export function hostOf(url) {
  if (typeof url !== 'string' || url.trim() === '') throw new GuardError('empty target URL');
  // postgres://user:pass@host:port/db and friends: take what sits between the last '@' (if any) and the next ':' '/' '?'
  const m = /^[a-z][a-z0-9+.-]*:\/\/(?:[^@/?#]*@)?(\[[^\]]+\]|[^:/?#]+)/i.exec(url.trim());
  if (!m) throw new GuardError(`not a URL: ${redact(url)}`);
  return m[1].toLowerCase();
}

export const isLoopback = (host) => LOOPBACK.has(host);

/** Never print credentials: strip user:pass@ from a URL. */
export function redact(url) {
  return String(url).replace(/\/\/[^@/]*@/, '//<credentials>@');
}

const splitList = (v) =>
  String(v ?? '')
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);

/**
 * @param {{ supabaseUrl?: string, apiUrl?: string, dbUrl?: string, staging?: boolean, stagingAck?: string,
 *           stagingSupabaseHosts?: string, prodHosts?: string }} t
 * @returns {{ mode: 'local' | 'staging', hosts: Record<string, string> }}
 */
export function assertSafeTargets(t) {
  const targets = {};
  if (t.supabaseUrl) targets.supabase = hostOf(t.supabaseUrl);
  if (t.apiUrl) targets.api = hostOf(t.apiUrl);
  if (t.dbUrl) targets.db = hostOf(t.dbUrl);
  if (Object.keys(targets).length === 0) throw new GuardError('no targets given');

  const prodHosts = new Set(splitList(t.prodHosts));
  for (const [what, host] of Object.entries(targets)) {
    if (prodHosts.has(host) || (!isLoopback(host) && PROD_MARKER.test(host))) {
      throw new GuardError(`refusing: the ${what} host "${host}" looks like PRODUCTION. The load harness never runs against production.`);
    }
  }

  const allLocal = Object.values(targets).every(isLoopback);
  if (allLocal) return { mode: 'local', hosts: targets };

  if (!t.staging) {
    const remote = Object.entries(targets)
      .filter(([, h]) => !isLoopback(h))
      .map(([w, h]) => `${w}=${h}`)
      .join(', ');
    throw new GuardError(`refusing: non-local target(s) ${remote}. Local runs only (localhost / 127.0.0.1). See tools/load/README.md "Staging".`);
  }

  // ---- staging opt-in
  const apiHost = targets.api;
  if (!apiHost) throw new GuardError('refusing: --staging needs the API URL');
  if (!isLoopback(apiHost)) {
    if (!NONPROD_MARKER.test(apiHost)) {
      throw new GuardError(`refusing: staging API host "${apiHost}" has no non-production marker (staging / stg / dev / test / preview / sandbox / qa).`);
    }
    if (String(t.stagingAck ?? '').trim().toLowerCase() !== apiHost) {
      throw new GuardError(`refusing: set AURA_LOAD_STAGING_ACK=${apiHost} (the exact staging API host) to confirm the target.`);
    }
  }
  const okSupabase = new Set(splitList(t.stagingSupabaseHosts));
  for (const what of ['supabase', 'db']) {
    const h = targets[what];
    if (!h || isLoopback(h)) continue;
    if (!okSupabase.has(h) && !NONPROD_MARKER.test(h)) {
      throw new GuardError(
        `refusing: staging ${what} host "${h}" is neither marked non-production nor listed in AURA_LOAD_STAGING_SUPABASE_HOST.`,
      );
    }
  }
  return { mode: 'staging', hosts: targets };
}

/** Run ids name every synthetic account (`load-<runid>-<n>@aura.test`); cleanup matches on them, so keep them strict. */
export const RUNID_RE = /^[a-z0-9]{4,24}$/;
export function assertRunId(runid) {
  if (!RUNID_RE.test(String(runid ?? ''))) throw new GuardError(`bad run id "${runid}": 4–24 chars [a-z0-9]`);
  return runid;
}

export const emailFor = (runid, n) => `load-${runid}-${n}@aura.test`;
