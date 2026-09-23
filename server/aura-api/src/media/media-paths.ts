/**
 * Object names in the `private-media` bucket. Every object of a user lives under `<user_id>/` (the account
 * purge deletes that prefix); a check-in's voice note is always `<user_id>/voice/<check-in id>` — one
 * deterministic name per record, so a retried upload overwrites instead of piling up.
 */
export const voiceObjectPath = (userId: string, checkInId: string): string =>
  `${userId.toLowerCase()}/voice/${checkInId.toLowerCase()}`;

/**
 * F4 capsule media (contracts/api/v1-capsules.md §5): `<user_id>/capsules/<capsule id>/<slot>` with slot `voice` or
 * `photo-0` … `photo-2`. Deterministic per slot (a retried upload overwrites); deleting a capsule removes its folder.
 */
export const CAPSULE_PHOTO_SLOTS = 3;
export type CapsuleSlot = 'voice' | `photo-${number}`;

export const capsuleObjectPrefix = (userId: string, capsuleId: string): string =>
  `${userId.toLowerCase()}/capsules/${capsuleId.toLowerCase()}/`;

export const capsuleObjectPath = (userId: string, capsuleId: string, slot: CapsuleSlot): string =>
  `${capsuleObjectPrefix(userId, capsuleId)}${slot}`;

const CAPSULE_PATH = /^([0-9a-f-]{36})\/capsules\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/[^/]+$/;

/** The capsule id of an own capsule-media path (`<user_id>/capsules/<id>/<slot>`), else null. */
export function capsuleIdOfPath(userId: string, path: string): string | null {
  const m = CAPSULE_PATH.exec(path);
  return m && m[1] === userId.toLowerCase() ? m[2] : null;
}

export const MAX_MEDIA_PATH_CHARS = 512;
const MAX_SEGMENTS_BELOW_USER = 4;
/** Letters, digits, `_`, `-`, with single dots only *inside* a segment — so `.` / `..` can never occur. */
const SEGMENT = /^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*$/;

/**
 * True when `path` is a well-formed object name under the caller's own `<user_id>/` prefix. Everything
 * else (another user's prefix, traversal, empty segments, odd characters) is treated as "not found" by
 * the media routes, so they never reveal whether a foreign object exists.
 */
export function isOwnMediaPath(userId: string, path: string): boolean {
  const prefix = `${userId.toLowerCase()}/`;
  if (path.length > MAX_MEDIA_PATH_CHARS || !path.startsWith(prefix)) return false;
  const rest = path.slice(prefix.length).split('/');
  return rest.length <= MAX_SEGMENTS_BELOW_USER && rest.every((s) => SEGMENT.test(s));
}
