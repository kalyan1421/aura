#!/usr/bin/env node
/**
 * Turns one run folder (.runs/<runid>) into report.md: per-route latency + errors by status (from k6's CSV samples),
 * match times, realtime fan-out, DB activity / lock waits, container CPU and the hottest statements (pg_stat_statements
 * delta over the run). Zero dependencies.   node report.mjs .runs/<runid>
 */
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { gunzipSync } from 'node:zlib';

const dir = process.argv[2];
if (!dir || !existsSync(join(dir, 'summary.json'))) {
  console.error('usage: node report.mjs <run dir with summary.json>');
  process.exit(2);
}
const read = (f) => (existsSync(join(dir, f)) ? readFileSync(join(dir, f), 'utf8') : '');
const summary = JSON.parse(read('summary.json'));
const provision = read('provision.json') ? JSON.parse(read('provision.json')) : null;
const runid = dir.split('/').filter(Boolean).pop();

const pct = (sorted, p) => (sorted.length ? sorted[Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length))] : NaN);
const r0 = (v) => (Number.isFinite(v) ? Math.round(v) : '-');
const r1 = (v) => (Number.isFinite(v) ? v.toFixed(1) : '-');

function parseCsvLine(line) {
  const out = [];
  let cur = '';
  let q = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (q) {
      if (c === '"' && line[i + 1] === '"') {
        cur += '"';
        i++;
      } else if (c === '"') q = false;
      else cur += c;
    } else if (c === '"') q = true;
    else if (c === ',') {
      out.push(cur);
      cur = '';
    } else cur += c;
  }
  out.push(cur);
  return out;
}
const tagsOf = (s) => Object.fromEntries((s || '').split('&').filter(Boolean).map((kv) => kv.split('=').map(decodeURIComponent)));

// ------------------------------------------------------------------ samples.csv.gz
const routes = new Map(); // name → { d: [], statuses: Map, t0, t1 }
const apiErrs = new Map(); // `${name}|${status}|${code}` → n
const rtErrs = new Map(); // `${kind}|${detail}` → n
const rtMsgs = new Map();
const outcomes = new Map(); // `${metric}|tags` → n
let tMin = Infinity;
let tMax = -Infinity;
if (existsSync(join(dir, 'samples.csv.gz'))) {
  const text = gunzipSync(readFileSync(join(dir, 'samples.csv.gz'))).toString('utf8');
  const lines = text.split('\n');
  const head = parseCsvLine(lines[0]);
  const col = Object.fromEntries(head.map((h, i) => [h, i]));
  for (let i = 1; i < lines.length; i++) {
    if (!lines[i]) continue;
    const f = parseCsvLine(lines[i]);
    const metric = f[col.metric_name];
    const ts = Number(f[col.timestamp]);
    if (metric === 'http_req_duration') {
      const name = f[col.name] || '(unnamed)';
      const r = routes.get(name) ?? { d: [], statuses: new Map() };
      r.d.push(Number(f[col.metric_value]));
      const st = f[col.status] || '0';
      r.statuses.set(st, (r.statuses.get(st) ?? 0) + 1);
      routes.set(name, r);
      tMin = Math.min(tMin, ts);
      tMax = Math.max(tMax, ts);
    } else if (metric === 'api_errors') {
      const t = tagsOf(f[col.extra_tags]);
      const k = `${f[col.name] || t.name || '?'}|${f[col.status] || t.status || '?'}|${t.code ?? ''}`;
      apiErrs.set(k, (apiErrs.get(k) ?? 0) + Number(f[col.metric_value]));
    } else if (metric === 'rt_errors') {
      const t = tagsOf(f[col.extra_tags]);
      const k = `${t.kind ?? '?'}|${t.detail ?? ''}`;
      rtErrs.set(k, (rtErrs.get(k) ?? 0) + Number(f[col.metric_value]));
    } else if (metric === 'room_match_steps' || metric === 'ripple_start_rules' || metric === 'reflection_outcomes') {
      const t = tagsOf(f[col.extra_tags]);
      const k = `${metric}|${Object.keys(t).sort().map((x) => `${x}=${t[x]}`).join(' ')}`;
      outcomes.set(k, (outcomes.get(k) ?? 0) + Number(f[col.metric_value]));
    } else if (metric === 'rt_msgs_received') {
      const t = tagsOf(f[col.extra_tags]);
      const k = `${t.topic ?? '?'}:${t.event ?? '?'}`;
      rtMsgs.set(k, (rtMsgs.get(k) ?? 0) + Number(f[col.metric_value]));
    }
  }
}
const spanS = Number.isFinite(tMax - tMin) ? Math.max(1, tMax - tMin) : 1;

const L = [];
const m = summary.metrics;
const trendRow = (name, label, note = '') => {
  const x = m[name];
  if (!x) return;
  const v = x.values;
  L.push(`| ${label ?? name} | ${v.count} | ${r0(v.med)} | ${r0(v['p(95)'])} | ${r0(v['p(99)'])} | ${r0(v.max)} | ${note} |`);
};

L.push(`# Load run ${runid}`, '');
if (provision) {
  L.push(`Provisioned ${provision.ok}/${provision.requested} users in ${r1(provision.elapsedS)} s (concurrency ${provision.concurrency}, tz ${provision.tz}).`, '');
  L.push('| Provisioning step | n | p50 ms | p95 ms | max ms |', '|---|---|---|---|---|');
  for (const [k, s] of Object.entries(provision.steps)) L.push(`| ${k} | ${s.n} | ${s.p50} | ${s.p95} | ${s.max} |`);
  L.push('');
}

L.push('## Match time', '', '| Metric | n | p50 ms | p95 ms | p99 ms | max ms | target |', '|---|---|---|---|---|---|---|');
trendRow('room_match_ms', 'Rooms `POST /v1/rooms/match` (client-observed)', 'p95 < 800 ms (v1-rooms §1.1)');
trendRow('ripple_match_ms', 'Breath Ripples ticket → matched (polling)', 'p50 < 20 s (weeks 18–20 exit)');
trendRow('ripple_polls', 'Breath Ripples polls per match', '');
L.push('');
if (outcomes.size) {
  L.push('| Outcome | Tags | n |', '|---|---|---|');
  for (const [k, n] of [...outcomes.entries()].sort()) L.push(`| ${k.split('|').join(' | ')} | ${n} |`);
}

L.push('', '## API latency per route (client-observed, loopback)', '', '| Route | n | req/s | p50 ms | p95 ms | p99 ms | max ms | statuses |', '|---|---|---|---|---|---|---|---|');
for (const [name, r] of [...routes.entries()].sort()) {
  const s = [...r.d].sort((a, b) => a - b);
  const statuses = [...r.statuses.entries()].sort().map(([k, v]) => `${k}×${v}`).join(' ');
  L.push(`| ${name} | ${s.length} | ${r1(s.length / spanS)} | ${r0(pct(s, 50))} | ${r0(pct(s, 95))} | ${r0(pct(s, 99))} | ${r0(s[s.length - 1])} | ${statuses} |`);
}
const all = [...routes.values()].flatMap((r) => r.d).sort((a, b) => a - b);
L.push(`| **all** | ${all.length} | ${r1(all.length / spanS)} | ${r0(pct(all, 50))} | ${r0(pct(all, 95))} | ${r0(pct(all, 99))} | ${r0(all[all.length - 1])} | |`);

L.push('', '## Errors', '');
if (apiErrs.size) {
  L.push('| Route | Status | Code | n |', '|---|---|---|---|');
  for (const [k, n] of [...apiErrs.entries()].sort((a, b) => b[1] - a[1])) L.push(`| ${k.split('|').join(' | ')} | ${n} |`);
} else L.push('No API errors.');
L.push('');
if (rtErrs.size) {
  L.push('| Realtime error | Detail | n |', '|---|---|---|');
  for (const [k, n] of [...rtErrs.entries()].sort((a, b) => b[1] - a[1])) L.push(`| ${k.split('|').join(' | ')} | ${n} |`);
} else L.push('No realtime errors.');
const rate = (n) => (m[n] ? `${(m[n].values.rate * 100).toFixed(2)}%` : '-');
L.push('', `http_req_failed ${rate('http_req_failed')} · realtime join ok ${rate('rt_join_ok')} · own gesture broadcast seen within 10 s ${rate('gesture_self_delivered')}`);

L.push('', '## Realtime', '', '| Metric | n | p50 ms | p95 ms | p99 ms | max ms | meaning |', '|---|---|---|---|---|---|---|');
trendRow('rt_connect_ms', 'socket connect', 'websocket open through Kong');
trendRow('rt_join_ms', 'private channel join', 'phx_join → ok (RLS topic check)');
trendRow('fanout_gesture_self_ms', 'gesture send → own `gesture_sent`', 'POST start → sender receives the room broadcast (end to end)');
trendRow('fanout_gesture_ms', 'gesture `at` → every member', 'server accept → receipt on room:<id>');
trendRow('fanout_gesture_member_ms', 'gesture `at` → recipient member topic', 'member:<id> `gesture_received`');
trendRow('fanout_member_joined_ms', '`member_joined` fan-out', 'server accept → receipt');
trendRow('fanout_reflection_ms', '`reflection_published` fan-out', 'publish decision → receipt');
trendRow('fanout_breath_ms', 'Breath Ripples client → client', 'sender server-clock `t` → receipt (F7 budget 1.5 s)');
L.push('');
if (rtMsgs.size) {
  const total = [...rtMsgs.values()].reduce((a, b) => a + b, 0);
  L.push(`Realtime messages received: ${total} (${r1(total / spanS)}/s) — ${[...rtMsgs.entries()].sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k} ${v}`).join(' · ')}`);
}
const ws = m.ws_sessions ? m.ws_sessions.values.count : 0;
L.push(`WebSocket sessions: ${ws}.`);

// ------------------------------------------------------------------ DB + containers
const dbRows = read('db_activity.csv').split('\n').filter(Boolean).map((l) => l.split(','));
if (dbRows.length) {
  const colMax = (i) => Math.max(...dbRows.map((r) => Number(r[i]) || 0));
  const colAvg = (i) => dbRows.reduce((a, r) => a + (Number(r[i]) || 0), 0) / dbRows.length;
  L.push('', '## Postgres (pg_stat_activity, sampled every second)', '', '| | connections | active | lock waits | advisory-lock waits | row/xact lock waits | LWLock waits | idle in xact |', '|---|---|---|---|---|---|---|---|');
  L.push(`| max | ${[1, 2, 3, 4, 5, 6, 7].map(colMax).join(' | ')} |`);
  L.push(`| avg | ${[1, 2, 3, 4, 5, 6, 7].map((i) => r1(colAvg(i))).join(' | ')} |`);
}
const cRows = read('containers.csv').split('\n').filter(Boolean).map((l) => l.split(','));
if (cRows.length) {
  const by = new Map();
  for (const [, name, cpu] of cRows) {
    const v = parseFloat(String(cpu).replace('%', ''));
    if (!Number.isFinite(v)) continue;
    (by.get(name) ?? by.set(name, []).get(name)).push(v);
  }
  L.push('', '## CPU (docker stats / ps, % of one core)', '', '| Process | samples | avg % | p95 % | max % |', '|---|---|---|---|---|');
  for (const [name, xs] of [...by.entries()].sort()) {
    const s = [...xs].sort((a, b) => a - b);
    L.push(`| ${name} | ${s.length} | ${r0(s.reduce((a, b) => a + b, 0) / s.length)} | ${r0(pct(s, 95))} | ${r0(s[s.length - 1])} |`);
  }
}
const pg = (f) =>
  new Map(
    read(f)
      .split('\n')
      .filter(Boolean)
      .map((l) => {
        const [id, calls, total, rows, ...q] = l.split(',');
        return [id, { calls: Number(calls), total: Number(total), rows: Number(rows), q: q.join(',') }];
      }),
  );
const before = pg('pgss_before.csv');
const after = pg('pgss_after.csv');
if (after.size) {
  const delta = [];
  for (const [id, a] of after) {
    const b = before.get(id) ?? { calls: 0, total: 0 };
    const calls = a.calls - b.calls;
    const total = a.total - b.total;
    if (calls > 0 && total > 0) delta.push({ calls, total, mean: total / calls, q: a.q });
  }
  delta.sort((x, y) => y.total - x.total);
  const sum = delta.reduce((s, d) => s + d.total, 0);
  L.push('', '## Hottest statements during the run (pg_stat_statements delta; includes other clients of the shared DB)', '', `Total statement time in the window: ${r0(sum)} ms.`, '', '| total ms | share | calls | mean ms | statement |', '|---|---|---|---|---|');
  for (const d of delta.slice(0, 15)) L.push(`| ${r0(d.total)} | ${r1((100 * d.total) / sum)}% | ${d.calls} | ${d.mean.toFixed(2)} | \`${d.q.replace(/\|/g, '/').slice(0, 160)}\` |`);
}

const failed = Object.entries(m).filter(([, x]) => x.thresholds && Object.values(x.thresholds).some((t) => !t.ok)).map(([k]) => k);
L.push('', '## Targets', '', failed.length ? `Missed: ${failed.map((f) => `\`${f}\``).join(', ')}` : 'All thresholds met.');
writeFileSync(join(dir, 'report.md'), `${L.join('\n')}\n`);
console.log(`report: ${join(dir, 'report.md')}`);
