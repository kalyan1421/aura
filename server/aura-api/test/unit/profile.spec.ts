import { ApiError } from '../../src/common/api-error';
import { ageOn, isUnder13 } from '../../src/profile/age';
import { languagePoolFor, profileRequestSchema } from '../../src/profile/profile.schema';
import { ProfileService } from '../../src/profile/profile.service';

describe('age gate', () => {
  it('ageOn counts completed years', () => {
    expect(ageOn('2013-10-08', '2026-10-07')).toBe(12);
    expect(ageOn('2013-10-08', '2026-10-08')).toBe(13);
    expect(ageOn('2012-02-29', '2025-02-28')).toBe(12);
    expect(ageOn('2012-02-29', '2025-03-01')).toBe(13);
  });

  it("judges age on the user's own local date (never blocks a 13-year-old because UTC lags)", () => {
    // 2026-10-07T20:00Z is already 2026-10-08 01:30 in IST; the UTC date is still 10-07.
    const now = new Date('2026-10-07T20:00:00Z');
    expect(isUnder13('2013-10-08', now, 'Asia/Kolkata')).toBe(false); // 13 today in IST → allowed
    expect(isUnder13('2013-10-09', now, 'Asia/Kolkata')).toBe(true); // one day short locally
    // Behind UTC: local date is 10-07 while UTC is 10-08.
    const late = new Date('2026-10-08T02:00:00Z');
    expect(isUnder13('2013-10-08', late, 'America/New_York')).toBe(true); // 12 locally
    expect(isUnder13('2013-10-08', late, 'UTC')).toBe(false);
  });
});

describe('profile request schema', () => {
  const ok = { birthDate: '2006-04-17', uiLocale: 'te-Latn', timezone: 'Asia/Kolkata', country: 'in' };

  it('accepts the contract example and normalises country', () => {
    expect(profileRequestSchema.parse(ok)).toEqual({ ...ok, country: 'IN' });
    expect(profileRequestSchema.parse({ ...ok, country: undefined }).country).toBeUndefined();
  });

  it.each([
    ['bad date', { birthDate: '2006-02-30' }],
    ['bad locale', { uiLocale: 'fr' }],
    ['bad tz', { timezone: 'Mars/Olympus' }],
    ['bad country', { country: 'IND' }],
  ])('rejects %s', (_, over) => {
    expect(profileRequestSchema.safeParse({ ...ok, ...over }).success).toBe(false);
  });

  it('derives the language pool', () => {
    expect(languagePoolFor('en')).toBe('en');
    expect(languagePoolFor('te')).toBe('te');
    expect(languagePoolFor('te-Latn')).toBe('te');
    expect(languagePoolFor('hi')).toBe('hi');
    expect(languagePoolFor('hi-Latn')).toBe('hi');
  });
});

describe('ProfileService', () => {
  const req = { birthDate: '2000-01-01', uiLocale: 'en' as const, timezone: 'UTC', country: null };

  const serviceWith = (withTx: jest.Mock) =>
    new ProfileService({ withTx } as never, {} as never, {} as never);

  it('refuses under-13 before touching the database', async () => {
    const withTx = jest.fn();
    const err = await serviceWith(withTx)
      .upsert('u', { ...req, birthDate: '2020-01-01' })
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err).toMatchObject({ status: 403, code: 'under_13' });
    expect(withTx).not.toHaveBeenCalled();
  });

  it('maps a profiles_min_age check violation (23514) to 403 under_13, never 500', async () => {
    const withTx = jest.fn().mockRejectedValue(Object.assign(new Error('check'), { code: '23514', constraint: 'profiles_min_age' }));
    await expect(serviceWith(withTx).upsert('u', req)).rejects.toMatchObject({ status: 403, code: 'under_13' });
  });
});
