import type { Queryable } from '../db/db';

/**
 * `public.signed_bundle_versions` (immutable, one row per kind and version) and `public.signed_bundle_current` (the
 * live, signed envelope per kind) — migration 20261005000017; kind `helplines` from 20261005000019. Plain SQL helpers that take any Queryable: the public
 * reads run as the service role, the console writes under `aura_admin` (src/admin/admin-db.ts).
 */
export const BUNDLE_KINDS = ['crisis_lexicon', 'helplines'] as const;
export type BundleKind = (typeof BUNDLE_KINDS)[number];

export interface StoredVersion {
  kind: BundleKind;
  version: number;
  content: unknown;
  contentSha256: string;
  vectors: unknown[];
  note: string | null;
  createdAt: string;
  createdBy: string;
}

export interface CurrentEnvelope {
  kind: BundleKind;
  version: number;
  seq: number;
  keyId: string;
  payload: string;
  signature: string;
  publishedAt: string;
  publishedBy: string;
}

interface VersionRow {
  kind: BundleKind;
  version: number;
  content: unknown;
  content_sha256: string;
  vectors: unknown[];
  note: string | null;
  created_at: Date;
  created_by: string;
}

interface CurrentRow {
  kind: BundleKind;
  version: number;
  seq: string;
  key_id: string;
  payload: string;
  signature: string;
  published_at: Date;
  published_by: string;
}

const versionOf = (r: VersionRow): StoredVersion => ({
  kind: r.kind,
  version: r.version,
  content: r.content,
  contentSha256: r.content_sha256,
  vectors: r.vectors,
  note: r.note,
  createdAt: r.created_at.toISOString(),
  createdBy: r.created_by,
});

const currentOf = (r: CurrentRow): CurrentEnvelope => ({
  kind: r.kind,
  version: r.version,
  seq: Number(r.seq),
  keyId: r.key_id,
  payload: r.payload,
  signature: r.signature,
  publishedAt: r.published_at.toISOString(),
  publishedBy: r.published_by,
});

/** Serialises publishes of one kind (and the first publish, when there is no row to lock yet). */
export async function lockKind(q: Queryable, kind: BundleKind): Promise<void> {
  await q.query('select pg_advisory_xact_lock(hashtextextended($1, 0))', [`aura:signed_bundle:${kind}`]);
}

export async function findVersion(q: Queryable, kind: BundleKind, version: number): Promise<StoredVersion | null> {
  const r = await q.query<VersionRow>(
    `select kind, version, content, content_sha256, vectors, note, created_at, created_by
       from public.signed_bundle_versions where kind = $1 and version = $2`,
    [kind, version],
  );
  return r.rows[0] ? versionOf(r.rows[0]) : null;
}

export interface VersionSummary {
  version: number;
  contentSha256: string;
  entries: number;
  note: string | null;
  createdAt: string;
  createdBy: string;
}

export async function listVersions(q: Queryable, kind: BundleKind): Promise<VersionSummary[]> {
  const r = await q.query<{ version: number; content_sha256: string; entries: number; note: string | null; created_at: Date; created_by: string }>(
    // `entries`: lexicon entries, or helpline lines (summed over the regions).
    `select version, content_sha256,
            case when jsonb_typeof(content -> 'countries') = 'object'
                 then (select coalesce(sum(jsonb_array_length(v)), 0) from jsonb_each(content -> 'countries') as c(k, v)
                        where jsonb_typeof(v) = 'array')
                 else coalesce(jsonb_array_length(content -> 'entries'), 0) end::int as entries,
            note, created_at, created_by
       from public.signed_bundle_versions where kind = $1 order by version desc limit 200`,
    [kind],
  );
  return r.rows.map((x) => ({
    version: x.version,
    contentSha256: x.content_sha256,
    entries: x.entries,
    note: x.note,
    createdAt: x.created_at.toISOString(),
    createdBy: x.created_by,
  }));
}

export async function insertVersion(
  q: Queryable,
  v: { kind: BundleKind; version: number; content: unknown; contentSha256: string; vectors: unknown[]; note: string | null; createdBy: string },
): Promise<void> {
  await q.query(
    `insert into public.signed_bundle_versions (kind, version, content, content_sha256, vectors, note, created_by)
     values ($1, $2, $3::jsonb, $4, $5::jsonb, $6, $7)`,
    [v.kind, v.version, JSON.stringify(v.content), v.contentSha256, JSON.stringify(v.vectors), v.note, v.createdBy],
  );
}

export async function findCurrent(q: Queryable, kind: BundleKind): Promise<CurrentEnvelope | null> {
  const r = await q.query<CurrentRow>(
    `select kind, version, seq, key_id, payload, signature, published_at, published_by
       from public.signed_bundle_current where kind = $1`,
    [kind],
  );
  return r.rows[0] ? currentOf(r.rows[0]) : null;
}

export async function upsertCurrent(
  q: Queryable,
  c: { kind: BundleKind; version: number; seq: number; keyId: string; payload: string; signature: string; publishedBy: string },
): Promise<CurrentEnvelope> {
  const r = await q.query<CurrentRow>(
    `insert into public.signed_bundle_current as x (kind, version, seq, key_id, payload, signature, published_at, published_by)
     values ($1, $2, $3, $4, $5, $6, now(), $7)
     on conflict (kind) do update set
       version = excluded.version, seq = excluded.seq, key_id = excluded.key_id, payload = excluded.payload,
       signature = excluded.signature, published_at = excluded.published_at, published_by = excluded.published_by
     returning kind, version, seq, key_id, payload, signature, published_at, published_by`,
    [c.kind, c.version, c.seq, c.keyId, c.payload, c.signature, c.publishedBy],
  );
  return currentOf(r.rows[0]);
}
