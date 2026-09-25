#!/usr/bin/env node
// Runs the API (dist/main.js) and the BullMQ worker (dist/worker.js) in one container, for hosts whose free tier
// gives one always-on web service and no background workers (render.yaml, Render Free). If either process exits,
// the other is stopped and this launcher exits with its code, so the host restarts the whole service. Production
// on paid plans runs them as two services instead (`pnpm start` and `pnpm start:worker`).
import { spawn } from 'node:child_process';

const children = [
  spawn(process.execPath, ['dist/main.js'], { stdio: 'inherit' }),
  spawn(process.execPath, ['dist/worker.js'], { stdio: 'inherit' }),
];

let stopping = false;
function stopAll(code) {
  if (stopping) return;
  stopping = true;
  for (const c of children) if (c.exitCode === null) c.kill('SIGTERM');
  setTimeout(() => process.exit(code), 10_000).unref();
}

for (const c of children) {
  c.on('exit', (code, signal) => {
    if (!stopping) console.error(`[start-all] ${c.spawnargs[1]} exited (${signal ?? code}); stopping the service`);
    stopAll(code ?? 1);
    if (children.every((x) => x.exitCode !== null || x.signalCode !== null)) process.exit(code ?? 1);
  });
}
for (const sig of ['SIGTERM', 'SIGINT']) process.on(sig, () => stopAll(0));
