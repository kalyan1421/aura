/**
 * Minimal Supabase Realtime (Phoenix channels, vsn 1.0.0) client for the e2e suite — enough to join PRIVATE
 * Broadcast channels with a user's access token (authorised by the RLS policy on realtime.messages) and record every
 * message, so tests can assert delivery, refusal and payload shapes (DS-10). Uses Node's global WebSocket.
 */
import { SUPABASE_URL, localAnonKey } from './support';

export interface RealtimeMessage {
  topic: string;
  event: string;
  payload: Record<string, unknown>;
}

export interface BroadcastMessage {
  /** Channel topic without the `realtime:` prefix, e.g. `room:<id>`. */
  topic: string;
  event: string;
  payload: Record<string, unknown>;
}

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

export class RealtimeClient {
  readonly messages: RealtimeMessage[] = [];
  private ref = 0;
  private readonly timer: NodeJS.Timeout;

  private constructor(private readonly ws: WebSocket) {
    ws.onmessage = (e: MessageEvent) => {
      try {
        this.messages.push(JSON.parse(String(e.data)) as RealtimeMessage);
      } catch {
        /* ignore non-JSON frames */
      }
    };
    this.timer = setInterval(() => this.push('phoenix', 'heartbeat', {}), 20_000);
    this.timer.unref();
  }

  static async connect(): Promise<RealtimeClient> {
    const url = `${SUPABASE_URL.replace(/^http/, 'ws')}/realtime/v1/websocket?apikey=${encodeURIComponent(localAnonKey())}&vsn=1.0.0`;
    const ws = new WebSocket(url);
    await new Promise<void>((resolve, reject) => {
      ws.onopen = () => resolve();
      ws.onerror = () => reject(new Error('realtime websocket failed to open'));
    });
    return new RealtimeClient(ws);
  }

  private push(topic: string, event: string, payload: unknown): string {
    const ref = String(++this.ref);
    this.ws.send(JSON.stringify({ topic, event, payload, ref, join_ref: ref }));
    return ref;
  }

  /**
   * Join a private channel as the token's user; resolves with the server's verdict. `ack: true` makes the server
   * answer every client broadcast (so a refused one is observable).
   */
  async join(topic: string, accessToken: string, opts: { ack?: boolean } = {}): Promise<{ ok: boolean; reason?: string }> {
    const full = `realtime:${topic}`;
    const ref = this.push(full, 'phx_join', {
      config: { broadcast: { self: false, ack: opts.ack ?? false }, presence: { key: '' }, postgres_changes: [], private: true },
      access_token: accessToken,
    });
    const reply = await this.waitFor((m) => m.topic === full && m.event === 'phx_reply' && (m as unknown as { ref?: string }).ref === ref, 8000);
    const p = reply.payload as { status?: string; response?: { reason?: string } };
    return p.status === 'ok' ? { ok: true } : { ok: false, reason: p.response?.reason };
  }

  /** Try to broadcast as a client (must be refused: no INSERT policy). Resolves with the reply status. */
  async clientBroadcast(topic: string, event: string, payload: Record<string, unknown>): Promise<string | undefined> {
    const full = `realtime:${topic}`;
    const ref = this.push(full, 'broadcast', { type: 'broadcast', event, payload });
    const reply = await this.waitFor(
      (m) => m.topic === full && m.event === 'phx_reply' && (m as unknown as { ref?: string }).ref === ref,
      5000,
    ).catch(() => null);
    return reply ? (reply.payload as { status?: string }).status : undefined;
  }

  leave(topic: string): void {
    this.push(`realtime:${topic}`, 'phx_leave', {});
  }

  /** Server broadcasts received so far (optionally for one topic / event). */
  broadcasts(topic?: string, event?: string): BroadcastMessage[] {
    return this.messages
      .filter((m) => m.event === 'broadcast')
      .map((m) => ({
        topic: m.topic.replace(/^realtime:/, ''),
        event: String((m.payload as { event?: unknown }).event),
        payload: ((m.payload as { payload?: unknown }).payload ?? {}) as Record<string, unknown>,
      }))
      .filter((b) => (topic ? b.topic === topic : true) && (event ? b.event === event : true));
  }

  async waitFor(pred: (m: RealtimeMessage) => boolean, timeoutMs = 6000): Promise<RealtimeMessage> {
    const deadline = Date.now() + timeoutMs;
    for (;;) {
      const hit = this.messages.find(pred);
      if (hit) return hit;
      if (Date.now() > deadline) throw new Error('timed out waiting for a realtime message');
      await sleep(50);
    }
  }

  async waitForBroadcast(topic: string, event: string, pred: (p: Record<string, unknown>) => boolean = () => true, timeoutMs = 6000): Promise<BroadcastMessage> {
    const deadline = Date.now() + timeoutMs;
    for (;;) {
      const hit = this.broadcasts(topic, event).find((b) => pred(b.payload));
      if (hit) return hit;
      if (Date.now() > deadline) throw new Error(`timed out waiting for ${event} on ${topic}`);
      await sleep(50);
    }
  }

  close(): void {
    clearInterval(this.timer);
    try {
      this.ws.close();
    } catch {
      /* already closed */
    }
  }
}
