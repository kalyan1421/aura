/**
 * The console's SMTP client against an in-process fake server: dialogue order, AUTH PLAIN, multi-recipient, dot-stuffing,
 * UTF-8 headers, header-injection hardening, and failure codes (never the server's reply text).
 */
import net from 'node:net';
import { SmtpError, addrSpec, buildMessage, dotStuff, encodeHeader, sendMail, smtpOptionsFromUrl } from '../../src/admin/mail/smtp';

interface Session {
  lines: string[];
  data: string;
}

/** A tiny SMTP server: records the dialogue; `failAt` answers 550 to the first command starting with it. */
function fakeServer(opts: { auth?: boolean; failAt?: string } = {}): Promise<{ port: number; sessions: Session[]; close: () => Promise<void> }> {
  const sessions: Session[] = [];
  const server = net.createServer((sock) => {
    const s: Session = { lines: [], data: '' };
    sessions.push(s);
    let inData = false;
    let buf = '';
    sock.on('error', () => undefined);
    sock.write('220 fake.test ESMTP ready\r\n');
    sock.on('data', (chunk) => {
      buf += chunk.toString('utf8');
      let i: number;
      while ((i = buf.indexOf('\r\n')) >= 0) {
        const line = buf.slice(0, i);
        buf = buf.slice(i + 2);
        if (inData) {
          if (line === '.') {
            inData = false;
            sock.write('250 2.0.0 queued\r\n');
          } else {
            s.data += `${line}\r\n`;
          }
          continue;
        }
        s.lines.push(line);
        if (opts.failAt && line.toUpperCase().startsWith(opts.failAt)) {
          sock.write('550 5.1.1 nope <secret@reply.text>\r\n');
          continue;
        }
        const cmd = line.split(' ')[0].toUpperCase();
        if (cmd === 'EHLO') sock.write(`250-fake.test\r\n250-SIZE 1000000\r\n${opts.auth ? '250-AUTH PLAIN LOGIN\r\n' : ''}250 8BITMIME\r\n`);
        else if (cmd === 'AUTH') sock.write('235 2.7.0 ok\r\n');
        else if (cmd === 'MAIL' || cmd === 'RCPT') sock.write('250 ok\r\n');
        else if (cmd === 'DATA') {
          inData = true;
          sock.write('354 go ahead\r\n');
        } else if (cmd === 'QUIT') {
          sock.write('221 bye\r\n');
          sock.end();
        } else sock.write('502 unknown\r\n');
      }
    });
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      const port = (server.address() as net.AddressInfo).port;
      resolve({ port, sessions, close: () => new Promise((r) => server.close(() => r())) });
    });
  });
}

describe('SMTP client', () => {
  it('delivers: EHLO, AUTH PLAIN, MAIL, RCPT per recipient, DATA with dot-stuffing and a UTF-8 subject', async () => {
    const srv = await fakeServer({ auth: true });
    try {
      await sendMail(smtpOptionsFromUrl(`smtp://aura:p%40ss@127.0.0.1:${srv.port}?helo=aura.test`), {
        from: 'Aura <no-reply@aura.test>',
        to: ['ak@akvega.test', 'Owner <owner@akvega.test>'],
        replyTo: 'grievance@akvega.test',
        subject: 'Grievance GRV-7K3F9Q2M — received',
        text: 'Line one\n.starts with a dot\nनमस्ते',
        autoSubmitted: true,
      });
      const s = srv.sessions[0];
      const cmds = s.lines.map((l) => l.split(' ')[0]);
      expect(cmds).toEqual(['EHLO', 'AUTH', 'MAIL', 'RCPT', 'RCPT', 'DATA', 'QUIT']);
      expect(s.lines[0]).toBe('EHLO aura.test');
      expect(Buffer.from(s.lines[1].split(' ')[2], 'base64').toString('utf8')).toBe('\u0000aura\u0000p@ss');
      expect(s.lines[2]).toBe('MAIL FROM:<no-reply@aura.test>');
      expect(s.lines.slice(3, 5)).toEqual(['RCPT TO:<ak@akvega.test>', 'RCPT TO:<owner@akvega.test>']);
      expect(s.data).toContain('Subject: =?UTF-8?B?');
      expect(s.data).toContain('Auto-Submitted: auto-generated');
      expect(s.data).toContain('Reply-To: grievance@akvega.test');
      const body = s.data.split('\r\n\r\n')[1].replace(/\r\n/g, '');
      expect(Buffer.from(body, 'base64').toString('utf8')).toBe('Line one\r\n.starts with a dot\r\nनमस्ते');
    } finally {
      await srv.close();
    }
  });

  it('a refused recipient fails with smtp_550 (the reply text is never surfaced)', async () => {
    const srv = await fakeServer({ failAt: 'RCPT' });
    try {
      const err = await sendMail(smtpOptionsFromUrl(`smtp://127.0.0.1:${srv.port}`), {
        from: 'no-reply@aura.test',
        to: ['x@y.test'],
        subject: 's',
        text: 't',
      }).catch((e: unknown) => e);
      expect(err).toBeInstanceOf(SmtpError);
      expect((err as SmtpError).code).toBe('smtp_550');
      expect((err as SmtpError).message).not.toContain('secret@reply.text');
    } finally {
      await srv.close();
    }
  });

  it('starttls=required refuses a server without STARTTLS; credentials without AUTH are refused', async () => {
    const srv = await fakeServer();
    try {
      await expect(sendMail(smtpOptionsFromUrl(`smtp://127.0.0.1:${srv.port}?starttls=required`), { from: 'a@b.test', to: ['c@d.test'], subject: 's', text: 't' }))
        .rejects.toMatchObject({ code: 'smtp_starttls_unavailable' });
      await expect(sendMail(smtpOptionsFromUrl(`smtp://u:p@127.0.0.1:${srv.port}`), { from: 'a@b.test', to: ['c@d.test'], subject: 's', text: 't' }))
        .rejects.toMatchObject({ code: 'smtp_auth_unsupported' });
    } finally {
      await srv.close();
    }
  });

  it('connection refused → smtp_connect_failed', async () => {
    const srv = await fakeServer();
    const port = srv.port;
    await srv.close();
    await expect(sendMail(smtpOptionsFromUrl(`smtp://127.0.0.1:${port}`), { from: 'a@b.test', to: ['c@d.test'], subject: 's', text: 't' })).rejects.toMatchObject({
      code: 'smtp_connect_failed',
    });
  });

  it('URL options', () => {
    expect(smtpOptionsFromUrl('smtp://127.0.0.1:55525')).toMatchObject({ host: '127.0.0.1', port: 55525, secure: false, starttls: 'opportunistic' });
    expect(smtpOptionsFromUrl('smtps://u:p@smtp.example.com')).toMatchObject({ port: 465, secure: true, starttls: 'off', user: 'u', pass: 'p' });
    expect(smtpOptionsFromUrl('smtp://h:587?starttls=required&tls_verify=false')).toMatchObject({ starttls: 'required', rejectUnauthorized: false });
    expect(() => smtpOptionsFromUrl('http://x')).toThrow(SmtpError);
  });

  it('headers cannot be injected; addresses and encoded words', () => {
    const msg = buildMessage({ from: 'a@b.test', to: ['c@d.test\r\nBcc: evil@x.test'], subject: 'Hi\r\nBcc: evil@x.test', text: 'x' });
    expect(msg.split('\r\n\r\n')[0]).not.toMatch(/^Bcc:/m);
    expect(addrSpec('Aura <no-reply@aura.test>')).toBe('no-reply@aura.test');
    expect(encodeHeader('plain')).toBe('plain');
    expect(encodeHeader('ಧನ್ಯವಾದ')).toMatch(/^=\?UTF-8\?B\?.+\?=$/);
    expect(dotStuff('.a\n..b\nc.')).toBe('..a\r\n...b\r\nc.');
  });
});
