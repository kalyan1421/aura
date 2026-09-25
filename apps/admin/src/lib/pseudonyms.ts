/** Room pseudonyms in the console (PRD 19 Configuration). Pure (unit-tested). */
export interface BlockedPseudonym {
  pseudonym: string;
  reasonCode: string;
  createdBy: string;
  createdAt: string;
}

export interface PseudonymConfig {
  adjectives: string[];
  nouns: string[];
  codeBlocked: string[];
  blocked: BlockedPseudonym[];
  available: number;
}

/** Two words of letters (the server checks it is one the generator hands out). */
export function isPseudonymShaped(v: string): boolean {
  return /^[A-Za-z]{2,15}\s+[A-Za-z]{2,15}$/.test(v.trim());
}
