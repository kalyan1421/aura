/**
 * F4 capsule media (contracts/api/v1-capsules.md §5): kinds capsule_voice / capsule_photo, slot paths, limits,
 * "sealed means sealed" (CapsuleMediaGate) and deleted capsules never downloading.
 */
import { Logger } from '@nestjs/common';
import type { PrivateMediaStore } from '../../src/account/private-media';
import { CapsuleMediaGate } from '../../src/capsules/capsule-media.gate';
import { ApiError } from '../../src/common/api-error';
import { uuidv7 } from '../../src/common/uuid';
import { capsuleIdOfPath, capsuleObjectPath, capsuleObjectPrefix, isOwnMediaPath, voiceObjectPath } from '../../src/media/media-paths';
import { MAX_MEDIA_BYTES } from '../../src/media/media.schema';
import { MediaService } from '../../src/media/media.service';

const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const OTHER = '0192f0c2-7a4e-7c1a-9b3d-000000000001';
const NOW = new Date('2026-10-08T10:00:00Z');

class FakeStore {
  configured = true;
  signed: string[] = [];
  existing = new Set<string>();
  async signUpload(path: string) {
    this.signed.push(path);
    return { url: `http://storage/upload/${path}?token=t`, expiresAt: new Date(NOW.getTime() + 7200_000) };
  }
  async signDownload(path: string) {
    return this.existing.has(path) ? { url: `http://storage/get/${path}?token=t`, expiresAt: new Date(NOW.getTime() + 300_000) } : null;
  }
}

/** CapsulesRepository stand-in for the gate: capsule states + existing objects. */
class FakeCapsuleRepo {
  states = new Map<string, 'live' | 'deleted'>();
  objects = new Set<string>();
  async state(_: unknown, userId: string, id: string) {
    return this.states.get(`${userId}:${id}`) ?? 'absent';
  }
  async objectExists(_: unknown, name: string) {
    return this.objects.has(name);
  }
}

const reason = async (p: Promise<unknown>): Promise<string> => {
  try {
    await p;
    return 'ok';
  } catch (e) {
    if (e instanceof ApiError) return `${e.status} ${e.code}`;
    throw e;
  }
};

describe('capsule media paths', () => {
  it('slot paths are deterministic and lower-case, under the owner prefix', () => {
    const id = uuidv7().toUpperCase();
    expect(capsuleObjectPrefix(USER.toUpperCase(), id)).toBe(`${USER}/capsules/${id.toLowerCase()}/`);
    expect(capsuleObjectPath(USER, id, 'voice')).toBe(`${USER}/capsules/${id.toLowerCase()}/voice`);
    expect(capsuleObjectPath(USER, id, 'photo-2')).toBe(`${USER}/capsules/${id.toLowerCase()}/photo-2`);
    expect(isOwnMediaPath(USER, capsuleObjectPath(USER, id, 'photo-2'))).toBe(true);
  });

  it('capsuleIdOfPath recognises only the caller’s own capsule paths', () => {
    const id = uuidv7();
    expect(capsuleIdOfPath(USER, capsuleObjectPath(USER, id, 'voice'))).toBe(id);
    expect(capsuleIdOfPath(OTHER, capsuleObjectPath(USER, id, 'voice'))).toBeNull();
    expect(capsuleIdOfPath(USER, voiceObjectPath(USER, id))).toBeNull();
    expect(capsuleIdOfPath(USER, `${USER}/capsules/${id}/a/b`)).toBeNull();
    expect(capsuleIdOfPath(USER, `${USER}/capsules/not-a-uuid/voice`)).toBeNull();
  });
});

describe('MediaService: capsule kinds', () => {
  let store: FakeStore;
  let repo: FakeCapsuleRepo;
  let service: MediaService;
  beforeAll(() => Logger.overrideLogger(false));
  beforeEach(() => {
    store = new FakeStore();
    repo = new FakeCapsuleRepo();
    const gate = new CapsuleMediaGate({} as never, repo as never);
    service = new MediaService(store as unknown as PrivateMediaStore, gate);
  });
  const upload = (body: Record<string, unknown>) => service.uploadUrl(USER, body, NOW);

  it('capsule_voice → <user>/capsules/<id>/voice; capsule_photo index 0–2 → photo-<index>', async () => {
    const id = uuidv7();
    expect((await upload({ kind: 'capsule_voice', recordId: id, bytes: 900_000 })).path).toBe(`${USER}/capsules/${id}/voice`);
    for (const index of [0, 1, 2]) {
      const r = await upload({ kind: 'capsule_photo', recordId: id, index, bytes: 1_500_000 });
      expect(r).toEqual({ path: `${USER}/capsules/${id}/photo-${index}`, uploadUrl: expect.any(String), expiresAt: expect.any(String) });
    }
    expect(store.signed).toHaveLength(4);
  });

  it('limits: voice 2 MiB, photo 4 MiB (ciphertext bytes)', async () => {
    const id = uuidv7();
    expect(MAX_MEDIA_BYTES).toEqual({ voice: 1_048_576, capsule_voice: 2_097_152, capsule_photo: 4_194_304 });
    expect(await reason(upload({ kind: 'capsule_voice', recordId: id, bytes: 2_097_152 }))).toBe('ok');
    expect(await reason(upload({ kind: 'capsule_voice', recordId: id, bytes: 2_097_153 }))).toBe('400 media_too_large');
    expect(await reason(upload({ kind: 'capsule_photo', recordId: id, index: 0, bytes: 4_194_304 }))).toBe('ok');
    expect(await reason(upload({ kind: 'capsule_photo', recordId: id, index: 0, bytes: 4_194_305 }))).toBe('400 media_too_large');
  });

  it.each<[string, Record<string, unknown>]>([
    ['photo without index', { kind: 'capsule_photo', bytes: 10 }],
    ['photo index 3', { kind: 'capsule_photo', index: 3, bytes: 10 }],
    ['photo index -1', { kind: 'capsule_photo', index: -1, bytes: 10 }],
    ['photo index 1.5', { kind: 'capsule_photo', index: 1.5, bytes: 10 }],
    ['photo index "0"', { kind: 'capsule_photo', index: '0', bytes: 10 }],
    ['an index on capsule_voice', { kind: 'capsule_voice', index: 0, bytes: 10 }],
    ['an index on a check-in voice note', { kind: 'voice', index: 0, bytes: 10 }],
    ['an unknown kind', { kind: 'capsule_video', bytes: 10 }],
  ])('%s → 400 invalid_request', async (_, body) => {
    expect(await reason(upload({ recordId: uuidv7(), ...body }))).toBe('400 invalid_request');
    expect(store.signed).toHaveLength(0);
  });

  it('index: null is fine for the non-photo kinds', async () => {
    expect(await reason(upload({ kind: 'capsule_voice', recordId: uuidv7(), index: null, bytes: 10 }))).toBe('ok');
    expect(await reason(upload({ kind: 'voice', recordId: uuidv7(), index: null, bytes: 10 }))).toBe('ok');
  });

  it('sealed means sealed: before the seal → upsert; sealed + empty slot → allowed once; occupied → 409 capsule_sealed', async () => {
    const id = uuidv7();
    const voice = capsuleObjectPath(USER, id, 'voice');
    expect(await reason(upload({ kind: 'capsule_voice', recordId: id, bytes: 10 }))).toBe('ok'); // not on the server yet
    repo.objects.add(voice);
    expect(await reason(upload({ kind: 'capsule_voice', recordId: id, bytes: 10 }))).toBe('ok'); // retry before the seal
    repo.states.set(`${USER}:${id}`, 'live');
    expect(await reason(upload({ kind: 'capsule_voice', recordId: id, bytes: 10 }))).toBe('409 capsule_sealed');
    expect(await reason(upload({ kind: 'capsule_photo', recordId: id, index: 0, bytes: 10 }))).toBe('ok'); // empty slot
    repo.states.set(`${USER}:${id}`, 'deleted');
    expect(await reason(upload({ kind: 'capsule_photo', recordId: id, index: 1, bytes: 10 }))).toBe('409 capsule_deleted');
  });

  it('another user’s capsule with the same id does not block the caller (their own prefix)', async () => {
    const id = uuidv7();
    repo.states.set(`${OTHER}:${id}`, 'live');
    repo.objects.add(capsuleObjectPath(OTHER, id, 'voice'));
    expect((await upload({ kind: 'capsule_voice', recordId: id, bytes: 10 })).path).toBe(capsuleObjectPath(USER, id, 'voice'));
  });

  it('a deleted capsule never downloads (404, like a missing object); live and unsynced ones do', async () => {
    const live = uuidv7();
    const gone = uuidv7();
    for (const id of [live, gone]) store.existing.add(capsuleObjectPath(USER, id, 'photo-0'));
    repo.states.set(`${USER}:${live}`, 'live');
    repo.states.set(`${USER}:${gone}`, 'deleted');
    expect(await reason(service.downloadUrl(USER, { path: capsuleObjectPath(USER, live, 'photo-0') }, NOW))).toBe('ok');
    expect(await reason(service.downloadUrl(USER, { path: capsuleObjectPath(USER, gone, 'photo-0') }, NOW))).toBe('404 not_found');
    expect(await reason(service.downloadUrl(OTHER, { path: capsuleObjectPath(USER, live, 'photo-0') }, NOW))).toBe('404 not_found');
  });

  it('without the capsule gate (older wiring) capsule kinds answer 503; voice notes are unaffected', async () => {
    const bare = new MediaService(store as unknown as PrivateMediaStore);
    expect(await reason(bare.uploadUrl(USER, { kind: 'capsule_voice', recordId: uuidv7(), bytes: 10 }, NOW))).toBe('503 media_unavailable');
    expect(await reason(bare.uploadUrl(USER, { kind: 'voice', recordId: uuidv7(), bytes: 10 }, NOW))).toBe('ok');
  });

  it('no service key → 503 media_unavailable after the capsule checks pass', async () => {
    store.configured = false;
    expect(await reason(upload({ kind: 'capsule_photo', recordId: uuidv7(), index: 2, bytes: 10 }))).toBe('503 media_unavailable');
  });
});
