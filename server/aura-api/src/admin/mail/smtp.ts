import { randomBytes } from 'node:crypto';
import net from 'node:net';
import tls from 'node:tls';

/**
 * A small SMTP submission client (RFC 5321 / 6409): EHLO, STARTTLS (opportunistic or required) or implicit TLS,
 * AUTH PLAIN / LOGIN, MAIL / RCPT / DATA with dot-stuffing, QUIT. Plain-text UTF-8 messages only (base64 body), which
 * is all the console sends: grievance acknowledgements and replies, and content-free pages. No dependency.
 *
 * Errors carry a short machine code (`smtp_timeout`, `smtp_550`, …) for the paging log; server replies are never logged
 * or stored (they can echo addresses).
 */
export interface SmtpOptions {
  host: string;
  port: number;
  /** Implicit TLS (smtps://, usually port 465). */
  secure: boolean;
  starttls: 'opportunistic' | 'required' | 'off';
  user?: string;
  pass?: string;
  helo?: string;
  timeoutMs?: number;
  /** Verify the server certificate (default true). `?tls_verify=false` only for a local relay with a self-signed cert. */
  rejectUnauthorized?: boolean;
}

export class SmtpError extends Error {
  constructor(
    readonly code: string,
    message: string = code,
  ) {
    super(message);
    this.name = 'SmtpError';
  }
}

/** `smtp://[user:pass@]host[:port][?starttls=required|off&helo=name&tls_verify=false]` or `smtps://…`. */
export function smtpOptionsFromUrl(url: string): SmtpOptions {
  const u = new URL(url);
  if (u.protocol !== 'smtp:' && u.protocol !== 'smtps:') throw new SmtpError('smtp_bad_url', 'SMTP_URL must be smtp:// or smtps://');
  const secure = u.protocol === 'smtps:';
  const st = u.searchParams.get('starttls');
  return {
    host: u.hostname.replace(/^\[|\]$/g, ''),
    port: u.port ? Number(u.port) : secure ? 465 : 587,
    secure,
    starttls: secure ? 'off' : st === 'required' ? 'required' : st === 'off' ? 'off' : 'opportunistic',
    user: u.username ? decodeURIComponent(u.username) : undefined,
    pass: u.password ? decodeURIComponent(u.password) : undefined,
    helo: u.searchParams.get('helo') ?? undefined,
    rejectUnauthorized: u.searchParams.get('tls_verify') !== 'false',
  };
}

export interface OutgoingMail {
  from: string;
  to: readonly string[];
  replyTo?: string | null;
  subject: string;
  text: string;
  /** Adds `Auto-Submitted: auto-generated` (acknowledgements, pages). */
  autoSubmitted?: boolean;
  date?: Date;
}

/** The bare address inside `Name <addr>` (or the whole string). */
export function addrSpec(mailbox: string): string {
  const m = /<([^<>\s]+)>\s*$/.exec(mailbox);
  return (m ? m[1] : mailbox).trim();
}

const noLineBreaks = (s: string): string => s.replace(/[\r\n]+/g, ' ').trim();

/** RFC 2047 encoded-word for non-ASCII header text. */
export function encodeHeader(value: string): string {
  const v = noLineBreaks(value);
  if (/^[\x20-\x7e]*$/.test(v)) return v;
  return `=?UTF-8?B?${Buffer.from(v, 'utf8').toString('base64')}?=`;
}

function wrap76(b64: string): string {
  const out: string[] = [];
  for (let i = 0; i < b64.length; i += 76) out.push(b64.slice(i, i + 76));
  return out.join('\r\n');
}

/** RFC 5322 message: plain text, UTF-8, base64 body, CRLF line ends. */
export function buildMessage(m: OutgoingMail): string {
  const domain = addrSpec(m.from).split('@')[1] ?? 'localhost';
  const headers = [
    `From: ${noLineBreaks(m.from)}`,
    `To: ${m.to.map(noLineBreaks).join(', ')}`,
    ...(m.replyTo ? [`Reply-To: ${noLineBreaks(m.replyTo)}`] : []),
    `Subject: ${encodeHeader(m.subject)}`,
    `Date: ${(m.date ?? new Date()).toUTCString()}`,
    `Message-ID: <${randomBytes(12).toString('hex')}@${noLineBreaks(domain)}>`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=utf-8',
    'Content-Transfer-Encoding: base64',
    ...(m.autoSubmitted ? ['Auto-Submitted: auto-generated'] : []),
  ];
  const body = wrap76(Buffer.from(m.text.replace(/\r?\n/g, '\r\n'), 'utf8').toString('base64'));
  return `${headers.join('\r\n')}\r\n\r\n${body}\r\n`;
}

/** Leading dots doubled (RFC 5321 §4.5.2), bare LFs normalised. */
export function dotStuff(message: string): string {
  return message.replace(/\r?\n/g, '\r\n').replace(/^\./gm, '..');
}

interface Reply {
  code: number;
  lines: string[];
}

/** One SMTP session over a socket that may be upgraded to TLS mid-way. */
class SmtpSession {
  private socket: net.Socket;
  private buf = '';
  private pendingLines: string[] = [];
  private replies: Reply[] = [];
  private waiter: { resolve: (r: Reply) => void; reject: (e: Error) => void } | null = null;
  private failure: Error | null = null;

  constructor(
    socket: net.Socket,
    private readonly timeoutMs: number,
  ) {
    this.socket = socket;
    this.attach(socket);
  }

  private attach(s: net.Socket): void {
    s.setEncoding('utf8');
    s.on('data', (chunk: string) => this.onData(chunk));
    s.on('error', (e: NodeJS.ErrnoException) => this.fail(new SmtpError(e.code === 'ECONNREFUSED' ? 'smtp_connect_failed' : 'smtp_socket_error')));
    s.on('close', () => this.fail(new SmtpError('smtp_connection_closed')));
  }

  private onData(chunk: string): void {
    this.buf += chunk;
    let i: number;
    while ((i = this.buf.indexOf('\n')) >= 0) {
      const line = this.buf.slice(0, i).replace(/\r$/, '');
      this.buf = this.buf.slice(i + 1);
      const m = /^(\d{3})([ -]?)(.*)$/.exec(line);
      if (!m) continue;
      this.pendingLines.push(m[3]);
      if (m[2] !== '-') {
        const reply = { code: Number(m[1]), lines: this.pendingLines };
        this.pendingLines = [];
        if (this.waiter) {
          const w = this.waiter;
          this.waiter = null;
          w.resolve(reply);
        } else {
          this.replies.push(reply);
        }
      }
    }
  }

  private fail(e: Error): void {
    if (!this.failure) this.failure = e;
    if (this.waiter) {
      const w = this.waiter;
      this.waiter = null;
      w.reject(this.failure);
    }
  }

  read(): Promise<Reply> {
    const queued = this.replies.shift();
    if (queued) return Promise.resolve(queued);
    if (this.failure) return Promise.reject(this.failure);
    return new Promise<Reply>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.waiter = null;
        reject(new SmtpError('smtp_timeout'));
      }, this.timeoutMs);
      this.waiter = {
        resolve: (r) => {
          clearTimeout(timer);
          resolve(r);
        },
        reject: (e) => {
          clearTimeout(timer);
          reject(e);
        },
      };
    });
  }

  async expect(codes: number[], stage: string): Promise<Reply> {
    const r = await this.read();
    if (!codes.includes(r.code)) throw new SmtpError(`smtp_${r.code}`, `SMTP ${stage}: unexpected ${r.code}`);
    return r;
  }

  write(data: string): void {
    this.socket.write(data);
  }

  async command(line: string, codes: number[], stage: string): Promise<Reply> {
    this.write(`${line}\r\n`);
    return this.expect(codes, stage);
  }

  async upgrade(host: string, rejectUnauthorized: boolean): Promise<void> {
    const plain = this.socket;
    plain.removeAllListeners('data');
    plain.removeAllListeners('close');
    plain.removeAllListeners('error');
    this.buf = '';
    const secured = await new Promise<tls.TLSSocket>((resolve, reject) => {
      const s = tls.connect({ socket: plain, servername: net.isIP(host) ? undefined : host, rejectUnauthorized }, () => resolve(s));
      s.once('error', () => reject(new SmtpError('smtp_tls_failed')));
    });
    this.socket = secured;
    this.attach(secured);
  }

  close(): void {
    this.socket.removeAllListeners('close');
    this.socket.destroy();
  }
}

function connect(o: SmtpOptions, timeoutMs: number): Promise<net.Socket> {
  return new Promise((resolve, reject) => {
    const onError = (e: NodeJS.ErrnoException): void =>
      reject(new SmtpError(e.code === 'ECONNREFUSED' ? 'smtp_connect_failed' : o.secure ? 'smtp_tls_failed' : 'smtp_socket_error'));
    const s: net.Socket = o.secure
      ? tls.connect(
          { host: o.host, port: o.port, servername: net.isIP(o.host) ? undefined : o.host, rejectUnauthorized: o.rejectUnauthorized ?? true },
          () => {
            s.off('error', onError);
            resolve(s);
          },
        )
      : net.connect({ host: o.host, port: o.port }, () => {
          s.off('error', onError);
          resolve(s);
        });
    s.once('error', onError);
    s.setTimeout(timeoutMs, () => {
      s.destroy();
      reject(new SmtpError('smtp_timeout'));
    });
  });
}

function capabilities(r: Reply): Set<string> {
  return new Set(r.lines.slice(1).map((l) => l.trim().toUpperCase()));
}

/** Delivers one message. Resolves when the server accepted it (250 after DATA). */
export async function sendMail(o: SmtpOptions, mail: OutgoingMail): Promise<void> {
  if (mail.to.length === 0) throw new SmtpError('smtp_no_recipients');
  const timeoutMs = o.timeoutMs ?? 10_000;
  const socket = await connect(o, timeoutMs);
  socket.setTimeout(0);
  const s = new SmtpSession(socket, timeoutMs);
  try {
    await s.expect([220], 'greeting');
    const helo = o.helo ?? 'aura-api.localdomain';
    let ehlo = await s.command(`EHLO ${helo}`, [250, 500, 501, 502, 504, 550], 'EHLO');
    if (ehlo.code !== 250) ehlo = await s.command(`HELO ${helo}`, [250], 'HELO');
    let caps = capabilities(ehlo);
    const canStartTls = caps.has('STARTTLS');
    if (!o.secure && o.starttls === 'required' && !canStartTls) throw new SmtpError('smtp_starttls_unavailable');
    if (!o.secure && o.starttls !== 'off' && canStartTls) {
      await s.command('STARTTLS', [220], 'STARTTLS');
      await s.upgrade(o.host, o.rejectUnauthorized ?? true);
      caps = capabilities(await s.command(`EHLO ${helo}`, [250], 'EHLO after STARTTLS'));
    }
    if (o.user) {
      const auth = [...caps].find((c) => c.startsWith('AUTH')) ?? '';
      if (/\bPLAIN\b/.test(auth)) {
        const token = Buffer.from(`\u0000${o.user}\u0000${o.pass ?? ''}`, 'utf8').toString('base64');
        await s.command(`AUTH PLAIN ${token}`, [235], 'AUTH').catch(() => {
          throw new SmtpError('smtp_auth_failed');
        });
      } else if (/\bLOGIN\b/.test(auth)) {
        await s.command('AUTH LOGIN', [334], 'AUTH');
        await s.command(Buffer.from(o.user, 'utf8').toString('base64'), [334], 'AUTH user');
        await s.command(Buffer.from(o.pass ?? '', 'utf8').toString('base64'), [235], 'AUTH pass').catch(() => {
          throw new SmtpError('smtp_auth_failed');
        });
      } else {
        throw new SmtpError('smtp_auth_unsupported');
      }
    }
    await s.command(`MAIL FROM:<${addrSpec(mail.from)}>`, [250], 'MAIL FROM');
    for (const rcpt of mail.to) await s.command(`RCPT TO:<${addrSpec(rcpt)}>`, [250, 251], 'RCPT TO');
    await s.command('DATA', [354], 'DATA');
    const body = dotStuff(buildMessage(mail));
    s.write(body.endsWith('\r\n') ? `${body}.\r\n` : `${body}\r\n.\r\n`);
    await s.expect([250], 'end of data');
    await s.command('QUIT', [221], 'QUIT').catch(() => undefined); // accepted already; a missing 221 doesn't matter
  } finally {
    s.close();
  }
}
