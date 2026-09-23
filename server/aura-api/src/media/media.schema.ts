import { z } from 'zod';
import { UUID_RE } from '../common/uuid';

export const MEDIA_KINDS = ['voice'] as const;
export type MediaKind = (typeof MEDIA_KINDS)[number];

/** Voice ≤ 60 s (PRD F1): AAC at ≤ 64 kbps is ~480 KB, plus the AES-GCM envelope — 1 MiB is ample. */
export const MAX_MEDIA_BYTES: Record<MediaKind, number> = { voice: 1_048_576 };

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
