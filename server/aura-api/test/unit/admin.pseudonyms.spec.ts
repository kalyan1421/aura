import { PseudonymsService, normalize } from '../../src/admin/pseudonyms.service';
import { blockedPseudonyms } from '../../src/rooms/pseudonym-blocklist';
import { ALL_PSEUDONYMS, BLOCKED_PSEUDONYMS, generatePseudonym } from '../../src/rooms/pseudonyms';

/** PRD 19 "Configuration … an offensive-combination blocklist": the Owner's live pseudonym blocklist. */
function fake() {
  const rows = new Map<string, { pseudonym: string; reason_code: string; created_by: string; created_at: Date }>();
  const audit: Array<{ action: string; reason: string; detail: Record<string, unknown> }> = [];
  const q = {
    async query(sql: string, params: unknown[] = []) {
      if (sql.startsWith('select pseudonym, reason_code')) return { rows: [...rows.values()] };
      if (sql.startsWith('select pseudonym from public.pseudonym_blocklist')) return { rows: [...rows.values()] };
      if (sql.includes('insert into public.pseudonym_blocklist')) {
        const name = params[0] as string;
        if (rows.has(name)) return { rows: [], rowCount: 0 };
        rows.set(name, { pseudonym: name, reason_code: params[1] as string, created_by: params[2] as string, created_at: new Date() });
        return { rows: [], rowCount: 1 };
      }
      if (sql.startsWith('delete from public.pseudonym_blocklist')) {
        const had = rows.delete(params[0] as string);
        return { rows: [], rowCount: had ? 1 : 0 };
      }
      if (sql.includes('count(*)::int as n from public.pseudonym_blocklist')) return { rows: [{ n: rows.size }] };
      if (sql.includes('insert into public.moderation_actions')) {
        audit.push({ action: params[1] as string, reason: params[4] as string, detail: JSON.parse(params[5] as string) });
        return { rows: [{ id: String(audit.length) }], rowCount: 1 };
      }
      throw new Error(`unexpected SQL: ${sql.slice(0, 60)}`);
    },
  };
  const db = { ...q, withTx: <T>(fn: (t: typeof q) => Promise<T>) => fn(q) };
  const service = new PseudonymsService(db as never);
  return { service, rows, audit, q };
}

const owner = { actor: 'staff:owner-1' } as never;

describe('pseudonym blocklist (console)', () => {
  it('shows the curated lists, the code blocklist and how many names are handed out', async () => {
    const { service } = fake();
    const c = await service.get();
    expect(c.adjectives.length).toBeGreaterThan(20);
    expect(c.nouns.length).toBeGreaterThan(20);
    expect(c.codeBlocked).toEqual([...BLOCKED_PSEUDONYMS].sort());
    expect(c.blocked).toEqual([]);
    expect(c.available).toBe(ALL_PSEUDONYMS.length);
  });

  it('the Owner blocks a name (normalised, idempotent, audited without the name) and lifts it again', async () => {
    const { service, rows, audit } = fake();
    const after = await service.block(owner, { pseudonym: '  quiet   COMET ', reasonCode: 'reads_badly_in_te' });
    expect([...rows.keys()]).toEqual(['Quiet Comet']);
    expect(after.blocked.map((b) => b.pseudonym)).toEqual(['Quiet Comet']);
    expect(after.available).toBe(ALL_PSEUDONYMS.length - 1);
    await service.block(owner, { pseudonym: 'Quiet Comet', reasonCode: 'again' });
    expect(audit).toEqual([{ action: 'config_pseudonym_block', reason: 'reads_badly_in_te', detail: { list: 'pseudonym_blocklist', size: 1 } }]);
    expect(JSON.stringify(audit)).not.toContain('Comet');

    await service.unblock(owner, { pseudonym: 'Quiet Comet', reasonCode: 'review_done' });
    expect(rows.size).toBe(0);
    expect(audit.map((a) => a.action)).toEqual(['config_pseudonym_block', 'config_pseudonym_unblock']);
  });

  it('refuses names the generator never hands out and bad reason codes', async () => {
    const { service } = fake();
    await expect(service.block(owner, { pseudonym: 'Call Me', reasonCode: 'x' })).rejects.toMatchObject({ status: 400 });
    await expect(service.block(owner, { pseudonym: 'Lunar Moon', reasonCode: 'x' })).rejects.toMatchObject({ status: 400 }); // blocked in code already
    await expect(service.block(owner, { pseudonym: 'Quiet Comet', reasonCode: 'Not A Code' })).rejects.toMatchObject({ status: 400 });
  });

  it('new memberships never get a blocked name', async () => {
    const { q, rows } = fake();
    for (const p of ALL_PSEUDONYMS.slice(0, ALL_PSEUDONYMS.length - 1)) {
      rows.set(p, { pseudonym: p, reason_code: 'x', created_by: 'x', created_at: new Date() });
    }
    const taken = await blockedPseudonyms(q as never);
    for (let i = 0; i < 20; i++) expect(generatePseudonym(taken)).toBe(ALL_PSEUDONYMS[ALL_PSEUDONYMS.length - 1]);
  });

  it('normalises capitalisation and spacing like the generator', () => {
    expect(normalize('quiet comet')).toBe('Quiet Comet');
    expect(normalize('  SILVER   nova ')).toBe('Silver Nova');
  });
});
