#!/usr/bin/env node
/**
 * Local stand-in for OpenAI omni-moderation (POST /v1/moderations), used ONLY by the harness's own NestJS instance
 * (run.sh starts the API on :3323 with OPENAI_MODERATION_URL pointing here). Every text scores clean, after a latency
 * that imitates the real provider, so load reflections publish (and fan out `reflection_published`) instead of
 * failing closed into `held` — thousands of held items would trip the pool kill switch (reflection_config
 * auto_pause_held = 50) for everyone sharing the local stack.
 *
 * Never logs the text. Binds 127.0.0.1 only. Zero dependencies.
 *   node mock-moderation.mjs [--port 3324] [--latency-ms 250] [--jitter-ms 150] [--key <expected bearer>]
 */
import { createServer } from 'node:http';

const arg = (name, dflt) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 && process.argv[i + 1] !== undefined ? process.argv[i + 1] : dflt;
};
const port = Number(arg('port', process.env.MOCK_MODERATION_PORT ?? 3324));
const latencyMs = Number(arg('latency-ms', 250));
const jitterMs = Number(arg('jitter-ms', 150));
const key = arg('key', process.env.MOCK_MODERATION_KEY ?? '');

const CATEGORIES = [
  'harassment', 'harassment/threatening', 'hate', 'hate/threatening', 'illicit', 'illicit/violent', 'self-harm',
  'self-harm/intent', 'self-harm/instructions', 'sexual', 'sexual/minors', 'violence', 'violence/graphic',
];

let served = 0;
const server = createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ ok: true, served }));
    return;
  }
  if (req.method !== 'POST' || !req.url?.startsWith('/v1/moderations')) {
    res.writeHead(404).end();
    return;
  }
  if (key && req.headers.authorization !== `Bearer ${key}`) {
    res.writeHead(401, { 'content-type': 'application/json' }).end('{"error":{"message":"bad key"}}');
    return;
  }
  req.resume(); // the body (the text) is read and dropped, never logged
  req.on('end', () => {
    const delay = Math.max(0, latencyMs + (Math.random() * 2 - 1) * jitterMs);
    setTimeout(() => {
      served += 1;
      const scores = Object.fromEntries(CATEGORIES.map((c) => [c, 0.0001]));
      const categories = Object.fromEntries(CATEGORIES.map((c) => [c, false]));
      res.writeHead(200, { 'content-type': 'application/json' }).end(
        JSON.stringify({ id: `modr-load-${served}`, model: 'omni-moderation-latest', results: [{ flagged: false, categories, category_scores: scores }] }),
      );
    }, delay);
  });
});

server.listen(port, '127.0.0.1', () => {
  process.stdout.write(`mock-moderation listening on 127.0.0.1:${port} (latency ${latencyMs}±${jitterMs} ms)\n`);
});
const stop = () => server.close(() => process.exit(0));
process.on('SIGTERM', stop);
process.on('SIGINT', stop);
