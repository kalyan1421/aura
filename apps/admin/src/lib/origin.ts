/**
 * Same-origin check for route handlers (they don't get the Server Action origin check). A missing, opaque (`null`) or
 * malformed Origin is refused, never an error (docs/security/milestone-b-review.md §5.14: `Origin: null` used to
 * answer 500 on the evidence export). Pure (unit-tested).
 */
export function isSameOrigin(origin: string | null, host: string | null): boolean {
  if (!origin || !host || origin === 'null') return false;
  try {
    return new URL(origin).host === host;
  } catch {
    return false;
  }
}
