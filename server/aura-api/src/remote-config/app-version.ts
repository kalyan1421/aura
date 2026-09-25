/**
 * Minimum supported app version (MASVS-CODE-2, docs/security/masvs-l1.md F-6; contracts/api/v1.md "Remote config"
 * `minAppVersion`). `GET /v1/config` carries `minAppVersion: { ios?, android? }`; an app older than its platform's
 * value shows a calm full-screen "Please update Aura" (store link, "I need help now" still reachable, nothing on the
 * phone deleted).
 *
 * Two sources, the higher one wins per platform:
 *  - env `APP_MIN_VERSION_IOS` / `APP_MIN_VERSION_ANDROID` (a deploy sets them; boot fails on a malformed value);
 *  - the `min_app_version` feature flag, when it exists and is **on**: `payload = { "ios": "1.2.0", "android": "1.2.0" }`.
 *    Raising it needs no deploy; switching the flag off in the console (audited) drops back to the env values, which
 *    is the quick way out of a minimum set too high by mistake.
 *
 * Format: `MAJOR[.MINOR[.PATCH]][+BUILD]` (the pubspec `version`: `1.4.0+57`). Compared numerically part by part
 * (missing parts are 0); BUILD only breaks a tie and only when the minimum names one. Prefer `x.y.z` without a build:
 * Android split-per-ABI APKs offset the build number (Flutter adds 1000 × ABI), the version name never changes.
 */
export const MIN_APP_VERSION_FLAG = 'min_app_version';

export const APP_PLATFORMS = ['ios', 'android'] as const;
export type AppPlatform = (typeof APP_PLATFORMS)[number];
export type MinAppVersion = Partial<Record<AppPlatform, string>>;

const VERSION = /^(\d{1,5})(?:\.(\d{1,5}))?(?:\.(\d{1,5}))?(?:\+(\d{1,9}))?$/;

export interface AppVersion {
  parts: [number, number, number];
  build: number | null;
}

export function parseAppVersion(value: unknown): AppVersion | null {
  if (typeof value !== 'string') return null;
  const m = VERSION.exec(value.trim());
  if (!m) return null;
  return { parts: [Number(m[1]), Number(m[2] ?? 0), Number(m[3] ?? 0)], build: m[4] === undefined ? null : Number(m[4]) };
}

/** < 0 when `a` is older than `b`. The build number counts only when both have one. */
export function compareAppVersions(a: AppVersion, b: AppVersion): number {
  for (let i = 0; i < 3; i++) if (a.parts[i] !== b.parts[i]) return a.parts[i] - b.parts[i];
  if (a.build === null || b.build === null) return 0;
  return a.build - b.build;
}

/** Per platform, the higher of the env value and an enabled flag's payload value; platforms with neither are left out. */
export function effectiveMinAppVersion(env: MinAppVersion, flag: { enabled: boolean; payload: unknown } | undefined): MinAppVersion {
  const payload = flag?.enabled && flag.payload && typeof flag.payload === 'object' ? (flag.payload as Record<string, unknown>) : {};
  const out: MinAppVersion = {};
  for (const p of APP_PLATFORMS) {
    const candidates = [env[p], payload[p]]
      .map((v) => (typeof v === 'string' ? v.trim() : v))
      .filter((v): v is string => parseAppVersion(v) !== null);
    if (candidates.length === 0) continue;
    out[p] = candidates.reduce((best, v) => (compareAppVersions(parseAppVersion(v)!, parseAppVersion(best)!) > 0 ? v : best));
  }
  return out;
}
