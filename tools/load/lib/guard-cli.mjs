#!/usr/bin/env node
/**
 * run.sh / cleanup.sh entry point for lib/guard.js: exits 0 and prints the mode ("local" / "staging") when the targets
 * are allowed, exits 3 with the reason otherwise. Inputs come from the environment (never printed with credentials).
 */
import { assertSafeTargets, GuardError } from './guard.js';

try {
  const r = assertSafeTargets({
    supabaseUrl: process.env.SUPABASE_URL || undefined,
    apiUrl: process.env.API_URL || undefined,
    dbUrl: process.env.LOAD_DB_URL || undefined,
    staging: process.env.AURA_LOAD_STAGING === '1',
    stagingAck: process.env.AURA_LOAD_STAGING_ACK,
    stagingSupabaseHosts: process.env.AURA_LOAD_STAGING_SUPABASE_HOST,
    prodHosts: process.env.AURA_LOAD_PROD_HOSTS,
  });
  process.stdout.write(`${r.mode}\n`);
} catch (e) {
  process.stderr.write(`guard: ${e instanceof GuardError ? e.message : String(e)}\n`);
  process.exit(3);
}
