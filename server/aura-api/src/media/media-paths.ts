/**
 * Object names in the `private-media` bucket. Every object of a user lives under `<user_id>/` (the account
 * purge deletes that prefix); a check-in's voice note is always `<user_id>/voice/<check-in id>` — one
 * deterministic name per record, so a retried upload overwrites instead of piling up.
 */
export const voiceObjectPath = (userId: string, checkInId: string): string =>
  `${userId.toLowerCase()}/voice/${checkInId.toLowerCase()}`;

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
