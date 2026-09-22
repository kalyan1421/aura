import { z } from 'zod';
import { isLocalDay, isValidTimeZone } from '../rules';

export const UI_LOCALES = ['en', 'te', 'te-Latn', 'hi', 'hi-Latn'] as const;
export type UiLocale = (typeof UI_LOCALES)[number];
export type LanguagePool = 'en' | 'te' | 'hi';

/** en→en, te/te-Latn→te, hi/hi-Latn→hi (contracts/api/v1.md). */
export function languagePoolFor(locale: UiLocale): LanguagePool {
  return locale.startsWith('te') ? 'te' : locale.startsWith('hi') ? 'hi' : 'en';
}

export const profileRequestSchema = z.object({
  birthDate: z
    .string()
    .refine(isLocalDay, 'must be a real date YYYY-MM-DD')
    .refine((d) => d >= '1900-01-01', 'is implausibly old'),
  uiLocale: z.enum(UI_LOCALES),
  timezone: z.string().trim().refine(isValidTimeZone, 'must be an IANA time zone, e.g. Asia/Kolkata'),
  country: z
    .string()
    .trim()
    .transform((c) => c.toUpperCase())
    .pipe(z.string().regex(/^[A-Z]{2}$/, 'must be an ISO 3166-1 alpha-2 code'))
    .nullish(),
});

export type ProfileRequest = z.infer<typeof profileRequestSchema>;

export interface ProfileDto {
  userId: string;
  birthDate: string;
  uiLocale: UiLocale;
  languagePool: LanguagePool;
  timezone: string;
  country: string | null;
  createdAt: string;
  updatedAt: string;
}
