import { z } from 'zod';

export const PLATFORMS = ['ios', 'android'] as const;
export type Platform = (typeof PLATFORMS)[number];

/** FCM registration tokens are ~160–200 chars today; 4096 leaves room without inviting abuse. */
export const MAX_TOKEN_CHARS = 4096;

// Messages never echo the value: a push token is a device identifier (never logged).
const token = z
  .string()
  .min(1, 'must not be empty')
  .max(MAX_TOKEN_CHARS, `must be at most ${MAX_TOKEN_CHARS} characters`);

/** `PUT /v1/devices` (contracts/api/v1.md). */
export const registerDeviceSchema = z.object({ token, platform: z.enum(PLATFORMS) });
export type RegisterDevice = z.infer<typeof registerDeviceSchema>;

/** `DELETE /v1/devices`. */
export const unregisterDeviceSchema = z.object({ token });
export type UnregisterDevice = z.infer<typeof unregisterDeviceSchema>;
