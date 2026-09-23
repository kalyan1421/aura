import { z } from 'zod';
import { isLocalDay, isValidTimeZone } from '../rules';

export const UI_LOCALES = ['en', 'te', 'te-Latn', 'hi', 'hi-Latn'] as const;
export type UiLocale = (typeof UI_LOCALES)[number];
export type LanguagePool = 'en' | 'te' | 'hi';

/** en→en, te/te-Latn→te, hi/hi-Latn→hi (contracts/api/v1.md). */
export function languagePoolFor(locale: UiLocale): LanguagePool {
  return locale.startsWith('te') ? 'te' : locale.startsWith('hi') ? 'hi' : 'en';
}

/**
 * Platform age signal band the app read before sign-in (Apple Declared Age Range / Play Age Signals; F8 REQ-ACC-04).
 * `under13` → refused like an under-13 DOB; `under18` → the invisible under-18 protections even with an adult DOB
 * (REQ-ACC-10); `adult` / null / absent → the DOB alone. Never stored as sent and never returned.
 */
export const AGE_SIGNALS = ['under13', 'under18', 'adult'] as const;
export type AgeSignal = (typeof AGE_SIGNALS)[number];

/** Under-18 protections from a signal last until the youngest age in the band (13) turns 18. */
export const SIGNAL_MINOR_YEARS = 18 - 13;

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
  ageSignal: z.enum(AGE_SIGNALS).nullish(),
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
