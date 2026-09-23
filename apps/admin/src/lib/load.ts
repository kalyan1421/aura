import { notFound } from 'next/navigation';
import { ApiFailure, apiGet } from './api';

/** A GET for a page: 404 → the not-found page; 403 (role) → `{ forbidden: true }` so the page can say so calmly. */
export type Forbidden = { forbidden: true };

export async function load<T>(path: string): Promise<T | Forbidden> {
  try {
    return await apiGet<T>(path);
  } catch (e) {
    if (e instanceof ApiFailure && e.status === 404) notFound();
    if (e instanceof ApiFailure && e.status === 403) return { forbidden: true };
    throw e;
  }
}

export const isForbidden = (x: unknown): x is Forbidden => typeof x === 'object' && x !== null && 'forbidden' in x;
