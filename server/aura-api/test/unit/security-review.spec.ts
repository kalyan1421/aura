/**
 * Milestone B security review (docs/security/milestone-b-review.md) — SR-2: `trust proxy` decides whose address the
 * public routes' per-client rate limits see (src/admin/admin-http.ts clientAddress → req.ip). Real Express app.
 */
import express from 'express';
import request from 'supertest';
import { applyTrustProxy } from '../../src/bootstrap';
import { clientAddress } from '../../src/admin/admin-http';

function appWith(trust: number | string[] | undefined): express.Express {
  const app = express();
  applyTrustProxy(app, trust);
  app.get('/ip', (req, res) => {
    res.json({ ip: clientAddress(req) });
  });
  return app;
}

describe('SR-2 trust proxy → client address for per-client rate limits', () => {
  it('default (unset): X-Forwarded-For is ignored — a client cannot pick its own bucket', async () => {
    const r = await request(appWith(undefined)).get('/ip').set('X-Forwarded-For', '203.0.113.7').expect(200);
    expect(r.body.ip).not.toBe('203.0.113.7');
    expect(r.body.ip).toMatch(/127\.0\.0\.1|::1/);
  });

  it('one trusted hop (a load balancer): the client address comes from the balancer-appended X-Forwarded-For entry', async () => {
    const app = appWith(1);
    const a = await request(app).get('/ip').set('X-Forwarded-For', '203.0.113.7').expect(200);
    const b = await request(app).get('/ip').set('X-Forwarded-For', '198.51.100.9').expect(200);
    expect(a.body.ip).toBe('203.0.113.7');
    expect(b.body.ip).toBe('198.51.100.9'); // two clients behind one balancer → two buckets, not one
  });

  it('one trusted hop: a spoofed leading X-Forwarded-For entry is not believed (only the last hop is)', async () => {
    const r = await request(appWith(1)).get('/ip').set('X-Forwarded-For', '6.6.6.6, 203.0.113.7').expect(200);
    expect(r.body.ip).toBe('203.0.113.7');
  });

  it('an address list: only the listed proxy is trusted', async () => {
    const r = await request(appWith(['loopback'])).get('/ip').set('X-Forwarded-For', '203.0.113.7').expect(200);
    expect(r.body.ip).toBe('203.0.113.7'); // supertest connects over loopback = the "proxy"
    const s = await request(appWith(['10.0.0.0/8'])).get('/ip').set('X-Forwarded-For', '203.0.113.7').expect(200);
    expect(s.body.ip).not.toBe('203.0.113.7');
  });
});
