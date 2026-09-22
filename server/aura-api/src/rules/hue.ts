/** RULES.md §6 — circular weighted mean of the last 14 aura days' check-in quadrants. */
export const QUADRANTS = ['storm', 'rain', 'moonlight', 'sunrise'] as const;
export type Quadrant = (typeof QUADRANTS)[number];

export const QUADRANT_HUE_DEG: Readonly<Record<Quadrant, number>> = {
  sunrise: 45,
  rain: 175,
  moonlight: 210,
  storm: 275,
};

export const HUE_WINDOW_DAYS = 14;
const EPS = 1e-9;

export function isQuadrant(v: unknown): v is Quadrant {
  return typeof v === 'string' && (QUADRANTS as readonly string[]).includes(v);
}

/** Hue in [0, 360), or null when there is nothing (or everything cancels out). */
export function hueFor(counts: Partial<Record<Quadrant, number>>): number | null {
  let x = 0;
  let y = 0;
  for (const q of QUADRANTS) {
    const w = counts[q] ?? 0;
    if (w <= 0) continue;
    const rad = (QUADRANT_HUE_DEG[q] * Math.PI) / 180;
    x += w * Math.cos(rad);
    y += w * Math.sin(rad);
  }
  if (Math.hypot(x, y) < EPS) return null;
  const deg = (Math.atan2(y, x) * 180) / Math.PI;
  return ((deg % 360) + 360) % 360;
}
