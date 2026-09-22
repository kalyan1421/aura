import { isUuid, uuidv5, uuidv7 } from '../../src/common/uuid';

describe('uuid helpers', () => {
  it('uuidv5 matches the RFC 9562 test vector', () => {
    // DNS namespace + "www.example.com" (RFC 9562 Appendix A.4)
    expect(uuidv5('www.example.com', '6ba7b810-9dad-11d1-80b4-00c04fd430c8')).toBe('2ed6657d-e927-568b-95e1-2665a8aea6a2');
  });
  it('uuidv7 is time ordered and well formed', () => {
    const a = uuidv7(1_700_000_000_000);
    const b = uuidv7(1_700_000_000_001);
    expect(isUuid(a)).toBe(true);
    expect(a[14]).toBe('7');
    expect(a < b).toBe(true);
  });
});
