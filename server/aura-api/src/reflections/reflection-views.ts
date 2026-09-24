import type { RejectReason } from './decide';
import { tryOpen } from './reflection-cipher';
import type { ListedRow } from './reflections.repository';

/**
 * App-facing shapes (contracts/api/v1-reflections.md "Shapes"). DS-10: authors only as `{ memberId, pseudonym }`; no
 * account id, age, under-18 flag, lane or score ever — the stricter-threshold and hold-reason details stay on the
 * server (the author sees only a calm review hint).
 */
export type ReviewHint = 'soon' | 'overnight';
export type ComposerState = 'open' | 'limit_reached' | 'paused' | 'read_only';

export interface ReflectionView {
  reflectionId: string;
  status: 'published' | 'pending' | 'held' | 'rejected' | 'removed';
  author: { memberId: string; pseudonym: string };
  isMine: boolean;
  text: string;
  createdAt: string;
  publishedAt: string | null;
  gestureCount: number | null;
  rejectReason: RejectReason | null;
  review: ReviewHint | null;
}

export interface ComposerView {
  state: ComposerState;
  maxChars: number;
  perRoom: number;
  remainingInRoom: number;
  remainingToday: number;
  slow: boolean;
}

export type SendStatus = 'published' | 'pending' | 'held' | 'rejected' | 'crisis_diverted';

export interface SendOutcome {
  reflectionId: string;
  status: SendStatus;
  rejectReason: RejectReason | null;
  review: ReviewHint | null;
  showSupport: boolean;
  reflection: ReflectionView | null;
  composer: ComposerView;
}

/** One listed row → the view, or null when its text can't be opened (never shown half-decrypted). */
export function reflectionView(row: ListedRow, viewerUserId: string, masterKey: Buffer, overnightNow: boolean): ReflectionView | null {
  const text = tryOpen(masterKey, row.id, row.body_ct, row.body_key);
  if (text === null) return null;
  const mine = row.user_id === viewerUserId;
  const status = row.status as ReflectionView['status'];
  const waiting = status === 'pending' || status === 'held';
  return {
    reflectionId: row.id,
    status,
    author: { memberId: row.member_id, pseudonym: row.pseudonym },
    isMine: mine,
    text,
    createdAt: row.created_at.toISOString(),
    publishedAt: row.published_at ? row.published_at.toISOString() : null,
    gestureCount: mine && status === 'published' ? row.gesture_count : null,
    rejectReason: mine && (status === 'rejected' || status === 'removed') ? (row.reject_reason ?? 'other') : null,
    review: mine && waiting ? (overnightNow || row.hold_reason === 'overnight' ? 'overnight' : 'soon') : null,
  };
}
