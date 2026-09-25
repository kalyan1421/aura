/**
 * Minimal Supabase Realtime client for k6 (Phoenix channels, vsn 1.0.0) — the same wire protocol supabase_flutter /
 * realtime-js speak and server/aura-api/test/e2e/realtime.ts uses: one socket per client, `phx_join` on
 * `realtime:<topic>` with `config.private = true` and the user's `access_token` (authorised by the RLS policies on
 * realtime.messages), `heartbeat` on `phoenix` every 25 s, client broadcasts as `broadcast` pushes, Presence `track`.
 */
import { WebSocket } from 'k6/websockets';
import { setInterval, clearInterval, setTimeout, clearTimeout } from 'k6/timers';

export class PhoenixSocket {
  /**
   * @param {string} url  ws(s)://…/realtime/v1/websocket?apikey=<anon>&vsn=1.0.0
   * @param {{ onBroadcast?: (topic: string, event: string, payload: object, recvMs: number) => void,
   *           onPresence?: (topic: string, event: string, payload: object) => void,
   *           onError?: (kind: string, detail: string) => void }} handlers
   */
  constructor(url, handlers = {}) {
    this.url = url;
    this.h = handlers;
    this.ref = 0;
    this.pending = new Map(); // ref → { resolve, timer, t0 }
    this.open = false;
    this.closedByUs = false;
    this.heartbeat = null;
  }

  connect(timeoutMs = 10000) {
    return new Promise((resolve, reject) => {
      const t0 = Date.now();
      const ws = new WebSocket(this.url);
      this.ws = ws;
      const timer = setTimeout(() => {
        reject(new Error('ws connect timeout'));
        try {
          ws.close();
        } catch (_) {
          /* ignore */
        }
      }, timeoutMs);
      ws.onopen = () => {
        clearTimeout(timer);
        this.open = true;
        this.heartbeat = setInterval(() => this.push('phoenix', 'heartbeat', {}), 25000);
        resolve(Date.now() - t0);
      };
      ws.onerror = (e) => {
        clearTimeout(timer);
        if (!this.open) reject(new Error(`ws error: ${e && e.error ? e.error : 'unknown'}`));
        else if (this.h.onError) this.h.onError('ws_error', String(e && e.error ? e.error : 'unknown'));
      };
      ws.onclose = () => {
        const wasOpen = this.open;
        this.open = false;
        if (this.heartbeat) clearInterval(this.heartbeat);
        this.heartbeat = null;
        for (const [, p] of this.pending) {
          clearTimeout(p.timer);
          p.resolve({ status: 'closed', response: {} });
        }
        this.pending.clear();
        if (wasOpen && !this.closedByUs && this.h.onError) this.h.onError('ws_closed', 'server closed the socket');
      };
      ws.onmessage = (e) => this.onMessage(e.data);
    });
  }

  onMessage(raw) {
    const recvMs = Date.now();
    let m;
    try {
      m = JSON.parse(raw);
    } catch (_) {
      return;
    }
    if (m.event === 'phx_reply' && m.ref && this.pending.has(m.ref)) {
      const p = this.pending.get(m.ref);
      this.pending.delete(m.ref);
      clearTimeout(p.timer);
      p.resolve(m.payload || {});
      return;
    }
    const topic = String(m.topic || '').replace(/^realtime:/, '');
    if (m.event === 'broadcast') {
      const p = m.payload || {};
      if (this.h.onBroadcast) this.h.onBroadcast(topic, String(p.event), p.payload || {}, recvMs);
      return;
    }
    if (m.event === 'presence_state' || m.event === 'presence_diff') {
      if (this.h.onPresence) this.h.onPresence(topic, m.event, m.payload || {});
      return;
    }
    if (m.event === 'phx_error' || m.event === 'phx_close') {
      if (this.h.onError && !this.closedByUs) this.h.onError(m.event, topic);
      return;
    }
    if (m.event === 'system' && m.payload && m.payload.status === 'error') {
      if (this.h.onError) this.h.onError('system_error', String(m.payload.message || m.payload.extension || 'error'));
    }
  }

  push(topic, event, payload) {
    if (!this.open) return null;
    const ref = String(++this.ref);
    this.ws.send(JSON.stringify({ topic, event, payload, ref, join_ref: ref }));
    return ref;
  }

  /** Push and wait for the phx_reply (status ok / error). Resolves { status, response, ms }. */
  request(topic, event, payload, timeoutMs = 10000) {
    const t0 = Date.now();
    return new Promise((resolve) => {
      const ref = this.push(topic, event, payload);
      if (!ref) {
        resolve({ status: 'closed', response: {}, ms: 0 });
        return;
      }
      const timer = setTimeout(() => {
        this.pending.delete(ref);
        resolve({ status: 'timeout', response: {}, ms: Date.now() - t0 });
      }, timeoutMs);
      this.pending.set(ref, { timer, resolve: (p) => resolve({ status: p.status, response: p.response || {}, ms: Date.now() - t0 }) });
    });
  }

  /** Join a private channel as the token's user. `presenceKey` enables Presence (ripples); rooms don't use it. */
  join(topic, accessToken, { presenceKey = '' } = {}) {
    return this.request(`realtime:${topic}`, 'phx_join', {
      config: { broadcast: { self: false, ack: false }, presence: { key: presenceKey }, postgres_changes: [], private: true },
      access_token: accessToken,
    });
  }

  leave(topic) {
    this.push(`realtime:${topic}`, 'phx_leave', {});
  }

  /** Client broadcast (only game:<sessionId> topics accept them — RLS INSERT policy aura_ripples_send). */
  broadcast(topic, event, payload) {
    return this.push(`realtime:${topic}`, 'broadcast', { type: 'broadcast', event, payload });
  }

  track(topic, payload) {
    return this.push(`realtime:${topic}`, 'presence', { type: 'presence', event: 'track', payload });
  }

  close() {
    this.closedByUs = true;
    if (this.heartbeat) clearInterval(this.heartbeat);
    this.heartbeat = null;
    for (const [, p] of this.pending) clearTimeout(p.timer);
    this.pending.clear();
    try {
      if (this.ws) this.ws.close();
    } catch (_) {
      /* already closed */
    }
  }
}
