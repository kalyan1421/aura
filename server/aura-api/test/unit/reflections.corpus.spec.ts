import { randomBytes, randomUUID } from 'node:crypto';
import { corpusLabel, corpusLanguage, isoWeekStart, openCorpusText, sealCorpusText } from '../../src/reflections/corpus';

/** REQ-SAFE-16 de-identified corpus: which decisions may enter it, as what, and how the text is sealed. */
describe('moderation corpus (REQ-SAFE-16)', () => {
  it('labels: published → allow; rejections and removals keep their category', () => {
    expect(corpusLabel('published', null)).toBe('allow');
    expect(corpusLabel('rejected', 'hurtful')).toBe('reject_hurtful');
    expect(corpusLabel('rejected', 'sexual')).toBe('reject_sexual');
    expect(corpusLabel('rejected', null)).toBe('reject_other');
    expect(corpusLabel('removed', 'hurtful')).toBe('removed_hurtful');
    expect(corpusLabel('removed', 'other')).toBe('removed_other');
  });

  it('never: crisis, held, deleted, expired, Minors & grooming, contact details, links, personal questions', () => {
    for (const outcome of ['crisis_diverted', 'held', 'pending', 'deleted', 'expired']) expect(corpusLabel(outcome, null)).toBeNull();
    expect(corpusLabel('rejected', 'sexual', { minorSafety: true })).toBeNull();
    expect(corpusLabel('published', null, { minorSafety: true })).toBeNull();
    for (const reason of ['contact_details', 'link', 'personal_questions'] as const) {
      expect(corpusLabel('rejected', reason)).toBeNull();
      expect(corpusLabel('removed', reason)).toBeNull();
    }
  });

  it('language: the pool in its script (romanized → -Latn)', () => {
    expect(corpusLanguage('en', 'first Diwali alone')).toBe('en');
    expect(corpusLanguage('te', 'నాకు బాధగా ఉంది')).toBe('te');
    expect(corpusLanguage('te', 'naaku baadhaga undi')).toBe('te-Latn');
    expect(corpusLanguage('hi', 'मुझे अकेलापन लग रहा है')).toBe('hi');
    expect(corpusLanguage('hi', 'akelapan lag raha hai')).toBe('hi-Latn');
    // Merged into English, written in Telugu script: the script wins.
    expect(corpusLanguage('en', 'ఒంటరితనం')).toBe('te');
  });

  it('the only time kept is the ISO week start (a Monday, UTC)', () => {
    expect(isoWeekStart(new Date('2026-10-07T18:30:00Z'))).toBe('2026-10-05'); // Wednesday
    expect(isoWeekStart(new Date('2026-10-05T00:00:00Z'))).toBe('2026-10-05'); // Monday
    expect(isoWeekStart(new Date('2026-10-11T23:59:59Z'))).toBe('2026-10-05'); // Sunday
    expect(isoWeekStart(new Date('2027-01-01T10:00:00Z'))).toBe('2026-12-28'); // across the year
  });

  it('text is sealed per row (DS-1 envelope) and bound to its id', () => {
    const master = randomBytes(32);
    const id = randomUUID();
    const sealed = sealCorpusText(master, id, 'naaku ontaritanam ga undi');
    expect(sealed.textCt).not.toContain('ontaritanam');
    expect(openCorpusText(master, id, sealed)).toBe('naaku ontaritanam ga undi');
    expect(() => openCorpusText(master, randomUUID(), sealed)).toThrow(); // moved to another row
    expect(() => openCorpusText(randomBytes(32), id, sealed)).toThrow(); // another master key
  });
});
