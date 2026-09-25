/**
 * Aura realtime load test (k6). Milestone B hardening, PRD 20-timeline weeks 28–29 ("Beta hardening: realtime load
 * test"), weeks 18–20 exit ("p50 match < 20 s"), 09-technical-constraints (Realtime budget, API p95 < 300 ms).
 *
 * Every virtual user is one synthetic account from provision.mjs (`<RUN_DIR>/users.json`) and behaves like the app:
 *
 *  rooms   (contracts/api/v1-rooms.md, v1-reflections.md) — a matching burst (`POST /v1/rooms/match` within
 *          ROOM_BURST_S), then one socket with the two private Broadcast topics `room:<roomId>` + `member:<memberId>`,
 *          the detail + reflections refetch after subscribing, a heartbeat every HEARTBEAT_S (45 s in the app),
 *          gestures (room / member targets, inside the server limits) and, for 1 in REFLECT_EVERY users, one
 *          reflection; finally `leave`. Measures match time, join time, and fan-out: server `at` → receipt at every
 *          other member, and send → the sender's own receipt of its `gesture_sent` (skew-free end-to-end).
 *  ripples (contracts/api/v1-ripples.md) — Breath Ripples quick-match: client ticket (UUIDv7), poll at `pollAfterMs`
 *          until `matched`, then `game:<sessionId>` (Broadcast + Presence): track `{seat}`, `breath_state` at the
 *          pacer's transitions, `heartbeat` when idle 2 s, the odd `pulse`; leave after PLAY_S; re-queue until the end.
 *          Measures match time (ticket → matched, the "< 20 s" exit criterion), start rule, and client→client fan-out.
 *  burst   HTTP-only matching burst (no socket): match → detail → heartbeat → leave, for scale beyond the socket cap.
 *
 * Run through run.sh (guards, own API on :3323 + mock moderation, provisioning, cleanup). Direct use:
 *   k6 run -e RUN_DIR=$PWD/.runs/<id> -e SUPABASE_URL=… -e API_URL=… -e SUPABASE_ANON_KEY=… aura-load.js
 */
import http from 'k6/http';
import exec from 'k6/execution';
import { SharedArray } from 'k6/data';
import { Counter, Rate, Trend } from 'k6/metrics';
import { setTimeout } from 'k6/timers';
import { assertSafeTargets } from './lib/guard.js';
import { PhoenixSocket } from './lib/phoenix.js';
import { uuidv7 } from './lib/uuid.js';

// ------------------------------------------------------------------ config
const E = __ENV;
const num = (k, d) => (E[k] === undefined || E[k] === '' ? d : Number(E[k]));
const RUN_DIR = E.RUN_DIR;
const RUNID = E.RUNID || 'adhoc';
const SUPABASE_URL = (E.SUPABASE_URL || 'http://127.0.0.1:55521').replace(/\/+$/, '');
const API_URL = (E.API_URL || 'http://127.0.0.1:3323').replace(/\/+$/, '');
const ANON = E.SUPABASE_ANON_KEY || '';
const TZ = E.LOAD_TZ || 'Asia/Kolkata';

const ROOMS_VUS = num('ROOMS_VUS', 30);
const RIPPLES_VUS = num('RIPPLES_VUS', 16);
const BURST_VUS = num('BURST_VUS', 0);
const DURATION_S = num('DURATION_S', 120); // how long each rooms / ripples user stays active
const ROOM_BURST_S = num('ROOM_BURST_S', 10); // rooms users all match within this window
const RIPPLE_RAMP_S = num('RIPPLE_RAMP_S', 10);
const BURST_START_S = num('BURST_START_S', 30);
const BURST_WINDOW_S = num('BURST_WINDOW_S', 10);
const HEARTBEAT_S = num('HEARTBEAT_S', 45);
const GESTURE_MIN_S = Math.max(2.5, num('GESTURE_MIN_S', 12)); // server: ≥ 2 s apart per account
const GESTURE_MAX_S = Math.max(GESTURE_MIN_S, num('GESTURE_MAX_S', 30));
const GESTURE_CAP = Math.min(30, num('GESTURE_CAP', 12)); // server: ≤ 40 per room per hour → never a limit hit
const REFLECTIONS = E.REFLECTIONS !== '0';
const REFLECT_EVERY = Math.max(1, num('REFLECT_EVERY', 3));
const PLAY_S = num('PLAY_S', 45);
const RT_MAX_SOCKETS = num('RT_MAX_SOCKETS', 150);
const QUADS = (E.QUADRANTS || 'storm,rain,moonlight,sunrise').split(',').map((s) => s.trim()).filter(Boolean);

const MOODS = {
  storm: ['anxious', 'frustrated', 'overwhelmed', 'restless'],
  rain: ['lonely', 'melancholy', 'numb', 'drained'],
  moonlight: ['calm', 'content', 'grateful', 'quietly_hopeful'],
  sunrise: ['joyful', 'excited', 'proud', 'energised'],
};
const ROOM_GESTURES = ['warm_tea', 'light_a_candle', 'hug', 'me_too', 'soft_rain', 'stargaze', 'deep_breath', 'youre_not_alone'];
const RIPPLE_GESTURES = ['hug', 'deep_breath', 'youre_not_alone'];

// Guard in the script too (defence in depth: run.sh checks first). Throws → k6 refuses to start.
assertSafeTargets({
  supabaseUrl: SUPABASE_URL,
  apiUrl: API_URL,
  staging: E.AURA_LOAD_STAGING === '1',
  stagingAck: E.AURA_LOAD_STAGING_ACK,
  stagingSupabaseHosts: E.AURA_LOAD_STAGING_SUPABASE_HOST,
  prodHosts: E.AURA_LOAD_PROD_HOSTS,
});
if (!RUN_DIR) throw new Error('RUN_DIR is required (the folder with users.json from provision.mjs)');
if (ROOMS_VUS + RIPPLES_VUS > RT_MAX_SOCKETS) {
  throw new Error(`ROOMS_VUS + RIPPLES_VUS = ${ROOMS_VUS + RIPPLES_VUS} sockets > RT_MAX_SOCKETS ${RT_MAX_SOCKETS} (local Realtime tenant allows 200 for everyone)`);
}

const users = new SharedArray('users', () => JSON.parse(open(`${RUN_DIR}/users.json`)));
const WS_URL = `${SUPABASE_URL.replace(/^http/, 'ws')}/realtime/v1/websocket?apikey=${encodeURIComponent(ANON)}&vsn=1.0.0`;

// ------------------------------------------------------------------ metrics
const roomMatchMs = new Trend('room_match_ms', true);
const rippleMatchMs = new Trend('ripple_match_ms', true);
const ripplePolls = new Trend('ripple_polls');
const rtConnectMs = new Trend('rt_connect_ms', true);
const rtJoinMs = new Trend('rt_join_ms', true);
const fanoutGestureMs = new Trend('fanout_gesture_ms', true); // server `at` → receipt at another member (room topic)
const fanoutGestureSelfMs = new Trend('fanout_gesture_self_ms', true); // POST start → sender's own gesture_sent
const fanoutGestureMemberMs = new Trend('fanout_gesture_member_ms', true); // `at` → recipient's member topic
const fanoutJoinedMs = new Trend('fanout_member_joined_ms', true);
const fanoutReflectionMs = new Trend('fanout_reflection_ms', true);
const fanoutBreathMs = new Trend('fanout_breath_ms', true); // client → client on game:<id>, server-clock `t`
const gestureSelfDelivered = new Rate('gesture_self_delivered'); // own gesture_sent seen within 10 s
const rtJoinOk = new Rate('rt_join_ok');
const rtErrors = new Counter('rt_errors');
const rtMsgs = new Counter('rt_msgs_received');
const apiErrors = new Counter('api_errors');
const matchSteps = new Counter('room_match_steps');
const rippleRules = new Counter('ripple_start_rules');
const reflectionOutcomes = new Counter('reflection_outcomes');
const vuExceptions = new Counter('vu_exceptions');

// ------------------------------------------------------------------ options
const scenarios = {};
const flowMax = (extra) => `${Math.ceil(extra + DURATION_S + 90)}s`;
if (ROOMS_VUS > 0) scenarios.rooms = { executor: 'per-vu-iterations', exec: 'roomsFlow', vus: ROOMS_VUS, iterations: 1, maxDuration: flowMax(ROOM_BURST_S), gracefulStop: '30s' };
if (RIPPLES_VUS > 0) scenarios.ripples = { executor: 'per-vu-iterations', exec: 'ripplesFlow', vus: RIPPLES_VUS, iterations: 1, maxDuration: flowMax(RIPPLE_RAMP_S), gracefulStop: '30s' };
if (BURST_VUS > 0) scenarios.burst = { executor: 'per-vu-iterations', exec: 'burstFlow', vus: BURST_VUS, iterations: 1, startTime: `${BURST_START_S}s`, maxDuration: `${BURST_WINDOW_S + 120}s`, gracefulStop: '30s' };

const ROUTES = [
  'POST /v1/rooms/match',
  'GET /v1/rooms/:id',
  'POST /v1/rooms/:id/heartbeat',
  'POST /v1/rooms/:id/gestures',
  'GET /v1/rooms/:id/reflections',
  'POST /v1/rooms/:id/reflections',
  'POST /v1/rooms/:id/leave',
  'POST /v1/ripples/match',
  'GET /v1/ripples/sessions/:id',
  'POST /v1/ripples/sessions/:id/leave',
];
const thresholds = {
  // PRD 09: API p95 < 300 ms (from India; this is loopback, so it is a floor, not a verdict on Mumbai).
  http_req_failed: ['rate<0.01'],
  // v1-rooms.md §1.1: match p95 target 800 ms. 20-timeline weeks 18–20: Breath Ripples p50 match < 20 s.
  room_match_ms: ['p(95)<800'],
  ripple_match_ms: ['p(50)<20000'],
  // F7: Breath Ripples tolerates up to 1.5 s one-way delay.
  fanout_breath_ms: ['p(95)<1500'],
  rt_join_ok: ['rate>0.99'],
};
for (const r of ROUTES) {
  // v1-reflections.md: publish p50 < 2 s (server waits ≤ 1.8 s for moderation); everything else: API p95 < 300 ms.
  thresholds[`http_req_duration{name:${r}}`] = r === 'POST /v1/rooms/:id/reflections' ? ['p(50)<2000'] : ['p(95)<300'];
  thresholds[`api_errors{name:${r}}`] = ['count>=0']; // makes a per-route error sub-metric appear in the summary
}

export const options = {
  scenarios,
  thresholds,
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max', 'count'],
  systemTags: ['name', 'status', 'method', 'scenario', 'error_code', 'expected_response'],
  discardResponseBodies: false,
  setupTimeout: '30s',
};

// ------------------------------------------------------------------ helpers
const sleepMs = (ms) => new Promise((r) => setTimeout(r, Math.max(0, ms)));
const rand = (a, b) => a + Math.random() * (b - a);
const pick = (xs) => xs[Math.floor(Math.random() * xs.length)];

async function call(u, method, path, body, name) {
  const params = {
    headers: { Authorization: `Bearer ${u.token}`, 'Content-Type': 'application/json' },
    tags: { name },
    timeout: '30s',
  };
  const res = await http.asyncRequest(method, `${API_URL}${path}`, body === undefined ? null : JSON.stringify(body), params);
  let json = null;
  if (res.body && typeof res.body === 'string' && res.body.length) {
    try {
      json = JSON.parse(res.body);
    } catch (_) {
      json = null;
    }
  }
  if (res.status < 200 || res.status >= 300) {
    const code = json && json.code ? json.code : res.status === 0 ? 'network' : 'http';
    apiErrors.add(1, { name, status: String(res.status), code });
  }
  return { status: res.status, json, ms: res.timings.duration };
}

function userAt(offset, scenarioName) {
  const idx = exec.scenario.iterationInTest;
  const u = users[offset + idx];
  if (!u) throw new Error(`${scenarioName}: no provisioned user #${offset + idx} (users.json has ${users.length})`);
  if (u.expiresAt && u.expiresAt < Date.now() + 60000) throw new Error('access token expired: provision again (tokens live 1 h)');
  return { u, idx };
}

// Benign, digit-free, unique texts (digits could read as contact details; the same text in > 2 rooms is held).
const W1 = ['quiet', 'slow', 'soft', 'gentle', 'long', 'cool', 'warm', 'grey', 'late', 'still', 'calm', 'bright'];
const W2 = ['evening', 'rain', 'walk', 'tea', 'morning', 'sky', 'breeze', 'window', 'garden', 'river', 'moon', 'street'];
const W3 = ['today', 'tonight', 'again', 'at last', 'for a while', 'somehow', 'after all', 'finally'];
const reflectionText = () => `a ${pick(W1)} ${pick(W2)} and a ${pick(W1)} ${pick(W2)} ${pick(W3)}, breathing ${pick(W1)} ${pick(W2)} ${pick(W3)}`;

// ------------------------------------------------------------------ rooms
export async function roomsFlow() {
  const { u, idx } = userAt(0, 'rooms');
  const quadrant = QUADS[idx % QUADS.length];
  const moodId = MOODS[quadrant][Math.floor(idx / QUADS.length) % 4];
  await sleepMs(rand(0, ROOM_BURST_S * 1000));

  const t0 = Date.now();
  const m = await call(u, 'POST', '/v1/rooms/match', { quadrant, moodId, timezone: TZ }, 'POST /v1/rooms/match');
  if (m.status !== 200 || !m.json) return;
  roomMatchMs.add(Date.now() - t0);
  matchSteps.add(1, { step: String(m.json.match.step), created: String(m.json.match.created), merged: String(m.json.match.merged) });

  const roomId = m.json.room.roomId;
  const memberId = m.json.me.memberId;
  const roomTopic = m.json.realtime.roomTopic;
  const memberTopic = m.json.realtime.memberTopic;
  const others = new Set(m.json.members.filter((x) => !x.isMe).map((x) => x.memberId));
  const mine = new Map(); // gestureId → POST start (ms)
  const early = new Map(); // gestureId → receipt before the POST answered
  let inflight = 0;

  const sock = new PhoenixSocket(WS_URL, {
    onBroadcast(topic, event, p, recv) {
      rtMsgs.add(1, { topic: topic.split(':')[0], event });
      const at = typeof p.at === 'string' ? Date.parse(p.at) : NaN;
      if (event === 'gesture_sent') {
        if (!Number.isNaN(at)) fanoutGestureMs.add(recv - at); // every subscriber, the sender included
        if (mine.has(p.gestureId)) {
          fanoutGestureSelfMs.add(recv - mine.get(p.gestureId));
          mine.delete(p.gestureId);
        } else if (inflight > 0) {
          early.set(p.gestureId, recv); // may be ours: the broadcast can beat the HTTP answer
        }
      } else if (event === 'gesture_received' && !Number.isNaN(at)) {
        fanoutGestureMemberMs.add(recv - at);
      } else if (event === 'member_joined') {
        if (p.member && p.member.memberId && p.member.memberId !== memberId) others.add(p.member.memberId);
        if (!Number.isNaN(at)) fanoutJoinedMs.add(recv - at);
      } else if (event === 'member_left') {
        others.delete(p.memberId);
      } else if (event === 'reflection_published' && !Number.isNaN(at)) {
        fanoutReflectionMs.add(recv - at);
      }
    },
    onError(kind, detail) {
      rtErrors.add(1, { kind, detail: String(detail).slice(0, 40) });
    },
  });

  let live = false;
  try {
    rtConnectMs.add(await sock.connect());
    live = true;
  } catch (e) {
    rtJoinOk.add(false);
    rtErrors.add(1, { kind: 'connect', detail: String(e.message || e).slice(0, 40) });
  }
  if (live) {
    for (const topic of [roomTopic, memberTopic]) {
      const j = await sock.join(topic, u.token);
      rtJoinOk.add(j.status === 'ok');
      if (j.status === 'ok') rtJoinMs.add(j.ms);
      else rtErrors.add(1, { kind: 'join_refused', detail: String(j.response.reason || j.status).slice(0, 40) });
    }
  }
  // The app refetches the detail after (re)subscribing (v1-rooms.md §3) and loads the reflections section.
  await call(u, 'GET', `/v1/rooms/${roomId}`, undefined, 'GET /v1/rooms/:id');
  await call(u, 'GET', `/v1/rooms/${roomId}/reflections`, undefined, 'GET /v1/rooms/:id/reflections');

  const end = Date.now() + DURATION_S * 1000;
  let nextHeartbeat = Date.now() + rand(0.2, 1) * HEARTBEAT_S * 1000;
  let nextGesture = Date.now() + rand(GESTURE_MIN_S, GESTURE_MAX_S) * 1000;
  let nextReflection = REFLECTIONS && idx % REFLECT_EVERY === 0 ? Date.now() + rand(0.1, 0.8) * DURATION_S * 1000 : Infinity;
  let gestures = 0;
  const perTarget = new Map(); // `${type}|${member}` → count (server: same gesture to the same member ≤ 3 / 10 min)

  while (Date.now() < end) {
    const wake = Math.min(nextHeartbeat, nextGesture, nextReflection, end);
    await sleepMs(wake - Date.now());
    const now = Date.now();
    if (now >= end) break;

    if (now >= nextHeartbeat) {
      await call(u, 'POST', `/v1/rooms/${roomId}/heartbeat`, {}, 'POST /v1/rooms/:id/heartbeat');
      nextHeartbeat = Date.now() + HEARTBEAT_S * 1000;
    }
    if (now >= nextGesture) {
      nextGesture = Date.now() + rand(GESTURE_MIN_S, GESTURE_MAX_S) * 1000;
      if (gestures < GESTURE_CAP) {
        const type = pick(ROOM_GESTURES);
        const candidates = [...others].filter((x) => (perTarget.get(`${type}|${x}`) || 0) < 3);
        const body = candidates.length && Math.random() < 0.4 ? { type, target: 'member', toMemberId: pick(candidates) } : { type, target: 'room' };
        const sentAt = Date.now();
        inflight += 1;
        const g = await call(u, 'POST', `/v1/rooms/${roomId}/gestures`, body, 'POST /v1/rooms/:id/gestures');
        inflight -= 1;
        gestures += 1;
        if (body.toMemberId) perTarget.set(`${type}|${body.toMemberId}`, (perTarget.get(`${type}|${body.toMemberId}`) || 0) + 1);
        if (g.status === 202 && g.json && g.json.gestureId && live) {
          const gid = g.json.gestureId;
          if (early.has(gid)) {
            fanoutGestureSelfMs.add(early.get(gid) - sentAt); // the broadcast beat the HTTP answer
            early.delete(gid);
            gestureSelfDelivered.add(true);
            early.clear();
          } else {
            early.clear();
            mine.set(gid, sentAt);
            setTimeout(() => {
              if (mine.has(gid)) {
                mine.delete(gid);
                gestureSelfDelivered.add(false);
              } else gestureSelfDelivered.add(true);
            }, 10000);
          }
        }
      }
    }
    if (now >= nextReflection) {
      nextReflection = Infinity;
      const r = await call(u, 'POST', `/v1/rooms/${roomId}/reflections`, { reflectionId: uuidv7(), text: reflectionText() }, 'POST /v1/rooms/:id/reflections');
      const status = r.json && r.json.status ? r.json.status : `http_${r.status}`;
      reflectionOutcomes.add(1, { outcome: status, reason: r.json && r.json.rejectReason ? r.json.rejectReason : r.json && r.json.code ? r.json.code : '' });
      if (status === 'held') {
        // No working moderation provider behind this API (fail-closed hold). Held items count toward the pool kill
        // switch (reflection_config.auto_pause_held) for everyone on this stack: stop the whole run at once.
        exec.test.abort('reflection came back "held": the API has no moderation provider (use run.sh, which starts the mock), aborting to protect the auto-pause kill switch');
      }
      await call(u, 'GET', `/v1/rooms/${roomId}/reflections`, undefined, 'GET /v1/rooms/:id/reflections');
    }
  }

  await sleepMs(1500); // let the last gesture broadcasts land
  await call(u, 'POST', `/v1/rooms/${roomId}/leave`, {}, 'POST /v1/rooms/:id/leave');
  if (live) {
    sock.leave(roomTopic);
    sock.leave(memberTopic);
  }
  sock.close();
}

// ------------------------------------------------------------------ ripples
export async function ripplesFlow() {
  const { u } = userAt(ROOMS_VUS, 'ripples');
  await sleepMs(rand(0, RIPPLE_RAMP_S * 1000));
  const end = Date.now() + DURATION_S * 1000;

  while (Date.now() < end - 25000) {
    try {
      await oneRipple(u);
    } catch (e) {
      vuExceptions.add(1, { flow: 'ripples' });
    }
    await sleepMs(rand(1000, 5000));
  }
}

async function oneRipple(u) {
  const ticketId = uuidv7();
  const t0 = Date.now();
  let session = null;
  let offset = 0; // server clock − local clock, from the matched answer (the app keeps the shortest round trip)
  let polls = 0;
  for (;;) {
    const sent = Date.now();
    const r = await call(u, 'POST', '/v1/ripples/match', { ticketId, entry: 'quick' }, 'POST /v1/ripples/match');
    polls += 1;
    if (r.status !== 200 || !r.json) {
      await sleepMs(2000);
      if (Date.now() - t0 > 60000) return;
      continue;
    }
    if (r.json.status === 'matched') {
      session = r.json.session;
      offset = r.json.serverTimeMs - (sent + Date.now()) / 2;
      break;
    }
    if (Date.now() - t0 > 60000) {
      rtErrors.add(1, { kind: 'ripple_match_timeout', detail: '' });
      await call(u, 'DELETE', `/v1/ripples/match/${ticketId}`, undefined, 'DELETE /v1/ripples/match/:id');
      return;
    }
    await sleepMs(Math.min(5000, Math.max(250, r.json.pollAfterMs || 2000)));
  }
  rippleMatchMs.add(Date.now() - t0, { rule: session.startRule });
  ripplePolls.add(polls);
  rippleRules.add(1, { rule: session.startRule, humans: String(session.humans) });

  const seat = session.mySeat;
  const topic = session.realtime.topic;
  const serverNow = () => Date.now() + offset;
  let lastSent = 0;
  const sock = new PhoenixSocket(WS_URL, {
    onBroadcast(tp, event, p, recv) {
      rtMsgs.add(1, { topic: tp.split(':')[0], event });
      if ((event === 'breath_state' || event === 'pulse' || event === 'heartbeat' || event === 'gesture') && p.seat !== seat && typeof p.t === 'number') {
        fanoutBreathMs.add(recv + offset - p.t, { event });
      }
    },
    onError(kind, detail) {
      rtErrors.add(1, { kind, detail: String(detail).slice(0, 40) });
    },
  });
  let live = false;
  try {
    rtConnectMs.add(await sock.connect());
    const j = await sock.join(topic, u.token, { presenceKey: String(seat) });
    rtJoinOk.add(j.status === 'ok');
    if (j.status === 'ok') {
      rtJoinMs.add(j.ms);
      live = true;
      sock.track(topic, { seat });
    } else rtErrors.add(1, { kind: 'join_refused', detail: String(j.response.reason || j.status).slice(0, 40) });
  } catch (e) {
    rtJoinOk.add(false);
    rtErrors.add(1, { kind: 'connect', detail: String(e.message || e).slice(0, 40) });
  }
  await call(u, 'GET', `/v1/ripples/sessions/${session.sessionId}`, undefined, 'GET /v1/ripples/sessions/:id');

  const send = (event, payload) => {
    if (!live) return;
    sock.broadcast(topic, event, Object.assign({ seat, t: Math.round(serverNow()) }, payload));
    lastSent = Date.now();
  };
  // Pacer transitions (server clock): inhale at t0 + settle + k·(in+out), exhale inhaleMs later.
  const cycleMs = session.inhaleMs + session.exhaleMs;
  const transitions = [];
  for (let k = 0; k < session.cycles; k++) {
    const start = session.t0Ms + session.settleMs + k * cycleMs;
    transitions.push({ at: start, phase: 'in' }, { at: start + session.inhaleMs, phase: 'out' });
  }
  const stopAt = Math.min(Date.now() + PLAY_S * 1000, session.endsAtMs - offset);
  let ti = transitions.findIndex((x) => x.at - offset > Date.now());
  if (ti < 0) ti = transitions.length;
  let nextPulse = Date.now() + rand(8000, 20000);
  let gestured = false;
  while (Date.now() < stopAt) {
    const nextTransition = ti < transitions.length ? transitions[ti].at - offset + rand(-150, 250) : Infinity; // human timing noise
    const nextHeartbeat = Math.max(lastSent, Date.now() - 2000) + 2000;
    const wake = Math.min(nextTransition, nextHeartbeat, nextPulse, stopAt);
    await sleepMs(wake - Date.now());
    const now = Date.now();
    if (now >= stopAt) break;
    if (ti < transitions.length && now >= transitions[ti].at - offset - 150) {
      send('breath_state', { phase: transitions[ti].phase });
      ti += 1;
    } else if (now >= nextPulse) {
      send('pulse', {});
      nextPulse = now + rand(8000, 20000);
      if (!gestured && Math.random() < 0.5) {
        await sleepMs(5000);
        send('gesture', { type: pick(RIPPLE_GESTURES) });
        gestured = true;
      }
    } else if (now - lastSent >= 2000) {
      send('heartbeat', {});
    }
  }
  await call(u, 'POST', `/v1/ripples/sessions/${session.sessionId}/leave`, {}, 'POST /v1/ripples/sessions/:id/leave');
  if (live) sock.leave(topic);
  sock.close();
}

// ------------------------------------------------------------------ burst (HTTP only)
export async function burstFlow() {
  const { u, idx } = userAt(ROOMS_VUS + RIPPLES_VUS, 'burst');
  const quadrant = QUADS[idx % QUADS.length];
  const moodId = MOODS[quadrant][Math.floor(idx / QUADS.length) % 4];
  await sleepMs(rand(0, BURST_WINDOW_S * 1000));
  const t0 = Date.now();
  const m = await call(u, 'POST', '/v1/rooms/match', { quadrant, moodId, timezone: TZ }, 'POST /v1/rooms/match');
  if (m.status !== 200 || !m.json) return;
  roomMatchMs.add(Date.now() - t0);
  matchSteps.add(1, { step: String(m.json.match.step), created: String(m.json.match.created), merged: String(m.json.match.merged) });
  const roomId = m.json.room.roomId;
  await call(u, 'GET', `/v1/rooms/${roomId}`, undefined, 'GET /v1/rooms/:id');
  await sleepMs(rand(2000, 8000));
  await call(u, 'POST', `/v1/rooms/${roomId}/heartbeat`, {}, 'POST /v1/rooms/:id/heartbeat');
  await sleepMs(rand(2000, 8000));
  await call(u, 'POST', `/v1/rooms/${roomId}/leave`, {}, 'POST /v1/rooms/:id/leave');
}

// ------------------------------------------------------------------ summary
function fmt(v) {
  return v === undefined || v === null ? '-' : Math.round(v);
}
export function handleSummary(data) {
  const lines = [`Aura load run ${RUNID} · rooms ${ROOMS_VUS} · ripples ${RIPPLES_VUS} · burst ${BURST_VUS} · ${DURATION_S}s`];
  const trend = (name, label) => {
    const m = data.metrics[name];
    if (!m) return;
    const v = m.values;
    lines.push(`  ${(label || name).padEnd(52)} p50 ${fmt(v.med)} · p95 ${fmt(v['p(95)'])} · p99 ${fmt(v['p(99)'])} · max ${fmt(v.max)} · n ${v.count}`);
  };
  for (const [name] of Object.entries(data.metrics).filter(([k]) => k.startsWith('http_req_duration{name:')).sort()) trend(name, name.replace('http_req_duration', ''));
  ['room_match_ms', 'ripple_match_ms', 'ripple_polls', 'rt_connect_ms', 'rt_join_ms', 'fanout_gesture_self_ms', 'fanout_gesture_ms', 'fanout_gesture_member_ms', 'fanout_member_joined_ms', 'fanout_reflection_ms', 'fanout_breath_ms'].forEach((n) => trend(n));
  const rate = (n) => (data.metrics[n] ? `${n} ${(data.metrics[n].values.rate * 100).toFixed(2)}%` : null);
  lines.push(`  ${[rate('http_req_failed'), rate('rt_join_ok'), rate('gesture_self_delivered')].filter(Boolean).join(' · ')}`);
  const count = (n) => (data.metrics[n] ? `${n} ${data.metrics[n].values.count}` : null);
  lines.push(`  ${['http_reqs', 'api_errors', 'rt_errors', 'rt_msgs_received', 'ws_sessions', 'vu_exceptions'].map(count).filter(Boolean).join(' · ')}`);
  const failed = Object.entries(data.metrics).filter(([, m]) => m.thresholds && Object.values(m.thresholds).some((t) => !t.ok)).map(([k]) => k);
  lines.push(failed.length ? `  thresholds missed: ${failed.join(', ')}` : '  all thresholds met');
  return {
    [`${RUN_DIR}/summary.json`]: JSON.stringify(data, null, 1),
    stdout: `${lines.join('\n')}\n`,
  };
}
