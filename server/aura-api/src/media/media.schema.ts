import { z } from 'zod';
import { UUID_RE } from '../common/uuid';

/** `voice` = F1 check-in voice note; `capsule_voice` / `capsule_photo` = F4 capsule media (contracts/api/v1-capsules.md §5). */
export const MEDIA_KINDS = ['voice', 'capsule_voice', 'capsule_photo'] as const;
export type MediaKind = (typeof MEDIA_KINDS)[number];

/**
 * Ciphertext size limits (the server never sees the plaintext):
 * - voice ≤ 60 s (PRD F1): AAC at ≤ 64 kbps is ~480 KB, plus the AES-GCM envelope — 1 MiB is ample;
 * - capsule voice ≤ 2:00 on Free (PRD F4): ~960 KB of AAC — 2 MiB; Plus (10:00) gets PLUS_CAPSULE_VOICE_BYTES (billing/entitlement-check.ts);
 * - capsule photo ≤ 2,048 px on the long edge, EXIF/GPS stripped on the device: 4 MiB.
 */
export const MAX_MEDIA_BYTES: Record<MediaKind, number> = {
  voice: 1_048_576,
  capsule_voice: 2_097_152,
  capsule_photo: 4_194_304,
};

/** What the client is told: stop using an upload URL after 10 minutes, a download URL after 5. */
export const UPLOAD_URL_TTL_SECONDS = 600;
export const DOWNLOAD_URL_TTL_SECONDS = 300;

export const uploadUrlRequestSchema = z.object({
  kind: z.enum(MEDIA_KINDS),
  recordId: z
    .string()
    .regex(UUID_RE, 'must be a UUID')
    .transform((s) => s.toLowerCase()),
  /** Size of the ciphertext the client will PUT. Integer + per-kind limit are checked by MediaService. */
  bytes: z.number().positive(),
  /** `capsule_photo` only (required there): photo slot 0–2. Checked by MediaService. */
  index: z.unknown().optional(),
});
export type UploadUrlRequest = z.infer<typeof uploadUrlRequestSchema>;

/** Any string: malformed or foreign paths are answered `404 not_found`, not 400 (no existence oracle). */
export const downloadUrlRequestSchema = z.object({ path: z.string() });

export interface UploadUrlResponse {
  path: string;
  uploadUrl: string;
  expiresAt: string;
}

export interface DownloadUrlResponse {
  downloadUrl: string;
  expiresAt: string;
}
