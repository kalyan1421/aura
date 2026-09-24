import { z } from 'zod';
import { UUID_RE } from '../common/uuid';

/** Request bodies (contracts/api/v1-billing.md). Unknown keys are refused; values are never echoed in errors. */
const uuid = z.string().regex(UUID_RE, 'must be a UUID').transform((v) => v.toLowerCase());
const productId = z.string().regex(/^[a-z0-9_.]{1,64}$/, 'unknown product');
/** The store's localized price string the paywall showed (e.g. "₹49.00"); stored for the trial reminder. */
const priceDisplay = z
  .string()
  .max(32)
  .refine((v) => !/[\n\r<>]/.test(v), 'invalid')
  .optional()
  .nullable();

export const verifySchema = z.discriminatedUnion('store', [
  z.strictObject({
    store: z.literal('apple'),
    productId,
    signedTransaction: z.string().min(20).max(20_000),
    priceDisplay,
    giftId: uuid.optional().nullable(),
  }),
  z.strictObject({
    store: z.literal('google'),
    productId,
    purchaseToken: z.string().min(10).max(512),
    priceDisplay,
    giftId: uuid.optional().nullable(),
  }),
]);
export type VerifyBody = z.infer<typeof verifySchema>;

export const restoreSchema = z.strictObject({
  apple: z.strictObject({ signedTransactions: z.array(z.string().min(20).max(20_000)).max(50) }).optional(),
  google: z
    .strictObject({ purchases: z.array(z.strictObject({ productId, purchaseToken: z.string().min(10).max(512) })).max(50) })
    .optional(),
});
export type RestoreBody = z.infer<typeof restoreSchema>;

export const giftCheckSchema = z.strictObject({
  giftId: uuid,
  roomId: uuid,
  memberId: uuid,
  kind: z.enum(['warm_tea', 'comfort_lantern', 'encouragement_bouquet']),
});

export const giftsSeenSchema = z.strictObject({ giftIds: z.array(uuid).min(1).max(50) });

export const redeemSchema = z.strictObject({
  cosmeticId: z.string().regex(/^[a-z0-9_]{1,40}$/),
  redemptionId: uuid,
});

export const skySchema = z.strictObject({
  theme: z.string().regex(/^[a-z0-9_]{1,40}$/),
  soundscape: z.string().regex(/^[a-z0-9_]{1,40}$/).nullable(),
});
